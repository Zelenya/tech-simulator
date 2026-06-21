package game

import k2 "../karl2d"
import "core:math/rand"

ITEM_WIDTH: f32 : 100
ITEM_HEIGHT: f32 : 100

GoodKind :: enum {
	Normal,
	Call,
	Faang,
	FireStack,
	BigMoney,
	Remote,
}

BadKind :: enum {
	Rejection,
	Ignore,
	NightmareStack,
}

GoodItemDef :: struct {
	kind:   GoodKind,
	weight: f32,
	points: u32,
}

BadItemDef :: struct {
	kind:   BadKind,
	weight: f32,
}

ItemDef :: union {
	GoodItemDef,
	BadItemDef,
}

Item :: struct {
	x, y:          f32,
	width, height: f32,
	speed:         f32,
	active:        bool,
	type:          ItemDef,
}

good_item_defs := []GoodItemDef {
	{kind = .Normal, weight = 5, points = 100},
	{kind = .Call, weight = 5, points = 200},
	{kind = .Faang, weight = 1, points = 300},
	{kind = .FireStack, weight = 1, points = 300},
	{kind = .BigMoney, weight = 1, points = 300},
	{kind = .Remote, weight = 1, points = 300},
}

// TODO: Add more
bad_item_defs := []BadItemDef {
	{kind = .Rejection, weight = 4},
	{kind = .Ignore, weight = 4},
	{kind = .NightmareStack, weight = 2},
}

// TODO: Improve randomness or let pool pass bool and own that
item_init :: proc(screen_x: f32, speed: f32) -> Item {
	type: ItemDef
	if rand.float32() < 0.6 {type = pick_weighted_good()} else {type = pick_weighted_bad()}

	return Item {
		x = rand.float32_range(0, screen_x - ITEM_WIDTH / 2),
		y = -ITEM_HEIGHT,
		width = ITEM_WIDTH,
		height = ITEM_HEIGHT,
		speed = speed,
		active = true,
		type = type,
	}
}

// TODO: Refactor to be generic
pick_weighted_good :: proc() -> GoodItemDef {
	// Do it ones?
	total: f32
	for d in good_item_defs do total += d.weight

	r := rand.float32() * total
	for d in good_item_defs {
		r -= d.weight
		if r <= 0 do return d
	}

	return good_item_defs[0] // just in case
}

pick_weighted_bad :: proc() -> BadItemDef {
	// Do it ones?
	total: f32
	for d in bad_item_defs do total += d.weight

	r := rand.float32() * total
	for d in bad_item_defs {
		r -= d.weight
		if r <= 0 do return d
	}

	return bad_item_defs[0] // just in case
}

item_draw :: proc(item: Item) {
	test_box := k2.Rect {
		x = item.x,
		y = item.y,
		w = item.width,
		h = item.height,
	}

	// TODO: How to properly pattern match on kind?
	switch def in item.type {
	case GoodItemDef:
		switch def.kind {
		case .Normal:
			k2.draw_rect(test_box, k2.GREEN)
		case .Call:
			k2.draw_rect(test_box, k2.GREEN)
		case .Faang:
			k2.draw_rect(test_box, k2.PURPLE)
		case .FireStack:
			k2.draw_rect(test_box, k2.PURPLE)
		case .BigMoney:
			k2.draw_rect(test_box, k2.PURPLE)
		case .Remote:
			k2.draw_rect(test_box, k2.PURPLE)
		}
	case BadItemDef:
		switch def.kind {
		case .Rejection:
			k2.draw_rect(test_box, k2.RED)
		case .Ignore:
			k2.draw_rect(test_box, k2.RED)
		case .NightmareStack:
			k2.draw_rect(test_box, k2.DARK_RED)
		}
	}
}

ITEM_SPAWN_TIMER: f32 : 0.5

ItemPool :: struct {
	setting_spawn_timer: f32,
	setting_item_speed:  f32,
	setting_active_cap:  u8,
	items:               [dynamic]Item,
	currently_active:    u8,
	spawn_cooldown:      f32,
}

// TODO: Should probably just create outside of screen anyways, and then change this on spawn.
// Also should properly pre-allocate and pre-create a list of items and reuse
item_pool_init :: proc(active_cap: u8, speed: f32, spawn_cooldown: f32) -> ItemPool {
	empty: [dynamic]Item
	return ItemPool {
		setting_spawn_timer = spawn_cooldown,
		setting_item_speed = speed,
		setting_active_cap = active_cap,
		items = empty,
		currently_active = 0,
		spawn_cooldown = spawn_cooldown,
	}
}

// Uses primitive cooldown based on dt
item_pool_spawn :: proc(item_pool: ^ItemPool, screen_x: f32, dt: f32) {
	item_pool.spawn_cooldown -= dt
	if item_pool.spawn_cooldown <= 0 {
		item_pool.spawn_cooldown = item_pool.setting_spawn_timer
		if item_pool.currently_active < item_pool.setting_active_cap {
			found := false
			// re-use a spot
			for &item in item_pool.items {
				if !item.active {
					item = item_init(screen_x, item_pool.setting_item_speed)
					found = true
					break
				}
			}
			// or create a new one (TODO: this is ugly and should be pre-allocated)
			if !found {
				item := item_init(screen_x, item_pool.setting_item_speed)
				append(&item_pool.items, item)
			}
			item_pool.currently_active += 1
		}
	}
}

item_pool_next_wave :: proc(item_pool: ^ItemPool, spawn_multiplier: f32, speed_multiplier: f32) {
	item_pool.setting_spawn_timer *= spawn_multiplier
	item_pool.setting_item_speed *= speed_multiplier
}
