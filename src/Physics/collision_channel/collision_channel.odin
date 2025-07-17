package collision_channel


CHANNEL_SIZE :: u16

set_is_not_blocking :: proc(collision_channel: CHANNEL_SIZE) -> CHANNEL_SIZE {
	mask: CHANNEL_SIZE = 0b1
	inverted: CHANNEL_SIZE = ~mask
	return collision_channel & (inverted)
}
set_is_blocking :: proc(collision_channel: CHANNEL_SIZE) -> CHANNEL_SIZE {
	return collision_channel | 0b1
}

is_blocking :: proc(collision_channel: CHANNEL_SIZE) -> bool {
	return (collision_channel & 0b1) > 0
}
