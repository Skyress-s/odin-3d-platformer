package microui_raylib

import "core:c"
import "core:fmt"
import "core:strings"
import "core:unicode/utf8"
import rl "vendor:raylib"
import mu "vendor:microui"

import mph_ui "src/mph_ui"


main :: proc() {


    rl.SetConfigFlags({ .VSYNC_HINT, .WINDOW_RESIZABLE, .MSAA_4X_HINT })
    rl.InitWindow(mph_ui.state.screen_width, mph_ui.state.screen_height, "microui-raylib-odin")
    defer rl.CloseWindow()
    rl.SetTargetFPS(144)

    ctx := &mph_ui.state.mu_ctx
    mu.init(ctx,
    set_clipboard = proc(user_data: rawptr, text: string) -> (ok: bool) {
        cstr := strings.clone_to_cstring(text)
        rl.SetClipboardText(cstr)
        delete(cstr)
        return true
    },
    get_clipboard = proc(user_data: rawptr) -> (text: string, ok: bool) {
        cstr := rl.GetClipboardText()
        if cstr != nil {
            text = string(cstr)
            ok = true
        }
        return
    },
    )

    ctx.text_width = mu.default_atlas_text_width
    ctx.text_height = mu.default_atlas_text_height

    mph_ui.state.atlas_texture = rl.LoadRenderTexture(c.int(mu.DEFAULT_ATLAS_WIDTH), c.int(mu.DEFAULT_ATLAS_HEIGHT))
    defer rl.UnloadRenderTexture(mph_ui.state.atlas_texture)

    image := rl.GenImageColor(c.int(mu.DEFAULT_ATLAS_WIDTH), c.int(mu.DEFAULT_ATLAS_HEIGHT), rl.Color{ 0, 0, 0, 0 })
    defer rl.UnloadImage(image)

    for alpha, i in mu.default_atlas_alpha {
        x := i % mu.DEFAULT_ATLAS_WIDTH
        y := i / mu.DEFAULT_ATLAS_WIDTH
        color := rl.Color{ 255, 255, 255, alpha }
        rl.ImageDrawPixel(&image, c.int(x), c.int(y), color)
    }

    rl.BeginTextureMode(mph_ui.state.atlas_texture)
    rl.UpdateTexture(mph_ui.state.atlas_texture.texture, rl.LoadImageColors(image))
    rl.EndTextureMode()

    mph_ui.state.screen_texture = rl.LoadRenderTexture(mph_ui.state.screen_width, mph_ui.state.screen_height)
    defer rl.UnloadRenderTexture(mph_ui.state.screen_texture)


    cam : rl.Camera3D = {
        position = { 5, 1, 5 },
        target = { 0, 0, 3 },
        up = { 0, 3, 0 },
        fovy = 90,
        projection = .PERSPECTIVE,
    }

    for !rl.WindowShouldClose() {
        free_all(context.temp_allocator)
        rl.UpdateCamera(&cam, rl.CameraMode.FIRST_PERSON)

        mouse_pos := rl.GetMousePosition()
        mouse_x, mouse_y := i32(mouse_pos.x), i32(mouse_pos.y)
        mu.input_mouse_move(ctx, mouse_x, mouse_y)

        mouse_wheel_pos := rl.GetMouseWheelMoveV()
        mu.input_scroll(ctx, i32(mouse_wheel_pos.x) * 30, i32(mouse_wheel_pos.y) * -30)

        for button_rl, button_mu in mph_ui.mouse_buttons_map {
            switch {
            case rl.IsMouseButtonPressed(button_rl):
                mu.input_mouse_down(ctx, mouse_x, mouse_y, button_mu)
            case rl.IsMouseButtonReleased(button_rl):
                mu.input_mouse_up  (ctx, mouse_x, mouse_y, button_mu)
            }
        }

        for keys_rl, key_mu in mph_ui.key_map {
            for key_rl in keys_rl {
                switch {
                case key_rl == .KEY_NULL:
                // ignore
                case rl.IsKeyPressed(key_rl), rl.IsKeyPressedRepeat(key_rl):
                    mu.input_key_down(ctx, key_mu)
                case rl.IsKeyReleased(key_rl):
                    mu.input_key_up  (ctx, key_mu)
                }
            }
        }

        {
            buf: [512]byte
            n: int
            for n < len(buf) {
                c := rl.GetCharPressed()
                if c == 0 {
                    break
                }
                b, w := utf8.encode_rune(c)
                n += copy(buf[n:], b[:w])
            }
            mu.input_text(ctx, string(buf[:n]))
        }

        // mph_ui.state.screen_height = rl.GetScreenHeight()
        // mph_ui.state.screen_width = rl.GetScreenWidth()

        mu.begin(ctx)
        all_windows(ctx)
        mu.end(ctx)

        render(ctx, &cam)
    }
}

