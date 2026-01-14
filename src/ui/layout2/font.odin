package layout

import rr "raylib"
import "vendor:raylib"

DEBUG_FONT_ID :: 1

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
