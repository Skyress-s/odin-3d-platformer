package tools

import spat "../../Spatial"
import rlb "../../raylib_bridge"
import "core:math"
import "core:math/linalg"
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

// Transform_Tool_Mode :: distinct struct {
// 	// Other state go here, like use_local_space etc
// }

Transform_Tool_Data :: distinct struct {
	transform:                 spat.Transform,
	start_transform:           spat.Transform,
	state:                     State,
	plane:                     spat.Plane,
	start_mouse_position:      spat.Vector2,
	start_ray_plane_intersect: spat.Vector,
}


init_transform_tool :: proc(
	state: State,
	plane: spat.Plane,
	mouse_position: spat.Vector2,
	cam: ^rl.Camera3D,
) -> (
	data: Transform_Tool_Data,
) {
	data.state = state
	switch (state) {
	case State.Position:
		data.plane = plane
		data.start_mouse_position = mouse_position

		{
			current_ray := rlb.convert_ray(rl.GetScreenToWorldRay(mouse_position, cam^))
			ok, intersect := spat.ray_plane_intersect(
				&current_ray,
				plane.normal,
				plane.point_on_plane,
			)

			assert(ok, "todo handle this")
			data.start_ray_plane_intersect = intersect
		}
	case State.Rotation:
		panic("rotation not implemented")
	case State.Scale:
		panic("scale not implemented")
	}

	return data
}

update_transform_tool :: proc(
	data: ^Transform_Tool_Data,
	cam: ^rl.Camera3D,
	left_mouse_button_pressed: bool,
	left_mouse_button_down: bool,

	// mouse_ray: spat.Ray,
	// start_mouse_position,
	current_mouse_position: spat.Vector2,
) {

	switch (data.state) {
	case State.Position:
		current_ray := rlb.convert_ray(rl.GetScreenToWorldRay(current_mouse_position, cam^))
		did_intersect, intersection := spat.ray_plane_intersect(
			&current_ray,
			data.plane.normal,
			data.plane.point_on_plane,
		)


		data.transform.position = intersection - data.start_ray_plane_intersect
	case State.Rotation:
		panic("rotation not implemented")
	case State.Scale:
		panic("scale not implemented")
	}


	// TODO: Resume here  

}
