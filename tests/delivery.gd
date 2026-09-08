extends Node
var failures := 0
var checks := 0
var game: Node

func check(condition: bool, label: String) -> void:
	checks += 1
	if condition: print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func collect(uid: String, id: String, count: int) -> void:
	Session.request_action("collect_delivery",{"delivery":uid,"id":id,"quantity":count})

func _ready() -> void:
	SaveStore.path = "user://tests/delivery_save.json"
	game = load("res://scenes/main.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	check(Session.start_host(true,false) == OK,"New game starts")
	check(is_instance_valid(game.world.supplies_box),"Starter chest exists while it has items")
	check(DeliveryOrders.quote({"health_potion":3,"bread":2}) == 30,"Basket total sums every product")
	check(DeliveryOrders.quote({"bread":1.5}) == -1 and DeliveryOrders.quote({}) == -1,"Malformed and empty baskets rejected")
	var timed := DeliveryOrders.create({"bread":1},1000.0)
	check(timed.due_at == 1300.0 and DeliveryOrders.ready([timed],1299).is_empty() and DeliveryOrders.ready([timed],1300).size() == 1,"Exact five-minute arrival boundary")
	Session.players[1].pos = Vector3(0,0.2,-1.5)
	Session.request_action("buy",{"shop":1})
	Session.players[1].pos = Vector3(1.9,0.2,-2)
	game.ui.show_stock()
	var basket: StockOrderPanel
	for child in game.ui.content.get_children():
		if child is StockOrderPanel: basket = child
	basket.quantities.health_potion.value = 3
	basket.quantities.bread.value = 2
	check("30 gold" in basket.total_label.text and not basket.checkout.disabled,"UI previews affordable order total")
	basket.quantities.iron_sword.value = 99
	check(basket.checkout.disabled,"UI disables unaffordable order")
	var unchanged := JSON.stringify(Session.state)
	Session.request_action("order",{"items":basket.basket()})
	check(JSON.stringify(Session.state) == unchanged,"Unaffordable order changes neither gold nor deliveries")
	basket.quantities.iron_sword.value = 0
	basket.checkout.pressed.emit()
	check(Session.state.money == 670 and Session.state.deliveries.size() == 1,"Successful basket charged once and queued once")
	check(basket.basket().is_empty(),"Basket clears after successful purchase")
	var uid: String = Session.state.deliveries[0].uid
	check(not is_instance_valid(game.world.delivery_box),"Delivery box absent before arrival")
	unchanged = JSON.stringify(Session.state)
	collect(uid,"bread",1)
	check(JSON.stringify(Session.state) == unchanged,"Early collection rejected")
	var due: float = Session.state.deliveries[0].due_at
	Session.leave()
	Session.start_host(false,false)
	check(Session.state.deliveries[0].due_at == due and Session.state.money == 670,"Reload preserves deadline without charging again")
	Session.state.deliveries[0].due_at = Time.get_unix_time_from_system()-1
	Session.refresh_deliveries()
	check(is_instance_valid(game.world.delivery_box),"Arrived delivery creates physical box")
	check(game.world.delivery_box.position == FantasyWorld.delivery_position(1),"Delivery box directly below Pip")
	game.ui.close()
	game.local_player.teleport(Vector3(1.9,0.2,-0.8))
	game.local_player.camera.look_at(game.world.delivery_box.global_position)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(game.local_player.look_target() == game.world.delivery_box,"Player ray can interact with box beneath Pip")
	if "--visual" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://tests/delivery-box.png")
	Session.players[1].pos = Vector3(12,0.2,4)
	unchanged = JSON.stringify(Session.state)
	collect(uid,"bread",1)
	check(JSON.stringify(Session.state) == unchanged,"Distant pickup rejected")
	Session.players[1].pos = Vector3(1.9,0.2,-2)
	var original_inventory: Dictionary = Session.state.inventories["1"].duplicate(true)
	var full := PlayerInventory.new()
	check(full.add_item("health_potion",480),"Prepare full backpack")
	Session.state.inventories["1"] = full.data
	unchanged = JSON.stringify(Session.state)
	collect(uid,"bread",1)
	check(JSON.stringify(Session.state) == unchanged and is_instance_valid(game.world.delivery_box),"Full backpack preserves uncollected goods and box")
	Session.state.inventories["1"] = original_inventory
	var normal_path := SaveStore.path
	SaveStore.path = normal_path.path_join("blocked.json")
	unchanged = JSON.stringify(Session.state)
	collect(uid,"bread",1)
	check(JSON.stringify(Session.state) == unchanged,"Pickup save failure rolls back inventory and delivery together")
	Session.request_action("order",{"items":{"bread":1}})
	check(JSON.stringify(Session.state) == unchanged,"Order save failure rolls back charge and queue together")
	SaveStore.path = normal_path
	collect(uid,"bread",1)
	check(Session.state.deliveries[0].contents.bread == 1 and is_instance_valid(game.world.delivery_box),"Partial collection retains remaining goods and box")
	game.ui.show_inventory(true,"delivery")
	check(game.ui.inventory_panel.ground_board.entries.size() == 2 and game.ui.inventory_panel.ground_board.entries[0].source_uid == uid and game.ui.inventory_panel.ground_board.entries[1].source_uid == uid,"Ground grid lists all remaining shipment contents")
	Session.leave()
	Session.start_host(false,false)
	check(Session.state.deliveries[0].contents.bread == 1 and is_instance_valid(game.world.delivery_box),"Partially collected box survives reload")
	Session.players[1].pos = Vector3(1.9,0.2,-2)
	Session.request_action("order",{"items":{"apple":1}})
	collect(uid,"bread",1)
	collect(uid,"health_potion",3)
	check(Session.state.deliveries.size() == 1 and not is_instance_valid(game.world.delivery_box),"Last arrived item removes box even with a pending order")
	unchanged = JSON.stringify(Session.state)
	collect(uid,"health_potion",3)
	check(JSON.stringify(Session.state) == unchanged,"Collected shipment cannot be looted twice")
	Session.state.deliveries[0].due_at = Time.get_unix_time_from_system()-1
	Session.refresh_deliveries()
	check(is_instance_valid(game.world.delivery_box),"Next arrival creates a new box")
	collect(Session.state.deliveries[0].uid,"apple",1)
	check(Session.state.deliveries.is_empty() and not is_instance_valid(game.world.delivery_box),"All deliveries collected and removed")
	Session.players[1].pos = AdventurerSupplies.POSITION
	Session.request_action("inventory",{"action":"pickup","args":{"id":"large_backpack","quantity":1}})
	for item in Session.inventory_for(1).data.items:
		if item.id == "large_backpack": Session.request_action("inventory",{"action":"equip","args":{"uid":item.uid,"slot":"back"}})
	for id in Session.inventory_for(1).data.loot:
		var count := int(Session.inventory_for(1).data.loot[id])
		if count > 0: Session.request_action("inventory",{"action":"pickup","args":{"id":id,"quantity":count}})
	check(not DeliveryOrders.has_contents(Session.inventory_for(1).data.loot),"All adventurer supplies collected")
	check(not is_instance_valid(game.world.supplies_box),"Empty adventurer supplies box disappears")
	Session.leave()
	Session.start_host(false,false)
	check(not is_instance_valid(game.world.supplies_box) and not is_instance_valid(game.world.delivery_box),"Empty boxes remain absent after Continue")
	var old_save := SaveStore.fresh()
	old_save.purchased_shop = 1
	old_save.ordered_stock = {"bread":4}
	check(SaveStore.write(old_save) == OK,"Old ledger-only save accepted")
	# Stop before writing the fixture so leave cannot overwrite it.
	Session.active = false
	Session.leave()
	Session.start_host(false,false)
	check(Session.state.deliveries.size() == 1 and Session.state.deliveries[0].contents.bread == 4 and Session.state.money == 1000,"Old paid ledger converted to delivery without a new charge")
	if "--visual" in OS.get_cmdline_user_args():
		game.ui.show_stock()
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://tests/delivery-order.png")
	Session.leave()
	print("DELIVERY RESULT: %d failure(s), %d checks" % [failures,checks])
	get_tree().quit(failures)
