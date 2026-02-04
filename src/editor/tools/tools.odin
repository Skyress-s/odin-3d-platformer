package tools

import spat "../../Spatial"
import hms "../../handle_map/handle_map_static"
import l "../../level"
import rlb "../../raylib_bridge"
import "core:fmt"
import "core:log"
import "core:math"
import "core:math/linalg"
import "core:time"
import rl "vendor:raylib"

Plane_Vector_Union :: union #no_nil {
	spat.Plane,
	spat.Vector,
}

Position_Tool :: distinct struct {
	position:       spat.Vector,
	translate_mode: Plane_Vector_Union, // Move along plane or vector
}

Rotation_Tool :: distinct struct {
	rotation: spat.Quaternion,
	axis:     spat.Vector,
}

Scale_Tool :: distinct struct {
	scale:        spat.Vector,
	// scale_mode: Plane_Vector_Union,
	axis:         spat.Axis, // todo could probably be a spat.Axis instead
	scale_normal: spat.Vector,
	// plane: spat.Plane,
}


Transform_Tool_Active_Type :: union #no_nil {
	Position_Tool,
	Rotation_Tool,
	Scale_Tool,
}

Transform_Tool_Data :: distinct struct {
	active_tool:               Transform_Tool_Active_Type,
	dragging:                  bool,
	start_transform:           spat.Transform,
	// start_mouse_position:      spat.Vector2,
	start_ray_plane_intersect: spat.Vector,
	target_object_id:          spat.Collision_Object_Id,
	local_tranform:            bool,
}


// todo please dear "})& please remove
tooltip_local: bool = true 

init_transform_tool :: proc() -> (data: Transform_Tool_Data) {
	// Does nothing atm
	data.local_tranform = true
	return data
}

on_click :: proc(
	transform_tool: ^Transform_Tool_Data,
	cam: ^rl.Camera3D,
	current_level: ^l.Level,
	mouse_pos: rl.Vector2,
	ray: spat.Ray,
) {

	// TODO use ray, not a line (even though its called ray atm, it really is a line, since its not infinite)

	// ray := rlb.convert_ray(rl.GetScreenToWorldRay(mouse_pos, cam^))
	ray := ray
	ray.end = ray.origin + (ray.end - ray.origin) * 100000 // augh

	found_object := hms.get(&current_level.collision_object_map, transform_tool.target_object_id)

	if found_object == nil {
		hit_object, id, position := spat.ray_intersect_spatial_hash_grid(
			&current_level.spatial_hash_grid,
			&current_level.collision_object_map,
			&ray,
		)

		if hit_object {
			transform_tool.target_object_id = id
			transform_tool.start_transform =
				hms.get(&current_level.collision_object_map, id).data.transform
		}
		return
	}

	// Have target from this point
	switch &active_tool in transform_tool.active_tool {
	case Position_Tool:
		on_click_position_tool(transform_tool, &active_tool, cam.position, found_object, ray)
	case Rotation_Tool:
		on_click_rotation_tool(transform_tool, &active_tool, cam.position, found_object, ray)
	case Scale_Tool:
		on_click_scale_tool(transform_tool, &active_tool, cam.position, found_object, ray)
	}


}

on_click_position_tool :: proc(
	transform_tool: ^Transform_Tool_Data,
	active_tool: ^Position_Tool,
	cam_position: spat.Vector,
	found_object: ^spat.Collision_Object_Data_Runtime,
	ray: spat.Ray,
) {
	ray := ray
	planes := generate_axis_planes(cam_position)

	transform_axis_planes(&planes, found_object.transform, tooltip_local)

	bars := generate_axis_bars()
	transform_axis_bars(&bars, found_object.transform, tooltip_local)
	bars_hit, bars_hit_location := ray_axis_bars_intersect(&ray, &bars)
	plane_hit, plane_hit_location, plane_normal := ray_axis_planes_intersect(&ray, &planes)

	bars_dist :f32= linalg.distance(cam_position, bars_hit_location)
	planes_dist :f32= linalg.distance(cam_position, plane_hit_location)

	plane_hit_closer_than_bars := bars_hit == .None || (bars_hit != .None && planes_dist < bars_dist)
	if plane_hit != .None && plane_hit_closer_than_bars {
		transform_tool.dragging = true
		transform_tool.start_transform = found_object.transform
		transform_tool.start_ray_plane_intersect = plane_hit_location

		active_tool.translate_mode = spat.Plane {
			point_on_plane = transform_tool.start_ray_plane_intersect,
			normal         = plane_normal,
		}
	} else if bars_hit != .None {
		transform_tool.dragging = true
		transform_tool.start_transform = found_object.transform
		transform_tool.start_ray_plane_intersect = bars_hit_location
		if tooltip_local {
			active_tool.translate_mode = spat.transform_vector_tr(
				found_object.transform,
				spat.axis_to_unit_vector(bars_hit),
			)
		} else {
			active_tool.translate_mode = spat.axis_to_unit_vector(bars_hit)

		}
	} else { 	// Hit nothing, stop tool
		transform_tool.target_object_id = spat.Collision_Object_Id{}
	}
}

