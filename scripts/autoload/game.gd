extends Node
## Run state and rules. UI reads from here and calls these functions.

signal changed
signal went_broke
signal run_ended

const CURRENCY := "$"
const START_CASH := 2000.0
const DAYS := 30
const DAY_SECONDS := 30.0
## How often prices move inside a day.
const TICK_SECONDS := 0.5

## Broker fee on every buy, as a share of the order.
const BUY_FEE := 0.01
## Tax on every sale, as a share of the sale amount.
const SELL_TAX := 0.05
## Extra tax on the profit of a sale. Off for now. Losses are never taxed.
const PROFIT_TAX := 0.0

## Rent taken from cash at the start of each new day.
## If cash is short, shares are sold to cover it.
const RENT := 200.0
## Days without rent after a payout, counting the hustle day.
const RENT_FREE_AFTER_PAYOUT := 3

## Side hustle: keep the coin up for HUSTLE_SECONDS. A drop restarts the clock.
## The round ends early after MAX_DROPS drops.
const HUSTLE_SECONDS := 15.0
const MAX_DROPS := 5
## Payout by drops: at most this many drops pays this much, in dollars.
const PAYOUT_TIERS := [[0, 500.0], [2, 350.0], [MAX_DROPS, 200.0]]
const PAYOUT_CAP := 0.3  # cash after payout is at most this share of START_CASH

## Block Breaker side hustle: $ blocks pay, clearing the board pays a bonus.
const BREAKER_SECONDS := 45.0
const BREAKER_LIVES := 3
const BREAKER_CASH_BLOCK := 40.0
const BREAKER_CLEAR_BONUS := 150.0
## Paid even with no $ blocks, so a bad round still gets you back in.
const BREAKER_MIN := 100.0
## Going broke opens one of these at random.
const HUSTLES := ["res://scenes/side_hustle.tscn", "res://scenes/block_breaker.tscn"]

var running := false
var paused := false
var seed_value := 0
var day := 1
var day_time_left := DAY_SECONDS
var cash := START_CASH
var holdings := {}  # id -> { "shares": int, "avg_cost": float }
var bounce_backs := 0
var lowest_net_worth := START_CASH
var lowest_day := 1
var rent_free_days := 0
var last_payout := 0.0
var last_payout_shares := 0
var last_payout_ticker := ""
var show_payout := false
var final_net_worth := 0.0
var _tick_wait := 0.0


func _process(delta: float) -> void:
	if not running or paused:
		return
	day_time_left -= delta
	if day_time_left <= 0.0:
		next_day()
		return
	_tick_wait += delta
	if _tick_wait >= TICK_SECONDS:
		_tick_wait = 0.0
		Market.tick(1.0 - day_time_left / DAY_SECONDS)
		_track_lowest()


func new_run() -> void:
	seed_value = randi()
	Market.new_run(seed_value)
	day = 1
	day_time_left = DAY_SECONDS
	cash = START_CASH
	holdings.clear()
	bounce_backs = 0
	lowest_net_worth = START_CASH
	lowest_day = 1
	rent_free_days = 0
	show_payout = false
	running = true
	paused = false
	Save.write()
	changed.emit()


func shares(id: String) -> int:
	return holdings.get(id, {}).get("shares", 0)


func avg_cost(id: String) -> float:
	return holdings.get(id, {}).get("avg_cost", 0.0)


func holdings_value() -> float:
	var v := 0.0
	for id in holdings:
		v += shares(id) * float(Market.prices.get(id, 0.0))
	return v


func net_worth() -> float:
	return cash + holdings_value()


func buy_fee(id: String, qty: int) -> float:
	return snappedf(Market.prices[id] * qty * BUY_FEE, 0.01)


## What a buy takes from cash, fee included.
func buy_cost(id: String, qty: int) -> float:
	return snappedf(Market.prices[id] * qty, 0.01) + buy_fee(id, qty)


func sell_tax(id: String, qty: int) -> float:
	var sale: float = Market.prices[id] * qty
	var profit := maxf(0.0, (Market.prices[id] - avg_cost(id)) * qty)
	return snappedf(sale * SELL_TAX + profit * PROFIT_TAX, 0.01)


## What a sale adds to cash, after tax.
func sell_proceeds(id: String, qty: int) -> float:
	return snappedf(Market.prices[id] * qty, 0.01) - sell_tax(id, qty)


func can_buy(id: String, qty: int) -> bool:
	return qty > 0 and buy_cost(id, qty) <= cash + 0.0001


func can_sell(id: String, qty: int) -> bool:
	return qty > 0 and qty <= shares(id)


func max_buy(id: String) -> int:
	var price: float = Market.prices.get(id, 0.0)
	if price <= 0.0:
		return 0
	var n := int(floor((cash + 0.0001) / (price * (1.0 + BUY_FEE))))
	while n > 0 and not can_buy(id, n):
		n -= 1
	return n


