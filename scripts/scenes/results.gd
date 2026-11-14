extends Control

var nick_field: LineEdit
var post_btn: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = C.BG_BASE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	add_child(Brand.make())

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var col := UI.box(true, 24)
	col.custom_minimum_size = Vector2(560, 0)
	center.add_child(col)

	var title := UI.label("Run over", 28, UI.W.SEMI)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var head := UI.box(true, 4)
	var fl := UI.label("Final net worth", 14, UI.W.REGULAR, C.TEXT2)
	fl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(fl)
	var fv := UI.label(UI.money(Game.final_net_worth), 40, UI.W.BOLD, C.ACCENT)
	fv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(fv)
	col.add_child(head)

	var tiles := UI.box(false, 16)
	tiles.add_child(_tile("Bounce backs", str(Game.bounce_backs), ""))
	tiles.add_child(_tile("Lowest point", UI.money(Game.lowest_net_worth), "Day %d" % Game.lowest_day))
	col.add_child(tiles)

	var nick := UI.box(true, 8)
	nick.add_child(UI.label("Your nickname", 12, UI.W.SEMI, C.TEXT2))
	var row := UI.box(false, 12)
	nick_field = LineEdit.new()
	nick_field.max_length = Board.NICK_MAX
	nick_field.custom_minimum_size = Vector2(0, 44)
	nick_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nick_field.text_submitted.connect(func(_t): _post())
	row.add_child(nick_field)
	post_btn = UI.button("Post my score", true, 44)
	post_btn.pressed.connect(_post)
	post_btn.disabled = true
	nick_field.text_changed.connect(func(t): post_btn.disabled = t.strip_edges() == "")
	row.add_child(post_btn)
	nick.add_child(row)
	col.add_child(nick)

	var actions := UI.box(false, 12)
	var again := UI.button("Play again", false, 44)
	again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	again.pressed.connect(func():
		Game.new_run()
		get_tree().change_scene_to_file("res://scenes/trading_floor.tscn"))
	actions.add_child(again)
	var hof := UI.button("Hall of Fame", false, 44)
	hof.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hof.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hall_of_fame.tscn"))
	actions.add_child(hof)
	col.add_child(actions)
	nick_field.call_deferred("grab_focus")


func _tile(title: String, value: String, sub: String) -> Control:
	var p := UI.panel(C.BG_PANEL, C.RADIUS_CARD, 16, C.LINE)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UI.box(true, 4)
	p.add_child(v)
	v.add_child(UI.label(title, 12, UI.W.REGULAR, C.TEXT2))
	var h := UI.box(false, 8)
	h.add_child(UI.label(value, 20, UI.W.SEMI))
	if sub != "":
		var s := UI.label(sub, 14, UI.W.REGULAR, C.TEXT2)
		s.size_flags_vertical = Control.SIZE_SHRINK_END
		h.add_child(s)
	v.add_child(h)
	return p


func _post() -> void:
	if post_btn.disabled or nick_field.text.strip_edges() == "":
		return
	post_btn.disabled = true
	Board.post(nick_field.text, Game.final_net_worth, Game.bounce_backs)
	get_tree().change_scene_to_file("res://scenes/hall_of_fame.tscn")
