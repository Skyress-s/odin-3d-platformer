package logging

import "core:log"

import rb "../ringbuffer/"

// TODO: Should not be here. But its own package. Then this function takes a generic 'system' type IMO
System :: enum {
	Physics,
	Audio,
	UI,
}


Log_Entry :: struct {
	line: string,
}

logger_proc :: proc(
	logger_data: rawptr,
	level: log.Level,
	text: string,
	options: log.Options,
	location := #caller_location,
) {
	log.console_logger_proc(logger_data, level, text, options, location)
}

init :: proc() -> log.Logger {
	logger := log.create_console_logger(log.Level.Info, {.Time, .Level, .Terminal_Color, .Line})
	logger.procedure = logger_proc
	// logger.data = &rb.ring_buffer(Log_Entry, 1024)


	return logger
}

deinit :: proc() {
	log.destroy_console_logger(context.logger)
}

// log :: proc(
// 	level: log.Level,
// 	system: System,
// 	args: ..any,
// 	sep := " ",
// 	location := #caller_location,
// ) {
//
//
// 	log.log(level, args, sep, location)
// }
