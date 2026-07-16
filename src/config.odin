package game

import k2 "../karl2d"
import "base:runtime"
import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:reflect"
import "core:strings"
import "core:testing"
import "core:time"
import "core:unicode/utf8"

// TODO: There isn't much use for this left
BaseConfig :: struct {
	effects:   EffectsConfig,
	item_pool: ItemPoolConfig,
}

GameConfig :: struct {
	using _:          BaseConfig,
	background:       BackgroundConfig,
	cards:            CardsConfig,
	difficulties:     [Difficulty]DifficultyConfig,
	fonts:            FontsConfig,
	hud:              HudConfig,
	items:            map[ItemKind]ItemConfig,
	modifier_effects: ModifierEffectsConfig,
	modifiers:        ModifiersConfig,
	player:           PlayerConfig,
	sounds:           SoundsConfig,
	waves:            []WaveConfig,
	updated_at:       time.Time,
}

GameConfigRaw :: struct {
	using _:          BaseConfig,
	background:       []BackgroundPieceConfigRaw,
	cards:            CardsConfigRaw,
	difficulties:     []DifficultyConfigRaw,
	fonts:            []FontConfigRaw,
	hud:              HudConfigRaw,
	items:            []ItemConfigRaw,
	modifier_effects: ModifierEffectsConfigRaw,
	modifiers:        []ModifierConfigRaw,
	player:           PlayerConfigRaw,
	sounds:           []SoundConfigRaw,
	waves:            []WaveConfigRaw,
}

BackgroundKind :: enum {
	Floor,
	Wall,
	Window,
}

BackgroundConfig :: struct {
	pieces: map[BackgroundKind]BackgroundPieceConfig,
}

BackgroundPieceConfigData :: struct($Kind, $Sprite: typeid) {
	kind:   Kind,
	sprite: Sprite,
	width:  f32,
	height: f32,
}

BackgroundPieceConfigRaw :: BackgroundPieceConfigData(string, string)
BackgroundPieceConfig :: BackgroundPieceConfigData(BackgroundKind, k2.Texture)

CardsConfigData :: struct($Sprite: typeid) {
	gap:             f32,
	sprite:          Sprite,
	width:           f32,
	height:          f32,
	title_box:       TitleTextBoxConfig,
	description_box: DescriptionTextBoxConfig,
}

CardsConfigRaw :: CardsConfigData(string)
CardsConfig :: CardsConfigData(k2.Texture)

TitleTextBoxConfig :: struct {
	x_margin: f32,
	top_y:    f32,
	height:   f32,
}

DescriptionTextBoxConfig :: struct {
	x_margin: f32,
	bottom_y: f32,
	height:   f32,
}

DifficultyConfigData :: struct($Kind: typeid) {
	kind:           Kind,
	label:          string,
	spawn_interval: f32,
	item_speed:     f32,
	max_active:     u8,
	lives:          u8,
}

DifficultyConfigRaw :: DifficultyConfigData(string)
DifficultyConfig :: DifficultyConfigData(Difficulty)

EffectsConfig :: struct {
	flashing_lifetime:                f32,
	flashing_speed:                   f32,
	full_flash_duration:              f32,
	floating_text_lifetime:           f32,
	floating_text_speed:              f32,
	floating_text_size:               f32,
	shake_duration:                   f32,
	shake_strength:                   f32,
	dust_timer:                       f32,
	dust_particle_count:              u32,
	dust_floor_offset:                f32,
	dust_x_jitter:                    f32,
	dust_y_jitter:                    f32,
	dust_vx_min_multiplier:           f32,
	dust_vx_max_multiplier:           f32,
	dust_vy_min_multiplier:           f32,
	dust_vy_max_multiplier:           f32,
	dust_lifetime_min_multiplier:     f32,
	dust_size_min_multiplier:         f32,
	dust_size_max_multiplier:         f32,
	particle_count:                   u32,
	particle_lifetime:                f32,
	particle_lifetime_min_multiplier: f32,
	particle_size:                    f32,
	particle_size_min_multiplier:     f32,
	particle_speed:                   f32,
}

FontKind :: enum {
	H1,
	P,
}

FontsConfig :: struct {
	by_kind: map[FontKind]FontConfig,
}

