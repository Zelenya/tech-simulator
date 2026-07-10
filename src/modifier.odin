package game

import k2 "../karl2d"
import "core:math/rand"
// import "core:strings"

Difficulty :: enum {
	Easy,
	Medium,
	Hard,
}

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

modifiers_pick :: proc(config: GameConfig, wave: int) -> [3]ModifierKind {
	for_wave := config.waves[wave].modifiers
	options := make([]ModifierKind, len(for_wave), context.temp_allocator)
	copy(options, for_wave)
	rand.shuffle(options[:])
	return {options[0], options[1], options[2]}
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
