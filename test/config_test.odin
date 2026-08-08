package game_tests

import game "../src"
import "core:encoding/json"
import "core:testing"
import "core:os"

@(test)
game_config_json_has_expected_shape :: proc(t: ^testing.T) {
	_ = t
	config_path := game.asset_path_required("config/game.json", "game config")
	data, os_err := os.read_entire_file(config_path, context.temp_allocator)
	assert(os_err == nil)

	value: json.Value
	json_err := json.unmarshal(data, &value, allocator = context.temp_allocator)
	assert(json_err == nil)

	_, ok := game.config_validate_shape(value, type_info_of(game.GameConfigRaw), "game-config")
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

	_, ok := game.config_validate_shape(value, type_info_of(ConfigShapeTest), "test")
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

	message, ok := game.config_validate_shape(value, type_info_of(ConfigShapeTest), "test")
	assert(!ok)
	assert(message == expected_error)
}
