package Shapes

rectangle_vertices := [?]f32 {
0.5,  0.5, 0.0,  // top right
0.5, -0.5, 0.0,  // bottom right
-0.5, -0.5, 0.0,  // bottom left
-0.5,  0.5, 0.0   // top left
}

rectangle_indices := [?]u32 {  // note that we start from 0!
0, 1, 3,   // first triangle
1, 2, 3    // second triangle
}