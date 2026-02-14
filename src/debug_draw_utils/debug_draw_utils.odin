package debug_draw_utils

import spat "../core/spatial"
import "core:log"


import col "../color"
import "core:fmt"

import rl "vendor:raylib"
import rlgl "vendor:raylib/rlgl"

import hms "../handle_map/handle_map_static"

USE_HMS :: true

Map_Type :: map[Id_Handle]Data2

debug_draw_instruction_array: Map_Type

Id_Handle :: hms.Handle

Handle_Map_Type :: distinct hms.Handle_Map(Data, Id_Handle, 1000)
ins_handle_map := Handle_Map_Type{}

ins_map: Map_Type

Id_Type: u32

@(private)
id_counter: u32 = 0

@(private)
get_next_id :: proc() -> u32 {
	id_counter += 1
	return id_counter
}

Data2 :: struct {
	// cololr : col.Color,
	handle:      Id_Handle,
	instruction: Instruction,
	duration:    f32,
}

Data :: struct {
	// cololr : col.Color,
	handle:      Id_Handle,
	instruction: Instruction,
	duration:    f32,
}

Instruction :: distinct union #no_nil {
	Cube_Ins,
	Wire_Cube_Ins,
	Sphere_Ins,
	Wire_Sphere_Ins,
	Cyllinder_Ins,
	Wire_Cyllinder_Ins,
	Capsule_Ins,
	Wire_Capsule_Ins,
	Circle_Ins,
	Triangle_Ins,
	Text_Ins,
	Line_Ins,
}

Cube_Ins :: distinct struct {
	location: spat.Vector,
	size:     spat.Vector,
	rot:      spat.Quaternion,
	color:    col.Color,
}

Wire_Cube_Ins :: distinct struct {
	using draw_instruction: Cube_Ins,
}


Sphere_Ins :: distinct struct {
	location: spat.Vector,
	radius:   f32,
	color:    col.Color,
}

Wire_Sphere_Ins :: distinct struct {
	using draw_instruction: Sphere_Ins,
}

Cyllinder_Ins :: distinct struct {
	using sphere_trace: spat.Sphere_Trace,
	color:              col.Color,
}

Wire_Cyllinder_Ins :: distinct struct {
	using instruction: Cyllinder_Ins,
}

Capsule_Ins :: distinct struct {
	using instruction: Cyllinder_Ins,
}

Wire_Capsule_Ins :: distinct struct {
	using instruction: Cyllinder_Ins,
}

Circle_Ins :: distinct struct {
	location, up, forward: spat.Vector,
	radius:                f32,
	color:                 col.Color,
}

Triangle_Ins :: distinct struct {
	a, b, c: spat.Vector,
	col:     col.Color,
}

Text_Ins :: distinct struct {
	message: string,
}

Line_Ins :: distinct struct {
	ray:   spat.Ray,
	color: col.Color,
}

draw_instruction :: proc(debug_draw_instruction: ^Instruction) {
	rlgl.PushMatrix()
	defer rlgl.PopMatrix()

	switch &v in debug_draw_instruction {
	case Cube_Ins:
		// rlgl.Translatef(v.location.x, v.location.y, v.location.z)
		mat := spat.calculate_matrix_from_loc_rot(&v.location, &v.rot)
		matrix_data := rl.MatrixToFloatV(mat)
		rlgl.MultMatrixf(auto_cast &matrix_data)
		rl.DrawCube(spat.ZERO_VEC3, v.size.x, v.size.y, v.size.z, v.color)
	case Wire_Cube_Ins:
		mat := spat.calculate_matrix_from_loc_rot(&v.location, &v.rot)
		matrix_data := rl.MatrixToFloatV(mat)
		rlgl.MultMatrixf(auto_cast &matrix_data)
		rl.DrawCubeWires(spat.ZERO_VEC3, v.size.x, v.size.y, v.size.z, v.color)
	case Sphere_Ins:
		rlgl.Translatef(v.location.x, v.location.y, v.location.z)
		rl.DrawSphere(spat.ZERO_VEC3, v.radius, v.color)
	case Wire_Sphere_Ins:
		rlgl.Translatef(v.location.x, v.location.y, v.location.z)
		rl.DrawSphereWires(spat.ZERO_VEC3, v.radius, 8, 8, v.color)
	case Cyllinder_Ins:
	case Wire_Cyllinder_Ins:
		draw_cyllinder(&v)
	case Capsule_Ins:
	case Wire_Capsule_Ins:
		draw_capsule_wires(&v)
	case Circle_Ins:

	case Triangle_Ins:
		rl.DrawTriangle3D(v.a, v.b, v.c, v.col)
		rl.DrawTriangle3D(v.b, v.a, v.c, v.col)
	case Text_Ins:
	case Line_Ins:
		rl.DrawLine3D(v.ray.origin, v.ray.end, v.color)
	// Drawn in the game ui package

	}

}

update_lifetime_and_clean :: proc(dt: f32) {

	to_remove: [dynamic]Id_Handle
	defer delete(to_remove)

	for &i in &ins_handle_map.items {
		if hms.skip(i) do continue

		if i.duration >= 0 {
			i.duration -= dt
			if i.duration < 0 {
				append_elem(&to_remove, i.handle)
			}
		}
	}

	for &handle in &to_remove {
		hms.remove(&ins_handle_map, handle)
	}
}

draw_all_instructions_and_reset :: proc() {
	for &e in &ins_handle_map.items {
		if hms.skip(e) || !hms.valid(ins_handle_map, e.handle) do continue
		draw_instruction(&e.instruction)
	}
}

clear_all_instructions :: proc() {
	when USE_HMS {
		hms.clear(&ins_handle_map)
	} else {
		clear_map(&ins_map)

	}
}


enqueue_ins :: proc(draw_ins: $T, dur: f32 = 0.0) {

	when USE_HMS {
		data := Data {
			instruction = draw_ins^,
			duration    = dur,
			handle      = Id_Handle{},
		}
		id, ok := hms.add(&ins_handle_map, data)
		assert(ok, "ddu handle map full. Please increase the size")
	} else {

	}
}
