package game_tests

@(require) import game "../src"
@(require) import "core:os"
@(require) import "core:reflect"
@(require) import "core:testing"

when ODIN_DEBUG {
	@(test)
	snapshot_decode_example :: proc(t: ^testing.T) {
		data, data_err := os.read_entire_file("dev/run.json.example", context.temp_allocator)
		assert(data_err == nil, "Could not read snapshot example")

		snapshot, snapshot_err := game.snapshot_decode(data)
		assert(snapshot_err == nil, "Snapshot decoding failed")
		defer delete(snapshot.modifier_picks)

		expected := game.Snapshot {
			difficulty      = .Easy,
			modifier_picks  = []game.ModifierKind{.Prestige, .AddPetProject},
			score           = 0,
			lives           = 5,
			elapsed_seconds = 0,
		}

		testing.expect(
			t,
			reflect.equal(snapshot, expected, including_indirect_array_recursion = true),
			"Decoded snapshot does not match the example",
		)
	}

	@(test)
	snapshot_json_round_trip :: proc(t: ^testing.T) {
		expected := game.Snapshot {
			difficulty      = .Hard,
			modifier_picks  = []game.ModifierKind{.Prestige, .AddPetProject},
			score           = 123,
			lives           = 3,
			elapsed_seconds = 12.3,
		}

		data, encode_err := game.snapshot_encode(expected)
		assert(encode_err == nil, "Snapshot encoding failed")
		defer delete(data)

		actual, decode_err := game.snapshot_decode(data)
		assert(decode_err == nil, "Snapshot decoding failed")
		defer delete(actual.modifier_picks)

		testing.expect(
			t,
			reflect.equal(actual, expected, including_indirect_array_recursion = true),
			"Snapshot changed after JSON round trip",
		)
	}
}
