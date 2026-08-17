package game

import k2 "../karl2d"
import "base:runtime"
import "core:fmt"

GameState :: enum {
	WaveMenu,
	Playing,
	Pause,
	GameOver,
}

GameRules :: struct {
	good_catch_magnet: f32,
	good_catch_margin: f32,
	item_preference:   Maybe(ItemKind),
	item_movement:     ItemMovement,
	item_speed:        f32,
	score_base:        u32,
	show_score:        bool,
	item_spawn_hidden: bool,
	final_mode:        bool,
}

game_rules_init :: proc(item_speed: f32) -> GameRules {
	return GameRules {
		good_catch_magnet = 1,
		good_catch_margin = 1,
		item_preference = nil,
		item_movement = .Normal,
		item_speed = item_speed,
		score_base = 1,
		show_score = true,
		item_spawn_hidden = false,
		final_mode = false,
	}
}

game_rules_rebuild :: proc(
	config: GameConfig,
	difficulty: Difficulty,
	modifier_picks: []ModifierKind,
) -> GameRules {
	assert(len(modifier_picks) < len(config.waves))

	rules := game_rules_init(config.difficulties[difficulty].item_speed)

	for modifier, i in modifier_picks {
		rules.item_speed *= config.waves[i + 1].speed_multiplier
		modifier_apply_rules(config, &rules, modifier)
	}

	return rules
}

get_multiplier :: proc(rules: GameRules, combo: u32, item_kind: ItemKind) -> u32 {
	// TODO: Move this to config and/or play with formulas
	item_multiplier: u32 = 2 if rules.item_preference == item_kind else 1
	return rules.score_base * item_multiplier * get_combo_multiplier(combo)
}

// TODO: Move this to config and/or play with formulas
get_combo_multiplier :: proc(combo: u32) -> u32 {
	return 1.0 + combo / 10
}

Session :: struct {
	player:         Player,
	item_catalog:   ItemCatalog,
	item_pool:      ItemPool,
	rules:          GameRules,
	modifiers:      ModifierSystem,
	difficulty:     Difficulty,
	modifier_picks: [dynamic]ModifierKind,
	effects:        Effects,
	combo:          u32,
	score:          u32,
	// just in case we go below 0
	lives:          i8,
	current_wave:   int,
	wave_timer:     f32,
}

game_init :: proc(
	allocator: runtime.Allocator,
	config: GameConfig,
	difficulty: Difficulty,
) -> Session {
	settings := config.difficulties[difficulty]

	return Session {
		player         = player_init(config.player),
		item_catalog   = item_catalog_init(allocator, config.items, config.item_pool),
		item_pool      = item_pool_init(
			allocator,
			settings.max_active,
			config.item_pool.hard_cap,
			settings.spawn_interval,
		),
		// TODO: pass and refactor more basic things from config
		rules          = game_rules_init(settings.item_speed),
		modifiers      = modifier_system_init(allocator),
		difficulty     = difficulty,
		// TODO: Max is number of waves
		modifier_picks = make([dynamic]ModifierKind, 0, 5, allocator),
		effects        = effects_init(allocator, config.effects),
		combo          = 0,
		score          = 0,
		lives          = cast(i8)settings.lives,
		current_wave   = 0,
		wave_timer     = 0,
	}
}

// TODO: Introduce events for catch items, etc. to make this manageable
game_update :: proc(config: GameConfig, session: ^Session, dt: f32) -> GameState {
	screen := game_screen_size()

	if k2.key_went_down(.Escape) do return GameState.Pause

	session.wave_timer += dt
	// Make progress (clamp it to X waves to be reasonable... for now)
	if session.wave_timer > config.waves[session.current_wave].duration &&
	   session.current_wave < len(config.waves) - 1 {
		return .WaveMenu
	}

	player_update_movement(config.player, &session.player, dt)

	item_pool_update_spawn(
		config,
		session.rules,
		session.item_catalog,
		&session.item_pool,
		screen.x,
		dt,
	)

	i := 0
	// TODO: it's ok, but could be cleaned up
	caught := false
	for i < len(session.item_pool.items) {
		item := &session.item_pool.items[i]
		def := session.item_catalog.by_kind[item.kind]

		item_update(session, item, def, dt)

		// Item can be caught
		_, is_good := def.effect.(GoodItemCaught)
		collision_margin := session.rules.good_catch_margin if is_good else 0
		is_colliding := has_collision(session.player, item^, collision_margin)
		// Item can be leaving the screen
		is_offscreen := item.y + item.height / 2 > screen.y
		// Reconciliate into a terminal state/outcome
		outcome, is_terminal := item_outcome(item^, def.effect, is_colliding, is_offscreen).?
		if !is_terminal {
			i += 1
			continue
		}

		removed := item_pool_remove_at(&session.item_pool, i)
		item_flash_spawn(&session.effects, removed)

		switch outcome.kind {
		case .CaughtGood:
			k2.play_sound(config.sounds.by_kind[.CatchGood])
			multiplier := get_multiplier(session.rules, session.combo, removed.kind)
			// TODO: We should pass something closer to collision's x,y
			floating_text_spawn(
				&session.effects.floating_texts,
				{session.player.x + session.player.width / 2, session.player.y - 10},
				outcome.base_points,
				multiplier,
			)
			session.score += outcome.base_points * multiplier
			session.combo += 1
			caught = true
			modifiers_on_good_item_caught(config.modifier_effects, &session.modifiers)

		case .CaughtBad:
			k2.play_sound(config.sounds.by_kind[.CatchBad])
			// TODO: Improve position passing (maybe trigger particles somewhere else)
			particles_spawn(config.effects, &session.effects.particle_pool, {removed.x, removed.y})
			if !modifier_is_active(session^, .GiveUp) {
				effects_set_hit(config.effects, &session.effects, v2 = false)
				session.lives -= 1
			}
			session.combo = 0
			caught = true

		case .CaughtNeutral:
			k2.play_sound(config.sounds.by_kind[.CatchDull])
			caught = true

		case .MissedGood:
			// TODO: Also should be event based
			if !modifier_is_active(session^, .GiveUp) {
				effects_set_hit(config.effects, &session.effects, v2 = true)
				// TODO: Consider different sound
				k2.play_sound(config.sounds.by_kind[.CatchBad])
				effects_set_hit(config.effects, &session.effects, v2 = false)
				session.lives -= 1
			}
			session.combo = 0

		case .MissedOther: // No additional effects
		}

		// we removed the element and need to iterate with the same index
		continue
	}


	modifier_system_update(config.effects, config.modifier_effects, session, dt)
	item_pool_spawn_modified(config, session, screen.x)
	// TODO: This could return new location that we can pass down for effects
	player_update_reaction(config.player, &session.player, caught, dt)
	effects_update(config.effects, session.player, &session.effects, dt)

	if session.lives <= 0 {
		k2.play_sound(config.sounds.by_kind[.GameOver])
		return .GameOver
	} else {return .Playing}
}

