package main

import "core:os/os2"
import "core:fmt"
import "core:mem"
import "core:os"
import "core:path/filepath"
import "core:testing"
import "base:runtime"

get_file_infos_with_extension :: proc(path: string, allocator: runtime.Allocator = context.allocator) -> (file_paths: [dynamic]string) {
	f, err := os.open(path)
	defer os.close(f)

	infos: []os.File_Info
	infos, err = os.read_dir(f, -1)
	assert(err == nil)

	defer os.file_info_slice_delete(infos)

	for info in infos {
			cwd := os.get_current_directory(context.temp_allocator)

		file_info_path, rel_err := filepath.rel(cwd, info.fullpath, context.temp_allocator)
		if (info.is_dir) {

			new_paths := get_file_infos_with_extension(info.fullpath)
			defer delete(new_paths)

			for p in new_paths {
				append_elem(&file_paths, p)
			}
		} else {
			append_elem(&file_paths, file_info_path)
		}

	}

	return file_paths
}

@(test)
test_get_file_infos_with_extension :: proc(t: ^testing.T) {
	paths := get_file_infos_with_extension("resources")
	defer delete(paths)
	testing.expectf(t, len(paths) != 0, "test")
}

main :: proc() {
	track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, context.allocator)
	context.allocator = mem.tracking_allocator(&track)
	defer {
		if len(track.allocation_map) > 0 {
			fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
			for _, entry in track.allocation_map {
				fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
			}
		}
		if len(track.bad_free_array) > 0 {
			fmt.eprintf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
			for entry in track.bad_free_array {
				fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
			}
		}
		mem.tracking_allocator_destroy(&track)
	}

	paths := get_file_infos_with_extension("resources")
	for &p in paths {
		fmt.println(p)
	}
	delete(paths)

	process_state, stdout, stderr, err := os2.process_exec(os2.Process_Desc{command = {"echo","hello world"}}, context.temp_allocator)

	fmt.println(process_state.success)
	fmt.println(string(stdout))

	free_all(context.temp_allocator)
}