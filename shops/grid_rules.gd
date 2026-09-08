class_name GridRules
extends RefCounted
const CELL = 0.5
const WIDTH = 12
const DEPTH = 12

static func size_for(id: String, turn: int) -> Vector2i:
	var s: Array = Catalog.FURNITURE[id].size
	return Vector2i(s[0], s[1]) if turn % 2 == 0 else Vector2i(s[1], s[0])

static func rect_for(entry: Dictionary) -> Rect2i:
	return Rect2i(Vector2i(int(entry.x), int(entry.z)), size_for(entry.id, int(entry.turn)))

static func validate(id: String, x: int, z: int, turn: int, placed: Array) -> String:
	if not Catalog.FURNITURE.has(id) or turn < 0 or turn > 3:
		return "Unknown furniture or rotation."
	var size := size_for(id, turn)
	var rect := Rect2i(Vector2i(x,z), size)
	if x < 0 or z < 0 or rect.end.x > WIDTH or rect.end.y > DEPTH:
		return "Keep the whole footprint inside the shop."
	# Reserve the entrance so furniture cannot trap players.
	if rect.intersects(Rect2i(5,9,2,3)):
		return "Keep the marked entrance clear."
	if Catalog.FURNITURE[id].get("wall", false):
		var on_wall := (turn == 0 and z + size.y == DEPTH) or (turn == 1 and x + size.x == WIDTH) or (turn == 2 and z == 0) or (turn == 3 and x == 0)
		if not on_wall:
			return "Rotate the shelf so its back touches a wall."
	for entry in placed:
		if rect.intersects(rect_for(entry)):
			return "That footprint is occupied."
	return ""

static func center(entry: Dictionary, origin: Vector3) -> Vector3:
	var s := size_for(entry.id, int(entry.turn))
	return origin + Vector3((float(entry.x) + s.x / 2.0) * CELL, 0, (float(entry.z) + s.y / 2.0) * CELL)

