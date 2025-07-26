package Bullshit

import "core:fmt"
import "core:c"

import gl "vendor:openGL"
import "vendor:glfw"

PROGRAMNAME::"Program"

GL_MAJOR_VERSION : c.int : 4
GL_MINOR_VERSION :: 6

running : b32 = true

WhatIsAnOdin :: proc() {

    if(glfw.Init() != 1) {
    // Print Line
        fmt.println("Failed to initialize GLFW")
        // Return early
        return
    }

    glfw.WindowHint(glfw.RESIZABLE, glfw.TRUE)
    glfw.WindowHint(glfw.OPENGL_FORWARD_COMPAT, glfw.TRUE)
    glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)
    glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, GL_MAJOR_VERSION)
    glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, GL_MINOR_VERSION)

    defer glfw.Terminate()

    window := glfw.CreateWindow(512, 512, PROGRAMNAME, nil, nil)
    defer glfw.DestroyWindow(window)

    if window == nil {
        fmt.println("Unable to create window")
        return
    }

    glfw.MakeContextCurrent(window)
    glfw.SwapInterval(1)
    glfw.SetKeyCallback(window, key_callback)
    glfw.SetFramebufferSizeCallback(window, size_callback)
    gl.load_up_to(int(GL_MAJOR_VERSION), GL_MINOR_VERSION, glfw.gl_set_proc_address)

    init()

    for (!glfw.WindowShouldClose(window) && running) {
    // Process waiting events in queue
    // https://www.glfw.org/docs/3.3/group__window.html#ga37bd57223967b4211d60ca1a0bf3c832
        glfw.PollEvents()

        update()
        draw()

        // This function swaps the front and back buffers of the specified window.
        // See https://en.wikipedia.org/wiki/Multiple_buffering to learn more about Multiple buffering
        // https://www.glfw.org/docs/3.0/group__context.html#ga15a5a1ee5b3c2ca6b15ca209a12efd14
        glfw.SwapBuffers((window))
    }

    exit()

}