package ringbuffer

import "core:fmt"

// TODO: Reimplement!

Ring_Buffer :: struct($T: typeid) {
	data:     []T,
	head:     int,
	tail:     int,
	count:    int,
	capacity: int,
}

ring_buffer :: proc($T: typeid, capacity: int) -> Ring_Buffer(T) {
	return Ring_Buffer(T) {
		data = make([]T, capacity),
		head = 0,
		tail = 0,
		count = 0,
		capacity = capacity,
	}
}

destroy :: proc(rb: ^Ring_Buffer($T)) {
	delete(rb.data)
	rb.head = 0
	rb.tail = 0
	rb.count = 0
	rb.capacity = 0
}

push :: proc(rb: ^Ring_Buffer($T), value: T) -> bool {
	if rb.count >= rb.capacity {
		return false
	}
	rb.data[rb.tail] = value
	rb.tail = (rb.tail + 1) % rb.capacity
	rb.count += 1
	return true
}

push_force :: proc(rb: ^Ring_Buffer($T), value: T) {
	if rb.count < rb.capacity {
		rb.data[rb.tail] = value
		rb.tail = (rb.tail + 1) % rb.capacity
		rb.count += 1
	} else {
		rb.data[rb.tail] = value
		rb.tail = (rb.tail + 1) % rb.capacity
		rb.head = (rb.head + 1) % rb.capacity
	}
}

pop :: proc(rb: ^Ring_Buffer($T)) -> (value: T, ok: bool) {
	if rb.count == 0 {
		return
	}
	value = rb.data[rb.head]
	rb.head = (rb.head + 1) % rb.capacity
	rb.count -= 1
	ok = true
	return
}

peek :: proc(rb: ^Ring_Buffer($T)) -> (value: T, ok: bool) {
	if rb.count == 0 {
		return
	}
	value = rb.data[rb.head]
	ok = true
	return
}

peek_back :: proc(rb: ^Ring_Buffer($T)) -> (value: T, ok: bool) {
	if rb.count == 0 {
		return
	}
	index := (rb.tail - 1 + rb.capacity) % rb.capacity
	value = rb.data[index]
	ok = true
	return
}

is_empty :: proc(rb: ^Ring_Buffer($T)) -> bool {
	return rb.count == 0
}

is_full :: proc(rb: ^Ring_Buffer($T)) -> bool {
	return rb.count >= rb.capacity
}

len :: proc(rb: ^Ring_Buffer($T)) -> int {
	return rb.count
}

cap :: proc(rb: ^Ring_Buffer($T)) -> int {
	return rb.capacity
}

clear :: proc(rb: ^Ring_Buffer($T)) {
	rb.head = 0
	rb.tail = 0
	rb.count = 0
}

resize :: proc(rb: ^Ring_Buffer($T), new_capacity: int) {
	if new_capacity == rb.capacity {
		return
	}
	new_data := make([]T, new_capacity)

	if rb.count > 0 {
		for i in 0 ..< rb.count {
			src_index := (rb.head + i) % rb.capacity
			new_data[i] = rb.data[src_index]
		}
	}

	delete(rb.data)
	rb.data = new_data
	rb.head = 0
	rb.tail = rb.count
	rb.capacity = new_capacity
}

to_slice :: proc(rb: ^Ring_Buffer($T), allocator := context.allocator) -> []T {
	result := make([]T, rb.count, allocator)

	for i in 0 ..< rb.count {
		src_index := (rb.head + i) % rb.capacity
		result[i] = rb.data[src_index]
	}

	return result
}

fmt_string :: proc(rb: ^Ring_Buffer($T)) -> string {
	return fmt.tprintf("Ring_Buffer{}/{}", rb.count, rb.capacity)
}
