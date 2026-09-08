class_name StockItemCard
extends PanelContainer
const Rarity = preload("res://inventory/item_rarity.gd")
## One reusable Pip purchase card. It owns only presentation/input; the panel
## and Session remain responsible for stock and economy transactions.
signal quantity_changed(id: String, quantity: int)
signal buy_requested(id: String, quantity: int)

var item_id := ""
var quantity_input: SpinBox
var total_label: Label
var name_label: Label
var price_label: Label
var buy_button: Button
var available_gold := 0
var base_item: Dictionary = {}

func setup(id: String) -> void:
	item_id = id
	var definition := ItemRegistry.get_item(id)
	base_item = ItemInstance.create(id, 1)
	base_item.buy_price = int(Catalog.PRODUCTS[id].price)
	base_item.properties = {}
	var rarity_color := Rarity.color_for(ItemInstance.rarity(base_item))
	var style := StyleBoxFlat.new()
	style.bg_color = Color("202d30")
	style.border_color = rarity_color.darkened(0.25)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	add_theme_stylebox_override("panel",style)
	custom_minimum_size = Vector2(205,265)
	tooltip_text = "Item"

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",6)
	add_child(column)
	var icon_panel := PanelContainer.new()
	icon_panel.custom_minimum_size = Vector2(0,92)
	icon_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_style := StyleBoxFlat.new()
	icon_style.bg_color = rarity_color.darkened(0.72)
	icon_style.border_color = rarity_color
	icon_style.set_border_width_all(1)
	icon_panel.add_theme_stylebox_override("panel",icon_style)
	column.add_child(icon_panel)
	if definition.icon:
		var icon := TextureRect.new()
		icon.texture = definition.icon
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(90,90)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_panel.add_child(icon)
	else:
		var fallback := Label.new()
		fallback.text = definition.category.substr(0,2).to_upper()
		fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		fallback.add_theme_font_size_override("font_size",28)
		fallback.add_theme_color_override("font_color",rarity_color)
		fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_panel.add_child(fallback)
	name_label = Label.new()
	name_label.text = definition.display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color",rarity_color)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(name_label)
	price_label = Label.new()
	price_label.text = "%d Gold each" % int(Catalog.PRODUCTS[id].price)
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.add_theme_color_override("font_color",Color("f3ce8b"))
	price_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(price_label)
	var quantity_row := HBoxContainer.new()
	quantity_row.add_theme_constant_override("separation",4)
	column.add_child(quantity_row)
	var quantity_caption := Label.new()
	quantity_caption.text = "Quantity"
	quantity_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	quantity_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quantity_row.add_child(quantity_caption)
	quantity_input = SpinBox.new()
	quantity_input.min_value = 0
	quantity_input.max_value = 99
	quantity_input.step = 1
	quantity_input.allow_greater = false
	quantity_input.allow_lesser = false
	quantity_input.custom_minimum_size.x = 84
	quantity_input.tooltip_text = "Enter a quantity from 1 to 99."
	quantity_input.value_changed.connect(func(_value): _refresh())
	quantity_row.add_child(quantity_input)
	var quick_row := HBoxContainer.new()
	quick_row.alignment = BoxContainer.ALIGNMENT_CENTER
	quick_row.add_theme_constant_override("separation",3)
	column.add_child(quick_row)
	for amount in [-10,-1,1,10]:
		var quick := Button.new()
		quick.text = ("+" if amount > 0 else "") + str(amount)
		quick.custom_minimum_size.x = 38
		quick.pressed.connect(func(): _change_quantity(amount))
		quick_row.add_child(quick)
	var max_button := Button.new()
	max_button.text = "MAX"
	max_button.custom_minimum_size.x = 48
	max_button.pressed.connect(func(): quantity_input.value = mini(int(quantity_input.max_value),int(floor(float(available_gold) / maxi(1,int(Catalog.PRODUCTS[item_id].price))))))
	quick_row.add_child(max_button)
	total_label = Label.new()
	total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	total_label.add_theme_color_override("font_color",Color("f3ce8b"))
	total_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(total_label)
	buy_button = Button.new()
	buy_button.text = "BUY"
	buy_button.pressed.connect(func(): buy_requested.emit(item_id,quantity()))
	column.add_child(buy_button)

func quantity() -> int:
	return int(quantity_input.value) if quantity_input != null else 0

func set_quantity(value: int) -> void:
	if quantity_input != null: quantity_input.value = clampi(value,0,int(quantity_input.max_value))

func set_available_gold(value: int) -> void:
	available_gold = maxi(0,value)
	_refresh()

func _change_quantity(amount: int) -> void:
	set_quantity(quantity() + amount)

func _refresh() -> void:
	if quantity_input == null: return
	var total := quantity() * int(Catalog.PRODUCTS[item_id].price)
	total_label.text = "Total: %d Gold" % total
	var valid := quantity() > 0 and total <= available_gold
	buy_button.disabled = not valid
	if total > available_gold: total_label.add_theme_color_override("font_color",Color("ef8b83"))
	else: total_label.add_theme_color_override("font_color",Color("f3ce8b"))
	quantity_changed.emit(item_id,quantity())

func _tooltip_item() -> Dictionary:
	var item := base_item.duplicate(true)
	item.quantity = maxi(1,quantity())
	item.buy_price = int(Catalog.PRODUCTS[item_id].price)
	return item

func _get_tooltip(_at_position: Vector2) -> String:
	return ItemTooltip.describe(_tooltip_item())

func _make_custom_tooltip(_text: String) -> Object:
	return ItemTooltip.make(_tooltip_item())
