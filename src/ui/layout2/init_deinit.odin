package layout
import clay "../clay-odin"
import "core:c"
import "core:fmt"
import "core:strings"
import rr "raylib"
import raylib "vendor:raylib"

windowWidth: i32 = 1024
windowHeight: i32 = 768


LOREM_IPSUM_TEXT :: "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua."

errorHandler :: proc "c" (errorData: clay.ErrorData) {
	if (errorData.errorType == clay.ErrorType.DuplicateId) {
		// etc
	}
}

// TODO should find a way to move the raylib specific stuff out
// measure_text_proc could be rr.measureText
init :: proc(
	measure_text_proc: proc "c" (
		text: clay.StringSlice,
		config: ^clay.TextElementConfig,
		userData: rawptr,
	) -> clay.Dimensions,
) -> clay.Arena {

	minMemorySize: c.size_t = cast(c.size_t)clay.MinMemorySize()
	memory := make([^]u8, minMemorySize)
	arena: clay.Arena = clay.CreateArenaWithCapacityAndMemory(minMemorySize, memory)
	clay.Initialize(
		arena,
		{cast(f32)raylib.GetScreenWidth(), cast(f32)raylib.GetScreenHeight()},
		{handler = errorHandler},
	)
	clay.SetMeasureTextFunction(measure_text_proc, nil)

	PATH_TO_RESOURCES: string : "content/"

	// raylib.SetConfigFlags({.VSYNC_HINT, .WINDOW_RESIZABLE, .MSAA_4X_HINT})
	// raylib.InitWindow(windowWidth, windowHeight, "Raylib Odin Example")
	// raylib.SetTargetFPS(raylib.GetMonitorRefreshRate(0)) // does not need be here

	loadFont(DEBUG_FONT_ID, 56, "resources/Calistoga-Regular.ttf")


	return arena
}


deinit :: proc(arena: clay.Arena) {
	free(arena.memory)

}

// Updated cursor / pointer states and such
update_state :: proc() {
	windowWidth = raylib.GetScreenWidth()
	windowHeight = raylib.GetScreenHeight()
	if (raylib.IsKeyPressed(.U)) {
		@(static) debugModeEnabled: bool
		debugModeEnabled = !debugModeEnabled
		clay.SetDebugModeEnabled(debugModeEnabled)
	}
	clay.SetPointerState(
		transmute(clay.Vector2)raylib.GetMousePosition(),
		raylib.IsMouseButtonDown(raylib.MouseButton.LEFT),
	)
	clay.UpdateScrollContainers(
		false,
		transmute(clay.Vector2)raylib.GetMouseWheelMoveV() * 5,
		raylib.GetFrameTime(),
	)
	clay.SetLayoutDimensions({cast(f32)raylib.GetScreenWidth(), cast(f32)raylib.GetScreenHeight()})

}


render :: proc(render_commands: ^clay.ClayArray(clay.RenderCommand)) {
	// raylib.BeginDrawing()
	rr.clay_raylib_render(render_commands)
	// raylib.EndDrawing()
}
