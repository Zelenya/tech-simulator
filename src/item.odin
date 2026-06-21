package game

import k2 "../karl2d"
import "core:math/rand"

ITEM_WIDTH: f32 : 32 * 2
ITEM_HEIGHT: f32 : 32 * 2

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

FLASHING_LIFETIME: f32 : 0.3
FLASHING_SPEED: f32 : 10

ItemState :: enum {
	Inactive,
	Falling,
	Flashing,
}

Item :: struct {
	x, y:             f32,
	width, height:    f32,
	speed:            f32,
	type:             ItemDef,
	state:            ItemState,
	// for the Flashing state
	flashing_elapsed: f32,
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
		type = type,
		state = .Falling,
		flashing_elapsed = 0,
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

item_draw :: proc(item: Item, textures: Textures) {
	item_box := k2.Rect {
		x = item.x,
		y = item.y,
		w = item.width,
		h = item.height,
	}

	// TODO: Is there a better way to pattern match on kind?
	// TODO: Fill those out and move?
	texture: k2.Texture
	switch def in item.type {
	case GoodItemDef:
		switch def.kind {
		case .Normal:
			texture = textures.item_good
		case .Call:
			texture = textures.item_good_call
		case .Faang:
			fallthrough
		case .FireStack:
			fallthrough
		case .BigMoney:
			fallthrough
		case .Remote:
			texture = textures.item_good
		}
	case BadItemDef:
		switch def.kind {
		case .Rejection:
			fallthrough
		case .Ignore:
			fallthrough
		case .NightmareStack:
			texture = textures.item_bad
		}
	}

	switch item.state {
	case .Inactive:
		break
	case .Falling:
		k2.draw_texture_fit(texture, k2.get_texture_rect(texture), item_box)
		// TODO: This only works with squares, what about circles?
		k2.draw_rect_outline(item_box, 3, get_item_color(item))
	case .Flashing:
		flashing := int(item.flashing_elapsed * FLASHING_SPEED) % 2 == 0
		if flashing {
			k2.draw_texture_fit(texture, k2.get_texture_rect(texture), item_box)
			// TODO: This only works with squares, what about circles?
			k2.draw_rect_outline(item_box, 3, get_item_color(item))
		} else {
			// TODO: This only works with squares, what about circles?
			k2.draw_rect(item_box, k2.WHITE)
		}
	}
}

// TODO: How to properly pattern match on kind?
// TODO: Special color for "selected" items, this is just for testing
get_item_color :: proc(item: Item) -> k2.Color {
	switch def in item.type {
	case GoodItemDef:
		switch def.kind {
		case .Normal, .Call:
			return k2.GREEN
		case .Faang, .FireStack, .BigMoney, .Remote:
			return k2.PURPLE
		}
	case BadItemDef:
		return k2.RED
	}
	return k2.WHITE // :shrug:
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
				if item.state == .Inactive {
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

// TODO: Not cleaned (need proper pool and reuse later?)
item_remove :: proc(pool: ^ItemPool, item: ^Item) {
	item.state = .Flashing
	// item.active = false
	pool.currently_active -= 1
}

item_pool_next_wave :: proc(item_pool: ^ItemPool, spawn_multiplier: f32, speed_multiplier: f32) {
	item_pool.setting_spawn_timer *= spawn_multiplier
	item_pool.setting_item_speed *= speed_multiplier
}
