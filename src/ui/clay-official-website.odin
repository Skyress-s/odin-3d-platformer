package main

import clay "clay-odin"
import "core:c"
import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:strings"
import "core:testing"
import "vendor:raylib"
import lay "layout"


windowWidth: i32 = 1024
windowHeight: i32 = 768

syntaxImage: raylib.Texture2D = {}
checkImage1: raylib.Texture2D = {}
checkImage2: raylib.Texture2D = {}
checkImage3: raylib.Texture2D = {}
checkImage4: raylib.Texture2D = {}
checkImage5: raylib.Texture2D = {}

FONT_ID_BODY_16 :: 0
FONT_ID_TITLE_56 :: 9
FONT_ID_TITLE_52 :: 1
FONT_ID_TITLE_48 :: 2
FONT_ID_TITLE_36 :: 3
FONT_ID_TITLE_32 :: 4
FONT_ID_BODY_36 :: 5
FONT_ID_BODY_30 :: 6
FONT_ID_BODY_28 :: 7
FONT_ID_BODY_24 :: 8

COLOR_DELTA: c.float : 50
COLOR_ONE :: clay.Color{0, 0, 0, 255}
COLOR_TWO :: clay.Color{COLOR_DELTA, COLOR_DELTA, COLOR_DELTA, 255}
COLOR_THREE :: clay.Color{COLOR_DELTA * 2, COLOR_DELTA * 2, COLOR_DELTA * 2, 255}
COLOR_FOUR :: clay.Color{COLOR_DELTA * 3, COLOR_DELTA * 3, COLOR_DELTA * 3, 255}
COLOR_FIVE :: clay.Color{COLOR_DELTA * 4, COLOR_DELTA * 4, COLOR_DELTA * 4, 255}
COLOR_SIX :: clay.Color{COLOR_DELTA * 5, COLOR_DELTA * 5, COLOR_DELTA * 5, 255}
COLOR_SEVEN :: clay.Color{COLOR_DELTA * 6, COLOR_DELTA * 6, COLOR_DELTA * 6, 255}

COLOR_LIGHT :: clay.Color{244, 235, 230, 255}
COLOR_LIGHT_HOVER :: clay.Color{224, 215, 210, 255}
COLOR_BUTTON_HOVER :: clay.Color{238, 227, 225, 255}
COLOR_BROWN :: clay.Color{61, 26, 5, 255}
//COLOR_RED :: clay.Color {252, 67, 27, 255}
COLOR_RED :: clay.Color{168, 66, 28, 255}
COLOR_RED_HOVER :: clay.Color{148, 46, 8, 255}
COLOR_ORANGE :: clay.Color{225, 138, 50, 255}
COLOR_BLUE :: clay.Color{111, 173, 162, 255}
COLOR_TEAL :: clay.Color{111, 173, 162, 255}
COLOR_BLUE_DARK :: clay.Color{2, 32, 82, 255}

COLOR_GREEN :: clay.Color{50, 200, 50, 255}

// Colors for top stripe
COLOR_TOP_BORDER_1 :: clay.Color{168, 66, 28, 255}
COLOR_TOP_BORDER_2 :: clay.Color{223, 110, 44, 255}
COLOR_TOP_BORDER_3 :: clay.Color{225, 138, 50, 255}
COLOR_TOP_BORDER_4 :: clay.Color{236, 189, 80, 255}
COLOR_TOP_BORDER_5 :: clay.Color{240, 213, 137, 255}

COLOR_BLOB_BORDER_1 :: clay.Color{168, 66, 28, 255}
COLOR_BLOB_BORDER_2 :: clay.Color{203, 100, 44, 255}
COLOR_BLOB_BORDER_3 :: clay.Color{225, 138, 50, 255}
COLOR_BLOB_BORDER_4 :: clay.Color{236, 159, 70, 255}
COLOR_BLOB_BORDER_5 :: clay.Color{240, 189, 100, 255}

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
	lerpValue: f32,
	root_node: ^lay.Tiling_Node,
) -> clay.ClayArray(clay.RenderCommand) {
	clay.BeginLayout()
	lay.tiling_window_test(root_node)
	return clay.EndLayout()
}


loadFont :: proc(fontId: u16, fontSize: u16, path: cstring) {
	assign_at(
		&raylib_fonts,
		fontId,
		Raylib_Font {
			font = raylib.LoadFontEx(path, cast(i32)fontSize * 2, nil, 0),
			fontId = cast(u16)fontId,
		},
	)
	raylib.SetTextureFilter(raylib_fonts[fontId].font.texture, raylib.TextureFilter.TRILINEAR)
}

errorHandler :: proc "c" (errorData: clay.ErrorData) {
	if (errorData.errorType == clay.ErrorType.DuplicateId) {
		// etc
	}
}

