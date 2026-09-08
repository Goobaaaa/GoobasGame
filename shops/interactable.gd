class_name Interactable
extends StaticBody3D
var kind := "shop"
var shop_id := 0

func prompt() -> String:
	if kind == "imp": return "[E] Talk to Pip • order stock"
	if kind == "exit": return "[E] Return to Lantern Lane"
	if Session.state.purchased_shop == shop_id: return "[E] Enter " + Catalog.SHOP_NAMES[shop_id]
	if Session.state.purchased_shop != -1: return "Unavailable • your co-op already owns a shop"
	return "[E] Buy " + Catalog.SHOP_NAMES[shop_id] + " • 300 gold"

func setup(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> void:
	parent.add_child(self)
	position = pos
	Geometry.box(self, Vector3.ZERO, size, color, false)
	var c := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = size
	c.shape = s
	add_child(c)

