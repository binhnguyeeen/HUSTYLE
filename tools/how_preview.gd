# Opens the Title screen with How to play showing.
extends Node


func _ready() -> void:
	var title: Control = load("res://scenes/title.tscn").instantiate()
	add_child(title)
	title.show_how()
