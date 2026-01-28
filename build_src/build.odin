package build

import "core:fmt"
import os "core:os/os2"
import "core:time"
import "core:time/datetime"

when ODIN_OS == .Windows {
	exe_file_extension :: ".exe"
} else {
	exe_file_extension :: ""
}

GAME_NAME :: "defenestration_game"
BUILD_FOLDER_PATH :: "build"
CONTENT_PATH :: "content"

main :: proc() {
	fmt.printfln("Start building game...")
	build_stopwatch: time.Stopwatch
	time.stopwatch_start(&build_stopwatch)


	build_step_stopwatch: time.Stopwatch
	time.stopwatch_start(&build_step_stopwatch)

	os.remove_all(BUILD_FOLDER_PATH) // make sure dir is clean
	os.remove_all(GAME_NAME)
	os.mkdir_all("build/content")
	os.mkdir_all(BUILD_FOLDER_PATH + "/" + CONTENT_PATH)

	print_build_step_with_time_and_restart(
		&build_step_stopwatch,
		"Removing old /build/ and creating new /build/.",
	)

	os.copy_directory_all(BUILD_FOLDER_PATH + "/" + CONTENT_PATH, CONTENT_PATH)

	print_build_step_with_time_and_restart(&build_step_stopwatch, "Copy /content/ into /build/.")

	process_desc := os.Process_Desc{}
	process_desc.working_dir = ""
	process_desc.command = {
		"odin",
		"build",
		"src/",
		"-o:speed",
		"-out:build/defenestration_game" + exe_file_extension,
	}

	_, _, _, err := os.process_exec(process_desc, context.temp_allocator)
	assert(err == nil, fmt.tprint(err))
	print_build_step_with_time_and_restart(&build_step_stopwatch, "Building game.")

	zip_folder("build", "defenestration_game.zip")
	print_build_step_with_time_and_restart(&build_step_stopwatch, "Compressing game to zip.")

	os.remove_all("build")

	print_build_step_with_time_and_restart(&build_step_stopwatch, "Deleting /build/")

	fmt.printfln(
		"Finished building game. Took {:.2f} seconds.",
		time.stopwatch_duration(build_stopwatch),
	)

}

print_build_step_with_time_and_restart :: proc(stopwatch: ^time.Stopwatch, text: string) {
	fmt.printfln(
		"{}\n\tTook: {:.2f} seconds.",
		text,
		time.duration_seconds(time.stopwatch_duration(stopwatch^)),
	)
	time.stopwatch_reset(stopwatch)
	time.stopwatch_start(stopwatch)

}

zip_folder :: proc(src, dst: string) -> bool {
	// tar is on modern windows. And on linux by default (apparently)
	cmd: []string = {"tar", "-a", "-c", "-f", dst, src}

	_, _, _, err := os.process_exec(
		os.Process_Desc{working_dir = "", command = cmd},
		context.temp_allocator,
	)
	assert(err == nil)

	return true
}
