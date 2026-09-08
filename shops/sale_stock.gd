class_name SaleStock
extends RefCounted
const Rarity = preload("res://inventory/item_rarity.gd")
## Local display grids, one footprint per physical unit, with explicit shelf tiers.
const SURFACES = {
	"small_table":{"size":Vector2i(6,4),"heights":[0.87]},
	"basic_shelf":{"size":Vector2i(4,2),"heights":[0.3,0.85,1.4]},
	"large_shelf":{"size":Vector2i(8,3),"heights":[0.3,0.85,1.4,1.95]},
	"wall_shelf":{"size":Vector2i(4,2),"heights":[1.8]},
	"counter":{"size":Vector2i(6,2),"heights":[1.12]}}

static func key(entry: Dictionary) -> String:
	return str(entry.get("uid","%s:%d:%d:%d" % [entry.id,entry.x,entry.z,entry.turn]))

static func definition(entry: Dictionary) -> Dictionary:
	return SURFACES.get(entry.id,{})

static func item_size(id: String, rotated: bool = false) -> Vector2i:
	var d := ItemRegistry.get_item(id)
	var size := d.grid_size if d.sale_size == Vector2i.ZERO else d.sale_size
	return Vector2i(size.y,size.x) if rotated else size

static func buy_price(id: String, item: Dictionary = {}) -> int:
	return int(Catalog.PRODUCTS[id].price) if Catalog.PRODUCTS.has(id) else ItemRegistry.get_item(id).sell_value(item)

static func unit_rect(id: String, unit: Dictionary) -> Rect2i:
	return Rect2i(Vector2i(unit.x,unit.y),item_size(id,unit.rotated))

static func capacity(entry: Dictionary) -> int:
	var surface := definition(entry)
	return surface.size.x * surface.size.y * surface.heights.size() if not surface.is_empty() else 0

static func used(listings: Array) -> int:
	var result := 0
	for listing in listings: result += item_size(listing.item.id).x * item_size(listing.item.id).y * listing.item.quantity
	return result

static func _place(id: String, surface: Dictionary, occupied: Array) -> Dictionary:
	if item_size(id).x <= 0 or item_size(id).y <= 0: return {}
	var turns: Array = [false,true] if ItemRegistry.get_item(id).can_rotate else [false]
	for tier in surface.heights.size():
		for turn in turns:
			for y in surface.size.y:
				for x in surface.size.x:
					var unit := {"tier":tier,"x":x,"y":y,"rotated":turn}
					var rect := unit_rect(id,unit)
					if not Rect2i(Vector2i.ZERO,surface.size).encloses(rect): continue
					var free := true
					for other in occupied:
						if other.unit.tier == tier and rect.intersects(unit_rect(other.id,other.unit)): free = false; break
					if free: return unit
	return {}

