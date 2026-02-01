package logging

import "core:log"

// TODO: Should not be here. But its own package. Then this function takes a generic 'system' type IMO
System :: enum {
	Physics,
	Audio,
	UI,
}

log :: proc(
	level: log.Level,
	system: System,
	args: ..any,
	sep := " ",
	location := #caller_location,
) {
	log.log(level, args, sep, location)
}
