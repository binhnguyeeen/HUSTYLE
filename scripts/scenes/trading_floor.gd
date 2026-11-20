extends Control

const NEWS_ROWS := 4
## Chart views: label, kind, size. Ticks are half seconds.
const VIEWS := [["10s", "ticks", 20], ["20s", "ticks", 40], ["1D", "days", 1], ["5D", "days", 5], ["10D", "days", 10]]

var selected := ""
var buying := true
var qty := 5
var view := 3
var _news_sig := ""

var day_label: Label
var day_bar: ProgressBar
var cash_label: Label
var worth_label: Label
var market_list: VBoxContainer
var head_logo: Control
var head_holder: HBoxContainer
var head_name: Label
var head_ticker: Label
var head_price: Label
var head_pill_holder: Control
var chart: PriceChart
var news_list: VBoxContainer
var pos_rows := {}
var profit_holder: HBoxContainer
var buy_tab: Button
var sell_tab: Button
var qty_label: Label
var less_btn: StepButton
var more_btn: StepButton
var action_btn: Button
var all_btn: Button
var fee_label: Label
var stat_labels := {}
var cash_after: Label
var holdings_list: VBoxContainer
var overlay: Control


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if not Game.running:
		Game.new_run()
	if not Market.stocks.is_empty():
		selected = Market.stocks[0]["id"]
	_build()
	Game.changed.connect(_refresh)
	Market.prices_changed.connect(_refresh)
	Game.went_broke.connect(_show_broke)
	Game.run_ended.connect(func(): get_tree().change_scene_to_file("res://scenes/results.tscn"))
	_refresh()
	if Game.show_payout:
		_show_payout()
	elif Game.is_broke():
		Game.paused = true
		_show_broke()


func _process(_delta: float) -> void:
	if day_bar:
		day_bar.value = 1.0 - Game.day_time_left / Game.DAY_SECONDS


# Layout

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = C.BG_BASE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := UI.box(true)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	root.add_child(_top_bar())
	root.add_child(UI.line(false))
	root.add_child(TickerTape.new())
	root.add_child(UI.line(false))
	var body := UI.box(false)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	body.add_child(_market_panel())
	body.add_child(UI.line(true))
	body.add_child(_stock_panel())
	body.add_child(UI.line(true))
	body.add_child(_wallet_panel())


func _top_bar() -> Control:
	var p := UI.panel(C.BG_PANEL)
	p.custom_minimum_size = Vector2(0, C.TOP_BAR)
	var h := UI.box(false, 12)
	h.alignment = BoxContainer.ALIGNMENT_BEGIN
	p.add_child(UI.margin(h, 20, 0, 20, 0))
	var brand := UI.box(false, 10)
	var logo := UI.logo("res://assets/logos/hustyle.png", 40)
	logo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	brand.add_child(logo)
	var word := UI.label("HUSTYLE", 20, UI.W.BOLD, C.ACCENT)
	word.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	brand.add_child(word)
	h.add_child(brand)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(16, 0)
	h.add_child(gap)
	var day_box := UI.box(true, 6)
	day_box.alignment = BoxContainer.ALIGNMENT_CENTER
	day_label = UI.label("", 14, UI.W.SEMI)
	day_box.add_child(day_label)
	day_bar = ProgressBar.new()
	day_bar.max_value = 1.0
	day_bar.show_percentage = false
	day_bar.custom_minimum_size = Vector2(160, 4)
	day_box.add_child(day_bar)
	h.add_child(day_box)
	h.add_child(UI.spacer())
	var cash_box := _stat("Cash", C.TEXT)
	cash_label = cash_box.get_child(1)
	h.add_child(cash_box)
	var worth_box := _stat("Net worth", C.ACCENT)
	worth_label = worth_box.get_child(1)
	h.add_child(worth_box)
	var gap2 := Control.new()
	gap2.custom_minimum_size = Vector2(8, 0)
	h.add_child(gap2)
	var next := UI.button("Next Day", true)
	next.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	next.pressed.connect(Game.next_day)
	h.add_child(next)
	var out := UI.button("Cash Out")
	out.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	out.pressed.connect(Game.end_run)
	h.add_child(out)
	return p


func _stat(title: String, color: Color) -> VBoxContainer:
	var v := UI.box(true, 0)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.custom_minimum_size = Vector2(96, 0)
	var t := UI.label(title, 12, UI.W.REGULAR, C.TEXT2)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(t)
	var val := UI.label("", 16, UI.W.SEMI, color)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(val)
	return v


