package ringbuffer


/*
 * ======================= EXAMPLE =======================
 *	backing: [1024]Entry
 *
 *	ringbuffer := rb.init(backing[:])
 *
 *	for i in 0 ..< 100_000_000 {
 *		rb.add_back_overrite(&ringbuffer, Entry{i64(i)})
 *	}
 *
 *	itr := rb.iterator_init(&ringbuffer)
 *	total: i128
 *	for item in rb.iterator_next(&itr) {
 *		total += i128(item.id)
 *	}
 *
 *	fmt.printfln("Sum {}", total)
 * */

RingBuffer :: struct($T: typeid) {
	elements:    []T,
	// Modulo and overflow is sometimes faster than with signed ints.
	// Testing with -o:speed it was about two or three times slower with signed ints
	len, offset: uint,
}

init :: proc(backing: []$T) -> (rb: RingBuffer(T)) {
	rb.elements = backing[:]
	rb.len = 0
	rb.offset = 0
	return
}

add_back_overrite :: #force_inline proc(rb: ^RingBuffer($T), new_elem: T) #no_bounds_check {
	idx := (rb.offset + rb.len) % len(rb.elements)
	rb.elements[idx] = new_elem

	if rb.len < len(rb.elements) {
		rb.len += 1
	} else {
		rb.offset = (rb.offset + 1) % len(rb.elements)
	}
}

add_front_overrite :: proc(rb: ^RingBuffer($T), new_elem: T) #no_bounds_check {
	rb.offset = (rb.offset - 1 + len(rb.elements)) % len(rb.elements)
	rb.elements[rb.offset] = new_elem
	if rb.len < len(rb.elements) do rb.len += 1
}

remove_back :: proc(rb: ^RingBuffer($T)) {
	if rb.len > 0 do rb.len -= 1
}

remove_front :: proc(rb: ^RingBuffer($T)) {
	if len(rb.elements) > 0 {
		rb.len -= 1
		rb.offset = get_index(rb, rb.offset + 1)
	}
}

get_index :: #force_inline proc(rb: RingBuffer($T), i: int) -> uint #no_bounds_check {
	return (rb.offset + uint(i)) % uint(len(rb.elements))
}

Iterator :: struct($T: typeid) {
	i:  int,
	rb: ^RingBuffer(T),
}

iterator_init :: proc(rb: ^RingBuffer($T)) -> (iter: Iterator(T)) {
	iter.i = 0
	iter.rb = rb
	return
}

iterator_next :: #force_inline proc(itr: ^Iterator($T)) -> (val: ^T, cond: bool) #no_bounds_check {
	if itr.i >= len(itr.rb.elements) do return nil, false

	index := get_index(itr.rb^, itr.i)
	itr.i += 1
	return &itr.rb.elements[index], true
}


// TODO:
// linearize :: proc(rb: ^RingBuffer($T, $N)) {
// }
