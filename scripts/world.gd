class_name FantasyWorld
extends Node3D
var interior: ShopInterior
var imp: ImpMerchant
var doors: Array[Interactable] = []
var supplies_box: Interactable
var delivery_box: Interactable
var ground_loot_boxes: Dictionary = {}
var shop_signs: Dictionary = {}

static func delivery_position(id: int) -> Vector3:
	var pos := imp_position(id)
	pos.y = 0.35
	return pos

static func shop_position(id: int) -> Vector3:
	return Vector3((id-1)*9.0,0,-4.6)

static func imp_position(id: int) -> Vector3:
	return shop_position(id) + Vector3(1.9,1.5,1.4)

func _ready() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("81979b")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("cbd8cf")
	env.ambient_light_energy = 0.52
	environment.environment = env
	add_child(environment)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48,-28,0)
	sun.light_color = Color("ffe0ac")
	sun.light_energy = 0.95
	sun.shadow_enabled = true
	add_child(sun)

	# Large shared surfaces now use stylised materials rather than one-off flat colours.
	Geometry.box(self, Vector3(0,-0.25,0), Vector3(34,0.5,19), Color("555e5b"), true, "stone")
	Geometry.box(self, Vector3(0,-0.09,-3.4), Vector3(32,0.18,3), Color("858879"), true, "stone")
	for x in range(-15,16):
		for z in range(-2,8,2):
			Geometry.box(
				self,
				Vector3(x + (0.5 if z%4 == 0 else 0.0),0.012,z),
				Vector3(0.91,0.02,1.85),
				Color("68716b") if x%2==0 else Color("727972"),
				false,
				"stone"
			)

	for id in range(3):
		shop(id)

	# Opposite facades and boundary walls define a compact, enclosed street.
	for x in [-12,-4,4,12]:
		Geometry.box(self, Vector3(x,2.8,8), Vector3(7.7,5.6,1), Color("ae9b81"), true, "plaster")
		for dx in [-3,0,3]:
			Geometry.box(self, Vector3(x+dx,2.8,7.43), Vector3(0.18,5.6,0.16), Color("493e32"), true, "wood")
		Geometry.box(self, Vector3(x,5.75,8), Vector3(8.2,0.3,2), Color("584c50"), true, "wood")
		for dx in [-1.8,1.8]:
			Geometry.box(self, Vector3(x+dx,3.7,7.4), Vector3(1.2,1.4,0.1), Color("354951"))

	Geometry.box(self, Vector3(-16.5,2,0), Vector3(0.6,4,19), Color("8c8776"), true, "plaster")
	Geometry.box(self, Vector3(16.5,2,0), Vector3(0.6,4,19), Color("8c8776"), true, "plaster")
	Geometry.box(self, Vector3(0,2,-5.6), Vector3(34,4,0.4), Color("8c8776"), true, "plaster")

	for x in [-14,-5,5,14]:
		Geometry.box(self, Vector3(x,1.4,-2.5), Vector3(0.12,2.8,0.12), Color("3d3830"), true, "wood")
		Geometry.box(self, Vector3(x,2.7,-2.5), Vector3(0.36,0.5,0.36), Color("efbb61"), false, "brass")
		var light := OmniLight3D.new()
		add_child(light)
		light.position = Vector3(x,2.5,-2.5)
		light.light_color = Color("ffbd60")
		light.omni_range = 4.5
		light.light_energy = 0.8
		light.shadow_enabled = true

	for x in [-14,14]:
		var crate := FurnitureFactory.create("storage_crate",false)
		add_child(crate)
		crate.position = Vector3(x,0,-3.2)

	Geometry.label(self, Vector3(0,4.9,-4.25), "L A N T E R N   L A N E", 43)
	interior = ShopInterior.new()
	add_child(interior)

