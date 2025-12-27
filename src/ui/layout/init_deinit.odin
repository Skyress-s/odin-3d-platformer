package layout
import clay "../clay-odin"
import "core:fmt"
import "core:c"
import "core:strings"
import rr "raylib"
import raylib "vendor:raylib"

windowWidth: i32 = 1024
windowHeight: i32 = 768

syntaxImage: raylib.Texture2D = {}
checkImage1: raylib.Texture2D = {}
checkImage2: raylib.Texture2D = {}
checkImage3: raylib.Texture2D = {}
checkImage4: raylib.Texture2D = {}
checkImage5: raylib.Texture2D = {}


headerTextConfig := clay.TextElementConfig {
	fontId    = FONT_ID_BODY_24,
	fontSize  = 24,
	textColor = {61, 26, 5, 255},
}

border2pxRed := clay.BorderElementConfig {
	width = {2, 2, 2, 2, 0},
	color = COLOR_RED,
}


LOREM_IPSUM_TEXT :: "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua."

animationLerpValue: f32 = -1.0

create_layout_tiling :: proc(
	root_node: ^Tiling_Node, allow_layout_edit: bool,
) -> (render_commands: clay.ClayArray(clay.RenderCommand), layout_updated: bool) {
	clay.BeginLayout()
	layout_updated = tiling_window_test(root_node, allow_layout_edit)
	return clay.EndLayout(), layout_updated
}

loadFont :: proc(fontId: u16, fontSize: u16, path: cstring) {
	assign_at(
		&rr.raylib_fonts,
		fontId,
		rr.Raylib_Font {
			font = raylib.LoadFontEx(path, cast(i32)fontSize * 2, nil, 0),
			fontId = cast(u16)fontId,
		},
	)
	raylib.SetTextureFilter(rr.raylib_fonts[fontId].font.texture, raylib.TextureFilter.TRILINEAR)
}

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
) {

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

	loadFont(
		FONT_ID_TITLE_56,
		56,
		strings.clone_to_cstring(
			strings.join({PATH_TO_RESOURCES, "resources/Calistoga-Regular.ttf"}, "/"),
		),
	)
	loadFont(
		FONT_ID_TITLE_52,
		52,
		strings.clone_to_cstring(
			strings.join({PATH_TO_RESOURCES, "resources/Calistoga-Regular.ttf"}, "/"),
		),
	)
	loadFont(
		FONT_ID_TITLE_48,
		48,
		strings.clone_to_cstring(
			strings.join({PATH_TO_RESOURCES, "resources/Calistoga-Regular.ttf"}, "/"),
		),
	)
	loadFont(
		FONT_ID_TITLE_36,
		36,
		strings.clone_to_cstring(
			strings.join({PATH_TO_RESOURCES, "resources/Calistoga-Regular.ttf"}, "/"),
		),
	)
	loadFont(
		FONT_ID_TITLE_32,
		32,
		strings.clone_to_cstring(
			strings.join({PATH_TO_RESOURCES, "resources/Calistoga-Regular.ttf"}, "/"),
		),
	)
	loadFont(
		FONT_ID_BODY_36,
		36,
		strings.clone_to_cstring(
			strings.join({PATH_TO_RESOURCES, "resources/Quicksand-Semibold.ttf"}, "/"),
		),
	)
	loadFont(
		FONT_ID_BODY_30,
		30,
		strings.clone_to_cstring(
			strings.join({PATH_TO_RESOURCES, "resources/Quicksand-Semibold.ttf"}, "/"),
		),
	)
	loadFont(
		FONT_ID_BODY_28,
		28,
		strings.clone_to_cstring(
			strings.join({PATH_TO_RESOURCES, "resources/Quicksand-Semibold.ttf"}, "/"),
		),
	)
	loadFont(
		FONT_ID_BODY_24,
		24,
		strings.clone_to_cstring(
			strings.join({PATH_TO_RESOURCES, "resources/Quicksand-Semibold.ttf"}, "/"),
		),
	)

	loadFont(
		FONT_ID_BODY_16,
		16,
			"resources/Quicksand-Semibold.ttf",
	)


	syntaxImage = raylib.LoadTexture(
		strings.unsafe_string_to_cstring(
			strings.join({PATH_TO_RESOURCES, "resources/declarative.png"}, "/"),
		),
	)
	checkImage1 = raylib.LoadTexture(
		strings.unsafe_string_to_cstring(
			strings.join({PATH_TO_RESOURCES, "resources/check_1.png"}, "/"),
		),
	)
	checkImage2 = raylib.LoadTexture(
		strings.unsafe_string_to_cstring(
			strings.join({PATH_TO_RESOURCES, "resources/check_2.png"}, "/"),
		),
	)
	checkImage3 = raylib.LoadTexture(
		strings.unsafe_string_to_cstring(
			strings.join({PATH_TO_RESOURCES, "resources/check_3.png"}, "/"),
		),
	)
	checkImage4 = raylib.LoadTexture(
		strings.unsafe_string_to_cstring(
			strings.join({PATH_TO_RESOURCES, "resources/check_4.png"}, "/"),
		),
	)
	checkImage5 = raylib.LoadTexture(
		strings.unsafe_string_to_cstring(
			strings.join({PATH_TO_RESOURCES, "resources/check_5.png"}, "/"),
		),
	)

	debugModeEnabled: bool = false

	// root := create_tiling_nodes_2X()

	// for !raylib.WindowShouldClose() {
	// 	defer free_all(context.temp_allocator)
	//
	// 	animationLerpValue += raylib.GetFrameTime()
	// 	if animationLerpValue > 1 {
	// 		animationLerpValue = animationLerpValue - 2
	// 	}
	// 	windowWidth = raylib.GetScreenWidth()
	// 	windowHeight = raylib.GetScreenHeight()
	// 	if (raylib.IsKeyPressed(.D)) {
	// 		debugModeEnabled = !debugModeEnabled
	// 		clay.SetDebugModeEnabled(debugModeEnabled)
	// 	}
	// 	clay.SetPointerState(
	// 		transmute(clay.Vector2)raylib.GetMousePosition(),
	// 		raylib.IsMouseButtonDown(raylib.MouseButton.LEFT),
	// 	)
	// 	clay.UpdateScrollContainers(
	// 		false,
	// 		transmute(clay.Vector2)raylib.GetMouseWheelMoveV() * 5,
	// 		raylib.GetFrameTime(),
	// 	)
	// 	clay.SetLayoutDimensions(
	// 		{cast(f32)raylib.GetScreenWidth(), cast(f32)raylib.GetScreenHeight()},
	// 	)
	// 	// renderCommands: clay.ClayArray(clay.RenderCommand) = createLayout(animationLerpValue < 0 ? (animationLerpValue + 1) : (1 - animationLerpValue))
	// 	renderCommands: clay.ClayArray(clay.RenderCommand) = create_layout_tiling(
	// 		animationLerpValue < 0 ? (animationLerpValue + 1) : (1 - animationLerpValue),
	// 		&root,
	// 	)
	// 	raylib.BeginDrawing()
	// 	rr.clay_raylib_render(&renderCommands)
	// 	raylib.EndDrawing()
	// }
}


deinit :: proc() {

}

// Updated cursor / pointer states and such
update_state :: proc() {
	windowWidth = raylib.GetScreenWidth()
	windowHeight = raylib.GetScreenHeight()
	// if (raylib.IsKeyPressed(.D)) {
	// 	@(static) debugModeEnabled: bool
	// 	debugModeEnabled = !debugModeEnabled
	// 	clay.SetDebugModeEnabled(debugModeEnabled)
	// }
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
