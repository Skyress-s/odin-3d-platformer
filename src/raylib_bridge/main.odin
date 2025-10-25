package raylib_bridge

import rl "vendor:raylib"
import spat "../Spatial"
import "../lightray"

// TODO: Might be kinda slow since we dont pass by ref
convert_ray :: proc(rl_ray: rl.Ray) -> spat.Ray{
	return spat.Ray{rl_ray.position, rl_ray.position + rl_ray.direction}
}

raylib_init :: proc() {
	rl.SetConfigFlags({.VSYNC_HINT, .WINDOW_RESIZABLE, .MSAA_4X_HINT})
	rl.InitWindow(1920, 1085, "mph*0.5mv^2")
	//rl.ToggleBorderlessWindowed()

	// rl.SetTargetFPS(180)
	rl.SetTargetFPS(180) // TODO CCD not working at low fps

	rl.SetWindowSize(rl.GetScreenWidth(), rl.GetScreenHeight())
	rl.DisableCursor()


	lightray.init_lighting()


	lightray.create_light(.DIRECTIONAL, {10, 10, 10}, spat.ZERO_VEC3, rl.RAYWHITE)
	{
		// backlight_color := rl.SKYBLUE
		backlight_color := rl.SKYBLUE
		// Color{ 102, 191, 255, 255 }

		lightray.create_light(.DIRECTIONAL, {-10, -10, 10}, spat.ZERO_VEC3, backlight_color)
	}

}

raylib_deinit :: proc() {
	rl.CloseWindow()
	lightray.destroy_lighting()

}
