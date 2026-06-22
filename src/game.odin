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
	current_wave:      u8,
	wave_timer:        f32,
	waves:             [5]Wave,
	// to be more forgiving and flexible with good catches
	good_catch_margin: f32,
}

Wave :: struct {
	spawn_multiplier: f32,
	speed_multiplier: f32,
	duration:         f32,
}

game_init :: proc(difficulty: Difficulty) -> Session {
	settings := set_difficulty(difficulty)
	waves := [5]Wave {
		{spawn_multiplier = 1.0, speed_multiplier = 1.0, duration = 30},
		{spawn_multiplier = 0.8, speed_multiplier = 1.2, duration = 30},
		{spawn_multiplier = 0.8, speed_multiplier = 1.2, duration = 60},
		{spawn_multiplier = 0.8, speed_multiplier = 1.2, duration = 60},
		{spawn_multiplier = 0.8, speed_multiplier = 1.2, duration = 60},
	}

	return Session {
		player            = player_init(),
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
		waves             = waves,
		// TODO: Make it part of the difficulty too?
		good_catch_margin = 0,
	}
}

game_update :: proc(session: ^Session, dt: f32) -> GameState {
	screen := game_screen_size()

	session.wave_timer += dt
	// Make progress (clamp it to X waves to be reasonable... for now)
	if session.wave_timer > session.waves[session.current_wave].duration &&
	   session.current_wave < len(session.waves) {
		return .ModifierPick
	}

	player_update(&session.player, dt)
	item_pool_spawn(&session.item_pool, screen.x, dt)
	score_delta, lives_delta := item_pool_update(
		&session.item_pool,
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
	item_pool: ^ItemPool,
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
		// TODO: Extract into item_update
		switch item.state {
		case .Inactive:
			continue
		case .Falling:
			item.y += item.speed * dt

			// Item leaves
			if item.y + item.height / 2 > screen.y {
				item_remove(item_pool, &item)
				if _, ok := item.type.(GoodItemDef); ok {
					lives_delta -= 1
				}
			}

			// Item caught
			switch def in item.type {
			case GoodItemDef:
				if (has_collision(player, item, good_catch_margin)) {
					// TODO: We should pass something closer to collision's x,y
					floating_text_spawn(
						&effects.floating_texts,
						player.x + player.width / 2,
						player.y - 10,
						fmt.tprintf("+%d", def.points),
					)
					item_remove(item_pool, &item)
					score_delta += def.points
				}
			case BadItemDef:
				if (has_collision(player, item)) {
					item_remove(item_pool, &item)
					effects.shake_is_active = true
					lives_delta -= 1
				}
			}

		case .Flashing:
			item.flashing_elapsed += dt
			if item.flashing_elapsed > FLASHING_LIFETIME {
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

game_draw :: proc(session: Session, textures: Textures) {
	screen := game_screen_size()

	player_draw(session.player, textures.player)
	for &item in session.item_pool.items do item_draw(item, textures)
	effects_draw(session.effects)

	k2.draw_text(fmt.tprintf("Score: %d", session.score), {screen.x - 100, 10}, 20, k2.GRAY)
	k2.draw_text(fmt.tprintf("Lives: %d", session.lives), {screen.x - 100, 30}, 20, k2.GRAY)
}
