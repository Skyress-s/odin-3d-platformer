package logging

import "core:log"

loggers: map[string]log.Logger

// get_or_add_logger :: proc(name: string) {
// 	found_logger, ok := loggers[name]
// 	if !ok {
// 		make_console_logger(name)
// 	}
// }
//
// @(private)
// make_console_logger :: proc(name: string) -> ^log.Logger{
// 	loggers[name] = log.create_console_logger()
// 	return loggers[name]
// }
//
// destroy_loggers :: proc() {
//
// 	for logger_name, &logger in loggers {
// 		log.destroy_console_logger(logger)
// 	}
//
// 	delete(loggers)
// }
