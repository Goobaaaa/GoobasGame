extends Node
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
var state: Dictionary = SaveStore.fresh()
var players: Dictionary = {}
var active := false
var online := false
var joining := false
var join_elapsed := 0.0
var save_elapsed := 0.0

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
		save_elapsed += delta
		if save_elapsed > 20:
			save_elapsed = 0
			save_game(false)

func local_id() -> int:
	return multiplayer.get_unique_id()

func start_host(fresh: bool, lan: bool) -> Error:
	if active or joining: return ERR_ALREADY_IN_USE
	var loaded := SaveStore.fresh() if fresh else SaveStore.read_save()
	if loaded.is_empty(): return ERR_FILE_CORRUPT
	var peer := ENetMultiplayerPeer.new()
	if lan:
		var err := peer.create_server(PORT, 7)
		if err != OK: return err
		multiplayer.multiplayer_peer = peer
	else:
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	state = loaded
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
	begin_client.rpc_id(id,state,players)
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
		"buy":
			var shop_id := int(data.get("shop",-1))
			if shop_id < 0 or shop_id > 2 or state.purchased_shop != -1:
				error = "Only one shop can be owned by this co-op."
			elif not near(id,FantasyWorld.shop_position(shop_id)): error = "Move closer to the shop door."
			elif state.money < Catalog.SHOP_PRICE: error = "Not enough gold."
			else:
				state.money -= Catalog.SHOP_PRICE
				state.purchased_shop = shop_id
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
			var product := str(data.get("id",""))
			var quantity := int(data.get("quantity",0))
			if state.purchased_shop < 0 or not near(id,FantasyWorld.imp_position(int(state.purchased_shop))):
				error = "Visit Pip outside your shop to order."
			elif not Catalog.PRODUCTS.has(product) or quantity < 1 or quantity > 99:
				error = "Select a product and quantity from 1 to 99."
			else:
				var total: int = Catalog.PRODUCTS[product].price * quantity
				if state.money < total: error = "Not enough gold."
				else:
					state.money -= total
					state.ordered_stock[product] = int(state.ordered_stock.get(product,0)) + quantity
		"save":
			var save_result := save_game(false)
			reply(id,"Saved • host world" if save_result == OK else "Save failed: " + error_string(save_result))
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
	reply(id,{"buy":"Shop purchased! Pip has arrived. Press E again to enter.", "place":"Furniture placed • saved", "order":"Stock ordered • saved (delivery comes later)"}.get(kind,"Saved"))

func in_shop(id: int) -> bool:
	var p: Vector3 = players[id].pos
	return absf(p.x) < 3.1 and p.z >= 24 and p.z <= 30.1

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
		message.emit("Saved • host world" if err == OK else "Save failed: " + error_string(err))
	return err
