package game_tests

import game "../src"
import "core:testing"

@(test)
item_pool_spawn_caps_only_normal_items :: proc(t: ^testing.T) {
	items_config := make(map[game.ItemKind]game.ItemConfig, context.allocator)
	map_insert(&items_config, game.ItemKind.Normal, game.ItemConfig{width = 20, height = 20})
	defer delete(items_config)

	rules: game.GameRules
	item_catalog: game.ItemCatalog
	screen_x: f32 = 800

	// Normal cap is 1 (total hard cap is 3)
	item_pool := game.item_pool_init(
		context.allocator,
		active_cap = 1,
		hard_cap = 3,
		spawn_cooldown = 0,
	)
	defer delete(item_pool.items)

	// Normal item spawn should respects the active cap
	normal_spawned := game.item_pool_try_spawn(
		items_config,
		rules,
		item_catalog,
		&item_pool,
		game.ItemKind.Normal,
		game.ItemSpawnPolicy.Normal,
		screen_x,
	)

	testing.expect(t, normal_spawned)
	testing.expect_value(t, len(item_pool.items), 1)
	testing.expect_value(t, item_pool.normal_active, u8(1))

	// Further normal items should be rejected by the active cap
	second_normal_spawned := game.item_pool_try_spawn(
		items_config,
		rules,
		item_catalog,
		&item_pool,
		game.ItemKind.Normal,
		game.ItemSpawnPolicy.Normal,
		screen_x,
	)

	testing.expect(t, !second_normal_spawned)
	testing.expect_value(t, len(item_pool.items), 1)
	testing.expect_value(t, item_pool.normal_active, u8(1))

	// Special items should bypass the normal active cap
	bypass_spawned := game.item_pool_try_spawn(
		items_config,
		rules,
		item_catalog,
		&item_pool,
		game.ItemKind.Normal,
		game.ItemSpawnPolicy.BypassCap,
		screen_x,
	)

	testing.expect(t, bypass_spawned)
	testing.expect_value(t, len(item_pool.items), 2)
	testing.expect_value(t, item_pool.normal_active, u8(1))

	// Removing the bypass_cap (last) item should not touch the active cap
	bypass_item := game.item_pool_remove_at(&item_pool, 1)
	testing.expect_value(t, bypass_item.spawn_policy, game.ItemSpawnPolicy.BypassCap)
	testing.expect_value(t, item_pool.normal_active, u8(1))

	// Removing normal item should free up the active slot
	normal_item := game.item_pool_remove_at(&item_pool, 0)
	testing.expect_value(t, normal_item.spawn_policy, game.ItemSpawnPolicy.Normal)
	testing.expect_value(t, item_pool.normal_active, u8(0))
	testing.expect_value(t, len(item_pool.items), 0)
}
