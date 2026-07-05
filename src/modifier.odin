package game

import k2 "../karl2d"
import "core:math/rand"

// TODO: Split enum?
ModifierKind :: enum {
	// Preferences:
	Prestige,
	TechStack,
	Compensation,
	RemoteWork,
	// Good:
	AddPetProject,
	AskForReferral,
	HiringFreeze,
	FileUnemployment,
	GiveConferenceTalk,
	// Curses:
	Burnout,
	LeetCodeGrind,
	LowerQualityBar,
	TightenCV,
	SprayAndPray,
	// Wild:
	AutomatePipeline,
	BlindApplication,
	GiveUp,
	RecruiterSpam,
	ImposterSyndrom,
	// Final:
	Bonus,
	Continue,
}

modifier_apply :: proc(config: GameConfig, session: ^Session, modifier: ModifierKind) {
	effects := config.modifier_effects

	switch modifier {
	case .Prestige:
		session.effects.preference = effects.prestige_preference_item
	case .TechStack:
		session.effects.preference = effects.tech_stack_preference_item
	case .Compensation:
		session.effects.preference = effects.compensation_preference_item
	case .RemoteWork:
		session.effects.preference = effects.remote_work_preference_item

	case .AddPetProject: // TODO
	case .AskForReferral:
		// We update preferences on the prev. wave, player should always have one
		item_to_boost, ok := session.effects.preference.?
		if ok {
			item_catalog_update_weight(
				&session.item_catalog,
				item_to_boost,
				effects.ask_for_referral_weight_multiplier,
			)
		}
	case .FileUnemployment:
		session.lives += effects.file_unemployment_lives_delta
	case .GiveConferenceTalk:
		session.effects.good_catch_margin +=
			config.player.width * effects.give_conference_talk_margin_multiplier
		session.effects.good_catch_magnet *= effects.give_conference_talk_magnet_multiplier
	case .HiringFreeze:
		// This conflicst with wave bumps?
		session.item_pool.setting_item_speed *= effects.hiring_freeze_item_speed_multiplier

	case .Burnout:
		session.item_pool.setting_item_speed *= effects.burnout_item_speed_multiplier
		session.effects.score_base *= effects.burnout_score_base_multiplier
	case .LeetCodeGrind: // TODO
	case .LowerQualityBar:
		item_catalog_update_good_to_bad_ratio(
			&session.item_catalog,
			effects.lower_quality_bar_ratio_multiplier,
		)
		// TODO: Should this be gated for people with one life?
		session.lives += effects.lower_quality_bar_lives_delta
	case .TightenCV:
		item_catalog_update_good_to_bad_ratio(
			&session.item_catalog,
			effects.tighten_cv_ratio_multiplier,
		)
		session.effects.score_base *= effects.tighten_cv_score_base_multiplier
	case .SprayAndPray:
		item_catalog_update_good_to_bad_ratio(
			&session.item_catalog,
			effects.spray_and_pray_ratio_multiplier,
		)
		session.effects.score_base /= effects.spray_and_pray_score_base_divisor

	case .AutomatePipeline: // TODO
	case .BlindApplication: // TODO
	case .GiveUp: // TODO
	case .RecruiterSpam: // TODO
	case .ImposterSyndrom: // TODO

	case .Bonus: // TODO
	case .Continue: // TODO
	}
}

ModifierOptions :: struct {
	options:  [3]ModifierCard,
	selected: int,
}

ModifierCard :: struct {
	kind:        ModifierKind,
	title:       string,
	description: string,
	card:        k2.Rect,
}

modifier_pick_init :: proc(config: GameConfig, session: Session) -> ModifierOptions {
	cards_config := config.cards
	screen := game_screen_size()

	total_width := cards_config.width * 3 + cards_config.gap * 2
	start_x := screen.x / 2 - total_width / 2
	start_y := screen.y / 2 - cards_config.height / 2

	to_card :: proc(cards_config: CardsConfig, start_x: f32, start_y: f32, i: int) -> k2.Rect {
		card_x := start_x + cast(f32)i * (cards_config.width + cards_config.gap)
		return k2.Rect{x = card_x, y = start_y, w = cards_config.width, h = cards_config.height}
	}

	option_cards: [3]ModifierCard
	for option, i in modifiers_pick(config, session.current_wave) {
		def := config.modifiers.by_kind[option]
		option_cards[i] = {
			kind        = option,
			title       = def.title,
			description = def.description,
			card        = to_card(cards_config, start_x, start_y, i),
		}
	}

	return ModifierOptions{options = option_cards, selected = 0}
}

modifiers_pick :: proc(config: GameConfig, wave: int) -> [3]ModifierKind {
	for_wave := config.waves[wave].modifiers
	options := make([]ModifierKind, len(for_wave), context.temp_allocator)
	copy(options, for_wave)
	rand.shuffle(options[:])
	return {options[0], options[1], options[2]}
}

// TODO: Should modifier own waves? or make wave.odin that owns game+modifiers
// TODO: Should we re-use menu card picking code?
// TODO: Allow picks with 1,2,3
modifier_pick_update :: proc(
	config: GameConfig,
	session: ^Session,
	modifier_options: ^ModifierOptions,
	dt: f32,
) -> GameState {
	if k2.key_went_down(.Left) do modifier_options.selected -= 1
	if k2.key_went_down(.Right) do modifier_options.selected += 1
	modifier_options.selected = clamp(
		modifier_options.selected,
		0,
		len(modifier_options.options) - 1,
	)

	mouse := game_mouse_position()
	for option, i in modifier_options.options {
		if is_inside(option.card, mouse) do modifier_options.selected = int(i)
	}

	if k2.key_went_down(.Enter) {
		selected := modifier_options.options[modifier_options.selected]
		return wave_next(config, session, selected.kind, dt)
	}

	if k2.mouse_button_went_down(.Left) {
		for option, _ in modifier_options.options {
			if is_inside(option.card, mouse) {
				return wave_next(config, session, option.kind, dt)
			}
		}
	}

	return .ModifierPick
}

wave_next :: proc(
	config: GameConfig,
	session: ^Session,
	modifier: ModifierKind,
	dt: f32,
) -> GameState {
	k2.play_sound(config.sounds.by_kind[.WaveNext])
	// TODO: Similar check is duplicate in game loop
	session.current_wave = min(session.current_wave + 1, len(config.waves) - 1)
	session.wave_timer = 0

	wave := config.waves[session.current_wave]

	// TODO: It's kind of weird that we do modifiers and normal "speed ups", those could conflict
	item_pool_next_wave(
		item_pool = &session.item_pool,
		spawn_multiplier = wave.spawn_multiplier,
		speed_multiplier = wave.speed_multiplier,
	)
	modifier_apply(config, session, modifier)
	return GameState.Playing
}

// TODO: Should we re-use menu card drawing code?
modifier_pick_draw :: proc(cards_config: CardsConfig, modifier_options: ModifierOptions) {
	for option, i in modifier_options.options {
		color := k2.GREEN if int(i) == modifier_options.selected else k2.GRAY
		k2.draw_rect(option.card, color)

		// TODO: this could be calc'ed ones inside card too (and looks bad now)
		text_size := k2.measure_text(option.title, 50)
		text_x := option.card.x + (cards_config.width / 2) - (text_size.x / 2)
		text_y := option.card.y + cards_config.height + 20

		k2.draw_text(option.title, {text_x, text_y}, 50, color)
	}
}
