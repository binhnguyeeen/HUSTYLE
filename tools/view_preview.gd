# Opens the Trading Floor on a chosen chart view. Pass the view index after --.
extends Node


func _ready() -> void:
	Game.new_run()
	var floor_scene: Control = load("res://scenes/trading_floor.tscn").instantiate()
	var args := OS.get_cmdline_user_args()
	floor_scene.view = int(args[0]) if args.size() > 0 else 0
	add_child(floor_scene)
