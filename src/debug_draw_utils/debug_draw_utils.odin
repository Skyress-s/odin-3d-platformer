package debug_draw_utils

import spat "../Spatial"


import col "../color"
import "core:fmt"

import rl "vendor:raylib"
import rlgl "vendor:raylib/rlgl"

debug_draw_instruction_array: Debug_Draw_Instruction_Map

Debug_Draw_Instruction_Map :: [dynamic]Debug_Draw_Instruction

Debug_Draw_Instruction :: distinct union #no_nil {
	Debug_Draw_Cube_Instruction,
	Debug_Draw_Wire_Cube_Instruction,
	Debug_Draw_Sphere_Instruction,
	Debug_Draw_Wire_Sphere_Instruction,
	Debug_Draw_Text_Instruction,
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

Debug_Draw_Text_Instruction :: distinct struct {
	message : string,
} 

draw_instruction :: proc(debug_draw_instruction: ^Debug_Draw_Instruction) {
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
		rlgl.MultMatrixf(auto_cast &mat)
		rl.DrawCubeWires(spat.ZERO_VEC3, v.size.x, v.size.y, v.size.z, v.color)
	case Debug_Draw_Sphere_Instruction:
		rlgl.Translatef(v.location.x, v.location.y, v.location.z)
		rl.DrawSphere(spat.ZERO_VEC3, v.radius, v.color)
	case Debug_Draw_Wire_Sphere_Instruction:
		rlgl.Translatef(v.location.x, v.location.y, v.location.z)
		rl.DrawSphereWires(spat.ZERO_VEC3, v.radius, 8, 8, v.color)
 	case Debug_Draw_Text_Instruction:
		// Drawn in the game ui package

	}
}

draw_all_instructions_and_reset :: proc() {
	for &instruction in &debug_draw_instruction_array {
		draw_instruction(&instruction)
	}
	clear(&debug_draw_instruction_array)
}

enqueue_draw_instruction :: proc(draw_ins: ^Debug_Draw_Instruction) {
	append_elem(&debug_draw_instruction_array, draw_ins^)
}
