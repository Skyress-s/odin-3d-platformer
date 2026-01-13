package layout

import hms "../../handle_map/handle_map_static/"

Layout_Item :: struct {
	handle: hms.Handle,
}

Layout_Item_Handle :: struct {}

Layout_Item_Container :: hms.Handle_Map(Layout_Item, hms.Handle, 1 >> 8)
