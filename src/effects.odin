package game

import k2 "../karl2d"
import "base:runtime"
import "core:fmt"
import "core:math/rand"

Effects :: struct {
	shake_is_active:   bool,
	shake_elapsed:     f32,
	flash_color:       Maybe(k2.Color),
	flash_timer:       f32,
	floating_texts:    [16]FloatingText,
	particle_pool:     []Particle,
	score_base:        u32,
	preference:        Maybe(ItemKind),
	good_catch_magnet: f32,
	// TODO: Make it part of the difficulty too?
	good_catch_margin: f32,
}

// TODO: Also needs better pools
effects_init :: proc(allocator: runtime.Allocator, config: EffectsConfig) -> Effects {
	empty: [16]FloatingText
	// TODO: Pass active from difficulty config
	max_particles := 5 * config.particle_count

	return Effects {
		shake_is_active = false,
		shake_elapsed = 0,
		flash_color = nil,
		flash_timer = 0,
		score_base = 1,
		floating_texts = empty,
		particle_pool = make([]Particle, max_particles, allocator),
		preference = nil,
		good_catch_magnet = 1,
		good_catch_margin = 1,
	}
}

// TODO: Not sure if catching bad should have same effect as missing good (v2 is for this)
effects_set_hit :: proc(config: EffectsConfig, effects: ^Effects, v2: bool) {
	effects.shake_is_active = true
	effects.flash_color = k2.YELLOW if v2 else k2.RED
	effects.flash_timer = config.full_flash_duration
}

effects_update :: proc(effects: ^Effects, dt: f32) {
	floating_text_pool_update(&effects.floating_texts, dt)
	flash_update(effects, dt)
	particle_pool_update(&effects.particle_pool, dt)
	shake_update(effects, dt)
}

effects_reset :: proc(effects: Effects) {
	if effects.shake_is_active {
		k2.set_camera(nil)
	}
}

effects_draw :: proc(effects: Effects) {
	flash_draw(effects)
	for text in effects.floating_texts {
		if text.active do floating_text_draw(text)
	}

	for particle in effects.particle_pool {
		if particle.active do particle_draw(particle)
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
	x, y:       f32,
	points:     u32,
	multiplier: u32,
	elapsed:    f32,
	active:     bool,
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
floating_text_spawn :: proc(
	floating_text_pool: ^[16]FloatingText,
	pos: k2.Vec2,
	points: u32,
	multiplier: u32,
) {
	for &spot in floating_text_pool {
		if !spot.active {
			spot.x = pos.x
			spot.y = pos.y
			spot.points = points
			spot.multiplier = multiplier
			spot.elapsed = 0
			spot.active = true
			return
		}
	}
}

// TODO: Pass the score as int or something and use it to manipulate the size (and color)
floating_text_draw :: proc(floating_text: FloatingText) {
	text: string
	if floating_text.multiplier == 1 {
		text = fmt.tprintf("+%d", floating_text.points)
	} else {
		text = fmt.tprintf("+%d x%d", floating_text.points, floating_text.multiplier)
	}

	text_width := k2.measure_text(text, 20).x
	text_x := floating_text.x - (text_width / 2)

	alpha := 1.0 - floating_text.elapsed / FLOATING_TEXT_LIFETIME
	faded_green := k2.GREEN
	faded_green[3] = u8(alpha * 255)

	k2.draw_text(text, {text_x, floating_text.y}, 20, faded_green)
}

flash_update :: proc(effects: ^Effects, dt: f32) {
	if effects.flash_color != nil {
		effects.flash_timer -= dt
		if effects.flash_timer <= 0 do effects.flash_color = nil
	}
}

flash_draw :: proc(effects: Effects) {
	if flash_color, is_flashing := effects.flash_color.?; is_flashing {
		screen := game_screen_size()
		k2.draw_rect_vec({0, 0}, screen, flash_color)
	}
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

Particle :: struct {
	x, y:     f32,
	vx, vy:   f32,
	size:     f32,
	lifetime: f32,
	elapsed:  f32,
	active:   bool,
	color:    k2.Color,
}

particle_pool_update :: proc(particle_pool: ^[]Particle, dt: f32) {
	for &particle in particle_pool {
		if particle.active {
			particle.elapsed += dt
			particle.x += particle.vx * dt
			particle.y += particle.vy * dt
			if particle.elapsed > particle.lifetime do particle.active = false
		}
	}
}

particles_spawn :: proc(config: EffectsConfig, particle_pool: ^[]Particle, pos: k2.Vec2) {
	for _ in 0 ..< config.particle_count do particles_spawn_one(config, particle_pool, pos)
}

// TODO: play with colors and effects
// Catching a good item: green/white, pop upward
// Catching a bad item: red/white, sharper burst
// Missing a good item: yellow/orange floor impact puff + sidway-bouncing bits
particles_spawn_one :: proc(config: EffectsConfig, particle_pool: ^[]Particle, pos: k2.Vec2) {
	for &spot in particle_pool {
		if !spot.active {
			spot.x = pos.x
			spot.y = pos.y
			spot.vx = rand.float32_range(-config.particle_speed, config.particle_speed)
			spot.vy = rand.float32_range(-config.particle_speed, config.particle_speed)
			spot.lifetime = rand.float32_range(
				0.2 * config.particle_lifetime,
				config.particle_lifetime,
			)
			spot.elapsed = 0
			spot.active = true
			spot.color = k2.WHITE // TODO: Should the color be random? should it fade out?
			spot.size = rand.float32_range(0, config.particle_size)
			return
		}
	}
}

particle_draw :: proc(particle: Particle) {
	k2.draw_rect({particle.x, particle.y, particle.size, particle.size}, particle.color)
}