modifier_is_active :: proc(session: Session, expected: ModifierKind) -> bool {
	for &modifier in session.modifier_picks {
		if modifier == expected do return true
	}
	return false
}

// TODO: Replay the modifier picks?
// TODO: Otherwise we have rules in half-reloaded state
game_reload :: proc(config: GameConfig, session: ^Session) {
	item_catalog_reset_from_config(config.items, config.item_pool, &session.item_catalog)
	item_pool_reset_active(config.item_pool, &session.item_pool)
	session.player = player_init(config.player)
	// in case we remove a wave:
	session.current_wave = min(session.current_wave, len(config.waves) - 1)
}

has_collision :: proc(player: Player, item: Item, margin: f32 = 0) -> bool {
	player_box := k2.rect_from_pos_size({player.x, player.y}, {player.width, player.height})
	// TODO: What if item is a circle? Does it matter much?
	item_box := k2.rect_from_pos_size({item.x, item.y}, {item.width, item.height})
	return k2.rect_overlapping(player_box, k2.rect_expand(item_box, margin, margin))
}

game_draw :: proc(config: GameConfig, session: Session) {
	screen := game_screen_size()

	// all the main elements
	game_background_draw(config.background)
	player_draw(session.player, config.player)
	for &item in session.item_pool.items {
		item_draw(config.effects, config.items[item.kind], session.rules, item, false)}
	effects_draw(config, session.rules, session.effects)

	// lives
	// TODO: Move to the right and draw in other direction
	for i in 1 ..= session.lives {
		rect := k2.Rect {
			x = screen.x - config.hud.margin - f32(i) * (config.hud.lives_width + config.hud.lives_gap),
			y = config.hud.margin,
			w = config.hud.lives_width,
			h = config.hud.lives_height,
		}
		k2.draw_texture_fit(
			config.hud.lives_sprite,
			k2.get_texture_rect(config.hud.lives_sprite),
			rect,
		)
	}

	// TODO: A more fun way to hide score?
	if session.rules.show_score {
		k2.draw_text(
			fmt.tprintf("Score: %d", session.score),
			{config.hud.margin, config.hud.margin},
			20,
			k2.BLACK,
		)
	}

	// TODO: mock visuals (split and prittify)
	multiplier := get_combo_multiplier(session.combo)
	combo :=
		fmt.tprintf("Combo: %d x%d", session.combo, multiplier) if multiplier > 1 else fmt.tprintf("Combo: %d", session.combo)
	k2.draw_text(combo, {config.hud.margin, config.hud.margin + 20}, 20, k2.BLACK)
}

game_background_draw :: proc(config: BackgroundConfig) {
	screen := game_screen_size()
	floor := config.pieces[.Floor]
	wall := config.pieces[.Wall]
	window := config.pieces[.Window]

	floor_cols := int(screen.x / floor.width) + 1
	for x in 0 ..< floor_cols {
		rect := k2.Rect {
			x = f32(x) * floor.width,
			y = screen.y - floor.height,
			w = floor.width,
			h = floor.height,
		}
		k2.draw_texture_fit(floor.sprite, k2.get_texture_rect(floor.sprite), rect)
	}

	wall_cols := int(screen.x / wall.width) + 1
	wall_rows := int((screen.y - floor.height) / wall.height) + 1
	for row in 0 ..< wall_rows {
		y := screen.y - floor.height - wall.height - f32(row) * wall.height
		for x in 0 ..< wall_cols {
			rect := k2.Rect {
				x = f32(x) * wall.width,
				y = y,
				w = wall.width,
				h = wall.height,
			}
			k2.draw_texture_fit(wall.sprite, k2.get_texture_rect(wall.sprite), rect)
		}
	}

	// TODO: Just mock, (pre)generate random positions
	for i in 1 ..= 3 {
		window_rect := k2.Rect {
			x = f32(300 * i),
			y = f32(100 * i),
			w = window.width,
			h = window.height,
		}

		k2.draw_texture_fit(window.sprite, k2.get_texture_rect(window.sprite), window_rect)
	}
}
