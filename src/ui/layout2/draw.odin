package layout


import hms "../../handle_map/handle_map_static/"
import clay "../clay-odin/"

draw :: proc(ctx: ^Context) {
	assert(hms.valid(ctx.lic, ctx.root))

	root_layout_item := hms.get(&ctx.lic, ctx.root)
	// TODO: Continue from here.

}
