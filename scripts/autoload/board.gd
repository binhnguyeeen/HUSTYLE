extends Node
## Hall of Fame. Local top 10 first, online board behind a switch.

signal loaded(rows: Array, offline: bool)

const ONLINE_BOARD := false
const BOARD_URL := ""
const BOARD_KEY := ""
const TOP := 10
const NICK_MAX := 12

var last_entry := {}


func post(nickname: String, net_worth: float, bounce_backs: int) -> void:
	var nick := nickname.strip_edges().left(NICK_MAX)
	if nick == "":
		return
	last_entry = { "nickname": nick, "net_worth": snappedf(net_worth, 0.01), "bounce_backs": bounce_backs, "t": Time.get_unix_time_from_system() }
	Save.local_scores.append(last_entry)
	Save.local_scores = _top(Save.local_scores)
	Save.write()


func local_top() -> Array:
	return _top(Save.local_scores)


func _top(rows: Array) -> Array:
	var r := rows.duplicate()
	r.sort_custom(func(a, b): return a["net_worth"] > b["net_worth"])
	return r.slice(0, TOP)
