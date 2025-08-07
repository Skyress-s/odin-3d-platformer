package Bullshit

import "core:fmt"
import "core:c"
import gl "vendor:openGL"
import "vendor:glfw"
import s "Shapes"
import d "Debugging"

PROGRAMNAME::"I CREATED A WINDOW!!! WHAT ARE YOU GOING TO DO ABOUT IT????!" // removed "motherfuckers" from this line earlier as I was sitting next to an older woman on the bus and wanted to atleast maintain some shallow image of being family friendly
GL_MAJOR_VERSION : c.int : 4
GL_MINOR_VERSION :: 6
SCR_WIDTH :: 800
SCR_HEIGHT :: 600
running : b32 = true

//  hacky shader setup
vertex_source : cstring = `#version 330 core
    layout (location = 0) in vec3 aPos;
    void main()
    {
       gl_Position = vec4(aPos.x, aPos.y, aPos.z, 1.0);
    }`

fragment_source:cstring = `#version 330 core
    out vec4 FragColor;
    void main()
    {
       FragColor = vec4(1.0f, 0.5f, 0.2f, 1.0f);
    }`;

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
    glfw.SwapInterval(0) // 1 syncs rendering loop to monitor refresh rate (Vsync). Set to 0 when measuring performance.
    glfw.SetKeyCallback(window, key_callback)
    glfw.SetFramebufferSizeCallback(window, size_callback)
    gl.load_up_to(int(GL_MAJOR_VERSION), GL_MINOR_VERSION, glfw.gl_set_proc_address)

//  init()

    // got absolutely no clue what this means, should prob look at it later
    // program_id : u32; ok : bool
    // if program_id, ok = gl.load_shaders("./triangle.vert", "./triangle.frag"); !ok {
    //     fmt.println("Failed to load shaders.")
    //     return
    // }
    // defer gl.DeleteProgram(program_id)

    // build and compile shader program
    // --------------------------------
    // variables for compilation error checking

    // vert shader
    vertexShader := gl.CreateShader(gl.VERTEX_SHADER)
    gl.ShaderSource(vertexShader, 1, &vertex_source, nil)
    gl.CompileShader(vertexShader)

    success : i32
    infoLog : [^]byte // will this work?
    // vert compilation err check
    gl.GetShaderiv(vertexShader, gl.COMPILE_STATUS, &success);
    if success == 0 {
        gl.GetShaderInfoLog(vertexShader, 512, nil, infoLog)
        fmt.println("ERROR::SHADER::VERTEX::COMPILATION_FAILED\n")
        fmt.print(infoLog)
    }

    // frag shader
    fragmentShader := gl.CreateShader(gl.FRAGMENT_SHADER)
    gl.ShaderSource(fragmentShader, 1, &fragment_source, nil)
    gl.CompileShader(fragmentShader)

    // frag compilation err check
    gl.GetShaderiv(vertexShader, gl.COMPILE_STATUS, &success);
    if success == 0 {
        gl.GetShaderInfoLog(vertexShader, 512, nil, infoLog)
        fmt.println("ERROR::SHADER::FAGMENT::COMPILATION_FAILED\n")
        fmt.print(infoLog)
    }

    // link shaders
    shaderProgram : u32 = gl.CreateProgram()
    gl.AttachShader(shaderProgram, vertexShader)
    gl.AttachShader(shaderProgram, fragmentShader)
    gl.LinkProgram(shaderProgram)

    // check for linking errors
    gl.GetProgramiv(shaderProgram,gl.LINK_STATUS, &success)
    if success == 0 {
        gl.GetProgramInfoLog(shaderProgram, 512, nil, infoLog)
        fmt.println("ERROR::SHADER_PROGRAM::LINKING_FAILED")
        fmt.println(infoLog)
    }

    gl.DeleteShader(vertexShader)
    gl.DeleteShader(fragmentShader)

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
    gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 3* size_of(f32), cast(uintptr)0)
    gl.EnableVertexAttribArray(0)

    // Unbind (optional, probably unnessecary because it adds a call)
    gl.BindBuffer(gl.ARRAY_BUFFER, 0) // safely unbind after VertexAttribPointer registers buffer object
    gl.BindVertexArray(0) // -||-

//  Dev logic

    // gl.PolygonMode(gl.FRONT_AND_BACK, gl.LINE) // enable wireframe
    framecounter := d.framecounter_init()
    query : u32
    time_elapsed : u64

    gl.GenQueries(1, &query)

    for (!glfw.WindowShouldClose(window) && running) {
    //  d.framecounter_update(&framecounter) // probably pretty inaccurate

        glfw.PollEvents()


        gl.BeginQuery(gl.TIME_ELAPSED, query)

        gl.ClearColor(0.2, 0.3, 0.3, 1.0)
        gl.Clear(gl.COLOR_BUFFER_BIT)

        gl.UseProgram(shaderProgram)
        gl.BindVertexArray(VAO)
        gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, EBO)
        gl.DrawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, nil)

        gl.EndQuery(gl.TIME_ELAPSED)

        glfw.SwapBuffers(window) // blocks until next vertical blanking interval unless glfwSwapInterval is set to 0

        // print gpu time
        gl.GetQueryObjectui64v(query, gl.QUERY_RESULT, &time_elapsed)
        fmt.printf("GPU Time: {}ms\n", f64(time_elapsed) / 1e6)
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
