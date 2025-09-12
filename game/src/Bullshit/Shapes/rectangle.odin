package Shapes

// Todo: Scale dynamically and adjust indices based on whether the shape has vertex color or not.

rectangle_vertices := [?]f32 {
    1.0,  1.0, 0.0,    1.0, 1.0, 0.0, // top right
    1.0, -1.0, 0.0,    1.0, 0.0, 0.0, // bottom right
    -1.0, -1.0, 0.0,    0.0, 0.0, 0.0, // bottom left
    -1.0,  1.0, 0.0,    0.0, 1.0, 0.0, // top left
}

rectangle_indices := [?]u32 {  // note that we start from 0!
0, 1, 3,   // first triangle
1, 2, 3,    // second triangle
}