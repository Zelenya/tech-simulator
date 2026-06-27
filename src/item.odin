package game

import k2 "../karl2d"
import "base:runtime"
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

ItemShape :: enum {
	Rect,
	Circle,
}

// TODO: Merge with item?
ItemDef :: struct {
	weight: f32,
	effect: CatchEffect,
}

WeightedItem :: struct {
	kind:   ItemKind,
	weight: f32,
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
	by_kind:           map[ItemKind]ItemDef,
	good:              [dynamic]WeightedItem,
	bad:               [dynamic]WeightedItem,
	good_weight:       f32,
	bad_weight:        f32,
	good_to_bad_ratio: f32,
}

// TODO: This should be unified with item pool
item_catalog_init :: proc(
	allocator: runtime.Allocator,
	item_configs: map[ItemKind]ItemConfig,
	item_pool_config: ItemPoolConfig,
) -> ItemCatalog {
	item_catalog := ItemCatalog {
		by_kind = make(map[ItemKind]ItemDef, allocator),
		// TODO: Do we need some capacity here? or use maps?
		good    = make([dynamic]WeightedItem, allocator),
		bad     = make([dynamic]WeightedItem, allocator),
	}
	item_catalog_reset_from_config(item_configs, item_pool_config, &item_catalog)
	return item_catalog
}

item_catalog_reset_from_config :: proc(
	item_configs: map[ItemKind]ItemConfig,
	item_pool_config: ItemPoolConfig,
	item_catalog: ^ItemCatalog,
) {
	clear(&item_catalog.by_kind)
	item_catalog.good_to_bad_ratio = item_pool_config.good_to_bad_ratio

	for kind, config in item_configs {
		map_insert(
			&item_catalog.by_kind,
			kind,
			ItemDef{weight = config.weight, effect = config.effect},
		)
	}

	item_catalog_refill(item_catalog)
}

item_catalog_refill :: proc(item_catalog: ^ItemCatalog) {
	clear(&item_catalog.good)
	clear(&item_catalog.bad)
	item_catalog.good_weight = 0
	item_catalog.bad_weight = 0

	for kind, def in item_catalog.by_kind {
		switch effect in def.effect {
		case GoodItemCaught:
			append_elem(&item_catalog.good, WeightedItem{kind = kind, weight = def.weight})
			item_catalog.good_weight += def.weight
		case BadItemCaught:
			append_elem(&item_catalog.bad, WeightedItem{kind = kind, weight = def.weight})
			item_catalog.bad_weight += def.weight
		}
	}
}

item_catalog_update_weight :: proc(
	item_catalog: ^ItemCatalog,
	item_kind: ItemKind,
	multiplier: f32,
) {
	item := &item_catalog.by_kind[item_kind]
	item.weight *= multiplier
	item_catalog_refill(item_catalog)
}

