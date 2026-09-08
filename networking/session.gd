extends Node
const ShopName = preload("res://shops/shop_naming.gd")
## One shared co-op business. Server validates all economy and placement requests.
## Movement uses owner prediction + server relay; this LAN prototype is not anti-cheat.
signal started
signal stopped
signal roster_changed
signal state_changed
signal pose_changed(id: int, pos: Vector3, yaw: float, pitch: float)
signal teleported(pos: Vector3)
signal message(text: String)
const PORT = 24567
## Multiplayer is suspended while the single-player foundation is developed.
const MULTIPLAYER_ENABLED = false
var state: Dictionary = SaveStore.fresh()
var players: Dictionary = {}
var active := false
var online := false
var joining := false
var join_elapsed := 0.0
var save_elapsed := 0.0
var delivery_poll := 0.0
var ready_delivery_ids: Array = []

func _ready() -> void:
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.connection_failed.connect(_failed)
	multiplayer.server_disconnected.connect(_lost)
	multiplayer.peer_disconnected.connect(_peer_left)

func _process(delta: float) -> void:
	if joining:
		join_elapsed += delta
		if join_elapsed > 10: _failed()
	if active and multiplayer.is_server():
		delivery_poll += delta
		if delivery_poll >= 1.0:
			delivery_poll = 0.0
			refresh_deliveries()
		save_elapsed += delta
		if save_elapsed > 20:
			save_elapsed = 0
			save_game(false)

func local_id() -> int:
	return multiplayer.get_unique_id()

func start_host(fresh: bool, lan: bool) -> Error:
	if lan and not MULTIPLAYER_ENABLED: return ERR_UNAVAILABLE
	if active or joining: return ERR_ALREADY_IN_USE
	var loaded := SaveStore.fresh() if fresh else SaveStore.read_save()
	if loaded.is_empty(): return ERR_FILE_CORRUPT
	if lan:
		var peer := ENetMultiplayerPeer.new()
		var err := peer.create_server(PORT, 7)
		if err != OK: return err
		multiplayer.multiplayer_peer = peer
	else:
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	state = loaded
	if not state.has("sale_stock"): state.sale_stock = {}
	if not state.has("ground_loot"): state.ground_loot = []
	if not state.has("shop_name"): state.shop_name = ""
	# Prior versions charged for ledger stock but had no physical delivery/pickup.
	if not state.has("deliveries"):
		state.deliveries = []
		var legacy: Dictionary = {}
		for product in state.ordered_stock:
			if state.ordered_stock[product] > 0: legacy[product] = state.ordered_stock[product]
		if not legacy.is_empty(): state.deliveries.append(DeliveryOrders.create(legacy,Time.get_unix_time_from_system()))
	ready_delivery_ids = []
	if not state.has("inventories"): state.inventories = {}
	# Peer IDs are connection identities; only the host has a persistent identity today.
	var host_inventory: Dictionary = state.inventories.get("1", PlayerInventory.new().data)
	state.inventories = {"1":host_inventory}
	online = lan
	active = true
	var p: Array = state.player_position
	var spawn := Vector3(p[0],p[1],p[2])
	# Reject unsafe edited save coordinates, including locked interiors.
	if not allowed_position(spawn): spawn = Vector3(0,0.2,4)
	players = {1:{"pos":spawn,"yaw":0.0,"pitch":0.0}}
	started.emit()
	roster_changed.emit()
	state_changed.emit()
	var save_result := save_game(false)
	if save_result == OK: message.emit("New business created • saved" if fresh else "Save loaded • welcome back")
	return OK

func join_game(address: String) -> Error:
	if not MULTIPLAYER_ENABLED: return ERR_UNAVAILABLE
	if active or joining: return ERR_ALREADY_IN_USE
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address.strip_edges(), PORT)
	if err != OK: return err
	multiplayer.multiplayer_peer = peer
	online = true
	joining = true
	join_elapsed = 0
	message.emit("Connecting to " + address + "…")
	return OK

