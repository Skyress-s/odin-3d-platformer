package logs

import rb "../ringbuffer/"
import "base:runtime"
import "core:fmt"
import "core:log"
import "core:os"
import "core:strings"
import "core:time"

Log_Entry :: struct {
	log: string,
}

Context :: struct {
	logs_cache: rb.RingBuffer(Log_Entry),
	levels:     [len(System)]log.Level, // This is really cool!
}

System :: enum {
	Base,
	Physics,
	UI,
	Gamelogic,
}

/*
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

init :: proc(backing: []Log_Entry) -> (ctx: Context, logger: log.Logger) {
	ctx.logs_cache = rb.init(backing[:])
	for &system_log_level in ctx.levels {
		system_log_level = .Debug
	}

	// TODO add our context to the usr ptr. So that we dont have to pass the context everywhere.

	// ahh := cast([8]rawptr)context.user_ptr
	// ahh[0] = ctx

	logger = log.create_console_logger(
		.Debug,
		{.Line, .Short_File_Path, .Terminal_Color, .Time, .Procedure, .Level},
	)

	return ctx, logger
}

log :: proc(
	ctx: ^Context,
	system: System,
	level: log.Level,
	args: ..any,
	sep := " ",
	location := #caller_location,
) {
	string_with_system := fmt.tprintf("[{}] {}", system, fmt.tprint(args))
	maybe_string := _log(
		level = level,
		args = {string_with_system},
		sep = sep,
		location = location,
	)
	string, ok := maybe_string.(string)
	if ok {
		rb.add_back_overrite(&ctx.logs_cache, Log_Entry{string})
		fmt.print(string)
	}
}

@(private)
_log :: proc(
	level: log.Level,
	args: ..any,
	sep := " ",
	location := #caller_location,
) -> Maybe(string) {
	logger := context.logger
	if logger.procedure == nil || logger.procedure == log.nil_logger_proc {
		return {}
	}
	if level < logger.lowest_level {
		return {}
	}
	runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()
	str := fmt.tprint(..args, sep = sep)

	return _console_logger_proc(logger.data, level, str, logger.options, location)
	// logger.procedure(logger.data, level, str, logger.options, location)
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
	return fmt.aprintf("{}{}\n", strings.to_string(buf), text) // called takes ownership
}

@(private)
_file_console_logger_proc :: proc(
	h: os.Handle,
	ident: string,
	level: log.Level,
	text: string,
	options: log.Options,
	location: runtime.Source_Code_Location,
) {
	backing: [1024]byte //NOTE(Hoej): 1024 might be too much for a header backing, unless somebody has really long paths.
	buf := strings.builder_from_bytes(backing[:])

	log.do_level_header(options, &buf, level)

	when time.IS_SUPPORTED {
		log.do_time_header(options, &buf, time.now())
	}

	log.do_location_header(options, &buf, location)

	if .Thread_Id in options {
		// NOTE(Oskar): not using context.thread_id here since that could be
		// incorrect when replacing context for a thread.
		fmt.sbprintf(&buf, "[{}] ", os.current_thread_id())
	}

	if ident != "" {
		fmt.sbprintf(&buf, "[%s] ", ident)
	}
	//TODO(Hoej): When we have better atomics and such, make this thread-safe
	fmt.fprintf(h, "%s%s\n", strings.to_string(buf), text)
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
