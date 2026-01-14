package layout

Active_Elements :: distinct struct{
	elems: map[string]Active_Element_Item
}

Active_Element_Item :: distinct struct{
	active, old : bool
}

active_elements_get :: proc(ae: ^Active_Elements, id: string) -> (Active_Element_Item, bool) {
	item, ok := ae.elems[id]
	return item, ok
}

active_elements_get_or_add :: proc(ae: ^Active_Elements, id: string) -> ^Active_Element_Item {
	item, ok := &ae.elems[id]
	if !ok {
		ae.elems[id] = Active_Element_Item{} // default to not old and not active
		item = &ae.elems[id]
		
	}

	return item
}

active_elements_mark_all_old :: proc(ae: ^Active_Elements){
	for key, &item in ae.elems{
		item.old = true
	}
}

active_elements_remove_old :: proc(ae: ^Active_Elements){
	elems_to_remove : [dynamic] string
	defer delete(elems_to_remove)

	for key, &item in ae.elems{
		if item.old do append(&elems_to_remove, key)
	}

	for &key in elems_to_remove{
		delete_key(&ae.elems, key)
	}
}

