class_name SaveStore
extends RefCounted
const ShopName = preload("res://shops/shop_naming.gd")
const Rarity = preload("res://inventory/item_rarity.gd")
const REQUIRED_KEYS = ["version", "money", "purchased_shop", "player_position", "furniture", "ordered_stock"]
## Host-only versioned JSON; retain a backup before replacing a save.
static var path := "user://saves/lantern_lane.json"

static func fresh() -> Dictionary:
	return {"version":1, "money":1000, "purchased_shop":-1, "shop_name":"", "player_position":[0.0,0.2,4.0], "furniture":[], "ordered_stock":{}}

static func validate(data: Variant) -> bool:
	if not data is Dictionary: return false
	for key in REQUIRED_KEYS:
		if not data.has(key): return false
	# Optional extension keeps version-1 business saves loadable.
	if data.has("inventories"):
		if not data.inventories is Dictionary: return false
		for inventory in data.inventories.values():
			if not inventory is Dictionary or inventory.is_empty() or not PlayerInventory.new(inventory).valid(): return false
	if data.version != 1 or not (data.money is float or data.money is int) or data.money < 0: return false
	if data.has("deliveries"):
		if not DeliveryOrders.valid(data.deliveries): return false
		if data.purchased_shop == -1 and not data.deliveries.is_empty(): return false
	if data.has("ground_loot") and not validate_ground_loot(data.ground_loot): return false
	if not (data.purchased_shop is float or data.purchased_shop is int) or data.purchased_shop < -1 or data.purchased_shop > 2: return false
	if data.has("shop_name"):
		if not data.shop_name is String or (not str(data.shop_name).is_empty() and not ShopName.validate(data.shop_name).is_empty()): return false
		if data.purchased_shop == -1 and not str(data.shop_name).is_empty(): return false
	if not data.player_position is Array or data.player_position.size() != 3: return false
	for n in data.player_position:
		if not (n is float or n is int) or not is_finite(float(n)): return false
	if not data.furniture is Array or not data.ordered_stock is Dictionary: return false
	var accepted: Array = []
	for e in data.furniture:
		if not e is Dictionary: return false
		for k in ["id","x","z","turn"]:
			if not e.has(k): return false
		if not e.id is String: return false
		for k in ["x","z","turn"]:
			if not (e[k] is float or e[k] is int): return false
		if GridRules.validate(e.id, int(e.x), int(e.z), int(e.turn), accepted) != "": return false
		accepted.append(e)
	for id in data.ordered_stock:
		var q: Variant = data.ordered_stock[id]
		if not Catalog.PRODUCTS.has(id) or not (q is int or q is float) or q < 0 or q != int(q): return false
	if not SaleStock.validate(data): return false
	return data.purchased_shop != -1 or (data.furniture.is_empty() and data.ordered_stock.is_empty())

static func validate_ground_loot(records: Variant) -> bool:
	if not records is Array: return false
	var chest_ids: Dictionary = {}
	for chest in records:
		if not chest is Dictionary: return false
		for key in ["uid", "position", "contents"]:
			if not chest.has(key): return false
		if not chest.uid is String or chest.uid.is_empty() or chest_ids.has(chest.uid): return false
		chest_ids[chest.uid] = true
		if not chest.position is Array or chest.position.size() != 3: return false
		for n in chest.position:
			if not (n is float or n is int) or not is_finite(float(n)): return false
		if not chest.contents is Array or chest.contents.is_empty(): return false
		var item_ids: Dictionary = {}
		for item in chest.contents:
			if not item is Dictionary: return false
			for key in ["id", "uid", "quantity", "x", "y", "rotated", "properties"]:
				if not item.has(key): return false
			if not item.id is String or item.id.is_empty() or not item.uid is String or item.uid.is_empty() or item_ids.has(item.uid): return false
			item_ids[item.uid] = true
			var definition := ItemRegistry.get_item(item.id)
			if definition == null or not item.properties is Dictionary or not item.rotated is bool: return false
			if item.has("rarity") and Rarity.normalize(str(item.rarity)) != str(item.rarity): return false
			for key in ["quantity", "x", "y"]:
				if not (item[key] is int or item[key] is float) or not is_finite(float(item[key])) or item[key] != int(item[key]): return false
			if item.quantity < 1 or item.quantity > definition.max_stack or (item.rotated and not definition.can_rotate): return false
	return true

static func write(data: Dictionary) -> Error:
	if not validate(data): return ERR_INVALID_DATA
	var folder := ProjectSettings.globalize_path(path.get_base_dir())
	var err := DirAccess.make_dir_recursive_absolute(folder)
	if err != OK: return err
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	err = file.get_error()
	file.close()
	if err != OK: return err
	if FileAccess.file_exists(path):
		err = DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(path + ".bak"))
		if err != OK: return err
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".tmp"), ProjectSettings.globalize_path(path))

static func read_save() -> Dictionary:
	for candidate in [path, path + ".bak"]:
		if FileAccess.file_exists(candidate):
			var parser := JSON.new()
			if parser.parse(FileAccess.get_file_as_string(candidate)) == OK and validate(parser.data):
				return parser.data
	return {}
