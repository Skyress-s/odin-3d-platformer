package Spatial

import hms "../handle_map/handle_map_static"
import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:testing"

Sphere_Trace :: distinct struct {
	ray:    Ray,
	radius: f32,
}

calculate_hashes_by_sphere :: proc(
	radius: f32,
	location: ^Vector,
) -> (
	hash_keys: map[Hash_Key]bool,
) {
	assert(radius >= 0)
	rad := radius
	rad_bigger := rad * 1.3 // 30% percent bigger for now
	radius_vector := Vector{rad, rad, rad}
	bound := Bound {
		min = location^ - radius_vector,
		max = location^ + radius_vector,
	}

	return calculate_overlapping_cells(bound)

}

// TODO create testing
@(test)
test_calculate_hashes_by_sphere :: proc(t: ^testing.T) {
	zero_vec := ZERO_VEC3

	hash_keys: map[Hash_Key]bool = calculate_hashes_by_sphere(5, &zero_vec)
	defer delete(hash_keys)

	some_arr: [dynamic]i32 = make([dynamic]i32)
	defer delete(some_arr)
	append_elem(&some_arr, 757)

	// some_arr2 :[dynamic]i32
	// defer delete(some_arr2)

	testing.expect(t, 1 == 1)
}

calculate_hashes_by_sphere_trace :: proc(
	sphere_trace: ^Sphere_Trace,
) -> (
	cells: map[Hash_Key]bool,
) {
	rays := calculate_rays_by_sphere_trace(sphere_trace)
	defer delete(rays)

	hashes := calculate_hashes_by_rays(&rays)
	return hashes

	// // To start out with, we use a sphere that is 30 % bigger that the original
	// trace_length := ray_length(&sphere_trace.ray)
	// trace_direction := ray_direction(sphere_trace.ray)
	// rad := sphere_trace.radius
	// rad_bigger := rad * 1.3 // 30% percent bigger for now
	//
	//
	// walk_distance := math.sqrt(rad_bigger * rad_bigger - rad * rad) // Application of Pythagoras
	//
	// current_dist: f32 = 0.0
	//
	// for current_dist < trace_length {
	// 	current_location := sphere_trace.ray.origin + trace_direction * current_dist
	// 	new_cells := calculate_hashes_by_sphere(rad, &current_location)
	// 	defer delete(new_cells)
	//
	// 	for cell in &new_cells {
	// 		cells[cell] = true
	// 	}
	//
	// 	current_dist += walk_distance
	// }
	//
	// return cells
}

distance_point_to_line :: proc(p_on_line, v, point: ^Vector) -> f32 {
	to_point := (point^ - p_on_line^)
	c := linalg.cross(to_point, v^)
	return linalg.length(c) / linalg.length(v^)
}

sphere_trace_spatial_hash_grid :: proc(
	sphere_trace: ^Sphere_Trace,
	shg: ^Spatial_Hash_Grid,
	com: ^Collision_Object_Handle_Map,
) -> (
	hit: bool,
	id: Collision_Object_Id,
	location: Vector,
) {
	rays := calculate_rays_by_sphere_trace(sphere_trace)
	defer delete(rays)

	hashes := calculate_hashes_by_rays(&rays)
	defer delete(hashes)

	for hash_key in &hashes {
		object_ids, ok := shg[hash_key]
		if ok {
			for object_id in &object_ids.objects_ids {
				object := hms.get(com, object_id)
				for &tri in &object.tris {


				}
			}
		}
	}

	return
}

calculate_rays_by_sphere_trace :: proc(
	sphere_trace: ^Sphere_Trace,
) -> (
	rays: [dynamic]Ray, // cells: map[Hash_Key]bool,
) {

	ray := &sphere_trace.ray
	ray_length := ray_length(ray)
	forward := ray_direction(ray^)

	up := linalg.normalize0(linalg.cross(forward, UP_VEC3))

	if up == ZERO_VEC3 {
		up = FORWARD_VEC3
	}


	right := linalg.normalize(linalg.cross(forward, up))

	start_location_center :=
		ray.origin -
		forward * sphere_trace.radius -
		sphere_trace.radius * up -
		sphere_trace.radius * right
	end_location_center :=
		ray.end +
		forward * sphere_trace.radius -
		sphere_trace.radius * up -
		sphere_trace.radius * right

	num_rays_per_side := i32(math.ceil(sphere_trace.radius * 2 / HASH_CELL_SIZE_METERS)) + 1

	for i: i32 = 0; i < num_rays_per_side * num_rays_per_side; i += 1 {
		x := f32((i % num_rays_per_side)) * (sphere_trace.radius * 2 / f32(num_rays_per_side - 1))
		y := f32(i / num_rays_per_side) * (sphere_trace.radius * 2 / f32(num_rays_per_side - 1))


		offset := right * f32(x) + up * f32(y)

		newt_gun_ray := Ray {
			origin = start_location_center + offset,
			end    = end_location_center + offset,
		}

		append_elem(&rays, newt_gun_ray)

		// cells_hit_by_ray := calculate_hashes_by(newt_gun_ray)
		// for key, _ in &cells_hit_by_ray{
		// 	cells[key] = true
		// }
	}

	return rays
}

