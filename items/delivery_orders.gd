class_name DeliveryOrders
extends RefCounted
## Saved deadlines avoid resetting delivery timers on Continue. Contents are remaining units.
const DELAY_SECONDS = 300.0

static func quote(contents: Dictionary) -> int:
	if contents.is_empty(): return -1
	var total := 0
	for id in contents:
		var quantity: Variant = contents[id]
		if not Catalog.PRODUCTS.has(id) or ItemRegistry.get_item(id) == null: return -1
		if not (quantity is int or quantity is float) or not is_finite(float(quantity)): return -1
		if quantity != int(quantity) or quantity < 1 or quantity > 99: return -1
		total += Catalog.PRODUCTS[id].price * int(quantity)
	return total

static func create(contents: Dictionary, now: float) -> Dictionary:
	return {"uid":Crypto.new().generate_random_bytes(16).hex_encode(),"due_at":now+DELAY_SECONDS,"contents":contents.duplicate(true)}

static func has_contents(contents: Dictionary) -> bool:
	for count in contents.values():
		if count > 0: return true
	return false

static func ready(orders: Array, now: float) -> Array:
	return orders.filter(func(order): return order.due_at <= now and has_contents(order.contents))

static func valid(orders: Variant) -> bool:
	if not orders is Array: return false
	var seen := {}
	for order in orders:
		if not order is Dictionary or not order.get("uid") is String or str(order.uid).is_empty() or seen.has(order.uid): return false
		seen[order.uid] = true
		var due: Variant = order.get("due_at")
		if not (due is float or due is int) or not is_finite(float(due)) or due < 0: return false
		if not order.get("contents") is Dictionary or order.contents.is_empty(): return false
		for id in order.contents:
			var count: Variant = order.contents[id]
			if not Catalog.PRODUCTS.has(id) or ItemRegistry.get_item(id) == null: return false
			if not (count is int or count is float) or not is_finite(float(count)) or count < 1 or count != int(count): return false
	return true
