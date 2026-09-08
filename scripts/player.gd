class_name FirstPersonPlayer
extends CharacterBody3D
var peer_id := 1
var camera: Camera3D
var head: Node3D
var model: Node3D
var target_pos := Vector3.ZERO
var target_yaw := 0.0
var send_clock := 0.0
var game: Node
const SPEED = 4.0

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = 1.75
	collision.shape = capsule
	collision.position.y = 0.875
	add_child(collision)
	head = Node3D.new()
	add_child(head)
	head.position.y = 1.58
	camera = Camera3D.new()
	head.add_child(camera)
	camera.fov = 78
	camera.near = 0.05
	camera.current = is_local()
	model = Node3D.new()
	add_child(model)
	var color := Color.from_hsv(fmod(peer_id*0.17,1.0),0.45,0.75)
	Geometry.box(model,Vector3(0,0.85,0),Vector3(0.5,0.85,0.32),color,false)
	Geometry.box(model,Vector3(0,1.47,0),Vector3(0.38,0.38,0.38),Color("d5b189"),false)
	Geometry.box(model,Vector3(0,1.48,-0.2),Vector3(0.26,0.08,0.03),Color("323844"),false)
	for x in [-0.15,0.15]:
		Geometry.box(model,Vector3(x,0.27,0),Vector3(0.19,0.55,0.23),Color("423c38"),false)
	model.visible = not is_local()
	var tag := Geometry.label(model,Vector3(0,1.98,0),"Host" if peer_id == 1 else "Merchant " + str(peer_id).right(4),21)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	target_pos = position

func is_local() -> bool:
	return peer_id == Session.local_id()

func _unhandled_input(event: InputEvent) -> void:
	if not is_local() or game == null or game.ui.modal_open(): return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotation.y -= event.relative.x * 0.0025
		head.rotation.x = clampf(head.rotation.x - event.relative.y * 0.0025,-1.45,1.45)

func _physics_process(delta: float) -> void:
	if not is_local():
		position = position.lerp(target_pos, minf(1.0,delta*15))
		rotation.y = lerp_angle(rotation.y,target_yaw,minf(1.0,delta*15))
		return
	if not Session.active: return
	var input := Vector2.ZERO
	if game != null and not game.ui.modal_open() and (game.running_test or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED):
		input = Input.get_vector("left","right","forward","back")
		if Input.is_action_just_pressed("jump") and is_on_floor(): velocity.y = 5.0
	var direction := transform.basis * Vector3(input.x,0,input.y)
	velocity.x = direction.x * SPEED
	velocity.z = direction.z * SPEED
	if not is_on_floor(): velocity.y -= 15.0 * delta
	move_and_slide()
	if position.y < -3: teleport(Vector3(0,0.2,4))
	send_clock += delta
	if send_clock >= 0.05:
		send_clock = 0
		Session.send_pose(position,rotation.y,head.rotation.x)

func teleport(pos: Vector3) -> void:
	position = pos
	target_pos = pos
	velocity = Vector3.ZERO
	Session.send_pose(position,rotation.y,head.rotation.x)

func look_target() -> Interactable:
	var from := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(from,from-camera.global_basis.z*3.5,1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.collider is Interactable: return hit.collider
	return null
