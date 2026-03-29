package layout

import rr "../raylib"
import "vendor:raylib"

DEBUG_FONT_ID :: 1
DEBUG_FONT_ID_2 :: 0

load_font :: proc(fontId: u16, fontSize: u16, path: cstring) {
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

unload_all_fonts :: proc() {
	for &font in rr.raylib_fonts {
		raylib.UnloadFont(font.font)
	}
	delete(rr.raylib_fonts)
}
