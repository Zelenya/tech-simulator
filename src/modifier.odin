package game

import k2 "../karl2d"
import "core:fmt"
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

// TODO: Make effect configurable
modifier_apply :: proc(config: GameConfig, session: ^Session, modifier: ModifierKind) {
	switch modifier {
	case .Prestige:
		session.effects.preference = .Faang
	case .TechStack:
		session.effects.preference = .FireStack
	case .Compensation:
		session.effects.preference = .BigMoney
	case .RemoteWork:
		session.effects.preference = .Remote

	case .AddPetProject: // TODO
	case .AskForReferral:
		// We update preferences on the prev. wave, player should always have one
		item_to_boost, ok := session.effects.preference.?
		if ok do item_catalog_update_weight(&session.item_catalog, item_to_boost, 3)
	case .FileUnemployment:
		session.lives += 1
	case .GiveConferenceTalk:
		session.effects.good_catch_margin += config.player.width * 0.2
		session.effects.good_catch_magnet *= 1.5
	case .HiringFreeze:
		// This conflicst with wave bumps?
		session.item_pool.setting_item_speed *= 0.6

	case .Burnout:
		session.item_pool.setting_item_speed *= 1.5
		session.effects.score_base *= 3
	case .LeetCodeGrind: // TODO
	case .LowerQualityBar:
		item_catalog_update_good_to_bad_ratio(&session.item_catalog, 1.5)
		// TODO: Should this be gated for people with one life?
		session.lives -= 1
	case .TightenCV:
		item_catalog_update_good_to_bad_ratio(&session.item_catalog, 0.5)
		session.effects.score_base *= 5
	case .SprayAndPray:
		item_catalog_update_good_to_bad_ratio(&session.item_catalog, 1.3)
		session.effects.score_base /= 4

	case .AutomatePipeline: // TODO
	case .BlindApplication: // TODO
	case .GiveUp: // TODO
	case .RecruiterSpam: // TODO
	case .ImposterSyndrom: // TODO

	case .Bonus: // TODO
	case .Continue: // TODO
	}
}

// TODO: How much should this be in config vs. drawn?
modifier_label :: proc(kind: ModifierKind) -> string {
	switch kind {
	case .Prestige:
		return "Prestige"
	case .TechStack:
		return "Interesting tech"
	case .Compensation:
		return "Compenstaion"
	case .RemoteWork:
		return "Remote"

	case .AddPetProject:
		return "Bonus item every 5 catches"
	case .AskForReferral:
		return "Ask for referrals"
	case .FileUnemployment:
		return "Get extra life"
	case .GiveConferenceTalk:
		return "Get wider + magnet"
	case .HiringFreeze:
		return "Hiring freeze"

	case .Burnout:
		return "faster items, x2 points"
	case .LeetCodeGrind:
		return "less bad items, but good move erratically"
	case .LowerQualityBar:
		return "more good items, -1 life"
	case .TightenCV:
		return "x3 bad items, x5 points"
	case .SprayAndPray:
		return "x1.5 good items, 1/3 points"

	case .AutomatePipeline:
		return "fast and slow"
	case .BlindApplication:
		return "hide stuff"
	case .GiveUp:
		return "loose lifes every 1 min"
	case .RecruiterSpam:
		return "spam"
	case .ImposterSyndrom:
		return "hide the score"

	case .Bonus:
		return "Accept the challenge"
	case .Continue:
		return "I'm not ready"
	}
	return "idk"
}

ModifierOptions :: struct {
	options:  [3]ModifierCard,
	selected: int,
}

ModifierCard :: struct {
	kind:  ModifierKind,
	label: string, // TODO: title + description
	card:  k2.Rect,
}

modifier_pick_init :: proc(cards_config: CardsConfig, session: Session) -> ModifierOptions {
	fmt.printfln("Wave: %v", session.current_wave)
	screen := game_screen_size()

	total_width := cards_config.width * 3 + cards_config.gap * 2
	start_x := screen.x / 2 - total_width / 2
	start_y := screen.y / 2 - cards_config.height / 2

	to_card :: proc(cards_config: CardsConfig, start_x: f32, start_y: f32, i: int) -> k2.Rect {
		card_x := start_x + cast(f32)i * (cards_config.width + cards_config.gap)
		return k2.Rect{x = card_x, y = start_y, w = cards_config.width, h = cards_config.height}
	}

	option_cards: [3]ModifierCard
	// TODO: Improve randomness and make level dependend
	for option, i in modifiers_pick(session.current_wave) {
		option_cards[i] = {
			kind  = option,
			label = modifier_label(option),
			card  = to_card(cards_config, start_x, start_y, i),
		}
	}

	return ModifierOptions{options = option_cards, selected = 0}
}

// TODO: Is there a way to clean this up?
// TODO: Tie it to the waves length
modifier_packs := [5][]ModifierKind {
	0 = []ModifierKind{.Prestige, .TechStack, .Compensation, .RemoteWork},
	1 = []ModifierKind {
		.AddPetProject,
		.AskForReferral,
		.FileUnemployment,
		.GiveConferenceTalk,
		.HiringFreeze,
	},
	2 = []ModifierKind{.Burnout, .LeetCodeGrind, .LowerQualityBar, .TightenCV, .SprayAndPray},
	3 = []ModifierKind {
		.AutomatePipeline,
		.BlindApplication,
		.GiveUp,
		.RecruiterSpam,
		.ImposterSyndrom,
	},
	// TODO: This isn't shown yet
	4 = []ModifierKind{.Bonus, .Continue, .Bonus, .Continue},
}

modifiers_pick :: proc(wave: int) -> [3]ModifierKind {
	for_wave := modifier_packs[wave]
	rand.shuffle(for_wave[:])
	return {for_wave[0], for_wave[1], for_wave[2]}
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
	modifier_options.selected = clamp(modifier_options.selected, 0, len(Difficulty))

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
	for difficulty, i in modifier_options.options {
		color := k2.GREEN if int(i) == modifier_options.selected else k2.GRAY
		k2.draw_rect(difficulty.card, color)

		// TODO: this could be calc'ed ones inside card too (and looks bad now)
		text_size := k2.measure_text(difficulty.label, 50)
		text_x := difficulty.card.x + (cards_config.width / 2) - (text_size.x / 2)
		text_y := difficulty.card.y + cards_config.height + 20

		k2.draw_text(difficulty.label, {text_x, text_y}, 50, color)
	}
}
