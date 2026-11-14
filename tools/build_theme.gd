# Builds res://ui/theme.tres from colors.gd.
# Run: godot --headless --path . --script res://tools/build_theme.gd
extends SceneTree

const Col = preload("res://scripts/colors.gd")


func _init() -> void:
	var t := Theme.new()
	var regular: FontFile = load("res://assets/fonts/Inter-Regular.ttf")
	var semi: FontFile = load("res://assets/fonts/Inter-SemiBold.ttf")
	t.default_font = regular
	t.default_font_size = 14

	t.set_color("font_color", "Label", Col.TEXT)

	# Secondary button is the default look.
	t.set_font("font", "Button", semi)
	t.set_font_size("font_size", "Button", 14)
	t.set_color("font_color", "Button", Col.TEXT)
	t.set_color("font_hover_color", "Button", Col.TEXT)
	t.set_color("font_pressed_color", "Button", Col.TEXT)
	t.set_color("font_focus_color", "Button", Col.TEXT)
	t.set_color("font_disabled_color", "Button", Col.MUTED)
	t.set_stylebox("normal", "Button", _box(Col.BG_BASE, Col.LINE))
	t.set_stylebox("hover", "Button", _box(Col.BG_RAISED, Col.TEXT2))
	t.set_stylebox("pressed", "Button", _box(Col.BG_RAISED, Col.TEXT2))
	t.set_stylebox("disabled", "Button", _box(Col.BG_BASE, Col.LINE))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())

	t.set_type_variation("PrimaryButton", "Button")
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(k, "PrimaryButton", Col.BG_BASE)
	t.set_color("font_disabled_color", "PrimaryButton", Col.BG_BASE)
	t.set_stylebox("normal", "PrimaryButton", _box(Col.ACCENT))
	t.set_stylebox("hover", "PrimaryButton", _box(Col.ACCENT.lightened(0.15)))
	t.set_stylebox("pressed", "PrimaryButton", _box(Col.ACCENT.darkened(0.1)))
	t.set_stylebox("disabled", "PrimaryButton", _box(Color(Col.ACCENT, 0.35)))

	t.set_type_variation("TabButton", "Button")
	t.set_color("font_color", "TabButton", Col.TEXT2)
	t.set_color("font_hover_color", "TabButton", Col.TEXT)
	t.set_color("font_pressed_color", "TabButton", Col.TEXT)
	t.set_color("font_hover_pressed_color", "TabButton", Col.TEXT)
	t.set_stylebox("normal", "TabButton", _box(Color(0, 0, 0, 0)))
	t.set_stylebox("hover", "TabButton", _box(Color(0, 0, 0, 0)))
	t.set_stylebox("pressed", "TabButton", _box(Col.BG_RAISED))
	t.set_stylebox("hover_pressed", "TabButton", _box(Col.BG_RAISED))

	t.set_type_variation("FlatButton", "Button")
	for s in ["normal", "hover", "pressed", "disabled"]:
		t.set_stylebox(s, "FlatButton", StyleBoxEmpty.new())

	var edit := _box(Col.BG_BASE, Col.LINE)
	edit.content_margin_left = 12
	edit.content_margin_right = 12
	t.set_stylebox("normal", "LineEdit", edit)
	t.set_stylebox("focus", "LineEdit", _box(Color(0, 0, 0, 0), Col.ACCENT))
	t.set_font_size("font_size", "LineEdit", 16)
	t.set_color("font_color", "LineEdit", Col.TEXT)
	t.set_color("caret_color", "LineEdit", Col.ACCENT)
	t.set_color("font_placeholder_color", "LineEdit", Col.MUTED)

	var bar_bg := _box(Col.LINE, Color(0, 0, 0, 0), 2)
	var bar_fill := _box(Col.ACCENT, Color(0, 0, 0, 0), 2)
	bar_bg.content_margin_top = 0
	bar_bg.content_margin_bottom = 0
	bar_fill.content_margin_top = 0
	bar_fill.content_margin_bottom = 0
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", bar_fill)

	var grab := _box(Col.LINE, Color(0, 0, 0, 0), 3)
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", grab)
	t.set_stylebox("grabber_pressed", "VScrollBar", grab)
	var track := StyleBoxEmpty.new()
	track.content_margin_left = 3
	track.content_margin_right = 3
	t.set_stylebox("scroll", "VScrollBar", track)

	var err := ResourceSaver.save(t, "res://ui/theme.tres")
	print("theme saved: ", err)
	quit()


func _box(bg: Color, border := Color(0, 0, 0, 0), radius := Col.RADIUS_CONTROL) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.set_corner_radius_all(radius)
	if border.a > 0:
		b.border_color = border
		b.set_border_width_all(1)
	b.content_margin_left = 16
	b.content_margin_right = 16
	b.content_margin_top = 8
	b.content_margin_bottom = 8
	b.anti_aliasing = true
	return b
