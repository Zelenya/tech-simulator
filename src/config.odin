package game

import k2 "../karl2d"
import "base:runtime"
import "core:encoding/json"
import "core:fmt"
import "core:math"
import "core:os"
import "core:path/filepath"
import "core:reflect"
import "core:strings"
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
	attempted_at:     time.Time,
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
	leet_code_ratio_multiplier:             f32,
	lower_quality_bar_ratio_multiplier:     f32,
	lower_quality_bar_lives_delta:          i8,
	tighten_cv_ratio_multiplier:            f32,
	tighten_cv_score_base_multiplier:       u32,
	spray_and_pray_ratio_multiplier:        f32,
	spray_and_pray_score_base_divisor:      u32,
	blind_application_hidden_ratio:         f32,
	give_up_timer:                          f32,
	recruiter_spawn_timer:                  f32,
	recruiter_spawn_rate:                   f32,
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
	CatchBad,
	CatchGood,
	CatchDull,
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

ConfigSnapshot :: struct {
	arena: runtime.Arena,
	value: GameConfig,
}

@(private = "file")
game_config_snapshot_create :: proc(gpa: runtime.Allocator) -> ^ConfigSnapshot {
	snapshot := new(ConfigSnapshot, gpa)
	snapshot.arena.backing_allocator = gpa
	return snapshot
}

game_config_snapshot_destroy :: proc(snapshot: ^ConfigSnapshot) {
	if snapshot == nil do return

	backing_allocator := snapshot.arena.backing_allocator
	game_config_destroy(&snapshot.value)
	runtime.arena_destroy(&snapshot.arena)
	free(snapshot, backing_allocator)
}

game_config_load :: proc(gpa: runtime.Allocator) -> ^ConfigSnapshot {
	snapshot := game_config_snapshot_create(gpa)
	config_allocator := runtime.arena_allocator(&snapshot.arena)

	path, path_err := asset_path_required("config/game.json", "game config")
	if path_err != nil do panic("Failed to load game config")

	updated_at, time_err := os.last_write_time_by_name(path)
	if time_err != nil {
		fmt.eprintfln("Failed to read config write time '%v': %v", path, os.error_string(time_err))
		panic("Failed to load game config")
	}

	raw, maybe_error := game_config_read_raw(path)
	if message, failed := maybe_error.?; failed {
		fmt.eprintln(message)
		panic("Failed to load game config")
	}

	new_config, parse_error := parse_game_config(config_allocator, raw, updated_at)
	if message, failed := parse_error.?; failed {
		fmt.eprintln(message)
		panic("Failed to load game config")
	} else {
		snapshot.value = new_config
	}

	return snapshot
}

ConfigReloadStatus :: enum {
	Unchanged,
	ReadyToReload,
	Rejected,
}

game_config_reload :: proc(
	current: ^ConfigSnapshot,
) -> (
	candidate: ^ConfigSnapshot,
	status: ConfigReloadStatus,
) {
	path, path_err := asset_path_required("config/game.json", "game config")
	if path_err != nil do panic("Failed to load game config")

	last_write_at, time_err := os.last_write_time_by_name(path)
	if time_err != nil {
		fmt.eprintfln("Failed to read config write time '%v': %v", path, os.error_string(time_err))
		return nil, .Rejected
	}

	if last_write_at == current.value.attempted_at {
		return nil, .Unchanged
	}

	// Record this before attempting the read (not to retry the same broken edit on every frame)
	current.value.attempted_at = last_write_at

	raw, maybe_error := game_config_read_raw(path)
	if message, failed := maybe_error.?; failed {
		fmt.eprintln(message)
		return nil, .Rejected
	}

	gpa := current.arena.backing_allocator
	candidate = game_config_snapshot_create(gpa)
	candidate_allocator := runtime.arena_allocator(&candidate.arena)

	new_config, parse_error := parse_game_config(candidate_allocator, raw, last_write_at)
	if message, failed := parse_error.?; failed {
		fmt.eprintln(message)
		game_config_snapshot_destroy(candidate)
		return nil, .Rejected
	} else {
		candidate.value = new_config
	}

	return candidate, .ReadyToReload
}

