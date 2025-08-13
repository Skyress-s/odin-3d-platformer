package Bullshit

import "core:fmt"
import "core:c"
import gl "vendor:openGL"
import "vendor:glfw"
import s "Shapes"
import m "core:math"

PROGRAMNAME::"BEHOLD!!! THE COORDINATES ARE HERE????! DAMN RIGHT, THIS SHIT IS A B S O L U T E FIRE 🔥🔥🔥" // removed "motherfuckers" from this line earlier as I was sitting next to an older woman on the bus and wanted to atleast maintain some shallow image of being family friendly
GL_MAJOR_VERSION : c.int : 4
GL_MINOR_VERSION :: 6
SCR_WIDTH :: 800
SCR_HEIGHT :: 800
CFG_DEV :: true
enable_wireframe := false
enable_VSync := true
running : b32 = true

main :: proc() {

    defer glfw.Terminate()
    if(glfw.Init() != true) {
        fmt.println("Failed to initialize GLFW")
        return
    }

    glfw.WindowHint(glfw.RESIZABLE, glfw.TRUE)
    glfw.WindowHint(glfw.OPENGL_FORWARD_COMPAT, glfw.TRUE)
    glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)
    glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, GL_MAJOR_VERSION)
    glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, GL_MINOR_VERSION)

    window := glfw.CreateWindow(SCR_WIDTH, SCR_HEIGHT, PROGRAMNAME, nil, nil)
    defer glfw.DestroyWindow(window)

    if window == nil {
        fmt.println("Unable to create window")
        return
    }

    glfw.MakeContextCurrent(window)
    glfw.SwapInterval(cast(i32)enable_VSync) // 1 syncs rendering loop to monitor refresh rate (Vsync). Set to 0 when measuring performance.
    glfw.SetKeyCallback(window, key_callback)
    glfw.SetFramebufferSizeCallback(window, size_callback)
    gl.load_up_to(int(GL_MAJOR_VERSION), GL_MINOR_VERSION, glfw.gl_set_proc_address)

//  init()

    shader_program : u32
    {
        ok:bool
        shader_program, ok = gl.load_shaders("src/Bullshit/Shaders/default.vert", "src/Bullshit/Shaders/default.frag")
        if !ok {
            panic("could not initialize shaders.")
        }
    }
    defer gl.DeleteProgram(shader_program)

    // VBO & VAO
    VBO, VAO, EBO : u32
    gl.GenBuffers(1, &VBO)
    gl.GenVertexArrays(1, &VAO)
    gl.GenBuffers(1, &EBO)

    // initialization code:
    // 1. bind Vertex Array Object
    gl.BindVertexArray(VAO)
    // 2. copy our vertices array in a vertex buffer for OpenGL to use
    gl.BindBuffer(gl.ARRAY_BUFFER, VBO)
    gl.BufferData(gl.ARRAY_BUFFER, size_of(s.rectangle_vertices), &s.rectangle_vertices, gl.STATIC_DRAW)
    // 3. copy our index array in an element buffer for OpenGL to use
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, EBO)
    gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, size_of(s.rectangle_indices), &s.rectangle_indices, gl.STATIC_DRAW)
    // 4. then set the vertex attributes pointers
    // position attribute
    gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 6 * size_of(f32), cast(uintptr)0)
    gl.EnableVertexAttribArray(0)
    // color attribute
    gl.VertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, 6 * size_of(f32), cast(uintptr)(3 * size_of(f32)))
    gl.EnableVertexAttribArray(1)

    // Unbind (optional, probably unnessecary because it adds a call)
    gl.BindBuffer(gl.ARRAY_BUFFER, 0) // safely unbind after VertexAttribPointer registers buffer object
    gl.BindVertexArray(0) // -||-

//  Dev logic
    when CFG_DEV {
        fmt.println("DEV CONFIG ENABLED\n")

        if enable_wireframe {
            gl.PolygonMode(gl.FRONT_AND_BACK, gl.LINE) // enable wireframe
        }

        nr_attributes : i32
        gl.GetIntegerv(gl.MAX_VERTEX_ATTRIBS, &nr_attributes)
        fmt.printf("There is [{}] 4-component vertex attributes available.", nr_attributes)

        query : u32
        time_elapsed : u64
    }

    gl.GenQueries(1, &query)

    for (!glfw.WindowShouldClose(window) && running) {

        glfw.PollEvents()

        // start gpu timer
        when CFG_DEV {
            gl.BeginQuery(gl.TIME_ELAPSED, query)
        }

        gl.ClearColor(0.135, 0.15, 0.15, 1.0)
        gl.Clear(gl.COLOR_BUFFER_BIT)

        gl.UseProgram(shader_program)

        time_value : f32 = f32(glfw.GetTime())
        green_value : f32 = f32(m.sin(time_value / 2.0) + 0.5)
        vertex_color_location : i32 = gl.GetUniformLocation(shader_program, "our_color")
        gl.UseProgram(shader_program);
        gl.Uniform4f(vertex_color_location, 0.0, green_value, 0.0, 1.0);


        gl.BindVertexArray(VAO)
        gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, EBO)
        gl.DrawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, nil)

        // end gpu timer and print
        when CFG_DEV {
        gl.EndQuery(gl.TIME_ELAPSED)
        gl.GetQueryObjectui64v(query, gl.QUERY_RESULT, &time_elapsed)
        // fmt.printf("GPU Time: {:8.5f} ms\n", f64(time_elapsed) / 1e6) // ":.4f" is some absolute black fucking magic
        }

        glfw.SwapBuffers(window) // blocks until next vertical blanking interval unless glfwSwapInterval is set to 0
    }
}

// I don't know why this works
size_callback :: proc "c" (window: glfw.WindowHandle, width, height: i32) {
    gl.Viewport(0, 0, width, height)
}

// I don't know why this works either
// It's also 100% unnessecary,
// but it works so I will keep it.
key_callback :: proc "c" (window: glfw.WindowHandle, key, scancode, action, mods: i32) {
    if key == glfw.KEY_ESCAPE {
        running = false
    }
}