item_catalog_update_good_to_bad_ratio :: proc(item_catalog: ^ItemCatalog, multiplier: f32) {
	item_catalog.good_to_bad_ratio *= multiplier
	item_catalog_refill(item_catalog)
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

item_init :: proc(
	item_configs: map[ItemKind]ItemConfig,
	item_catalog: ItemCatalog,
	screen_x: f32,
	speed: f32,
) -> Item {
	kind := pick_weighted_item_kind(item_catalog)
	config := item_configs[kind]

	return Item {
		x = rand.float32_range(0, screen_x - config.width / 2),
		y = -config.height,
		width = config.width,
		height = config.height,
		speed = speed,
		kind = kind,
		state = .Falling,
		flashing_elapsed = 0,
	}
}

pick_weighted_item_kind :: proc(items: ItemCatalog) -> ItemKind {
	weighted := items.good[:]
	total_weight := items.good_weight
	if rand.float32() >= items.good_to_bad_ratio {
		weighted = items.bad[:]
		total_weight = items.bad_weight
	}

	return pick_weighted_item_kind_from(weighted, total_weight)
}

pick_weighted_item_kind_from :: proc(items: []WeightedItem, total_weight: f32) -> ItemKind {
	assert(len(items) > 0)
	assert(total_weight > 0)

	r := rand.float32() * total_weight
	for d in items {
		r -= d.weight
		if r <= 0 do return d.kind
	}

	return items[0].kind
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

item_draw :: proc(
	effects_config: EffectsConfig,
	item_config: ItemConfig,
	effects: Effects,
	item: Item,
) {
	item_box := k2.Rect {
		x = item.x,
		y = item.y,
		w = item.width,
		h = item.height,
	}

	#partial switch item.state {
	case .Inactive:
		break
	case .Falling:
		k2.draw_texture_fit(item_config.sprite, k2.get_texture_rect(item_config.sprite), item_box)
		draw_item_outline(item_config.shape, item_box, 3, get_item_color(effects, item_config))
	case .Flashing:
		flashing := int(item.flashing_elapsed * effects_config.flashing_speed) % 2 == 0
		if flashing {
			draw_item_flashing(item_config.shape, item_box, k2.WHITE)
		} else {
			k2.draw_texture_fit(
				item_config.sprite,
				k2.get_texture_rect(item_config.sprite),
				item_box,
			)
			draw_item_outline(item_config.shape, item_box, 3, get_item_color(effects, item_config))
		}
	}
}

draw_item_outline :: proc(shape: ItemShape, box: k2.Rect, thickness: f32, color: k2.Color) {
	switch shape {
	case .Rect:
		k2.draw_rect_outline(box, thickness, color)
	case .Circle:
		// TODO: This is not really pixel-arty :)
		k2.draw_circle_outline(k2.rect_center(box), box.w / 2, thickness, color)
	}
}

draw_item_flashing :: proc(shape: ItemShape, box: k2.Rect, color: k2.Color) {
	switch shape {
	case .Rect:
		k2.draw_rect(box, color)
	case .Circle:
		k2.draw_circle(k2.rect_center(box), box.w / 2, color)
	}
}

// Note: If we decide to make effects dynamic and mess with items, this shouldn't use config
get_item_color :: proc(effects: Effects, item: ItemConfig) -> k2.Color {
	switch effect in item.effect {
	case GoodItemCaught:
		if effects.preference == item.kind {
			return k2.PURPLE
		} else {
			return k2.GREEN
		}
	case BadItemCaught:
		return k2.RED
	}
	// idk
	return k2.WHITE
}

ItemPool :: struct {
	// TODO: Move the settings?
	setting_spawn_timer: f32,
	setting_item_speed:  f32,
	setting_active_cap:  u8,
	items:               [dynamic]Item,
	currently_active:    u8,
	spawn_cooldown:      f32,
}

// TODO: Should probably just create outside of screen anyways, and then change this on spawn.
// Also should properly pre-allocate and pre-create a list of items and reuse
item_pool_init :: proc(
	allocator: runtime.Allocator,
	active_cap: u8,
	speed: f32,
	spawn_cooldown: f32,
) -> ItemPool {
	// TODO: Review. We only see capped active items + flashing items
	capacity := int(2 * active_cap)
	return ItemPool {
		setting_spawn_timer = spawn_cooldown,
		setting_item_speed = speed,
		setting_active_cap = active_cap,
		items = make([dynamic]Item, capacity, capacity, allocator),
		currently_active = 0,
		spawn_cooldown = spawn_cooldown,
	}
}

// Uses primitive cooldown based on dt
item_pool_spawn :: proc(
	config: GameConfig,
	item_catalog: ItemCatalog,
	item_pool: ^ItemPool,
	screen_x: f32,
	dt: f32,
) {
	item_pool.spawn_cooldown -= dt
	if item_pool.spawn_cooldown <= 0 {
		item_pool.spawn_cooldown = item_pool.setting_spawn_timer
		if item_pool.currently_active < item_pool.setting_active_cap {
			found := false
			// re-use a spot
			for &item in item_pool.items {
				if item.state == .Inactive {
					item = item_init(
						config.items,
						item_catalog,
						screen_x,
						item_pool.setting_item_speed,
					)
					found = true
					break
				}
			}
			// or create a new one (TODO: this is ok for now, but can be pre-allocated)
			if !found {
				item := item_init(
					config.items,
					item_catalog,
					screen_x,
					item_pool.setting_item_speed,
				)
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

item_pool_reset_active :: proc(item_pool: ^ItemPool) {
	clear(&item_pool.items)
	item_pool.currently_active = 0
	item_pool.spawn_cooldown = item_pool.setting_spawn_timer
}

item_remove :: proc(pool: ^ItemPool, item: ^Item) {
	if item.state == .Falling {
		item.state = .Flashing
		pool.currently_active -= 1
	}
}
