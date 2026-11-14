# Opens the Trading Floor already broke, or with a payout if PAYOUT is in the args.
extends Node


func _ready() -> void:
	Game.new_run()
	if "PAYOUT" in OS.get_cmdline_user_args():
		Game.cash = 0.0
		Game.finish_hustle(14)
	else:
		Game.cash = 150.0
		Game.next_day()
	get_tree().change_scene_to_file.call_deferred("res://scenes/trading_floor.tscn")
