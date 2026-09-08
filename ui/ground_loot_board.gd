class_name GroundLootBoard
extends Control
const Rarity = preload("res://inventory/item_rarity.gd")
## A visual ground container. Source quantities remain in Session until a saved pickup commits.
signal requested(action: String, args: Dictionary)
signal feedback(message: String)
const CELL = InventoryBoard.CELL
const COLUMNS = 4
const MIN_ROWS = 6
const ORIGIN = Vector2(8, 8)
var inventory_board: InventoryBoard
var model: PlayerInventory
var entries: Array = []
var source := "supplies"
var dragging := ""
var split := false
var rotated := false
var pointer := Vector2.ZERO
var pending: Dictionary = {}
var placement_error := ""
var cached_preview := ""
var hover_item: Dictionary = {}
var grid_size := Vector2i(COLUMNS, MIN_ROWS)

func _ready() -> void:
	custom_minimum_size = Vector2(ORIGIN.x * 2 + COLUMNS * InventoryBoard.CELL, ORIGIN.y * 2 + MIN_ROWS * InventoryBoard.CELL)
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = "Item"

func sync(saved: Dictionary, source_kind: String) -> void:
	model = PlayerInventory.new(saved)
	source = source_kind
	entries.clear()
	hover_item = {}
	cancel_drag()
	var candidates: Array = []
	if source == "delivery":
		for order in DeliveryOrders.ready(Session.state.get("deliveries", []), Time.get_unix_time_from_system()):
			for id in order.contents:
				if int(order.contents[id]) > 0: candidates.append(_entry(id, int(order.contents[id]), str(order.uid)))
	elif source.begins_with("ground:"):
		var chest_uid := source.trim_prefix("ground:")
		for chest in Session.state.get("ground_loot", []):
			if str(chest.get("uid", "")) != chest_uid: continue
			for item in chest.get("contents", []):
				if item is Dictionary and int(item.get("quantity", 0)) > 0: candidates.append(_stored_entry(item, chest_uid))
			break
	else:
		for id in model.data.loot:
			if int(model.data.loot[id]) > 0: candidates.append(_entry(id, int(model.data.loot[id]), ""))
	candidates.sort_custom(func(a, b): return InventoryGrid.rect(a).get_area() > InventoryGrid.rect(b).get_area())
	var rows := MIN_ROWS
	while rows <= maxi(MIN_ROWS, candidates.size() * 4 + 2):
		entries.clear()
		var size := Vector2i(COLUMNS, rows)
		var fits_all := true
		for item in candidates:
			if InventoryGrid.first_fit(item, entries, size): entries.append(item)
			else:
				fits_all = false
				break
		if fits_all:
			grid_size = size
			break
		rows += 1
	custom_minimum_size = Vector2(ORIGIN.x * 2 + COLUMNS * InventoryBoard.CELL, ORIGIN.y * 2 + grid_size.y * InventoryBoard.CELL)
	queue_redraw()

func _entry(id: String, quantity: int, source_uid: String) -> Dictionary:
	var result := ItemInstance.create(id, quantity)
	result.uid = "ground:%s:%s" % [source_uid if not source_uid.is_empty() else "supplies", id]
	result.source_uid = source_uid
	return result

func _stored_entry(item: Dictionary, source_uid: String) -> Dictionary:
	var result := item.duplicate(true)
	result.source_uid = source_uid
	return result

func cancel_drag() -> void:
	dragging = ""
	pending.clear()
	placement_error = ""
	cached_preview = ""
	if inventory_board != null: inventory_board.external_preview.clear(); inventory_board.queue_redraw()
	queue_redraw()

func item_at(pos: Vector2) -> Dictionary:
	for item in entries:
		var rect := InventoryGrid.rect(item)
		if Rect2(ORIGIN + Vector2(rect.position) * CELL, Vector2(rect.size) * CELL).has_point(pos): return item
	return {}

func item_rect(item: Dictionary) -> Rect2:
	var rect := InventoryGrid.rect(item)
	return Rect2(ORIGIN + Vector2(rect.position) * CELL, Vector2(rect.size) * CELL)

func _get_tooltip(at_position: Vector2) -> String:
	if not dragging.is_empty(): return ""
	hover_item = item_at(at_position)
	return "" if hover_item.is_empty() else ItemTooltip.describe(hover_item)

func _make_custom_tooltip(text: String) -> Object:
	if model == null or not dragging.is_empty() or hover_item.is_empty(): return null
	var current := _dragged() if not dragging.is_empty() else hover_item
	if current.is_empty() or ItemTooltip.describe(current) != text: return null
	return ItemTooltip.make(current)