render :: proc "contextless" (ctx: ^mu.Context, cam: ^rl.Camera3D) {
    render_texture :: proc "contextless" (renderer: rl.RenderTexture2D, dst: ^rl.Rectangle, src: mu.Rect, color: rl.Color) {
        dst.width = f32(src.w)
        dst.height = f32(src.h)

        rl.DrawTextureRec(
        texture  = mph_ui.state.atlas_texture.texture,
        source   = { f32(src.x), f32(src.y), f32(src.w), f32(src.h) },
        position = { dst.x, dst.y },
        tint     = color,
        )
    }

    to_rl_color :: proc "contextless" (in_color: mu.Color) -> (out_color: rl.Color) {
        return { in_color.r, in_color.g, in_color.b, in_color.a }
    }

    height := rl.GetScreenHeight()

    rl.BeginTextureMode(mph_ui.state.screen_texture)
    rl.EndScissorMode()
    rl.ClearBackground(to_rl_color(mph_ui.state.bg))

    command_backing: ^mu.Command
    for variant in mu.next_command_iterator(ctx, &command_backing) {
        switch cmd in variant {
        case ^mu.Command_Text:
            dst := rl.Rectangle{ f32(cmd.pos.x), f32(cmd.pos.y), 0, 0 }
            for ch in cmd.str {
                if ch & 0xc0 != 0x80 {
                    r := min(int(ch), 127)
                    src := mu.default_atlas[mu.DEFAULT_ATLAS_FONT + r]
                    render_texture(mph_ui.state.screen_texture, &dst, src, to_rl_color(cmd.color))
                    dst.x += dst.width
                }
            }
        case ^mu.Command_Rect:
            rl.DrawRectangle(cmd.rect.x, cmd.rect.y, cmd.rect.w, cmd.rect.h, to_rl_color(cmd.color))
        case ^mu.Command_Icon:
            src := mu.default_atlas[cmd.id]
            x := cmd.rect.x + (cmd.rect.w - src.w) / 2
            y := cmd.rect.y + (cmd.rect.h - src.h) / 2
            render_texture(mph_ui.state.screen_texture, &rl.Rectangle { f32(x), f32(y), 0, 0 }, src, to_rl_color(cmd.color))
        case ^mu.Command_Clip:
            rl.BeginScissorMode(cmd.rect.x, height - (cmd.rect.y + cmd.rect.h), cmd.rect.w, cmd.rect.h)
        case ^mu.Command_Jump:
            unreachable()
        }
    }
    rl.EndTextureMode()
    rl.BeginDrawing()
    rl.ClearBackground(rl.RAYWHITE)

    rl.BeginMode3D(cam^)
    rl.DrawCube(rl.Vector3{ 0, 0, 0 }, 0.1, 0.1, 0.1, rl.RED)

    rl.EndMode3D()

    rl.DrawTextureRec(
    texture  = mph_ui.state.screen_texture.texture,
    source   = { 0, 0, f32(mph_ui.state.screen_width), -f32(mph_ui.state.screen_height) },
    // source   = { 0, 0, f32(rl.GetScreenWidth()), -f32(rl.GetScreenHeight()) },
    position = { 0, 0 },
    tint     = rl.WHITE,
    )

    rl.EndDrawing()
}

u8_slider :: proc(ctx: ^mu.Context, val: ^u8, lo, hi: u8) -> (res: mu.Result_Set) {
    mu.push_id(ctx, uintptr(val))

    @static tmp: mu.Real
    tmp = mu.Real(val^)
    res = mu.slider(ctx, &tmp, mu.Real(lo), mu.Real(hi), 0, "%.0f", { .ALIGN_CENTER })
    val^ = u8(tmp)
    mu.pop_id(ctx)
    return
}

