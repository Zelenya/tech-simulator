package game

import k2 "../karl2d"
import "base:runtime"
import "core:math/rand"

Difficulty :: enum {
	Easy,
	Medium,
	Hard,
}

PetProjectModifier :: struct {
	catches:       u32,
	pending_items: u32,
}

GiveUpModifier :: struct {
	elapsed: f32,
}

RecruiterSpamModifier :: struct {
	cooldown:      f32,
	elapsed:       f32,
	pending_items: u32,
}

ModifierRuntime :: union {
	PetProjectModifier,
	GiveUpModifier,
	RecruiterSpamModifier,
}

ModifierSystem :: struct {
	runtime: [dynamic]ModifierRuntime,
}

// TODO: Add a way to pre-select/debug the picks
// TODO: Show the modifiers and score at the end for debuffs
modifier_system_init :: proc(allocator: runtime.Allocator) -> ModifierSystem {
	// TODO: check the limits, we shouldn't have that many ~4 capacity is ok to start with
	return ModifierSystem{runtime = make([dynamic]ModifierRuntime, 0, 4, allocator)}
}

modifier_system_update :: proc(
	effect_config: EffectsConfig,
	modifier_config: ModifierEffectsConfig,
	session: ^Session,
	dt: f32,
) {
	if session.rules.item_spawn_hidden {
		screen := game_screen_size()
		fog_line := screen.y * modifier_config.blind_application_hidden_ratio

		for &item in session.item_pool.items {
			if item.y > fog_line do item.hidden = false
		}
	}

	i := 0
	for i < len(session.modifiers.runtime) {
		modifier := &session.modifiers.runtime[i]
		switch &state in modifier {
		case PetProjectModifier:
		case GiveUpModifier:
			state.elapsed += dt
			if state.elapsed >= modifier_config.give_up_timer {
				session.lives -= 1
				effects_set_hit(effect_config, &session.effects, v2 = false)
				state.elapsed = 0
			}
		case RecruiterSpamModifier:
			state.elapsed += dt
			state.cooldown += dt

			if state.cooldown >= modifier_config.recruiter_spawn_rate {
				state.pending_items += 1
				state.cooldown = 0
			}

			if state.elapsed >= modifier_config.recruiter_spawn_timer {
				// TODO: Need to remove the modifier from picks too or mark it inactive?
				// And maybe do this better too
				unordered_remove(&session.modifiers.runtime, i)
				state.elapsed = 0
				continue
			}
		}
		i += 1
	}
}

modifiers_on_good_item_caught :: proc(
	modifier_config: ModifierEffectsConfig,
	modifiers: ^ModifierSystem,
) {
	for &modifier in modifiers.runtime {
		switch &state in modifier {
		// TODO: This is the only one that has it, refactor
		case PetProjectModifier:
			state.catches += 1

			if state.catches >= modifier_config.add_pet_project_catch_number {
				state.catches = 0
				state.pending_items += 1
			}
		case GiveUpModifier:
		case RecruiterSpamModifier:
		}
	}
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
	ImposterSyndrome,
	// Final:
	Bonus,
	Continue,
}

modifier_apply :: proc(config: GameConfig, session: ^Session, modifier: ModifierKind) {
	effects := config.modifier_effects
	append(&session.picks, modifier)

	switch modifier {
	case .Prestige:
		session.rules.item_preference = effects.prestige_preference_item
	case .TechStack:
		session.rules.item_preference = effects.tech_stack_preference_item
	case .Compensation:
		session.rules.item_preference = effects.compensation_preference_item
	case .RemoteWork:
		session.rules.item_preference = effects.remote_work_preference_item

	case .AddPetProject:
		append(&session.modifiers.runtime, PetProjectModifier{pending_items = 0, catches = 0})
	case .AskForReferral:
		// We update preferences on the prev. wave, player should always have one
		item_to_boost, ok := session.rules.item_preference.?
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
		session.rules.item_speed *= effects.hiring_freeze_item_speed_multiplier

	case .Burnout:
		session.rules.item_speed *= effects.burnout_item_speed_multiplier
		session.effects.score_base *= effects.burnout_score_base_multiplier
	case .LeetCodeGrind:
		item_catalog_update_good_to_bad_ratio(
			&session.item_catalog,
			effects.leet_code_ratio_multiplier,
		)
		session.rules.item_movement = .ErraticMotion
	case .LowerQualityBar:
		item_catalog_update_good_to_bad_ratio(
			&session.item_catalog,
			effects.lower_quality_bar_ratio_multiplier,
		)
		// TODO: Should this be gated for people with one life?
		session.lives += effects.lower_quality_bar_lives_delta
	case .TightenCV:
		// TODO: Should this be a game rule too?
		item_catalog_update_good_to_bad_ratio(
			&session.item_catalog,
			effects.tighten_cv_ratio_multiplier,
		)
		// TODO: This should be a game rule
		session.effects.score_base *= effects.tighten_cv_score_base_multiplier
	case .SprayAndPray:
		item_catalog_update_good_to_bad_ratio(
			&session.item_catalog,
			effects.spray_and_pray_ratio_multiplier,
		)
		session.effects.score_base /= effects.spray_and_pray_score_base_divisor

	case .AutomatePipeline:
		session.rules.item_movement = .MixedSpeed
	case .BlindApplication:
		session.rules.item_spawn_hidden = true
	case .GiveUp:
		append(&session.modifiers.runtime, GiveUpModifier{elapsed = 0})
	case .RecruiterSpam:
		append(
			&session.modifiers.runtime,
			RecruiterSpamModifier{cooldown = 0, elapsed = 0, pending_items = 0},
		)
	case .ImposterSyndrome:
		session.rules.show_score = false
	case .Bonus:
		// TODO: Implement it (or as modifier)
		session.rules.final_mode = true
	case .Continue: // noop
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
		rules = &session.rules,
		item_pool = &session.item_pool,
		spawn_multiplier = wave.spawn_multiplier,
		speed_multiplier = wave.speed_multiplier,
	)
	modifier_apply(config, session, modifier)
	return GameState.Playing
}
