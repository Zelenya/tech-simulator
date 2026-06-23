package game

import k2 "../karl2d"

Player :: struct {
	x, y:          f32,
	width, height: f32,
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
	}
}

player_update :: proc(config: PlayerConfig, player: ^Player, dt: f32) {
	screen := game_screen_size()
	mouse := game_mouse_position()
	mouse_delta := k2.get_mouse_delta()
	if mouse_delta.x != 0 do player.x = mouse.x - config.width / 2
	if k2.key_is_held(.Left) do player.x -= config.speed * dt
	if k2.key_is_held(.Right) do player.x += config.speed * dt
	player.x = clamp(player.x, 0, screen.x - config.width)
}

player_draw :: proc(player: Player, config: PlayerConfig) {
	player_box := k2.Rect {
		x = player.x,
		y = player.y,
		w = player.width,
		h = player.height,
	}
	// k2.draw_rect_outline(player_box, 1, k2.RED) // test hit box
	k2.draw_texture_fit(config.sprite, k2.get_texture_rect(config.sprite), player_box)
}