write_log :: proc(str: string) {
    mph_ui.state.log_buf_len += copy(mph_ui.state.log_buf[mph_ui.state.log_buf_len:], str)
    mph_ui.state.log_buf_len += copy(mph_ui.state.log_buf[mph_ui.state.log_buf_len:], "\n")
    mph_ui.state.log_buf_updated = true
}

read_log :: proc() -> string {
    return string(mph_ui.state.log_buf[:mph_ui.state.log_buf_len])
}
reset_log :: proc() {
    mph_ui.state.log_buf_updated = true
    mph_ui.state.log_buf_len = 0
}


all_windows :: proc(ctx: ^mu.Context) {
    @static opts := mu.Options{ .NO_CLOSE }

    if mu.window(ctx, "Demo Window", { 40, 40, 300, 450 }, opts) {
        if .ACTIVE in mu.header(ctx, "Window Info") {
            win := mu.get_current_container(ctx)
            mu.layout_row(ctx, { 54, -1 }, 0)
            mu.label(ctx, "Position:")
            mu.label(ctx, fmt.tprintf("%d, %d", win.rect.x, win.rect.y))
            mu.label(ctx, "Size:")
            mu.label(ctx, fmt.tprintf("%d, %d", win.rect.w, win.rect.h))
        }

        if .ACTIVE in mu.header(ctx, "Window Options") {
            mu.layout_row(ctx, { 120, 120, 120 }, 0)
            for opt in mu.Opt {
                state := opt in opts
                if .CHANGE in mu.checkbox(ctx, fmt.tprintf("%v", opt), &state)  {
                    if state {
                        opts += { opt }
                    } else {
                        opts -= { opt }
                    }
                }
            }
        }

        if .ACTIVE in mu.header(ctx, "Test Buttons", { .EXPANDED }) {
            mu.layout_row(ctx, { 86, -110, -1 })
            mu.label(ctx, "Test buttons 1:")
            if .SUBMIT in mu.button(ctx, "Button 1") {
                write_log("Pressed button 1")
            }
            if .SUBMIT in mu.button(ctx, "Button 2") {
                write_log("Pressed button 2")
            }
            mu.label(ctx, "Test buttons 2:")
            if .SUBMIT in mu.button(ctx, "Button 3") {
                write_log("Pressed button 3")
            }
            if .SUBMIT in mu.button(ctx, "Button 4") {
                write_log("Pressed button 4")
            }
        }

        if .ACTIVE in mu.header(ctx, "Tree and Text", { .EXPANDED }) {
            mu.layout_row(ctx, { 140, -1 })
            mu.layout_begin_column(ctx)
            if .ACTIVE in mu.treenode(ctx, "Test 1") {
                if .ACTIVE in mu.treenode(ctx, "Test 1a") {
                    mu.label(ctx, "Hello")
                    mu.label(ctx, "world")
                }
                if .ACTIVE in mu.treenode(ctx, "Test 1b") {
                    if .SUBMIT in mu.button(ctx, "Button 1") {
                        write_log("Pressed button 1")
                    }
                    if .SUBMIT in mu.button(ctx, "Button 2") {
                        write_log("Pressed button 2")
                    }
                }
            }
            if .ACTIVE in mu.treenode(ctx, "Test 2") {
                mu.layout_row(ctx, { 53, 53 })
                if .SUBMIT in mu.button(ctx, "Button 3") {
                    write_log("Pressed button 3")
                }
                if .SUBMIT in mu.button(ctx, "Button 4") {
                    write_log("Pressed button 4")
                }
                if .SUBMIT in mu.button(ctx, "Button 5") {
                    write_log("Pressed button 5")
                }
                if .SUBMIT in mu.button(ctx, "Button 6") {
                    write_log("Pressed button 6")
                }
            }
            if .ACTIVE in mu.treenode(ctx, "Test 3") {
                @static checks := [3]bool{ true, false, true }
                mu.checkbox(ctx, "Checkbox 1", &checks[0])
                mu.checkbox(ctx, "Checkbox 2", &checks[1])
                mu.checkbox(ctx, "Checkbox 3", &checks[2])

            }
            mu.layout_end_column(ctx)

            mu.layout_begin_column(ctx)
            mu.layout_row(ctx, { -1 })
            mu.text(ctx,
            "Lorem ipsum dolor sit amet, consectetur adipiscing " +
            "elit. Maecenas lacinia, sem eu lacinia molestie, mi risus faucibus " +
            "ipsum, eu varius magna felis a nulla.",
            )
            mu.layout_end_column(ctx)
        }

        if .ACTIVE in mu.header(ctx, "Background Colour", { .EXPANDED }) {
            mu.layout_row(ctx, { -78, -1 }, 68)
            mu.layout_begin_column(ctx)
            {
                mu.layout_row(ctx, { 46, -1 }, 0)
                mu.label(ctx, "Red:");   u8_slider(ctx, &mph_ui.state.bg.r, 0, 255)
                mu.label(ctx, "Green:"); u8_slider(ctx, &mph_ui.state.bg.g, 0, 255)
                mu.label(ctx, "Blue:");  u8_slider(ctx, &mph_ui.state.bg.b, 0, 255)
            }
            mu.layout_end_column(ctx)

            r := mu.layout_next(ctx)
            mu.draw_rect(ctx, r, mph_ui.state.bg)
            mu.draw_box(ctx, mu.expand_rect(r, 1), ctx.style.colors[.BORDER])
            mu.draw_control_text(ctx, fmt.tprintf("#%02x%02x%02x", mph_ui.state.bg.r, mph_ui.state.bg.g, mph_ui.state.bg.b), r, .TEXT, { .ALIGN_CENTER })
        }
    }



    if mu.window(ctx, "Log Window", { 350, 40, 300, 200 }, opts) {
        mu.layout_row(ctx, { -1 }, -28)
        mu.begin_panel(ctx, "Log")
        mu.layout_row(ctx, { -1 }, -1)
        mu.text(ctx, read_log())
        if mph_ui.state.log_buf_updated {
            panel := mu.get_current_container(ctx)
            panel.scroll.y = panel.content_size.y
            mph_ui.state.log_buf_updated = false
        }
        mu.end_panel(ctx)

        @static buf: [128]byte
        @static buf_len: int
        submitted := false
        mu.layout_row(ctx, { -70, -1 })
        if .SUBMIT in mu.textbox(ctx, buf[:], &buf_len) {
            mu.set_focus(ctx, ctx.last_id)
            submitted = true
        }
        if .SUBMIT in mu.button(ctx, "Submit") {
            submitted = true
        }
        if submitted {
            write_log(string(buf[:buf_len]))
            buf_len = 0
        }
    }

    if mu.window(ctx, "Style Window", { 350, 250, 300, 240 }) {
        @static colors := [mu.Color_Type]string{
            .TEXT         = "text",
            .BORDER       = "border",
            .WINDOW_BG    = "window bg",
            .TITLE_BG     = "title bg",
            .TITLE_TEXT   = "title text",
            .PANEL_BG     = "panel bg",
            .BUTTON       = "button",
            .BUTTON_HOVER = "button hover",
            .BUTTON_FOCUS = "button focus",
            .BASE         = "base",
            .BASE_HOVER   = "base hover",
            .BASE_FOCUS   = "base focus",
            .SCROLL_BASE  = "scroll base",
            .SCROLL_THUMB = "scroll thumb",
            .SELECTION_BG = "selection bg",
        }

        sw := i32(f32(mu.get_current_container(ctx).body.w) * 0.14)
        mu.layout_row(ctx, { 80, sw, sw, sw, sw, -1 })
        for label, col in colors {
            mu.label(ctx, label)
            u8_slider(ctx, &ctx.style.colors[col].r, 0, 255)
            u8_slider(ctx, &ctx.style.colors[col].g, 0, 255)
            u8_slider(ctx, &ctx.style.colors[col].b, 0, 255)
            u8_slider(ctx, &ctx.style.colors[col].a, 0, 255)
            mu.draw_rect(ctx, mu.layout_next(ctx), ctx.style.colors[col])
        }
    }
}
