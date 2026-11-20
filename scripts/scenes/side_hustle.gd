extends Control
## Bounce Back: keep the coin in the air with the paddle.

const GRAVITY := 2000.0
## Bounce height is BOUNCE_SPEED² / (2 × GRAVITY), about 420 px.
const BOUNCE_SPEED := 1300.0
## Pong-style sideways speed. The coin never goes straight up, so the paddle has to move.
const MIN_VX := 420.0
const MAX_VX := 1100.0
## Extra sideways speed after each bounce.
const SPEED_UP := 40.0
## How much hitting off-center steers the coin.
const STEER := 500.0
const COIN_R := 22.0
## The coin art from Figma (Prototype page, Group 1069).
const COIN_TEX := preload("res://assets/hustle/coin.png")
## How fast the coin spins, per pixel per second of sideways speed.
const SPIN := 0.006
const PADDLE := Vector2(160, 14)
## The paddle glides to the mouse every frame instead of jumping on each mouse event.
const PADDLE_FOLLOW := 35.0
const PADDLE_Y := 644.0
const FLOOR_Y := 680.0

var time_left := Game.HUSTLE_SECONDS
var bounces := 0
var drops := 0
var coin := Vector2.ZERO
var vel := Vector2.ZERO
var spin := 0.0
var paddle_x := 640.0
var target_x := 640.0
var trail: Array[Vector2] = []
var done := false
var bounce_label: Label
var bounce_value: Label
var clock: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# Mipmaps keep the small coin from shimmering as it moves.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	Game.paused = true
	var hud := UI.box(false, 6)
	hud.position = Vector2(32, 32)
	bounce_label = UI.label("Drops", 20, UI.W.SEMI, C.TEXT2)
	bounce_value = UI.label("0/%d" % Game.MAX_DROPS, 20, UI.W.SEMI)
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
	var s := UI.label("Keep the coin up for %d seconds" % int(Game.HUSTLE_SECONDS), 14, UI.W.REGULAR, C.TEXT2)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(s)
	add_child(mid)
	_drop()


func _drop() -> void:
	coin = Vector2(randf_range(200, 1080), 220)
	vel = Vector2(randf_range(MIN_VX, MIN_VX + 80) * (1 if randf() < 0.5 else -1), 0)
	trail.clear()


func _input(e: InputEvent) -> void:
	if e is InputEventMouseMotion or e is InputEventScreenDrag or e is InputEventScreenTouch:
		target_x = clampf(e.position.x, PADDLE.x / 2, 1280 - PADDLE.x / 2)


func _process(delta: float) -> void:
	paddle_x = lerpf(paddle_x, target_x, 1.0 - exp(-PADDLE_FOLLOW * delta))
	if done:
		return
	time_left -= delta
	if time_left <= 0.0:
		_finish()
		return
	vel.y += GRAVITY * delta
	coin += vel * delta
	spin += vel.x * SPIN * delta
	if coin.x < COIN_R or coin.x > 1280 - COIN_R:
		vel.x = -vel.x
		coin.x = clampf(coin.x, COIN_R, 1280 - COIN_R)
	var top := PADDLE_Y - PADDLE.y / 2
	if vel.y > 0 and coin.y + COIN_R >= top and coin.y + COIN_R <= top + 24 and absf(coin.x - paddle_x) <= PADDLE.x / 2 + COIN_R * 0.5:
		coin.y = top - COIN_R
		var off := (coin.x - paddle_x) / (PADDLE.x / 2)
		var dir := 1.0 if vel.x >= 0 else -1.0
		var vx := dir * (absf(vel.x) + SPEED_UP) + off * STEER
		if absf(vx) < MIN_VX:
			vx = MIN_VX * (1.0 if vx >= 0 else -1.0)
		vel = Vector2(clampf(vx, -MAX_VX, MAX_VX), -BOUNCE_SPEED)
		bounces += 1
	if coin.y - COIN_R > 720:
		drops += 1
		if drops >= Game.MAX_DROPS:
			_finish()
			return
		time_left = Game.HUSTLE_SECONDS
		bounces = 0
		_drop()
	trail.push_front(coin)
	if trail.size() > 6:
		trail.pop_back()
	bounce_value.text = "%d/%d" % [drops, Game.MAX_DROPS]
	clock.text = UI.clock(time_left)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(1280, 720)), C.BG_BASE)
	draw_line(Vector2(0, FLOOR_Y), Vector2(1280, FLOOR_Y), C.LINE, 1.0)
	for i in range(trail.size() - 1, 0, -2):
		_draw_coin(trail[i], COIN_R * 0.8, Color(1, 1, 1, 0.12))
	_draw_coin(coin, COIN_R, Color.WHITE)
	var r := Rect2(Vector2(paddle_x - PADDLE.x / 2, PADDLE_Y - PADDLE.y / 2), PADDLE)
	draw_style_box(UI.style(C.TEXT, 7), r)


func _draw_coin(at: Vector2, r: float, tint: Color) -> void:
	draw_set_transform(at, spin)
	draw_texture_rect(COIN_TEX, Rect2(-r, -r, r * 2, r * 2), false, tint)
	draw_set_transform(Vector2.ZERO)


func _finish() -> void:
	done = true
	Game.finish_hustle(drops)
	if Game.running:
		get_tree().change_scene_to_file("res://scenes/trading_floor.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/results.tscn")
