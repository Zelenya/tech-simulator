package game

import k2 "../karl2d"
import "core:fmt"

GameState :: enum {
	Title,
	Playing,
	ModifierPick,
	GameOver,
}

Session :: struct {
	player:            Player,
	item_pool:         ItemPool,
	effects:           Effects,
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

	session.wave_timer += dt
	// Make progress (clamp it to X waves to be reasonable... for now)
	if session.wave_timer > config.waves[session.current_wave].duration &&
	   session.current_wave < len(config.waves) - 1 {
		return .ModifierPick
	}

	player_update(config.player, &session.player, dt)
	item_pool_spawn(config, &session.item_pool, screen.x, dt)
	score_delta, lives_delta := item_pool_update(
		config.effects,
		&session.item_pool,
		config.items,
		&session.effects,
		session.player,
		good_catch_margin = session.good_catch_margin,
		dt = dt,
	)
	effects_update(&session.effects, dt)
	session.score += score_delta
	session.lives += lives_delta

	if session.lives <= 0 {return .GameOver} else {return .Playing}
}

// TODO: This doesn't feel right, this should be inline and/or split by "domain"
// TODO: With effects even worse now, need to refactor
item_pool_update :: proc(
	effect_config: EffectsConfig,
	item_pool: ^ItemPool,
	items: ItemCatalog,
	effects: ^Effects,
	player: Player,
	good_catch_margin: f32,
	dt: f32,
) -> (
	score_delta: u32,
	lives_delta: i8,
) {
	screen := game_screen_size()
	for &item in item_pool.items {
		def := items.by_kind[item.kind]

		// TODO: Extract into item_update
		switch item.state {
		case .Inactive:
			continue
		case .Falling:
			item.y += item.speed * dt

			// Item leaves
			if item.y + item.height / 2 > screen.y {
				item_remove(item_pool, &item)
				if item_is_good(def) {
					lives_delta -= 1
				}
				// TODO: We should give user a chance to pick up almost remove item?
				continue
			}

			// Item caught
			switch effect in def.effect {
			case GoodItemCaught:
				if (has_collision(player, item, good_catch_margin)) {
					// TODO: We should pass something closer to collision's x,y
					floating_text_spawn(
						&effects.floating_texts,
						player.x + player.width / 2,
						player.y - 10,
						fmt.tprintf("+%d", effect.points),
					)
					item_remove(item_pool, &item)
					score_delta += effect.points
					continue
				}
			case BadItemCaught:
				if (has_collision(player, item)) {
					item_remove(item_pool, &item)
					effects.shake_is_active = true
					lives_delta -= 1
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
	return score_delta, lives_delta
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
	for &item in session.item_pool.items do item_draw(config.effects, config.items.by_kind[item.kind], item)
	effects_draw(session.effects)

	k2.draw_text(fmt.tprintf("Score: %d", session.score), {screen.x - 100, 10}, 20, k2.GRAY)
	k2.draw_text(fmt.tprintf("Lives: %d", session.lives), {screen.x - 100, 30}, 20, k2.GRAY)
}