on_click_rotation_tool :: proc(
	transform_tool: ^Transform_Tool_Data,
	active_tool: ^Rotation_Tool,
	cam_position: spat.Vector,
	found_object: ^spat.Collision_Object_Data_Runtime,
	ray: spat.Ray,
) {
	ray := ray
	planes := generate_axis_planes(found_object.transform.position)
	transform_axis_planes(&planes, found_object.transform, tooltip_local)

	plane_hit, plane_intersect_location, plane_normal := ray_axis_planes_intersect(&ray, &planes)

	if plane_hit != .None {

		transform_tool.dragging = true
		transform_tool.start_transform = found_object.transform
		transform_tool.start_ray_plane_intersect = plane_intersect_location
		active_tool.axis = plane_normal

		//continue
	} else do transform_tool.target_object_id = spat.Collision_Object_Id{}

}

on_click_scale_tool :: proc(
	transform_tool: ^Transform_Tool_Data,
	active_tool: ^Scale_Tool,
	cam_position: spat.Vector,
	found_object: ^spat.Collision_Object_Data_Runtime,
	ray: spat.Ray,
) {
	ray := ray
	scale_bars := generate_axis_bars()
	transform_axis_bars(&scale_bars, found_object.transform, true)

	axis_hit, intersect_location := ray_axis_bars_intersect(&ray, &scale_bars)

	if axis_hit != .None {

		transform_tool.dragging = true
		transform_tool.start_transform = found_object.transform
		transform_tool.start_ray_plane_intersect = intersect_location
		active_tool.axis = axis_hit 
		active_tool.scale_normal = 
			spat.transform_vector_tr(
				found_object.transform,
				spat.axis_to_unit_vector(axis_hit),
			)

		//continue
	} else do transform_tool.target_object_id = spat.Collision_Object_Id{}

}
update_transform_tool :: proc(
	data: ^Transform_Tool_Data,
	cam: ^rl.Camera3D,
	left_mouse_button_pressed: bool,
	left_mouse_button_down: bool,
	object_map: ^spat.Collision_Object_Handle_Map,
	ray: spat.Ray
) {
	if !data.dragging do return
	log.warnf("update {}", time.to_unix_seconds(time.now()))


	current_ray := ray
	// current_ray := rlb.convert_ray(rl.GetScreenToWorldRay(current_mouse_position, cam^))
	found_object := hms.get(object_map, data.target_object_id)
	assert(found_object != nil)

	switch &active_tool in data.active_tool {
	case Position_Tool:
		norm: spat.Vector
		switch &trans_mode in active_tool.translate_mode {
		case spat.Plane:
			norm = trans_mode.normal
		case spat.Vector:
			norm = linalg.cross(
				linalg.cross(trans_mode, (cam.position - data.start_ray_plane_intersect)),
				trans_mode,
			)
		}
		did_intersect, intersection := spat.ray_plane_intersect(
			&current_ray,
			norm,
			data.start_ray_plane_intersect,
		)

		found_object.data.transform.position =
			data.start_transform.position + (intersection - data.start_ray_plane_intersect)

		switch &trans_mode in active_tool.translate_mode {
		case spat.Plane:
		case spat.Vector:
			found_object.data.transform.position =
				data.start_transform.position +
				linalg.projection((intersection - data.start_ray_plane_intersect), trans_mode)

		}

	case Rotation_Tool:
		did_intersect, intersection := spat.ray_plane_intersect(
			&current_ray,
			active_tool.axis,
			data.start_ray_plane_intersect,
		)

		new_qua := linalg.quaternion_from_forward_and_up_f32(
			data.start_ray_plane_intersect - data.start_transform.position,
			active_tool.axis,
		)
		new_quat := linalg.quaternion_from_forward_and_up_f32(
			intersection - data.start_transform.position,
			active_tool.axis,
		)
		//found_object.data.transform.rotation = spat.QuaternionData{new_quat.x,new_quat.y, new_quat.z, new_quat.w}

		//found_object.data.transform.rotation = linalg.QUATERNIONF32_IDENTITY * new_quat

		found_object.data.transform.rotation =
			new_quat * linalg.quaternion_inverse(new_qua) * data.start_transform.rotation

	// //panic("rotation not implemented")
	case Scale_Tool:
		norm := linalg.cross(
				linalg.cross(active_tool.scale_normal, (cam.position - data.start_ray_plane_intersect)),
				active_tool.scale_normal,
			)
		hit, location := spat.ray_plane_intersect(
			&current_ray,
			norm,
			data.start_ray_plane_intersect,
		)

		if !hit do return // todo panic?

		delta := location - data.start_ray_plane_intersect

		dirs := calculate_dirs(found_object.transform.position, cam.position)

		dot := linalg.dot(active_tool.scale_normal, delta)

		scale_scale: f32 = 0.2


		#partial switch active_tool.axis {
		case .X:
			found_object.transform.scale.x = (data.start_transform.scale.x + dot * scale_scale)
		case .Y:
			found_object.transform.scale.y = (data.start_transform.scale.y + dot * scale_scale)
		case .Z:
			found_object.transform.scale.z = (data.start_transform.scale.z + dot * scale_scale)
		}

		fmt.printfln("updates scale!: {}", found_object.transform.scale)

	}
	// TODO: Resume here
}
