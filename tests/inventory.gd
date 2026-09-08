extends Node
var failures := 0
var checks := 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if condition: print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func acquire(model: PlayerInventory, id: String, quantity: int = 1) -> Dictionary:
	check(model.transact("pickup",{"id":id,"quantity":quantity}).is_empty(),"Acquire " + id)
	for item in model.data.items:
		if item.id == id: return item
	return {}

func same_json(a: Dictionary, b: Dictionary) -> bool:
	# JSON loads numbers as floats; compare after applying the same conversion to both.
	return JSON.stringify(JSON.parse_string(JSON.stringify(a))) == JSON.stringify(JSON.parse_string(JSON.stringify(b)))

func mouse_to(pos: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	get_viewport().push_input(motion,true)
	await get_tree().process_frame

func mouse_button(pos: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = pos
	event.global_position = pos
	event.pressed = pressed
	get_viewport().push_input(event,true)
	await get_tree().process_frame

func edge_cases() -> void:
	var m := PlayerInventory.new()
	var first := acquire(m,"health_potion",12)
	acquire(m,"health_potion",20)
	check(m.transact("split",{"uid":first.uid,"quantity":5,"x":5,"y":3}).is_empty(),"Create partial merge target")
	var second: Dictionary = m.data.items[1]
	check(m.transact("move",{"uid":second.uid,"x":0,"y":0}).is_empty(),"Partial stack transfer")
	check(m.find_item(first.uid).quantity == 20 and m.find_item(second.uid).quantity == 7,"Stack overflow retained at source")
	var ore := acquire(m,"iron_ore",50)
	var old_first := m.find_item(first.uid).duplicate()
	var old_ore := ore.duplicate()
	check(m.transact("move",{"uid":first.uid,"x":ore.x,"y":ore.y}).is_empty(),"Compatible grid swap")
	check(m.find_item(ore.uid).x == old_first.x and m.find_item(first.uid).x == old_ore.x,"Swap preserves both items")
	check(m.add_item("iron_ore",1,{"quality":"refined"}),"Custom item properties accepted")
	check(m.data.items.back().quantity == 1 and m.data.items.back().properties.quality == "refined","Different properties do not stack")
	var snapshot := JSON.stringify(m.data)
	check(not m.add_item("iron_sword",30) and JSON.stringify(m.data) == snapshot,"Failed bulk pickup leaves no partial items")
	var sword := acquire(m,"iron_sword")
	var definition := ItemRegistry.get_item("iron_sword")
	definition.can_rotate = false
	check(not m.transact("move",{"uid":sword.uid,"x":3,"y":0,"rotated":true}).is_empty(),"Rotation-disabled definition respected")
	definition.can_rotate = true
	definition.requirements = {"strength":99}
	check(not m.transact("equip",{"uid":sword.uid,"slot":"main_hand"}).is_empty(),"Equipment requirements enforced")
	definition.requirements = {}
	check(m.transact("equip",{"uid":sword.uid,"slot":"main_hand"}).is_empty(),"Equip first weapon for swap")
	check(m.add_item("iron_sword",1),"Acquire replacement weapon")
	var replacement: Dictionary = m.data.items.back()
	check(m.transact("equip",{"uid":replacement.uid,"slot":"main_hand"}).is_empty(),"Swap equipped weapon back to inventory")
	check(not m.find_item(sword.uid).is_empty() and m.slot_for(replacement.uid) == "main_hand" and m.final_stats().damage == 12,"Equipment swap conserves items and stats")
	m = PlayerInventory.new()
	var pack := acquire(m,"large_backpack")
	check(m.transact("equip",{"uid":pack.uid,"slot":"back"}).is_empty(),"Prepare shrink repack")
	var potion := acquire(m,"health_potion",1)
	check(m.transact("move",{"uid":potion.uid,"x":9,"y":5}).is_empty(),"Move item beyond smaller backpack boundary")
	var small: Dictionary
	for item in m.data.items:
		if item.id == "small_backpack": small = item
	check(m.transact("equip",{"uid":small.uid,"slot":"back"}).is_empty() and m.dimensions() == Vector2i(6,4) and m.valid(),"Smaller backpack repacks safely when items fit")
	check(not m.transact("move",{"uid":small.uid,"x":4,"y":2}).is_empty(),"Cannot remove sole container into itself")
	var corrupted := m.data.duplicate(true)
	corrupted.items.append(corrupted.items[0].duplicate(true))
	check(not PlayerInventory.new(corrupted).valid(),"Duplicate instance IDs rejected")
	m = PlayerInventory.new()
	var medium := acquire(m,"medium_backpack")
	check(m.transact("equip",{"uid":medium.uid,"slot":"back"}).is_empty() and m.dimensions() == Vector2i(8,5),"Medium backpack dimensions")
	for id in ["iron_chestplate","leather_gloves","adventurer_cape","wooden_shield"]:
		var equipment := acquire(m,id)
		check(m.transact("equip",{"uid":equipment.uid,"slot":ItemRegistry.get_item(id).equipment_slots[0]}).is_empty(),"Equip " + id)
	check(m.final_stats().armour == 20 and m.final_stats().dexterity == 2 and m.final_stats().luck == 3,"Multiple equipment bonuses combine")
	check(ItemRegistry.get_item("health_potion").icon != null,"Definition icons loaded")

func _ready() -> void:
	SaveStore.path = "user://tests/inventory_save.json"
	edge_cases()
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for rarity in ItemRarity.TIERS:
		var generated := LootGenerator.create_item("iron_sword",1,0.0,rng,rarity)
		check(generated.rarity == rarity and not ItemTooltip.describe(generated).is_empty(),"Rarity instance and tooltip: " + rarity)
		check(ItemRarity.color_for(rarity) != ItemRarity.color_for(ItemRarity.COMMON) or rarity == ItemRarity.COMMON,"Rarity colour available: " + rarity)
	var common_sword := ItemInstance.create("iron_sword",1,{},ItemRarity.COMMON)
	var legendary_sword := ItemInstance.create("iron_sword",1,{},ItemRarity.LEGENDARY)
	check(ItemRegistry.get_item("iron_sword").effective_modifiers(legendary_sword).damage > ItemRegistry.get_item("iron_sword").effective_modifiers(common_sword).damage,"Rarity stat scaling increases power")
	var rare_stacks := PlayerInventory.new()
	check(rare_stacks.add_item("health_potion",1,{}, {}, "", ItemRarity.RARE) and rare_stacks.add_item("health_potion",1),"Rare and common item instances can be created")
	check(rare_stacks.data.items.size() == 2,"Different rarities do not stack together")
	check(ItemRarity.weights_for_stage("early")[ItemRarity.COMMON] == 75.0 and ItemRarity.weights_for_stage("late")[ItemRarity.ARTIFACT] == 1.0,"Progression rarity weights are configurable")
	var model := PlayerInventory.new()
	check(model.valid() and model.dimensions() == Vector2i(6,4),"Initial backpack valid")
	var potion := acquire(model,"health_potion",12)
	acquire(model,"health_potion",20)
	check(model.data.items.size() == 2 and model.data.items[0].quantity == 20 and model.data.items[1].quantity == 12,"Pickup merges then creates remainder")
	check(model.transact("split",{"uid":potion.uid,"quantity":5,"x":4,"y":3}).is_empty(),"Split to free cell")
	var split_item: Dictionary = model.data.items.back()
	check(model.transact("move",{"uid":split_item.uid,"x":0,"y":0}).is_empty(),"Merge dragged stack")
	check(model.data.items.size() == 2 and model.data.items[0].quantity == 20,"Merge consumes emptied source")
	var before := JSON.stringify(model.data)
	check(not model.transact("move",{"uid":potion.uid,"x":-1,"y":0}).is_empty() and JSON.stringify(model.data) == before,"Out of bounds atomic rejection")
	var sword := acquire(model,"iron_sword")
	check(model.transact("move",{"uid":sword.uid,"x":2,"y":2,"rotated":true}).is_empty(),"Rotate 1x3 into 3x1")
	before = JSON.stringify(model.data)
	check(not model.transact("move",{"uid":sword.uid,"x":0,"y":0,"rotated":true}).is_empty() and JSON.stringify(model.data) == before,"Multiple overlaps rejected without mutation")
	check(not model.transact("equip",{"uid":sword.uid,"slot":"head"}).is_empty(),"Wrong equipment slot rejected")
	check(model.transact("equip",{"uid":sword.uid,"slot":"main_hand"}).is_empty(),"Equip weapon")
	check(model.final_stats().damage == 12,"Weapon stats applied")
	check(model.transact("move",{"uid":sword.uid,"x":2,"y":2,"rotated":true}).is_empty(),"Unequip weapon")
	check(model.final_stats().damage == 0,"Weapon stats removed")
	var helmet := acquire(model,"iron_helmet")
	check(model.transact("equip",{"uid":helmet.uid,"slot":"head"}).is_empty(),"Equip armour")
	check(model.final_stats().armour == 8 and model.final_stats().strength == 2 and model.final_stats().movement_speed == 3,"Generic positive and negative stats")
	var large := acquire(model,"large_backpack")
	check(model.transact("equip",{"uid":large.uid,"slot":"back"}).is_empty() and model.dimensions() == Vector2i(10,6),"Upgrade backpack and retain old pack")
	var old_pack: Dictionary = {}
	for item in model.data.items:
		if item.id == "small_backpack": old_pack = item
	check(not old_pack.is_empty(),"Old backpack returned to inventory")
	for id in ["iron_chestplate","wooden_shield","leather_gloves","adventurer_cape","medium_backpack"]: acquire(model,id)
	before = JSON.stringify(model.data)
	check(model.transact("equip",{"uid":old_pack.uid,"slot":"back"}) == PlayerInventory.SPACE_ERROR and JSON.stringify(model.data) == before,"Too-small backpack rejected with exact message and zero loss")
	var restored := PlayerInventory.new(JSON.parse_string(JSON.stringify(model.data)))
	check(restored.valid() and same_json(restored.data,model.data),"JSON round trip preserves IDs rotation stacks equipment")
	var world := SaveStore.fresh()
	world.inventories = {"1":model.data}
	check(SaveStore.write(world) == OK and same_json(SaveStore.read_save().inventories["1"],model.data),"Inventory saved through backed-up world save")
	check(SaveStore.validate(SaveStore.fresh()),"Legacy saves accepted")
	var bad := model.data.duplicate(true)
	bad.items[0].id = "missing_definition"
	check(not PlayerInventory.new(bad).valid(),"Unknown definitions rejected safely")
	bad = model.data.duplicate(true)
	bad.items[0].quantity = 0.5
	check(not PlayerInventory.new(bad).valid(),"Malformed quantity rejected")
	# Real game integration, including input routing, pause, persistence, pickup authority.
	var game = load("res://scenes/main.tscn").instantiate()
	add_child(game)
	await get_tree().create_timer(0.2).timeout
	check(Session.start_host(true,true) == ERR_UNAVAILABLE and not Session.active,"LAN hosting disabled")
	check(Session.join_game("127.0.0.1") == ERR_UNAVAILABLE and not Session.joining,"LAN joining disabled")
	var menu_has_network := false
	for child in game.ui.content.get_children():
		if child is LineEdit or (child is Button and ("Host" in child.text or "Join" in child.text)): menu_has_network = true
	check(not menu_has_network,"Main menu has no multiplayer controls")
	check(Session.start_host(true,false) == OK,"Game starts with inventory extension")
	check(float(ProjectSettings.get_setting("gui/timers/tooltip_delay_sec")) <= 0.05,"Item tooltip delay is near-instant")
	Session.request_action("inventory",{"action":"pickup","args":{"id":"health_potion","quantity":12}})
	game.ui.show_inventory(true)
	await get_tree().create_timer(0.2).timeout
	check(game.ui.modal_open() and game.ui.inventory_panel.board.model.data.items.size() == 1,"Pickup visible in inventory UI")
	var board: InventoryBoard = game.ui.inventory_panel.board
	var ground: GroundLootBoard = game.ui.inventory_panel.ground_board
	check(ground.visible and ground.entries.size() > 0 and ground.entries[0].id == "large_backpack","Ground items use a grid with item footprints")
	var ground_item: Dictionary = ground.entries[0]
	var candidate := ground_item.duplicate(true)
	candidate.quantity = 1
	var drop_cell := Vector2i(-1,-1)
	for y in board.model.dimensions().y:
		for x in board.model.dimensions().x:
			candidate.x = x
			candidate.y = y
			if InventoryGrid.fits(candidate,board.model.data.items,board.model.dimensions()):
				drop_cell = Vector2i(x,y)
				break
		if drop_cell.x >= 0: break
	check(drop_cell.x >= 0,"Ground item has a free backpack target cell")
	var ground_source: Vector2 = ground.global_position + ground.item_rect(ground_item).position + Vector2(5,5)
	var backpack_target: Vector2 = board.global_position + board.GRID_ORIGIN + (Vector2(drop_cell)+Vector2(0.5,0.5))*board.CELL
	await mouse_to(ground_source)
	await mouse_button(ground_source,true)
	check(ground.dragging == ground_item.uid,"Ground item begins drag")
	await mouse_to(backpack_target)
	await mouse_button(backpack_target,false)
	var transferred_item: Dictionary = {}
	for item in Session.inventory_for(1).data.items:
		if item.id == ground_item.id:
			transferred_item = item
			break
	check(not transferred_item.is_empty() and int(Session.inventory_for(1).data.loot[ground_item.id]) == 0,"Ground drag transfers item into inventory")
	if not transferred_item.is_empty():
		check(int(transferred_item.x) == drop_cell.x and int(transferred_item.y) == drop_cell.y,"Ground drag preserves the requested backpack placement")
	check(ground.dragging.is_empty(),"Ground drag clears after authoritative transfer")
	var dragged: Dictionary = board.model.data.items[0]
	check(ItemTooltip.make({}) == null and ItemTooltip.describe({}).is_empty(),"Empty tooltip data safely rejected (crash regression)")
	check(ItemTooltip.make({"id":"unknown_item","quantity":1}) == null,"Unknown tooltip definition safely rejected")
	var tooltip_text := board._get_tooltip(board.GRID_ORIGIN + Vector2(10,10))
	check(not tooltip_text.is_empty() and ItemRegistry.get_item(dragged.id).display_name in tooltip_text,"Hover tooltip supplies the item name")
	var tooltip: Control = board._make_custom_tooltip(tooltip_text)
	check(tooltip != null,"Valid item creates tooltip")
	if tooltip != null: tooltip.free()
	board._get_tooltip(Vector2.ZERO)
	check(board._make_custom_tooltip(tooltip_text) == null,"Delayed tooltip after moving to empty space is safe")
	board._get_tooltip(board.GRID_ORIGIN + Vector2(10,10))
	board.sync(board.model.data)
	check(board._make_custom_tooltip(tooltip_text) == null,"Delayed tooltip after inventory refresh is safe")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = board.GRID_ORIGIN + Vector2(10,10)
	board._gui_input(press)
	check(board.dragging == dragged.uid,"Mouse press begins drag without removing source")
	board.pointer = board.GRID_ORIGIN + Vector2(48*3+1,48*2+1)
	board._preview()
	check(board.placement_error.is_empty(),"Drag preview accepts free grid footprint")
	board.requested.emit(board.pending.action,board.pending.args)
	check(Session.inventory_for(1).find_item(dragged.uid).x == 3,"Drag command commits through host and refreshes board")
	check(board.dragging.is_empty(),"Committed drag cleared on authoritative refresh")
	var open_key := InputEventAction.new()
	open_key.action = "inventory"
	open_key.pressed = true
	game._unhandled_input(open_key)
	check(not game.ui.modal_open(),"I closes inventory")
	game._unhandled_input(open_key)
	check(game.ui.inventory_panel.visible,"I opens inventory")
	await get_tree().process_frame
	var mouse_source: Vector2 = board.global_position + board.GRID_ORIGIN + Vector2(3*48+10,2*48+10)
	var mouse_target: Vector2 = board.global_position + board.GRID_ORIGIN + Vector2(4*48+10,2*48+10)
	await mouse_to(mouse_source)
	await mouse_button(mouse_source,true)
	check(board.dragging == dragged.uid,"Viewport mouse event starts drag")
	await mouse_to(mouse_target)
	await mouse_button(mouse_target,false)
	check(Session.inventory_for(1).find_item(dragged.uid).x == 4,"Viewport mouse release places item")
	var drop_source_item: Dictionary = Session.inventory_for(1).find_item(dragged.uid)
	var drop_source := board.global_position + board.item_rect(drop_source_item).position + Vector2(10,10)
	var drop_target := board.global_position + Vector2(board.size.x + 80, board.size.y / 2.0)
	await mouse_to(drop_source)
	await mouse_button(drop_source,true)
	await mouse_to(drop_target)
	check(board.pending.action == "drop" and board.placement_error.is_empty(),"Dragging outside the backpack previews a ground chest drop")
	await mouse_button(drop_target,false)
	var dropped_uid := ""
	if not Session.state.ground_loot.is_empty(): dropped_uid = Session.state.ground_loot.back().uid
	check(not dropped_uid.is_empty() and Session.inventory_for(1).find_item(dragged.uid).is_empty() and game.world.ground_loot_boxes.size() == 1,"Dropped item leaves the backpack and creates a ground chest")
	var dropped_chest: Interactable = game.world.ground_loot_boxes.get(dropped_uid)
	check(is_instance_valid(dropped_chest) and dropped_chest.kind == "ground_loot" and "Open dropped item chest" in dropped_chest.prompt(),"Dropped chest is interactable")
	game.ui.show_inventory(true,"ground:" + dropped_uid)
	await get_tree().process_frame
	ground = game.ui.inventory_panel.ground_board
	check(ground.entries.size() == 1 and ground.entries[0].uid == dragged.uid,"Dropped chest exposes the original item for re-looting")
	var reloot_item: Dictionary = ground.entries[0] if not ground.entries.is_empty() else {}
	var reloot_candidate := reloot_item.duplicate(true)
	reloot_candidate.quantity = 1
	var reloot_cell := Vector2i(-1,-1)
	for y in board.model.dimensions().y:
		for x in board.model.dimensions().x:
			reloot_candidate.x = x
			reloot_candidate.y = y
			if InventoryGrid.fits(reloot_candidate,board.model.data.items,board.model.dimensions()):
				reloot_cell = Vector2i(x,y)
				break
		if reloot_cell.x >= 0: break
	check(reloot_cell.x >= 0,"Dropped item has a free backpack target cell")
	var reloot_source := ground.global_position + ground.item_rect(reloot_item).position + Vector2(10,10)
	var reloot_target := board.global_position + board.GRID_ORIGIN + (Vector2(reloot_cell)+Vector2(0.5,0.5))*board.CELL
	await mouse_to(reloot_source)
	await mouse_button(reloot_source,true)
	await mouse_to(reloot_target)
	await mouse_button(reloot_target,false)
	check(Session.inventory_for(1).find_item(dragged.uid).x == reloot_cell.x and Session.state.ground_loot.is_empty(),"Dropped item can be dragged back into the backpack")
	check(game.world.ground_loot_boxes.is_empty(),"Ground chest disappears after its last item is collected")
	var saved_before_failure := Session.inventory_for(1).data
	var normal_path := SaveStore.path
	SaveStore.path = normal_path.path_join("blocked.json")
	Session.request_action("inventory",{"action":"move","args":{"uid":dragged.uid,"x":5,"y":2}})
	check(Session.inventory_for(1).data == saved_before_failure,"Failed save rolls back inventory transaction")
	SaveStore.path = normal_path
	var saved := Session.inventory_for(1).data
	game.ui.close()
	game.ui.show_inventory()
	check(game.ui.inventory_panel.board.model.data == saved,"Close and reopen retains state")
	Session.players[1].pos = Vector3(10,0,4)
	Session.request_action("inventory",{"action":"pickup","args":{"id":"iron_sword","quantity":1}})
	check(Session.inventory_for(1).data == saved,"Server rejects distant pickup")
	if "--visual" in OS.get_cmdline_user_args():
		Session.players[1].pos = Vector3(0,0.2,4)
		Session.request_action("inventory",{"action":"pickup","args":{"id":"large_backpack","quantity":1}})
		var visual_inventory := Session.inventory_for(1)
		for item in visual_inventory.data.items:
			if item.id == "large_backpack": Session.request_action("inventory",{"action":"equip","args":{"uid":item.uid,"slot":"back"}})
		for id in ["iron_sword","iron_helmet","iron_ore","wooden_shield","iron_chestplate","leather_gloves","adventurer_cape"]:
			Session.request_action("inventory",{"action":"pickup","args":{"id":id,"quantity":1}})
		for item in Session.inventory_for(1).data.items:
			if item.id == "iron_helmet" or item.id == "iron_sword": Session.request_action("inventory",{"action":"equip","args":{"uid":item.uid,"slot":"head" if item.id == "iron_helmet" else "main_hand"}})
		game.ui.show_inventory(true)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://tests/inventory.png")
		saved = Session.inventory_for(1).data
	Session.leave()
	check(Session.start_host(false,false) == OK and same_json(Session.inventory_for(1).data,saved),"Continue restores inventory")
	Session.leave()
	print("INVENTORY RESULT: %d failure(s), %d checks" % [failures,checks])
	get_tree().quit(failures)