@(private = "file")
game_config_read_raw :: proc(path: string) -> (raw: GameConfigRaw, err: Maybe(string)) {
	data, os_err := os.read_entire_file(path, context.temp_allocator)
	if os_err != nil {
		return {}, fmt.tprintf("Failed to read required config '%v': %v", path, os.error_string(os_err))
	}

	return game_config_decode_raw(data)
}

@(private = "file")
game_config_decode_raw :: proc(data: []byte) -> (raw: GameConfigRaw, err: Maybe(string)) {
	// I don't want to miss and zero-init any config value, so I'd rather double decode.
	// This validates basic shape (object/slices/required fields), the second unmarshalling checks the primitive types
	config_json: json.Value
	json_err := json.unmarshal(data, &config_json, allocator = context.temp_allocator)
	if json_err != nil {
		return {}, fmt.tprintf("Failed to decode config JSON: %v", json_err)
	}

	if message, shape_ok := config_validate_shape(
		config_json,
		type_info_of(GameConfigRaw),
		"game_config",
	); !shape_ok {
		return {}, message
	}

	raw_config: GameConfigRaw
	json_err = json.unmarshal(data, &raw_config, allocator = context.temp_allocator)
	if json_err != nil {
		return {}, fmt.tprintf("Failed to decode typed config: %v", json_err)
	}

	return raw_config, nil
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
) -> (
	config: GameConfig,
	err: Maybe(string),
) {
	defer if err != nil {
		game_config_destroy(&config)
	}

	config.cards = parse_cards_config(raw.cards) or_return
	config.difficulties = parse_difficulties_config(allocator, raw.difficulties) or_return
	config.effects = raw.effects
	config.hud = parse_hud_config(raw.hud) or_return
	config.modifiers = parse_modifiers_config(allocator, raw.modifiers) or_return
	config.player = parse_player_config(raw.player) or_return
	config.waves = parse_waves_config(allocator, raw.waves, config.modifiers) or_return
	config.item_pool = parse_item_pool_config(
		raw.item_pool,
		raw.items,
		raw.modifier_effects,
	) or_return

	// These allocate something that needs to be cleaned up in case of failure
	config.background, err = parse_background_config(allocator, raw.background)
	if err != nil do return config, err
	config.fonts, err = parse_fonts_config(allocator, raw.fonts)
	if err != nil do return config, err
	config.items, err = parse_items_config(allocator, raw.items)
	if err != nil do return config, err
	config.sounds, err = parse_sound_config(allocator, raw.sounds)
	if err != nil do return config, err

	config.modifier_effects = parse_modifier_effects_config(
		raw.modifier_effects,
		config.items,
	) or_return

	config.updated_at = updated_at
	config.attempted_at = updated_at
	return config, nil
}

parse_background_config :: proc(
	allocator: runtime.Allocator,
	raw: []BackgroundPieceConfigRaw,
) -> (
	config: BackgroundConfig,
	err: Maybe(string),
) {
	if len(raw) == 0 {
		return {}, "Invalid background config: background must be non-empty"
	}

	pieces := make(map[BackgroundKind]BackgroundPieceConfig, allocator)
	config.pieces = pieces
	for piece in raw {
		kind, kind_ok := background_kind_from_string(piece.kind).?
		if !kind_ok do return config, fmt.tprintf("Invalid background config: unknown piece kind '%v'", piece.kind)
		if kind in pieces do return config, fmt.tprintf("Invalid background config: duplicate piece kind '%v'", piece.kind)
		def, parse_err := parse_background_piece_def(piece)
		if message, failed := parse_err.?; failed do return config, message
		map_insert(&pieces, def.kind, def)
	}

	if !(.Floor in pieces) || !(.Wall in pieces) || !(.Window in pieces) {
		return config, "Invalid background config: floor, wall, and window pieces are required"
	}

	return BackgroundConfig{pieces}, nil
}

