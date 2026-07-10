package game

import k2 "../karl2d"
import "core:strings"

ActiveWaveMenu :: union {
	WaveMenu(Difficulty),
	WaveMenu(ModifierKind),
}

WaveMenu :: struct($Kind: typeid) {
	cards:    [3]WaveMenuCard(Kind),
	selected: int,
}

WaveMenuCard :: struct($Kind: typeid) {
	kind:        Kind,
	title:       string,
	description: string,
	card:        k2.Rect,
}

wave_menu_init :: proc(
	cards_config: CardsConfig,
	difficulties: [Difficulty]DifficultyConfig,
) -> WaveMenu(Difficulty) {
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

	difficulty_cards := [3]WaveMenuCard(Difficulty) {
		{
			kind = .Easy,
			title = difficulties[.Easy].label,
			description = "",
			card = settings_card(cards_config, start_x, start_y, int(Difficulty.Easy)),
		},
		{
			kind = .Medium,
			title = difficulties[.Medium].label,
			description = "",
			card = settings_card(cards_config, start_x, start_y, int(Difficulty.Medium)),
		},
		{
			kind = .Hard,
			title = difficulties[.Hard].label,
			description = "",
			card = settings_card(cards_config, start_x, start_y, int(Difficulty.Hard)),
		},
	}

	return WaveMenu(Difficulty){cards = difficulty_cards, selected = 0}
}

wave_modifier_init :: proc(config: GameConfig, session: Session) -> WaveMenu(ModifierKind) {
	cards_config := config.cards
	screen := game_screen_size()

	total_width := cards_config.width * 3 + cards_config.gap * 2
	start_x := screen.x / 2 - total_width / 2
	start_y := screen.y / 2 - cards_config.height / 2

	to_card :: proc(cards_config: CardsConfig, start_x: f32, start_y: f32, i: int) -> k2.Rect {
		card_x := start_x + cast(f32)i * (cards_config.width + cards_config.gap)
		return k2.Rect{x = card_x, y = start_y, w = cards_config.width, h = cards_config.height}
	}

	option_cards: [3]WaveMenuCard(ModifierKind)
	for option, i in modifiers_pick(config, session.current_wave) {
		def := config.modifiers.by_kind[option]
		option_cards[i] = {
			kind        = option,
			title       = def.title,
			description = def.description,
			card        = to_card(cards_config, start_x, start_y, i),
		}
	}

	return WaveMenu(ModifierKind){cards = option_cards, selected = 0}
}

// TODO: Allow picks with 1,2,3
wave_menu_update :: proc($Kind: typeid, menu: ^WaveMenu(Kind)) -> Maybe(Kind) {
	if k2.key_went_down(.Left) do menu.selected -= 1
	if k2.key_went_down(.Right) do menu.selected += 1
	menu.selected = clamp(menu.selected, 0, len(menu.cards) - 1)

	mouse := game_mouse_position()
	mouse_over_card := false
	for option, i in menu.cards {
		if k2.point_in_rect(mouse, option.card) {
			menu.selected = int(i)
			mouse_over_card = true
		}
	}

	if k2.key_went_down(.Enter) {
		return menu.cards[menu.selected].kind
	}

	if mouse_over_card && k2.mouse_button_went_down(.Left) {
		return menu.cards[menu.selected].kind
	}

	return nil
}

wave_menu_draw :: proc(
	$Kind: typeid,
	cards_config: CardsConfig,
	fonts_config: FontsConfig,
	menu: WaveMenu(Kind),
) {
	title_font := fonts_config.by_kind[.H1]
	description_font := fonts_config.by_kind[.P]

	for option, i in menu.cards {
		source := k2.get_texture_rect(cards_config.sprite)
		k2.draw_texture_fit(cards_config.sprite, source, option.card)

		color := k2.GREEN if int(i) == menu.selected else k2.BLACK

		if int(i) == menu.selected {
			k2.draw_rect_outline(option.card, 5, k2.color_alpha(color, 200))
		}

		// TODO: Could recalculate with just margin, remove width
		title_text_width := cards_config.width - cards_config.title_box.x_margin * 2
		// TODO: Should be done ones, not on each draw
		title_text, title_font_size, title_text_size := fit_text_into_box(
			option.title,
			title_text_width,
			cards_config.title_box.height,
			title_font.font,
			title_font.size,
		)

		box_position :=
			k2.rect_top_left(option.card) +
			{cards_config.title_box.x_margin, cards_config.title_box.top_y}
		box_size := k2.Vec2{title_text_width, cards_config.title_box.height}
		title_pos := box_position + box_size / 2 - title_text_size / 2
		k2.draw_text(title_text, title_pos, f32(title_font_size), k2.BLACK, title_font.font)

		description_text_width := cards_config.width - cards_config.description_box.x_margin * 2
		// TODO: Should be done once, not on each draw
		description_text, description_font_size, description_text_size := fit_text_into_box(
			option.description,
			description_text_width,
			cards_config.description_box.height,
			description_font.font,
			description_font.size,
		)

		desc_box_position :=
			k2.rect_bottom_left(option.card) +
			{cards_config.description_box.x_margin, cards_config.description_box.bottom_y}
		desc_box_size := k2.Vec2{description_text_width, cards_config.description_box.height}
		description_pos := desc_box_position + desc_box_size / 2 - description_text_size / 2
		k2.draw_text(
			description_text,
			description_pos,
			f32(description_font_size),
			k2.BLACK,
			description_font.font,
		)
	}
}

MIN_FONT_SIZE :: 2

// TODO: Consider passing `wrap` bool flag
// Try to fit word by word, and if it's not possible at the current font size, try with a smaller one
fit_text_into_box :: proc(
	text: string,
	w, h: f32,
	font: k2.Font,
	initial_size: int,
) -> (
	string,
	int,
	k2.Vec2,
) {
	size := max(initial_size, MIN_FONT_SIZE)

	for {
		wrapped, wrapped_size := wrap_text(text, w, font, size)

		// If doesn't fit, try again with a smaller font
		if wrapped_size.x <= w && wrapped_size.y <= h || size == MIN_FONT_SIZE {
			return wrapped, size, wrapped_size
		}

		size -= 1
	}
}

// TODO: Should it short-circuit if it overflows on h mid-way?
wrap_text :: proc(text: string, w: f32, font: k2.Font, size: int) -> (string, k2.Vec2) {
	remaining := text
	wrapped_text: string
	wrapped_text_size: k2.Vec2

	for word in strings.fields_iterator(&remaining) {
		candidate := strings.concatenate(
			{wrapped_text, len(wrapped_text) > 0 ? " " : "", word},
			context.temp_allocator,
		)
		candidate_size := k2.measure_text(candidate, f32(size), font)

		// If doesn't fit width-wise, try with this word on the next line
		if candidate_size.x <= w {
			wrapped_text = candidate
			wrapped_text_size = candidate_size
		} else {
			wrapped_text = strings.concatenate({wrapped_text, "\n", word}, context.temp_allocator)
			wrapped_text_size = k2.measure_text(wrapped_text, f32(size), font)
		}
	}

	return wrapped_text, wrapped_text_size
}
