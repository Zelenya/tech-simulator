package game

import k2 "../karl2d"
import "core:fmt"

gameover_update :: proc() -> GameState {
	if k2.key_went_down(.Enter) || k2.key_went_down(.Space) || k2.key_went_down(.R) {
		return GameState.Title
	} else {
		return GameState.GameOver
	}
}

gameover_draw :: proc(session: Session) {
	screen := k2.get_screen_size()

	k2.draw_text(fmt.tprintf("Score: %d", session.score), {screen.x - 100, 10}, 20, k2.GRAY)
	k2.draw_text(fmt.tprintf("Lives: %d", session.lives), {screen.x - 100, 30}, 20, k2.GRAY)

	// TODO: R to restart?
	text_width := k2.measure_text("GAME OVER", 50).x
	text_x := screen.x / 2 - (text_width / 2)
	k2.draw_text("GAME OVER", {text_x, screen.y / 2}, 50, k2.GRAY)
}
