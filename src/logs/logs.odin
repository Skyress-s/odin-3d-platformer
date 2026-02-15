package logs

import rb "../ringbuffer/"
import "base:runtime"
import "core:fmt"
import "core:log"
import "core:os"
import "core:strings"
import "core:time"

Context :: struct {
	// logs_cache: rb.RingBuffer(Log_Entry),
	logs_buf: rb.RingBuffer(byte),
	levels:   [len(System)]log.Level, // This is really cool!
}

global_ctx: Context

NUM_BYTES_FOR_RUNTIME_LOGS :: 1024 << 2 // 1024 ~ 1 kb
// NUM_BYTES_FOR_RUNTIME_LOGS :: 1 << 9 // 1024 ~ 1 kb
@(private)
logs_memory: [NUM_BYTES_FOR_RUNTIME_LOGS]byte // contains our runtime logs
@(private)
static_buf: [NUM_BYTES_FOR_RUNTIME_LOGS]byte

// TODO: Can use generic type instead, this does not really need to be here
System :: enum {
	Base,
	Physics,
	UI,
	Editor,
	Gamelogic,
	Serialization,
}

/*
  TODO: OUTDATED
 Example program
package main

import logs "./logs"
import rb "./rb"
import "core:fmt"
import log "core:log"

main :: proc() {

	arr: [8]rawptr
	context.user_ptr = &arr
	backing: [12]logs.Log_Entry
	ctx, logger := logs.init(backing[:])
	context.logger = logger

	logs.log(&ctx, .Physics, .Error, 56)
	log.log(.Error, 49)

	for i in 0 ..< 1024 {
		logs.log(&ctx, .Physics, .Debug, i)
	}

	fmt.printfln("============== LOGS ==============\n {} ", ctx.logs_cache.len)
	itr := rb.iterator_init(&ctx.logs_cache)
	for item in rb.iterator_next(&itr) {

		fmt.println(item)
	}

}
 */

init :: proc() -> (logger: log.Logger) {
	global_ctx.logs_buf = rb.init(logs_memory[:])
	// global_ctx.logs_cache = rb.init(backing[:])
	for &system_log_level in global_ctx.levels {
		system_log_level = .Debug
	}

	// TODO add our context to the usr ptr. So that we dont have to pass the context everywhere.

	// ahh := cast([8]rawptr)context.user_ptr
	// ahh[0] = ctx

	logger = log.create_console_logger(.Debug, {.Line, .Short_File_Path, .Time, .Level})

	return logger
}

clear :: proc() {
	rb.reset(&global_ctx.logs_buf)
}

deinit :: proc() {
}

get_string_slice :: proc() -> string {

	itr := rb.iterator_init(&global_ctx.logs_buf)

	for item, i in rb.iterator_next(&itr) {
		// fmt.print(rune(item^), "bazinga")
		static_buf[i] = item^
	}
	static_as_string := string(static_buf[:])
	return static_as_string
}


debug :: proc(system: System, args: ..any, sep := " ", location := #caller_location) {
	log_base(system = system, level = .Debug, args = args, sep = sep, location = location)
}
info :: proc(system: System, args: ..any, sep := " ", location := #caller_location) {
	log_base(system = system, level = .Info, args = args, sep = sep, location = location)
}
warn :: proc(system: System, args: ..any, sep := " ", location := #caller_location) {
	log_base(system = system, level = .Warning, args = args, sep = sep, location = location)
}
error :: proc(system: System, args: ..any, sep := " ", location := #caller_location) {
	log_base(system = system, level = .Error, args = args, sep = sep, location = location)
}
fatal :: proc(system: System, args: ..any, sep := " ", location := #caller_location) {
	log_base(system = system, level = .Fatal, args = args, sep = sep, location = location)
}

debugf :: proc(system: System, fmt_str: string, args: ..any, location := #caller_location) {
	logf_base(system = system, level = .Debug, fmt_str = fmt_str, args = args, location = location)
}
infof :: proc(system: System, fmt_str: string, args: ..any, location := #caller_location) {
	logf_base(system = system, level = .Info, fmt_str = fmt_str, args = args, location = location)
}
warnf :: proc(system: System, fmt_str: string, args: ..any, location := #caller_location) {
	logf_base(
		system = system,
		level = .Warning,
		fmt_str = fmt_str,
		args = args,
		location = location,
	)
}
errorf :: proc(system: System, fmt_str: string, args: ..any, location := #caller_location) {
	logf_base(system = system, level = .Error, fmt_str = fmt_str, args = args, location = location)
}
fatalf :: proc(system: System, fmt_str: string, args: ..any, location := #caller_location) {
	logf_base(system = system, level = .Fatal, fmt_str = fmt_str, args = args, location = location)
}
// Info    = 10,
// Warning = 20,
// Error   = 30,
// Fatal   = 40,


