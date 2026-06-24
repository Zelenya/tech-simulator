package game

import k2 "../karl2d"
import "core:fmt"

// TODO: This is for playing only now
pause_update :: proc() -> GameState {
	if k2.key_went_down(.Escape) || k2.key_went_down(.Space) || k2.key_went_down(.Enter) {
		return GameState.Playing
	} else {
		return GameState.Pause
	}
}

pause_draw :: proc(session: Session) {
	screen := game_screen_size()

	k2.draw_text(fmt.tprintf("Lives: %d", session.lives), {screen.x - 150, 10}, 20, k2.GRAY)

	text_width := k2.measure_text("PAUSED", 50).x
	text_x := screen.x / 2 - (text_width / 2)
	k2.draw_text("PAUSED", {text_x, screen.y / 2}, 50, k2.GRAY)
}