func _market_panel() -> Control:
	var p := UI.panel(C.BG_PANEL)
	p.custom_minimum_size = Vector2(C.MARKET_W, 0)
	var v := UI.box(true, 12)
	p.add_child(UI.margin(v, 16, 16, 16, 16))
	var t := UI.label("Market", 12, UI.W.SEMI, C.TEXT2)
	v.add_child(UI.margin(t, 4, 0, 0, 0))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	market_list = UI.box(true, 4)
	market_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(market_list)
	return p


func _stock_panel() -> Control:
	var v := UI.box(true, 16)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var m := UI.margin(v, 24, 24, 24, 24)
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var head := UI.box(false, 16)
	head_holder = UI.box(false)
	head.add_child(head_holder)
	var names := UI.box(true, 0)
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_name = UI.label("", 20, UI.W.SEMI)
	head_name.clip_text = true
	head_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head_ticker = UI.label("", 14, UI.W.REGULAR, C.TEXT2)
	names.add_child(head_name)
	names.add_child(head_ticker)
	head.add_child(names)
	head_price = UI.label("", 40, UI.W.BOLD)
	head.add_child(head_price)
	head_pill_holder = UI.box(false)
	head_pill_holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(head_pill_holder)
	v.add_child(head)
	var stats := UI.box(false, 24)
	for key in ["Open", "High", "Low"]:
		var sb := UI.box(false, 8)
		sb.add_child(UI.label(key, 12, UI.W.REGULAR, C.TEXT2))
		var sv := UI.label("", 12, UI.W.SEMI)
		stat_labels[key] = sv
		sb.add_child(sv)
		stats.add_child(sb)
	stats.add_child(UI.spacer())
	var views := UI.box(false, 2)
	var vg := ButtonGroup.new()
	for i in VIEWS.size():
		views.add_child(_view_tab(VIEWS[i][0], vg, i))
	stats.add_child(views)
	v.add_child(stats)
	chart = PriceChart.new()
	chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(chart)
	var news := UI.panel(C.BG_PANEL, C.RADIUS_CONTROL)
	var nv := UI.box(true, 8)
	var nh := UI.box(false)
	nh.add_child(UI.label("News", 12, UI.W.SEMI, C.TEXT2))
	nh.add_child(UI.spacer())
	nh.add_child(UI.label("Rent %s a day" % UI.money(Game.RENT), 12, UI.W.REGULAR, C.MUTED))
	nv.add_child(nh)
	news_list = UI.box(true, 4)
	news_list.custom_minimum_size = Vector2(0, NEWS_ROWS * 20 - 4)
	nv.add_child(news_list)
	news.add_child(UI.margin(nv, 16, 10, 16, 12))
	v.add_child(news)
	return m


func _wallet_panel() -> Control:
	var p := UI.panel(C.BG_PANEL)
	p.custom_minimum_size = Vector2(C.WALLET_W, 0)
	var v := UI.box(true, 12)
	p.add_child(UI.margin(v, 16, 16, 16, 16))
	v.add_child(UI.label("Your position", 12, UI.W.SEMI, C.TEXT2))
	var card := UI.panel(C.BG_RAISED, C.RADIUS_CARD, 12)
	var rows := UI.box(true, 6)
	card.add_child(rows)
	for key in ["Shares", "Average cost", "Value", "Profit"]:
		var r := UI.box(false)
		r.add_child(UI.label(key, 14, UI.W.REGULAR, C.TEXT2))
		r.add_child(UI.spacer())
		if key == "Profit":
			profit_holder = UI.box(false)
			r.add_child(profit_holder)
		else:
			var val := UI.label("", 14, UI.W.SEMI)
			pos_rows[key] = val
			r.add_child(val)
		rows.add_child(r)
	v.add_child(card)

	var trade := UI.panel(C.BG_RAISED, C.RADIUS_CARD, 12)
	var tv := UI.box(true, 12)
	trade.add_child(tv)
	var tabs_bg := UI.panel(C.BG_BASE, C.RADIUS_CONTROL, 4)
	var tabs := UI.box(false, 4)
	tabs_bg.add_child(tabs)
	var group := ButtonGroup.new()
	buy_tab = _tab("Buy", group, true)
	sell_tab = _tab("Sell", group, false)
	tabs.add_child(buy_tab)
	tabs.add_child(sell_tab)
	tv.add_child(tabs_bg)
	var qrow := UI.box(false, 8)
	var ql := UI.label("Shares", 14, UI.W.REGULAR, C.TEXT2)
	ql.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	qrow.add_child(ql)
	qrow.add_child(UI.spacer())
	less_btn = StepButton.new(false)
	less_btn.pressed.connect(func(): _set_qty(qty - 1))
	qrow.add_child(less_btn)
	qty_label = UI.label("", 16, UI.W.SEMI)
	qty_label.custom_minimum_size = Vector2(40, 0)
	qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qty_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	qrow.add_child(qty_label)
	more_btn = StepButton.new(true)
	more_btn.pressed.connect(func(): _set_qty(qty + 1))
	qrow.add_child(more_btn)
	tv.add_child(qrow)
	action_btn = UI.button("", true, 36)
	action_btn.pressed.connect(_trade)
	tv.add_child(action_btn)
	all_btn = UI.button("", false, 36)
	all_btn.pressed.connect(_trade_all)
	var fee_row := UI.box(false)
	fee_label = UI.label("", 12, UI.W.REGULAR, C.TEXT2)
	fee_row.add_child(fee_label)
	fee_row.add_child(UI.spacer())
	cash_after = UI.label("", 12, UI.W.REGULAR, C.TEXT2)
	fee_row.add_child(cash_after)
	tv.add_child(fee_row)
	tv.add_child(all_btn)
	v.add_child(trade)

	var hl := UI.label("Holdings", 12, UI.W.SEMI, C.TEXT2)
	v.add_child(UI.margin(hl, 0, 8, 0, 0))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	holdings_list = UI.box(true, 14)
	holdings_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(holdings_list)
	v.add_child(scroll)
	return p


