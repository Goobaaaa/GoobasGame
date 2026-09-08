class_name InventoryPanel
extends PanelContainer
var board: InventoryBoard
var ground_board: GroundLootBoard
var title: Label
var footer: Label
var loot_list: Control
var ground_title: Label
var show_loot := false
var loot_source := "supplies"
var game_ui: GameUI

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	offset_left = -630
	offset_right = 630
	offset_top = -325
	offset_bottom = 325
	var column := VBoxContainer.new()
	add_child(column)
	var top := HBoxContainer.new()
	column.add_child(top)
	title = Label.new()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size",24)
	top.add_child(title)
	var close_button := Button.new()
	close_button.text = "Close [I]"
	close_button.pressed.connect(game_ui.close)
	top.add_child(close_button)
	var body_scroll := ScrollContainer.new()
	body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body_scroll)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	body.custom_minimum_size.x = 1208
	body_scroll.add_child(body)
	var inventory_column := VBoxContainer.new()
	inventory_column.custom_minimum_size.x = 930
	body.add_child(inventory_column)
	board = InventoryBoard.new()
	board.requested.connect(func(action, args): Session.request_action("inventory",{"action":action,"args":args}))
	board.feedback.connect(game_ui.notify)
	inventory_column.add_child(board)
	var help := Label.new()
	help.text = "Drag to move / equip · R or right click while dragging: rotate · Shift-drag: split half · Esc: cancel"
	help.add_theme_font_size_override("font_size",14)
	inventory_column.add_child(help)
	footer = Label.new()
	footer.add_theme_font_size_override("font_size",14)
	inventory_column.add_child(footer)
	var ground_column := VBoxContainer.new()
	ground_column.custom_minimum_size.x = 272
	ground_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(ground_column)
	ground_title = Label.new()
	ground_title.name = "GroundTitle"
	ground_title.text = "GROUND ITEMS"
	ground_title.add_theme_font_size_override("font_size",18)
	ground_title.tooltip_text = "Drag items onto the backpack grid to collect them."
	ground_column.add_child(ground_title)
	var ground_scroll := ScrollContainer.new()
	ground_scroll.name = "GroundScroll"
	ground_scroll.custom_minimum_size = Vector2(272, 0)
	ground_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ground_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ground_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	ground_scroll.tooltip_text = "Drag items onto the backpack grid to collect them."
	ground_column.add_child(ground_scroll)
	ground_board = GroundLootBoard.new()
	ground_board.inventory_board = board
	ground_board.requested.connect(func(action, args):
		if action == "pickup": Session.request_action("inventory",{"action":action,"args":args})
		else: Session.request_action(action,args))
	ground_board.feedback.connect(game_ui.notify)
	ground_scroll.add_child(ground_board)
	loot_list = ground_board
	hide()

func refresh() -> void:
	if not is_instance_valid(board): return
	var inventory := Session.inventory_for(Session.local_id())
	board.sync(inventory.data)
	ground_title.visible = show_loot
	ground_board.visible = show_loot
	ground_board.sync(inventory.data, loot_source)
	var d := inventory.dimensions()
	board.custom_minimum_size = Vector2(maxi(930,440+d.x*48),maxi(470,80+d.y*48))
	var name := "No backpack"
	if inventory.data.equipment.has("back"): name = ItemRegistry.get_item(inventory.data.equipment.back.id).display_name
	title.text = "%s  ·  %d × %d" % [name,d.x,d.y]
	var used := 0
	var weight := 0.0
	for item in inventory.data.items:
		used += InventoryGrid.rect(item).get_area()
		weight += ItemRegistry.get_item(item.id).weight * item.quantity
	footer.text = "%d / %d cells · %.1f carried weight · %d gold" % [used,d.x*d.y,weight,Session.state.money]
