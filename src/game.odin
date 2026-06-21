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
	player:             Player,
	item_pool:          ItemPool,
	// TODO: Needs to have a better pool
	floating_text_pool: [16]FloatingText,
	score:              u32,
	// just in case we go below 0
	lives:              i8,
	current_wave:       u8,
	wave_timer:         f32,
	waves:              [5]Wave,
	// to be more forgiving and flexible with good catches
	good_catch_margin:  f32,
}

Wave :: struct {
	spawn_multiplier: f32,
	speed_multiplier: f32,
	duration:         f32,
}

game_init :: proc(difficulty: Difficulty) -> Session {
	settings := set_difficulty(difficulty)
	waves := [5]Wave {
		{spawn_multiplier = 1.0, speed_multiplier = 1.0, duration = 10},
		{spawn_multiplier = 0.8, speed_multiplier = 1.5, duration = 10},
		{spawn_multiplier = 0.8, speed_multiplier = 1.5, duration = 20},
		{spawn_multiplier = 0.8, speed_multiplier = 1.5, duration = 20},
		{spawn_multiplier = 0.8, speed_multiplier = 1.5, duration = 20},
	}

	return Session {
		player             = player_init(),
		item_pool          = item_pool_init(
			settings.max_active,
			settings.item_speed,
			settings.spawn_interval,
		),
		floating_text_pool = floating_text_init(),
		score              = 0,
		lives              = cast(i8)settings.lives,
		current_wave       = 0,
		wave_timer         = 0,
		waves              = waves,
		// TODO: Make it part of difficulty too?
		good_catch_margin  = 0,
	}
}

game_update :: proc(session: ^Session, dt: f32) -> GameState {
	screen := k2.get_screen_size()

	session.wave_timer += dt
	// Make progress (clamp it to X waves to be reasonable... for now)
	if session.wave_timer > session.waves[session.current_wave].duration &&
	   session.current_wave < len(session.waves) {
		return .ModifierPick
	}

	player_update(&session.player, dt)
	floating_text_pool_update(&session.floating_text_pool, dt)
	player_draw(session.player)

	item_pool_spawn(&session.item_pool, screen.x, dt)
	score_delta, lives_delta := item_pool_update(
		&session.item_pool,
		&session.floating_text_pool,
		session.player,
		good_catch_margin = session.good_catch_margin,
		dt = dt,
	)
	session.score += score_delta
	session.lives += lives_delta

	if session.lives <= 0 {return .GameOver} else {return .Playing}
}

// TODO: This doesn't feel right, this should be split by "domain"
// TODO: With effects even worse now, need to refactor
item_pool_update :: proc(
	item_pool: ^ItemPool,
	floating_text_pool: ^[16]FloatingText,
	player: Player,
	good_catch_margin: f32,
	dt: f32,
) -> (
	score_delta: u32,
	lives_delta: i8,
) {
	screen := k2.get_screen_size()
	for &item in item_pool.items {
		if !item.active do continue

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
					floating_text_pool,
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
				lives_delta -= 1
			}
		}


		item_draw(item)
		effects_draw(floating_text_pool)
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

// TODO: Not cleaned (need proper pool and reuse later?)
item_remove :: proc(pool: ^ItemPool, item: ^Item) {
	item.active = false
	pool.currently_active -= 1
}

game_draw :: proc(session: Session) {
	screen := k2.get_screen_size()

	k2.draw_text(fmt.tprintf("Score: %d", session.score), {screen.x - 100, 10}, 20, k2.GRAY)
	k2.draw_text(fmt.tprintf("Lives: %d", session.lives), {screen.x - 100, 30}, 20, k2.GRAY)
}
