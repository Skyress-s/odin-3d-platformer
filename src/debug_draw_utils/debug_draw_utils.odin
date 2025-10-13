package debug_draw_utils

import spat "../Spatial"


import col "../color"
import "core:fmt"

import rl "vendor:raylib"
import rlgl "vendor:raylib/rlgl"

import hms "../handle_map/handle_map_static"

Debug_Draw_Instruction_Map :: [dynamic]Data

debug_draw_instruction_array: Debug_Draw_Instruction_Map

Data :: struct {
	// cololr : col.Color,
	instruction: Instruction,
	duration:    f32,
}

Instruction :: distinct union #no_nil {
	Debug_Draw_Cube_Instruction,
	Debug_Draw_Wire_Cube_Instruction,
	Debug_Draw_Sphere_Instruction,
	Debug_Draw_Wire_Sphere_Instruction,
	Debug_Draw_Cyllinder_Instruction,
	Debug_Draw_Wire_Cyllinder_Instruction,
	Debug_Draw_Circle_Instruction,
	Debug_Draw_Triangle_Instruction,
	Debug_Draw_Text_Instruction,
	Debug_Draw_Line_Instruction,
}

Debug_Draw_Cube_Instruction :: distinct struct {
	location: spat.Vector,
	size:     spat.Vector,
	rot:      spat.Quaternion,
	color:    col.Color,
}

Debug_Draw_Wire_Cube_Instruction :: distinct struct {
	using draw_instruction: Debug_Draw_Cube_Instruction,
}


Debug_Draw_Sphere_Instruction :: distinct struct {
	location: spat.Vector,
	radius:   f32,
	color:    col.Color,
}

Debug_Draw_Wire_Sphere_Instruction :: distinct struct {
	using draw_instruction: Debug_Draw_Sphere_Instruction,
}

Debug_Draw_Cyllinder_Instruction :: distinct struct {
	using sphere_trace: spat.Sphere_Trace,
	color:              col.Color,
}

Debug_Draw_Wire_Cyllinder_Instruction :: distinct struct {
	using instruction: Debug_Draw_Cyllinder_Instruction,
}

Debug_Draw_Circle_Instruction :: distinct struct {
	location, up, forward: spat.Vector,
	radius:                f32,
	color:                 col.Color,
}

Debug_Draw_Triangle_Instruction :: distinct struct {
	a, b, c: spat.Vector,
	col:     col.Color,
}

Debug_Draw_Text_Instruction :: distinct struct {
	message: string,
}

Debug_Draw_Line_Instruction :: distinct struct {
	ray:   spat.Ray,
	color: col.Color,
}

draw_instruction :: proc(debug_draw_instruction: ^Instruction) {
	rlgl.PushMatrix()
	defer rlgl.PopMatrix()

	switch &v in debug_draw_instruction {
	case Debug_Draw_Cube_Instruction:
		// rlgl.Translatef(v.location.x, v.location.y, v.location.z)
		mat := spat.calculate_matrix_from_loc_rot(&v.location, &v.rot)
		matrix_data := rl.MatrixToFloatV(mat)
		rlgl.MultMatrixf(auto_cast &matrix_data)
		rl.DrawCube(spat.ZERO_VEC3, v.size.x, v.size.y, v.size.z, v.color)
	case Debug_Draw_Wire_Cube_Instruction:
		mat := spat.calculate_matrix_from_loc_rot(&v.location, &v.rot)
		matrix_data := rl.MatrixToFloatV(mat)
		rlgl.MultMatrixf(auto_cast &matrix_data)
		rl.DrawCubeWires(spat.ZERO_VEC3, v.size.x, v.size.y, v.size.z, v.color)
	case Debug_Draw_Sphere_Instruction:
		rlgl.Translatef(v.location.x, v.location.y, v.location.z)
		rl.DrawSphere(spat.ZERO_VEC3, v.radius, v.color)
	case Debug_Draw_Wire_Sphere_Instruction:
		rlgl.Translatef(v.location.x, v.location.y, v.location.z)
		rl.DrawSphereWires(spat.ZERO_VEC3, v.radius, 8, 8, v.color)
	case Debug_Draw_Cyllinder_Instruction:

	case Debug_Draw_Wire_Cyllinder_Instruction:
		draw_cyllinder(&v)
	case Debug_Draw_Circle_Instruction:

	case Debug_Draw_Triangle_Instruction:
		rl.DrawTriangle3D(v.a, v.b, v.c, v.col)
		rl.DrawTriangle3D(v.b, v.a, v.c, v.col)
	case Debug_Draw_Text_Instruction:
	case Debug_Draw_Line_Instruction:
		rl.DrawLine3D(v.ray.origin, v.ray.end, v.color)
	// Drawn in the game ui package

	}

}

draw_all :: proc() {
	for &instruction in &debug_draw_instruction_array do draw_instruction(&instruction.instruction)
}

update_lifetime_and_clean :: proc(dt: f32) {

	for &data in &debug_draw_instruction_array {
		data.duration -= dt
		if data.duration <= 0.0 {

		}
	}
}

draw_all_instructions_and_reset :: proc() {
	for &instruction in &debug_draw_instruction_array {
		draw_instruction(&instruction.instruction)
	}
	clear_all_instructions()
}

clear_all_instructions :: proc() {
	clear(&debug_draw_instruction_array)
}

enqueue_draw_instruction :: proc(draw_ins: ^Instruction) {
	dat := Data{draw_ins^, 0.0}
	append_elem(&debug_draw_instruction_array, dat)
}

enqueue_ins :: proc(draw_ins: $T, duration: f32 = 0.0) {
	ins: Instruction = draw_ins^
	append_elem(&debug_draw_instruction_array, Data{ins, duration})
}
