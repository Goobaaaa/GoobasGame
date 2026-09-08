class_name ItemInstance
extends RefCounted
const Rarity = preload("res://inventory/item_rarity.gd")
## JSON-safe instance records. Properties distinguish customized stacks.
static func create(id: String, quantity: int = 1, properties: Dictionary = {}, rarity: String = "") -> Dictionary:
	return create_with_rarity(id,quantity,properties,rarity)

static func create_with_rarity(id: String, quantity: int = 1, properties: Dictionary = {}, rarity: String = "") -> Dictionary:
	var definition := ItemRegistry.get_item(id)
	var selected := Rarity.normalize(rarity if not rarity.is_empty() else (definition.rarity if definition != null else Rarity.COMMON))
	return {"uid":Crypto.new().generate_random_bytes(16).hex_encode(), "id":id,
		"rarity":selected, "quantity":quantity, "x":0, "y":0, "rotated":false, "properties":properties.duplicate(true)}

static func rarity(item: Dictionary) -> String:
	var definition := ItemRegistry.get_item(str(item.get("id","")))
	return Rarity.normalize(str(item.get("rarity",definition.rarity if definition != null else Rarity.COMMON)))

static func stack_matches(a: Dictionary, b: Dictionary) -> bool:
	return a.id == b.id and rarity(a) == rarity(b) and a.properties == b.properties and ItemRegistry.get_item(a.id).max_stack > 1
