class_name PlayerInventory
extends RefCounted
const Rarity = preload("res://inventory/item_rarity.gd")
## Pure transactional model: UI previews and server commits use identical rules.
const SPACE_ERROR = "Not enough inventory space to equip this backpack."
var data: Dictionary

func _init(saved: Dictionary = {}) -> void:
	data = saved.duplicate(true) if not saved.is_empty() else {"version":1,"items":[],"equipment":{"back":ItemInstance.create("small_backpack")},"loot":AdventurerSupplies.CONTENTS.duplicate()}
	_normalize_rarity_fields()

func _normalize_rarity_fields() -> void:
	if not data.get("items") is Array or not data.get("equipment") is Dictionary: return
	for item in data.items + data.equipment.values():
		if item is Dictionary and not item.has("rarity"): item.rarity = ItemInstance.rarity(item)

func dimensions() -> Vector2i:
	if not data.equipment.has("back"): return Vector2i.ZERO
	return (ItemRegistry.get_item(data.equipment.back.id) as BackpackDefinition).inventory_size

func final_stats() -> Dictionary:
	return EquipmentRules.stats(data.equipment)

func find_item(uid: String) -> Dictionary:
	for item in data.items:
		if item.uid == uid: return item
	for item in data.equipment.values():
		if item.uid == uid: return item
	return {}

func slot_for(uid: String) -> String:
	for slot in data.equipment:
		if data.equipment[slot].uid == uid: return slot
	return ""

func transact(action: String, args: Dictionary, preview: bool = false) -> String:
	var candidate := PlayerInventory.new(data)
	var error := candidate._apply(action, args)
	if error.is_empty() and not candidate.valid(): error = "Invalid inventory operation."
	if error.is_empty() and not preview: data = candidate.data
	return error