func _view_tab(text: String, group: ButtonGroup, index: int) -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = &"TabButton"
	b.toggle_mode = true
	b.button_group = group
	b.button_pressed = index == view
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size", 12)
	for st in ["normal", "hover"]:
		b.add_theme_stylebox_override(st, _small_box(Color(0, 0, 0, 0)))
	for st in ["pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(st, _small_box(C.BG_RAISED))
	b.pressed.connect(func():
		view = index
		_refresh_stock())
	return b


func _small_box(bg: Color) -> StyleBoxFlat:
	var sb := UI.style(bg, 6)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	return sb


func _tab(text: String, group: ButtonGroup, on: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = &"TabButton"
	b.toggle_mode = true
	b.button_group = group
	b.button_pressed = on
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 32)
	b.pressed.connect(func():
		buying = on
		_refresh())
	return b


# Updates

func _refresh() -> void:
	day_label.text = "Day %d of %d" % [Game.day, Game.DAYS]
	cash_label.text = UI.money(Game.cash)
	worth_label.text = UI.money(Game.net_worth())
	_refresh_market()
	_refresh_stock()
	_refresh_wallet()
	_refresh_news()


func _refresh_news() -> void:
	# Rebuild only when a new headline arrives, so the box stays still.
	var sig := str(Market.feed.slice(0, NEWS_ROWS))
	if sig == _news_sig:
		return
	_news_sig = sig
	UI.clear(news_list)
	for i in mini(NEWS_ROWS, Market.feed.size()):
		var e: Dictionary = Market.feed[i]
		var row := UI.box(false, 12)
		row.custom_minimum_size = Vector2(0, 16)
		var d := UI.label("Day %d" % int(e["day"]), 12, UI.W.REGULAR, C.ACCENT if i == 0 else C.MUTED)
		d.custom_minimum_size = Vector2(44, 0)
		row.add_child(d)
		var t := UI.label(str(e["text"]), 12, UI.W.SEMI if i == 0 else UI.W.REGULAR, C.TEXT if i == 0 else C.TEXT2)
		t.clip_text = true
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(t)
		news_list.add_child(row)


func _refresh_market() -> void:
	UI.clear(market_list)
	for s in Market.stocks:
		market_list.add_child(_market_row(s))


func _market_row(s: Dictionary) -> Control:
	var id: String = s["id"]
	var on := id == selected
	var p := UI.panel(C.BG_RAISED if on else Color(0, 0, 0, 0), C.RADIUS_CONTROL, 0)
	p.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var h := UI.box(false, 12)
	p.add_child(UI.margin(h, 12, 10, 12, 10))
	var logo := UI.logo(s["logo"], 32, 48, 0, s.get("light_tile", false))
	logo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(logo)
	var names := UI.box(true, 0)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nl := UI.label(s["name"], 14, UI.W.SEMI)
	nl.clip_text = true
	nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	names.add_child(nl)
	names.add_child(UI.label(s["ticker"], 12, UI.W.REGULAR, C.TEXT2))
	h.add_child(names)
	var right := UI.box(true, 2)
	var price := UI.label(UI.money(Market.prices[id]), 14, UI.W.SEMI)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(price)
	right.add_child(UI.pill(Market.change.get(id, 0.0)))
	h.add_child(right)
	for c in [h, logo, names, right]:
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	p.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			selected = id
			_refresh())
	return p