main :: proc() {
	minMemorySize: c.size_t = cast(c.size_t)clay.MinMemorySize()
	memory := make([^]u8, minMemorySize)
	arena: clay.Arena = clay.CreateArenaWithCapacityAndMemory(minMemorySize, memory)
	clay.Initialize(
		arena,
		{cast(f32)raylib.GetScreenWidth(), cast(f32)raylib.GetScreenHeight()},
		{handler = errorHandler},
	)
	clay.SetMeasureTextFunction(measure_text, nil)

	PATH_TO_RESOURCES :string: "content/"

	raylib.SetConfigFlags({.VSYNC_HINT, .WINDOW_RESIZABLE, .MSAA_4X_HINT})
	raylib.InitWindow(windowWidth, windowHeight, "Raylib Odin Example")
	raylib.SetTargetFPS(raylib.GetMonitorRefreshRate(0))
	loadFont(FONT_ID_TITLE_56, 56, strings.clone_to_cstring(strings.join({PATH_TO_RESOURCES, "resources/Calistoga-Regular.ttf"}, "/")))
	loadFont(FONT_ID_TITLE_52, 52, strings.clone_to_cstring(strings.join({PATH_TO_RESOURCES, "resources/Calistoga-Regular.ttf"}, "/")))
	loadFont(FONT_ID_TITLE_48, 48, strings.clone_to_cstring(strings.join({PATH_TO_RESOURCES, "resources/Calistoga-Regular.ttf"}, "/")))
	loadFont(FONT_ID_TITLE_36, 36, strings.clone_to_cstring(strings.join({PATH_TO_RESOURCES, "resources/Calistoga-Regular.ttf"}, "/")))
	loadFont(FONT_ID_TITLE_32, 32, strings.clone_to_cstring(strings.join({PATH_TO_RESOURCES, "resources/Calistoga-Regular.ttf"}, "/")))
	loadFont(FONT_ID_BODY_36, 36, strings.clone_to_cstring(strings.join({PATH_TO_RESOURCES, "resources/Quicksand-Semibold.ttf"}, "/")))
	loadFont(FONT_ID_BODY_30, 30, strings.clone_to_cstring(strings.join({PATH_TO_RESOURCES, "resources/Quicksand-Semibold.ttf"}, "/")))
	loadFont(FONT_ID_BODY_28, 28, strings.clone_to_cstring(strings.join({PATH_TO_RESOURCES, "resources/Quicksand-Semibold.ttf"}, "/")))
	loadFont(FONT_ID_BODY_24, 24, strings.clone_to_cstring(strings.join({PATH_TO_RESOURCES, "resources/Quicksand-Semibold.ttf"}, "/")))
	loadFont(FONT_ID_BODY_16, 16, strings.clone_to_cstring(strings.join({PATH_TO_RESOURCES, "resources/Quicksand-Semibold.ttf"}, "/")))

	syntaxImage = raylib.LoadTexture(strings.unsafe_string_to_cstring(strings.join({PATH_TO_RESOURCES,"resources/declarative.png"}, "/")))
	checkImage1 = raylib.LoadTexture(strings.unsafe_string_to_cstring(strings.join({PATH_TO_RESOURCES, "resources/check_1.png"}, "/")))
	checkImage2 = raylib.LoadTexture(strings.unsafe_string_to_cstring(strings.join({PATH_TO_RESOURCES, "resources/check_2.png"}, "/")))
	checkImage3 = raylib.LoadTexture(strings.unsafe_string_to_cstring(strings.join({PATH_TO_RESOURCES, "resources/check_3.png"}, "/")))
	checkImage4 = raylib.LoadTexture(strings.unsafe_string_to_cstring(strings.join({PATH_TO_RESOURCES, "resources/check_4.png"}, "/")))
	checkImage5 = raylib.LoadTexture(strings.unsafe_string_to_cstring(strings.join({PATH_TO_RESOURCES, "resources/check_5.png"}, "/")))

	debugModeEnabled: bool = false

	root := lay.create_tiling_nodes_2X()

	for !raylib.WindowShouldClose() {
		defer free_all(context.temp_allocator)

		animationLerpValue += raylib.GetFrameTime()
		if animationLerpValue > 1 {
			animationLerpValue = animationLerpValue - 2
		}
		windowWidth = raylib.GetScreenWidth()
		windowHeight = raylib.GetScreenHeight()
		if (raylib.IsKeyPressed(.D)) {
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
		clay.SetLayoutDimensions(
			{cast(f32)raylib.GetScreenWidth(), cast(f32)raylib.GetScreenHeight()},
		)
		// renderCommands: clay.ClayArray(clay.RenderCommand) = createLayout(animationLerpValue < 0 ? (animationLerpValue + 1) : (1 - animationLerpValue))
		renderCommands: clay.ClayArray(clay.RenderCommand) = create_layout_tiling(
			animationLerpValue < 0 ? (animationLerpValue + 1) : (1 - animationLerpValue),
			&root,
		)
		raylib.BeginDrawing()
		clay_raylib_render(&renderCommands)
		raylib.EndDrawing()
	}
}
