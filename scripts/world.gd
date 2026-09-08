class_name FantasyWorld
extends Node3D
var interior: ShopInterior
var imp: ImpMerchant
var doors: Array[Interactable] = []

static func shop_position(id: int) -> Vector3:
	return Vector3((id-1)*9.0,0,-4.6)

static func imp_position(id: int) -> Vector3:
	return shop_position(id) + Vector3(1.9,1.5,1.4)

func _ready() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("859fa5")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("d5decc")
	env.ambient_light_energy = 0.65
	environment.environment = env
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48,-28,0)
	sun.light_color = Color("ffe0ac")
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	add_child(sun)
	Geometry.box(self, Vector3(0,-0.25,0), Vector3(34,0.5,19), Color("555e5b"))
	Geometry.box(self, Vector3(0,-0.09,-3.4), Vector3(32,0.18,3), Color("858879"))
	for x in range(-15,16):
		for z in range(-2,8,2):
			Geometry.box(self, Vector3(x + (0.5 if z%4 == 0 else 0.0),0.012,z), Vector3(0.91,0.02,1.85), Color("68716b") if x%2==0 else Color("727972"), false)
	for id in range(3):
		shop(id)
	# Opposite facades and boundary walls define a compact, enclosed street.
	for x in [-12,-4,4,12]:
		Geometry.box(self, Vector3(x,2.8,8), Vector3(7.7,5.6,1), Color("ae9b81"))
		for dx in [-3,0,3]:
			Geometry.box(self, Vector3(x+dx,2.8,7.43), Vector3(0.18,5.6,0.16), Color("493e32"))
		Geometry.box(self, Vector3(x,5.75,8), Vector3(8.2,0.3,2), Color("584c50"))
		for dx in [-1.8,1.8]:
			Geometry.box(self, Vector3(x+dx,3.7,7.4), Vector3(1.2,1.4,0.1), Color("354951"))
	Geometry.box(self, Vector3(-16.5,2,0), Vector3(0.6,4,19), Color("8c8776"))
	Geometry.box(self, Vector3(16.5,2,0), Vector3(0.6,4,19), Color("8c8776"))
	Geometry.box(self, Vector3(0,2,-5.6), Vector3(34,4,0.4), Color("8c8776"))
	for x in [-14,-5,5,14]:
		Geometry.box(self, Vector3(x,1.4,-2.5), Vector3(0.12,2.8,0.12), Color("3d3830"))
		Geometry.box(self, Vector3(x,2.7,-2.5), Vector3(0.36,0.5,0.36), Color("efbb61"), false)
		var light := OmniLight3D.new()
		add_child(light)
		light.position = Vector3(x,2.5,-2.5)
		light.light_color = Color("ffbd60")
		light.omni_range = 4
		light.light_energy = 0.65
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
	Geometry.box(self,p+Vector3(-2.3,2.1,-0.3),Vector3(3.2,4.2,0.6),plaster)
	Geometry.box(self,p+Vector3(2.3,2.1,-0.3),Vector3(3.2,4.2,0.6),plaster)
	Geometry.box(self,p+Vector3(0,3.35,-0.3),Vector3(1.4,1.7,0.6),plaster)
	for x in [-3.85,-0.8,0.8,3.85]:
		Geometry.box(self,p+Vector3(x,2.1,0.05),Vector3(0.16,4.3,0.2),Color("503d2b"))
	for x in [-2.3,2.3]:
		Geometry.box(self,p+Vector3(x,1.7,0.08),Vector3(1.9,1.45,0.16),Color("35494b"))
		Geometry.box(self,p+Vector3(x,1.7,0.2),Vector3(0.07,1.5,0.07),Color("c69c61"),false)
		Geometry.box(self,p+Vector3(x,1.7,0.2),Vector3(1.9,0.07,0.07),Color("c69c61"),false)
	Geometry.box(self,p+Vector3(0,4.25,-0.3),Vector3(8.2,0.28,2.2),Color("574954"))
	Geometry.roof(self,p+Vector3(0,4.35,-0.3),8.3,2.3)
	Geometry.box(self,p+Vector3(0,2.9,0.15),Vector3(3.9,0.62,0.15),Color("433d31"),false)
	Geometry.label(self,p+Vector3(0,2.9,0.25),Catalog.SHOP_NAMES[id],25)
	var door := Interactable.new()
	door.shop_id = id
	door.setup(self,p+Vector3(0,1.15,0.05),Vector3(1.35,2.3,0.25),Color("78513b"))
	Geometry.box(door,Vector3(0.4,0,0.15),Vector3(0.1,0.1,0.1),Color("e9bc69"),false)
	doors.append(door)

func apply_state() -> void:
	interior.rebuild(Session.state.furniture)
	if Session.state.purchased_shop >= 0 and imp == null:
		imp = ImpMerchant.new()
		add_child(imp)
		imp.position = imp_position(int(Session.state.purchased_shop))
	if imp != null and Session.state.purchased_shop < 0:
		imp.queue_free()
		imp = null
