package game

import k2 "../karl2d"

main :: proc() {
	k2.init(WINDOW_WIDTH, WINDOW_HEIGHT, "Greetings!")

	memory: AppMemory
	memory_init(&memory)

	config := game_config_load(memory.config)
	game_state := GameState.WaveMenu
	session: Session
	wave_menu: ActiveWaveMenu = wave_menu_init(config.cards, config.difficulties)

	for k2.update() {
		dt := k2.get_frame_time()
		k2.clear(k2.LIGHT_BLUE)
		set_game_camera()

		if game_config_reload(memory.config, &config) {
			switch game_state {
			case .WaveMenu:
				switch menu in wave_menu {
				case WaveMenu(Difficulty):
					wave_menu = wave_menu_init(config.cards, config.difficulties)
				case WaveMenu(ModifierKind):
					game_reload(config, &session)
					wave_menu = wave_modifier_init(config, session)
				}
			case .Playing, .Pause:
				game_reload(config, &session)
			case .GameOver:
			}
		}

		switch game_state {
		case .WaveMenu:
			switch &menu in wave_menu {
			case WaveMenu(Difficulty):
				choice, picked := wave_menu_update(Difficulty, &menu).?

				if picked {
					free_all(memory.session)
					session = game_init(memory.session, config, choice)
					game_state = .Playing
				} else {
					wave_menu_draw(Difficulty, config.cards, config.fonts, menu)
				}
			case WaveMenu(ModifierKind):
				choice, picked := wave_menu_update(ModifierKind, &menu).?
				if picked {
					game_state = wave_next(config, &session, choice, dt)
				} else {
					wave_menu_draw(ModifierKind, config.cards, config.fonts, menu)
				}
			}

		case .Playing:
			next_state := game_update(config, &session, dt)
			if next_state == .WaveMenu {
				enter_modifier_menu(config, session, &wave_menu, &game_state)
			} else {
				game_state = next_state
			}
			game_draw(config, session)
			effects_reset(session.effects)

		case .Pause:
			game_state = pause_update()
			pause_draw(session)

		case .GameOver:
			next_state := gameover_update()
			if next_state == .WaveMenu {
				enter_difficulty_menu(config, &wave_menu, &game_state)
			} else {
				game_state = next_state
			}
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

enter_difficulty_menu :: proc(
	config: GameConfig,
	wave_menu: ^ActiveWaveMenu,
	game_state: ^GameState,
) {
	wave_menu^ = wave_menu_init(config.cards, config.difficulties)
	game_state^ = .WaveMenu
}

enter_modifier_menu :: proc(
	config: GameConfig,
	session: Session,
	wave_menu: ^ActiveWaveMenu,
	game_state: ^GameState,
) {
	wave_menu^ = wave_modifier_init(config, session)
	game_state^ = .WaveMenu
}
