extends Control


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = C.BG_BASE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var line := MarketLine.new()
	line.position = Vector2(0, 610)
	line.size = Vector2(1280, 110)
	add_child(line)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var col := UI.box(true, 32)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(col)

	var brand := UI.box(true, 8)
	var logo := UI.logo("res://assets/logos/hustyle.png", 120)
	logo.custom_minimum_size = Vector2(120, 132)
	logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	brand.add_child(logo)
	var word := UI.label("HUSTYLE", 40, UI.W.BOLD, C.ACCENT)
	word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	brand.add_child(word)
	var tag := UI.label("Hustle in style", 16, UI.W.REGULAR, C.TEXT2)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	brand.add_child(tag)
	col.add_child(brand)

	var buttons := UI.box(true, 12)
	buttons.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var play := _btn("Play", true)
	play.pressed.connect(func():
		Game.new_run()
		get_tree().change_scene_to_file("res://scenes/trading_floor.tscn"))
	buttons.add_child(play)
	var cont := _btn("Continue")
	cont.disabled = not Save.has_run()
	cont.pressed.connect(func():
		if Save.load_run():
			get_tree().change_scene_to_file("res://scenes/trading_floor.tscn"))
	buttons.add_child(cont)
	var hof := _btn("Hall of Fame")
	hof.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hall_of_fame.tscn"))
	buttons.add_child(hof)
	var how := _btn("How to play")
	how.disabled = true
	buttons.add_child(how)
	col.add_child(buttons)

	if not Save.persistent():
		var warn := UI.label("Progress will not be saved in this browser", 12, UI.W.REGULAR, C.MUTED)
		warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(warn)


func _btn(text: String, primary := false) -> Button:
	var b := UI.button(text, primary, 44)
	b.custom_minimum_size = Vector2(280, 44)
	return b
