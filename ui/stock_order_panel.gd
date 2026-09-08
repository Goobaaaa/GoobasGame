class_name StockOrderPanel
extends VBoxContainer
const StockCard = preload("res://ui/stock_item_card.gd")
## Visual Pip catalogue. Each card owns its quantity controls and calls back to
## this panel; the authoritative order and save transaction remain in Session.
var quantities: Dictionary = {}
var labels: Dictionary = {}
var cards: Dictionary = {}
var total_label: Label
var arrivals: Label
var checkout: Button
var grid: GridContainer

func _ready() -> void:
	add_theme_constant_override("separation",8)
	total_label = Label.new()
	total_label.text = "Choose a quantity on a card. BUY adds now; selected delivery orders arrive beneath Pip in 5 minutes."
	total_label.add_theme_color_override("font_color",Color("c6d0cc"))
	add_child(total_label)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1000,430)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	grid = GridContainer.new()
	grid.name = "StockGrid"
	grid.add_theme_constant_override("h_separation",10)
	grid.add_theme_constant_override("v_separation",10)
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	for id in Catalog.PRODUCTS:
		var card := StockCard.new()
		card.setup(id)
		card.quantity_changed.connect(_quantity_changed)
		card.buy_requested.connect(_buy)
		grid.add_child(card)
		cards[id] = card
		quantities[id] = card.quantity_input
		labels[id] = card.name_label
	checkout = Button.new()
	checkout.text = "PLACE DELIVERY ORDER"
	checkout.pressed.connect(_checkout)
	add_child(checkout)
	arrivals = Label.new()
	arrivals.add_theme_font_size_override("font_size",14)
	arrivals.add_theme_color_override("font_color",Color("c6d0cc"))
	add_child(arrivals)
	# Kept as a compatibility handle for callers that submit a multi-item basket;
	# individual cards still keep the common one-item path next to their icon.
	_responsive_columns()
	refresh()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED: _responsive_columns()

func _responsive_columns() -> void:
	if grid == null: return
	var width := maxf(size.x,640.0)
	grid.columns = clampi(int(floor(width / 225.0)),1,4)

func _quantity_changed(_id: String, _quantity: int) -> void:
	_refresh_total()

func _buy(id: String, quantity: int) -> void:
	if quantity < 1:
		Session.message.emit("Choose at least one item to buy.")
		return
	var total := DeliveryOrders.quote({id:quantity})
	if total < 0:
		Session.message.emit("Choose a valid quantity from 1 to 99.")
		return
	if total > int(Session.state.money):
		Session.message.emit("Not enough gold.")
		return
	# The per-card Buy action is immediate. Keep the preflight here so the UI can
	# give a fast local response before the authoritative transaction.
	var inventory := Session.inventory_for(Session.local_id())
	if not inventory.add_item(id,quantity):
		Session.message.emit("Not enough inventory space.")
		return
	var previous_gold := int(Session.state.money)
	Session.request_action("buy_item",{"id":id,"quantity":quantity})
	if int(Session.state.money) < previous_gold:
		cards[id].set_quantity(0)

func _checkout() -> void:
	var selected := basket()
	var total := DeliveryOrders.quote(selected)
	if total < 0 or total > int(Session.state.money): return
	var previous_gold := int(Session.state.money)
	Session.request_action("order",{"items":selected})
	if int(Session.state.money) < previous_gold:
		for id in quantities: quantities[id].value = 0

func basket() -> Dictionary:
	var result := {}
	for id in quantities:
		var count := int(quantities[id].value)
		if count > 0: result[id] = count
	return result

func refresh() -> void:
	if total_label == null: return
	for card in cards.values(): card.set_available_gold(int(Session.state.money))
	_refresh_total()
	var pending := 0
	var ready := 0
	var next := INF
	for order in Session.state.get("deliveries",[]):
		var left := float(order.due_at) - Time.get_unix_time_from_system()
		if left <= 0: ready += 1
		else:
			pending += 1
			next = minf(next,left)
	arrivals.text = "%d ready · %d on the way" % [ready,pending]
	if pending > 0: arrivals.text += " · Next: %d:%02d" % [int(ceil(next))/60,int(ceil(next))%60]

func _refresh_total() -> void:
	if total_label == null: return
	var total := DeliveryOrders.quote(basket())
	total_label.text = "Selected total: %d gold · Available: %d" % [maxi(total,0),Session.state.money]
	if total > Session.state.money: total_label.add_theme_color_override("font_color",Color("f08a83"))
	else: total_label.add_theme_color_override("font_color",Color("c6d0cc"))
	if checkout != null: checkout.disabled = total <= 0 or total > int(Session.state.money)
