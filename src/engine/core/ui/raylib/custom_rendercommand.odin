package raylib_renderer


Custom_Render_Command :: union {
	Custom_Image_Render_Command,
}

Custom_Image_Render_Command :: struct {
	image_data:     rawptr,
	flip_x, flip_y: bool,
}
