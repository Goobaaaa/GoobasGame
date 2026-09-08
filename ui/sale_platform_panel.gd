class_name SalePlatformPanel
extends VBoxContainer
const Rarity = preload("res://inventory/item_rarity.gd")
var platform_id := ""
var entry: Dictionary = {}
var summary: Label
var carried: VBoxContainer
var listed: VBoxContainer

func _ready() -> void:
	summary = Label.new()
	add_child(summary)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation",20)
	add_child(columns)
	carried = _column(columns,"BACKPACK → DISPLAY")
	listed = _column(columns,"FOR SALE → PRICES / RETURN")
	refresh()

func _column(parent: Control, title: String) -> VBoxContainer:
	var section := VBoxContainer.new()
	section.custom_minimum_size.x = 480
	parent.add_child(section)
	var heading := Label.new()
	heading.text = title
	heading.add_theme_font_size_override("font_size",17)
	section.add_child(heading)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(480,380)
	section.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation",12)
	scroll.add_child(list)
	return list

func refresh() -> void:
	if summary == null: return
	entry = {}
	for furniture in Session.state.furniture:
		if SaleStock.key(furniture) == platform_id: entry = furniture
	for column in [carried,listed]:
		for child in column.get_children():
			column.remove_child(child)
			child.queue_free()
	if entry.is_empty():
		summary.text = "This platform is no longer available."
		return
	var listings: Array = Session.state.get("sale_stock",{}).get(platform_id,[])
	var config := SaleStock.definition(entry)
	summary.text = "%d / %d display cells used · %d tier(s) · Each unit occupies its own footprint" % [SaleStock.used(listings),SaleStock.capacity(entry),config.heights.size()]
	for item in Session.inventory_for(Session.local_id()).data.items: _stock_row(item)
	for listing in listings: _listing_row(listing)
	if carried.get_child_count() == 0: _label(carried,"Your backpack is empty.")
	if listed.get_child_count() == 0: _label(listed,"Nothing for sale. Stock an item from your backpack.")

func _label(parent: Control, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size",14)
	parent.add_child(label)
	return label

func _spin(parent: Control, maximum: int, initial: int) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = 1
	spin.max_value = maximum
	spin.value = initial
	spin.custom_minimum_size.x = 95
	parent.add_child(spin)
	return spin

func _button(parent: Control, title: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.add_theme_font_size_override("font_size",14)
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func command(action: String, args: Dictionary) -> void:
	Session.request_action("sale_platform",{"platform":platform_id,"action":action,"args":args})

func _stock_row(item: Dictionary) -> void:
	var group := VBoxContainer.new()
	carried.add_child(group)
	var d := ItemRegistry.get_item(item.id)
	var footprint := SaleStock.item_size(item.id)
	var label := _label(group,"%s ×%d · %d×%d cells per unit" % [d.display_name,item.quantity,footprint.x,footprint.y])
	label.add_theme_color_override("font_color",Rarity.color_for(ItemInstance.rarity(item)))
	label.tooltip_text = ItemTooltip.describe(item)
	var row := HBoxContainer.new()
	group.add_child(row)
	_label(row,"Qty")
	var count := _spin(row,item.quantity,1)
	_label(row,"Sell/unit")
	var price := _spin(row,1000000,maxi(1,int(ceil(SaleStock.buy_price(item.id)*1.5))))
	_button(row,"Stock",func(): command("stock",{"uid":item.uid,"quantity":int(count.value),"price":int(price.value)}))
	var economics := _label(group,"")
	var update := func(_n = 0): _economics(economics,item.id,int(price.value),int(count.value))
	price.value_changed.connect(update)
	count.value_changed.connect(update)
	update.call()

func _listing_row(listing: Dictionary) -> void:
	var group := VBoxContainer.new()
	listed.add_child(group)
	var item: Dictionary = listing.item
	var title := _label(group,"FOR SALE · %s ×%d · %dg each" % [ItemRegistry.get_item(item.id).display_name,item.quantity,listing.price])
	title.add_theme_color_override("font_color",Rarity.color_for(ItemInstance.rarity(item)))
	var row := HBoxContainer.new()
	group.add_child(row)
	var price := _spin(row,1000000,int(listing.price))
	_button(row,"Set price",func(): command("price",{"uid":item.uid,"price":int(price.value)}))
	_button(row,"Return all",func(): command("remove",{"uid":item.uid}))
	var economics := _label(group,"")
	var update := func(_n = 0): _economics(economics,item.id,int(price.value),int(item.quantity))
	price.value_changed.connect(update)
	update.call()

func _economics(label: Label, id: String, sell: int, quantity: int) -> void:
	var buy := SaleStock.buy_price(id)
	label.text = "Buy ref: %dg · Sell: %dg · Est. profit: %dg/unit (%dg total)" % [buy,sell,sell-buy,(sell-buy)*quantity]
	label.add_theme_color_override("font_color",Color("e69b8a") if sell < buy else Color("a3d9ae"))
