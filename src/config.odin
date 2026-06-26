package game

import k2 "../karl2d"
import "core:encoding/json"
import "core:fmt"
import "core:os"
import filepath "core:path/filepath"
import "core:strings"
import "core:time"

BaseConfig :: struct {
	cards:     CardsConfig,
	effects:   EffectsConfig,
	item_pool: ItemPoolConfig,
	waves:     []WaveConfig,
}

GameConfig :: struct {
	using _:    BaseConfig,
	player:     PlayerConfig,
	items:      map[ItemKind]ItemDef,
	updated_at: time.Time,
}

GameConfigRaw :: struct {
	using _: BaseConfig,
	player:  PlayerConfigRaw,
	items:   []ItemConfigRaw,
}

CardsConfig :: struct {
	width:  f32,
	height: f32,
	gap:    f32,
}

EffectsConfig :: struct {
	flashing_lifetime: f32,
	flashing_speed:    f32,
}

ItemPoolConfig :: struct {
	good_to_bad_ratio: f32,
}

ItemConfigRaw :: struct {
	kind:    string,
	sprite:  string,
	shape:   string,
	width:   f32,
	height:  f32,
	weight:  f32,
	is_good: bool,
	points:  u32,
}

PlayerConfigRaw :: struct {
	sprite: string,
	width:  f32,
	height: f32,
	speed:  f32,
}

PlayerConfig :: struct {
	sprite: k2.Texture,
	width:  f32,
	height: f32,
	speed:  f32,
}

WaveConfig :: struct {
	spawn_multiplier: f32,
	speed_multiplier: f32,
	duration:         f32,
}

game_config_load :: proc() -> GameConfig {
	// TODO: allocator? config is for the whole game anyway
	config_path := asset_path_required("config/game.json", "game config")
	data, os_err := os.read_entire_file(config_path, context.allocator)
	if os_err != nil {
		fmt.eprintln("Failed to read the config file", config_path, os.error_string(os_err))
		panic("Failed to read the config file")
	}

	raw_config: GameConfigRaw
	json_err := json.unmarshal(data, &raw_config)
	if json_err != nil {
		fmt.eprintln("Failed to parse the config file", json_err)
		panic("Failed to parse the config file")
	}

	last_write_at, time_err := os.last_write_time_by_name(config_path)
	if time_err != nil {
		fmt.eprintln("Failed to read config's write time", config_path, os.error_string(time_err))
		panic("Failed to read the config's write time")
	}

	return parse_game_config(raw_config, last_write_at)
}

game_config_reload :: proc(game_config: ^GameConfig) {
	config_path := asset_path_required("config/game.json", "game config")
	last_write_at, time_err := os.last_write_time_by_name(config_path)

	if time_err != nil {
		fmt.eprintln(
			"Failed to re-read config's write time",
			config_path,
			os.error_string(time_err),
		)
		panic("Failed to re-read the config's write time")
	}

	if last_write_at != game_config.updated_at {
		game_config^ = game_config_load()
	}
}

parse_game_config :: proc(raw: GameConfigRaw, updated_at: time.Time) -> GameConfig {
	item_pool := parse_item_pool_config(raw.item_pool)

	return GameConfig {
		cards = parse_cards_config(raw.cards),
		effects = parse_effects_config(raw.effects),
		item_pool = item_pool,
		player = parse_player_config(raw.player),
		waves = parse_waves_config(raw.waves),
		items = parse_items_config(raw.items, item_pool.good_to_bad_ratio),
		updated_at = updated_at,
	}
}

parse_cards_config :: proc(config: CardsConfig) -> CardsConfig {
	if config.width <= 0 || config.height <= 0 || config.gap <= 0 {
		fmt.eprintln("Invalid cards config: width, height, and gap must be positive")
		panic("Invalid cards config")
	}
	return config
}

parse_effects_config :: proc(config: EffectsConfig) -> EffectsConfig {
	if config.flashing_lifetime <= 0 || config.flashing_speed <= 0 {
		fmt.eprintln("Invalid effects config: lifetime and speed must be positive")
		panic("Invalid effects config")
	}
	return config
}

parse_item_pool_config :: proc(config: ItemPoolConfig) -> ItemPoolConfig {
	if config.good_to_bad_ratio < 0 || config.good_to_bad_ratio > 1 {
		fmt.eprintfln(
			"Invalid item pool config: good_to_bad_ratio must be between 0 and 1, got %v",
			config.good_to_bad_ratio,
		)
		panic("Invalid item pool config")
	}
	return config
}

