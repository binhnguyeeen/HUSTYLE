class_name Arrow
extends Control

var up := true


func _draw() -> void:
	var w := size.x
	var h := size.y * 0.8
	var top := (size.y - h) / 2.0
	var pts: PackedVector2Array
	if up:
		pts = [Vector2(0, top + h), Vector2(w, top + h), Vector2(w / 2.0, top)]
	else:
		pts = [Vector2(0, top), Vector2(w, top), Vector2(w / 2.0, top + h)]
	draw_colored_polygon(pts, C.UP if up else C.DOWN)
