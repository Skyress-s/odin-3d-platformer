package layout2

import "core:fmt"

import hm "core:container/handle_map"
import clay "../clay-odin/"

COLOR_LEAF_OUTLINE := clay.Color{72, 100, 150, 255}
COLOR_LEAF_OUTLINE_CONTROLLING := clay.Color{164, 165, 252, 255}
COLOR_BACKGROUND := clay.Color{3, 4, 43, 255}
COLOR_ITEM_BODY := clay.Color{14, 21, 33, 255}

OUTLINE_WIDTH :: 3
LEAF_CORNER_RADIUS :: 12

BODY_PADDING :: 13

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
	assert(hm.get(&ctx.lic, ctx.root) != nil)

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

// todo same style as the normal items

layout_floating_item :: proc(ctx: ^Context) {
	dragging_item, dragging_item_ok := get_item(&ctx.lic, ctx.dragging_handle)
	if !dragging_item_ok do return

	target_floating_dimensions := ctx.screen_dimensions
	target_floating_dimensions.height *= 0.2
	target_floating_dimensions.width *= 0.2

	if clay.UI(clay.ID(fmt.tprintf("{}", dragging_item.id)))(
		config = clay.ElementDeclaration {
			cornerRadius = clay.CornerRadiusAll(LEAF_CORNER_RADIUS),
			layout = clay.LayoutConfig {
				layoutDirection = .TopToBottom,
				sizing = {
					clay.SizingFixed(target_floating_dimensions.width),
					clay.SizingFixed(target_floating_dimensions.height),
				},
				padding = clay.PaddingAll(OUTLINE_WIDTH),
			},
			floating = clay.FloatingElementConfig {
				pointerCaptureMode = .Passthrough,
				attachTo = clay.FloatingAttachToElement.Parent,
				offset = ctx.mouse_pos -
				{target_floating_dimensions.width / 2, target_floating_dimensions.height / 2},
			},
			backgroundColor = COLOR_LEAF_OUTLINE,
		},
	) {

		if clay.UI(clay.ID(fmt.tprintf("{}_body", dragging_item.id)))(
		{
			cornerRadius = clay.CornerRadiusAll(LEAF_CORNER_RADIUS - OUTLINE_WIDTH),
			layout = {
				layoutDirection = .TopToBottom,
				sizing = {clay.SizingPercent(0.99), clay.SizingPercent(0.99)},
				padding = clay.PaddingAll(BODY_PADDING),
			},
			backgroundColor = COLOR_ITEM_BODY,
		},
		) {
			if dragging_item.layout_proc != nil {
				parent := get_item_checked(&ctx.lic, dragging_item.handle)
				dragging_item.layout_proc(parent, &ctx.active_elements)

			} else {
				layout_debug_leaf_data(ctx, dragging_item)
			}

		}

	}
}

// TODO: Can we use non ptr?
layout_tiling_layout_item :: proc(ctx: ^Context, item_handle: Layout_Item_Handle) {
	assert(hm.get(&ctx.lic, item_handle) != nil)
	item := hm.get(&ctx.lic, item_handle)


	should_draw_debug_background :=
		ctx.debug_settings.draw_if_no_content &&
		is_leaf(&ctx.lic, item_handle) &&
		item.layout_proc == nil

	outline_color := is_leaf(&ctx.lic, item_handle) ? COLOR_LEAF_OUTLINE : COLOR_BACKGROUND
	// if ctx.controlling_layout_item == item_handle do outline_color = COLOR_LEAF_OUTLINE_CONTROLLING

	if clay.UI(clay.ID(fmt.tprintf("{}", item.id)))(
	{
		cornerRadius = clay.CornerRadiusAll(LEAF_CORNER_RADIUS),
		// clip = clay.ClipElementConfig{true, true, clay.GetScrollOffset()},
		layout = {
			layoutDirection = item.layout_dir,
			sizing = {
				clay.SizingPercent(item.size_percent.x),
				clay.SizingPercent(item.size_percent.y),
			},
			padding = is_leaf(&ctx.lic, item_handle) ? clay.PaddingAll(OUTLINE_WIDTH) : clay.PaddingAll(0),
			childGap = 4,
		},
		backgroundColor = outline_color,
	},
	) {

		if is_leaf(&ctx.lic, item_handle) {
			if clay.UI(clay.ID(fmt.tprintf("{}_body", item.id)))(
			{
				cornerRadius = clay.CornerRadiusAll(LEAF_CORNER_RADIUS - OUTLINE_WIDTH),
				layout = {
					padding = clay.PaddingAll(BODY_PADDING),
					layoutDirection = .TopToBottom,
					sizing = {clay.SizingGrow(), clay.SizingGrow()},
				},
				backgroundColor = COLOR_ITEM_BODY,
			},
			) {
				if item.layout_proc != nil {
					parent := get_item_checked(&ctx.lic, item.handle)
					item.layout_proc(parent, &ctx.active_elements)

				} else {
					layout_debug_leaf_data(ctx, item)
				}

			}

		} else {
			for child_item_handle in item.child_nodes {
				layout_tiling_layout_item(ctx, child_item_handle)
			}

		}
	}
}

layout_debug_leaf_data :: proc(ctx: ^Context, item: ^Layout_Item) {
	if ctx.debug_settings.draw_ids {
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
		parent_item, parent_item_ok := get_item(&ctx.lic, item.parent_handle)
		if parent_item_ok {
			clay.TextDynamic(
				fmt.tprintf("parent_layout_dir {}", parent_item.layout_dir),
				clay.TextConfig(DEBUG_ID_TEXT_ELEMENT_CONFIG),
			)

		}
	}

}
