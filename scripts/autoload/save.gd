extends Node
## One save file. Stock names and logos are never saved.

const PATH := "user://save.json"
const VERSION := 1

var local_scores: Array = []


func _ready() -> void:
	var d := _read()
	local_scores = d.get("local_scores", [])


func persistent() -> bool:
	return OS.is_userfs_persistent()


func has_run() -> bool:
	return bool(_read().get("running", false))


func write() -> void:
	var d := Game.to_dict()
	d.merge(Market.to_dict())
	d["version"] = VERSION
	d["local_scores"] = local_scores
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(d))


func load_run() -> bool:
	var d := _read()
	if not d.get("running", false):
		return false
	Market.from_dict(d, int(d.get("seed", 0)), int(d.get("day", 1)))
	Game.from_dict(d)
	return true


func _read() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return {}
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return {}
	var d = JSON.parse_string(f.get_as_text())
	return d if typeof(d) == TYPE_DICTIONARY else {}
