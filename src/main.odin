package game

import k2 "../karl2d"

main :: proc() {
	k2.init(WINDOW_WIDTH, WINDOW_HEIGHT, "Greetings!")
	textures := textures_init()
	game_state := GameState.Title
	// TODO: Should this be cleaned when the game starts?
	menu := menu_init()
	session: Session
	// TODO: And what about cleaning this up?
	modifier_options: ModifierOptions

	for k2.update() {
		dt := k2.get_frame_time()
		k2.clear(k2.LIGHT_BLUE)
		set_game_camera()

		switch game_state {
		case .Title:
			next_state := menu_update(&menu, dt)
			if next_state == .Playing {
				session = game_init(Difficulty(menu.selected))
				game_state = next_state
			} else {
				menu_draw(menu)
			}
		case .Playing:
			next_state := game_update(&session, dt)
			if next_state == .ModifierPick {
				modifier_options = modifier_pick_init(session)
			}
			game_state = next_state
			game_draw(session, textures)
			effects_reset(session.effects)
		case .ModifierPick:
			game_state = modifier_pick_update(&session, &modifier_options, dt)
			modifier_pick_draw(modifier_options)
		case .GameOver:
			game_state = gameover_update()
			gameover_draw(session)
		}
		k2.present()
	}
	k2.shutdown()
}
