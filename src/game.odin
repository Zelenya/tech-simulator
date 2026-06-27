package game

import k2 "../karl2d"
import "base:runtime"
import "core:fmt"

GameState :: enum {
	Title,
	Playing,
	ModifierPick,
	Pause,
	GameOver,
}

Session :: struct {
	player:       Player,
	item_catalog: ItemCatalog,
	item_pool:    ItemPool,
	effects:      Effects,
	combo:        u32,
	score:        u32,
	// just in case we go below 0
	lives:        i8,
	current_wave: int,
	wave_timer:   f32,
}

game_init :: proc(
	allocator: runtime.Allocator,
	config: GameConfig,
	difficulty: Difficulty,
) -> Session {
	settings := set_difficulty(difficulty)

	return Session {
		player = player_init(config.player),
		item_catalog = item_catalog_init(allocator, config.items, config.item_pool),
		item_pool = item_pool_init(
			allocator,
			settings.max_active,
			settings.item_speed,
			settings.spawn_interval,
		),
		effects = effects_init(),
		combo = 0,
		score = 0,
		lives = cast(i8)settings.lives,
		current_wave = 0,
		wave_timer = 0,
	}
}

game_update :: proc(config: GameConfig, session: ^Session, dt: f32) -> GameState {
	screen := game_screen_size()

	if k2.key_went_down(.Escape) do return GameState.Pause

	session.wave_timer += dt
	// Make progress (clamp it to X waves to be reasonable... for now)
	if session.wave_timer > config.waves[session.current_wave].duration &&
	   session.current_wave < len(config.waves) - 1 {
		return .ModifierPick
	}

	player_update(config.player, &session.player, dt)
	item_pool_spawn(config, session.item_catalog, &session.item_pool, screen.x, dt)
	item_pool_update(config.sounds, config.effects, session, session.item_catalog, dt = dt)
	effects_update(&session.effects, dt)

	if session.lives <= 0 {
		k2.play_sound(config.sounds.game_over)
		return .GameOver
	} else {return .Playing}
}

game_reload :: proc(config: GameConfig, session: ^Session) {
	item_catalog_reset_from_config(config.items, config.item_pool, &session.item_catalog)
	item_pool_reset_active(&session.item_pool)
	session.player = player_init(config.player)
	// in case we remove a wave:
	session.current_wave = min(session.current_wave, len(config.waves) - 1)
}

// TODO: This doesn't feel right, this should be inline and/or split by "domain"
// TODO: With effects even worse now, need to refactor
item_pool_update :: proc(
	sounds_config: SoundsConfig,
	effect_config: EffectsConfig,
	session: ^Session,
	items: ItemCatalog,
	dt: f32,
) {
	screen := game_screen_size()
	for &item in session.item_pool.items {
		def := items.by_kind[item.kind]

		// TODO: Extract into item_update
		switch item.state {
		case .Inactive:
			continue
		case .Falling:
			item.y += item.speed * dt

			if item_is_good(def) && session.effects.good_catch_magnet > 1 {
				dir := session.player.x - item.x
				item.x += dir * session.effects.good_catch_magnet * dt
			}

			// Item leaves
			if item.y + item.height / 2 > screen.y {
				item_remove(&session.item_pool, &item)
				if item_is_good(def) {
					// TODO: Consider different sound
					k2.play_sound(sounds_config.catch_bad)
					session.lives -= 1
					session.combo = 0
				}
				// TODO: We should give user a chance to pick up almost remove item?
				continue
			}

			// Item caught
			switch effect in def.effect {
			case GoodItemCaught:
				if (has_collision(session.player, item, session.effects.good_catch_margin)) {
					k2.play_sound(sounds_config.catch_good)
					multiplier := get_multiplier(session.effects, session.combo, item.kind)
					// TODO: We should pass something closer to collision's x,y
					floating_text_spawn(
						&session.effects.floating_texts,
						{session.player.x + session.player.width / 2, session.player.y - 10},
						effect.points,
						multiplier,
					)
					item_remove(&session.item_pool, &item)
					session.score += effect.points * multiplier
					session.combo += 1
					continue
				}
			case BadItemCaught:
				if (has_collision(session.player, item)) {
					k2.play_sound(sounds_config.catch_bad)
					item_remove(&session.item_pool, &item)
					session.effects.shake_is_active = true
					session.lives -= 1
					session.combo = 0
					continue
				}
			}

		case .Flashing:
			item.flashing_elapsed += dt
			if item.flashing_elapsed > effect_config.flashing_lifetime {
				item.state = .Inactive
			}
		}
	}
}

has_collision :: proc(player: Player, item: Item, margin: f32 = 0) -> bool {
	player_box := k2.rect_from_pos_size({player.x, player.y}, {player.width, player.height})
	// TODO: What if item is a circle? Does it matter much?
	item_box := k2.rect_from_pos_size({item.x, item.y}, {item.width, item.height})
	return k2.rect_overlapping(player_box, k2.rect_expand(item_box, margin, margin))
}

game_draw :: proc(config: GameConfig, session: Session) {
	screen := game_screen_size()

	game_background_draw(config.background)
	player_draw(session.player, config.player)
	for &item in session.item_pool.items {
		item_draw(config.effects, config.items[item.kind], session.effects, item)}
	effects_draw(session.effects)

	// TODO: ugly mess (lives should be hearts on the right, score should go to the left? or center?)
	k2.draw_text(fmt.tprintf("Lives: %d", session.lives), {screen.x - 150, 10}, 20, k2.GRAY)
	k2.draw_text(fmt.tprintf("Score: %d", session.score), {screen.x - 150, 30}, 20, k2.GRAY)

	multiplier := get_combo_multiplier(session.combo)
	combo :=
		fmt.tprintf("Combo: %d x%d", session.combo, multiplier) if multiplier > 1 else fmt.tprintf("Combo: %d", session.combo)
	k2.draw_text(combo, {screen.x - 150, 50}, 20, k2.GRAY)
}

game_background_draw :: proc(config: BackgroundConfig) {
	screen := game_screen_size()
	size := config.size

	cols := int(screen.x / size) + 1
	rows := int(screen.y / size) + 1

	for row in 0 ..< rows {
		y := screen.y - size - f32(row) * size
		texture := config.floor if row == 0 else config.wall
		for x in 0 ..< cols {
			rect := k2.Rect {
				x = f32(x) * size,
				y = y,
				w = size,
				h = size,
			}
			k2.draw_texture_fit(texture, k2.get_texture_rect(texture), rect)
		}
	}

	// TODO: Just mock, (pre)generate random positions
	for i in 1 ..= 3 {
		window_rect := k2.Rect {
			x = f32(300 * i),
			y = f32(100 * i),
			w = size,
			h = size,
		}

		k2.draw_texture_fit(config.window, k2.get_texture_rect(config.window), window_rect)
	}

}
