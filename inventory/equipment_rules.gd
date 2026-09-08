class_name EquipmentRules
extends RefCounted
## Add slot IDs here and to the panel layout; item resources opt into compatible IDs.
const SLOTS = ["head", "chest", "legs", "hands", "feet", "cape", "back", "main_hand", "off_hand"]
const BASE_STATS = {"health":100.0, "mana":50.0, "movement_speed":4.0, "armour":0.0, "damage":0.0}

static func accepts(slot: String, item: Dictionary) -> bool:
	var definition := ItemRegistry.get_item(item.id)
	return slot in SLOTS and slot in definition.equipment_slots and item.quantity == 1 and (slot != "back" or definition is BackpackDefinition)

static func stats(equipment: Dictionary, base: Dictionary = BASE_STATS) -> Dictionary:
	var result := base.duplicate(true)
	for item in equipment.values():
		var definition := ItemRegistry.get_item(item.id)
		var modifiers := definition.effective_modifiers(item)
		for key in modifiers:
			result[key] = float(result.get(key, 0)) + float(modifiers[key])
	return result
