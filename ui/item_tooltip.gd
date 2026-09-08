class_name ItemTooltip
extends RefCounted
const Rarity = preload("res://inventory/item_rarity.gd")
## Shared item presentation data and custom tooltip builder. All item surfaces
## use this class so inventory, loot, shops, and equipment stay consistent.
static func describe(item: Dictionary) -> String:
	var d := ItemRegistry.get_item(str(item.get("id", "")))
	if d == null or not item.has("quantity"): return ""
	var rarity := ItemInstance.rarity(item)
	var lines: Array[String] = [d.display_name, rarity + " · " + d.category]
	if not d.description.is_empty(): lines.append(d.description)
	var modifiers := d.effective_modifiers(item)
	if not modifiers.is_empty():
		lines.append("STATS")
		for key in modifiers: lines.append("%s%s %s" % ["+" if modifiers[key] >= 0 else "",_number(modifiers[key]),_label(key)])
	if d is BackpackDefinition: lines.append("Capacity: %d × %d" % [d.inventory_size.x, d.inventory_size.y])
	if not d.equipment_slots.is_empty(): lines.append("Equip: " + _slot_label(d.equipment_slots[0]))
	if d.max_stack > 1: lines.append("Stack: %d / %d" % [item.quantity, d.max_stack])
	if d.weight > 0.0: lines.append("Weight: %.1f" % d.weight)
	lines.append("Sell Value: %d Gold" % d.sell_value(item))
	if item.has("buy_price"): lines.append("Buy Price: %d Gold" % int(item.buy_price))
	if not d.special_effects.is_empty(): lines.append("Effects: " + ", ".join(d.special_effects))
	for key in d.requirements: lines.append("Requires %s %s" % [str(d.requirements[key]), str(key).capitalize()])
	return "\n".join(lines)

static func make(item: Dictionary) -> Control:
	# Hover timers can outlive the item or the inventory refresh that selected it.
	var d := ItemRegistry.get_item(str(item.get("id", "")))
	if d == null or not item.has("quantity"): return null
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("172326")
	style.border_color = Rarity.color_for(ItemInstance.rarity(item))
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel",style)
	panel.custom_minimum_size.x = 310
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",4)
	panel.add_child(column)
	var heading := HBoxContainer.new()
	column.add_child(heading)
	if d.icon:
		var icon := TextureRect.new()
		icon.texture = d.icon
		icon.custom_minimum_size = Vector2(52,52)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		heading.add_child(icon)
	var name_column := VBoxContainer.new()
	name_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(name_column)
	var name := Label.new()
	name.text = d.display_name
	name.add_theme_font_size_override("font_size",20)
	name.add_theme_color_override("font_color",Rarity.color_for(ItemInstance.rarity(item)))
	name_column.add_child(name)
	var rarity := Label.new()
	rarity.text = ItemInstance.rarity(item) + " · " + d.category
	rarity.add_theme_color_override("font_color",Rarity.color_for(ItemInstance.rarity(item)))
	name_column.add_child(rarity)
	if not d.description.is_empty():
		var description := Label.new()
		description.text = d.description
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.add_theme_color_override("font_color",Color("c6d0cc"))
		column.add_child(description)
	var modifiers := d.effective_modifiers(item)
	if not modifiers.is_empty():
		_add_section(column,"STATS")
		for key in modifiers: _add_value(column,"%s: %s%s" % [_label(key),"+" if modifiers[key] >= 0 else "",_number(modifiers[key])],modifiers[key] >= 0)
	if d is BackpackDefinition: _add_value(column,"Capacity: %d × %d" % [d.inventory_size.x,d.inventory_size.y],true)
	if not d.equipment_slots.is_empty(): _add_value(column,"Equipment Slot: " + _slot_label(d.equipment_slots[0]),true)
	if d.max_stack > 1: _add_value(column,"Stack: %d / %d" % [item.quantity,d.max_stack],true)
	if d.weight > 0.0: _add_value(column,"Weight: %.1f" % d.weight,true)
	_add_value(column,"Sell Value: %d Gold" % d.sell_value(item),true)
	if item.has("buy_price"): _add_value(column,"Buy Price: %d Gold" % int(item.buy_price),true)
	if not d.special_effects.is_empty(): _add_value(column,"Effects: " + ", ".join(d.special_effects),true)
	for key in d.requirements: _add_value(column,"Requires %s %s" % [str(d.requirements[key]),_label(key)],true)
	return panel

static func _add_section(parent: Control, title: String) -> void:
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size",12)
	label.add_theme_color_override("font_color",Color("f3ce8b"))
	parent.add_child(label)

static func _add_value(parent: Control, value: String, positive: bool) -> void:
	var label := Label.new()
	label.text = value
	label.add_theme_color_override("font_color",Color("9fe3ae") if positive else Color("f08a83"))
	parent.add_child(label)

static func _number(value: Variant) -> String:
	var number := float(value)
	return str(roundi(number)) if is_equal_approx(number,round(number)) else "%.1f" % number

static func _label(value: String) -> String:
	return value.replace("_"," ").capitalize()

static func _slot_label(value: String) -> String:
	return _label(value)
