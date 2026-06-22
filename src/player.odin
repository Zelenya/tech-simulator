package game

import k2 "../karl2d"

PLAYER_WIDTH: f32 : 32 * 3
PLAYER_HEIGHT: f32 : 42 * 3
PLAYER_SPEED: f32 : 1000

Player :: struct {
	x, y:          f32,
	width, height: f32,
	// TODO
	// hitbox_offset: k2.Vec2,
	// hitbox_size:   k2.Vec2,
}

player_init :: proc() -> Player {
	screen := game_screen_size()
	return Player {
		x = screen.x / 2 - PLAYER_WIDTH / 2,
		y = screen.y - PLAYER_HEIGHT - 8,
		width = PLAYER_WIDTH,
		height = PLAYER_HEIGHT,
	}
}

player_update :: proc(player: ^Player, dt: f32) {
	screen := game_screen_size()
	mouse := game_mouse_position()
	mouse_delta := k2.get_mouse_delta()
	if mouse_delta.x != 0 do player.x = mouse.x - PLAYER_WIDTH / 2
	if k2.key_is_held(.Left) do player.x -= PLAYER_SPEED * dt
	if k2.key_is_held(.Right) do player.x += PLAYER_SPEED * dt
	player.x = clamp(player.x, 0, screen.x - PLAYER_WIDTH)
}

player_draw :: proc(player: Player, texture: k2.Texture) {
	player_box := k2.Rect {
		x = player.x,
		y = player.y,
		w = player.width,
		h = player.height,
	}
	// k2.draw_rect_outline(player_box, 1, k2.RED) // test hit box
	k2.draw_texture_fit(texture, k2.get_texture_rect(texture), player_box)
}
