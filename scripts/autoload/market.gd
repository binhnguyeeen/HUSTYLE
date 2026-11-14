extends Node
## Prices, styles and the daily news line.

signal prices_changed

const STOCKS_PATH := "res://data/stocks.json"
const HISTORY_LEN := 12
const DEFAULT_STYLE := "normal"
const MIN_PRICE := 1.0

## Each style: daily move range, crash weight, drift per day,
## and for meme a chance of a sudden spike up.
const STYLES := {
	"steady": { "volatility": 0.02, "crash_weight": 1.0, "drift": 0.003, "spike_chance": 0.0 },
	"normal": { "volatility": 0.04, "crash_weight": 2.0, "drift": 0.001, "spike_chance": 0.0 },
	"wild": { "volatility": 0.08, "crash_weight": 3.0, "drift": 0.0, "spike_chance": 0.0 },
	"meme": { "volatility": 0.15, "crash_weight": 5.0, "drift": -0.002, "spike_chance": 0.08 },
}

## About one day in six one stock crashes, then climbs back.
const CRASH_CHANCE := 1.0 / 6.0
const CRASH_MIN := 0.15
const CRASH_MAX := 0.30
const RECOVER_DAYS_MIN := 2
const RECOVER_DAYS_MAX := 3
const SPIKE_MIN := 0.2
const SPIKE_MAX := 0.5

var stocks: Array[Dictionary] = []
var prices := {}
var history := {}  # id -> Array of { "day": int, "price": float }
var change := {}  # id -> fraction since yesterday
var recovering := {}  # id -> { "days_left", "per_day", "crash_day" }
var news := ""
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	load_stocks()


func load_stocks() -> void:
	stocks.clear()
	var f := FileAccess.open(STOCKS_PATH, FileAccess.READ)
	if f == null:
		push_error("Missing " + STOCKS_PATH)
		return
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_ARRAY:
		push_error("stocks.json must be a list")
		return
	for e in data:
		if typeof(e) != TYPE_DICTIONARY or not e.has("id") or not e.has("base_price"):
			push_warning("Skipping stock entry without id or base_price")
			continue
		var s: Dictionary = e.duplicate()
		s["style"] = s.get("style", DEFAULT_STYLE) if STYLES.has(s.get("style", "")) else DEFAULT_STYLE
		s["name"] = str(s.get("name", s["id"]))
		s["ticker"] = str(s.get("ticker", str(s["id"]).to_upper()))
		s["logo"] = str(s.get("logo", "res://assets/logos/%s.png" % s["id"]))
		stocks.append(s)


func stock(id: String) -> Dictionary:
	for s in stocks:
		if s["id"] == id:
			return s
	return {}


func volatility(s: Dictionary) -> float:
	return float(s.get("volatility", STYLES[s["style"]]["volatility"]))


func new_run(seed_value: int) -> void:
	rng.seed = seed_value
	prices.clear()
	history.clear()
	change.clear()
	recovering.clear()
	for s in stocks:
		prices[s["id"]] = float(s["base_price"])
		history[s["id"]] = []
	# Quiet days before day 1 so the chart is never empty.
	for d in range(2 - HISTORY_LEN, 1):
		_move_all(d, false)
	# Scale the quiet days so day 1 opens at the base price.
	for s in stocks:
		var id: String = s["id"]
		var k: float = float(s["base_price"]) / float(prices[id])
		for h in history[id]:
			h["price"] = snappedf(h["price"] * k, 0.01)
		prices[id] = float(s["base_price"])
	news = "The market opens. Good luck."
	prices_changed.emit()


func advance_day(day: int) -> void:
	_move_all(day, true)
	prices_changed.emit()


func cheapest() -> Dictionary:
	var best := {}
	for s in stocks:
		if best.is_empty() or prices[s["id"]] < prices[best["id"]]:
			best = s
	return best


func _move_all(day: int, allow_events: bool) -> void:
	var events := {}
	var finished := {}
	for s in stocks:
		var id: String = s["id"]
		var st: Dictionary = STYLES[s["style"]]
		var vol := volatility(s)
		var c: float
		if recovering.has(id):
			var r: Dictionary = recovering[id]
			c = r["per_day"] + rng.randf_range(-vol, vol) * 0.25
			r["days_left"] -= 1
			if r["days_left"] <= 0:
				finished[id] = r["crash_day"]
				recovering.erase(id)
		else:
			c = rng.randf_range(-vol, vol) + st["drift"]
			if allow_events and rng.randf() < st["spike_chance"]:
				c = rng.randf_range(SPIKE_MIN, SPIKE_MAX)
				events[id] = "spike"
		change[id] = c
	if allow_events and rng.randf() < CRASH_CHANCE:
		var victim := _pick_crash_victim()
		if victim != "":
			var drop := rng.randf_range(CRASH_MIN, CRASH_MAX)
			var days := rng.randi_range(RECOVER_DAYS_MIN, RECOVER_DAYS_MAX)
			change[victim] = -drop
			recovering[victim] = {
				"days_left": days,
				"per_day": pow(1.0 / (1.0 - drop), 1.0 / days) - 1.0,
				"crash_day": day,
			}
			events[victim] = "crash"
			finished.erase(victim)
	for s in stocks:
		var id: String = s["id"]
		prices[id] = maxf(MIN_PRICE, snappedf(prices[id] * (1.0 + change[id]), 0.01))
		var h: Array = history[id]
		h.append({ "day": day, "price": prices[id] })
		if h.size() > HISTORY_LEN:
			h.pop_front()
	if allow_events:
		news = _news_line(day, events, finished)


func _pick_crash_victim() -> String:
	var candidates := stocks.filter(func(s): return not recovering.has(s["id"]))
	var total := 0.0
	for s in candidates:
		total += STYLES[s["style"]]["crash_weight"]
	var roll := rng.randf() * total
	for s in candidates:
		roll -= STYLES[s["style"]]["crash_weight"]
		if roll <= 0.0:
			return s["id"]
	return ""


func _news_line(day: int, events: Dictionary, finished: Dictionary) -> String:
	for id in events:
		var n: String = stock(id)["name"]
		if events[id] == "crash":
			return "%s crashed %s on day %d" % [n, UI.percent(change[id]), day]
		return "%s spiked %s on day %d" % [n, UI.percent(change[id]), day]
	for id in finished:
		return "%s dipped on day %d and climbed back by day %d" % [stock(id)["name"], finished[id], day]
	var top := ""
	for s in stocks:
		if top == "" or absf(change[s["id"]]) > absf(change[top]):
			top = s["id"]
	if top == "":
		return ""
	var verb := "rose" if change[top] >= 0 else "slipped"
	return "%s %s %s on day %d" % [stock(top)["name"], verb, UI.percent(change[top]), day]


func to_dict() -> Dictionary:
	return { "prices": prices, "history": history, "recovering": recovering, "news": news }


func from_dict(d: Dictionary, seed_value: int, day: int) -> void:
	rng.seed = seed_value + day * 7919
	for s in stocks:
		var id: String = s["id"]
		prices[id] = float(d.get("prices", {}).get(id, s["base_price"]))
		history[id] = d.get("history", {}).get(id, [{ "day": day, "price": prices[id] }])
		change[id] = 0.0
		var h: Array = history[id]
		if h.size() >= 2:
			change[id] = h[-1]["price"] / h[-2]["price"] - 1.0
	recovering = d.get("recovering", {})
	news = str(d.get("news", ""))
	prices_changed.emit()
