package game

import k2 "../karl2d"
import "core:fmt"

GameState :: enum {
	Title,
	Playing,
	ModifierPick,
	Pause,
	GameOver,
}

Session :: struct {
	player:            Player,
	item_pool:         ItemPool,
	effects:           Effects,
	combo:             u32,
	score:             u32,
	// just in case we go below 0
	lives:             i8,
	current_wave:      int,
	wave_timer:        f32,
	// to be more forgiving and flexible with good catches
	good_catch_margin: f32,
}

game_init :: proc(config: GameConfig, difficulty: Difficulty) -> Session {
	settings := set_difficulty(difficulty)

	return Session {
		player            = player_init(config.player),
		item_pool         = item_pool_init(
			settings.max_active,
			settings.item_speed,
			settings.spawn_interval,
		),
		effects           = effects_init(),
		combo             = 0,
		score             = 0,
		lives             = cast(i8)settings.lives,
		current_wave      = 0,
		wave_timer        = 0,
		// TODO: Make it part of the difficulty too?
		good_catch_margin = 0,
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
	item_pool_spawn(config, &session.item_pool, screen.x, dt)
	item_pool_update(
		config.effects,
		session,
		config.items,
		good_catch_margin = session.good_catch_margin,
		dt = dt,
	)
	effects_update(&session.effects, dt)

	if session.lives <= 0 {return .GameOver} else {return .Playing}
}

// TODO: This doesn't feel right, this should be inline and/or split by "domain"
// TODO: With effects even worse now, need to refactor
item_pool_update :: proc(
	effect_config: EffectsConfig,
	session: ^Session,
	items: ItemCatalog,
	good_catch_margin: f32,
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

			// Item leaves
			if item.y + item.height / 2 > screen.y {
				item_remove(&session.item_pool, &item)
				if item_is_good(def) {
					session.lives -= 1
					session.combo = 0
				}
				// TODO: We should give user a chance to pick up almost remove item?
				continue
			}

			// Item caught
			switch effect in def.effect {
			case GoodItemCaught:
				if (has_collision(session.player, item, good_catch_margin)) {
					multiplier := get_multiplier(session.effects, session.combo, item.kind)
					text :=
						fmt.tprintf("+%d", effect.points) if multiplier == 1 else fmt.tprintf("+%d x%d", effect.points, int(multiplier))
					// TODO: We should pass something closer to collision's x,y
					floating_text_spawn(
						&session.effects.floating_texts,
						session.player.x + session.player.width / 2,
						session.player.y - 10,
						text,
					)
					item_remove(&session.item_pool, &item)
					session.score += effect.points * multiplier
					session.combo += 1
					continue
				}
			case BadItemCaught:
				if (has_collision(session.player, item)) {
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

// TODO: Use built-in functions
has_collision :: proc(player: Player, item: Item, margin: f32 = 0) -> bool {
	return(
		item.x - margin < player.x + player.width &&
		item.x + item.width + margin > player.x &&
		item.y - margin < player.y + player.height &&
		item.y + item.height + margin > player.y \
	)
}

game_draw :: proc(config: GameConfig, session: Session) {
	screen := game_screen_size()

	player_draw(session.player, config.player)
	for &item in session.item_pool.items do item_draw(config.effects, session.effects, config.items.by_kind[item.kind], item)
	effects_draw(session.effects)

	// TODO: ugly mess (lives should be hearts on the right, score should go to the left? or center?)
	k2.draw_text(fmt.tprintf("Lives: %d", session.lives), {screen.x - 150, 10}, 20, k2.GRAY)
	k2.draw_text(fmt.tprintf("Score: %d", session.score), {screen.x - 150, 30}, 20, k2.GRAY)

	multiplier := get_combo_multiplier(session.combo)
	combo :=
		fmt.tprintf("Combo: %d x%d", session.combo, multiplier) if multiplier > 1 else fmt.tprintf("Combo: %d", session.combo)
	k2.draw_text(combo, {screen.x - 150, 50}, 20, k2.GRAY)
}
