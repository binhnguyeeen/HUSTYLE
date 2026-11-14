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

## Intraday: how much prices wobble between ticks, as a share of volatility.
const JITTER := 0.25
const JITTER_KEEP := 0.7
## Crashes and spikes play out inside this part of the day.
const EVENT_START := 0.25
const EVENT_END := 0.6
const FEED_LEN := 20
## How many recorded ticks to keep for the chart views.
const TICKS_KEEP := 720

var stocks: Array[Dictionary] = []
var prices := {}  # live price
var open := {}  # price at the start of today
var high := {}
var low := {}
var target := {}  # planned move for today, as a fraction of open
var events := {}  # id -> "crash" or "spike" for today
var history := {}  # id -> Array of { "day": int, "price": float }, past closes
var times: Array[float] = []  # market time of each recorded tick, day plus progress
var ticks := {}  # id -> Array of prices, one per entry in times
var change := {}  # id -> live fraction since today's open
var recovering := {}  # id -> { "days_left", "per_day", "crash_day" }
var news := ""
var feed: Array = []  # newest first, { "day": int, "text": String }
var rng := RandomNumberGenerator.new()

var _announced := {}
var _finished := {}
var _jitter := {}
var _day := 1


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
	feed.clear()
	times.clear()
	ticks.clear()
	for s in stocks:
		prices[s["id"]] = float(s["base_price"])
		history[s["id"]] = []
		ticks[s["id"]] = []
	# Quiet days before day 1 so the chart is never empty.
	var per_day := int(Game.DAY_SECONDS / Game.TICK_SECONDS)
	_record(float(2 - HISTORY_LEN))
	for d in range(2 - HISTORY_LEN, 1):
		_open_day(d, false)
		for i in range(1, per_day):
			tick(float(i) / per_day, true)
		_close_day(d)
	# Scale the quiet days so day 1 opens at the base price.
	for s in stocks:
		var id: String = s["id"]
		var k: float = float(s["base_price"]) / float(prices[id])
		for h in history[id]:
			h["price"] = snappedf(h["price"] * k, 0.01)
		var t: Array = ticks[id]
		for i in t.size():
			t[i] = snappedf(t[i] * k, 0.01)
		prices[id] = float(s["base_price"])
	_open_day(1, true)
	feed.clear()
	_say(1, "The market opens. Good luck.")
	prices_changed.emit()


## Closes the day before and opens the given day.
func advance_day(day: int) -> void:
	_close_day(day - 1)
	_open_day(day, true)
	prices_changed.emit()


## Moves live prices. progress runs from 0 at the open to 1 at the close.
func tick(progress: float, quiet := false) -> void:
	var p := clampf(progress, 0.0, 1.0)
	for s in stocks:
		var id: String = s["id"]
		var shape := p
		if events.has(id):
			shape = smoothstep(EVENT_START, EVENT_END, p)
			if p >= EVENT_START and not _announced.has(id):
				_announced[id] = true
				_say(_day, "%s is %s" % [s["name"], "crashing" if events[id] == "crash" else "spiking"])
		_jitter[id] = _jitter[id] * JITTER_KEEP + randf_range(-1.0, 1.0) * volatility(s) * JITTER
		var price: float = open[id] * (1.0 + target[id] * shape) * (1.0 + _jitter[id] * sin(PI * p))
		_set_price(id, price)
	_record(_day + p)
	if not quiet:
		prices_changed.emit()


func cheapest() -> Dictionary:
	var best := {}
	for s in stocks:
		if best.is_empty() or prices[s["id"]] < prices[best["id"]]:
			best = s
	return best


## Chart data for one stock.
## kind "ticks" shows the last n ticks, kind "days" shows the last n days.
## Points are Vector2(x from 0 to 1, price).
func view(id: String, kind: String, n: int, day: int) -> Dictionary:
	var pts := PackedVector2Array()
	var labels := []
	var dividers := []
	var list: Array = ticks.get(id, [])
	var count := mini(times.size(), list.size())
	if kind == "ticks":
		var first := maxi(0, count - (n + 1))
		var span := maxi(1, count - 1 - first)
		for i in range(first, count):
			pts.append(Vector2(float(i - first) / span, list[i]))
		labels = [[0.0, "%d sec ago" % int(n * Game.TICK_SECONDS)], [1.0, "Now"]]
	else:
		var start := float(day - (n - 1))
		var i := count - 1
		while i >= 0 and times[i] >= start:
			i -= 1
		for j in range(i + 1, count):
			pts.append(Vector2((times[j] - start) / n, list[j]))
		if n == 1:
			labels = [[0.0, "Open"], [1.0, "Close"]]
		else:
			var every := 1 if n <= 5 else 2
			for d in range(day - (n - 1), day + 1):
				var x := (d - start) / n
				if x > 0.0:
					dividers.append(x)
				if d >= 1 and (day - d) % every == 0:
					labels.append([x, "Day %d" % d])
	return { "points": pts, "labels": labels, "dividers": dividers }


