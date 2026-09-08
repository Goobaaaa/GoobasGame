extends Node
var game: Node
var failures := 0
var visual := false

func check(condition: bool, label: String) -> void:
	if condition: print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func frame_wait(seconds: float = 0.12) -> void:
	await get_tree().create_timer(seconds).timeout

func capture(filename: String) -> void:
	if not visual: return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/" + filename + ".png")

func key(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	game._unhandled_input(event)
	await frame_wait()

func _ready() -> void:
	visual = "--visual" in OS.get_cmdline_user_args()
	SaveStore.path = "user://tests/smoke_save.json"
	game = preload("res://scenes/main.tscn").instantiate()
	game.running_test = true
	add_child(game)
	await frame_wait()
	check(game.ui.modal_kind == "main","First launch shows main menu")
	await capture("01_menu")
	check(Session.start_host(true,false) == OK,"New save starts")
	await frame_wait()
	check(FileAccess.file_exists(SaveStore.path),"New save written")
	check(game.world.imp == null,"IMP absent before purchase")
	check(game.local_player.position.z > 3.5,"Street spawn")
	Session.request_action("enter",{"shop":1})
	await frame_wait()
	check(game.local_player.position.z < 8,"Unpurchased interior locked")
	var start_z: float = game.local_player.position.z
	Input.action_press("forward")
	await frame_wait(1.48)
	Input.action_release("forward")
	check(game.local_player.position.z < start_z - 4.5,"WASD movement and floor collision")
	Input.action_press("jump")
	await frame_wait(0.18)
	Input.action_release("jump")
	check(game.local_player.position.y > 0.3,"Jump")
	await frame_wait(0.7)
	var target: Interactable = game.local_player.look_target()
	check(target != null and target.shop_id == 1,"Camera ray finds shop interaction")
	await key("interact")
	check(game.ui.modal_kind == "purchase","E opens purchase prompt")
	# Exercise the actual purchase button.
	for child in game.ui.content.get_children():
		if child is Button and child.text.begins_with("Purchase"):
			child.pressed.emit()
			break
	await frame_wait()
	check(Session.state.purchased_shop == 1 and Session.state.money == 700,"Shop purchase charges once")
	check(game.world.imp != null,"Purchase spawns IMP")
	check(game.ui.modal_kind == "shop_naming" and game.ui.shop_name_input != null,"Shop naming window appears")
	game.ui.shop_name_input.text = ""
	check(game.ui.shop_name_feedback.text != " " and game.ui.shop_name_feedback.text != "","Empty shop name rejected")
	game.ui.shop_name_input.text = "   "
	check(game.ui.shop_name_feedback.text != " " and game.ui.shop_name_feedback.text != "","Whitespace-only shop name rejected")
	check(ShopNaming.validate("A".repeat(31)) != "","Overlong shop name rejected")
	game.ui.shop_name_input.text = "The Silver Griffin"
	for child in game.ui.content.get_children():
		if child is Button and child.name == "ConfirmShopName":
			child.pressed.emit()
			break
	await frame_wait()
	check(Session.state.shop_name == "The Silver Griffin" and game.world.shop_signs[1].text == "THE SILVER GRIFFIN","Shop name updates the exterior sign")
	Session.request_action("buy",{"shop":1})
	check(Session.state.money == 700,"Duplicate purchase rejected")
	await capture("02_street")
	await key("interact")
	check(game.world.interior.contains(game.local_player.position),"E enters purchased interior")
	await key("build")
	check(game.ui.modal_kind == "furniture","B opens furniture catalog")
	game.placement.select("small_table")
	game.ui.close()
	game.local_player.head.rotation.x = -0.65
	await frame_wait()
	check(game.placement.ghost != null and game.placement.ghost.visible,"Ghost preview appears on floor")
	check(game.placement.valid,"Preview finds legal floor cells")
	await key("rotate")
	check(game.placement.turn == 1,"90 degree rotation")
	check(game.placement.valid,"Rotated preview remains legal")
	await capture("03_placement")
	game.placement.place()
	await frame_wait()
	check(Session.state.furniture.size() == 1 and Session.state.money == 640,"Table placed and charged")
	check(game.world.interior.furniture_root.get_child_count() == 1,"Furniture rendered with collision")
	game.placement.place()
	check(Session.state.furniture.size() == 1,"Overlap cannot place twice")
	game.placement.cancel()
	check(game.placement.selected == "","Placement cancel")
	check(GridRules.size_for("small_table",0) == Vector2i(3,2),"Table footprint 3 by 2")
	check(GridRules.size_for("small_table",1) == Vector2i(2,3),"Rotated footprint 2 by 3")
	check(GridRules.validate("large_shelf",10,0,0,[]) != "","Wall bounds rejected")
	check(GridRules.validate("counter",4,10,0,[]) != "","Entrance kept clear")
	check(GridRules.validate("wall_shelf",2,3,0,[]) != "","Floating wall shelf rejected")
	check(GridRules.validate("wall_shelf",2,0,2,[]) == "","Wall-aligned shelf allowed")
	var before: int = Session.state.money
	Session.request_action("place",{"id":"storage_crate","x":5,"z":8,"turn":0})
	check(Session.state.money == before,"Entrance placement rejected without charge")
	Session.request_action("place",{"id":"storage_crate","x":5,"z":7,"turn":0})
	check(Session.state.money == before,"Occupied footprint rejected without charge")
	for id in Catalog.FURNITURE:
		var model := FurnitureFactory.create(id,false)
		check(model.get_child_count() >= 2,"GLB and collision: " + id)
		model.free()
	game.local_player.teleport(Vector3(0,0.1,29.2))
	Session.request_action("exit")
	await frame_wait()
	check(game.local_player.position.z < 8,"Exit returns to street")
	game.local_player.teleport(Vector3(1.9,0.1,-1.0))
	await frame_wait()
	game.ui.show_stock()
	check(game.ui.order_labels.size() == 8,"Eight stock products in UI")
	check(game.ui.stock_panel.cards.size() == 8 and game.ui.stock_panel.grid.columns >= 1,"Stock is displayed as a responsive card grid")
	for id in Catalog.PRODUCTS: check(ItemRegistry.get_item(id).icon != null,"Stock card icon: " + id)
	var potion_card: StockItemCard = game.ui.stock_panel.cards["health_potion"]
	potion_card.quantity_input.value = 3
	check("24" in potion_card.total_label.text and not potion_card.buy_button.disabled,"Card quantity and purchase total update")
	check(potion_card._make_custom_tooltip(potion_card._get_tooltip(Vector2.ZERO)) != null,"Stock card reuses item tooltip")
	potion_card.quantity_input.value = 0
	var immediate_gold := int(Session.state.money)
	potion_card.quantity_input.value = 1
	potion_card.buy_button.pressed.emit()
	await frame_wait()
	var bought_potion := false
	for item in Session.inventory_for(1).data.items:
		if item.id == "health_potion": bought_potion = true
	check(Session.state.money == immediate_gold - 8 and bought_potion,"Card Buy adds items and charges atomically")
	Session.request_action("order",{"id":"health_potion","quantity":3})
	await frame_wait()
	check(Session.state.ordered_stock.get("health_potion",0) == 3 and Session.state.money == 608,"Order quantity, payment, and ledger")
	var gold: int = Session.state.money
	Session.request_action("order",{"id":"iron_sword","quantity":99})
	check(Session.state.money == gold,"Unaffordable order rejected")
	Session.request_action("order",{"id":"bread","quantity":-5})
	check(Session.state.money == gold,"Invalid quantity rejected")
	await capture("04_stock")
	Session.save_game()
	var data := SaveStore.read_save()
	check(data.money == 608 and data.furniture.size() == 1 and data.ordered_stock.health_potion == 3 and data.shop_name == "The Silver Griffin","Save round trip")
	Session.leave()
	check(Session.start_host(false,false) == OK,"Continue loads save")
	await frame_wait()
	check(game.world.imp != null and game.world.interior.furniture_root.get_child_count() == 1 and game.world.shop_signs[1].text == "THE SILVER GRIFFIN","Loaded world restores shop, IMP, name, and furniture")
	check(game.local_player.position.distance_to(Vector3(1.9,0,-1)) < 0.3,"Player position restored")
	game.local_player.teleport(Vector3(12,0.1,4))
	Session.request_action("order",{"id":"bread","quantity":1})
	check(Session.state.money == 608,"Remote stock order rejected")
	Session.leave()
	# Corrupt primary falls back to previous valid backup.
	var file := FileAccess.open(SaveStore.path,FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	check(not SaveStore.read_save().is_empty(),"Corrupted primary recovers backup")
	print("SMOKE RESULT: %d failure(s)" % failures)
	get_tree().quit(1 if failures else 0)
