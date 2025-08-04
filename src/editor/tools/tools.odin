package tools

import spat "../../Spatial"
import "core:math/linalg"
import "core:math"
import rl "vendor:raylib"

Position_Tool :: distinct struct {
	position: spat.Vector,
}

Rotation_Tool :: distinct struct {
	rotation: spat.Quaternion,
}

Scale_Tool :: distinct struct {
	scale: spat.Vector,
}


State :: enum {
	Position,
	Rotation,
	Scale,
}

Transform_Tool_Mode :: distinct struct {
	state: State,
	// Other state go here, like use_local_space etc
}

Transform_Tool_Data :: distinct struct {
	using transform:     spat.Transform,
	transform_tool_mode: Transform_Tool_Mode,
}


update_transform_tool :: proc(data: ^Transform_Tool_Data, cam: ^rl.Camera3D, left_mouse_button_down: bool, mouse_ray: spat.Ray, start_mouse_position, current_mouse_position: spat.Vector2) {
	current_ray:= rl.GetScreenToWorldRay(current_mouse_position, cam^)
	// TODO: Resume here 

}