func _record(time: float) -> void:
	times.append(time)
	for s in stocks:
		ticks[s["id"]].append(prices[s["id"]])
	if times.size() > TICKS_KEEP + 60:
		times = times.slice(times.size() - TICKS_KEEP)
		for s in stocks:
			var t: Array = ticks[s["id"]]
			ticks[s["id"]] = t.slice(t.size() - TICKS_KEEP)


func _say(day: int, text: String) -> void:
	if text == "":
		return
	news = text
	feed.push_front({ "day": day, "text": text })
	if feed.size() > FEED_LEN:
		feed.pop_back()


func _set_price(id: String, price: float) -> void:
	prices[id] = maxf(MIN_PRICE, snappedf(price, 0.01))
	high[id] = maxf(high[id], prices[id])
	low[id] = minf(low[id], prices[id])
	change[id] = prices[id] / open[id] - 1.0


## Plans where each stock ends the day. The move plays out through tick().
func _open_day(day: int, allow_events: bool) -> void:
	_day = day
	events.clear()
	_announced.clear()
	_finished.clear()
	for s in stocks:
		var id: String = s["id"]
		var st: Dictionary = STYLES[s["style"]]
		var vol := volatility(s)
		open[id] = prices[id]
		high[id] = prices[id]
		low[id] = prices[id]
		change[id] = 0.0
		_jitter[id] = 0.0
		var c: float
		if recovering.has(id):
			var r: Dictionary = recovering[id]
			c = r["per_day"] + rng.randf_range(-vol, vol) * 0.25
			r["days_left"] -= 1
			if r["days_left"] <= 0:
				_finished[id] = int(r["crash_day"])
				recovering.erase(id)
		else:
			c = rng.randf_range(-vol, vol) + st["drift"]
			if allow_events and rng.randf() < st["spike_chance"]:
				c = rng.randf_range(SPIKE_MIN, SPIKE_MAX)
				events[id] = "spike"
		target[id] = c
	if allow_events and rng.randf() < CRASH_CHANCE:
		var victim := _pick_crash_victim()
		if victim != "":
			var drop := rng.randf_range(CRASH_MIN, CRASH_MAX)
			var days := rng.randi_range(RECOVER_DAYS_MIN, RECOVER_DAYS_MAX)
			target[victim] = -drop
			recovering[victim] = {
				"days_left": days,
				"per_day": pow(1.0 / (1.0 - drop), 1.0 / days) - 1.0,
				"crash_day": day,
			}
			events[victim] = "crash"
			_finished.erase(victim)


func _close_day(day: int) -> void:
	for s in stocks:
		var id: String = s["id"]
		_set_price(id, open[id] * (1.0 + target[id]))
		var h: Array = history[id]
		h.append({ "day": day, "price": prices[id] })
		while h.size() > HISTORY_LEN - 1:
			h.pop_front()
	_record(day + 1.0)
	_say(day, _news_line(day))


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


func _news_line(day: int) -> String:
	for id in events:
		var n: String = stock(id)["name"]
		var verb := "crashed" if events[id] == "crash" else "spiked"
		return "%s %s %s on day %d" % [n, verb, UI.percent(change[id]), day]
	for id in _finished:
		return "%s dipped on day %d and climbed back by day %d" % [stock(id)["name"], _finished[id], day]
	var top := ""
	for s in stocks:
		if top == "" or absf(change[s["id"]]) > absf(change[top]):
			top = s["id"]
	if top == "":
		return ""
	var word := "rose" if change[top] >= 0 else "slipped"
	return "%s %s %s on day %d" % [stock(top)["name"], word, UI.percent(change[top]), day]


func to_dict() -> Dictionary:
	return { "prices": prices, "history": history, "recovering": recovering, "news": news, "feed": feed }


func from_dict(d: Dictionary, seed_value: int, day: int) -> void:
	rng.seed = seed_value + day * 7919
	for s in stocks:
		var id: String = s["id"]
		prices[id] = float(d.get("prices", {}).get(id, s["base_price"]))
		history[id] = d.get("history", {}).get(id, [])
	recovering = d.get("recovering", {})
	# Ticks are not saved. Rebuild a coarse line from the daily closes.
	times.clear()
	ticks.clear()
	for s in stocks:
		ticks[s["id"]] = []
	if not stocks.is_empty():
		var closes: Array = history[stocks[0]["id"]]
		for i in closes.size():
			times.append(float(closes[i]["day"]) + 1.0)
			for s in stocks:
				var h: Array = history[s["id"]]
				ticks[s["id"]].append(float(h[i]["price"]) if i < h.size() else prices[s["id"]])
	if times.is_empty() or times[-1] < float(day):
		_record(float(day))
	_open_day(day, true)
	news = str(d.get("news", ""))
	feed = d.get("feed", [])
	prices_changed.emit()
