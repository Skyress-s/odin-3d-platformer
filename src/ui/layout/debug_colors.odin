package layout
import clay "../clay-odin"
import "core:c"

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
COLOR_LIGHT_BLACK :: clay.Color{100, 100, 100, 255}
COLOR_BLACK :: clay.Color{0, 0, 0, 255}

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

COLOR_DARK_GREY :: clay.Color{50,50,50,255}
COLOR_GREY :: clay.Color{110,110,110,255}
COLOR_LIGHT_GREY :: clay.Color{200,200,200,255}

leaf_dist_to_color :: proc(dist: u32) -> clay.Color {
	switch dist {
	case 0:
		return COLOR_ONE
	case 1:
		return COLOR_TWO
	case 2:
		return COLOR_THREE
	case 3:
		return COLOR_FOUR
	case 4:
		return COLOR_FIVE
	case 5:
		return COLOR_SIX
	}

	return COLOR_SEVEN
}