sphere_trace_triangle_intersect :: proc(sphere_trace: ^Sphere_Trace, tri: ^Collision_Triangle, reaction: ^Vector) {
	//
	// i: i32
	// nvelo := ray_direction(sphere_trace.ray)
	// nvelo = linalg.normalize(nvelo)
	//
	// tri_normal := collision_triangle_normal(tri)
	//
	// if linalg.dot(tri_normal, nvelo) > -0.001 do return false
	//
	// minDist := max(f32)
	// reaction: Vector
	// col :i32= -1
	// _distTravel :f32= max(f32)
	//
	//
	// plane : Plane = Plane{point_on_plane = tri.points.x, normal = tri_normal}
	//
	// // pass1: sphere VS plane
	// h :f32= plane.dist( _sphere.center );
	// h :f32= distance_point_to_plane(&plane, &sphere_trace.ray.origin)
	// if h < -_sphere.radius do return false
	//
	// if h > _sphere.radius {
	// 	h -= _sphere.radius;
	// 	dot := linalg.dot(tri_normal, nvelo)
	// 	if (dot != 0) {
	// 		t :f32= -h / dot;
	// 		onPlane :Vector= _sphere.center + nvelo * t;
	// 		if (collision_triangle_point_inside(tri, onPlane)) {
	// 			if (t < _distTravel) {
	// 				_distTravel = t;
	// 				if reaction != nil{
	// 					reaction = tri_normal;
	// 				}
	// 				col = 0;
	// 			}
	// 		}
	// 	}
	// }
	//
	// // pass2: sphere VS triangle vertices
	// for i:i32= 0; i < 3; i += 1{
	//
	// 	seg_pt0 :Vector= tri.points[i];
	// 		 seg_pt1 :Vector= seg_pt0 - nvelo;
	// 			  v :Vector= seg_pt1 - seg_pt0;
	//
	// 			     inter1, inter2:=max(f32), max(f32)
	// 	nbInter:i32 = 0
	// 	ozbool res = testIntersectionSphereLine(_sphere, seg_pt0, seg_pt1, &nbInter, &inter1, &inter2);
	// 	if (res == OZFALSE)
	// 		continue;
	//
	// 	float t = inter1;
	// 	if (inter2 < t)
	// 		t = inter2;
	//
	// 	if (t < 0)
	// 		continue;
	//
	// 	if (t < _distTravel) {
	// 		_distTravel = t;
	// 		Vec3f onSphere = seg_pt0 + v * t;
	// 		if (_reaction)
	// 			*_reaction = _sphere.center - onSphere;
	// 		col = 1;
	// 	}
	// }
	//
	// // pass3: sphere VS triangle edges
	// for (i = 0; i < 3; i++) {
	// 	Vec3f edge0 = *_triPts[i];
	// 	int j = i + 1;
	// 	if (j == 3)
	// 		j = 0;
	// 	Vec3f edge1 = *_triPts[j];
	//
	// 	Plane plane;
	// 	plane.fromPoints(edge0, edge1, edge1 - nvelo);
	// 	float d = plane.dist(_sphere.center);
	// 	if (d > _sphere.radius || d < -_sphere.radius)
	// 		continue;
	//
	// 	float srr = _sphere.radius * _sphere.radius;
	// 	float r = sqrtf(srr - d*d);
	//
	// 	Vec3f pt0 = plane.project(_sphere.center); // center of the sphere slice (a circle)
	//
	// 	Vec3f onLine;
	// 	float h = distancePointToLine(pt0, edge0, edge1, &onLine);
	// 	Vec3f v = onLine - pt0;
	// 	v.normalize();
	// 	Vec3f pt1 = v * r + pt0; // point on the sphere that will maybe collide with the edge
	//
	// 	int a0 = 0, a1 = 1;
	// 	float pl_x = fabsf(plane.a);
	// 	float pl_y = fabsf(plane.b);
	// 	float pl_z = fabsf(plane.c);
	// 	if (pl_x > pl_y && pl_x > pl_z) {
	// 		a0 = 1;
	// 		a1 = 2;
	// 	}
	// 	else {
	// 		if (pl_y > pl_z) {
	// 			a0 = 0;
	// 			a1 = 2;
	// 		}
	// 	}
	//
	// 	Vec3f vv = pt1 + nvelo;
	//
	// 	float t;
	// 	ozbool res = testIntersectionLineLine(  Vec2f(pt1[a0], pt1[a1]),
	// 											Vec2f(vv[a0], vv[a1]),
	// 											Vec2f(edge0[a0], edge0[a1]),
	// 											Vec2f(edge1[a0], edge1[a1]),
	// 											&t);
	// 	if (!res || t < 0)
	// 		continue;
	//
	// 	Vec3f inter = pt1 + nvelo * t;
	//
	// 	Vec3f r1 = edge0 - inter;
	// 	Vec3f r2 = edge1 - inter;
	// 	if (r1.dot(r2) > 0)
	// 		continue;
	//
	// 	if (t > _distTravel)
	// 		continue;
	//
	// 	_distTravel = t;
	// 	if (_reaction)
	// 		*_reaction = _sphere.center - pt1;
	// 	col = 2;
	// }
	//
	// if (_reaction && col != -1)
	// 	_reaction->normalize();
	//
	// return col == -1 ? OZFALSE : OZTRUE;
	//
	//
}


calculate_hashes_by_rays :: proc(rays: ^[dynamic]Ray) -> (hashes: map[Hash_Key]bool) {
	for &ray in rays {
		new_hashes := calculate_hashes_by(ray)
		defer delete(new_hashes)

		for hash in &new_hashes {
			hashes[hash] = true
		}
	}

	return hashes
}