func _apply(action: String, args: Dictionary) -> String:
	if action == "pickup":
		var id := str(args.get("id", ""))
		var quantity := int(args.get("quantity", 1))
		if quantity < 1 or quantity > int(data.loot.get(id, 0)): return "That supply is no longer available."
		var placement: Dictionary = {}
		for key in ["x", "y", "rotated"]:
			if args.has(key): placement[key] = args[key]
		var properties: Dictionary = args.get("properties",{}) if args.get("properties",{}) is Dictionary else {}
		if not add_item(id, quantity, properties, placement, "", str(args.get("rarity",""))): return "That space is occupied or there is not enough inventory space."
		data.loot[id] -= quantity
		return ""
	var item := find_item(str(args.get("uid", "")))
	if item.is_empty(): return "Item no longer available."
	var old_slot := slot_for(item.uid)
	var definition := ItemRegistry.get_item(item.id)
	if action == "drop":
		if not old_slot.is_empty(): return "Only items in the backpack can be dropped."
		var dropped_quantity := int(args.get("quantity", item.quantity))
		return "" if not _extract_item(item.uid, dropped_quantity).is_empty() else "That item can no longer be dropped."
	if action == "equip":
		var slot := str(args.get("slot", ""))
		if not EquipmentRules.accepts(slot, item): return "This item cannot be equipped in that slot."
		if slot == old_slot: return ""
		var without: Dictionary = data.equipment.duplicate(true)
		without.erase(slot)
		if not old_slot.is_empty(): without.erase(old_slot)
		var available := EquipmentRules.stats(without)
		for stat in definition.requirements:
			if float(available.get(stat, 0)) < float(definition.requirements[stat]): return "Equipment requirements not met."
		var displaced: Dictionary = data.equipment.get(slot, {})
		_remove(item)
		data.equipment[slot] = item
		if not displaced.is_empty(): data.items.append(displaced)
		if slot == "back" or old_slot == "back": return _resize()
		if not displaced.is_empty() and not InventoryGrid.fits(displaced, data.items, dimensions()):
			if not InventoryGrid.first_fit(displaced, data.items, dimensions()): return "Not enough inventory space for the unequipped item."
		return ""
	if action != "move" and action != "split": return "Unknown inventory action."
	var rotated: bool = args.get("rotated", item.rotated) == true
	if rotated and not definition.can_rotate: return "This item cannot rotate."
	var moving := item.duplicate(true)
	moving.x = int(args.get("x", -1))
	moving.y = int(args.get("y", -1))
	moving.rotated = rotated
	if not Rect2i(Vector2i.ZERO,dimensions()).has_point(Vector2i(moving.x,moving.y)): return "That space is outside the backpack."
	if action == "split":
		var count := int(args.get("quantity", 0))
		if not old_slot.is_empty() or count < 1 or count >= item.quantity: return "Choose less than the full stack to split."
		moving.uid = ItemInstance.create_with_rarity(item.id,1,item.properties,ItemInstance.rarity(item)).uid
		moving.quantity = count
		if not InventoryGrid.fits(moving, data.items, dimensions()): return "That space is occupied or outside the backpack."
		item.quantity -= count
		data.items.append(moving)
		return ""
	var overlaps: Array = []
	for other in data.items:
		if other.uid != item.uid and InventoryGrid.rect(moving).intersects(InventoryGrid.rect(other)): overlaps.append(other)
	if overlaps.size() == 1 and ItemInstance.stack_matches(item, overlaps[0]):
		var target: Dictionary = overlaps[0]
		var transfer := mini(item.quantity, definition.max_stack - int(target.quantity))
		if transfer == 0: return "That stack is full."
		target.quantity += transfer
		item.quantity -= transfer
		if item.quantity == 0: _remove(item)
		return ""
	if overlaps.size() == 1:
		var other: Dictionary = overlaps[0]
		if not old_slot.is_empty():
			if not EquipmentRules.accepts(old_slot, other): return "The other item does not fit the equipment slot."
			# Equip through the same requirement and backpack transaction checks.
			var equip_error := _apply("equip", {"uid":other.uid,"slot":old_slot})
			if not equip_error.is_empty(): return equip_error
			item = find_item(item.uid)
		else:
			other.x = item.x
			other.y = item.y
			if not InventoryGrid.fits(other, data.items, dimensions(), [item.uid]): return "The swapped item does not fit."
	elif not overlaps.is_empty(): return "That space is occupied."
	if not InventoryGrid.fits(moving, data.items, dimensions()): return "That space is occupied or outside the backpack."
	_remove(item)
	data.items.append(moving)
	if old_slot == "back": return _resize()
	return ""

func _remove(item: Dictionary) -> void:
	var slot := slot_for(item.uid)
	if not slot.is_empty(): data.equipment.erase(slot)
	else: data.items.erase(item)

func _extract_item(uid: String, quantity: int) -> Dictionary:
	var item := find_item(uid)
	if item.is_empty() or not slot_for(uid).is_empty() or quantity < 1 or quantity > int(item.quantity): return {}
	var extracted := item.duplicate(true)
	if quantity == int(item.quantity):
		_remove(item)
	else:
		extracted.uid = ItemInstance.create(item.id).uid
		extracted.quantity = quantity
		item.quantity -= quantity
	return extracted

func _resize() -> String:
	var fits := true
	for item in data.items:
		if not InventoryGrid.fits(item, data.items, dimensions()): fits = false
	if fits: return ""
	return "" if InventoryGrid.pack(data.items, dimensions()) else SPACE_ERROR

## Safe acquisition API for future loot/crafting systems. Failure rolls back partial merges.
func take_item(uid: String, quantity: int = 0) -> Dictionary:
	var candidate := PlayerInventory.new(data)
	var item := candidate.find_item(uid)
	if item.is_empty(): return {}
	var amount := int(item.quantity) if quantity <= 0 else quantity
	var extracted := candidate._extract_item(uid, amount)
	if extracted.is_empty() or not candidate.valid(): return {}
	data = candidate.data
	return extracted

