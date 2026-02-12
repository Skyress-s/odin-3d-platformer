package collision_channel


// Type :: enum u8 {
// 	Blocking,
// }

// Responses :: bit_set[Type]


IGNORE :: 0
OVERLAP :: 1
BLOCK :: 2

Response_Size :: distinct u16

Responses :: bit_field Response_Size {
	player: u8 | 2,
	// other:  u8 | 2,
}

BLOCK_ALL := Responses {
	player = BLOCK,
}