FontConfigData :: struct($Kind, $Font: typeid) {
	kind: Kind,
	font: Font,
	size: int,
}

FontConfigRaw :: FontConfigData(string, string)
FontConfig :: FontConfigData(FontKind, k2.Font)

HudConfigData :: struct($LivesSprite: typeid) {
	margin:       f32,
	lives_sprite: LivesSprite,
	lives_width:  f32,
	lives_height: f32,
	lives_gap:    f32,
}

HudConfigRaw :: HudConfigData(string)
HudConfig :: HudConfigData(k2.Texture)

ItemPoolConfig :: struct {
	good_to_bad_ratio: f32,
	hard_cap:          u8,
}

ModifierEffectsConfigData :: struct($Item: typeid) {
	prestige_preference_item:     Item,
	tech_stack_preference_item:   Item,
	compensation_preference_item: Item,
	remote_work_preference_item:  Item,
	using _:                      ModifierEffectsTuningConfig,
}

ModifierEffectsConfigRaw :: ModifierEffectsConfigData(string)
ModifierEffectsConfig :: ModifierEffectsConfigData(ItemKind)

ModifierEffectsTuningConfig :: struct {
	add_pet_project_catch_number:           u32,
	ask_for_referral_weight_multiplier:     f32,
	file_unemployment_lives_delta:          i8,
	give_conference_talk_margin_multiplier: f32,
	give_conference_talk_magnet_multiplier: f32,
	hiring_freeze_item_speed_multiplier:    f32,
	burnout_item_speed_multiplier:          f32,
	burnout_score_base_multiplier:          u32,
	lower_quality_bar_ratio_multiplier:     f32,
	lower_quality_bar_lives_delta:          i8,
	tighten_cv_ratio_multiplier:            f32,
	tighten_cv_score_base_multiplier:       u32,
	spray_and_pray_ratio_multiplier:        f32,
	spray_and_pray_score_base_divisor:      u32,
}

ModifiersConfig :: struct {
	by_kind: map[ModifierKind]ModifierConfig,
}

ModifierConfigData :: struct($Kind: typeid) {
	kind:        Kind,
	title:       string,
	description: string,
}

ModifierConfigRaw :: ModifierConfigData(string)
ModifierConfig :: ModifierConfigData(ModifierKind)

ItemConfig :: struct {
	kind:   ItemKind,
	sprite: k2.Texture,
	shape:  ItemShape,
	width:  f32,
	height: f32,
	weight: f32,
	effect: CatchEffect,
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

PlayerConfigData :: struct($Sprite: typeid) {
	sprite:         Sprite,
	width:          f32,
	height:         f32,
	speed:          f32,
	floor_offset:   f32,
	squash_scale_x: f32,
	squash_scale_y: f32,
	squash_time:    f32,
}

PlayerConfigRaw :: PlayerConfigData(string)
PlayerConfig :: PlayerConfigData(k2.Texture)

SoundKind :: enum {
	CatchGood,
	CatchBad,
	GameOver,
	WaveNext,
}

SoundsConfig :: struct {
	by_kind: map[SoundKind]k2.Sound,
}

SoundConfigRaw :: struct {
	kind:  string,
	sound: string,
}

WaveConfigData :: struct($Modifier: typeid) {
	spawn_multiplier: f32,
	speed_multiplier: f32,
	duration:         f32,
	modifiers:        []Modifier,
}

WaveConfigRaw :: WaveConfigData(string)
WaveConfig :: WaveConfigData(ModifierKind)

game_config_load :: proc(allocator: runtime.Allocator) -> GameConfig {
	config_path := asset_path_required("config/game.json", "game config")
	data, os_err := os.read_entire_file(config_path, context.temp_allocator)
	if os_err != nil {
		fmt.eprintln("Failed to read the config file", config_path, os.error_string(os_err))
		panic("Failed to read the config file")
	}

	// I don't want to miss and zero-init any config value, so I'd rather double decode.
	// This validates basic shape (object/slices/required fields), the second unmarshalling checks the primitive types
	config_json: json.Value
	json_err := json.unmarshal(data, &config_json, allocator = context.temp_allocator)
	if json_err != nil {
		fmt.eprintln("Failed to decode the raw config file", json_err)
		panic("Failed to decode the raw config file")
	}
	expected_shape := type_info_of(GameConfigRaw)
	if err, shape_ok := config_validate_shape(config_json, expected_shape, "game_config");
	   !shape_ok {
		fmt.eprintln(err)
		panic("Invalid config")
	}

	raw_config: GameConfigRaw
	json_err = json.unmarshal(data, &raw_config, allocator = context.temp_allocator)
	if json_err != nil {
		fmt.eprintln("Failed to decode the config file", json_err)
		panic("Failed to decode the config file")
	}

	last_write_at, time_err := os.last_write_time_by_name(config_path)
	if time_err != nil {
		fmt.eprintln("Failed to read config's write time", config_path, os.error_string(time_err))
		panic("Failed to read the config's write time")
	}

	return parse_game_config(allocator, raw_config, last_write_at)
}

game_config_reload :: proc(allocator: runtime.Allocator, game_config: ^GameConfig) -> bool {
	config_path := asset_path_required("config/game.json", "game_config")
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
		game_config_destroy(game_config)
		free_all(allocator)
		game_config^ = game_config_load(allocator)
		return true
	} else {
		return false
	}
}