func _connected() -> void:
	hello.rpc_id(1)

@rpc("any_peer", "call_remote", "reliable")
func hello() -> void:
	if not multiplayer.is_server() or not active: return
	var id := multiplayer.get_remote_sender_id()
	if players.has(id): return
	players[id] = {"pos":Vector3(1,0.2,4),"yaw":0.0,"pitch":0.0}
	state.inventories[str(id)] = PlayerInventory.new().data
	begin_client.rpc_id(id,state,players)
	receive_state.rpc(state)
	receive_roster.rpc(players)
	roster_changed.emit()

@rpc("authority", "call_remote", "reliable")
func begin_client(data: Dictionary, roster: Dictionary) -> void:
	state = data
	players = roster
	joining = false
	active = true
	started.emit()
	roster_changed.emit()
	state_changed.emit()
	message.emit("Connected • shared co-op shop")

@rpc("authority", "call_remote", "reliable")
func receive_roster(roster: Dictionary) -> void:
	players = roster
	if active: roster_changed.emit()

func _peer_left(id: int) -> void:
	if not multiplayer.is_server() or not active: return
	players.erase(id)
	receive_roster.rpc(players)
	roster_changed.emit()

func _failed() -> void:
	leave()
	message.emit("Could not connect. Check the host IP and UDP port 24567.")

func _lost() -> void:
	leave()
	message.emit("Host disconnected. Progress stays in the host's save.")

func leave() -> void:
	if active and multiplayer.is_server(): save_game(false)
	active = false
	joining = false
	online = false
	multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players.clear()
	stopped.emit()

func allowed_position(pos: Vector3) -> bool:
	if not pos.is_finite(): return false
	var street := absf(pos.x) < 16.2 and pos.z > -4.4 and pos.z < 7.4
	var shop: bool = state.purchased_shop >= 0 and absf(pos.x) < 3.05 and pos.z > 23.95 and pos.z < 30.05
	return (street or shop) and pos.y > -2 and pos.y < 4

func send_pose(pos: Vector3, yaw: float, pitch: float) -> void:
	if not active: return
	if multiplayer.is_server():
		accept_pose(1,pos,yaw,pitch)
	else:
		request_pose.rpc_id(1,pos,yaw,pitch)

@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func request_pose(pos: Vector3, yaw: float, pitch: float) -> void:
	if multiplayer.is_server(): accept_pose(multiplayer.get_remote_sender_id(),pos,yaw,pitch)

func accept_pose(id: int, pos: Vector3, yaw: float, pitch: float) -> void:
	if not players.has(id) or not allowed_position(pos) or not is_finite(yaw) or not is_finite(pitch): return
	players[id] = {"pos":pos,"yaw":yaw,"pitch":clampf(pitch,-1.45,1.45)}
	pose_changed.emit(id,pos,yaw,pitch)
	if online: relay_pose.rpc(id,pos,yaw,pitch)

@rpc("authority", "call_remote", "unreliable_ordered", 1)
func relay_pose(id: int, pos: Vector3, yaw: float, pitch: float) -> void:
	if not players.has(id): return
	players[id] = {"pos":pos,"yaw":yaw,"pitch":pitch}
	pose_changed.emit(id,pos,yaw,pitch)

func request_action(kind: String, data: Dictionary = {}) -> void:
	if not active: return
	if multiplayer.is_server(): execute_action(1,kind,data)
	else: action_rpc.rpc_id(1,kind,data)

@rpc("any_peer", "call_remote", "reliable")
func action_rpc(kind: String, data: Dictionary) -> void:
	if multiplayer.is_server(): execute_action(multiplayer.get_remote_sender_id(),kind,data)

func reply(id: int, text: String) -> void:
	if id == 1: message.emit(text)
	else: receive_message.rpc_id(id,text)

@rpc("authority", "call_remote", "reliable")
func receive_message(text: String) -> void:
	message.emit(text)

func near(id: int, target: Vector3, distance: float = 4.0) -> bool:
	return players.has(id) and (players[id].pos as Vector3).distance_to(target) <= distance

