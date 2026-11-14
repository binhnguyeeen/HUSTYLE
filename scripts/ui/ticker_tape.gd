class_name TickerTape
extends Control
## Strip of every ticker, price and change, scrolling left.

const HEIGHT := 28
const SPEED := 40.0
const GAP := 36.0

var offset := 0.0


func _init() -> void:
	custom_minimum_size = Vector2(0, HEIGHT)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	offset += SPEED * delta
	queue_redraw()


func _draw() -> void:
	if Market.stocks.is_empty():
		return
	var semi: Font = UI.FONTS[UI.W.SEMI]
	var regular: Font = UI.FONTS[UI.W.REGULAR]
	var base := size.y / 2.0 + 4.0
	var loop_w := 0.0
	for s in Market.stocks:
		loop_w += _item(s, semi, regular, 0.0, base, false)
	var x := -fmod(offset, loop_w)
	while x < size.x:
		for s in Market.stocks:
			x += _item(s, semi, regular, x, base, true)


## Draws one stock at x and returns how wide it is.
func _item(s: Dictionary, semi: Font, regular: Font, x: float, base: float, paint: bool) -> float:
	var id: String = s["id"]
	var ch: float = Market.change.get(id, 0.0)
	var col := C.UP if ch >= 0 else C.DOWN
	var parts := [
		[semi, s["ticker"], C.TEXT, 8.0],
		[regular, UI.money(Market.prices[id]), C.TEXT2, 8.0],
	]
	var w := 0.0
	for p in parts:
		if paint:
			draw_string(p[0], Vector2(x + w, base), p[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, p[2])
		w += p[0].get_string_size(p[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + p[3]
	if paint:
		var cy := size.y / 2.0
		var tx := x + w
		var tri: PackedVector2Array
		if ch >= 0:
			tri = [Vector2(tx, cy + 3), Vector2(tx + 7, cy + 3), Vector2(tx + 3.5, cy - 3)]
		else:
			tri = [Vector2(tx, cy - 3), Vector2(tx + 7, cy - 3), Vector2(tx + 3.5, cy + 3)]
		draw_colored_polygon(tri, col)
	w += 11.0
	var pct := UI.percent(ch)
	if paint:
		draw_string(semi, Vector2(x + w, base), pct, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)
	w += semi.get_string_size(pct, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + GAP
	return w