func _gui_input(event: InputEvent) -> void:
	if model == null: return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var item := item_at(event.position)
		if not item.is_empty():
			dragging = item.uid
			split = event.shift_pressed and item.quantity > 1
			rotated = item.rotated
			pointer = event.position
			_preview()
			queue_redraw()
			accept_event()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or dragging.is_empty(): return
	if (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_R) or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT):
		var item := _dragged()
		if not item.is_empty() and ItemRegistry.get_item(item.id).can_rotate: rotated = not rotated
		_preview()
		queue_redraw()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		pointer = get_global_transform_with_canvas().affine_inverse() * event.position
		_preview(event.position)
		queue_redraw()
	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pointer = get_global_transform_with_canvas().affine_inverse() * event.position
		_preview(event.position)
		if not pending.is_empty() and placement_error.is_empty(): requested.emit(pending.action, pending.args)
		elif not placement_error.is_empty(): feedback.emit(placement_error)
		cancel_drag()
		get_viewport().set_input_as_handled()

func _dragged() -> Dictionary:
	for item in entries:
		if item.uid == dragging: return item
	return {}

func _preview(viewport_position: Vector2 = Vector2(-1, -1)) -> void:
	var item := _dragged()
	if item.is_empty() or inventory_board == null: return
	var quantity: int = maxi(1, int(item.quantity / 2)) if split else int(item.quantity)
	var target_position := get_viewport().get_mouse_position() if viewport_position.x < 0 else viewport_position
	var board_position := inventory_board.get_global_transform_with_canvas().affine_inverse() * target_position
	var action := "pickup" if source == "supplies" else "collect_delivery"
	if source.begins_with("ground:"): action = "collect_ground_loot"
	var args := {"id": item.id, "quantity": quantity}
	if source == "delivery": args.delivery = item.source_uid
	if source.begins_with("ground:"):
		args.chest = item.source_uid
		args.item_uid = item.uid
	if inventory_board.get_global_rect().has_point(target_position):
		var cell := Vector2i(((board_position - inventory_board.GRID_ORIGIN) / inventory_board.CELL).floor())
		args.x = cell.x
		args.y = cell.y
		args.rotated = rotated
	var key := JSON.stringify([action, args])
	if key == cached_preview: return
	cached_preview = key
	pending = {"action": action, "args": args}
	placement_error = "Drop the item onto the backpack grid."
	if args.has("x"):
		if source == "supplies": placement_error = model.transact("pickup", args, true)
		elif source.begins_with("ground:"):
			var candidate := PlayerInventory.new(model.data)
			placement_error = "" if candidate.add_item(item.id, quantity, item.properties, {"x":args.x,"y":args.y,"rotated":args.rotated}, item.uid) else "That space is occupied or there is not enough inventory space."
		else:
			var candidate := PlayerInventory.new(model.data)
			placement_error = "" if candidate.add_item(item.id, quantity, item.properties, {"x":args.x,"y":args.y,"rotated":args.rotated}) else "That space is occupied or there is not enough inventory space."

func _draw() -> void:
	var font := ThemeDB.fallback_font
	for y in grid_size.y:
		for x in grid_size.x:
			var rect := Rect2(ORIGIN + Vector2(x,y) * InventoryBoard.CELL, Vector2.ONE * (InventoryBoard.CELL - 2))
			draw_rect(rect, Color("182629"))
			draw_rect(rect, Color("485351"), false)
	for item in entries: _draw_item(item, item_rect(item).grow(-3))
	if not dragging.is_empty() and not pending.is_empty() and pending.args.has("x"):
		var footprint := ItemRegistry.get_item(_dragged().id).footprint(rotated)
		var board_position := inventory_board.get_global_transform_with_canvas().affine_inverse() * get_viewport().get_mouse_position()
		var cell := Vector2i(((board_position - inventory_board.GRID_ORIGIN) / inventory_board.CELL).floor())
		var rect := Rect2(inventory_board.GRID_ORIGIN + Vector2(cell) * inventory_board.CELL, Vector2(footprint) * inventory_board.CELL)
		var color := Color("69dba0") if placement_error.is_empty() else Color("f07777")
		inventory_board.set_external_preview(rect, color)
	else:
		if inventory_board != null and not inventory_board.external_preview.is_empty():
			inventory_board.external_preview.clear()
			inventory_board.queue_redraw()

func _draw_item(item: Dictionary, rect: Rect2) -> void:
	var d := ItemRegistry.get_item(item.id)
	var rarity_color := Rarity.color_for(ItemInstance.rarity(item))
	var color := Color("6b6952") if source == "supplies" else Color("59687e")
	if item.uid == dragging: color.a = 0.4
	draw_rect(rect, color)
	draw_rect(rect, rarity_color, false, 2.0)
	if d.icon: draw_texture_rect(d.icon, Rect2(rect.position + Vector2(rect.size.x/2-16, rect.size.y/2-16), Vector2(32,32)), false)
	if d.max_stack > 1: draw_string(ThemeDB.fallback_font, rect.position + Vector2(2, rect.size.y-2), str(item.quantity), HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x-4, 9, Color.WHITE)
