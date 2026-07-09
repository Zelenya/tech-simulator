package game

import k2 "../karl2d"

Difficulty :: enum {
	Easy,
	Medium,
	Hard,
}

Menu :: struct {
	difficulty_cards: [Difficulty]DifficutlyCard,
	selected:         int,
}

DifficutlyCard :: struct {
	label: string,
	card:  k2.Rect,
}

menu_init :: proc(cards_config: CardsConfig, difficulties: [Difficulty]DifficultyConfig) -> Menu {
	screen := game_screen_size()

	total_width := cards_config.width * 3 + cards_config.gap * 2
	start_x := screen.x / 2 - total_width / 2
	start_y := screen.y / 2 - cards_config.height / 2

	settings_card :: proc(
		cards_config: CardsConfig,
		start_x: f32,
		start_y: f32,
		i: int,
	) -> k2.Rect {
		card_x := start_x + cast(f32)i * (cards_config.width + cards_config.gap)
		return k2.Rect{x = card_x, y = start_y, w = cards_config.width, h = cards_config.height}
	}

	difficulty_cards := [Difficulty]DifficutlyCard {
		.Easy = {
			label = difficulties[.Easy].label,
			card = settings_card(cards_config, start_x, start_y, int(Difficulty.Easy)),
		},
		.Medium = {
			label = difficulties[.Medium].label,
			card = settings_card(cards_config, start_x, start_y, int(Difficulty.Medium)),
		},
		.Hard = {
			label = difficulties[.Hard].label,
			card = settings_card(cards_config, start_x, start_y, int(Difficulty.Hard)),
		},
	}

	return Menu{difficulty_cards = difficulty_cards, selected = 0}
}

menu_update :: proc(menu: ^Menu, dt: f32) -> GameState {
	if k2.key_went_down(.Left) do menu.selected -= 1
	if k2.key_went_down(.Right) do menu.selected += 1
	menu.selected = clamp(menu.selected, 0, len(Difficulty) - 1)

	mouse := game_mouse_position()
	for difficulty, i in menu.difficulty_cards {
		if is_inside(difficulty.card, mouse) do menu.selected = int(i)
	}

	if k2.key_went_down(.Enter) {
		return GameState.Playing
	}

	if k2.mouse_button_went_down(.Left) {
		for difficulty, _ in menu.difficulty_cards {
			if is_inside(difficulty.card, mouse) {
				return GameState.Playing
			}
		}
	}

	return GameState.Title
}

menu_draw :: proc(cards_config: CardsConfig, fonts_config: FontsConfig, menu: Menu) {
	font := fonts_config.by_kind[.H1]

	for difficulty, i in menu.difficulty_cards {
		source := k2.get_texture_rect(cards_config.sprite)
		k2.draw_texture_fit(cards_config.sprite, source, difficulty.card)

		// TODO: It should hover up with sound
		color := k2.GREEN if int(i) == menu.selected else k2.BLACK
		if int(i) == menu.selected {
			k2.draw_rect_outline(difficulty.card, 5, k2.color_alpha(color, 200))
		}

		text_width := cards_config.width - cards_config.title_box.x_margin * 2
		// TODO: Should be done once, not on each draw
		fitting_font_size, fitting_text_size := fit_text_into_box(
			difficulty.label,
			text_width,
			cards_config.title_box.height,
			font.font,
			font.size,
		)

		// k2.draw_rect_outline(test, 5, k2.RED)

		box_position :=
			k2.rect_top_left(difficulty.card) +
			{cards_config.title_box.x_margin, cards_config.title_box.top_y}
		box_size := k2.Vec2{text_width, cards_config.title_box.height}
		text_pos := box_position + box_size / 2 - fitting_text_size / 2

		k2.draw_text(difficulty.label, text_pos, f32(fitting_font_size), k2.BLACK, font.font)
	}
}

fit_text_into_box :: proc(text: string, w, h: f32, font: k2.Font, size: int) -> (int, k2.Vec2) {
	// Safety net
	if size <= 2 do return 2, {w, h}

	text_size := k2.measure_text(text, f32(size), font)
	if text_size.x <= w && text_size.y <= h {
		return size, text_size
	} else {
		return fit_text_into_box(text, w, h, font, size - 2)
	}
}

// TODO: use k2 functions
is_inside :: proc(rect: k2.Rect, pos: k2.Vec2) -> bool {
	return(
		pos.x > rect.x &&
		pos.x < (rect.x + rect.w) &&
		pos.y > rect.y &&
		pos.y < (rect.y + rect.h) \
	)
}
