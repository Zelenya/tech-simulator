package game

import k2 "../karl2d"
import "core:math/rand"

// TODO: I'm not happy with this shape, see more usage and re-shape
ItemKind :: enum {
	// Good
	Normal,
	Call,
	Faang,
	FireStack,
	BigMoney,
	Remote,
	// Bad
	Rejection,
	Ignore,
	NightmareStack,
}

// TODO: Not used yet
ItemShape :: enum {
	Rect,
	Circle,
}

ItemDef :: struct {
	kind:   ItemKind,
	sprite: k2.Texture,
	shape:  ItemShape,
	width:  f32,
	height: f32,
	weight: f32,
	effect: CatchEffect,
}

GoodItemCaught :: struct {
	points: u32,
}

BadItemCaught :: struct {}

CatchEffect :: union {
	GoodItemCaught,
	BadItemCaught,
}

ItemCatalog :: struct {
	by_kind:     map[ItemKind]ItemDef,
	good:        [dynamic]ItemDef,
	bad:         [dynamic]ItemDef,
	good_weight: f32,
	bad_weight:  f32,
}

ItemState :: enum {
	Inactive,
	Falling,
	Flashing,
}

Item :: struct {
	x, y:             f32,
	width, height:    f32,
	speed:            f32,
	kind:             ItemKind,
	state:            ItemState,
	// for the Flashing state
	flashing_elapsed: f32,
}

item_init :: proc(config: GameConfig, screen_x: f32, speed: f32) -> Item {
	kind := pick_weighted_item_kind(config.item_pool, config.items)
	def := config.items.by_kind[kind]

	return Item {
		x = rand.float32_range(0, screen_x - def.width / 2),
		y = -def.height,
		width = def.width,
		height = def.height,
		speed = speed,
		kind = kind,
		state = .Falling,
		flashing_elapsed = 0,
	}
}

pick_weighted_item_kind :: proc(item_pool_config: ItemPoolConfig, items: ItemCatalog) -> ItemKind {
	item_defs := items.good[:]
	total_weight := items.good_weight
	if rand.float32() >= item_pool_config.good_to_bad_ratio {
		item_defs = items.bad[:]
		total_weight = items.bad_weight
	}

	return pick_weighted_item_kind_from(item_defs, total_weight)
}

pick_weighted_item_kind_from :: proc(item_defs: []ItemDef, total_weight: f32) -> ItemKind {
	if len(item_defs) == 0 || total_weight <= 0 do return .Normal

	r := rand.float32() * total_weight
	for d in item_defs {
		r -= d.weight
		if r <= 0 do return d.kind
	}

	return item_defs[0].kind
}

item_is_good :: proc(def: ItemDef) -> bool {
	switch effect in def.effect {
	case GoodItemCaught:
		return true
	case BadItemCaught:
		return false
	}
	return false
}

item_draw :: proc(effects_config: EffectsConfig, item_def: ItemDef, item: Item) {
	item_box := k2.Rect {
		x = item.x,
		y = item.y,
		w = item.width,
		h = item.height,
	}

	switch item.state {
	case .Inactive:
		break
	case .Falling:
		k2.draw_texture_fit(item_def.sprite, k2.get_texture_rect(item_def.sprite), item_box)
		// TODO: This only works with squares, what about circles?
		k2.draw_rect_outline(item_box, 3, get_item_color(item_def))
	case .Flashing:
		flashing := int(item.flashing_elapsed * effects_config.flashing_speed) % 2 == 0
		if flashing {
			k2.draw_texture_fit(item_def.sprite, k2.get_texture_rect(item_def.sprite), item_box)
			// TODO: This only works with squares, what about circles?
			k2.draw_rect_outline(item_box, 3, get_item_color(item_def))
		} else {
			// TODO: This only works with squares, what about circles?
			k2.draw_rect(item_box, k2.WHITE)
		}
	}
}

// TODO: How to properly pattern match on kind?
// TODO: Special color for "selected" items, this is just for testing
get_item_color :: proc(def: ItemDef) -> k2.Color {
	switch effect in def.effect {
	case GoodItemCaught:
		#partial switch def.kind {
		case .Normal, .Call:
			return k2.GREEN
		case .Faang, .FireStack, .BigMoney, .Remote:
			return k2.PURPLE
		}
	case BadItemCaught:
		return k2.RED
	}
	return k2.WHITE // :shrug:
}

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
item_pool_spawn :: proc(config: GameConfig, item_pool: ^ItemPool, screen_x: f32, dt: f32) {
	item_pool.spawn_cooldown -= dt
	if item_pool.spawn_cooldown <= 0 {
		item_pool.spawn_cooldown = item_pool.setting_spawn_timer
		if item_pool.currently_active < item_pool.setting_active_cap {
			found := false
			// re-use a spot
			for &item in item_pool.items {
				if item.state == .Inactive {
					item = item_init(config, screen_x, item_pool.setting_item_speed)
					found = true
					break
				}
			}
			// or create a new one (TODO: this is ugly and should be pre-allocated)
			if !found {
				item := item_init(config, screen_x, item_pool.setting_item_speed)
				append(&item_pool.items, item)
			}
			item_pool.currently_active += 1
		}
	}
}

item_remove :: proc(pool: ^ItemPool, item: ^Item) {
	if item.state == .Falling {
		item.state = .Flashing
		pool.currently_active -= 1
	}
}

item_pool_next_wave :: proc(item_pool: ^ItemPool, spawn_multiplier: f32, speed_multiplier: f32) {
	item_pool.setting_spawn_timer *= spawn_multiplier
	item_pool.setting_item_speed *= speed_multiplier
}
