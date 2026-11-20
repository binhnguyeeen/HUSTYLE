extends Control
## Block Breaker: break blocks with the coin. $ blocks pay, ball blocks split the coin.
## Board and block look from Figma (Prototype page, "Blocks" and "Sample game").

const COIN_TEX := preload("res://assets/hustle/coin.png")
const COIN_R := 12.0
const SPIN := 0.01
## Coin speed in px/s. It speeds up a little on every paddle hit.
const START_SPEED := 620.0
const MAX_SPEED := 920.0
const SPEED_UP := 12.0
## Widest bounce angle off the paddle edge, from straight up.
const MAX_ANGLE := deg_to_rad(62.0)
const PADDLE := Vector2(160, 14)
## The paddle glides to the mouse every frame instead of jumping on each mouse event.
const PADDLE_FOLLOW := 35.0
const PADDLE_Y := 644.0
const FLOOR_Y := 680.0
const TOP := 104.0

## Grid: the Sample game board, scaled down to fit 1280x720.
const COLS := 7
const ROWS := 4
const BLOCK := Vector2(136, 44)
const GAP := Vector2(16, 14)
const GRID_Y := 128.0
const BLOCK_RADIUS := 13
const BORDER := 3
## How many special blocks a shuffled board gets.
const CASH_BLOCKS := 8
const BALL_BLOCKS := 2
const SPLIT_ANGLE := deg_to_rad(28.0)

## Hit points to colors: green breaks in 1, yellow in 2, red in 3.
const FILL := {1: C.UP, 2: C.ACCENT, 3: C.DOWN}
const EDGE := {1: Color("#117200"), 2: Color("#726E00"), 3: Color("#9D0E01")}

enum Kind { PLAIN, CASH, BALL }

class Ball:
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var spin := 0.0
	var trail: Array[Vector2] = []

var blocks: Array[Dictionary] = []  # { rect, hp, kind }
var balls: Array[Ball] = []
var pops: Array[Dictionary] = []  # floating "+$40" and break flashes
var lives := Game.BREAKER_LIVES
var earned := 0.0
var time_left := Game.BREAKER_SECONDS
var speed := START_SPEED
var paddle_x := 640.0
var target_x := 640.0
var waiting := true  # the coin sits on the paddle until a click
var started := false
var done := false
var end_wait := 0.0
var money_value: Label
var clock: Label
var hint: Label
var banner: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# Mipmaps keep the small coin from shimmering as it moves.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	Game.paused = true
	var hud := UI.box(false, 6)
	hud.position = Vector2(32, 32)
	hud.add_child(UI.label("Earned", 20, UI.W.SEMI, C.TEXT2))
	money_value = UI.label(UI.money(0), 20, UI.W.SEMI, C.ACCENT)
	hud.add_child(money_value)
	add_child(hud)
	clock = UI.label(UI.clock(time_left), 28, UI.W.BOLD, C.ACCENT)
	clock.position = Vector2(1280 - 32 - 80, 28)
	clock.custom_minimum_size = Vector2(80, 0)
	clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(clock)
	var title := UI.label("Block Breaker", 20, UI.W.SEMI)
	title.position = Vector2(0, 34)
	title.custom_minimum_size = Vector2(1280, 0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	hint = UI.label("Click to launch", 14, UI.W.REGULAR, C.TEXT2)
	hint.position = Vector2(0, 470)
	hint.custom_minimum_size = Vector2(1280, 0)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)
	banner = UI.label("", 28, UI.W.BOLD, C.ACCENT)
	banner.position = Vector2(0, 430)
	banner.custom_minimum_size = Vector2(1280, 0)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(banner)
	_build_board()
	_reset_coin()


## Same 7x4 grid every round, with colors and specials shuffled.
func _build_board() -> void:
	var kinds: Array[int] = []
	for i in COLS * ROWS:
		kinds.append(Kind.CASH if i < CASH_BLOCKS else Kind.BALL if i < CASH_BLOCKS + BALL_BLOCKS else Kind.PLAIN)
	kinds.shuffle()
	var left := (1280.0 - (COLS * BLOCK.x + (COLS - 1) * GAP.x)) / 2.0
	for row in ROWS:
		for col in COLS:
			var r := randf()
			var hp := 1 if r < 0.4 else 2 if r < 0.75 else 3
			var at := Vector2(left + col * (BLOCK.x + GAP.x), GRID_Y + row * (BLOCK.y + GAP.y))
			blocks.append({ "rect": Rect2(at, BLOCK), "hp": hp, "kind": kinds[row * COLS + col] })


