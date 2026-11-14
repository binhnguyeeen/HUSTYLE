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
## Price and percent get fixed slots, so changing numbers never shift the strip.
func _item(s: Dictionary, semi: Font, regular: Font, x: float, base: float, paint: bool) -> float:
	var id: String = s["id"]
	var ch: float = Market.change.get(id, 0.0)
	var col := C.UP if ch >= 0 else C.DOWN
	var price := UI.money(Market.prices[id])
	var w := 0.0
	if paint:
		draw_string(semi, Vector2(x, base), s["ticker"], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, C.TEXT)
	w += semi.get_string_size(s["ticker"], HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 8.0
	if paint:
		draw_string(regular, Vector2(x + w, base), price, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, C.TEXT2)
	w += _slot(regular, UI.money(float(s["base_price"]) * 2.0)) + 8.0
	if paint:
		var cy := size.y / 2.0
		var tx := x + w
		var tri: PackedVector2Array
		if ch >= 0:
			tri = [Vector2(tx, cy + 3), Vector2(tx + 7, cy + 3), Vector2(tx + 3.5, cy - 3)]
		else:
			tri = [Vector2(tx, cy - 3), Vector2(tx + 7, cy - 3), Vector2(tx + 3.5, cy + 3)]
		draw_colored_polygon(tri, col)
		draw_string(semi, Vector2(x + w + 11.0, base), UI.percent(ch), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)
	w += 11.0 + _slot(semi, "00.0%") + GAP
	return w


## Width of a text with every digit as a zero, the widest digit.
func _slot(font: Font, text: String) -> float:
	var wide := ""
	for ch in text:
		wide += "0" if ch >= "0" and ch <= "9" else ch
	return font.get_string_size(wide, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
