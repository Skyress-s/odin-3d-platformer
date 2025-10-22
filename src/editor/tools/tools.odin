package tools

import spat "../../Spatial"
import hms "../../handle_map/handle_map_static"
import l "../../level"
import rlb "../../raylib_bridge"
import "core:fmt"
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
	scale, first_intersect_location: spat.Vector,
	axis:                            spat.Axis,
	plane:                           spat.Plane,
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

on_click :: proc(
	position_transform_tool: ^Transform_Tool_Data,
	cam: ^rl.Camera3D,
	current_level: ^l.Level,
) {

	ray := rlb.convert_ray(rl.GetScreenToWorldRay(rl.GetMousePosition(), cam^))
	ray.end = ray.origin + (ray.end - ray.origin) * 100000 // augh


	found_object := hms.get(
		&current_level.collision_object_map,
		position_transform_tool.target_object_id,
	)

	if found_object == nil {
		ok, id, position := spat.ray_intersect_spatial_hash_grid(
			&current_level.spatial_hash_grid,
			&current_level.collision_object_map,
			&ray,
		)

		if ok {
			position_transform_tool.target_object_id = id
			position_transform_tool.start_transform =
				hms.get(&current_level.collision_object_map, id).data.transform
		}
		return
	}

	switch &active_tool in position_transform_tool.active_tool {
	case Position_Tool:
		planes := calculate_drag_planes(found_object.transform.position, cam.position)
		plane_hit, plane_intersect_location, plane_normal := ray_transform_tool_planes_intersect(
			&ray,
			&planes,
		)
		if plane_hit != Interacted_Plane.None {
			fmt.printfln("{:5.f} {}", rl.GetTime(), plane_hit)

			rl.DrawCube(plane_intersect_location, 5, 5, 5, rl.WHITE)

		}
		if plane_hit != .None {

			position_transform_tool.dragging = true
			position_transform_tool.plane.point_on_plane = plane_intersect_location
			position_transform_tool.plane.normal = plane_normal
			position_transform_tool.start_transform = found_object.transform
			position_transform_tool.start_ray_plane_intersect = plane_intersect_location

			//continue
		} else do position_transform_tool.target_object_id = spat.Collision_Object_Id{}

	case Rotation_Tool:
		planes := calculate_drag_planes(found_object.transform.position, cam.position)
		plane_hit, plane_intersect_location, plane_normal := ray_transform_tool_planes_intersect(
			&ray,
			&planes,
		)
		if plane_hit != Interacted_Plane.None {
			fmt.printfln("{:5.f} {}", rl.GetTime(), plane_hit)

			// rl.DrawCube(plane_intersect_location, 5, 5, 5, rl.WHITE)

		}
		if plane_hit != .None {

			position_transform_tool.dragging = true
			position_transform_tool.plane.point_on_plane = plane_intersect_location
			position_transform_tool.plane.normal = plane_normal
			position_transform_tool.start_transform = found_object.transform
			position_transform_tool.start_ray_plane_intersect = plane_intersect_location

			//continue
		} else do position_transform_tool.target_object_id = spat.Collision_Object_Id{}

	case Scale_Tool:
		boxes := calculate_scale_bars(found_object.transform, cam.position)
		interacter_bar, location := ray_scale_bars_collision(&ray, &boxes)
		fmt.println(interacter_bar)

		if interacter_bar != .None {

			axis_vector := spat.axis_to_unit_vector(interacter_bar)
			position_transform_tool.dragging = true
			active_tool.axis = interacter_bar
			active_tool.plane = spat.Plane {
				point_on_plane = location,
				normal         = linalg.cross(
					axis_vector,
					linalg.cross(axis_vector, cam.position - location),
				),
			}
			hit_plane, hit_location := spat.ray_plane_intersect(
				&ray,
				active_tool.plane.normal,
				active_tool.plane.point_on_plane,
			)
			active_tool.first_intersect_location = hit_location
			// position_transform_tool.plane.point_on_plane = plane_intersect_location
			// position_transform_tool.plane.normal = plane_normal
			position_transform_tool.start_transform = found_object.transform

			//continue
		} else do position_transform_tool.target_object_id = spat.Collision_Object_Id{}
	}


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
	if !data.dragging do return
	// if !left_mouse_button_down do return
	current_ray := rlb.convert_ray(rl.GetScreenToWorldRay(current_mouse_position, cam^))
	found_object := hms.get(object_map, data.target_object_id)
	assert(found_object != nil)

	switch &active_tool in data.active_tool {
	case Position_Tool:
		did_intersect, intersection := spat.ray_plane_intersect(
			&current_ray,
			data.plane.normal,
			data.plane.point_on_plane,
		)
		found_object.data.transform.position =
			data.start_transform.position + (intersection - data.plane.point_on_plane)

	case Rotation_Tool:
		did_intersect, intersection := spat.ray_plane_intersect(
			&current_ray,
			data.plane.normal,
			data.plane.point_on_plane,
		)

		new_qua := linalg.quaternion_from_forward_and_up_f32(
			data.start_ray_plane_intersect - data.start_transform.position,
			data.plane.normal,
		)
		new_quat := linalg.quaternion_from_forward_and_up_f32(
			intersection - data.start_transform.position,
			data.plane.normal,
		)
		//found_object.data.transform.rotation = spat.QuaternionData{new_quat.x,new_quat.y, new_quat.z, new_quat.w}

		//found_object.data.transform.rotation = linalg.QUATERNIONF32_IDENTITY * new_quat

		found_object.data.transform.rotation =
			new_quat * linalg.quaternion_inverse(new_qua) * data.start_transform.rotation

	//panic("rotation not implemented")
	case Scale_Tool:
		hit, location := spat.ray_plane_intersect(
			&current_ray,
			active_tool.plane.normal,
			active_tool.plane.point_on_plane,
		)
		if !hit do return
		delta := location - active_tool.first_intersect_location

		dirs := calculate_dirs(found_object.transform.position, cam.position)
		axis_vector := spat.axis_to_unit_vector(active_tool.axis)

		dot := linalg.dot(axis_vector, delta)

		scale_scale: f32 = 0.2

		#partial switch active_tool.axis {
		case .X:
			found_object.transform.scale.x = (data.start_transform.scale.x - dot * scale_scale)
		case .Y:
			found_object.transform.scale.y = (data.start_transform.scale.y - dot * scale_scale)
		case .Z:
			found_object.transform.scale.z = (data.start_transform.scale.z - dot * scale_scale)
		}

		fmt.printfln("updates scale!: {}", found_object.transform.scale)

	}
	// TODO: Resume here
}
