package layout

import "core:fmt"

import hms "../../handle_map/handle_map_static/"
import clay "../clay-odin/"

DEBUG_ID_TEXT_ELEMENT_CONFIG :: clay.TextElementConfig {
	// fontSize      = 48,
	// letterSpacing = 4,
	// lineHeight    = 48,
	wrapMode  = .Words,
	// textAlignment = .Left,
	fontId    = DEBUG_FONT_ID,
	fontSize  = 24,
	textColor = {255, 255, 255, 255},
}

layout :: proc(ctx: ^Context) {
	assert(hms.valid(ctx.lic, ctx.root))

	if clay.UI(clay.ID("main"))(
	{
		layout = clay.LayoutConfig {
			sizing = {clay.SizingGrow(), clay.SizingGrow()},
			layoutDirection = .TopToBottom,
		},
	},
	) {
		layout_tiling_layout_item(ctx, ctx.root)
		layout_floating_item(ctx)
	}


}

layout_floating_item :: proc(ctx: ^Context) {
	dragging_item, dragging_item_ok := get_item(&ctx.lic, ctx.dragging_handle)
	if !dragging_item_ok do return

	bounds := get_clay_bounding_box(dragging_item.id)

	if clay.UI(clay.ID(dragging_item.id))(
		config = clay.ElementDeclaration {
			layout = clay.LayoutConfig {
				layoutDirection = .TopToBottom,
				sizing = {clay.SizingPercent(0.25), clay.SizingPercent(0.25)},
			},
			floating = clay.FloatingElementConfig {
				attachTo = clay.FloatingAttachToElement.Parent,
				offset = ctx.mouse_pos - {bounds.width / 2, bounds.height / 2},
			},
			backgroundColor = clay.Color{0, 255, 255, 255},
		},
	) {

	}
}

// TODO: Can we use non ptr?
layout_tiling_layout_item :: proc(ctx: ^Context, item_handle: Layout_Item_Handle) {
	assert(hms.valid(ctx.lic, item_handle))
	item := hms.get(&ctx.lic, item_handle)

	should_draw_debug_background :=
		ctx.debug_settings.draw_if_no_content &&
		is_leaf(&ctx.lic, item_handle) &&
		item.layout_proc == nil

	if clay.UI(clay.ID(item.id))(
	{
		layout = {
			layoutDirection = item.layout_dir,
			sizing          = {
				clay.SizingPercent(item.size_percent.x),
				clay.SizingPercent(item.size_percent.y),
			},
			padding         = is_leaf(&ctx.lic, item_handle) ? clay.PaddingAll(8) : clay.PaddingAll(0),
			childGap        = 4,
			// padding         = is_leaf(&ctx.lic, item_handle) ? clay.PaddingAll(16) : clay.PaddingAll(16),
			// childGap        = 8,
		},
		backgroundColor = clay.Color {
			f32(max_leaf_distance(&ctx.lic, item_handle)) * 50,
			0,
			0,
			255,
		},
		// backgroundColor = should_draw_debug_background ? clay.Color{0, 0,0, 255} : clay.Color{},
	},
	) {
		if ctx.debug_settings.draw_ids && is_leaf(&ctx.lic, item_handle) {
			clay.TextDynamic(
				fmt.tprintf("id_{}", item.id),
				clay.TextConfig(DEBUG_ID_TEXT_ELEMENT_CONFIG),
			)
			clay.TextDynamic(
				fmt.tprintf("layout_dir {}", item.layout_dir),
				clay.TextConfig(DEBUG_ID_TEXT_ELEMENT_CONFIG),
			)
			clay.TextDynamic(
				fmt.tprintf("size {}", item.size_percent),
				clay.TextConfig(DEBUG_ID_TEXT_ELEMENT_CONFIG),
			)
			parent_item := get_item_checked(&ctx.lic, item.parent_handle)
			clay.TextDynamic(
				fmt.tprintf("parent_layout_dir {}", parent_item.layout_dir),
				clay.TextConfig(DEBUG_ID_TEXT_ELEMENT_CONFIG),
			)
		}

		for child_item_handle in item.child_nodes {
			layout_tiling_layout_item(ctx, child_item_handle)
		}

	}
}
