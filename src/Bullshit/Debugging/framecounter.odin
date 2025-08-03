package Debugging
import "vendor:glfw"
import fmt "core:fmt"

frame_counters :: struct {
    last_time : f64,
    nb_frames : i32
}

framecounter_init :: proc () -> frame_counters {
    return frame_counters{glfw.GetTime(), 0}
}

framecounter_update :: proc(counters: ^frame_counters) {

    current_time : f64 = glfw.GetTime()
    counters.nb_frames += 1

    if (current_time - counters.last_time >= 1.0) {
        fmt.printf("heyo, what's up") // "%f ms/frame\n", 1000.0/f64(nb_frames)
        counters.nb_frames = 0
        counters.last_time += 1.0
    }
}