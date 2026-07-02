package game

import k2 "../karl2d"

Moving :: enum {
	Idle,
	Left,
	Right,
}

// TODO: not sure if we need those if we use a different frame on catch
SQUASH_SCALE_X: f32 : 1.1
SQUASH_SCALE_Y: f32 : 0.9
SQUASH_TIME: f32 : 0.5

Player :: struct {
	x, y:          f32,
	width, height: f32,
	moving:        Moving,
	facing:        Moving,
	squash_timer:  f32,
	// TODO
	// hitbox_offset: k2.Vec2,
	// hitbox_size:   k2.Vec2,
}

player_init :: proc(config: PlayerConfig) -> Player {
	screen := game_screen_size()
	return Player {
		x = screen.x / 2 - config.width / 2,
		y = screen.y - config.height - 8,
		width = config.width,
		height = config.height,
		facing = .Right,
		squash_timer = 0,
	}
}

player_update :: proc(config: PlayerConfig, player: ^Player, has_caught: bool, dt: f32) {
	screen := game_screen_size()

	if player.squash_timer > 0 do player.squash_timer -= dt
	if has_caught {
		player.squash_timer = SQUASH_TIME
	}

	old_x := player.x
	player.moving = .Idle

	mouse := game_mouse_position()
	mouse_delta := k2.get_mouse_delta()
	if mouse_delta.x != 0 {
		player.x = mouse.x - config.width / 2
	}
	if k2.key_is_held(.Left) {
		player.x -= config.speed * dt
	}
	if k2.key_is_held(.Right) {
		player.x += config.speed * dt
	}
	player.x = clamp(player.x, 0, screen.x - config.width)

	delta_x := player.x - old_x
	if delta_x < -0.1 {
		player.moving = .Left
		player.facing = .Left
	} else if delta_x > 0.1 {
		player.moving = .Right
		player.facing = .Right
	}
}

player_draw :: proc(player: Player, config: PlayerConfig) {
	// scale_x, scale_y := 1.0, 1.0

	player_box := k2.Rect {
		x = player.x,
		y = player.y,
		w = player.width,
		h = player.height,
	}

	// TODO: Proper animation frame
	if player.squash_timer > 0 {
		squashed_h := player_box.h * SQUASH_SCALE_Y
		player_box.y += player_box.h - squashed_h
		player_box.w *= SQUASH_SCALE_X
		player_box.h = squashed_h
	}

	source := k2.get_texture_rect(config.sprite)
	// TODO: Until we have better sprites, that'll do
	if player.facing == .Left do source.w = -source.w

	// k2.draw_rect_outline(player_box, 1, k2.RED) // test hit box
	k2.draw_texture_fit(config.sprite, source, player_box)
}
