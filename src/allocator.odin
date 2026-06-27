package game

import "base:runtime"

AppMemory :: struct {
	// not permanent, configs can be hot reloaded:
	config_arena:  runtime.Arena,
	config:        runtime.Allocator,
	session_arena: runtime.Arena,
	session:       runtime.Allocator,
}

memory_init :: proc(memory: ^AppMemory) {
	assert(memory != nil)
	memory.config = runtime.arena_allocator(&memory.config_arena)
	memory.session = runtime.arena_allocator(&memory.session_arena)
}
