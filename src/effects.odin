package game

import k2 "../karl2d"
import "core:math/rand"

Effects :: struct {
	shake_is_active:   bool,
	shake_elapsed:     f32,
	floating_texts:    [16]FloatingText,
	score_base:        u32,
	preference:        Maybe(ItemKind),
	good_catch_magnet: f32,
	// TODO: Make it part of the difficulty too?
	good_catch_margin: f32,
}

// TODO: Also needs better pools
effects_init :: proc() -> Effects {
	empty: [16]FloatingText
	return Effects {
		shake_is_active = false,
		shake_elapsed = 0,
		score_base = 1,
		floating_texts = empty,
		preference = nil,
		good_catch_magnet = 1,
		good_catch_margin = 1,
	}
}

effects_update :: proc(effects: ^Effects, dt: f32) {
	floating_text_pool_update(&effects.floating_texts, dt)
	shake_update(effects, dt)
}

effects_reset :: proc(effects: Effects) {
	if effects.shake_is_active {
		k2.set_camera(nil)
	}
}

effects_draw :: proc(effects: Effects) {
	for text in effects.floating_texts {
		if text.active do floating_text_draw(text)
	}
}

get_multiplier :: proc(effects: Effects, combo: u32, item_kind: ItemKind) -> u32 {
	// TODO: Move this to config and/or play with formulas
	item_multiplier: u32 = 2 if effects.preference == item_kind else 1
	return effects.score_base * item_multiplier * get_combo_multiplier(combo)
}

// TODO: Move this to config and/or play with formulas
get_combo_multiplier :: proc(combo: u32) -> u32 {
	return 1.0 + combo / 10
}

// TODO: Add to config
FLOATING_TEXT_LIFETIME: f32 : 1

// TODO: Might need to do floating hearts too
FloatingText :: struct {
	x, y:    f32,
	text:    string,
	elapsed: f32,
	active:  bool,
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

// TODO: Pass the score as int or something and use it to manipulate the size (and color)
floating_text_draw :: proc(floating_text: FloatingText) {
	text_width := k2.measure_text(floating_text.text, 20).x
	text_x := floating_text.x - (text_width / 2)

	alpha := 1.0 - floating_text.elapsed / FLOATING_TEXT_LIFETIME
	faded_green := k2.GREEN
	faded_green[3] = u8(alpha * 255)

	k2.draw_text(floating_text.text, {text_x, floating_text.y}, 20, faded_green)
}

SHAKE_DURATION: f32 : 0.5
SHAKE_STRENGTH: f32 : 10

shake_update :: proc(effects: ^Effects, dt: f32) {
	if effects.shake_is_active {
		effects.shake_elapsed += dt
		if effects.shake_elapsed >= SHAKE_DURATION {
			effects.shake_is_active = false
			effects.shake_elapsed = 0
		}

		offset := shake_offset(effects^)
		set_game_camera(offset)
	}
}

shake_offset :: proc(effects: Effects) -> k2.Vec2 {
	if !effects.shake_is_active do return {0, 0}
	t := effects.shake_elapsed / SHAKE_DURATION
	strength := SHAKE_STRENGTH * (1.0 - t)
	return {rand.float32_range(-strength, strength), rand.float32_range(-strength, strength)}
}
