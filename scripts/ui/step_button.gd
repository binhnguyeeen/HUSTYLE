class_name StepButton
extends Button
## Stepper button that draws its own minus or plus shape.

var plus := false


func _init(is_plus := false) -> void:
	plus = is_plus
	theme_type_variation = &"FlatButton"
	custom_minimum_size = Vector2(32, 32)
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _draw() -> void:
	var c := size / 2.0
	var col := C.MUTED if disabled else C.TEXT
	draw_line(c - Vector2(6, 0), c + Vector2(6, 0), col, 2.0)
	if plus:
		draw_line(c - Vector2(0, 6), c + Vector2(0, 6), col, 2.0)
