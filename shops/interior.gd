class_name ShopInterior
extends Node3D
var origin := Vector3(-3,0,24)
var furniture_root: Node3D
var title_sign: Label3D

func _ready() -> void:
	Geometry.box(self, origin + Vector3(3,-0.12,3), Vector3(6.4,0.24,6.4), Color("79624b"), true, "wood")
	Geometry.box(self, origin + Vector3(-0.15,1.7,3), Vector3(0.3,3.4,6.4), Color("c3b38f"), true, "plaster")
	Geometry.box(self, origin + Vector3(6.15,1.7,3), Vector3(0.3,3.4,6.4), Color("c3b38f"), true, "plaster")
	Geometry.box(self, origin + Vector3(3,1.7,-0.15), Vector3(6.4,3.4,0.3), Color("cfbf9c"), true, "plaster")
	for x in [1.175,4.825]:
		Geometry.box(self, origin + Vector3(x,1.7,6.15), Vector3(2.35,3.4,0.3), Color("b5a181"), true, "plaster")
	Geometry.box(self, origin + Vector3(3,3,6.15), Vector3(1.3,0.8,0.3), Color("b5a181"), true, "plaster")
	Geometry.box(self, origin + Vector3(3,3.6,3), Vector3(6.4,0.25,6.4), Color("655441"), true, "wood")
	for x in range(13):
		Geometry.box(self, origin + Vector3(x*0.5,0.012,3), Vector3(0.016,0.012,6), Color("b6ae7f"), false, "brass")
	for z in range(13):
		Geometry.box(self, origin + Vector3(3,0.012,z*0.5), Vector3(6,0.012,0.016), Color("b6ae7f"), false, "brass")
	Geometry.box(self, origin + Vector3(3,0.018,5.25), Vector3(0.98,0.015,1.48), Color("ab7742"), false, "wood")
	var door := Interactable.new()
	door.kind = "exit"
	door.setup(self, origin + Vector3(3,1.1,6.16), Vector3(1.25,2.2,0.18), Color("614332"))
	# Rear wall sign faces the player entering from positive Z.
	title_sign = Geometry.label(self, origin + Vector3(3,2.65,0.02), "YOUR SHOP\n[B] Furnish  •  0.5m grid", 28)
	var light := OmniLight3D.new()
	add_child(light)
	light.position = origin + Vector3(3,2.8,3)
	light.light_color = Color("ffdda0")
	light.light_energy = 1.45
	light.omni_range = 9
	light.shadow_enabled = true
	furniture_root = Node3D.new()
	add_child(furniture_root)

func set_shop_name(value: String) -> void:
	if not is_instance_valid(title_sign): return
	title_sign.text = (value.to_upper() if not value.is_empty() else "YOUR SHOP") + "\n[B] Furnish  •  0.5m grid"

func contains(pos: Vector3) -> bool:
	return pos.x > -3.1 and pos.x < 3.1 and pos.z > 23.9 and pos.z < 30.2

func rebuild(entries: Array) -> void:
	for child in furniture_root.get_children():
		furniture_root.remove_child(child)
		child.queue_free()
	for entry in entries:
		var item := FurnitureFactory.create(entry.id, false, entry)
		furniture_root.add_child(item)
		item.position = GridRules.center(entry, origin)
		item.rotation.y = int(entry.turn) * PI / 2