func shop(id: int) -> void:
	var p := shop_position(id)
	var plaster: Color = [Color("c6b18b"),Color("a9b4a2"),Color("b6a4b6")][id]
	Geometry.box(self,p+Vector3(-2.3,2.1,-0.3),Vector3(3.2,4.2,0.6),plaster,true,"plaster")
	Geometry.box(self,p+Vector3(2.3,2.1,-0.3),Vector3(3.2,4.2,0.6),plaster,true,"plaster")
	Geometry.box(self,p+Vector3(0,3.35,-0.3),Vector3(1.4,1.7,0.6),plaster,true,"plaster")
	for x in [-3.85,-0.8,0.8,3.85]:
		Geometry.box(self,p+Vector3(x,2.1,0.05),Vector3(0.16,4.3,0.2),Color("503d2b"),true,"wood")
	for x in [-2.3,2.3]:
		Geometry.box(self,p+Vector3(x,1.7,0.08),Vector3(1.9,1.45,0.16),Color("35494b"))
		Geometry.box(self,p+Vector3(x,1.7,0.2),Vector3(0.07,1.5,0.07),Color("c69c61"),false,"brass")
		Geometry.box(self,p+Vector3(x,1.7,0.2),Vector3(1.9,0.07,0.07),Color("c69c61"),false,"brass")
	Geometry.box(self,p+Vector3(0,4.25,-0.3),Vector3(8.2,0.28,2.2),Color("574954"),true,"wood")
	Geometry.roof(self,p+Vector3(0,4.35,-0.3),8.3,2.3)
	Geometry.box(self,p+Vector3(0,2.9,0.15),Vector3(3.9,0.62,0.15),Color("433d31"),false,"wood")
	shop_signs[id] = Geometry.label(self,p+Vector3(0,2.9,0.25),Catalog.SHOP_NAMES[id],25)
	var door := Interactable.new()
	door.shop_id = id
	door.setup(self,p+Vector3(0,1.15,0.05),Vector3(1.35,2.3,0.25),Color("78513b"))
	Geometry.box(door,Vector3(0.4,0,0.15),Vector3(0.1,0.1,0.1),Color("e9bc69"),false,"brass")
	doors.append(door)

func apply_state() -> void:
	_update_shop_signs()
	interior.set_shop_name(str(Session.state.get("shop_name","")) if int(Session.state.get("purchased_shop",-1)) >= 0 else "")
	var supplies_remain := Session.active and DeliveryOrders.has_contents(Session.inventory_for(Session.local_id()).data.loot)
	supplies_box = _sync_box(supplies_box,supplies_remain,"supplies",AdventurerSupplies.POSITION,"Adventurer supplies · E")
	var shop_id := int(Session.state.purchased_shop)
	var delivered := Session.active and shop_id >= 0 and not DeliveryOrders.ready(Session.state.get("deliveries",[]),Time.get_unix_time_from_system()).is_empty()
	delivery_box = _sync_box(delivery_box,delivered,"delivery",delivery_position(shop_id),"Delivery · E")
	_sync_ground_loot()
	interior.rebuild(Session.state.furniture)
	if Session.state.purchased_shop >= 0 and imp == null:
		imp = ImpMerchant.new()
		add_child(imp)
		imp.position = imp_position(int(Session.state.purchased_shop))
	if imp != null and Session.state.purchased_shop < 0:
		imp.queue_free()
		imp = null

func _update_shop_signs() -> void:
	var owned := int(Session.state.get("purchased_shop",-1))
	var name := str(Session.state.get("shop_name",""))
	for id in shop_signs:
		var sign: Label3D = shop_signs[id]
		if not is_instance_valid(sign): continue
		if int(id) == owned: sign.text = name.to_upper() if not name.is_empty() else "YOUR SHOP"
		else: sign.text = Catalog.SHOP_NAMES[int(id)]

func _sync_box(box: Interactable, needed: bool, kind: String, pos: Vector3, title: String) -> Interactable:
	if not needed:
		if is_instance_valid(box):
			remove_child(box)
			box.queue_free()
		return null
	if not is_instance_valid(box):
		box = Interactable.new()
		box.kind = kind
		box.setup(self,pos,Vector3(1.0,0.6,0.65),Color("86633c"))
		Geometry.label(box,Vector3(0,0.45,0),title,18)
	box.position = pos
	return box

func _sync_ground_loot() -> void:
	var active: Dictionary = {}
	if Session.active:
		for chest in Session.state.get("ground_loot", []):
			var uid := str(chest.get("uid", ""))
			if uid.is_empty() or not chest.get("position",[]) is Array or chest.position.size() != 3: continue
			active[uid] = true
			var box: Interactable = ground_loot_boxes.get(uid)
			if not is_instance_valid(box):
				box = Interactable.new()
				box.kind = "ground_loot"
				box.loot_uid = uid
				box.setup(self,Vector3(float(chest.position[0]),float(chest.position[1]),float(chest.position[2])),Vector3(0.9,0.55,0.65),Color("76583f"))
				Geometry.label(box,Vector3(0,0.42,0),"Dropped items · E",16)
			ground_loot_boxes[uid] = box
			box.position = Vector3(float(chest.position[0]),float(chest.position[1]),float(chest.position[2]))
	for uid in ground_loot_boxes.keys():
		if active.has(uid): continue
		var old_box: Interactable = ground_loot_boxes[uid]
		if is_instance_valid(old_box):
			remove_child(old_box)
			old_box.queue_free()
		ground_loot_boxes.erase(uid)
