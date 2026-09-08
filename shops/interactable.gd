class_name Interactable
extends StaticBody3D
var kind := "shop"
var shop_id := 0
var platform_id := ""
var loot_uid := ""

func prompt() -> String:
	if kind == "sale_platform":
		var listings: Array = Session.state.get("sale_stock",{}).get(platform_id,[])
		return "[E] Manage sale display · " + ("FOR SALE" if not listings.is_empty() else "Empty · stock from backpack")
	if kind == "delivery": return "[E] Collect your delivery"
	if kind == "supplies": return "[E] Open adventurer supplies · pick up equipment and items"
	if kind == "ground_loot": return "[E] Open dropped item chest"
	if kind == "imp": return "[E] Talk to Pip • order stock"
	if kind == "exit": return "[E] Return to Lantern Lane"
	if Session.state.purchased_shop == shop_id:
		var owned_name := str(Session.state.get("shop_name",""))
		return "[E] Enter " + (owned_name if not owned_name.is_empty() else "your shop")
	if Session.state.purchased_shop != -1: return "Unavailable • you already own a shop"
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