config_validate_shape :: proc(
	value: json.Value,
	type_info: ^reflect.Type_Info,
	path: string,
) -> (
	err_message: string,
	shape_ok: bool,
) {
	if _, is_null := value.(json.Null); is_null {
		return fmt.tprintf("Invalid %v: value must not be null", path), false
	}

	info := reflect.type_info_base(type_info)
	#partial switch type in info.variant {
	// Struct should match json object
	case reflect.Type_Info_Struct:
		object, object_ok := value.(json.Object)
		if !object_ok {
			return fmt.tprintf("Invalid %v: expected object", path), false
		}

		// Verify that we have all the required fields (of expected shapes)
		object_map := (map[string]json.Value)(object)
		for field in reflect.struct_fields_zipped(info.id) {
			// Special "using field". Treat the "nested" fields as if they live directly on this object
			if field.is_using && field.name == "_" {
				if child_message, child_ok := config_validate_shape(value, field.type, path);
				   !child_ok {
					return child_message, false
				}
			} else {
				// Normal (required) field
				name := field.name
				field_value, found := object_map[name]
				if !found {
					return fmt.tprintf("Invalid %v: missing required field '%v'", path, name),
						false
				}

				if child_message, child_ok := config_validate_shape(
					field_value,
					field.type,
					fmt.tprintf("%v.%v", path, name),
				); !child_ok {
					return child_message, false
				}
			}
		}
	// Slice should match json array
	case reflect.Type_Info_Slice:
		array, array_ok := value.(json.Array)
		if !array_ok {
			return fmt.tprintf("Invalid %v: expected array", path), false
		}
		// Verify that all the children have expected shape
		for item, i in array {
			if child_message, child_ok := config_validate_shape(
				item,
				type.elem,
				fmt.tprintf("%v[%v]", path, i),
			); !child_ok {
				return child_message, false
			}
		}
	}

	return "", true
}

parse_game_config :: proc(
	allocator: runtime.Allocator,
	raw: GameConfigRaw,
	updated_at: time.Time,
) -> GameConfig {
	item_pool := parse_item_pool_config(raw.item_pool)
	modifiers := parse_modifiers_config(allocator, raw.modifiers)

	return GameConfig {
		background = parse_background_config(allocator, raw.background),
		cards = parse_cards_config(raw.cards),
		difficulties = parse_difficulties_config(allocator, raw.difficulties),
		effects = raw.effects,
		fonts = parse_fonts_config(allocator, raw.fonts),
		hud = parse_hud_config(raw.hud),
		item_pool = item_pool,
		modifier_effects = parse_modifier_effects_config(raw.modifier_effects),
		modifiers = modifiers,
		player = parse_player_config(raw.player),
		waves = parse_waves_config(allocator, raw.waves, modifiers),
		items = parse_items_config(allocator, raw.items, item_pool.good_to_bad_ratio),
		sounds = parse_sound_config(allocator, raw.sounds),
		updated_at = updated_at,
	}
}