## Called with transaction copies; the session commits inventory + listings together after success.
static func apply(inventory: PlayerInventory, listings: Array, entry: Dictionary, action: String, args: Dictionary) -> String:
	var surface := definition(entry)
	if surface.is_empty(): return "This furniture is not a sale platform."
	if action == "stock":
		var item := inventory.find_item(str(args.get("uid","")))
		if item.is_empty() or not inventory.slot_for(item.uid).is_empty(): return "Choose an item in your backpack."
		var quantity := int(args.get("quantity",0))
		var price := int(args.get("price",0))
		if quantity < 1 or quantity > item.quantity or price < 1 or price > 1000000: return "Choose a valid quantity and a price from 1 to 1,000,000 gold."
		var occupied: Array = []
		for listing in listings:
			for unit in listing.units: occupied.append({"id":listing.item.id,"unit":unit})
		var units: Array = []
		for index in quantity:
			var unit := _place(item.id,surface,occupied)
			if unit.is_empty(): return "Not enough display space for that quantity or item size."
			units.append(unit)
			occupied.append({"id":item.id,"unit":unit})
		var stocked := item.duplicate(true)
		stocked.quantity = quantity
		if quantity == item.quantity: inventory.data.items.erase(item)
		else:
			item.quantity -= quantity
			stocked.uid = ItemInstance.create(item.id).uid
		listings.append({"item":stocked,"price":price,"units":units})
		return ""
	var selected: Dictionary = {}
	for listing in listings:
		if listing.item.uid == str(args.get("uid","")): selected = listing
	if selected.is_empty(): return "That listing no longer exists."
	if action == "price":
		var price := int(args.get("price",0))
		if price < 1 or price > 1000000: return "Enter a price from 1 to 1,000,000 gold."
		selected.price = price
		return ""
	if action == "remove":
		# Preserve properties and the persistent instance ID unless merged into an existing stack.
		var returned: Dictionary = selected.item.duplicate(true)
		for item in inventory.data.items:
			if ItemInstance.stack_matches(item,returned):
				var amount := mini(returned.quantity,ItemRegistry.get_item(item.id).max_stack-int(item.quantity))
				item.quantity += amount
				returned.quantity -= amount
		if returned.quantity > 0:
			if not InventoryGrid.first_fit(returned,inventory.data.items,inventory.dimensions()): return "Not enough backpack space. The listing remains for sale."
			inventory.data.items.append(returned)
		listings.erase(selected)
		return ""
	return "Unknown sale-platform action."

static func validate(state: Dictionary) -> bool:
	var stocks: Variant = state.get("sale_stock",{})
	if not stocks is Dictionary: return false
	var platforms := {}
	for entry in state.furniture: platforms[key(entry)] = entry
	var ids := {}
	for inv in state.get("inventories",{}).values():
		for item in inv.items + inv.equipment.values(): ids[item.uid] = true
	for platform in stocks:
		if not platforms.has(platform) or definition(platforms[platform]).is_empty() or not stocks[platform] is Array: return false
		var surface := definition(platforms[platform])
		var occupied: Array = []
		for listing in stocks[platform]:
			if not listing is Dictionary or not listing.get("item") is Dictionary or not listing.get("units") is Array: return false
			var item: Dictionary = listing.item
			# Validate item records plus unit placement; display items must have a single owner.
			for field in ["id","uid","quantity","properties","rotated","x","y"]:
				if not item.has(field): return false
			if not item.id is String or ItemRegistry.get_item(item.id) == null or not item.uid is String or item.uid.is_empty() or ids.has(item.uid): return false
			if item_size(item.id).x <= 0 or item_size(item.id).y <= 0: return false
			ids[item.uid] = true
			if not item.properties is Dictionary or not item.rotated is bool: return false
			if item.has("rarity") and Rarity.normalize(str(item.rarity)) != str(item.rarity): return false
			for value in [item.quantity,item.x,item.y,listing.get("price")]:
				if not (value is int or value is float) or not is_finite(float(value)) or value != int(value): return false
			if item.quantity < 1 or item.quantity > ItemRegistry.get_item(item.id).max_stack or listing.price < 1 or listing.price > 1000000 or listing.units.size() != int(item.quantity): return false
			for unit in listing.units:
				if not unit is Dictionary or not unit.get("rotated") is bool: return false
				for field in ["x","y","tier"]:
					var n: Variant = unit.get(field)
					if not (n is int or n is float) or not is_finite(float(n)) or n != int(n): return false
				if unit.tier < 0 or unit.tier >= surface.heights.size() or (unit.rotated and not ItemRegistry.get_item(item.id).can_rotate): return false
				var rect := unit_rect(item.id,unit)
				if not Rect2i(Vector2i.ZERO,surface.size).encloses(rect): return false
				for other in occupied:
					if other.unit.tier == unit.tier and rect.intersects(unit_rect(other.id,other.unit)): return false
				occupied.append({"id":item.id,"unit":unit})
	return true
