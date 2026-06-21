package game

import k2 "../karl2d"
// import "core:fmt"

FLOATING_TEXT_LIFETIME: f32 : 1

// TODO: Might need to do floating hearts too
FloatingText :: struct {
	x, y:    f32,
	text:    string,
	elapsed: f32,
	active:  bool,
}

// TODO: Also needs better pools
floating_text_init :: proc() -> [16]FloatingText {
	empty: [16]FloatingText
	return empty
}

// TODO: Currently, if we get more than 16 notifications, we won't show anything (ok for now)
floating_text_pool_update :: proc(floating_text_pool: ^[16]FloatingText, dt: f32) {
	for &text in floating_text_pool {
		if text.active {
			text.elapsed += dt
			text.y -= 10 * dt
			if text.elapsed > FLOATING_TEXT_LIFETIME do text.active = false
		}
	}
}

// TODO: Currently, if we get more than 16 notifications, we won't show anything (ok for now)
floating_text_spawn :: proc(floating_text_pool: ^[16]FloatingText, x, y: f32, text: string) {
	for &spot in floating_text_pool {
		if !spot.active {
			spot.x = x
			spot.y = y
			spot.text = text
			spot.elapsed = 0
			spot.active = true
			return
		}
	}
}

floating_text_draw :: proc(floating_text: FloatingText) {
	text_width := k2.measure_text(floating_text.text, 20).x
	text_x := floating_text.x - (text_width / 2)

	alpha := 1.0 - floating_text.elapsed / FLOATING_TEXT_LIFETIME
	faded_green := k2.GREEN
	faded_green[3] = u8(alpha * 255)

	k2.draw_text(floating_text.text, {text_x, floating_text.y}, 20, faded_green)
}

// This name is half generalized, so I don't forget what I want later
effects_draw :: proc(floating_text_pool: ^[16]FloatingText) {
	for text in floating_text_pool {
		if text.active do floating_text_draw(text)
	}
}
