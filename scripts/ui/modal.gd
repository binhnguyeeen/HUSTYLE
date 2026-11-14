class_name Modal
extends RefCounted
## Dim layer with a centered card: title, body and one primary button.

const WIDTH := 440


static func make(title: String, body: String, button_text: String, on_press: Callable) -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(C.BG_BASE, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var card := UI.panel(C.BG_PANEL, C.RADIUS_CARD, 32, C.LINE)
	card.custom_minimum_size = Vector2(WIDTH, 0)
	center.add_child(card)
	var v := UI.box(true, 24)
	card.add_child(v)
	var texts := UI.box(true, 8)
	var t := UI.label(title, 28, UI.W.SEMI)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texts.add_child(t)
	var b := UI.label(body, 14, UI.W.REGULAR, C.TEXT2)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texts.add_child(b)
	v.add_child(texts)
	var btn := UI.button(button_text, true, 44)
	btn.pressed.connect(on_press)
	v.add_child(btn)
	return root


## Same card, with a list of short lines instead of one body text.
static func make_list(title: String, lines: Array, button_text: String, on_press: Callable) -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(C.BG_BASE, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var card := UI.panel(C.BG_PANEL, C.RADIUS_CARD, 32, C.LINE)
	card.custom_minimum_size = Vector2(560, 0)
	center.add_child(card)
	var v := UI.box(true, 24)
	card.add_child(v)
	var t := UI.label(title, 28, UI.W.SEMI)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var list := UI.box(true, 14)
	for text in lines:
		var row := UI.box(false, 12)
		var dot := Panel.new()
		dot.add_theme_stylebox_override("panel", UI.style(C.ACCENT, 3))
		dot.custom_minimum_size = Vector2(6, 6)
		dot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(UI.margin(dot, 0, 8, 0, 0))
		var l := UI.label(text, 16, UI.W.REGULAR, C.TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		list.add_child(row)
	v.add_child(list)
	var btn := UI.button(button_text, true, 44)
	btn.pressed.connect(on_press)
	v.add_child(btn)
	return root
