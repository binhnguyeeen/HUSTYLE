class_name PriceChart
extends Control
## Polyline of the last prices with a soft fill, grid and day labels.

const AXIS_W := 56.0
const LABEL_H := 28.0

var points: Array = []  # { "day": int, "price": float }


func set_points(p: Array) -> void:
	points = p
	queue_redraw()


func _draw() -> void:
	if points.size() < 2:
		return
	var font: Font = UI.FONTS[UI.W.REGULAR]
	var plot := Rect2(Vector2(8, 8), Vector2(size.x - AXIS_W - 8, size.y - LABEL_H - 8))
	var lo := INF
	var hi := -INF
	for p in points:
		lo = minf(lo, p["price"])
		hi = maxf(hi, p["price"])
	var step := _nice_step((hi - lo) / 3.0)
	lo = floor(lo / step) * step
	hi = ceil(hi / step) * step
	if hi - lo < step * 2:
		hi = lo + step * 3

	# Grid and price labels.
	var v := lo
	while v <= hi + step * 0.01:
		var y := _y(v, lo, hi, plot)
		draw_line(Vector2(0, y), Vector2(plot.end.x, y), C.LINE, 1.0)
		draw_string(font, Vector2(plot.end.x + 10, y + 4), _short_money(v, step), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, C.MUTED)
		v += step

	var up: bool = points[-1]["price"] >= points[0]["price"]
	var col := C.UP if up else C.DOWN
	var line := PackedVector2Array()
	var low_i := 0
	for i in points.size():
		var x := plot.position.x + plot.size.x * i / float(points.size() - 1)
		line.append(Vector2(x, _y(points[i]["price"], lo, hi, plot)))
		if points[i]["price"] < points[low_i]["price"]:
			low_i = i
	var fill := line.duplicate()
	fill.append(Vector2(plot.end.x, plot.end.y))
	fill.append(Vector2(plot.position.x, plot.end.y))
	draw_colored_polygon(fill, Color(col, 0.08))
	draw_polyline(line, col, 2.0, true)
	draw_circle(line[-1], 4.0, col)
	if low_i != points.size() - 1 and low_i != 0:
		draw_circle(line[low_i], 5.0, C.DOWN, false, 1.5, true)

	# Day labels: first, middle, low point and last, only for real days.
	var marks := { 0: C.MUTED, points.size() / 2: C.MUTED, points.size() - 1: C.MUTED }
	if low_i != points.size() - 1 and low_i != 0:
		marks[low_i] = C.DOWN
	for i in marks:
		var d: int = points[i]["day"]
		if d < 1:
			continue
		var x := line[i].x
		var txt := "Day %d" % d
		var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		x = clampf(x - w / 2.0, 0, plot.end.x - w)
		draw_string(font, Vector2(x, size.y - 8), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, marks[i])


func _y(v: float, lo: float, hi: float, plot: Rect2) -> float:
	return plot.end.y - (v - lo) / (hi - lo) * plot.size.y


func _nice_step(raw: float) -> float:
	if raw <= 0.0:
		return 1.0
	var mag := pow(10.0, floor(log(raw) / log(10.0)))
	for m in [1.0, 2.0, 2.5, 5.0, 10.0]:
		if raw <= m * mag:
			return m * mag
	return 10.0 * mag


func _short_money(v: float, step: float) -> String:
	if step >= 1.0:
		return Game.CURRENCY + str(int(round(v)))
	return Game.CURRENCY + ("%.2f" % v)
