package game

@(require) import "core:encoding/json"
@(require) import "core:fmt"
@(require) import "core:os"
@(require) import "core:time"

when ODIN_DEBUG {

	Snapshot :: struct {
		difficulty:      Difficulty,
		// Note: pick count is the zero-based wave index
		modifier_picks:  []ModifierKind,
		score:           u32,
		lives:           i8,
		elapsed_seconds: f32,
	}

	SnapshotRaw :: struct {
		difficulty:      string,
		modifier_picks:  []string,
		score:           u32,
		lives:           i8,
		elapsed_seconds: f32,
	}

	// The game never writes this one (read-only)
	DEV_SNAPSHOT_PATH :: "dev/run.json"
	// The game optionally writes here at the end of the run
	DEV_HISTORY_DIRECTORY :: "dev/history"

	snapshot_load :: proc(path: string) -> (snapshot: Snapshot, err: Maybe(string)) {
		data, data_err := os.read_entire_file(path, context.temp_allocator)
		if data_err != nil {
			return {}, fmt.tprintf("Failed to read snapshot from '%v': %v", path, os.error_string(data_err))
		}

		return snapshot_decode(data)
	}

	snapshot_decode :: proc(data: []byte) -> (snapshot: Snapshot, err: Maybe(string)) {
		raw_json: json.Value
		json_err := json.unmarshal(data, &raw_json, allocator = context.temp_allocator)
		if json_err != nil {
			return {}, fmt.tprintf("Failed to decode snapshot JSON: %v", json_err)
		}

		root, root_ok := raw_json.(json.Object)
		if !root_ok do return {}, "Snapshot must be a JSON object"
		fields := (map[string]json.Value)(root)

		difficulty_name, difficulty_ok := fields["difficulty"].(json.String)
		if !difficulty_ok do return {}, "The difficulty string is required"
		difficulty, difficulty_valid := difficulty_from_string(difficulty_name).?
		if !difficulty_valid do return {}, fmt.tprintf("Unexpected difficulty: '%v'", difficulty_name)
		snapshot.difficulty = difficulty

		score, score_ok := fields["score"].(json.Integer)
		if !score_ok do return {}, "The score integer is required"
		if score < 0 || score > i64(max(u32)) do return {}, fmt.tprintf("Unexpected snapshot value: '%v'", score)
		snapshot.score = u32(score)

		lives, lives_ok := fields["lives"].(json.Integer)
		if !lives_ok do return {}, "The lives integer is required"
		if (lives < -128 || lives > 127) do return {}, fmt.tprintf("Unexpected lives value: '%v'", lives)
		snapshot.lives = i8(lives)

		#partial switch value in fields["elapsed_seconds"] {
		case json.Integer:
			if value < 0 do return {}, "Snapshot elapsed_seconds must be nonnegative"
			snapshot.elapsed_seconds = f32(value)
		case json.Float:
			if value < 0 do return {}, "Snapshot elapsed_seconds must be nonnegative"
			snapshot.elapsed_seconds = f32(value)
		case:
			return {}, "The elapsed_seconds number is required"
		}

		picks_raw, picks_ok := fields["modifier_picks"].(json.Array)
		if !picks_ok do return {}, "The modifier_picks array is required"
		modifier_picks := make([]ModifierKind, len(picks_raw), context.allocator)
		defer {
			if err != nil do delete(modifier_picks)
		}
		for value, i in picks_raw {
			name, name_ok := value.(json.String)
			if !name_ok do return {}, fmt.tprintf("The modifier_picks['%v'] should be a string, but got: '%v'", i, value)
			kind, kind_ok := modifier_kind_from_string(name).?
			if !kind_ok do return {}, fmt.tprintf("Unexpected modifier_picks['%v']: '%v'", i, value)
			modifier_picks[i] = kind
		}
		snapshot.modifier_picks = modifier_picks

		return snapshot, nil
	}

	snapshot_encode :: proc(snapshot: Snapshot) -> (data: []byte, err: Maybe(string)) {
		modifiers := make([]string, len(snapshot.modifier_picks), context.temp_allocator)
		for kind, i in snapshot.modifier_picks {
			modifiers[i] = modifier_kind_to_string(kind)
		}

		raw := SnapshotRaw {
			difficulty      = difficulty_to_string(snapshot.difficulty),
			modifier_picks  = modifiers,
			score           = snapshot.score,
			lives           = snapshot.lives,
			elapsed_seconds = snapshot.elapsed_seconds,
		}

		encoded, encoded_err := json.marshal(raw, opt = {pretty = true})
		if encoded_err != nil {
			return nil, fmt.tprintf("Failed to encode snapshot: '%v'", encoded_err)
		} else {
			return encoded, nil
		}
	}

	snapshot_save_history :: proc(snapshot: Snapshot) -> Maybe(string) {
		data, data_err := snapshot_encode(snapshot)
		if data_err != nil do return data_err
		defer delete(data)

		if dir_err := os.make_directory_all(DEV_HISTORY_DIRECTORY);
		   dir_err != nil && !os.is_dir(DEV_HISTORY_DIRECTORY) {
			return fmt.tprintf("Failed to create history directory: %v", os.error_string(dir_err))
		}

		now := time.now()
		year, month, day := time.date(now)
		hour, minute, second, nanosecond := time.precise_clock(now)
		path := fmt.tprintf(
			"%s/%04d-%02d-%02dT%02d-%02d-%02d.%09dZ.json",
			DEV_HISTORY_DIRECTORY,
			year,
			int(month),
			day,
			hour,
			minute,
			second,
			nanosecond,
		)

		if write_err := os.write_entire_file(path, data); write_err != nil {
			return fmt.tprintf("Failed to save history '%v': %v", path, os.error_string(write_err))
		}

		return nil
	}
}