func add_item(id: String, quantity: int, properties: Dictionary = {}, placement: Dictionary = {}, preferred_uid: String = "", rarity: String = "") -> bool:
	var original := data.duplicate(true)
	if _add_item(id,quantity,properties,placement,preferred_uid,rarity): return true
	data = original
	return false

func _add_item(id: String, quantity: int, properties: Dictionary, placement: Dictionary = {}, preferred_uid: String = "", rarity: String = "") -> bool:
	var definition := ItemRegistry.get_item(id)
	if definition == null or quantity < 1: return false
	var selected_rarity := Rarity.normalize(rarity if not rarity.is_empty() else definition.rarity)
	if not placement.is_empty():
		var preferred := ItemInstance.create_with_rarity(id, mini(quantity, definition.max_stack), properties, selected_rarity)
		if not preferred_uid.is_empty(): preferred.uid = preferred_uid
		preferred.x = int(placement.get("x", -1))
		preferred.y = int(placement.get("y", -1))
		preferred.rotated = placement.get("rotated", false) == true
		if preferred.rotated and not definition.can_rotate: return false
		if not Rect2i(Vector2i.ZERO, dimensions()).has_point(Vector2i(preferred.x, preferred.y)): return false
		var overlaps: Array = []
		for other in data.items:
			if InventoryGrid.rect(preferred).intersects(InventoryGrid.rect(other)): overlaps.append(other)
		if overlaps.size() == 1 and ItemInstance.stack_matches(preferred, overlaps[0]):
			var target: Dictionary = overlaps[0]
			var transfer := mini(preferred.quantity, definition.max_stack - int(target.quantity))
			if transfer == 0: return false
			target.quantity += transfer
			quantity -= transfer
		else:
			if not overlaps.is_empty() or not InventoryGrid.fits(preferred, data.items, dimensions()): return false
			data.items.append(preferred)
			quantity -= preferred.quantity
		if quantity == 0: return true
	var template := ItemInstance.create_with_rarity(id, 1, properties, selected_rarity)
	for item in data.items:
		if ItemInstance.stack_matches(item, template):
			var count := mini(quantity, definition.max_stack - int(item.quantity))
			item.quantity += count
			quantity -= count
	while quantity > 0:
		var item := ItemInstance.create_with_rarity(id, mini(quantity, definition.max_stack), properties, selected_rarity)
		if not preferred_uid.is_empty():
			item.uid = preferred_uid
			preferred_uid = ""
		if not InventoryGrid.first_fit(item, data.items, dimensions()): return false
		data.items.append(item)
		quantity -= item.quantity
	return true

func valid() -> bool:
	if data.get("version") != 1 or not data.get("items") is Array or not data.get("equipment") is Dictionary or not data.get("loot") is Dictionary: return false
	var uids: Dictionary = {}
	for item in data.items + data.equipment.values():
		if not item is Dictionary: return false
		for key in ["id","uid","quantity","x","y","rotated","properties"]:
			if not item.has(key): return false
		if not item.id is String or not item.uid is String or item.uid.is_empty() or uids.has(item.uid): return false
		uids[item.uid] = true
		var definition := ItemRegistry.get_item(item.id)
		if definition == null or not item.properties is Dictionary or not item.rotated is bool: return false
		if item.has("rarity") and Rarity.normalize(str(item.rarity)) != str(item.rarity): return false
		for key in ["quantity","x","y"]:
			if not (item[key] is int or item[key] is float) or not is_finite(float(item[key])) or item[key] != int(item[key]): return false
		if item.quantity < 1 or item.quantity > definition.max_stack or (item.rotated and not definition.can_rotate): return false
	for slot in data.equipment:
		if not EquipmentRules.accepts(slot, data.equipment[slot]): return false
	for item in data.items:
		if not InventoryGrid.fits(item, data.items, dimensions()): return false
	for id in data.loot:
		var quantity: Variant = data.loot[id]
		if ItemRegistry.get_item(id) == null or not (quantity is int or quantity is float): return false
		if not is_finite(float(quantity)) or quantity < 0 or quantity != int(quantity): return false
	return true