parse_background_config :: proc(
	allocator: runtime.Allocator,
	raw: []BackgroundPieceConfigRaw,
) -> BackgroundConfig {
	if len(raw) == 0 {
		fmt.eprintln("Invalid background config: background must be non-empty")
		panic("Invalid background config")
	}

	pieces := make(map[BackgroundKind]BackgroundPieceConfig, allocator)
	for piece in raw {
		def := parse_background_piece_def(&pieces, piece)
		map_insert(&pieces, def.kind, def)
	}

	if !(.Floor in pieces) || !(.Wall in pieces) || !(.Window in pieces) {
		fmt.eprintln("Invalid background config: floor, wall, and window pieces are required")
		panic("Invalid background config")
	}

	return BackgroundConfig{pieces}
}

parse_background_piece_def :: proc(
	pieces: ^map[BackgroundKind]BackgroundPieceConfig,
	raw: BackgroundPieceConfigRaw,
) -> BackgroundPieceConfig {
	kind, kind_ok := background_kind_from_string(raw.kind).?
	if !kind_ok {
		fmt.eprintfln("Invalid background config: unknown piece kind '%v'", raw.kind)
		panic("Invalid background config")
	}
	if kind in pieces {
		fmt.eprintfln("Invalid background config: duplicate piece kind '%v'", raw.kind)
		panic("Invalid background config")
	}

	return BackgroundPieceConfig {
		kind = kind,
		sprite = load_texture_from(raw.sprite),
		width = raw.width,
		height = raw.height,
	}
}

parse_cards_config :: proc(config: CardsConfigRaw) -> CardsConfig {
	return CardsConfig {
		gap = config.gap,
		sprite = load_texture_from(config.sprite),
		width = config.width,
		height = config.height,
		title_box = config.title_box,
		description_box = config.description_box,
	}
}

parse_difficulties_config :: proc(
	allocator: runtime.Allocator,
	raw: []DifficultyConfigRaw,
) -> [Difficulty]DifficultyConfig {
	if len(raw) == 0 {
		fmt.eprintln("Invalid difficulties config: difficulties must be non-empty")
		panic("Invalid difficulties config")
	}

	configs: [Difficulty]DifficultyConfig
	seen: [Difficulty]bool
	for difficulty in raw {
		parse_difficulty(allocator, &configs, &seen, difficulty)
	}

	if !seen[.Easy] || !seen[.Medium] || !seen[.Hard] {
		fmt.eprintln(
			"Invalid difficulties config: easy, medium, and hard difficulties are required",
		)
		panic("Invalid difficulties config")
	}

	return configs
}

parse_difficulty :: proc(
	allocator: runtime.Allocator,
	configs: ^[Difficulty]DifficultyConfig,
	seen: ^[Difficulty]bool,
	difficulty: DifficultyConfigRaw,
) {
	kind, kind_ok := difficulty_from_string(difficulty.kind).?
	if !kind_ok {
		fmt.eprintfln("Invalid difficulty config: unknown difficulty kind '%v'", difficulty.kind)
		panic("Invalid difficulty config")
	}
	if seen[kind] {
		fmt.eprintfln("Invalid difficulty config: duplicate difficulty kind '%v'", difficulty.kind)
		panic("Invalid difficulty config")
	}

	label := strings.clone(difficulty.label, allocator)
	configs[kind] = DifficultyConfig {
		kind           = kind,
		label          = label,
		spawn_interval = difficulty.spawn_interval,
		item_speed     = difficulty.item_speed,
		max_active     = difficulty.max_active,
		lives          = difficulty.lives,
	}
	seen[kind] = true
}

parse_fonts_config :: proc(allocator: runtime.Allocator, raw: []FontConfigRaw) -> FontsConfig {
	if len(raw) == 0 {
		fmt.eprintln("Invalid fonts config: fonts must be non-empty")
		panic("Invalid fonts config")
	}

	by_kind := make(map[FontKind]FontConfig, allocator)
	for font in raw {
		def := parse_font_def(&by_kind, font)
		map_insert(&by_kind, def.kind, def)
	}

	if !(.H1 in by_kind) || !(.P in by_kind) {
		fmt.eprintln("Invalid fonts config: h1 and p fonts are required")
		panic("Invalid fonts config")
	}

	return FontsConfig{by_kind = by_kind}
}

