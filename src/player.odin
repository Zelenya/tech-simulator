package game

import k2 "../karl2d"

PLAYER_WIDTH: f32 : 100
PLAYER_HEIGHT: f32 : 100
PLAYER_SPEED: f32 : 1000

Player :: struct {
	x, y:          f32,
	width, height: f32,
}

player_init :: proc() -> Player {
	screen := k2.get_screen_size()
	return Player {
		x = screen.x / 2 - PLAYER_WIDTH / 2,
		y = screen.y - PLAYER_HEIGHT - 8,
		width = PLAYER_WIDTH,
		height = PLAYER_HEIGHT,
	}
}

player_update :: proc(player: ^Player, dt: f32) {
	screen := k2.get_screen_size()
	mouse := k2.get_mouse_position()
	mouse_delta := k2.get_mouse_delta()
	if mouse_delta.x != 0 do player.x = mouse.x - PLAYER_WIDTH / 2
	if k2.key_is_held(.Left) do player.x -= PLAYER_SPEED * dt
	if k2.key_is_held(.Right) do player.x += PLAYER_SPEED * dt
	player.x = clamp(player.x, 0, screen.x - PLAYER_WIDTH)
}

player_draw :: proc(player: Player) {
	player_box := k2.Rect {
		x = player.x,
		y = player.y,
		w = player.width,
		h = player.height,
	}
	k2.draw_rect(player_box, k2.GRAY)
}