func execute_action(id: int, kind: String, data: Dictionary) -> void:
	if not players.has(id): return
	var old := state.duplicate(true)
	var error := ""
	match kind:
		"sale_platform":
			var entry: Dictionary = {}
			var platform := str(data.get("platform",""))
			for furniture in state.furniture:
				if SaleStock.key(furniture) == platform: entry = furniture
			if entry.is_empty() or not in_shop(id) or not near(id,GridRules.center(entry,Vector3(-3,0,24)),3.5):
				error = "Approach a sale platform inside your shop."
			elif not data.get("args",{}) is Dictionary: error = "Invalid stocking request."
			else:
				var inventory := inventory_for(id)
				var listings: Array = state.sale_stock.get(platform,[]).duplicate(true)
				error = SaleStock.apply(inventory,listings,entry,str(data.get("action","")),data.get("args",{}))
				if error.is_empty():
					state.inventories[str(id)] = inventory.data
					state.sale_stock[platform] = listings
		"collect_delivery":
			var product := str(data.get("id",""))
			var quantity := int(data.get("quantity",0))
			var order: Dictionary = {}
			for candidate in state.deliveries:
				if candidate.uid == str(data.get("delivery","")): order = candidate
			if state.purchased_shop < 0 or not near(id,FantasyWorld.delivery_position(int(state.purchased_shop)),3.5):
				error = "Move closer to the delivery box beneath Pip."
			elif order.is_empty() or order.due_at > Time.get_unix_time_from_system(): error = "That delivery has not arrived."
			elif quantity < 1 or quantity > 99 or quantity > int(order.contents.get(product,0)): error = "That quantity is not available."
			else:
				var inventory := inventory_for(id)
				var placement: Dictionary = {}
				for key in ["x", "y", "rotated"]:
					if data.has(key): placement[key] = data[key]
				if not inventory.add_item(product,quantity,{},placement): error = "That space is occupied or there is not enough inventory space. Items remain in the delivery box."
				else:
					state.inventories[str(id)] = inventory.data
					order.contents[product] -= quantity
					if order.contents[product] == 0: order.contents.erase(product)
					if order.contents.is_empty(): state.deliveries.erase(order)
		"collect_ground_loot":
			var chest_uid := str(data.get("chest", ""))
			var item_uid := str(data.get("item_uid", ""))
			var chest: Dictionary = {}
			for candidate in state.get("ground_loot", []):
				if candidate.uid == chest_uid: chest = candidate
			var chest_position := _ground_loot_position(chest)
			var ground_item: Dictionary = {}
			for candidate in chest.get("contents", []):
				if candidate.uid == item_uid: ground_item = candidate
			if chest.is_empty() or not near(id,chest_position,3.5):
				error = "Move closer to the dropped item chest."
			elif ground_item.is_empty():
				error = "That dropped item is no longer available."
			else:
				var quantity := int(data.get("quantity",0))
				if quantity < 1 or quantity > 99 or quantity > int(ground_item.quantity):
					error = "That quantity is not available."
				else:
					var inventory := inventory_for(id)
					var placement: Dictionary = {}
					for key in ["x", "y", "rotated"]:
						if data.has(key): placement[key] = data[key]
					if not inventory.add_item(ground_item.id,quantity,ground_item.properties,placement,ground_item.uid,ItemInstance.rarity(ground_item)):
						error = "That space is occupied or there is not enough inventory space. Items remain in the chest."
					else:
						state.inventories[str(id)] = inventory.data
						ground_item.quantity -= quantity
						if ground_item.quantity == 0: chest.contents.erase(ground_item)
						if chest.contents.is_empty(): state.ground_loot.erase(chest)
		"inventory":
			var action_args: Variant = data.get("args", {})
			if not action_args is Dictionary: return
			var action := str(data.get("action", ""))
			if action == "drop":
				var inventory := inventory_for(id)
				var dropped := inventory.take_item(str(action_args.get("uid","")),int(action_args.get("quantity",0)))
				if dropped.is_empty():
					error = "Only backpack items can be dropped."
				else:
					var position := _drop_position(id)
					state.inventories[str(id)] = inventory.data
					state.ground_loot.append({"uid":_new_uid("ground"),"position":[position.x,position.y,position.z],"contents":[dropped]})
			elif action == "pickup" and not near(id,AdventurerSupplies.POSITION,3.5):
				error = "Move closer to the adventurer supplies chest."
			else:
				var inventory := inventory_for(id)
				error = inventory.transact(action,action_args)
				if error.is_empty(): state.inventories[str(id)] = inventory.data
		"buy":
			var shop_id := int(data.get("shop",-1))
			if shop_id < 0 or shop_id > 2 or state.purchased_shop != -1:
				error = "You can only own one shop."
			elif not near(id,FantasyWorld.shop_position(shop_id)): error = "Move closer to the shop door."
			elif state.money < Catalog.SHOP_PRICE: error = "Not enough gold."
			else:
				state.money -= Catalog.SHOP_PRICE
				state.purchased_shop = shop_id
				state.shop_name = ""
		"set_shop_name":
			var shop_name: String = ShopName.normalize(str(data.get("name","")))
			if state.purchased_shop < 0: error = "Purchase a shop before naming it."
			elif not near(id,FantasyWorld.shop_position(int(state.purchased_shop)),4.5): error = "Move closer to your shop before naming it."
			else:
				error = ShopName.validate(shop_name)
				if error.is_empty(): state.shop_name = shop_name
		"enter":
			var shop_id := int(data.get("shop",-1))
			if shop_id != state.purchased_shop or shop_id < 0 or not near(id,FantasyWorld.shop_position(shop_id)):
				reply(id,"Purchase this shop before entering.")
				return
			move_player(id,Vector3(0,0.15,29.2))
			return
		"exit":
			if not near(id,Vector3(0,0,30)): return
			move_player(id,FantasyWorld.shop_position(int(state.purchased_shop))+Vector3(0,0.15,1.8))
			return
		"place":
			var fid := str(data.get("id",""))
			var x := int(data.get("x",-99))
			var z := int(data.get("z",-99))
			var turn := int(data.get("turn",-1))
			if state.purchased_shop < 0 or not in_shop(id): error = "Enter your purchased shop first."
			else: error = GridRules.validate(fid,x,z,turn,state.furniture)
			if error == "":
				var entry := {"id":fid,"x":x,"z":z,"turn":turn}
				var center := GridRules.center(entry,Vector3(-3,0,24))
				var size := GridRules.size_for(fid,turn)
				for other in players.values():
					var p: Vector3 = other.pos
					if absf(p.x-center.x) < size.x*0.25+0.3 and absf(p.z-center.z) < size.y*0.25+0.3:
						error = "A player is standing in that footprint."
				if state.money < Catalog.FURNITURE[fid].price: error = "Not enough gold."
				if error == "":
					state.money -= Catalog.FURNITURE[fid].price
					state.furniture.append(entry)
		"order":
			var contents: Variant = data.get("items",{str(data.get("id","")):data.get("quantity",0)})
			var total := DeliveryOrders.quote(contents) if contents is Dictionary else -1
			if state.purchased_shop < 0 or not near(id,FantasyWorld.imp_position(int(state.purchased_shop))):
				error = "Visit Pip outside your shop to order."
			elif total < 0:
				error = "Select a product and quantity from 1 to 99."
			elif state.money < total:
				error = "Not enough gold."
			else:
				# Delivery orders reserve no backpack space. Inventory capacity is checked
				# only when the player actually collects items from the arrived box.
				state.money -= total
				state.deliveries.append(DeliveryOrders.create(contents,Time.get_unix_time_from_system()))
				for product in contents:
					state.ordered_stock[product] = int(state.ordered_stock.get(product,0)) + int(contents[product])
		"buy_item":
			var product_id := str(data.get("id",""))
			var quantity := int(data.get("quantity",0))
			var total := DeliveryOrders.quote({product_id:quantity})
			if state.purchased_shop < 0 or not near(id,FantasyWorld.imp_position(int(state.purchased_shop))):
				error = "Visit Pip outside your shop to buy stock."
			elif total < 0: error = "Select a product and quantity from 1 to 99."
			elif state.money < total: error = "Not enough gold."
			else:
				var inventory := inventory_for(id)
				if not inventory.add_item(product_id,quantity): error = "Not enough inventory space."
				else:
					state.inventories[str(id)] = inventory.data
					state.money -= total
		"save":
			var save_result := save_game(false)
			reply(id,"Game saved" if save_result == OK else "Save failed: " + error_string(save_result))
			return
		_:
			return
	if error != "":
		reply(id,error)
		return
	update_saved_position()
	var result := SaveStore.write(state)
	if result != OK:
		state = old
		reply(id,"Could not save transaction: " + error_string(result))
		return
	state_changed.emit()
	if online: receive_state.rpc(state)
	reply(id,{"buy":"Shop purchased! Choose its name to get started.", "set_shop_name":"Shop name saved.", "buy_item":"Purchase added to your backpack.", "place":"Furniture placed • saved", "order":"Order placed • delivery beneath Pip in 5 minutes", "collect_delivery":"Items collected • saved", "collect_ground_loot":"Items collected • saved", "inventory":"Inventory updated • saved"}.get(kind,"Saved"))

