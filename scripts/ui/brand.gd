class_name Brand
extends RefCounted
## Logo and name, pinned top left.


static func make() -> Control:
	var h := UI.box(false, 10)
	h.position = Vector2(20, 6)
	h.custom_minimum_size = Vector2(0, 44)
	var logo := UI.logo("res://assets/logos/hustyle.png", 40)
	logo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(logo)
	var word := UI.label("HUSTYLE", 20, UI.W.BOLD, C.ACCENT)
	word.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(word)
	return h
