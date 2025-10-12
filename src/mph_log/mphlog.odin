package mphlog

import "core:fmt"
import "core:strings"
import rl "vendor:raylib"
import mu "vendor:microui"
import "core:c"

log_state := struct {
	log_buf:         [1 << 16]byte,
	log_buf_len:     int,
	log_buf_updated: bool,
}{}

state := struct {
	log_buf:         [1 << 16]byte,
	log_buf_len:     int,
	log_buf_updated: bool,
}{}

// write_log :: proc(str: string) {
// 	state.log_buf_len += copy(state.log_buf[state.log_buf_len:], str)
// 	state.log_buf_len += copy(state.log_buf[state.log_buf_len:], "\n")
// 	state.log_buf_updated = true
// }
//
// read_log :: proc() -> string {
// 	return string(state.log_buf[:state.log_buf_len])
// }
// reset_log :: proc() {
// 	state.log_buf_updated = true
// 	state.log_buf_len = 0
// }
write_log :: proc(str: string) {
	log_state.log_buf_len += copy(log_state.log_buf[log_state.log_buf_len:], str)
	log_state.log_buf_len += copy(log_state.log_buf[log_state.log_buf_len:], "\n")
	log_state.log_buf_updated = true
}

read_log :: proc() -> string {
	return string(log_state.log_buf[:log_state.log_buf_len])
}
reset_log :: proc() {
	log_state.log_buf_updated = true
	log_state.log_buf_len = 0
}