func buy_max(id: String) -> void:
	buy(id, max_buy(id))


func sell_all(id: String) -> void:
	sell(id, shares(id))


func buy(id: String, qty: int) -> void:
	if not can_buy(id, qty):
		return
	var price: float = Market.prices[id]
	var have := shares(id)
	var total_cost := avg_cost(id) * have + price * qty
	var cost := buy_cost(id, qty)
	holdings[id] = { "shares": have + qty, "avg_cost": total_cost / (have + qty) }
	cash = snappedf(maxf(0.0, cash - cost), 0.01)
	_after_change()


func sell(id: String, qty: int) -> void:
	if not can_sell(id, qty):
		return
	cash = snappedf(cash + sell_proceeds(id, qty), 0.01)
	var left := shares(id) - qty
	if left <= 0:
		holdings.erase(id)
	else:
		holdings[id]["shares"] = left
	_after_change()


func next_day() -> void:
	if not running:
		return
	if day >= DAYS:
		end_run()
		return
	day += 1
	day_time_left = DAY_SECONDS
	Market.advance_day(day)
	_pay_rent()
	_after_change()
	if is_broke():
		paused = true
		went_broke.emit()


func end_run() -> void:
	running = false
	paused = false
	final_net_worth = net_worth()
	_track_lowest()
	Save.write()
	run_ended.emit()


func is_broke() -> bool:
	var c := Market.cheapest()
	if c.is_empty():
		return false
	return holdings.is_empty() and cash < Market.prices[c["id"]]


## Called when the coin bounce side hustle ends.
func finish_hustle(drops: int) -> void:
	var pay := 0.0
	for tier in PAYOUT_TIERS:
		if drops <= tier[0]:
			pay = tier[1]
			break
	_payout(pay)


## Called when Block Breaker ends, with what the $ blocks and bonus earned.
func finish_breaker(earned: float) -> void:
	_payout(maxf(earned, BREAKER_MIN))


func _payout(pay: float) -> void:
	var c := Market.cheapest()
	var price: float = Market.prices[c["id"]]
	pay = minf(pay, maxf(0.0, START_CASH * PAYOUT_CAP - cash))
	pay = snappedf(pay, 0.01)
	cash = snappedf(cash + pay, 0.01)
	bounce_backs += 1
	last_payout = pay
	last_payout_ticker = c["ticker"]
	last_payout_shares = int(floor(pay / price + 0.0001))
	rent_free_days = RENT_FREE_AFTER_PAYOUT
	show_payout = true
	# The hustle uses up one market day.
	if day >= DAYS:
		end_run()
		return
	day += 1
	day_time_left = DAY_SECONDS
	Market.advance_day(day)
	_pay_rent()
	_after_change()


func close_payout() -> void:
	show_payout = false
	paused = false
	changed.emit()


func _pay_rent() -> void:
	if rent_free_days > 0:
		rent_free_days -= 1
		return
	var due := RENT
	if cash < due:
		# Sell the biggest holdings first until rent is covered.
		var ids := holdings.keys()
		ids.sort_custom(func(a, b): return shares(a) * Market.prices[a] > shares(b) * Market.prices[b])
		for id in ids:
			while cash < due and shares(id) > 0:
				cash += Market.prices[id]
				var left := shares(id) - 1
				if left <= 0:
					holdings.erase(id)
				else:
					holdings[id]["shares"] = left
	cash = snappedf(maxf(0.0, cash - due), 0.01)


func _after_change() -> void:
	_track_lowest()
	Save.write()
	changed.emit()


func _track_lowest() -> void:
	var nw := net_worth()
	if nw < lowest_net_worth:
		lowest_net_worth = nw
		lowest_day = day


func to_dict() -> Dictionary:
	return {
		"day": day,
		"cash": cash,
		"holdings": holdings,
		"seed": seed_value,
		"bounce_backs": bounce_backs,
		"lowest_net_worth": lowest_net_worth,
		"lowest_day": lowest_day,
		"rent_free_days": rent_free_days,
		"running": running,
	}


func from_dict(d: Dictionary) -> void:
	day = int(d.get("day", 1))
	cash = float(d.get("cash", START_CASH))
	holdings = {}
	var h: Dictionary = d.get("holdings", {})
	for id in h:
		if not Market.stock(id).is_empty():
			holdings[id] = { "shares": int(h[id]["shares"]), "avg_cost": float(h[id]["avg_cost"]) }
	seed_value = int(d.get("seed", 0))
	bounce_backs = int(d.get("bounce_backs", 0))
	lowest_net_worth = float(d.get("lowest_net_worth", START_CASH))
	lowest_day = int(d.get("lowest_day", 1))
	rent_free_days = int(d.get("rent_free_days", 0))
	day_time_left = DAY_SECONDS
	show_payout = false
	paused = false
	running = true
	changed.emit()
