package camera

import "core:math"
import "core:math/ease"
import "core:math/linalg"
import rl "vendor:raylib"


Settings :: struct {
	fovy_increase_per_unit_speed: f32, // if set to 0.5. Then if our speed is 40, the fov will be increased by 20.
	lerp_speed:                   f32,
}


Camera :: rl.Camera3D

Global_State :: struct {
	// end_camera_settings: Camera_Settings,
	// start_camera_settings: Camera_Settings,
	base_camera:      Camera,
	current_camera:   Camera,
	current_settings: Settings, // lerps towards to the target_camera_settings
}

init :: proc(cam: Camera, camera_settings: Settings) -> (state: Global_State) {

	state.current_settings = camera_settings
	state.base_camera = cam
	state.current_camera = cam
	return state
}

interp_fov :: proc(gs: ^Global_State, player_speed: f32, dt: f32) {
	// gs.base_camera.fovy + gs.current_settings.fovy_increase_per_unit_speed * player_speed
	gs.current_camera.fovy = math.lerp(
		gs.current_camera.fovy,
		gs.base_camera.fovy + gs.current_settings.fovy_increase_per_unit_speed * player_speed,
		dt * gs.current_settings.lerp_speed,
	)

}

update_transform :: proc(gc: ^Global_State, position, forward, right: rl.Vector3) {
	gc.current_camera.position = position
	gc.current_camera.target = gc.current_camera.position + forward
	gc.current_camera.up = linalg.cross(forward, right)
}
