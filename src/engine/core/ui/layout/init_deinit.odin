package layout
import clay "../clay-odin"
import rr "../raylib"
import "base:runtime"
import "core:c"
import hm "core:container/handle_map"
import "core:fmt"
import vmem "core:mem/virtual"
import raylib "vendor:raylib"

windowWidth: i32 = 1024
windowHeight: i32 = 768

MODIFIER_KEYS: []raylib.KeyboardKey : {.LEFT_SHIFT, .LEFT_CONTROL, .LEFT_ALT, .LEFT_SUPER}

errorHandler :: proc "c" (errorData: clay.ErrorData) {
	context = runtime.default_context()
	assert(errorData.errorType == nil, fmt.tprintf("CLAY ERROR: {}", errorData))
}

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

	temp_arena_init_err := vmem.arena_init_growing(&ctx.temp_arena)
	assert(temp_arena_init_err == nil)
	ctx.temp_allocator = vmem.arena_allocator(&ctx.temp_arena)

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


	// TODO: Change in future if its needed:
	// Hardcoded. Should be moved / add functionality so user can choose what fonts are used.
	load_font(DEBUG_FONT_ID, 56, "content/resources/Calistoga-Regular.ttf")
	load_font(DEBUG_FONT_ID_2, 56, "content/resources/Calistoga-Regular.ttf")

	// root node
	{

		root := make_layout_item(&ctx, "root")
		root.layout_dir = .LeftToRight
		root.size_percent = {1, 1}
		handle, _ := hm.add(&ctx.lic, root)

		ctx.root = handle
	}

	ctx.add_click = .Released
	ctx.remove_click = .Released
	ctx.resize_click = .Released
	ctx.move_click = .Released

	return ctx
}


deinit :: proc(ctx: ^Context) {
	vmem.arena_destroy(&ctx.arena)
	vmem.arena_destroy(&ctx.temp_arena)
	free(ctx.clay_arena.memory)

	delete(ctx.active_elements.elems)

	unload_all_fonts()

	hm.clear(&ctx.lic)
}

// Updated cursor / pointer states and such
update_state :: proc(ctx: ^Context, mouse_pos: raylib.Vector2) {
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
	ctx.screen_dimensions = {cast(f32)raylib.GetScreenWidth(), cast(f32)raylib.GetScreenHeight()}
	clay.SetLayoutDimensions(ctx.screen_dimensions)

	ctx.mouse_pos_last_frame = ctx.mouse_pos
	ctx.mouse_pos = mouse_pos

	// TODO: Change in future if its needed:
	// Should be changed so that we can change at runtime what actions does what!
	update_pointer_state_mouse(&ctx.remove_click, .SIDE, .LEFT_ALT)
	update_pointer_state_mouse(&ctx.add_click, .MIDDLE, .LEFT_ALT)
	update_pointer_state_mouse(&ctx.resize_click, .RIGHT, .LEFT_ALT)
	update_pointer_state_mouse(&ctx.move_click, .LEFT, .LEFT_ALT)

	ctx.pressed_fullscreen_this_frame = raylib.IsKeyPressed(.F)

	ctx.hover_layout_handle = get_hovered_layout_item_leaf(ctx)
}


update_pointer_state_mouse :: proc(
	pointer_state: ^clay.PointerDataInteractionState,
	mouse_button: raylib.MouseButton,
	modifier_key: raylib.KeyboardKey,
) {
	assert(pointer_state != nil)

	modifier_down :=
		(modifier_key == nil && !any_modifier_key_down_or_pressed()) ||
		(raylib.IsKeyPressed(modifier_key) || raylib.IsKeyDown(modifier_key))

	pointer_state^ = to_pointer_state(
		raylib.IsMouseButtonPressed(mouse_button),
		raylib.IsMouseButtonReleased(mouse_button),
		modifier_down,
		pointer_state^,
	)
}

any_modifier_key_down_or_pressed :: proc() -> bool {
	for &key in MODIFIER_KEYS {
		if raylib.IsKeyPressed(key) || raylib.IsKeyDown(key) do return true
	}

	return false

}


to_pointer_state :: proc(
	down_this_frame, up_this_frame, modifier_down: bool,
	previous_state: clay.PointerDataInteractionState,
) -> clay.PointerDataInteractionState {
	if down_this_frame && modifier_down do return .PressedThisFrame

	if up_this_frame && previous_state == .Pressed do return .ReleasedThisFrame

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
	rr.clay_raylib_render(render_commands)
}