parse_font_def :: proc(by_kind: ^map[FontKind]FontConfig, raw: FontConfigRaw) -> FontConfig {
	kind, kind_ok := font_kind_from_string(raw.kind).?
	if !kind_ok {
		fmt.eprintfln("Invalid fonts config: unknown font kind '%v'", raw.kind)
		panic("Invalid fonts config")
	}
	if kind in by_kind {
		fmt.eprintfln("Invalid fonts config: duplicate font kind '%v'", raw.kind)
		panic("Invalid fonts config")
	}

	return FontConfig{kind = kind, font = load_font_from(raw.font, raw.size), size = raw.size}
}

parse_hud_config :: proc(raw: HudConfigRaw) -> HudConfig {
	return HudConfig {
		margin = raw.margin,
		lives_sprite = load_texture_from(raw.lives_sprite),
		lives_gap = raw.lives_gap,
		lives_width = raw.lives_width,
		lives_height = raw.lives_height,
	}
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

parse_modifier_effects_config :: proc(raw: ModifierEffectsConfigRaw) -> ModifierEffectsConfig {
	return ModifierEffectsConfig {
		prestige_preference_item = parse_modifier_effect_item(
			raw.prestige_preference_item,
			"prestige_preference_item",
		),
		tech_stack_preference_item = parse_modifier_effect_item(
			raw.tech_stack_preference_item,
			"tech_stack_preference_item",
		),
		compensation_preference_item = parse_modifier_effect_item(
			raw.compensation_preference_item,
			"compensation_preference_item",
		),
		remote_work_preference_item = parse_modifier_effect_item(
			raw.remote_work_preference_item,
			"remote_work_preference_item",
		),
		add_pet_project_catch_number = raw.add_pet_project_catch_number,
		ask_for_referral_weight_multiplier = raw.ask_for_referral_weight_multiplier,
		file_unemployment_lives_delta = raw.file_unemployment_lives_delta,
		give_conference_talk_margin_multiplier = raw.give_conference_talk_margin_multiplier,
		give_conference_talk_magnet_multiplier = raw.give_conference_talk_magnet_multiplier,
		hiring_freeze_item_speed_multiplier = raw.hiring_freeze_item_speed_multiplier,
		burnout_item_speed_multiplier = raw.burnout_item_speed_multiplier,
		burnout_score_base_multiplier = raw.burnout_score_base_multiplier,
		lower_quality_bar_ratio_multiplier = raw.lower_quality_bar_ratio_multiplier,
		lower_quality_bar_lives_delta = raw.lower_quality_bar_lives_delta,
		tighten_cv_ratio_multiplier = raw.tighten_cv_ratio_multiplier,
		tighten_cv_score_base_multiplier = raw.tighten_cv_score_base_multiplier,
		spray_and_pray_ratio_multiplier = raw.spray_and_pray_ratio_multiplier,
		spray_and_pray_score_base_divisor = raw.spray_and_pray_score_base_divisor,
	}
}

parse_modifier_effect_item :: proc(raw: string, field: string) -> ItemKind {
	kind, ok := kind_from_string(raw).?
	if !ok {
		fmt.eprintfln(
			"Invalid modifier effects config: unknown item kind '%v' for '%v'",
			raw,
			field,
		)
		panic("Invalid modifier effects config")
	}
	return kind
}

parse_modifiers_config :: proc(
	allocator: runtime.Allocator,
	raw: []ModifierConfigRaw,
) -> ModifiersConfig {
	if len(raw) == 0 {
		fmt.eprintln("Invalid modifiers config: modifiers must be non-empty")
		panic("Invalid modifiers config")
	}

	by_kind := make(map[ModifierKind]ModifierConfig, allocator)
	for modifier in raw {
		def := parse_modifier_def(allocator, &by_kind, modifier)
		map_insert(&by_kind, def.kind, def)
	}

	return ModifiersConfig{by_kind = by_kind}
}

parse_modifier_def :: proc(
	allocator: runtime.Allocator,
	by_kind: ^map[ModifierKind]ModifierConfig,
	raw: ModifierConfigRaw,
) -> ModifierConfig {
	kind, kind_ok := modifier_kind_from_string(raw.kind).?
	if !kind_ok {
		fmt.eprintfln("Invalid modifier config: unknown modifier kind '%v'", raw.kind)
		panic("Invalid modifier config")
	}
	if kind in by_kind {
		fmt.eprintfln("Invalid modifier config: duplicate modifier kind '%v'", raw.kind)
		panic("Invalid modifier config")
	}

	return ModifierConfig {
		kind = kind,
		title = strings.clone(raw.title, allocator),
		description = strings.clone(raw.description, allocator),
	}
}

// Fill out item catalog so we don't have to recalculate the weights for each random generation
parse_items_config :: proc(
	allocator: runtime.Allocator,
	raw: []ItemConfigRaw,
	good_to_bad_ratio: f32,
) -> map[ItemKind]ItemConfig {
	if len(raw) == 0 {
		fmt.eprintln("Invalid items config: items must be non-empty")
		panic("Invalid items config")
	}

	by_kind := make(map[ItemKind]ItemConfig, allocator)
	for item in raw {
		def := parse_item_def(&by_kind, item)
		if item.is_good {
			def.effect = GoodItemCaught {
				points = item.points,
			}
		} else {
			def.effect = BadItemCaught{}
		}
		map_insert(&by_kind, def.kind, def)
	}

	return by_kind
}

// Note: doesn't set the item effect
parse_item_def :: proc(by_kind: ^map[ItemKind]ItemConfig, raw: ItemConfigRaw) -> ItemConfig {
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

	return ItemConfig {
		kind = kind,
		sprite = load_texture_from(raw.sprite),
		shape = shape,
		width = raw.width,
		height = raw.height,
		weight = raw.weight,
	}
}

parse_player_config :: proc(config: PlayerConfigRaw) -> PlayerConfig {
	return PlayerConfig {
		sprite = load_texture_from(config.sprite),
		width = config.width,
		height = config.height,
		speed = config.speed,
		floor_offset = config.floor_offset,
		squash_scale_x = config.squash_scale_x,
		squash_scale_y = config.squash_scale_y,
		squash_time = config.squash_time,
	}
}

parse_sound_config :: proc(allocator: runtime.Allocator, raw: []SoundConfigRaw) -> SoundsConfig {
	if len(raw) == 0 {
		fmt.eprintln("Invalid sounds config: sounds must be non-empty")
		panic("Invalid sounds config")
	}

	by_kind := make(map[SoundKind]k2.Sound, allocator)
	for sound in raw {
		kind, kind_ok := sound_kind_from_string(sound.kind).?
		if !kind_ok {
			fmt.eprintfln("Invalid sounds config: unknown sound kind '%v'", sound.kind)
			panic("Invalid sounds config")
		}
		if kind in by_kind {
			fmt.eprintfln("Invalid sounds config: duplicate sound kind '%v'", sound.kind)
			panic("Invalid sounds config")
		}

		map_insert(&by_kind, kind, load_sound_from(sound.sound))
	}

	if !(.CatchGood in by_kind) ||
	   !(.CatchBad in by_kind) ||
	   !(.GameOver in by_kind) ||
	   !(.WaveNext in by_kind) {
		fmt.eprintln("Invalid sounds config: all the sounds are required")
		panic("Invalid sounds config")
	}

	return SoundsConfig{by_kind = by_kind}
}

parse_waves_config :: proc(
	allocator: runtime.Allocator,
	raw: []WaveConfigRaw,
	modifiers: ModifiersConfig,
) -> []WaveConfig {
	if len(raw) == 0 {
		fmt.eprintln("Invalid waves config: waves must be non-empty")
		panic("Invalid waves config")
	}

	config := make([]WaveConfig, len(raw), allocator)
	for wave, wave_index in raw {
		parsed_modifiers := make([]ModifierKind, len(wave.modifiers), allocator)
		for modifier, modifier_index in wave.modifiers {
			kind, kind_ok := modifier_kind_from_string(modifier).?
			if !kind_ok {
				fmt.eprintfln(
					"Invalid waves config: wave %v uses unknown modifier kind '%v'",
					wave_index,
					modifier,
				)
				panic("Invalid waves config")
			}
			if !(kind in modifiers.by_kind) {
				fmt.eprintfln(
					"Invalid waves config: wave %v references missing modifier '%v'",
					wave_index,
					modifier,
				)
				panic("Invalid waves config")
			}
			parsed_modifiers[modifier_index] = kind
		}

		if len(parsed_modifiers) < 3 {
			fmt.eprintfln(
				"Invalid waves config: wave %v must have at least 3 modifiers",
				wave_index,
			)
			panic("Invalid waves config")
		}

		config[wave_index] = WaveConfig {
			spawn_multiplier = wave.spawn_multiplier,
			speed_multiplier = wave.speed_multiplier,
			duration         = wave.duration,
			modifiers        = parsed_modifiers,
		}
	}
	return config
}

load_font_from :: proc(font_name: string, size: int) -> k2.Font {
	// TODO: This won't work from the bin (or any non root dir)
	path := asset_path_required(
		strings.concatenate({"fonts/", font_name, ".ttf"}, context.temp_allocator),
		font_name,
	)

	font_codepoints := utf8.string_to_runes(
		"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz1234567890-., :'",
		context.temp_allocator,
	)

	return k2.load_static_font_from_file(path, f32(size), font_codepoints)
}

load_sound_from :: proc(sound_name: string) -> k2.Sound {
	// TODO: This won't work from the bin (or any non root dir)
	path := asset_path_required(
		strings.concatenate({"sounds/", sound_name, ".wav"}, context.temp_allocator),
		sound_name,
	)
	return k2.load_sound_from_file(path)
}

load_texture_from :: proc(sprite_name: string) -> k2.Texture {
	// TODO: This won't work from the bin (or any non root dir)
	path := asset_path_required(
		strings.concatenate({"sprites/", sprite_name, ".png"}, context.temp_allocator),
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

background_kind_from_string :: proc(raw: string) -> Maybe(BackgroundKind) {
	switch raw {
	case "floor":
		return .Floor
	case "wall":
		return .Wall
	case "window":
		return .Window
	}
	return nil
}

sound_kind_from_string :: proc(raw: string) -> Maybe(SoundKind) {
	switch raw {
	case "catch-good":
		return .CatchGood
	case "catch-bad":
		return .CatchBad
	case "game-over":
		return .GameOver
	case "wave-next":
		return .WaveNext
	}
	return nil
}

difficulty_from_string :: proc(raw: string) -> Maybe(Difficulty) {
	switch raw {
	case "easy":
		return .Easy
	case "medium":
		return .Medium
	case "hard":
		return .Hard
	}
	return nil
}

modifier_kind_from_string :: proc(raw: string) -> Maybe(ModifierKind) {
	switch raw {
	case "prestige":
		return .Prestige
	case "tech-stack":
		return .TechStack
	case "compensation":
		return .Compensation
	case "remote-work":
		return .RemoteWork
	case "add-pet-project":
		return .AddPetProject
	case "ask-for-referral":
		return .AskForReferral
	case "hiring-freeze":
		return .HiringFreeze
	case "file-unemployment":
		return .FileUnemployment
	case "give-conference-talk":
		return .GiveConferenceTalk
	case "burnout":
		return .Burnout
	case "leetcode-grind":
		return .LeetCodeGrind
	case "lower-quality-bar":
		return .LowerQualityBar
	case "tighten-cv":
		return .TightenCV
	case "spray-and-pray":
		return .SprayAndPray
	case "automate-pipeline":
		return .AutomatePipeline
	case "blind-application":
		return .BlindApplication
	case "give-up":
		return .GiveUp
	case "recruiter-spam":
		return .RecruiterSpam
	case "imposter-syndrome":
		return .ImposterSyndrome
	case "bonus":
		return .Bonus
	case "continue":
		return .Continue
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

font_kind_from_string :: proc(raw: string) -> Maybe(FontKind) {
	switch raw {
	case "h1":
		return .H1
	case "p":
		return .P
	}
	return nil
}

asset_path_required :: proc(relative: string, label: string) -> string {
	path, err := filepath.join({"assets", relative}, context.temp_allocator)
	if err != nil {
		fmt.eprintln("Failed to allocate asset path")
		panic("Failed to allocate asset path")
	}

	if os.is_file(path) do return path

	fmt.eprintfln("Failed to find asset '%v': %v", label, path)
	panic("Asset not found")
}

// TODO: This is fine for now because we recreate all
game_config_destroy :: proc(game_config: ^GameConfig) {
	for _, font in game_config.fonts.by_kind {
		k2.destroy_font(font.font)
	}

	k2.destroy_texture(game_config.cards.sprite)
	k2.destroy_texture(game_config.player.sprite)

	for _, item in game_config.items {
		k2.destroy_texture(item.sprite)
	}

	for _, piece in game_config.background.pieces {
		k2.destroy_texture(piece.sprite)
	}

	k2.destroy_texture(game_config.hud.lives_sprite)

	for _, sound in game_config.sounds.by_kind {
		k2.destroy_sound(sound)
	}
}


@(test)
game_config_json_has_expected_shape :: proc(t: ^testing.T) {
	_ = t
	config_path := asset_path_required("config/game.json", "game config")
	data, os_err := os.read_entire_file(config_path, context.temp_allocator)
	assert(os_err == nil)

	value: json.Value
	json_err := json.unmarshal(data, &value, allocator = context.temp_allocator)
	assert(json_err == nil)

	_, ok := config_validate_shape(value, type_info_of(GameConfigRaw), "game-config")
	assert(ok)
}

ConfigShapeTest :: struct {
	value:  f32,
	nested: ConfigShapeNestedTest,
	items:  []ConfigShapeNestedTest,
}

ConfigShapeNestedTest :: struct {
	name: string,
}

@(test)
config_validate_shape_accepts_present_fields :: proc(t: ^testing.T) {
	_ = t

	value: json.Value
	err := json.unmarshal_string(
		`{"value":0,"nested":{"name":"one"},"items":[{"name":"two"}]}`,
		&value,
		allocator = context.temp_allocator,
	)
	assert(err == nil)

	_, ok := config_validate_shape(value, type_info_of(ConfigShapeTest), "test")
	assert(ok)
}

@(test)
config_validate_shape_rejects_missing_fields :: proc(t: ^testing.T) {
	_ = t
	test_config_shape_error(
		raw = `{"value":0,"items":[]}`,
		expected_error = "Invalid test: missing required field 'nested'",
	)
}

@(test)
config_validate_shape_rejects_null_fields :: proc(t: ^testing.T) {
	_ = t
	test_config_shape_error(
		raw = `{"value":0,"nested":null,"items":[]}`,
		expected_error = "Invalid test.nested: value must not be null",
	)
}

@(test)
config_validate_shape_rejects_missing_nested_fields :: proc(t: ^testing.T) {
	_ = t
	test_config_shape_error(
		raw = `{"value":0,"nested":{"wrong":1},"items":[]}`,
		expected_error = "Invalid test.nested: missing required field 'name'",
	)
}

@(test)
config_validate_shape_rejects_wrong_object_type :: proc(t: ^testing.T) {
	_ = t
	test_config_shape_error(
		raw = `{"value":0,"nested":1,"items":[]}`,
		expected_error = "Invalid test.nested: expected object",
	)
}

@(test)
config_validate_shape_rejects_wrong_slice_type :: proc(t: ^testing.T) {
	_ = t
	test_config_shape_error(
		raw = `{"value":0,"nested":{"name":"one"},"items":{"wrong": 1}}`,
		expected_error = "Invalid test.items: expected array",
	)
}

@(test)
config_validate_shape_rejects_wrong_item :: proc(t: ^testing.T) {
	_ = t
	test_config_shape_error(
		raw = `{"value":0,"nested":{"name":"one"},"items":[42]}`,
		expected_error = "Invalid test.items[0]: expected object",
	)
}

test_config_shape_error :: proc(raw: string, expected_error: string) {
	value: json.Value
	err := json.unmarshal_string(raw, &value, allocator = context.temp_allocator)
	assert(err == nil)

	message, ok := config_validate_shape(value, type_info_of(ConfigShapeTest), "test")
	assert(!ok)
	assert(message == expected_error)
}