func _reset_coin() -> void:
	balls.clear()
	var b := Ball.new()
	b.pos = Vector2(paddle_x, PADDLE_Y - PADDLE.y / 2 - COIN_R)
	balls.append(b)
	waiting = true


func _launch() -> void:
	if not waiting or done:
		return
	waiting = false
	started = true
	hint.visible = false
	var a := randf_range(-0.35, 0.35)
	balls[0].vel = Vector2(sin(a), -cos(a)) * speed


func _input(e: InputEvent) -> void:
	if e is InputEventMouseMotion or e is InputEventScreenDrag or e is InputEventScreenTouch:
		target_x = clampf(e.position.x, PADDLE.x / 2, 1280 - PADDLE.x / 2)
	if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
		_launch()
	elif e.is_action_pressed("ui_accept"):
		_launch()


func _process(delta: float) -> void:
	paddle_x = lerpf(paddle_x, target_x, 1.0 - exp(-PADDLE_FOLLOW * delta))
	_update_pops(delta)
	if done:
		end_wait -= delta
		if end_wait <= 0.0:
			_finish()
		queue_redraw()
		return
	if started:
		time_left -= delta
		if time_left <= 0.0:
			time_left = 0.0
			_end("Time's up")
	if waiting:
		balls[0].pos.x = paddle_x
	else:
		# Two half steps so fast coins can't skip through a block.
		for i in 2:
			for b in balls.duplicate():
				_step(b, delta / 2.0)
		if balls.is_empty():
			lives -= 1
			if lives <= 0:
				_end("Out of coins")
			else:
				_reset_coin()
	money_value.text = UI.money(earned)
	clock.text = UI.clock(time_left)
	queue_redraw()


func _step(b: Ball, dt: float) -> void:
	b.pos += b.vel * dt
	b.spin += b.vel.x * SPIN * dt
	if b.pos.x < COIN_R or b.pos.x > 1280 - COIN_R:
		b.vel.x = -b.vel.x
		b.pos.x = clampf(b.pos.x, COIN_R, 1280 - COIN_R)
	if b.pos.y < TOP + COIN_R:
		b.vel.y = absf(b.vel.y)
		b.pos.y = TOP + COIN_R
	# Paddle: where it lands sets the angle, like Pong.
	var top := PADDLE_Y - PADDLE.y / 2
	if b.vel.y > 0 and b.pos.y + COIN_R >= top and b.pos.y + COIN_R <= top + 20 and absf(b.pos.x - paddle_x) <= PADDLE.x / 2 + COIN_R:
		var off := clampf((b.pos.x - paddle_x) / (PADDLE.x / 2), -1.0, 1.0)
		speed = minf(speed + SPEED_UP, MAX_SPEED)
		var a := off * MAX_ANGLE
		b.vel = Vector2(sin(a), -cos(a)) * speed
		b.pos.y = top - COIN_R
	_hit_blocks(b)
	if b.pos.y - COIN_R > 720:
		balls.erase(b)
		return
	b.trail.push_front(b.pos)
	if b.trail.size() > 6:
		b.trail.pop_back()


func _hit_blocks(b: Ball) -> void:
	for blk in blocks:
		var r: Rect2 = blk["rect"]
		var near := Vector2(clampf(b.pos.x, r.position.x, r.end.x), clampf(b.pos.y, r.position.y, r.end.y))
		var d := b.pos - near
		if d.length_squared() > COIN_R * COIN_R:
			continue
		# Bounce off the side the coin came in from.
		var pen_x := COIN_R - absf(b.pos.x - r.get_center().x) + r.size.x / 2
		var pen_y := COIN_R - absf(b.pos.y - r.get_center().y) + r.size.y / 2
		if pen_x < pen_y:
			b.vel.x = absf(b.vel.x) * (1.0 if b.pos.x > r.get_center().x else -1.0)
		else:
			b.vel.y = absf(b.vel.y) * (1.0 if b.pos.y > r.get_center().y else -1.0)
		_damage(blk, b)
		return


