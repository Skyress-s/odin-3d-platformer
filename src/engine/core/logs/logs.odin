package logs

import rb "../../../ringbuffer/"
import "base:runtime"
import "core:fmt"
import "core:log"
import "core:os"
import "core:strings"
import "core:time"

Context :: struct {
	logs_buf:    rb.RingBuffer(byte),
	levels:      [len(System)]log.Level, // This is really cool!
	initialized: bool,
}

global_ctx: Context

NUM_BYTES_FOR_RUNTIME_LOGS :: 1024 << 2 // 1024 ~ 1 kb
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


init :: proc() -> (logger: log.Logger) {
	global_ctx.initialized = true
	global_ctx.logs_buf = rb.init(logs_memory[:])
	for &system_log_level in global_ctx.levels {
		system_log_level = .Debug
	}

	logger = log.create_console_logger(.Debug, {.Line, .Short_File_Path, .Time, .Level})

	return logger
}

deinit :: proc() {
	// Nothing needed here yet.
}

clear :: proc() {
	rb.reset(&global_ctx.logs_buf)
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

logf_base :: proc(
	system: System,
	level: log.Level,
	fmt_str: string,
	args: ..any,
	location := #caller_location,
) {
	string_with_system := fmt.tprintf("[{}] {}", system, fmt.tprintf(fmt_str, ..args))
	_log_and_add_to_ringbuffer(
		level = level,
		string_with_system = string_with_system,
		location = location,
	)
}


log_base :: proc(
	system: System,
	level: log.Level,
	args: ..any,
	sep := " ",
	location := #caller_location,
) {
	string_with_system := fmt.tprintf("[{}] {}", system, fmt.tprint(..args, sep = sep))
	_log_and_add_to_ringbuffer(
		level = level,
		string_with_system = string_with_system,
		location = location,
	)
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

	return _console_logger_proc(logger.data, level, str, logger.options, location)
}

_log_and_add_to_ringbuffer :: proc(
	level: log.Level,
	string_with_system: string,
	location := #caller_location,
) {
	if !global_ctx.initialized do return
	runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()

	maybe_string := _format_string(level = level, str = string_with_system, location = location)
	string, string_ok := maybe_string.(string)
	if string_ok {
		if global_ctx.levels[0:0] != nil {
			string_as_bytes := transmute([]byte)(string)
			for b in string_as_bytes {
				rb.add_back_overrite(&global_ctx.logs_buf, b)
			}

		}
	}
	context.logger.options += {.Terminal_Color, .Long_File_Path, .Procedure}

	context.logger.options -= {.Short_File_Path}
	log.log(level = level, args = {string_with_system}, sep = "", location = location) // Slightly more expensive to do logic again. But fine for now
}


@(private)
_console_logger_proc :: proc(
	logger_data: rawptr,
	level: log.Level,
	text: string,
	options: log.Options,
	location := #caller_location,
) -> Maybe(string) {
	if logger_data == nil do return {}
	options := options
	data := cast(^log.File_Console_Logger_Data)logger_data
	if data == nil do return {}
	h: ^os.File = nil
	if level < log.Level.Error {
		h = os.stdout
	} else {
		h = os.stderr
	}
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
	log.do_level_header(options, buf, level)

	when time.IS_SUPPORTED {
		log.do_time_header(options, buf, time.now())
	}

	log.do_location_header(options, buf, location)

	if .Thread_Id in options {
		fmt.sbprintf(buf, "[{}] ", os.get_current_thread_id())
	}

	if ident != "" {
		fmt.sbprintf(buf, "[%s] ", ident)
	}
}
