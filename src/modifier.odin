package game

import k2 "../karl2d"
import "base:runtime"
import "core:container/queue"
import "core:math/rand"

Difficulty :: enum {
	Easy,
	Medium,
	Hard,
}

PetProjectModifier :: struct {
	catches: u32,
}

GiveUpModifier :: struct {
	elapsed: f32,
}

RecruiterSpamModifier :: struct {
	cooldown: f32,
	elapsed:  f32,
}

ModifierRuntime :: union {
	PetProjectModifier,
	GiveUpModifier,
	RecruiterSpamModifier,
}

SpawnItemAction :: struct {
	item_kind: Maybe(ItemKind),
}

ChangeLivesAction :: struct {
	delta: i8,
}

ModifierAction :: union {
	SpawnItemAction,
	ChangeLivesAction,
}

ModifierSystem :: struct {
	runtime: [dynamic]ModifierRuntime,
	pending: queue.Queue(ModifierAction),
}

// TODO: Add a way to pre-select/debug the picks
// TODO: Show the modifiers and score at the end for debuffs
modifier_system_init :: proc(allocator: runtime.Allocator) -> ModifierSystem {
	pending_queue: queue.Queue(ModifierAction)
	queue.init(&pending_queue, capacity = 8, allocator = allocator)

	// TODO: check the limits, we shouldn't have that many ~4 capacity is ok to start with
	return ModifierSystem {
		runtime = make([dynamic]ModifierRuntime, 0, 4, allocator),
		pending = pending_queue,
	}
}

modifier_system_update :: proc(
	modifier_config: ModifierEffectsConfig,
	modifiers: ^ModifierSystem,
	dt: f32,
) {
	i := 0
	for i < len(modifiers.runtime) {
		has_expired := false

		switch &state in &modifiers.runtime[i] {
		case PetProjectModifier:
		case GiveUpModifier:
			state.elapsed += dt
			if state.elapsed >= modifier_config.give_up_timer {
				queue.push_back(&modifiers.pending, ChangeLivesAction{delta = -1})
				state.elapsed = 0
			}
		case RecruiterSpamModifier:
			state.elapsed += dt
			state.cooldown += dt

			if state.cooldown >= modifier_config.recruiter_spawn_rate {
				queue.push_back(&modifiers.pending, SpawnItemAction{ItemKind.Neutral})
				state.cooldown = 0
			}

			has_expired = state.elapsed >= modifier_config.recruiter_spawn_timer
		}

		if has_expired do unordered_remove(&modifiers.runtime, i)
		else do i += 1
	}
}

modifiers_on_item_outcome :: proc(
	modifier_config: ModifierEffectsConfig,
	modifiers: ^ModifierSystem,
	item_preference: Maybe(ItemKind),
	outcome: ItemOutcome,
) {
	for &modifier in modifiers.runtime {
		#partial switch &state in modifier {
		case PetProjectModifier:
			if outcome.kind == .CaughtGood {
				state.catches += 1

				if state.catches >= modifier_config.add_pet_project_catch_number {
					state.catches = 0
					queue.push_back(&modifiers.pending, SpawnItemAction{item_preference})
				}
			}
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

modifier_apply_rules :: proc(config: GameConfig, rules: ^GameRules, modifier: ModifierKind) {
	effects := config.modifier_effects

	// These have special handling so we can reuse a bit of that code
	preference, changes_preference := modifier_preference(effects, modifier).?
	if changes_preference do rules.item_preference = preference

	#partial switch modifier {
	case .GiveConferenceTalk:
		rules.good_catch_margin +=
			config.player.width * effects.give_conference_talk_margin_multiplier
		rules.good_catch_magnet *= effects.give_conference_talk_magnet_multiplier
	case .HiringFreeze:
		rules.item_speed *= effects.hiring_freeze_item_speed_multiplier

	case .Burnout:
		rules.item_speed *= effects.burnout_item_speed_multiplier
		rules.score_base *= effects.burnout_score_base_multiplier
	case .LeetCodeGrind:
		rules.item_movement = .ErraticMotion
	case .TightenCV:
		rules.score_base *= effects.tighten_cv_score_base_multiplier
	case .SprayAndPray:
		rules.score_base /= effects.spray_and_pray_score_base_divisor

	case .AutomatePipeline:
		rules.item_movement = .MixedSpeed
	case .BlindApplication:
		rules.item_hidden_until_screen_ratio = effects.blind_application_hidden_ratio
	case .ImposterSyndrome:
		rules.show_score = false
	case .GiveUp:
		rules.item_damage_immune = true
	case .Bonus:
		// TODO: Implement it (or as modifier)
		rules.final_mode = true
	}
}

modifier_preference :: proc(
	effects: ModifierEffectsConfig,
	modifier: ModifierKind,
) -> Maybe(ItemKind) {
	#partial switch modifier {
	case .Prestige:
		return effects.prestige_preference_item
	case .TechStack:
		return effects.tech_stack_preference_item
	case .Compensation:
		return effects.compensation_preference_item
	case .RemoteWork:
		return effects.remote_work_preference_item
	}

	return nil
}

modifier_apply_catalog :: proc(
	effects: ModifierEffectsConfig,
	preference: Maybe(ItemKind),
	catalog: ^ItemCatalog,
	modifier: ModifierKind,
) {
	#partial switch modifier {
	case .AskForReferral:
		// We update preferences on the prev. wave, player should always have one
		item_to_boost, has_preference := preference.?
		if has_preference {
			item_catalog_update_weight(
				catalog,
				item_to_boost,
				effects.ask_for_referral_weight_multiplier,
			)
		}

	case .LeetCodeGrind:
		item_catalog_update_good_to_bad_ratio(catalog, effects.leet_code_ratio_multiplier)

	case .LowerQualityBar:
		item_catalog_update_good_to_bad_ratio(catalog, effects.lower_quality_bar_ratio_multiplier)

	case .TightenCV:
		item_catalog_update_good_to_bad_ratio(catalog, effects.tighten_cv_ratio_multiplier)

	case .SprayAndPray:
		item_catalog_update_good_to_bad_ratio(catalog, effects.spray_and_pray_ratio_multiplier)
	}
}

modifier_activate :: proc(
	effects: ModifierEffectsConfig,
	modifiers: ^ModifierSystem,
	modifier: ModifierKind,
) {
	#partial switch modifier {
	case .AddPetProject:
		append(&modifiers.runtime, PetProjectModifier{catches = 0})
	case .FileUnemployment:
		queue.push_back(
			&modifiers.pending,
			ChangeLivesAction{delta = effects.file_unemployment_lives_delta},
		)
	case .LowerQualityBar:
		// TODO: Should this be gated for people with one life?
		queue.push_back(
			&modifiers.pending,
			ChangeLivesAction{delta = effects.lower_quality_bar_lives_delta},
		)
	case .GiveUp:
		append(&modifiers.runtime, GiveUpModifier{elapsed = 0})
	case .RecruiterSpam:
		append(&modifiers.runtime, RecruiterSpamModifier{cooldown = 0, elapsed = 0})
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
	session.item_pool.setting_spawn_timer *= wave.spawn_multiplier

	// Record selection, rebuild persistnet rules and catalog, update current runtime state
	append(&session.modifier_picks, modifier)
	session.rules = game_rules_rebuild(config, session.difficulty, session.modifier_picks[:])
	item_catalog_rebuild(config, session.modifier_picks[:], &session.item_catalog)
	modifier_activate(config.modifier_effects, &session.modifiers, modifier)

	return GameState.Playing
}