// Fill out item catalog so we don't have to recalculate the weights for each random generation
parse_items_config :: proc(raw: []ItemConfigRaw, good_to_bad_ratio: f32) -> map[ItemKind]ItemDef {
	if len(raw) == 0 {
		fmt.eprintln("Invalid items config: items must be non-empty")
		panic("Invalid items config")
	}

	by_kind := make(map[ItemKind]ItemDef)
	for item in raw {
		def := parse_item_def(&by_kind, item)
		if item.is_good {
			def.effect = GoodItemCaught {
				points = item.points,
			}
			// append_elem(&item_catalog.good, def)
			// item_catalog.good_weight += def.weight
		} else {
			def.effect = BadItemCaught{}
			// append_elem(&item_catalog.bad, def)
			// item_catalog.bad_weight += def.weight
		}
		map_insert(&by_kind, def.kind, def)
	}

	return by_kind
}

// Note: doesn't set the item effect
parse_item_def :: proc(by_kind: ^map[ItemKind]ItemDef, raw: ItemConfigRaw) -> ItemDef {
	kind, kind_ok := kind_from_string(raw.kind).?
	if !kind_ok {
		fmt.eprintfln("Invalid item config: unknown item kind '%v'", raw.kind)
		panic("Invalid item config")
	}
	if kind in by_kind {
		fmt.eprintfln("Invalid item config: duplicate item kind '%v'", raw.kind)
		panic("Invalid item config")
	}

	shape, shape_ok := shape_from_string(raw.shape).?
	if !shape_ok {
		fmt.eprintfln("Invalid item config: unknown item shape '%v'", raw.shape)
		panic("Invalid item config")
	}

	if raw.width <= 0 || raw.height <= 0 || raw.weight <= 0 {
		fmt.eprintfln(
			"Invalid item '%v' config: width, height, and weight must be positive ",
			raw.kind,
		)
		panic("Invalid item config")
	}

	return ItemDef {
		kind = kind,
		sprite = texture_from(raw.sprite),
		shape = shape,
		width = raw.width,
		height = raw.height,
		weight = raw.weight,
	}
}

parse_player_config :: proc(config: PlayerConfigRaw) -> PlayerConfig {
	if config.width <= 0 || config.height <= 0 || config.speed <= 0 {
		fmt.eprintln("Invalid player config: player width, height, and speed must be positive")
		panic("Invalid player config")
	}

	return PlayerConfig {
		sprite = texture_from(config.sprite),
		width = config.width,
		height = config.height,
		speed = config.speed,
	}
}

parse_waves_config :: proc(config: []WaveConfig) -> []WaveConfig {
	if len(config) == 0 {
		fmt.eprintln("Invalid waves config: waves must be non-empty")
		panic("Invalid waves config")
	}

	for wave, i in config {
		if wave.duration <= 0 || wave.spawn_multiplier <= 0 || wave.speed_multiplier <= 0 {
			fmt.eprintfln("Invalid wave #%v config: duration and multipliers must be positive", i)
			panic("Invalid waves config")
		}
	}

	return config
}

texture_from :: proc(sprite_name: string) -> k2.Texture {
	// TODO: Review allocation and errors
	// TODO: This won't work from the bin (or any non root dir)
	path := asset_path_required(
		strings.concatenate({"sprites/", sprite_name, ".png"}),
		sprite_name,
	)
	texture := k2.load_texture_from_file(path)
	if texture.width <= 0 || texture.height <= 0 {
		fmt.eprintfln(
			"Invalid texture config: failed to load sprite '%v' from %v (w: %v, h: %v)",
			sprite_name,
			path,
			texture.width,
			texture.height,
		)
		panic("Invalid texture config")
	}
	return texture
}

kind_from_string :: proc(raw: string) -> Maybe(ItemKind) {
	switch raw {
	case "normal":
		return .Normal
	case "call":
		return .Call
	case "faang":
		return .Faang
	case "fire-stack":
		return .FireStack
	case "big-money":
		return .BigMoney
	case "remote":
		return .Remote
	case "rejection":
		return .Rejection
	case "ignore":
		return .Ignore
	case "nightmare-stack":
		return .NightmareStack
	}
	return nil
}

shape_from_string :: proc(raw: string) -> Maybe(ItemShape) {
	switch raw {
	case "rect":
		return .Rect
	case "circle":
		return .Circle
	}
	return nil
}

asset_path_required :: proc(relative: string, label: string) -> string {
	path, err := filepath.join({"assets", relative}, context.allocator)
	if err != nil {
		fmt.eprintln("Failed to allocate asset path")
		panic("Failed to allocate asset path")
	}

	if os.is_file(path) do return path

	fmt.eprintfln("Failed to find asset '%v': %v", label, path)
	panic("Asset not found")
}