func refresh_deliveries() -> void:
	var current: Array = []
	for order in DeliveryOrders.ready(state.get("deliveries",[]),Time.get_unix_time_from_system()): current.append(order.uid)
	if current == ready_delivery_ids: return
	var arrived := false
	for uid in current:
		if uid not in ready_delivery_ids: arrived = true
	ready_delivery_ids = current
	state_changed.emit()
	if arrived: message.emit("Your delivery has arrived! Collect it from the box beneath Pip.")

func in_shop(id: int) -> bool:
	var p: Vector3 = players[id].pos
	return absf(p.x) < 3.1 and p.z >= 24 and p.z <= 30.1

func inventory_for(id: int) -> PlayerInventory:
	return PlayerInventory.new(state.get("inventories",{}).get(str(id),{}))

func _new_uid(prefix: String) -> String:
	return "%s:%s" % [prefix,Crypto.new().generate_random_bytes(16).hex_encode()]

func _drop_position(id: int) -> Vector3:
	var player: Dictionary = players[id]
	var forward := Vector3(-sin(float(player.yaw)),0,-cos(float(player.yaw)))
	var position: Vector3 = player.pos + forward * 1.2
	position.y = 0.35
	return position

func _ground_loot_position(chest: Dictionary) -> Vector3:
	if chest.is_empty() or not chest.get("position",[]) is Array or chest.position.size() != 3: return Vector3.INF
	return Vector3(float(chest.position[0]),float(chest.position[1]),float(chest.position[2]))

func move_player(id: int, pos: Vector3) -> void:
	players[id].pos = pos
	if id == 1: teleported.emit(pos)
	else: teleport_client.rpc_id(id,pos)
	if online: relay_pose.rpc(id,pos,players[id].yaw,players[id].pitch)
	pose_changed.emit(id,pos,players[id].yaw,players[id].pitch)

@rpc("authority", "call_remote", "reliable")
func teleport_client(pos: Vector3) -> void:
	teleported.emit(pos)

@rpc("authority", "call_remote", "reliable")
func receive_state(data: Dictionary) -> void:
	state = data
	state_changed.emit()

func update_saved_position() -> void:
	if players.has(1):
		var p: Vector3 = players[1].pos
		state.player_position = [p.x,p.y,p.z]

func save_game(feedback: bool = true) -> Error:
	if not active or not multiplayer.is_server(): return ERR_UNAUTHORIZED
	update_saved_position()
	var err := SaveStore.write(state)
	if feedback or err != OK:
		message.emit("Game saved" if err == OK else "Save failed: " + error_string(err))
	return err
