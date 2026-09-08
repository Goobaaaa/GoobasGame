class_name InventoryBoard
extends Control
const Rarity = preload("res://inventory/item_rarity.gd")
## Input and drawing only. No items leave their source until the server accepts a move.
signal requested(action: String, args: Dictionary)
signal feedback(message: String)
const CELL = 48
const GRID_ORIGIN = Vector2(440, 38)
const SLOT_POSITIONS = {"head":Vector2(145,38),"chest":Vector2(145,134),"legs":Vector2(145,230),"feet":Vector2(145,326),"hands":Vector2(12,134),"cape":Vector2(278,38),"back":Vector2(278,134),"main_hand":Vector2(12,326),"off_hand":Vector2(278,326)}
var model: PlayerInventory
var dragging := ""
var rotated := false
var split := false
var pointer := Vector2.ZERO
var hover_item: Dictionary = {}
var pending: Dictionary = {}
var placement_error := ""
var cached_preview := ""
var external_preview: Dictionary = {}

func _ready() -> void:
	custom_minimum_size = Vector2(930, 470)
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = "Item"

func sync(saved: Dictionary) -> void:
	hover_item = {}
	model = PlayerInventory.new(saved)
	cancel_drag()
	queue_redraw()

func cancel_drag() -> void:
	hover_item = {}
	dragging = ""
	pending.clear()
	cached_preview = ""
	external_preview.clear()
	queue_redraw()

func set_external_preview(rect: Rect2, color: Color) -> void:
	external_preview = {"rect":rect,"color":color}
	queue_redraw()

func slot_rect(slot: String) -> Rect2:
	var index := EquipmentRules.SLOTS.find(slot)
	return Rect2(SLOT_POSITIONS.get(slot, Vector2(12 + (index % 3) * 133, 422)), Vector2(120,84))

func item_at(pos: Vector2) -> Dictionary:
	if model == null: return {}
	for slot in model.data.equipment:
		if slot_rect(slot).has_point(pos): return model.data.equipment[slot]
	for item in model.data.items:
		if item_rect(item).has_point(pos): return item
	return {}

func item_rect(item: Dictionary) -> Rect2:
	var rect := InventoryGrid.rect(item)
	return Rect2(GRID_ORIGIN + Vector2(rect.position) * CELL, Vector2(rect.size) * CELL)

func _get_tooltip(at_position: Vector2) -> String:
	if not dragging.is_empty(): return ""
	hover_item = item_at(at_position)
	return "" if hover_item.is_empty() else ItemTooltip.describe(hover_item)

func _make_custom_tooltip(text: String) -> Object:
	# Godot requests this after a delay: don't assume _get_tooltip's item still exists.
	if model == null or not dragging.is_empty() or hover_item.is_empty(): return null
	var current := model.find_item(str(hover_item.get("uid", "")))
	if current.is_empty() or ItemTooltip.describe(current) != text: return null
	return ItemTooltip.make(current)

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or dragging.is_empty(): return
	if (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_R) or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT):
		if ItemRegistry.get_item(model.find_item(dragging).id).can_rotate: rotated = not rotated
		_preview()
		queue_redraw()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		cancel_drag()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pointer = get_global_transform_with_canvas().affine_inverse() * event.position
		_preview()
		if not pending.is_empty() and placement_error.is_empty(): requested.emit(pending.action, pending.args)
		elif not placement_error.is_empty(): feedback.emit(placement_error)
		cancel_drag()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		pointer = get_global_transform_with_canvas().affine_inverse() * event.position
		_preview()
		queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if model == null: return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var item := item_at(event.position)
		if not item.is_empty():
			dragging = item.uid
			rotated = item.rotated
			split = event.shift_pressed and item.quantity > 1 and model.slot_for(item.uid).is_empty()
			pointer = event.position
			_preview()
			queue_redraw()
		accept_event()

func _preview() -> void:
	if dragging.is_empty(): return
	var cell := Vector2i(((pointer - GRID_ORIGIN) / CELL).floor())
	var args := {"uid":dragging,"x":cell.x,"y":cell.y,"rotated":rotated}
	var action := "split" if split else "move"
	var equipment_slot := ""
	for slot in EquipmentRules.SLOTS:
		if slot_rect(slot).has_point(pointer):
			equipment_slot = slot
			break
	var in_backpack_grid := Rect2(GRID_ORIGIN,Vector2(model.dimensions()) * CELL).has_point(pointer)
	if not equipment_slot.is_empty():
		action = "equip"
		args.slot = equipment_slot
	elif not in_backpack_grid:
		action = "drop"
		args = {"uid":dragging,"quantity":int(model.find_item(dragging).quantity / 2) if split else int(model.find_item(dragging).quantity),"rotated":rotated}
	else:
		if split: args.quantity = int(model.find_item(dragging).quantity / 2)
	var key := JSON.stringify([action,args])
	if key == cached_preview: return
	cached_preview = key
	pending = {"action":action,"args":args}
	placement_error = model.transact(action,args,true)

