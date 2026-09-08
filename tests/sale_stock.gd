extends Node
var game: Node
var failures := 0
var checks := 0
var platform := ""

func check(condition: bool, label: String) -> void:
	checks += 1
	if condition: print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func command(action: String, args: Dictionary) -> void:
	Session.request_action("sale_platform",{"platform":platform,"action":action,"args":args})

func listings() -> Array:
	return Session.state.sale_stock.get(platform,[])

func _ready() -> void:
	SaveStore.path = "user://tests/sale_stock.json"
	game = load("res://scenes/main.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	check(Session.start_host(true,false) == OK,"Single-player game starts")
	Session.players[1].pos = Vector3(0,0.2,-1.5)
	Session.request_action("buy",{"shop":1})
	game.local_player.teleport(Vector3(0,0.2,29.2))
	Session.request_action("place",{"id":"small_table","x":2,"z":2,"turn":1})
	check(Session.state.furniture.size() == 1,"Existing table placement remains functional")
	var entry: Dictionary = Session.state.furniture[0]
	platform = SaleStock.key(entry)
	check(SaleStock.capacity(entry) == 24,"Small table has 24 display cells")
	check(SaleStock.capacity({"id":"basic_shelf"}) == 24 and SaleStock.capacity({"id":"large_shelf"}) == 96,"Shelf capacity includes separate tiers")
	var inventory := Session.inventory_for(1)
	inventory.add_item("health_potion",20)
	inventory.add_item("iron_sword",1,{"engraving":"Test blade"})
	inventory.add_item("wooden_shield",1)
	Session.state.inventories["1"] = inventory.data
	var potion: Dictionary = inventory.data.items[0]
	var sword: Dictionary = inventory.data.items[1]
	var shield: Dictionary = inventory.data.items[2]
	game.local_player.teleport(Vector3(-1.5,0.2,27.0))
	var gold: int = Session.state.money
	command("stock",{"uid":potion.uid,"quantity":12,"price":12})
	check(listings().size() == 1 and Session.inventory_for(1).find_item(potion.uid).quantity == 8,"Stocking splits stack and transfers only chosen quantity")
	check(listings()[0].units.size() == 12 and SaleStock.used(listings()) == 12,"Twelve potions occupy twelve footprints")
	check(Session.state.money == gold,"Listing is not a completed sale and grants no gold")
	var listing_uid: String = listings()[0].item.uid
	check(listing_uid != potion.uid,"Split listing receives independent instance ID")
	check(SaleStock.buy_price("health_potion") == 8 and listings()[0].price - SaleStock.buy_price("health_potion") == 4,"Reference buy price and potential unit profit")
	command("price",{"uid":listing_uid,"price":15})
	check(listings()[0].price == 15,"Listing price can be updated")
	var snapshot := JSON.stringify(Session.state)
	command("price",{"uid":listing_uid,"price":0})
	check(JSON.stringify(Session.state) == snapshot,"Invalid price rejected without mutation")
	command("stock",{"uid":potion.uid,"quantity":8,"price":12})
	command("stock",{"uid":sword.uid,"quantity":1,"price":40})
	check(listings().size() == 3 and SaleStock.used(listings()) == 23,"Larger sword occupies three display cells")
	check(Session.inventory_for(1).find_item(sword.uid).is_empty() and listings()[2].item.uid == sword.uid,"Whole unique item retains identity on display")
	snapshot = JSON.stringify(Session.state)
	command("stock",{"uid":shield.uid,"quantity":1,"price":30})
	check(JSON.stringify(Session.state) == snapshot,"Oversized stock rejected atomically on almost-full table")
	var normal_path := SaveStore.path
	SaveStore.path = normal_path.path_join("blocked.json")
	command("price",{"uid":listing_uid,"price":17})
	check(JSON.stringify(Session.state) == snapshot,"Failed save rolls back listing price")
	command("remove",{"uid":sword.uid})
	check(JSON.stringify(Session.state) == snapshot,"Failed withdrawal save preserves both containers")
	SaveStore.path = normal_path
	var original_inventory: Dictionary = Session.state.inventories["1"].duplicate(true)
	var full := PlayerInventory.new()
	full.add_item("iron_ore",1200)
	Session.state.inventories["1"] = full.data
	snapshot = JSON.stringify(Session.state)
	command("remove",{"uid":sword.uid})
	check(JSON.stringify(Session.state) == snapshot,"Full backpack leaves listing safely for sale")
	Session.state.inventories["1"] = original_inventory
	command("remove",{"uid":sword.uid})
	check(Session.inventory_for(1).find_item(sword.uid).properties.engraving == "Test blade","Withdrawal preserves custom properties and unique ID")
	game.ui.show_sale_platform(platform)
	check(game.ui.modal_open() and game.ui.sale_panel.listed.get_child_count() == 2,"Sale management UI shows saved listings")
	if "--visual" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://tests/sale-panel.png")
	game.ui.close()
	game.local_player.camera.look_at(GridRules.center(entry,Vector3(-3,0,24))+Vector3(0,0.65,0))
	await get_tree().physics_frame
	await get_tree().physics_frame
	var target: Interactable = game.local_player.look_target()
	check(target != null and target.kind == "sale_platform" and target.platform_id == platform,"Rotated table is interactable through player ray")
	check(target != null and "FOR SALE" in target.prompt(),"Stocked table advertises for-sale status")
	if "--visual" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://tests/sale-display.png")
	Session.players[1].pos = Vector3(12,0.2,4)
	snapshot = JSON.stringify(Session.state)
	command("price",{"uid":listing_uid,"price":99})
	check(JSON.stringify(Session.state) == snapshot,"Remote stocking requests rejected")
	Session.players[1].pos = Vector3(-1.5,0.2,27)
	Session.save_game(false)
	Session.leave()
	Session.start_host(false,false)
	check(listings().size() == 2 and listings()[0].price == 15 and listings()[0].units.size() == 12,"Continue restores stock quantities prices and unit positions")
	var bad := Session.state.duplicate(true)
	bad.sale_stock[platform][0].units[1] = bad.sale_stock[platform][0].units[0].duplicate(true)
	check(not SaveStore.validate(bad),"Overlapping display positions rejected on load")
	bad = Session.state.duplicate(true)
	bad.sale_stock[platform][0].item.uid = Session.inventory_for(1).data.items[0].uid
	check(not SaveStore.validate(bad),"Duplicate ownership across backpack and display rejected")
	for listing in listings().duplicate(true): command("remove",{"uid":listing.item.uid})
	check(listings().is_empty() and SaleStock.used(listings()) == 0,"Removing final listing clears for-sale stock")
	check(Session.state.money == gold,"Stocking repricing and withdrawal never alter gold")
	Session.leave()
	print("SALE_STOCK RESULT: %d failure(s), %d checks" % [failures,checks])
	get_tree().quit(failures)
