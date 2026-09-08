class_name InventoryGrid
extends RefCounted

static func rect(item: Dictionary) -> Rect2i:
	return Rect2i(Vector2i(item.x, item.y), ItemRegistry.get_item(item.id).footprint(item.rotated))

static func fits(item: Dictionary, items: Array, size: Vector2i, ignore: Array = []) -> bool:
	var area := rect(item)
	if not Rect2i(Vector2i.ZERO, size).encloses(area): return false
	for other in items:
		if other.uid == item.uid or other.uid in ignore: continue
		if area.intersects(rect(other)): return false
	return true

static func first_fit(item: Dictionary, items: Array, size: Vector2i) -> bool:
	var original: Dictionary = item.duplicate(true)
	var orientations: Array = [item.rotated]
	if ItemRegistry.get_item(item.id).can_rotate: orientations.append(not item.rotated)
	for turn in orientations:
		item.rotated = turn
		for y in size.y:
			for x in size.x:
				item.x = x
				item.y = y
				if fits(item, items, size): return true
	item.merge(original, true)
	return false

## Bounded exact repacking. Failure never mutates the live inventory.
static func pack(items: Array, size: Vector2i) -> bool:
	var area := 0
	for item in items: area += rect(item).get_area()
	if area > size.x * size.y: return false
	var ordered := items.duplicate()
	ordered.sort_custom(func(a, b): return rect(a).get_area() > rect(b).get_area())
	return _search(ordered, [], size, [100000])

static func _search(remaining: Array, placed: Array, size: Vector2i, budget: Array) -> bool:
	if remaining.is_empty(): return true
	budget[0] -= 1
	if budget[0] < 0: return false
	var item: Dictionary = remaining[0]
	var orientations: Array = [item.rotated]
	if ItemRegistry.get_item(item.id).can_rotate: orientations.append(not item.rotated)
	for turn in orientations:
		item.rotated = turn
		for y in size.y:
			for x in size.x:
				item.x = x
				item.y = y
				if fits(item, placed, size):
					if _search(remaining.slice(1), placed + [item], size, budget): return true
	return false