logf_base :: proc(
	system: System,
	level: log.Level,
	fmt_str: string,
	args: ..any,
	location := #caller_location,
) {
	string_with_system := fmt.tprintf("[{}] {}", system, fmt.tprintf(fmt_str, ..args))
	_fire_string(level = level, string_with_system = string_with_system, location = location)
}


log_base :: proc(
	system: System,
	level: log.Level,
	args: ..any,
	sep := " ",
	location := #caller_location,
) {
	string_with_system := fmt.tprintf("[{}] {}", system, fmt.tprint(..args, sep = sep))
	_fire_string(level = level, string_with_system = string_with_system, location = location)
}

@(private)
_format_string :: proc(
	level: log.Level,
	str: string,
	location := #caller_location,
) -> Maybe(string) {
	logger := context.logger
	if logger.procedure == nil || logger.procedure == log.nil_logger_proc {
		return {}
	}
	if level < logger.lowest_level {
		return {}
	}
	// runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()

	return _console_logger_proc(logger.data, level, str, logger.options, location)
}

_fire_string :: proc(level: log.Level, string_with_system: string, location := #caller_location) {
	runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()
	maybe_string := _format_string(level = level, str = string_with_system, location = location)
	string, ok := maybe_string.(string)
	assert(ok)
	if ok {
		// ugh
		// if (int(global_ctx.logs_cache.len) == len(global_ctx.logs_cache.elements)) {
		// 	i := rb.get_index(global_ctx.logs_cache, 0)
		// 	delete(global_ctx.logs_cache.elements[i].log)
		// }
		string_as_bytes := transmute([]byte)(string)
		for b in string_as_bytes {
			rb.add_back_overrite(&global_ctx.logs_buf, b)
		}
		// rb.add_back_overrite(&global_ctx.logs_cache, Log_Entry{string})
		context.logger.options += {.Terminal_Color, .Long_File_Path, .Procedure}

		context.logger.options -= {.Short_File_Path}
		log.log(level = level, args = {string_with_system}, sep = "", location = location) // Slightly more expensive to do logic again. But fine for now
		//fmt.print(string)
	}

}


@(private)
_console_logger_proc :: proc(
	logger_data: rawptr,
	level: log.Level,
	text: string,
	options: log.Options,
	location := #caller_location,
) -> string {
	options := options
	data := cast(^log.File_Console_Logger_Data)logger_data
	h: os.Handle = ---
	if level < log.Level.Error {
		h = os.stdout
		// options -= log.global_subtract_stdout_options
	} else {
		h = os.stderr
		// options -= log.global_subtract_stderr_options
	}
	// _file_console_logger_proc(h, data.ident, level, text, options, location)
	backing: [1024]byte
	buf := strings.builder_from_bytes(backing[:])
	_format_logger_proc(&buf, data.ident, level, text, options, location)
	return fmt.tprintf("{}{}\n", strings.to_string(buf), text) // called takes ownership
}


@(private)
_format_logger_proc :: proc(
	buf: ^strings.Builder,
	ident: string,
	level: log.Level,
	text: string,
	options: log.Options,
	location: runtime.Source_Code_Location,
) {
	// backing: [1024]byte //NOTE(Hoej): 1024 might be too much for a header backing, unless somebody has really long paths.
	// buf := strings.builder_from_bytes(backing[:])

	log.do_level_header(options, buf, level)

	when time.IS_SUPPORTED {
		log.do_time_header(options, buf, time.now())
	}

	log.do_location_header(options, buf, location)

	if .Thread_Id in options {
		// NOTE(Oskar): not using context.thread_id here since that could be
		// incorrect when replacing context for a thread.
		fmt.sbprintf(buf, "[{}] ", os.current_thread_id())
	}

	if ident != "" {
		fmt.sbprintf(buf, "[%s] ", ident)
	}
	//TODO(Hoej): When we have better atomics and such, make this thread-safe
	// fmt.tprintf("%s%s\n", strings.to_string(buf^), text)
	// fmt.fprintf(h, "%s%s\n", strings.to_string(buf^), text)
}
