# Plays a fake run without UI and prints the numbers.
# Run: godot --headless --path . res://tools/smoke_test.tscn
extends Node


func _ready() -> void:
	Game.new_run()
	print("day1 prices ", Market.prices)
	Game.buy_max("mchd")
	print("buy max mchd shares ", Game.shares("mchd"), " cash ", Game.cash)
	Game.sell_all("mchd")
	print("sell all mchd shares ", Game.shares("mchd"), " cash ", Game.cash)
	Game.buy("prblx", 10)
	print("after buy cash ", Game.cash, " nw ", Game.net_worth())
	for i in 5:
		Game.next_day()
		print("day ", Game.day, " cash ", Game.cash, " nw ", snappedf(Game.net_worth(), 0.01), " | ", Market.news)
	Game.sell("prblx", Game.shares("prblx"))
	Game.cash = 150.0
	Game.next_day()
	print("forced broke? ", Game.is_broke(), " cash ", Game.cash)
	Game.finish_hustle(14)
	print("payout ", Game.last_payout, " shares ", Game.last_payout_shares, " of ", Game.last_payout_ticker, " cash ", Game.cash, " bb ", Game.bounce_backs, " day ", Game.day)
	Game.end_run()
	print("final ", Game.final_net_worth, " lowest ", Game.lowest_net_worth, " on day ", Game.lowest_day)
	get_tree().quit()
