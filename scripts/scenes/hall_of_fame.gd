extends Control

const COLS := [64, 0, 160, 120]  # 0 fills


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

	var col := UI.box(true, 16)
	col.position = Vector2(280, 72)
	col.custom_minimum_size = Vector2(720, 0)
	add_child(col)
	var t := UI.label("Hall of Fame", 28, UI.W.SEMI)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(t)
	if Board.ONLINE_BOARD:
		col.add_child(_offline_notice())

	var table := UI.panel(C.BG_PANEL, C.RADIUS_CARD, 16, C.LINE)
	var rows := UI.box(true, 4)
	table.add_child(rows)
	rows.add_child(_row(["Rank", "Nickname", "Net worth", "Bounce backs"], true, false))
	var rank := 1
	for e in Board.local_top():
		var mine: bool = not Board.last_entry.is_empty() and e.get("t") == Board.last_entry.get("t")
		rows.add_child(_row([str(rank), str(e["nickname"]), UI.money(e["net_worth"]), str(int(e["bounce_backs"]))], false, mine))
		rank += 1
	col.add_child(table)


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
