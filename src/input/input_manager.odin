package input

// Systems needs to ask to performe actions like
//
// Or should the systems just do what they want and we reset it all when when change?
// This will be better if i need to use this in the future or move away from raylib.
// - Lock cursor
// - Cursor visibility state
// - Restrict cursor
// - check if system is allowed to have inputs.
// How to group systems? Register? ID? Layout_Item_Handle?


request_change_cursor_lock_state :: proc()
request_change_cursor_visible_state :: proc()
request_restrict_cursor :: proc()
