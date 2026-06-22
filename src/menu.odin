package game

import k2 "../karl2d"

CARD_WIDTH: f32 : 225
CARD_HEIGHT: f32 : 400
CARD_GAP: f32 : 50

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

menu_init :: proc() -> Menu {
	screen := game_screen_size()

	total_width := CARD_WIDTH * 3 + CARD_GAP * 2
	start_x := screen.x / 2 - total_width / 2
	start_y := screen.y / 2 - CARD_HEIGHT / 2

	settings_card :: proc(start_x: f32, start_y: f32, i: int) -> k2.Rect {
		card_x := start_x + cast(f32)i * (CARD_WIDTH + CARD_GAP)
		return k2.Rect{x = card_x, y = start_y, w = CARD_WIDTH, h = CARD_HEIGHT}
	}

	difficulty_cards := [Difficulty]DifficutlyCard {
		.Easy = {
			label = "2021-2022",
			card = settings_card(start_x, start_y, int(Difficulty.Easy)),
		},
		.Medium = {
			label = "2023-2024",
			card = settings_card(start_x, start_y, int(Difficulty.Medium)),
		},
		.Hard = {
			label = "2025-2026",
			card = settings_card(start_x, start_y, int(Difficulty.Hard)),
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
	menu.selected = clamp(menu.selected, 0, len(Difficulty))

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

menu_draw :: proc(menu: Menu) {
	for difficulty, i in menu.difficulty_cards {
		color := k2.GREEN if int(i) == menu.selected else k2.GRAY
		k2.draw_rect(difficulty.card, color)

		// TODO: this could be calc'ed ones inside card too
		text_size := k2.measure_text(difficulty.label, 50)
		text_x := difficulty.card.x + (CARD_WIDTH / 2) - (text_size.x / 2)
		text_y := difficulty.card.y + CARD_HEIGHT + 20

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
