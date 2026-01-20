package layout
import hms "../../handle_map/handle_map_static/"
import clay "../clay-odin"
import "core:c"
import "core:fmt"
import vmem "core:mem/virtual"
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
) -> (
	ctx: Context,
) {

	arena_init_err := vmem.arena_init_growing(&ctx.arena)
	assert(arena_init_err == nil)

	ctx.arena_allocator = vmem.arena_allocator(&ctx.arena)


	minMemorySize: c.size_t = cast(c.size_t)clay.MinMemorySize()
	memory := make([^]u8, minMemorySize)
	ctx.clay_arena = clay.CreateArenaWithCapacityAndMemory(minMemorySize, memory)
	clay.Initialize(
		ctx.clay_arena,
		{cast(f32)raylib.GetScreenWidth(), cast(f32)raylib.GetScreenHeight()},
		{handler = errorHandler},
	)
	clay.SetMeasureTextFunction(measure_text_proc, nil)

	PATH_TO_RESOURCES: string : "content/"

	// raylib.SetConfigFlags({.VSYNC_HINT, .WINDOW_RESIZABLE, .MSAA_4X_HINT})
	// raylib.InitWindow(windowWidth, windowHeight, "Raylib Odin Example")
	// raylib.SetTargetFPS(raylib.GetMonitorRefreshRate(0)) // does not need be here

	loadFont(DEBUG_FONT_ID, 56, "resources/Calistoga-Regular.ttf")
	loadFont(DEBUG_FONT_ID_2, 56, "resources/Calistoga-Regular.ttf") // Need to have something with ID = 0 for debug to work

	// root node
	{
		root := Layout_Item{}
		root.id = "Root"
		root.size_percent = {1, 1}
		root.layout_dir = .LeftToRight
		handle, _ := hms.add(&ctx.lic, root)

		ctx.root = handle
	}

	ctx.add_click = .Released
	ctx.remove_click = .Released
	ctx.resize_click = .Released

	return ctx
}


deinit :: proc(ctx: ^Context) {
	vmem.arena_destroy(&ctx.arena)
	free(ctx.clay_arena.memory)

	hms.clear(&ctx.lic)
}

// Updated cursor / pointer states and such
update_state :: proc(ctx: ^Context) {
	windowWidth = raylib.GetScreenWidth()
	windowHeight = raylib.GetScreenHeight()
	if (raylib.IsKeyPressed(.U)) {
		@(static) debugModeEnabled: bool
		debugModeEnabled = !debugModeEnabled
		clay.SetDebugModeEnabled(debugModeEnabled)
	}

	clay.SetPointerState(
		transmute(clay.Vector2)ctx.mouse_pos,
		raylib.IsMouseButtonDown(raylib.MouseButton.LEFT),
	)
	clay.UpdateScrollContainers(
		false,
		transmute(clay.Vector2)raylib.GetMouseWheelMoveV() * 5,
		raylib.GetFrameTime(),
	)
	clay.SetLayoutDimensions({cast(f32)raylib.GetScreenWidth(), cast(f32)raylib.GetScreenHeight()})


	ctx.mouse_pos_last_frame = ctx.mouse_pos
	ctx.mouse_pos = raylib.GetMousePosition()

	update_pointer_state(&ctx.remove_click, raylib.MouseButton.MIDDLE)
	update_pointer_state(&ctx.add_click, raylib.MouseButton.RIGHT)
	update_pointer_state(&ctx.resize_click, raylib.MouseButton.LEFT)
}

update_pointer_state :: proc {
	update_pointer_state_mouse,
	update_pointer_state_key,
}

update_pointer_state_mouse :: proc(
	pointer_state: ^clay.PointerDataInteractionState,
	mouse_button: raylib.MouseButton,
) {
	assert(pointer_state != nil)

	pointer_state^ = to_pointer_state(
		raylib.IsMouseButtonPressed(mouse_button),
		raylib.IsMouseButtonReleased(mouse_button),
		pointer_state^,
	)
}

update_pointer_state_key :: proc(
	pointer_state: ^clay.PointerDataInteractionState,
	key: raylib.KeyboardKey,
) {
	assert(pointer_state != nil)

	pointer_state^ = to_pointer_state(
		raylib.IsKeyPressed(key),
		raylib.IsKeyReleased(key),
		pointer_state^,
	)
}

to_pointer_state :: proc(
	down_this_frame, up_this_frame: bool,
	previous_state: clay.PointerDataInteractionState,
) -> clay.PointerDataInteractionState {
	if down_this_frame do return .PressedThisFrame

	if up_this_frame do return .ReleasedThisFrame

	if previous_state == .PressedThisFrame || previous_state == .Pressed do return .Pressed

	if previous_state == .ReleasedThisFrame || previous_state == .Released do return .Released

	panic(
		fmt.tprintf(
			"pointer state could not update down_this_frame: {}, up_this_frame: {}, previous_state: {}",
			down_this_frame,
			up_this_frame,
			previous_state,
		),
	)
}


render :: proc(render_commands: ^clay.ClayArray(clay.RenderCommand)) {
	// raylib.BeginDrawing()
	rr.clay_raylib_render(render_commands)
	// raylib.EndDrawing()
}
