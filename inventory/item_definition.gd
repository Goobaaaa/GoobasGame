class_name ItemDefinition
extends Resource
const Rarity = preload("res://inventory/item_rarity.gd")
## Immutable catalog data. Save files store id, never resource paths.
@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var category: String = "Material"
@export var rarity: String = "Common"
@export var icon: Texture2D
@export var visual: PackedScene
@export var rarity_scales_stats: bool = true
@export var special_effects: PackedStringArray = []
## Zero uses the inventory footprint. Display cells are independent of world placement cells.
@export var sale_size: Vector2i = Vector2i.ZERO
@export var display_scale: float = 1.0
@export var grid_size: Vector2i = Vector2i.ONE
@export var max_stack: int = 1
@export var can_rotate: bool = true
@export var weight: float = 0.0
@export var value: int = 0
@export var equipment_slots: PackedStringArray = []
@export var modifiers: Dictionary = {}
@export var requirements: Dictionary = {}

func footprint(rotated: bool) -> Vector2i:
	return Vector2i(grid_size.y, grid_size.x) if rotated else grid_size

func instance_rarity(item: Dictionary = {}) -> String:
	return Rarity.normalize(str(item.get("rarity",rarity)))

func effective_modifiers(item: Dictionary = {}) -> Dictionary:
	var selected_rarity := instance_rarity(item)
	var rule := Rarity.rule_for(selected_rarity)
	var multiplier := float(rule.get("stat_multiplier",1.0)) if rarity_scales_stats else 1.0
	var result := {}
	for key in modifiers:
		result[key] = float(modifiers[key]) * multiplier
	var properties: Dictionary = item.get("properties",{}) if item.get("properties",{}) is Dictionary else {}
	var rolled: Variant = properties.get("modifiers",{})
	if rolled is Dictionary:
		for key in rolled:
			if rolled[key] is int or rolled[key] is float: result[key] = float(result.get(key,0)) + float(rolled[key])
	return result

func sell_value(item: Dictionary = {}) -> int:
	var multiplier := float(Rarity.rule_for(instance_rarity(item)).get("value_multiplier",1.0))
	return maxi(0,roundi(float(value) * multiplier))
