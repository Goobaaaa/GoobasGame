class_name SaveStore
extends RefCounted
## Host-only versioned JSON; retain a backup before replacing a save.
static var path := "user://saves/lantern_lane.json"

static func fresh() -> Dictionary:
	return {"version":1, "money":1000, "purchased_shop":-1, "player_position":[0.0,0.2,4.0], "furniture":[], "ordered_stock":{}}

static func validate(data: Variant) -> bool:
	if not data is Dictionary: return false
	for key in fresh():
		if not data.has(key): return false
	if data.version != 1 or not (data.money is float or data.money is int) or data.money < 0: return false
	if not (data.purchased_shop is float or data.purchased_shop is int) or data.purchased_shop < -1 or data.purchased_shop > 2: return false
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
	return data.purchased_shop != -1 or (data.furniture.is_empty() and data.ordered_stock.is_empty())

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
