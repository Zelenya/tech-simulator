package game

import k2 "../karl2d"
import "core:fmt"
import "core:math/rand"

// TODO: Should we reuse the card code from menu?
MOD_CARD_WIDTH: f32 : 225
MOD_CARD_HEIGHT: f32 : 400
MOD_CARD_GAP: f32 : 50

ModifierKind :: enum {
	Immunity,
	// TODO: Not sure this works well, might need to draw
	WiderCatch,
	SlowerItems,
	WideAndSlow,
}

modifier_apply :: proc(session: ^Session, modifier: ModifierKind) {
	switch modifier {
	case .Immunity:
		session.lives += 1
	case .WiderCatch:
		// Increase by 20%, TODO: make configurable
		// TODO: Should probably just use percents there
		session.good_catch_margin += PLAYER_WIDTH * 0.2
	case .SlowerItems:
		// Decrease by 20%, TODO: make configurable
		session.item_pool.setting_item_speed *= 0.8
	case .WideAndSlow:
		modifier_apply(session, .SlowerItems)
		modifier_apply(session, .WiderCatch)
	}
}

modifiers_pick :: proc() -> [3]ModifierKind {
	// TODO: Is there a way to clean up this?
	all := [len(ModifierKind)]ModifierKind{.Immunity, .WiderCatch, .SlowerItems, .WideAndSlow}
	rand.shuffle(all[:])
	return {all[0], all[1], all[2]}
}

modifier_label :: proc(kind: ModifierKind) -> string {
	switch kind {
	case .Immunity:
		return "Get extra life"
	case .WiderCatch:
		return "Get wider"
	case .SlowerItems:
		return "Get slower"
	case .WideAndSlow:
		return "Get wider and slower"
	}
	return "what is this, go?"
}

ModifierOptions :: struct {
	options:  [3]ModifierCard,
	selected: int,
}

ModifierCard :: struct {
	kind:  ModifierKind,
	label: string, // TODO: title + description
	card:  k2.Rect,
}

modifier_pick_init :: proc(session: Session) -> ModifierOptions {
	screen := game_screen_size()

	total_width := MOD_CARD_WIDTH * 3 + MOD_CARD_GAP * 2
	start_x := screen.x / 2 - total_width / 2
	start_y := screen.y / 2 - MOD_CARD_HEIGHT / 2

	to_card :: proc(start_x: f32, start_y: f32, i: int) -> k2.Rect {
		card_x := start_x + cast(f32)i * (MOD_CARD_WIDTH + MOD_CARD_GAP)
		return k2.Rect{x = card_x, y = start_y, w = MOD_CARD_WIDTH, h = MOD_CARD_HEIGHT}
	}

	option_cards: [3]ModifierCard
	// TODO: Improve randomness and make level dependend
	for option, i in modifiers_pick() {
		option_cards[i] = {
			kind  = option,
			label = modifier_label(option),
			card  = to_card(start_x, start_y, i),
		}
	}

	return ModifierOptions{options = option_cards, selected = 0}
}

// TODO: Should modifier own waves? or make wave.odin that owns game+modifiers
// TODO: Should we re-use menu card picking code?
modifier_pick_update :: proc(
	session: ^Session,
	modifier_options: ^ModifierOptions,
	dt: f32,
) -> GameState {
	if k2.key_went_down(.Left) do modifier_options.selected -= 1
	if k2.key_went_down(.Right) do modifier_options.selected += 1
	modifier_options.selected = clamp(modifier_options.selected, 0, len(Difficulty))

	mouse := game_mouse_position()
	for option, i in modifier_options.options {
		if is_inside(option.card, mouse) do modifier_options.selected = int(i)
	}

	if k2.key_went_down(.Enter) {
		selected := modifier_options.options[modifier_options.selected]
		return wave_next(session, selected.kind, dt)
	}

	if k2.mouse_button_went_down(.Left) {
		for option, _ in modifier_options.options {
			if is_inside(option.card, mouse) {
				return wave_next(session, option.kind, dt)
			}
		}
	}

	return .ModifierPick
}

wave_next :: proc(session: ^Session, modifier: ModifierKind, dt: f32) -> GameState {
	// TODO: Similar check is duplicate in game loop
	session.current_wave = min(session.current_wave + 1, len(session.waves) - 1)
	session.wave_timer = 0

	wave := session.waves[session.current_wave]

	// TODO: It's kind of weird that we do modifiers and normal "speed ups", those could conflict
	item_pool_next_wave(
		item_pool = &session.item_pool,
		spawn_multiplier = wave.spawn_multiplier,
		speed_multiplier = wave.speed_multiplier,
	)
	modifier_apply(session, modifier)
	fmt.printfln("Wave: %v", session.current_wave)
	return GameState.Playing
}

// TODO: Should we re-use menu card drawing code?
modifier_pick_draw :: proc(modifier_options: ModifierOptions) {
	for difficulty, i in modifier_options.options {
		color := k2.GREEN if int(i) == modifier_options.selected else k2.GRAY
		k2.draw_rect(difficulty.card, color)

		// TODO: this could be calc'ed ones inside card too
		text_size := k2.measure_text(difficulty.label, 50)
		text_x := difficulty.card.x + (MOD_CARD_WIDTH / 2) - (text_size.x / 2)
		text_y := difficulty.card.y + MOD_CARD_HEIGHT + 20

		k2.draw_text(difficulty.label, {text_x, text_y}, 50, color)
	}
}
