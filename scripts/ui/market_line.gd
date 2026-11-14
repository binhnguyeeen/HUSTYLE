class_name MarketLine
extends Control
## Faint decorative price line for the Title screen.

const POINTS := [0.7, 0.55, 0.62, 0.4, 0.5, 0.3, 0.45, 0.8, 0.6, 0.35, 0.42, 0.2, 0.28, 0.1]


func _draw() -> void:
	var pts := PackedVector2Array()
	for i in POINTS.size():
		pts.append(Vector2(size.x * i / float(POINTS.size() - 1), size.y * POINTS[i]))
	var fill := pts.duplicate()
	fill.append(Vector2(size.x, size.y))
	fill.append(Vector2(0, size.y))
	draw_colored_polygon(fill, Color(C.UP, 0.04))
	draw_polyline(pts, Color(C.UP, 0.25), 2.0, true)
