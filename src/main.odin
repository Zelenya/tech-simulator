package game

import k2 "../karl2d"

main :: proc() {
	k2.init(WINDOW_WIDTH, WINDOW_HEIGHT, "Greetings!")

	memory: AppMemory
	memory_init(&memory)

	config := game_config_load(memory.config)
	game_state := GameState.Title
	menu := menu_init(config.cards)
	session: Session
	modifier_options: ModifierOptions

	for k2.update() {
		dt := k2.get_frame_time()
		k2.clear(k2.LIGHT_BLUE)
		set_game_camera()

		if game_config_reload(memory.config, &config) {
			switch game_state {
			case .Title:
				menu = menu_init(config.cards)
			case .Playing, .Pause:
				game_reload(config, &session)
			case .ModifierPick:
				game_reload(config, &session)
				modifier_options = modifier_pick_init(config.cards, session)
			case .GameOver:
			}
		}

		switch game_state {
		case .Title:
			next_state := menu_update(&menu, dt)
			if next_state == .Playing {
				free_all(memory.session)
				session = game_init(memory.session, config, Difficulty(menu.selected))
				game_state = next_state
			} else {
				menu_draw(config.cards, menu)
			}
		case .Playing:
			next_state := game_update(config, &session, dt)
			if next_state == .ModifierPick {
				modifier_options = modifier_pick_init(config.cards, session)
			}
			game_state = next_state
			game_draw(config, session)
			effects_reset(session.effects)
		case .ModifierPick:
			game_state = modifier_pick_update(config, &session, &modifier_options, dt)
			modifier_pick_draw(config.cards, modifier_options)
		case .Pause:
			game_state = pause_update()
			pause_draw(session)
		case .GameOver:
			game_state = gameover_update()
			gameover_draw(session)
		}
		k2.present()
		free_all(context.temp_allocator)
	}

	game_config_destroy(&config)
	free_all(memory.config)
	free_all(memory.session)
	k2.shutdown()
}
