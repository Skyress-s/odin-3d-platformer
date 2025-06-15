package mph_ui
import rl "vendor:raylib"
import mu "vendor:microui"
import c "core:c"

state := struct{
    mu_ctx: mu.Context,
    log_buf: [1 << 16]byte,
    log_buf_len: int,
    log_buf_updated: bool,
    bg: mu.Color,
    atlas_texture: rl.RenderTexture2D,

    screen_width: c.int,
    screen_height: c.int,

    screen_texture: rl.RenderTexture2D,
}{
    screen_width = 1900,
    screen_height = 1040,
    bg = { 90, 95, 100, 0 }, // 255
}

mouse_buttons_map := [mu.Mouse]rl.MouseButton{
    .LEFT    = .LEFT,
    .RIGHT   = .RIGHT,
    .MIDDLE  = .MIDDLE,
}

key_map := [mu.Key][2]rl.KeyboardKey{
    .SHIFT     = { .LEFT_SHIFT, .RIGHT_SHIFT },
    .CTRL      = { .LEFT_CONTROL, .RIGHT_CONTROL },
    .ALT       = { .LEFT_ALT, .RIGHT_ALT },
    .BACKSPACE = { .BACKSPACE, .KEY_NULL },
    .DELETE    = { .DELETE, .KEY_NULL },
    .RETURN    = { .ENTER, .KP_ENTER },
    .LEFT      = { .LEFT, .KEY_NULL },
    .RIGHT     = { .RIGHT, .KEY_NULL },
    .HOME      = { .HOME, .KEY_NULL },
    .END       = { .END, .KEY_NULL },
    .A         = { .A, .KEY_NULL },
    .X         = { .X, .KEY_NULL },
    .C         = { .C, .KEY_NULL },
    .V         = { .V, .KEY_NULL },
}

init :: proc (){

}