parse_background_piece_def :: proc(
	raw: BackgroundPieceConfigRaw,
) -> (
	config: BackgroundPieceConfig,
	err: Maybe(string),
) {
	kind, kind_ok := background_kind_from_string(raw.kind).?
	if !kind_ok {
		return {}, fmt.tprintf("Invalid background config: unknown piece kind '%v'", raw.kind)
	}
	sprite := load_texture_from(raw.sprite) or_return
	return BackgroundPieceConfig {
			kind = kind,
			sprite = sprite,
			width = raw.width,
			height = raw.height,
		},
		nil
}

parse_cards_config :: proc(config: CardsConfigRaw) -> (parsed: CardsConfig, err: Maybe(string)) {
	sprite := load_texture_from(config.sprite) or_return
	return CardsConfig {
			gap = config.gap,
			sprite = sprite,
			width = config.width,
			height = config.height,
			title_box = config.title_box,
			description_box = config.description_box,
		},
		nil
}

parse_difficulties_config :: proc(
	allocator: runtime.Allocator,
	raw: []DifficultyConfigRaw,
) -> (
	configs: [Difficulty]DifficultyConfig,
	err: Maybe(string),
) {
	if len(raw) == 0 {
		return {}, "Invalid difficulties config: difficulties must be non-empty"
	}

	local_configs: [Difficulty]DifficultyConfig
	seen: [Difficulty]bool
	for difficulty in raw {
		parse_difficulty(allocator, &local_configs, &seen, difficulty) or_return
	}

	if !seen[.Easy] || !seen[.Medium] || !seen[.Hard] {
		return {}, "Invalid difficulties config: easy, medium, and hard difficulties are required"
	}

	return local_configs, nil
}