func _draw() -> void:
	if model == null: return
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(12,22), "EQUIPMENT", HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("e6c990"))
	draw_string(font, Vector2(440,22), "BACKPACK", HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("e6c990"))
	# A subdued mannequin behind independent equipment slots.
	draw_circle(Vector2(205,88),25,Color("394443"))
	draw_line(Vector2(205,110),Vector2(205,340),Color("394443"),35)
	for slot in EquipmentRules.SLOTS:
		var rect := slot_rect(slot)
		draw_rect(rect,Color("182629"))
		draw_rect(rect,Color("7b755c"),false,1)
		draw_string(font,rect.position+Vector2(6,17),slot.replace("_"," ").to_upper(),HORIZONTAL_ALIGNMENT_LEFT,110,12,Color("c7b58d"))
		if model.data.equipment.has(slot): _draw_item(model.data.equipment[slot],Rect2(rect.position+Vector2(3,24),rect.size-Vector2(6,27)))
	var dimensions := model.dimensions()
	for y in dimensions.y:
		for x in dimensions.x:
			var rect := Rect2(GRID_ORIGIN+Vector2(x,y)*CELL,Vector2.ONE*(CELL-2))
			draw_rect(rect,Color("142226"))
			draw_rect(rect,Color("485351"),false)
	for item in model.data.items: _draw_item(item,item_rect(item).grow(-3))
	var dropping_outside := false
	if not dragging.is_empty() and not pending.is_empty():
		var color := Color("69dba0") if placement_error.is_empty() else Color("f07777")
		if pending.action == "drop":
			dropping_outside = true
			draw_string(font,Vector2(440,452),"Drop to create a ground chest",HORIZONTAL_ALIGNMENT_LEFT,480,14,color)
		else:
			var rect: Rect2
			if pending.action == "equip": rect = slot_rect(pending.args.slot)
			else:
				var footprint := ItemRegistry.get_item(model.find_item(dragging).id).footprint(rotated)
				rect = Rect2(GRID_ORIGIN + Vector2(pending.args.x,pending.args.y)*CELL,Vector2(footprint)*CELL)
			draw_rect(rect,Color(color,0.25))
			draw_rect(rect,color,false,3)
			draw_string(font,pointer+Vector2(12,-10),"Split half" if split else "Move",HORIZONTAL_ALIGNMENT_LEFT,-1,14,color)
	if not external_preview.is_empty():
		var preview_color: Color = external_preview.color
		draw_rect(external_preview.rect, Color(preview_color, 0.25))
		draw_rect(external_preview.rect, preview_color, false, 3)
	var stats := model.final_stats()
	var summary: Array[String] = []
	for key in stats: summary.append("%s %s" % [str(key).capitalize(),str(stats[key])])
	if not dropping_outside: draw_string(font,Vector2(12,452)," · ".join(summary),HORIZONTAL_ALIGNMENT_LEFT,910,14,Color("c8d1c4"))

func _draw_item(item: Dictionary, rect: Rect2) -> void:
	var d := ItemRegistry.get_item(item.id)
	var rarity_color := Rarity.color_for(ItemInstance.rarity(item))
	var color := Color("557776")
	if d.category == "Weapon": color = Color("69778c")
	elif d.category == "Backpack": color = Color("8c7655")
	elif d.category == "Consumable": color = Color("994e60")
	if item.uid == dragging: color.a = 0.4
	draw_rect(rect,color)
	draw_rect(rect,rarity_color,false,2.0)
	if d.icon:
		draw_texture_rect(d.icon,Rect2(rect.position+Vector2(rect.size.x/2-16,rect.size.y/2-16),Vector2(32,32)),false)
	if d.max_stack > 1: draw_string(ThemeDB.fallback_font,rect.position+Vector2(3,rect.size.y-4),"%d/%d" % [item.quantity,d.max_stack],HORIZONTAL_ALIGNMENT_RIGHT,rect.size.x-6,11,Color.WHITE)
