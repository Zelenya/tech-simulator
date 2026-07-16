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

Item :: struct {
	x, y:          f32,
	width, height: f32,
	speed:         f32,
	kind:          ItemKind,
	spawn_elapsed: f32,
}

item_init :: proc(
	item_configs: map[ItemKind]ItemConfig,
	item_catalog: ItemCatalog,
	item_kind: Maybe(ItemKind),
	screen_x: f32,
	speed: f32,
) -> Item {
	kind := item_kind.? or_else pick_weighted_item_kind(item_catalog)
	config := item_configs[kind]

	return Item {
		x = rand.float32_range(0, screen_x - config.width / 2),
		y = -config.height,
		width = config.width,
		height = config.height,
		speed = speed,
		kind = kind,
		spawn_elapsed = 0,
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

item_update :: proc(
	effect_config: EffectsConfig,
	session: ^Session,
	item: ^Item,
	def: ItemDef,
	dt: f32,
) {
	item.y += item.speed * dt
	item.spawn_elapsed += dt

	if item_is_good(def) && session.effects.good_catch_magnet > 1 {
		dir := session.player.x - item.x
		item.x += dir * session.effects.good_catch_magnet * dt
	}
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
	rules: GameRules,
	item: Item,
	flashing: bool,
) {
	// Stretch on spawn (TODO: this might need to go into update not to mess with magnets and stuff)
	scale := min(item.spawn_elapsed / 0.2, 1.0)
	scale_w := item.width * scale
	scale_h := item.height * scale
	item_box := k2.Rect {
		x = item.x + (item.width - scale_w) / 2,
		y = item.y + (item.height - scale_h) / 2,
		w = scale_w,
		h = scale_h,
	}

	if flashing {
		item_draw_flashing(item_config.shape, item_box, k2.WHITE)

	} else {
		k2.draw_texture_fit(item_config.sprite, k2.get_texture_rect(item_config.sprite), item_box)
		item_draw_outline(
			item_config.shape,
			item_box,
			3,
			get_item_color(rules.preference, item_config),
		)
	}
}

item_draw_outline :: proc(shape: ItemShape, box: k2.Rect, thickness: f32, color: k2.Color) {
	switch shape {
	case .Rect:
		k2.draw_rect_outline(box, thickness, color)
	case .Circle:
		// TODO: This is not really pixel-arty :)
		k2.draw_circle_outline(k2.rect_center(box), box.w / 2, thickness, color)
	}
}

item_draw_flashing :: proc(shape: ItemShape, box: k2.Rect, color: k2.Color) {
	switch shape {
	case .Rect:
		k2.draw_rect(box, color)
	case .Circle:
		k2.draw_circle(k2.rect_center(box), box.w / 2, color)
	}
}

// Note: If we decide to make effects dynamic and mess with items, this shouldn't use config
get_item_color :: proc(preference: Maybe(ItemKind), item: ItemConfig) -> k2.Color {
	switch effect in item.effect {
	case GoodItemCaught:
		if preference == item.kind {
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
	setting_normal_cap:  u8,
	setting_hard_cap:    u8,
	items:               [dynamic]Item,
	spawn_cooldown:      f32,
}

// TODO: Should probably just create outside of screen anyways, and then change this on spawn.
// Also should properly pre-allocate and pre-create a list of items and reuse
item_pool_init :: proc(
	allocator: runtime.Allocator,
	active_cap: u8,
	hard_cap: u8,
	speed: f32,
	spawn_cooldown: f32,
) -> ItemPool {
	return ItemPool {
		setting_spawn_timer = spawn_cooldown,
		setting_item_speed = speed,
		setting_normal_cap = active_cap,
		setting_hard_cap = hard_cap,
		items = make([dynamic]Item, 0, hard_cap, allocator),
		spawn_cooldown = spawn_cooldown,
	}
}

ItemSpawnPolicy :: enum {
	Normal,
	BypassCap,
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
		_ = item_pool_spawn_one(
			config,
			item_catalog,
			item_pool,
			nil,
			ItemSpawnPolicy.Normal,
			screen_x,
		)
	}
}

// TODO: Merge with above when we have better event/modifiers handling
item_pool_spawn_modified :: proc(config: GameConfig, session: ^Session, screen_x: f32) {
	for &modifier in session.modifiers.runtime {
		switch &state in modifier {
		case PetProjectModifier:
			to_spawn := state.pending_items
			for _ in 0 ..< to_spawn {
				spawned := item_pool_spawn_one(
					config,
					session.item_catalog,
					&session.item_pool,
					session.rules.preference,
					ItemSpawnPolicy.BypassCap,
					screen_x,
				)

				if !spawned do break
				state.pending_items -= 1
			}
		}
	}
}

@(private = "file")
item_pool_spawn_one :: proc(
	config: GameConfig,
	item_catalog: ItemCatalog,
	item_pool: ^ItemPool,
	item_kind: Maybe(ItemKind),
	policy: ItemSpawnPolicy,
	screen_x: f32,
) -> bool {
	active := len(item_pool.items)

	// Everyone respects the hard cap
	if active >= int(item_pool.setting_hard_cap) {
		return false
	}

	// Normal spawns respect the normal cap, special/modifiers don't
	if policy == .Normal && active >= int(item_pool.setting_normal_cap) {
		return false
	}

	item := item_init(
		config.items,
		item_catalog,
		item_kind,
		screen_x,
		item_pool.setting_item_speed,
	)
	append(&item_pool.items, item)
	return true
}

item_pool_next_wave :: proc(item_pool: ^ItemPool, spawn_multiplier: f32, speed_multiplier: f32) {
	item_pool.setting_spawn_timer *= spawn_multiplier
	item_pool.setting_item_speed *= speed_multiplier
}

item_pool_reset_active :: proc(config: ItemPoolConfig, item_pool: ^ItemPool) {
	clear(&item_pool.items)
	item_pool.spawn_cooldown = item_pool.setting_spawn_timer
	item_pool.setting_hard_cap = config.hard_cap
}

item_pool_remove_at :: proc(pool: ^ItemPool, index: int) -> Item {
	removed := pool.items[index]
	unordered_remove(&pool.items, index)
	return removed
}
