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

menu_init :: proc(cards_config: CardsConfig) -> Menu {
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
			label = "2021-2022",
			card = settings_card(cards_config, start_x, start_y, int(Difficulty.Easy)),
		},
		.Medium = {
			label = "2023-2024",
			card = settings_card(cards_config, start_x, start_y, int(Difficulty.Medium)),
		},
		.Hard = {
			label = "2025-2026",
			card = settings_card(cards_config, start_x, start_y, int(Difficulty.Hard)),
		},
	}

	return Menu{difficulty_cards = difficulty_cards, selected = 0}
}

DifficultySettings :: struct {
	spawn_interval: f32,
	item_speed:     f32,
	max_active:     u8,
	lives:          u8,
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

set_difficulty :: proc(chosen: Difficulty) -> DifficultySettings {
	switch chosen {
	case .Easy:
		return DifficultySettings {
			spawn_interval = 0.7,
			item_speed = 250,
			max_active = 2,
			lives = 5,
		}
	case .Medium:
		return DifficultySettings {
			spawn_interval = 0.5,
			item_speed = 500,
			max_active = 3,
			lives = 4,
		}
	case .Hard:
		return DifficultySettings {
			spawn_interval = 0.3,
			item_speed = 500,
			max_active = 4,
			lives = 3,
		}
	}
	return {}
}

menu_draw :: proc(cards_config: CardsConfig, menu: Menu) {
	for difficulty, i in menu.difficulty_cards {
		color := k2.GREEN if int(i) == menu.selected else k2.GRAY
		k2.draw_rect(difficulty.card, color)

		// TODO: this could be calc'ed ones inside card too
		text_size := k2.measure_text(difficulty.label, 50)
		text_x := difficulty.card.x + (cards_config.width / 2) - (text_size.x / 2)
		text_y := difficulty.card.y + cards_config.height + 20

		k2.draw_text(difficulty.label, {text_x, text_y}, 50, color)
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
