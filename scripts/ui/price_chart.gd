class_name PriceChart
extends Control
## Price line with a soft fill, price grid, day dividers and labels.

const AXIS_W := 56.0
const LABEL_H := 28.0

var points := PackedVector2Array()  # x from 0 to 1, y is the price
var labels: Array = []  # [x from 0 to 1, text]
var dividers: Array = []


func set_view(v: Dictionary) -> void:
	points = v["points"]
	labels = v["labels"]
	dividers = v["dividers"]
	queue_redraw()


func _draw() -> void:
	if points.is_empty():
		return
	var font: Font = UI.FONTS[UI.W.REGULAR]
	var plot := Rect2(Vector2(8, 8), Vector2(size.x - AXIS_W - 8, size.y - LABEL_H - 8))
	var lo := INF
	var hi := -INF
	var low_i := 0
	for i in points.size():
		var v := points[i].y
		if v < lo:
			lo = v
			low_i = i
		hi = maxf(hi, v)
	var step := _nice_step((hi - lo) / 3.0)
	lo = floor(lo / step) * step
	hi = ceil(hi / step) * step
	if hi - lo < step * 2:
		hi = lo + step * 2

	# Grid and price labels.
	var g := lo
	while g <= hi + step * 0.01:
		var y := _y(g, lo, hi, plot)
		draw_line(Vector2(0, y), Vector2(plot.end.x, y), C.LINE, 1.0)
		draw_string(font, Vector2(plot.end.x + 10, y + 4), _short_money(g, step), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, C.MUTED)
		g += step
	for d in dividers:
		var dx: float = plot.position.x + plot.size.x * d
		draw_line(Vector2(dx, plot.position.y), Vector2(dx, plot.end.y), Color(C.LINE, 0.7), 1.0)

	var up: bool = points[-1].y >= points[0].y
	var col := C.UP if up else C.DOWN
	var line := PackedVector2Array()
	for p in points:
		line.append(Vector2(plot.position.x + plot.size.x * p.x, _y(p.y, lo, hi, plot)))
	# Fill one slice per segment so long lines never fail to triangulate.
	var fill := Color(col, 0.08)
	for i in range(1, line.size()):
		var a := line[i - 1]
		var b := line[i]
		if b.x - a.x < 0.01:
			continue
		draw_colored_polygon([a, b, Vector2(b.x, plot.end.y), Vector2(a.x, plot.end.y)], fill)
	if line.size() >= 2:
		draw_polyline(line, col, 2.0, true)
	draw_circle(line[-1], 4.0, col)
	if low_i != points.size() - 1 and low_i != 0:
		draw_circle(line[low_i], 5.0, C.DOWN, false, 1.5, true)

	for l in labels:
		var txt: String = l[1]
		var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		var x: float = plot.position.x + plot.size.x * float(l[0])
		if float(l[0]) >= 1.0:
			x -= w
		elif float(l[0]) > 0.0:
			x += 4.0
		draw_string(font, Vector2(x, size.y - 8), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, C.MUTED)


func _y(v: float, lo: float, hi: float, plot: Rect2) -> float:
	return plot.end.y - (v - lo) / (hi - lo) * plot.size.y


func _nice_step(raw: float) -> float:
	if raw <= 0.005:
		return 0.01
	var mag := pow(10.0, floor(log(raw) / log(10.0)))
	for m in [1.0, 2.0, 5.0, 10.0]:
		if raw <= m * mag:
			return m * mag
	return 10.0 * mag


func _short_money(v: float, step: float) -> String:
	if step >= 1.0:
		return Game.CURRENCY + str(int(round(v)))
	return Game.CURRENCY + ("%.2f" % v)
