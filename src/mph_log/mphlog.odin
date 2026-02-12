package mphlog

import "base:runtime"
import "core:c"
import "core:fmt"
import "core:log"
import "core:os"
import "core:strings"
import rl "vendor:raylib"

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

logger_proc :: proc(
	data: rawptr,
	level: runtime.Logger_Level,
	text: string,
	options: runtime.Logger_Options,
	location := #caller_location,
) {
	// string_data := cast(^string)data
	fmt.println(text)
	write_log(fmt.aprintf("{}: {}", strings.to_upper(fmt.aprint(level)), text))

	log.file_logger_proc(data, level, text, options, location)
	// string_data := cast(^log.File_Console_Logger_Data)data

	// fmt.printfln("{}: {}", level, text)
}

logger_init :: proc() -> (ok: bool, handle: os.Handle) {
	hand, open_file_err := os.open("test_log4.log", os.O_CREATE | os.O_RDWR | os.O_TRUNC, 0o666)

	if open_file_err != nil {
		fmt.println(open_file_err)
		return false, os.INVALID_HANDLE
	}

	logger := log.create_file_logger(hand)

	context.logger = logger
	context.logger.procedure = logger_proc

	return true, hand
}

logger_deinit :: proc(handle: os.Handle) {
	os.close(handle)
	log.destroy_file_logger(context.logger)
}