func _refresh_stock() -> void:
	var s := Market.stock(selected)
	if s.is_empty():
		return
	UI.clear(head_holder)
	head_holder.add_child(UI.logo(s["logo"], 56, 0, 110, s.get("light_tile", false)))
	head_name.text = s["name"]
	head_ticker.text = s["ticker"]
	head_price.text = UI.money(Market.prices[selected])
	UI.clear(head_pill_holder)
	head_pill_holder.add_child(UI.pill(Market.change.get(selected, 0.0)))
	stat_labels["Open"].text = UI.money(Market.open[selected])
	stat_labels["High"].text = UI.money(Market.high[selected])
	stat_labels["Low"].text = UI.money(Market.low[selected])
	chart.set_view(Market.view(selected, VIEWS[view][1], VIEWS[view][2], Game.day))


func _refresh_wallet() -> void:
	var price: float = Market.prices.get(selected, 0.0)
	var n := Game.shares(selected)
	pos_rows["Shares"].text = str(n)
	pos_rows["Average cost"].text = UI.money(Game.avg_cost(selected)) if n > 0 else UI.money(0)
	pos_rows["Value"].text = UI.money(n * price)
	UI.clear(profit_holder)
	var profit := (price - Game.avg_cost(selected)) * n
	if n > 0:
		profit_holder.add_child(UI.change(profit, UI.money(profit), 14))
	else:
		profit_holder.add_child(UI.label(UI.money(0), 14, UI.W.SEMI))

	if not buying:
		qty = clampi(qty, 1, maxi(1, n))
	qty = maxi(1, qty)
	qty_label.text = str(qty)
	less_btn.disabled = qty <= 1
	more_btn.disabled = (not buying and qty >= n)
	less_btn.queue_redraw()
	more_btn.queue_redraw()
	if buying:
		var cost := Game.buy_cost(selected, qty)
		action_btn.text = "Buy %d for %s" % [qty, UI.money(cost)]
		action_btn.disabled = not Game.can_buy(selected, qty)
		fee_label.text = "Fee %s" % UI.money(Game.buy_fee(selected, qty))
		cash_after.text = "Cash after %s" % UI.money(maxf(0.0, Game.cash - cost))
		all_btn.text = "Buy max"
		all_btn.disabled = Game.max_buy(selected) < 1
	else:
		var got := Game.sell_proceeds(selected, qty) if n >= qty else 0.0
		action_btn.text = "Sell %d for %s" % [qty, UI.money(got)]
		action_btn.disabled = not Game.can_sell(selected, qty)
		fee_label.text = "Tax %s" % UI.money(Game.sell_tax(selected, qty) if n >= qty else 0.0)
		cash_after.text = "Cash after %s" % UI.money(Game.cash + got)
		all_btn.text = "Sell all"
		all_btn.disabled = n < 1

	UI.clear(holdings_list)
	var ids := Game.holdings.keys()
	ids.sort_custom(func(a, b): return Game.shares(a) * Market.prices[a] > Game.shares(b) * Market.prices[b])
	for id in ids:
		var s := Market.stock(id)
		var h := UI.box(false)
		var left := UI.box(true, 0)
		left.add_child(UI.label(s["ticker"], 14, UI.W.SEMI))
		var c := Game.shares(id)
		left.add_child(UI.label("%d %s" % [c, "share" if c == 1 else "shares"], 12, UI.W.REGULAR, C.TEXT2))
		h.add_child(left)
		h.add_child(UI.spacer())
		var right := UI.box(true, 0)
		var val := UI.label(UI.money(c * Market.prices[id]), 14, UI.W.SEMI)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		right.add_child(val)
		var pr: float = (Market.prices[id] - Game.avg_cost(id)) * c
		right.add_child(UI.change(pr, UI.money(pr)))
		h.add_child(right)
		holdings_list.add_child(h)


func _set_qty(v: int) -> void:
	qty = maxi(1, v)
	_refresh_wallet()


func _trade() -> void:
	if buying:
		Game.buy(selected, qty)
	else:
		Game.sell(selected, qty)


func _trade_all() -> void:
	if buying:
		Game.buy_max(selected)
	else:
		Game.sell_all(selected)


# Overlays

func _show_broke() -> void:
	_open_overlay(Modal.make("You're broke", "No cash and no shares. Time to bounce back.", "Start a side hustle",
		func(): get_tree().change_scene_to_file(Game.HUSTLES.pick_random())))


func _show_payout() -> void:
	Game.paused = true
	var body := "Enough for %d %s of %s" % [Game.last_payout_shares, "share" if Game.last_payout_shares == 1 else "shares", Game.last_payout_ticker]
	_open_overlay(Modal.make("You earned %s" % UI.money(Game.last_payout), body, "Back to the market",
		func():
			overlay.queue_free()
			overlay = null
			Game.close_payout()))


func _open_overlay(o: Control) -> void:
	if overlay:
		overlay.queue_free()
	overlay = o
	add_child(o)
