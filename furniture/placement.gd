class_name PlacementController
extends Node3D
var game: Node
var selected := ""
var turn := 0
var ghost: Node3D
var entry: Dictionary = {}
var reason := ""
var valid := false

func select(id: String) -> void:
	cancel()
	selected = id
	ghost = FurnitureFactory.create(id,true)
	add_child(ghost)
	var s := GridRules.size_for(id,0)
	Geometry.box(ghost,Vector3(0,0.035,0),Vector3(s.x*0.5,0.03,s.y*0.5),Color.WHITE,false)

func cancel() -> void:
	selected = ""
	entry = {}
	valid = false
	if is_instance_valid(ghost): ghost.queue_free()
	ghost = null

func _process(_delta: float) -> void:
	if selected == "" or not is_instance_valid(game.local_player): return
	var player: FirstPersonPlayer = game.local_player
	if game.ui.modal_open():
		ghost.visible = false
		return
	if not game.world.interior.contains(player.position):
		cancel()
		return
	var camera := player.camera
	var point: Variant = Plane(Vector3.UP,0).intersects_ray(camera.global_position,-camera.global_basis.z)
	if point == null or camera.global_position.distance_to(point) > 7:
		valid = false
		ghost.visible = false
		reason = "Look at the shop floor within 7 metres."
		return
	ghost.visible = true
	var local: Vector3 = point - game.world.interior.origin
	entry = {"id":selected,"x":floori(local.x/GridRules.CELL),"z":floori(local.z/GridRules.CELL),"turn":turn}
	ghost.position = GridRules.center(entry,game.world.interior.origin)
	ghost.rotation.y = turn*PI/2
	reason = GridRules.validate(selected,entry.x,entry.z,turn,Session.state.furniture)
	if Session.state.money < Catalog.FURNITURE[selected].price: reason = "Not enough gold."
	var s := GridRules.size_for(selected,turn)
	for p in game.players.values():
		if absf(p.position.x-ghost.position.x) < s.x*0.25+0.3 and absf(p.position.z-ghost.position.z) < s.y*0.25+0.3:
			reason = "A player is standing in that footprint."
	valid = reason == ""
	FurnitureFactory.tint(ghost,Color(0.3,0.95,0.65,0.5) if valid else Color(1,0.25,0.25,0.5))

func place() -> void:
	if valid: Session.request_action("place",entry)
	else: game.ui.notify(reason)

