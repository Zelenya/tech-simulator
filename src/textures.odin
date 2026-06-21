package game

import k2 "../karl2d"

Textures :: struct {
	player:         k2.Texture,
	item_good:      k2.Texture,
	item_good_call: k2.Texture,
	item_bad:       k2.Texture,
}

textures_init :: proc() -> Textures {
	return {
		player = k2.load_texture_from_file("./assets/sprites/test-player.png"),
		item_good = k2.load_texture_from_file("./assets/sprites/test-item-good-normal.png"),
		item_good_call = k2.load_texture_from_file("./assets/sprites/test-item-good-call.png"),
		item_bad = k2.load_texture_from_file("./assets/sprites/test-item-bad.png"),
	}
}
