extends Control

const COLS := [64, 0, 160, 120]  # 0 fills

var col: VBoxContainer
var rows: VBoxContainer
var notice: Control


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = C.BG_BASE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	add_child(Brand.make())
	var back := UI.button("Back")
	back.position = Vector2(1280 - 20 - 80, 10)
	back.custom_minimum_size = Vector2(80, 36)
	back.pressed.connect(func():
		var to := "res://scenes/trading_floor.tscn" if Game.running else "res://scenes/title.tscn"
		get_tree().change_scene_to_file(to))
	add_child(back)

	col = UI.box(true, 16)
	col.position = Vector2(280, 72)
	col.custom_minimum_size = Vector2(720, 0)
	add_child(col)
	var t := UI.label("Hall of Fame", 28, UI.W.SEMI)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(t)
	notice = _offline_notice()
	notice.visible = false
	col.add_child(notice)

	var table := UI.panel(C.BG_PANEL, C.RADIUS_CARD, 16, C.LINE)
	rows = UI.box(true, 4)
	table.add_child(rows)
	col.add_child(table)
	_show_message("Loading scores...")
	Board.loaded.connect(_show_rows, CONNECT_ONE_SHOT)
	Board.fetch()


func _show_rows(entries: Array, online: bool) -> void:
	notice.visible = Board.ONLINE_BOARD and not online
	if entries.is_empty():
		_show_message("No scores yet. Finish a run to be the first.")
		return
	UI.clear(rows)
	rows.add_child(_row(["Rank", "Nickname", "Net worth", "Bounce backs"], true, false))
	var rank := 1
	for e in entries:
		rows.add_child(_row([str(rank), str(e["nickname"]), UI.money(e["net_worth"]), str(int(e["bounce_backs"]))], false, Board.is_mine(e)))
		rank += 1


func _show_message(text: String) -> void:
	UI.clear(rows)
	rows.add_child(_row(["Rank", "Nickname", "Net worth", "Bounce backs"], true, false))
	var l := UI.label(text, 14, UI.W.REGULAR, C.TEXT2)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(0, 88)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rows.add_child(l)


func _row(cells: Array, header: bool, mine: bool) -> Control:
	var p := UI.panel(Color(C.ACCENT, 0.12) if mine else Color(0, 0, 0, 0), C.RADIUS_CONTROL, 0, Color(C.ACCENT, 0.6) if mine else Color(0, 0, 0, 0))
	p.custom_minimum_size = Vector2(0, 32 if header else 44)
	var h := UI.box(false, 16)
	p.add_child(UI.margin(h, 16, 0, 16, 0))
	for i in cells.size():
		var fs := 12 if header else 14
		var col: Color = C.MUTED if header else (C.ACCENT if mine and i < 2 else C.TEXT)
		var weight := UI.W.REGULAR if header or i == 0 else UI.W.SEMI
		var l := UI.label(cells[i], fs, weight, col)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if COLS[i] == 0:
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		else:
			l.custom_minimum_size = Vector2(COLS[i], 0)
		if i >= 2:
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(l)
	return p


func _offline_notice() -> Control:
	var p := UI.panel(C.BG_RAISED, 999, 0, C.ACCENT)
	var h := UI.box(false, 8)
	var dot := Panel.new()
	dot.add_theme_stylebox_override("panel", UI.style(C.ACCENT, 3))
	dot.custom_minimum_size = Vector2(6, 6)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(dot)
	h.add_child(UI.label("Could not reach the board. Showing scores from this device.", 12, UI.W.REGULAR, C.TEXT2))
	p.add_child(UI.margin(h, 12, 6, 12, 6))
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return p
