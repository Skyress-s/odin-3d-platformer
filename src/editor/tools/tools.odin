package tools

import spat "../../Spatial"
import "core:fmt"
import hms "../../handle_map/handle_map_static"
import l "../../level"
import rlb "../../raylib_bridge"
import "core:math"
import "core:math/linalg"
import rl "vendor:raylib"

Position_Tool :: distinct struct {
	position: spat.Vector,
}

Rotation_Tool :: distinct struct {
	rotation: spat.Quaternion,
	axis:     spat.Vector,
}

Scale_Tool :: distinct struct {
	scale, first_intersect_location : spat.Vector,
	axis: spat.Axis,
	plane: spat.Plane,
}


// TODO: This can be removed probably.
State :: enum {
	Position,
	Rotation,
	Scale,
}

Transform_Tool_Active_Type :: union #no_nil {
	Position_Tool,
	Rotation_Tool,
	Scale_Tool,
}

Transform_Tool_Data :: distinct struct {
	start_transform:           spat.Transform,
	state:                     State, // TODO: REMOVE
	active_tool:               Transform_Tool_Active_Type,
	plane:                     spat.Plane, // Plane we are dragging along
	start_mouse_position:      spat.Vector2,
	start_ray_plane_intersect: spat.Vector,
	target_object_id:          spat.Collision_Object_Id,
	dragging:                  bool,
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
	object_map: ^spat.Collision_Object_Handle_Map,
	// mouse_ray: spat.Ray,
	// start_mouse_position,
	current_mouse_position: spat.Vector2,
) {
	if !left_mouse_button_down do return

	switch &active_tool in data.active_tool {
	case Position_Tool:
		current_ray := rlb.convert_ray(rl.GetScreenToWorldRay(current_mouse_position, cam^))
		did_intersect, intersection := spat.ray_plane_intersect(
			&current_ray,
			data.plane.normal,
			data.plane.point_on_plane,
		)
		found_object := hms.get(object_map, data.target_object_id)
		found_object.data.transform.position =
			data.start_transform.position + (intersection - data.plane.point_on_plane)

	case Rotation_Tool:
		current_ray := rlb.convert_ray(rl.GetScreenToWorldRay(current_mouse_position, cam^))
		did_intersect, intersection := spat.ray_plane_intersect(
			&current_ray,
			data.plane.normal,
			data.plane.point_on_plane,
		)

		found_object := hms.get(object_map, data.target_object_id)
			new_qua := linalg.quaternion_from_forward_and_up_f32(data.start_ray_plane_intersect - data.start_transform.position, data.plane.normal)
			new_quat := linalg.quaternion_from_forward_and_up_f32(intersection - data.start_transform.position, data.plane.normal)
			//found_object.data.transform.rotation = spat.QuaternionData{new_quat.x,new_quat.y, new_quat.z, new_quat.w}

			//found_object.data.transform.rotation = linalg.QUATERNIONF32_IDENTITY * new_quat
			
			found_object.data.transform.rotation =   new_quat *linalg.quaternion_inverse(new_qua)* data.start_transform.rotation

		//panic("rotation not implemented")
	case Scale_Tool:
		panic("scale not implemented")
	}
	// TODO: Resume here  
}
