package game

import "base:runtime"

// TODO: This used to be more complex, consider removing this fully
AppMemory :: struct {
	session_arena: runtime.Arena,
	session:       runtime.Allocator,
}

memory_init :: proc(memory: ^AppMemory) {
	assert(memory != nil)
	memory.session = runtime.arena_allocator(&memory.session_arena)
}
