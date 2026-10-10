package game

import k2 "../karl2d"
import "core:fmt"

main :: proc() {
	k2.init(WINDOW_WIDTH, WINDOW_HEIGHT, "Don't forget to drink some water")

	memory: AppMemory
	memory_init(&memory)

	current_config: ^ConfigSnapshot = game_config_load(context.allocator)
	config := current_config.value

	game_state := GameState.WaveMenu
	session: Session
	wave_menu: ActiveWaveMenu = wave_menu_init(config.cards, config.difficulties)

	for k2.update() {
		dt := k2.get_frame_time()
		k2.clear(k2.LIGHT_BLUE)
		set_game_camera()

		// Hot config reload:
		config_candidate, config_status := game_config_reload(current_config)
		// Validate the config (if reloaded)
		if config_status == .ReadyToReload {
			_, is_modifier_menu := wave_menu.(WaveMenu(ModifierKind))
			choosing_modifier := game_state == .WaveMenu && is_modifier_menu
			if game_state == .Playing || game_state == .Pause || choosing_modifier {
				required_waves := max(session.current_wave + 1, len(session.modifier_picks) + 1)
				if choosing_modifier do required_waves += 1 // We are advancing to the next wave

				issue, rejected := game_reload_check(
					config_candidate.value,
					&session,
					required_waves,
				).?

				if rejected {
					switch reason in issue {
					case ReloadMissingWaves:
						fmt.eprintfln(
							"Config reload rejected: need %v waves, got %v",
							reason.required,
							reason.available,
						)
					case ReloadMissingItem:
						fmt.eprintfln(
							"Config reload rejected: pending spawn requires item %v",
							reason.kind,
						)
					}
					game_config_snapshot_destroy(config_candidate)
					config_candidate = nil
					config_status = .Rejected
				}
			}
		}
		// Apply the config (if reloaded)
		if config_status == .ReadyToReload {
			previous := current_config
			current_config = config_candidate
			config = current_config.value
			switch game_state {
			case .WaveMenu:
				switch menu in wave_menu {
				case WaveMenu(Difficulty):
					wave_menu = wave_menu_init(config.cards, config.difficulties)
				case WaveMenu(ModifierKind):
					game_reload(config, &session)
					// Note that this reshuffles the cards
					wave_menu = wave_modifier_init(config, session)
				}
			case .Playing, .Pause:
				game_reload(config, &session)
			case .GameOver:
			}
			game_config_snapshot_destroy(previous)
		}

		// Transition between game states and game loops:
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

	// Clean up:
	game_config_snapshot_destroy(current_config)
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
