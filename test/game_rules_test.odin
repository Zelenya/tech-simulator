package game_tests

import game "../src"
import "core:testing"

@(test)
game_rules_rebuild_replays_rules_without_compounding :: proc(t: ^testing.T) {
	waves := [5]game.WaveConfig {
		{speed_multiplier = 1}, // Initial wave; not replayed
		{speed_multiplier = 2},
		{speed_multiplier = 3},
		{speed_multiplier = 1},
		{speed_multiplier = 1},
	}

	config: game.GameConfig
	config.waves = waves[:]
	config.difficulties[game.Difficulty.Easy].item_speed = 100
	config.modifier_effects.hiring_freeze_item_speed_multiplier = 0.5
	config.modifier_effects.burnout_item_speed_multiplier = 2
	config.modifier_effects.burnout_score_base_multiplier = 3

	picks := [4]game.ModifierKind{.HiringFreeze, .Burnout, .LeetCodeGrind, .AutomatePipeline}

	first := game.game_rules_rebuild(config, game.Difficulty.Easy, picks[:])

	// 100 × 2 × 0.5 × 3 × 2 = 600
	testing.expect_value(t, first.item_speed, f32(600))
	testing.expect_value(t, first.score_base, u32(3))
	testing.expect_value(t, first.item_movement, game.ItemMovement.MixedSpeed)

	// Rebuilding from the same inputs, is "idempotent" (doesn't compound effects)
	second := game.game_rules_rebuild(config, game.Difficulty.Easy, picks[:])
	testing.expect_value(t, second, first)
}
