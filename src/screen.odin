package game

import k2 "../karl2d"

WINDOW_WIDTH :: 1280
WINDOW_HEIGHT :: 720

// TODO: Should I have those in consts/vars?
game_screen_size :: proc() -> k2.Vec2 {
	return k2.get_screen_size() / k2.get_window_scale()
}

game_camera :: proc(target: k2.Vec2 = {}) -> k2.Camera {
	return k2.Camera{target = target, offset = {}, rotation = 0, zoom = k2.get_window_scale()}
}

set_game_camera :: proc(target: k2.Vec2 = {}) {
	k2.set_camera(game_camera(target))
}

game_mouse_position :: proc() -> k2.Vec2 {
	return k2.screen_to_world(k2.get_mouse_position(), game_camera())
}
