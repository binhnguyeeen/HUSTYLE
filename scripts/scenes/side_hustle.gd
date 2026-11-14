extends Control
## Bounce Back: keep the coin in the air with the paddle.

const GRAVITY := 900.0
const BOUNCE_SPEED := 640.0
const COIN_R := 22.0
const PADDLE := Vector2(160, 14)
const PADDLE_Y := 644.0
const FLOOR_Y := 680.0

var time_left := Game.HUSTLE_SECONDS
var bounces := 0
var coin := Vector2.ZERO
var vel := Vector2.ZERO
var paddle_x := 640.0
var trail: Array[Vector2] = []
var done := false
var bounce_label: Label
var bounce_value: Label
var clock: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Game.paused = true
	var hud := UI.box(false, 6)
	hud.position = Vector2(32, 32)
	bounce_label = UI.label("Bounces", 20, UI.W.SEMI, C.TEXT2)
	bounce_value = UI.label("0", 20, UI.W.SEMI)
	hud.add_child(bounce_label)
	hud.add_child(bounce_value)
	add_child(hud)
	clock = UI.label("", 28, UI.W.BOLD, C.ACCENT)
	clock.position = Vector2(1280 - 32 - 80, 28)
	clock.custom_minimum_size = Vector2(80, 0)
	clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(clock)
	var mid := UI.box(true, 4)
	mid.position = Vector2(0, 120)
	mid.custom_minimum_size = Vector2(1280, 0)
	var t := UI.label("Bounce Back", 28, UI.W.SEMI)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(t)
	var s := UI.label("Keep the coin in the air", 14, UI.W.REGULAR, C.TEXT2)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(s)
	add_child(mid)
	_drop()


func _drop() -> void:
	coin = Vector2(randf_range(200, 1080), 220)
	vel = Vector2(randf_range(-120, 120), 0)
	trail.clear()


func _input(e: InputEvent) -> void:
	if e is InputEventMouseMotion or e is InputEventScreenDrag or e is InputEventScreenTouch:
		paddle_x = clampf(e.position.x, PADDLE.x / 2, 1280 - PADDLE.x / 2)


func _process(delta: float) -> void:
	if done:
		return
	time_left -= delta
	if time_left <= 0.0:
		_finish()
		return
	vel.y += GRAVITY * delta
	coin += vel * delta
	if coin.x < COIN_R or coin.x > 1280 - COIN_R:
		vel.x = -vel.x
		coin.x = clampf(coin.x, COIN_R, 1280 - COIN_R)
	var top := PADDLE_Y - PADDLE.y / 2
	if vel.y > 0 and coin.y + COIN_R >= top and coin.y + COIN_R <= top + 24 and absf(coin.x - paddle_x) <= PADDLE.x / 2 + COIN_R * 0.5:
		coin.y = top - COIN_R
		var off := (coin.x - paddle_x) / (PADDLE.x / 2)
		vel = Vector2(off * 360.0, -BOUNCE_SPEED - bounces * 6.0)
		bounces += 1
	if coin.y - COIN_R > 720:
		_drop()
	trail.push_front(coin)
	if trail.size() > 6:
		trail.pop_back()
	bounce_value.text = str(bounces)
	clock.text = UI.clock(time_left)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(1280, 720)), C.BG_BASE)
	draw_line(Vector2(0, FLOOR_Y), Vector2(1280, FLOOR_Y), C.LINE, 1.0)
	for i in range(trail.size() - 1, 0, -2):
		draw_circle(trail[i], COIN_R * 0.8, Color(C.ACCENT, 0.08))
	draw_circle(coin, COIN_R, C.ACCENT)
	draw_circle(coin, COIN_R * 0.62, C.ACCENT.darkened(0.25), false, 2.0, true)
	var r := Rect2(Vector2(paddle_x - PADDLE.x / 2, PADDLE_Y - PADDLE.y / 2), PADDLE)
	draw_style_box(UI.style(C.TEXT, 7), r)


func _finish() -> void:
	done = true
	Game.finish_hustle(bounces)
	if Game.running:
		get_tree().change_scene_to_file("res://scenes/trading_floor.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/results.tscn")
