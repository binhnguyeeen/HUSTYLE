class_name UI
extends RefCounted
## Small helpers that build themed controls from code.

enum W { REGULAR, SEMI, BOLD }

const FONTS := {
	W.REGULAR: preload("res://assets/fonts/Inter-Regular.ttf"),
	W.SEMI: preload("res://assets/fonts/Inter-SemiBold.ttf"),
	W.BOLD: preload("res://assets/fonts/Inter-Bold.ttf"),
}


static func label(text: String, size := 14, weight := W.REGULAR, color := C.TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", FONTS[weight])
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func box(vertical: bool, gap := 0) -> BoxContainer:
	var b: BoxContainer = VBoxContainer.new() if vertical else HBoxContainer.new()
	b.add_theme_constant_override("separation", gap)
	return b


static func style(bg: Color, radius := 0, pad := 0, border := Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(pad)
	if border.a > 0:
		s.border_color = border
		s.set_border_width_all(1)
	return s


static func panel(bg: Color, radius := 0, pad := 0, border := Color(0, 0, 0, 0)) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", style(bg, radius, pad, border))
	return p


static func margin(child: Control, left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", left)
	m.add_theme_constant_override("margin_top", top)
	m.add_theme_constant_override("margin_right", right)
	m.add_theme_constant_override("margin_bottom", bottom)
	m.add_child(child)
	return m


static func spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func line(vertical: bool) -> ColorRect:
	var r := ColorRect.new()
	r.color = C.LINE
	r.custom_minimum_size = Vector2(1, 0) if vertical else Vector2(0, 1)
	return r


static func button(text: String, primary := false, height := 36) -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = &"PrimaryButton" if primary else &""
	b.custom_minimum_size = Vector2(0, height)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b


## Logo scaled to fit a box, keeping its proportions.
## With max_w set, the box grows wider for wide logos, up to max_w.
static func logo(path: String, h: int, w := 0, max_w := 0) -> Control:
	var box := Vector2(w if w > 0 else h, h)
	if path != "" and ResourceLoader.exists(path):
		var t := TextureRect.new()
		t.texture = load(path)
		if max_w > 0:
			var ts: Vector2 = t.texture.get_size()
			box.x = clampf(h * ts.x / ts.y, h, max_w)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.custom_minimum_size = box
		return t
	# Missing logo: gray rounded tile.
	var p := panel(C.BG_RAISED, 6, 0, C.LINE)
	p.custom_minimum_size = box
	return p


## Up or down triangle drawn as a shape, never as a plus or minus sign.
static func arrow(up: bool, px := 8) -> Control:
	var a := Arrow.new()
	a.up = up
	a.custom_minimum_size = Vector2(px, px)
	return a


## Triangle plus text, colored by direction.
static func change(value: float, text: String, size := 12, weight := W.SEMI) -> HBoxContainer:
	var up := value >= 0
	var h := box(false, 4)
	h.alignment = BoxContainer.ALIGNMENT_END
	var a := arrow(up, 8)
	a.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(a)
	h.add_child(label(text, size, weight, C.UP if up else C.DOWN))
	return h


static func pill(pct: float) -> PanelContainer:
	var up := pct >= 0
	var col := C.UP if up else C.DOWN
	var p := PanelContainer.new()
	var s := style(Color(col, 0.14), 4)
	s.content_margin_left = 6
	s.content_margin_right = 6
	s.content_margin_top = 1
	s.content_margin_bottom = 1
	p.add_theme_stylebox_override("panel", s)
	p.add_child(change(pct, percent(pct)))
	p.size_flags_horizontal = Control.SIZE_SHRINK_END
	return p


static func money(v: float) -> String:
	var cents := int(round(absf(v) * 100.0))
	var whole := str(cents / 100)
	var out := ""
	while whole.length() > 3:
		out = "," + whole.substr(whole.length() - 3) + out
		whole = whole.substr(0, whole.length() - 3)
	return Game.CURRENCY + whole + out + "." + ("%02d" % (cents % 100))


static func percent(v: float) -> String:
	return "%.1f%%" % absf(v * 100.0)


static func clock(seconds: float) -> String:
	var s := int(ceil(maxf(seconds, 0.0)))
	return "%d:%02d" % [s / 60, s % 60]


static func clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()
