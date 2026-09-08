extends Node3D
var world: FantasyWorld
var ui: GameUI
var placement: PlacementController
var players: Dictionary = {}
var local_player: FirstPersonPlayer
var menu_camera: Camera3D
var player_root: Node3D
var running_test := false

func _ready() -> void:
	setup_input()
	world = preload("res://scenes/world/street.tscn").instantiate()
	add_child(world)
	player_root = Node3D.new()
	player_root.name = "Players"
	add_child(player_root)
	menu_camera = Camera3D.new()
	add_child(menu_camera)
	menu_camera.position = Vector3(7,4.5,6)
	menu_camera.look_at(Vector3(0,1.5,-4))
	menu_camera.current = true
	ui = GameUI.new()
	ui.game = self
	add_child(ui)
	placement = PlacementController.new()
	placement.game = self
	add_child(placement)
	Session.started.connect(_started)
	Session.stopped.connect(_stopped)
	Session.roster_changed.connect(sync_players)
	Session.state_changed.connect(_state_changed)
	Session.pose_changed.connect(_pose)
	Session.teleported.connect(func(pos: Vector3):
		if is_instance_valid(local_player): local_player.teleport(pos))
	Session.message.connect(ui.notify)
	get_tree().auto_accept_quit = false

func setup_input() -> void:
	var keys := {"forward":KEY_W,"back":KEY_S,"left":KEY_A,"right":KEY_D,"jump":KEY_SPACE,"interact":KEY_E,"build":KEY_B,"rotate":KEY_R,"save":KEY_F5,"inventory":KEY_I}
	for action in keys:
		if not InputMap.has_action(action): InputMap.add_action(action)
		var event := InputEventKey.new()
		event.physical_keycode = keys[action]
		InputMap.action_add_event(action,event)

func _started() -> void:
	ui.close()
	ui.hud.show()
	sync_players()
	_state_changed()
	ui.notify("Welcome to Lantern Lane • approach a shop door and press E")

func _stopped() -> void:
	placement.cancel()
	for p in players.values():
		player_root.remove_child(p)
		p.queue_free()
	players.clear()
	local_player = null
	ui.hud.hide()
	menu_camera.current = true
	ui.show_main()

func sync_players() -> void:
	for id in players.keys():
		if not Session.players.has(id):
			player_root.remove_child(players[id])
			players[id].queue_free()
			players.erase(id)
	for id in Session.players:
		if players.has(id): continue
		var p: FirstPersonPlayer = preload("res://scenes/player/player.tscn").instantiate()
		p.name = str(id)
		p.peer_id = id
		p.game = self
		p.position = Session.players[id].pos
		player_root.add_child(p)
		players[id] = p
		if p.is_local():
			local_player = p
			p.camera.current = true
	ui.refresh()

func _state_changed() -> void:
	world.apply_state()
	ui.refresh()

func _pose(id: int, pos: Vector3, yaw: float, pitch: float) -> void:
	if not players.has(id) or players[id].is_local(): return
	var p: FirstPersonPlayer = players[id]
	if p.position.distance_to(pos) > 5: p.position = pos
	p.target_pos = pos
	p.target_yaw = yaw
	p.head.rotation.x = pitch

func _process(_delta: float) -> void:
	if not Session.active or not is_instance_valid(local_player) or ui.modal_open():
		ui.prompt.text = ""
		return
	if placement.selected != "":
		ui.prompt.text = "%s  •  R Rotate  •  Click Place  •  Right click Cancel\n%s" % [Catalog.FURNITURE[placement.selected].name,"Ready to place" if placement.valid else placement.reason]
	else:
		var target := local_player.look_target()
		ui.prompt.text = target.prompt() if target != null else ("[B] Furnish your shop" if world.interior.contains(local_player.position) else "Find a shop door to begin your business")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo: return
	if Session.active and event.is_action_pressed("inventory"):
		if ui.inventory_panel.visible: ui.close()
		elif not ui.modal_open():
			placement.cancel()
			ui.show_inventory()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		if not Session.active: return
		if placement.selected != "": placement.cancel()
		elif ui.modal_open(): ui.close()
		else: ui.show_pause()
		get_viewport().set_input_as_handled()
		return
	if not Session.active or ui.modal_open(): return
	if event.is_action_pressed("save"): Session.request_action("save")
	if event.is_action_pressed("build"):
		if Session.state.purchased_shop >= 0 and world.interior.contains(local_player.position): ui.show_furniture()
		else: ui.notify("Purchase and enter your shop to furnish it.")
	if event.is_action_pressed("rotate"): placement.turn = (placement.turn+1)%4
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT: placement.cancel()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			elif placement.selected != "": placement.place()
	if event.is_action_pressed("interact") and placement.selected == "":
		var target := local_player.look_target()
		if target == null: return
		match target.kind:
			"sale_platform": ui.show_sale_platform(target.platform_id)
			"delivery": ui.show_inventory(true,"delivery")
			"supplies": ui.show_inventory(true)
			"ground_loot": ui.show_inventory(true,"ground:" + target.loot_uid)
			"imp": ui.show_stock()
			"exit": Session.request_action("exit")
			"shop":
				if Session.state.purchased_shop == target.shop_id: Session.request_action("enter",{"shop":target.shop_id})
				elif Session.state.purchased_shop == -1: ui.show_purchase(target.shop_id)
				else: ui.notify("You already own another shop.")

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if Session.active: Session.leave()
		get_tree().quit()
