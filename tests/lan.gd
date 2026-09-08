extends Node
var game: Node
var role := ""
var failures := 0
var saw_guest := false
var saw_move := false
var saw_order := false
var saw_inventory := false

func check(condition: bool, label: String) -> void:
	if condition: print("PASS ["+role+"]: "+label)
	else:
		failures += 1
		push_error("FAIL ["+role+"]: "+label)

func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	role = "host" if "--host" in args else ("late" if "--late" in args else "client")
	SaveStore.path = "user://tests/lan_" + role + ".json"
	game = preload("res://scenes/main.tscn").instantiate()
	add_child(game)
	await wait(0.1)
	if role == "host":
		check(Session.start_host(true,true) == OK,"ENet server started")
		for i in range(180):
			await wait(0.1)
			if Session.players.size() > 1:
				if not saw_guest: game.local_player.teleport(Vector3(-1.5,0.1,4))
				saw_guest = true
				for id in Session.players:
					if id != 1 and Session.players[id].pos.z < 0: saw_move = true
			if Session.state.ordered_stock.get("bread",0) == 2: saw_order = true
			for key in Session.state.inventories:
				if key != "1" and Session.state.inventories[key].equipment.has("main_hand"): saw_inventory = true
		check(saw_guest,"Guest registered and spawned")
		check(saw_move,"Guest movement received")
		check(saw_order,"Guest stock request validated on host")
		check(saw_inventory,"Guest weapon equipped authoritatively on host")
		check(Session.inventory_for(1).data.items.is_empty(),"Guest inventory actions do not affect host inventory")
		check(Session.state.purchased_shop == 1,"Guest purchase shared")
		check(Session.state.furniture.size() == 1,"Guest furniture replicated")
		check(Session.players.size() == 1,"Disconnected guests removed")
	else:
		check(Session.join_game("127.0.0.1") == OK,"Client connection initiated")
		for i in range(80):
			if Session.active: break
			await wait(0.1)
		check(Session.active,"Handshake completed")
		if Session.active:
			check(game.players.size() >= 2,"Host and local player visible in scene")
			if role == "late":
				check(Session.state.purchased_shop == 1,"Late join receives ownership")
				check(Session.state.furniture.size() == 1,"Late join receives furniture")
				check(Session.state.ordered_stock.get("bread",0) == 2,"Late join receives orders")
				check(game.world.imp != null,"Late join spawns IMP")
				check(Session.inventory_for(Session.local_id()).data.items.is_empty(),"Late join has independent inventory")
			else:
				await wait(0.4)
				check(game.players[1].position.x < -1.0 and game.players[1].model.visible,"Host movement and remote avatar rendered on guest")
				game.local_player.teleport(Vector3(-1,0.1,3))
				await wait(0.3)
				Session.request_action("inventory",{"action":"pickup","args":{"id":"iron_sword","quantity":1}})
				await wait(0.3)
				var inventory := Session.inventory_for(Session.local_id())
				check(inventory.data.items.size() == 1,"Guest pickup snapshot received")
				if inventory.data.items.size() == 1:
					Session.request_action("inventory",{"action":"equip","args":{"uid":inventory.data.items[0].uid,"slot":"main_hand"}})
					await wait(0.3)
					check(Session.inventory_for(Session.local_id()).data.equipment.has("main_hand"),"Guest equip replicated")
					check(game.local_player.stats.damage == 12,"Guest equipment stats refreshed")
				game.local_player.teleport(Vector3(0,0.1,-1.5))
				await wait(0.4)
				Session.request_action("buy",{"shop":1})
				await wait(0.4)
				check(Session.state.purchased_shop == 1 and Session.state.money == 700,"Purchase state returned to guest")
				check(game.world.imp != null,"Guest sees IMP")
				game.local_player.teleport(Vector3(1.9,0.1,-1))
				await wait(0.4)
				Session.request_action("order",{"id":"bread","quantity":2})
				await wait(0.4)
				check(Session.state.ordered_stock.get("bread",0) == 2,"Order replicated to guest")
				game.local_player.teleport(Vector3(0,0.1,-1.5))
				await wait(0.3)
				Session.request_action("enter",{"shop":1})
				await wait(0.4)
				check(game.world.interior.contains(game.local_player.position),"Guest authoritative teleport")
				Session.request_action("place",{"id":"small_table","x":2,"z":2,"turn":1})
				await wait(0.4)
				check(Session.state.furniture.size() == 1,"Guest placement returned")
				Session.request_action("save")
				await wait(0.3)
				check(game.ui.status.text == "Saved • host world","Guest receives save feedback")
	if Session.active: Session.leave()
	await wait(0.2)
	print("LAN RESULT ["+role+"]: %d failure(s)" % failures)
	get_tree().quit(1 if failures else 0)