parse_difficulty :: proc(
	allocator: runtime.Allocator,
	configs: ^[Difficulty]DifficultyConfig,
	seen: ^[Difficulty]bool,
	difficulty: DifficultyConfigRaw,
) -> Maybe(string) {
	kind, kind_ok := difficulty_from_string(difficulty.kind).?
	if !kind_ok {
		return fmt.tprintf(
			"Invalid difficulty config: unknown difficulty kind '%v'",
			difficulty.kind,
		)
	}
	if seen[kind] {
		return fmt.tprintf(
			"Invalid difficulty config: duplicate difficulty kind '%v'",
			difficulty.kind,
		)
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
	return nil
}

parse_fonts_config :: proc(
	allocator: runtime.Allocator,
	raw: []FontConfigRaw,
) -> (
	config: FontsConfig,
	err: Maybe(string),
) {
	if len(raw) == 0 {
		return {}, "Invalid fonts config: fonts must be non-empty"
	}

	by_kind := make(map[FontKind]FontConfig, allocator)
	config.by_kind = by_kind
	for font in raw {
		kind, kind_ok := font_kind_from_string(font.kind).?
		if !kind_ok do return config, fmt.tprintf("Invalid fonts config: unknown font kind '%v'", font.kind)
		if kind in by_kind do return config, fmt.tprintf("Invalid fonts config: duplicate font kind '%v'", font.kind)
		def, parse_err := parse_font_def(allocator, font)
		if message, failed := parse_err.?; failed do return config, message
		map_insert(&by_kind, def.kind, def)
	}

	if !(.H1 in by_kind) || !(.P in by_kind) {
		return config, "Invalid fonts config: h1 and p fonts are required"
	}

	return FontsConfig{by_kind = by_kind}, nil
}

parse_font_def :: proc(
	allocator: runtime.Allocator,
	raw: FontConfigRaw,
) -> (
	config: FontConfig,
	err: Maybe(string),
) {
	kind, kind_ok := font_kind_from_string(raw.kind).?
	if !kind_ok {
		return {}, fmt.tprintf("Invalid fonts config: unknown font kind '%v'", raw.kind)
	}

	font := load_font_from(raw.font, raw.size) or_return
	return FontConfig{kind = kind, font = font, size = raw.size}, nil
}

parse_hud_config :: proc(raw: HudConfigRaw) -> (config: HudConfig, err: Maybe(string)) {
	sprite := load_texture_from(raw.lives_sprite) or_return
	return HudConfig {
			margin = raw.margin,
			lives_sprite = sprite,
			lives_gap = raw.lives_gap,
			lives_width = raw.lives_width,
			lives_height = raw.lives_height,
		},
		nil
}

parse_item_pool_config :: proc(
	raw: ItemPoolConfig,
	items: []ItemConfigRaw,
	effects: ModifierEffectsConfigRaw,
) -> (
	config: ItemPoolConfig,
	err: Maybe(string),
) {
	if math.is_nan(raw.good_to_bad_ratio) ||
	   raw.good_to_bad_ratio < 0 ||
	   raw.good_to_bad_ratio > 1 {
		return raw, fmt.tprintf(
			"Invalid item pool config: good_to_bad_ratio must be between 0 and 1, got %v",
			raw.good_to_bad_ratio,
		)
	}

	good_weight, bad_weight: f32
	for item in items {
		if math.is_nan(item.weight) || math.is_inf(item.weight) || item.weight < 0 {
			return raw, fmt.tprintf(
				"Invalid item config: weight for '%v' must be finite and non-negative",
				item.kind,
			)
		}
		if !item.is_good {
			bad_weight += item.weight
		} else if item.points > 0 {
			good_weight += item.weight
		}
	}

	if good_weight <= 0 || math.is_inf(good_weight) {
		return raw,
			"Invalid items config: weighted spawning requires a finite, positive total good-item weight"
	}
	if bad_weight <= 0 || math.is_inf(bad_weight) {
		return raw,
			"Invalid items config: weighted spawning requires a finite, positive total bad-item weight"
	}
	return raw, nil
}

parse_modifier_effects_config :: proc(
	raw: ModifierEffectsConfigRaw,
	items: map[ItemKind]ItemConfig,
) -> (
	config: ModifierEffectsConfig,
	err: Maybe(string),
) {
	if raw.spray_and_pray_score_base_divisor == 0 {
		return {},
			"Invalid modifier effects config: spray_and_pray_score_base_divisor must be greater than zero"
	}

	ratio_multipliers := [4]f32 {
		raw.leet_code_ratio_multiplier,
		raw.lower_quality_bar_ratio_multiplier,
		raw.tighten_cv_ratio_multiplier,
		raw.spray_and_pray_ratio_multiplier,
	}
	for multiplier in ratio_multipliers {
		if math.is_nan(multiplier) || math.is_inf(multiplier) || multiplier < 0 {
			return {},
				"Invalid modifier effects config: ratio multipliers must be finite and non-negative"
		}
	}

	return ModifierEffectsConfig {
			prestige_preference_item = parse_modifier_effect_item(
				items,
				raw.prestige_preference_item,
			) or_return,
			tech_stack_preference_item = parse_modifier_effect_item(
				items,
				raw.tech_stack_preference_item,
			) or_return,
			compensation_preference_item = parse_modifier_effect_item(
				items,
				raw.compensation_preference_item,
			) or_return,
			remote_work_preference_item = parse_modifier_effect_item(
				items,
				raw.remote_work_preference_item,
			) or_return,
			add_pet_project_catch_number = raw.add_pet_project_catch_number,
			ask_for_referral_weight_multiplier = raw.ask_for_referral_weight_multiplier,
			file_unemployment_lives_delta = raw.file_unemployment_lives_delta,
			give_conference_talk_margin_multiplier = raw.give_conference_talk_margin_multiplier,
			give_conference_talk_magnet_multiplier = raw.give_conference_talk_magnet_multiplier,
			hiring_freeze_item_speed_multiplier = raw.hiring_freeze_item_speed_multiplier,
			burnout_item_speed_multiplier = raw.burnout_item_speed_multiplier,
			burnout_score_base_multiplier = raw.burnout_score_base_multiplier,
			leet_code_ratio_multiplier = raw.leet_code_ratio_multiplier,
			lower_quality_bar_ratio_multiplier = raw.lower_quality_bar_ratio_multiplier,
			lower_quality_bar_lives_delta = raw.lower_quality_bar_lives_delta,
			tighten_cv_ratio_multiplier = raw.tighten_cv_ratio_multiplier,
			tighten_cv_score_base_multiplier = raw.tighten_cv_score_base_multiplier,
			spray_and_pray_ratio_multiplier = raw.spray_and_pray_ratio_multiplier,
			spray_and_pray_score_base_divisor = raw.spray_and_pray_score_base_divisor,
			blind_application_hidden_ratio = raw.blind_application_hidden_ratio,
			give_up_timer = raw.give_up_timer,
			recruiter_spawn_rate = raw.recruiter_spawn_rate,
			recruiter_spawn_timer = raw.recruiter_spawn_timer,
		},
		nil
}

parse_modifier_effect_item :: proc(
	items: map[ItemKind]ItemConfig,
	raw: string,
) -> (
	ItemKind,
	Maybe(string),
) {
	kind, ok := kind_from_string(raw).?
	if !ok {
		return .Neutral, fmt.tprintf(
			"Invalid modifier effect item config: unknown item kind '%v'",
			raw,
		)
	}
	if kind not_in items {
		return .Neutral, fmt.tprintf(
			"Invalid modifier effect item config: item '%v' isn't defined",
			raw,
		)
	}
	return kind, nil
}

parse_modifiers_config :: proc(
	allocator: runtime.Allocator,
	raw: []ModifierConfigRaw,
) -> (
	config: ModifiersConfig,
	err: Maybe(string),
) {
	if len(raw) == 0 {
		return {}, "Invalid modifiers config: modifiers must be non-empty"
	}

	by_kind := make(map[ModifierKind]ModifierConfig, allocator)
	for modifier in raw {
		def := parse_modifier_def(allocator, modifier) or_return
		if def.kind in by_kind do return {}, fmt.tprintf("Invalid modifier config: duplicate modifier kind '%v'", modifier.kind)
		map_insert(&by_kind, def.kind, def)
	}

	return ModifiersConfig{by_kind = by_kind}, nil
}

parse_modifier_def :: proc(
	allocator: runtime.Allocator,
	raw: ModifierConfigRaw,
) -> (
	config: ModifierConfig,
	err: Maybe(string),
) {
	kind, kind_ok := modifier_kind_from_string(raw.kind).?
	if !kind_ok {
		return {}, fmt.tprintf("Invalid modifier config: unknown modifier kind '%v'", raw.kind)
	}

	return ModifierConfig {
			kind = kind,
			title = strings.clone(raw.title, allocator),
			description = strings.clone(raw.description, allocator),
		},
		nil
}

// Fill out item catalog so we don't have to recalculate the weights for each random generation
parse_items_config :: proc(
	allocator: runtime.Allocator,
	raw: []ItemConfigRaw,
) -> (
	config: map[ItemKind]ItemConfig,
	err: Maybe(string),
) {

	if len(raw) == 0 {
		return nil, "Invalid items config: items must be non-empty"
	}

	by_kind := make(map[ItemKind]ItemConfig, allocator)
	config = by_kind
	for item in raw {
		kind, kind_ok := kind_from_string(item.kind).?
		if !kind_ok do return config, fmt.tprintf("Invalid item config: unknown item kind '%v'", item.kind)
		if kind in by_kind do return config, fmt.tprintf("Invalid item config: duplicate item kind '%v'", item.kind)
		def, parse_err := parse_item_def(item)
		if message, failed := parse_err.?; failed do return config, message
		if item.is_good {
			if item.points > 0 {
				def.effect = GoodItemCaught {
					points = item.points,
				}
			} else {
				def.effect = NeutralItemCaught{}
			}
		} else {
			def.effect = BadItemCaught{}
		}
		map_insert(&by_kind, def.kind, def)
	}

	if .Neutral not_in by_kind {
		return nil, "Neutral item is missing, but it's required"
	}

	return by_kind, nil
}

// Note: doesn't set the item effect
parse_item_def :: proc(raw: ItemConfigRaw) -> (config: ItemConfig, err: Maybe(string)) {
	kind, kind_ok := kind_from_string(raw.kind).?
	if !kind_ok {
		return {}, fmt.tprintf("Invalid item config: unknown item kind '%v'", raw.kind)
	}

	shape, shape_ok := shape_from_string(raw.shape).?
	if !shape_ok {
		return {}, fmt.tprintf("Invalid item config: unknown item shape '%v'", raw.shape)
	}

	sprite := load_texture_from(raw.sprite) or_return
	return ItemConfig {
			kind = kind,
			sprite = sprite,
			shape = shape,
			width = raw.width,
			height = raw.height,
			weight = raw.weight,
		},
		nil
}

parse_player_config :: proc(
	config: PlayerConfigRaw,
) -> (
	parsed: PlayerConfig,
	err: Maybe(string),
) {
	sprite := load_texture_from(config.sprite) or_return
	return PlayerConfig {
			sprite = sprite,
			width = config.width,
			height = config.height,
			speed = config.speed,
			floor_offset = config.floor_offset,
			squash_scale_x = config.squash_scale_x,
			squash_scale_y = config.squash_scale_y,
			squash_time = config.squash_time,
		},
		nil
}

parse_sound_config :: proc(
	allocator: runtime.Allocator,
	raw: []SoundConfigRaw,
) -> (
	config: SoundsConfig,
	err: Maybe(string),
) {
	if len(raw) == 0 {
		return {}, "Invalid sounds config: sounds must be non-empty"
	}

	by_kind := make(map[SoundKind]k2.Sound, allocator)
	config.by_kind = by_kind
	for sound in raw {
		kind, kind_ok := sound_kind_from_string(sound.kind).?
		if !kind_ok {
			return config, fmt.tprintf(
				"Invalid sounds config: unknown sound kind '%v'",
				sound.kind,
			)
		}
		if kind in by_kind {
			return config, fmt.tprintf(
				"Invalid sounds config: duplicate sound kind '%v'",
				sound.kind,
			)
		}

		sound_value := load_sound_from(sound.sound) or_return
		map_insert(&by_kind, kind, sound_value)
	}

	if !(.CatchGood in by_kind) ||
	   !(.CatchBad in by_kind) ||
	   !(.CatchDull in by_kind) ||
	   !(.GameOver in by_kind) ||
	   !(.WaveNext in by_kind) {
		return config,
			"Invalid sounds config: catch-good, catch-bad, catch-dull, game-over, and wave-next are required"
	}

	return SoundsConfig{by_kind = by_kind}, nil
}

parse_waves_config :: proc(
	allocator: runtime.Allocator,
	raw: []WaveConfigRaw,
	modifiers: ModifiersConfig,
) -> (
	config: []WaveConfig,
	err: Maybe(string),
) {
	if len(raw) == 0 {
		return nil, "Invalid waves config: waves must be non-empty"
	}

	local_config := make([]WaveConfig, len(raw), allocator)
	for wave, wave_index in raw {
		parsed_modifiers := make([]ModifierKind, len(wave.modifiers), allocator)
		for modifier, modifier_index in wave.modifiers {
			kind, kind_ok := modifier_kind_from_string(modifier).?
			if !kind_ok {
				return nil, fmt.tprintf(
					"Invalid waves config: wave %v uses unknown modifier kind '%v'",
					wave_index,
					modifier,
				)
			}
			if !(kind in modifiers.by_kind) {
				return nil, fmt.tprintf(
					"Invalid waves config: wave %v references missing modifier '%v'",
					wave_index,
					modifier,
				)
			}
			parsed_modifiers[modifier_index] = kind
		}

		if len(parsed_modifiers) < 3 {
			return nil, fmt.tprintf(
				"Invalid waves config: wave %v must have at least 3 modifiers",
				wave_index,
			)
		}

		local_config[wave_index] = WaveConfig {
			spawn_multiplier = wave.spawn_multiplier,
			speed_multiplier = wave.speed_multiplier,
			duration         = wave.duration,
			modifiers        = parsed_modifiers,
		}
	}
	return local_config, nil
}

load_font_from :: proc(font_name: string, size: int) -> (font: k2.Font, err: Maybe(string)) {
	// TODO: This won't work from the bin (or any non root dir)
	path := asset_path_required(
		strings.concatenate({"fonts/", font_name, ".ttf"}, context.temp_allocator),
		font_name,
	) or_return

	font_codepoints := utf8.string_to_runes(
		"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz1234567890-., :'",
		context.temp_allocator,
	)

	font = k2.load_static_font_from_file(path, f32(size), font_codepoints)
	if font == k2.FONT_NONE do return {}, fmt.tprintf("Failed to load font '%v'", path)
	return font, nil
}

load_sound_from :: proc(sound_name: string) -> (sound: k2.Sound, err: Maybe(string)) {
	// TODO: This won't work from the bin (or any non root dir)
	path := asset_path_required(
		strings.concatenate({"sounds/", sound_name, ".wav"}, context.temp_allocator),
		sound_name,
	) or_return
	sound = k2.load_sound_from_file(path)
	if sound == k2.SOUND_NONE do return {}, fmt.tprintf("Failed to load sound '%v'", path)
	return sound, nil
}

load_texture_from :: proc(sprite_name: string) -> (texture: k2.Texture, err: Maybe(string)) {
	// TODO: This won't work from the bin (or any non root dir)
	path := asset_path_required(
		strings.concatenate({"sprites/", sprite_name, ".png"}, context.temp_allocator),
		sprite_name,
	) or_return
	texture = k2.load_texture_from_file(path)
	if texture.width <= 0 || texture.height <= 0 {
		return {}, fmt.tprintf("Invalid texture config: failed to load sprite '%v' from %v (w: %v, h: %v)", sprite_name, path, texture.width, texture.height)
	}
	return texture, nil
}

kind_from_string :: proc(raw: string) -> Maybe(ItemKind) {
	switch raw {
	case "neutral":
		return .Neutral
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
	case "catch-bad":
		return .CatchBad
	case "catch-good":
		return .CatchGood
	case "catch-dull":
		return .CatchDull
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

asset_path_required :: proc(
	relative: string,
	label: string,
) -> (
	path: string,
	err: Maybe(string),
) {
	joined, join_err := filepath.join({"assets", relative}, context.temp_allocator)
	if join_err != nil {
		return "", "Failed to allocate asset path"
	}
	path = joined

	if os.is_file(path) do return path, nil

	return "", fmt.tprintf("Failed to find asset '%v': %v", label, path)
}

destroy_background_config :: proc(config: ^BackgroundConfig) {
	for _, piece in config.pieces {
		k2.destroy_texture(piece.sprite)
	}
}

destroy_fonts_config :: proc(config: ^FontsConfig) {
	for _, font in config.by_kind {
		k2.destroy_font(font.font)
	}
}

destroy_item_configs :: proc(config: map[ItemKind]ItemConfig) {
	for _, item in config {
		k2.destroy_texture(item.sprite)
	}
}

destroy_sounds_config :: proc(config: ^SoundsConfig) {
	for _, sound in config.by_kind {
		k2.destroy_sound(sound)
	}
}

game_config_destroy :: proc(game_config: ^GameConfig) {
	destroy_fonts_config(&game_config.fonts)
	k2.destroy_texture(game_config.cards.sprite)
	k2.destroy_texture(game_config.player.sprite)
	destroy_item_configs(game_config.items)
	destroy_background_config(&game_config.background)
	k2.destroy_texture(game_config.hud.lives_sprite)
	destroy_sounds_config(&game_config.sounds)
}