func _damage(blk: Dictionary, b: Ball) -> void:
	blk["hp"] -= 1
	if blk["hp"] > 0:
		return
	var r: Rect2 = blk["rect"]
	blocks.erase(blk)
	pops.append({ "kind": "flash", "rect": r, "kind_block": blk["kind"], "t": 0.0 })
	match blk["kind"]:
		Kind.CASH:
			earned += Game.BREAKER_CASH_BLOCK
			pops.append({ "kind": "text", "text": "+" + _cash(Game.BREAKER_CASH_BLOCK), "at": r.get_center(), "t": 0.0 })
		Kind.BALL:
			for side in [-1.0, 1.0]:
				var n := Ball.new()
				n.pos = b.pos
				n.vel = b.vel.rotated(side * SPLIT_ANGLE)
				if n.vel.y > -120.0 and n.vel.y < 120.0:
					n.vel.y = -120.0
				balls.append(n)
	if blocks.is_empty():
		earned += Game.BREAKER_CLEAR_BONUS
		pops.append({ "kind": "text", "text": "+" + _cash(Game.BREAKER_CLEAR_BONUS), "at": Vector2(640, 380), "t": 0.0 })
		_end("Board cleared")


func _update_pops(delta: float) -> void:
	for p in pops.duplicate():
		p["t"] += delta
		if p["t"] > 0.9:
			pops.erase(p)


func _end(text: String) -> void:
	if done:
		return
	done = true
	banner.text = text
	hint.visible = false
	end_wait = 1.4
	money_value.text = UI.money(earned)
	clock.text = UI.clock(time_left)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(1280, 720)), C.BG_BASE)
	draw_line(Vector2(0, FLOOR_Y), Vector2(1280, FLOOR_Y), C.LINE, 1.0)
	for blk in blocks:
		_draw_block(blk["rect"], blk["hp"], blk["kind"], 1.0)
	for p in pops:
		var k: float = p["t"] / 0.9
		if p["kind"] == "flash":
			var r: Rect2 = p["rect"]
			_draw_block(r.grow(k * 10.0), 1, p["kind_block"], (1.0 - k) * 0.6)
	for b in balls:
		for i in range(b.trail.size() - 1, 0, -2):
			_draw_coin(b.trail[i], COIN_R * 0.8, b.spin, Color(1, 1, 1, 0.12))
		_draw_coin(b.pos, COIN_R, b.spin, Color.WHITE)
	var pr := Rect2(Vector2(paddle_x - PADDLE.x / 2, PADDLE_Y - PADDLE.y / 2), PADDLE)
	draw_style_box(UI.style(C.TEXT, 7), pr)
	# Lives as coins, bottom left under the floor line.
	for i in Game.BREAKER_LIVES:
		_draw_coin(Vector2(44 + i * 30, 700), 10, 0.0, Color.WHITE if i < lives else Color(1, 1, 1, 0.2))
	var font: Font = UI.FONTS[UI.W.BOLD]
	for p in pops:
		if p["kind"] != "text":
			continue
		var k: float = p["t"] / 0.9
		var at: Vector2 = p["at"] + Vector2(0, -40.0 * k)
		var s: String = p["text"]
		var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		draw_string(font, at + Vector2(-w / 2, 8), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(C.ACCENT, 1.0 - k))


func _draw_block(r: Rect2, hp: int, kind: int, alpha: float) -> void:
	var fill: Color = FILL[hp]
	var edge: Color = EDGE[hp]
	var s := UI.style(Color(fill, alpha), BLOCK_RADIUS)
	s.border_color = Color(edge, alpha)
	s.set_border_width_all(BORDER)
	draw_style_box(s, r)
	# Icons use a darker block color with the border color as outline, like Figma.
	var icon := Color(fill.darkened(0.27), alpha)
	var c := r.get_center()
	if kind == Kind.BALL:
		draw_circle(c, 11, icon)
		draw_arc(c, 11, 0, TAU, 32, Color(edge, alpha), 1.5, true)
	elif kind == Kind.CASH:
		var font: Font = UI.FONTS[UI.W.BOLD]
		var w := font.get_string_size("$", HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
		var at := c + Vector2(-w / 2, 9)
		draw_string_outline(font, at, "$", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, 3, Color(edge, alpha))
		draw_string(font, at, "$", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, icon)


func _draw_coin(at: Vector2, r: float, spin: float, tint: Color) -> void:
	draw_set_transform(at, spin)
	draw_texture_rect(COIN_TEX, Rect2(-r, -r, r * 2, r * 2), false, tint)
	draw_set_transform(Vector2.ZERO)


func _finish() -> void:
	Game.finish_breaker(earned)
	if Game.running:
		get_tree().change_scene_to_file("res://scenes/trading_floor.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/results.tscn")


## Whole dollars, like "$40".
func _cash(v: float) -> String:
	return Game.CURRENCY + str(int(v))
