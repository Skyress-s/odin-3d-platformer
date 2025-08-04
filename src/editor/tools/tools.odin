package tools

import spat "../../Spatial"

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


update_transform_tool :: proc(data: ^Transform_Tool_Data){

}
