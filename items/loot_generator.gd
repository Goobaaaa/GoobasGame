class_name LootGenerator
extends RefCounted
const Rarity = preload("res://inventory/item_rarity.gd")
## Future mob/dungeon loot entry point. It rolls a rarity and creates a normal
## persistent ItemInstance; no enemy system is coupled to it yet.

static func create_item(id: String, quantity: int = 1, progression: float = 0.0, rng: RandomNumberGenerator = null, forced_rarity: String = "", extra_modifiers: Dictionary = {}) -> Dictionary:
	var rarity := Rarity.normalize(forced_rarity) if not forced_rarity.is_empty() else Rarity.roll(rng, Rarity.weights_for_progression(progression))
	var properties := {}
	if not extra_modifiers.is_empty(): properties["modifiers"] = extra_modifiers.duplicate(true)
	return ItemInstance.create(id, quantity, properties, rarity)

static func rarity_weights(progression: float, enemy_bonus: Dictionary = {}) -> Dictionary:
	var result := Rarity.weights_for_progression(progression)
	for tier in enemy_bonus:
		if result.has(tier): result[tier] = maxf(0.0, float(result[tier]) + float(enemy_bonus[tier]))
	return result
