package game

import k2 "../karl2d"
import "core:fmt"

gameover_update :: proc(session: Session) -> GameState {
	if k2.key_went_down(.Enter) || k2.key_went_down(.Space) || k2.key_went_down(.R) {
		return GameState.WaveMenu
	}

	when ODIN_DEBUG {
		if k2.point_in_rect(game_mouse_position(), gameover_save_button_rect()) &&
		   k2.mouse_button_went_down(.Left) {
			snapshot := game_snapshot_from_session(session)
			if err := snapshot_save_history(snapshot); err != nil {
				fmt.eprintln(err)
			} else {
				fmt.println("Saved snapshot to history")
			}
		}
	}

	return GameState.GameOver
}

gameover_draw :: proc(session: Session) {
	screen := game_screen_size()

	k2.draw_text(fmt.tprintf("Score: %d", session.score), {screen.x - 150, 10}, 20, k2.GRAY)

	text_width := k2.measure_text("GAME OVER", 50).x
	text_x := screen.x / 2 - (text_width / 2)
	k2.draw_text("GAME OVER", {text_x, screen.y / 2}, 50, k2.GRAY)

	when ODIN_DEBUG {
		button := gameover_save_button_rect()
		hovered := k2.point_in_rect(game_mouse_position(), button)
		label := "Save to history"
		color := k2.GREEN if hovered else k2.LIGHT_GRAY
		k2.draw_rect(button, color)
		text_size := k2.measure_text(label, 22)
		text_position := k2.rect_top_left(button) + (k2.Vec2{button.w, button.h} - text_size) / 2
		k2.draw_text(label, text_position, 22, k2.BLACK)
	}
}

when ODIN_DEBUG {
	@(private = "file")
	gameover_save_button_rect :: proc() -> k2.Rect {
		screen := game_screen_size()
		// TODO: Good enough for now, but will need to integrate with other buttons
		// TODO: Maybe also do "Press S to save" and no button?
		return {x = screen.x / 2 - 120, y = screen.y / 2 + 80, w = 240, h = 48}
	}
}
