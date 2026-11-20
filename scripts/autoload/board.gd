extends Node
## Hall of Fame. Online board on Supabase, with this device's scores as a fallback.

signal loaded(rows: Array, online: bool)
signal posted

const ONLINE_BOARD := true
## Supabase project "hustyle-asia" (Singapore). The publishable key is meant to be public:
## the scores table only lets players read and add scores, never edit or delete them.
const BOARD_URL := "https://fznjufeecmhfoiqybnqf.supabase.co/rest/v1/scores"
const BOARD_KEY := "sb_publishable_EDNE0oZw_so2ALlLepJ1Ng_ChWrP5Pc"
const TIMEOUT := 8.0
const TOP := 10
const NICK_MAX := 12

var last_entry := {}
var _posting := false


func post(nickname: String, net_worth: float, bounce_backs: int) -> void:
	var nick := nickname.strip_edges().left(NICK_MAX)
	if nick == "":
		return
	last_entry = { "nickname": nick, "net_worth": snappedf(net_worth, 0.01), "bounce_backs": bounce_backs, "t": Time.get_unix_time_from_system() }
	Save.local_scores.append(last_entry)
	Save.local_scores = _top(Save.local_scores)
	Save.write()
	if ONLINE_BOARD:
		_send(last_entry)


## Loads the top scores and emits `loaded`. Falls back to this device's scores when offline.
func fetch() -> void:
	if not ONLINE_BOARD:
		loaded.emit(local_top(), false)
		return
	# Wait for a score that is still posting, so it shows up on the board.
	if _posting:
		await posted
	var res := await _request(BOARD_URL + "?select=nickname,net_worth,bounce_backs&order=net_worth.desc&limit=%d" % TOP, HTTPClient.METHOD_GET, "")
	if res[0] != HTTPRequest.RESULT_SUCCESS or res[1] != 200:
		loaded.emit(local_top(), false)
		return
	var data = JSON.parse_string(res[3].get_string_from_utf8())
	if typeof(data) != TYPE_ARRAY:
		loaded.emit(local_top(), false)
		return
	var rows := []
	for e in data:
		rows.append({ "nickname": str(e.get("nickname", "")), "net_worth": float(e.get("net_worth", 0)), "bounce_backs": int(e.get("bounce_backs", 0)) })
	loaded.emit(rows, true)


func local_top() -> Array:
	return _top(Save.local_scores)


## True for the score this player just posted.
func is_mine(e: Dictionary) -> bool:
	if last_entry.is_empty():
		return false
	return e.get("nickname") == last_entry["nickname"] and is_equal_approx(float(e.get("net_worth", -1)), last_entry["net_worth"]) and int(e.get("bounce_backs", -1)) == last_entry["bounce_backs"]


func _send(entry: Dictionary) -> void:
	_posting = true
	var body := JSON.stringify({ "nickname": entry["nickname"], "net_worth": entry["net_worth"], "bounce_backs": entry["bounce_backs"] })
	await _request(BOARD_URL, HTTPClient.METHOD_POST, body)
	_posting = false
	posted.emit()


## Returns [result, response_code, headers, body].
func _request(url: String, method: int, body: String) -> Array:
	var req := HTTPRequest.new()
	req.timeout = TIMEOUT
	# In the browser, fetch already unzips the reply. Unzipping again in Godot fails.
	req.accept_gzip = false
	add_child(req)
	var headers := ["apikey: " + BOARD_KEY, "Content-Type: application/json", "Prefer: return=minimal"]
	if req.request(url, headers, method, body) != OK:
		req.queue_free()
		return [HTTPRequest.RESULT_CANT_CONNECT, 0, [], PackedByteArray()]
	var res: Array = await req.request_completed
	req.queue_free()
	return res


func _top(rows: Array) -> Array:
	var r := rows.duplicate()
	r.sort_custom(func(a, b): return a["net_worth"] > b["net_worth"])
	return r.slice(0, TOP)
