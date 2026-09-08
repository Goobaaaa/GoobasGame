class_name SaleDisplayVisual
extends RefCounted
## Stable unit coordinates provide anchors for future product meshes, independently of UI.
static func build(root: Node3D, entry: Dictionary) -> void:
	var surface := SaleStock.definition(entry)
	var furniture: Dictionary = Catalog.FURNITURE[entry.id]
	var listings: Array = Session.state.get("sale_stock",{}).get(SaleStock.key(entry),[])
	var count := 0
	var width: float = furniture.size[0] * 0.5 - 0.12
	var depth: float = furniture.size[1] * 0.5 - 0.12
	for listing in listings:
		var d := ItemRegistry.get_item(listing.item.id)
		for unit in listing.units:
			count += 1
			var footprint := SaleStock.item_size(d.id,unit.rotated)
			var anchor := Node3D.new()
			anchor.name = "Unit_" + str(count)
			root.add_child(anchor)
			anchor.position = Vector3(-width/2 + (unit.x+footprint.x/2.0)*width/surface.size.x, surface.heights[int(unit.tier)], -depth/2 + (unit.y+footprint.y/2.0)*depth/surface.size.y)
			anchor.rotation.y = PI/2 if unit.rotated else 0.0
			if d.visual != null:
				var model := d.visual.instantiate()
				if model is Node3D:
					anchor.add_child(model)
					model.scale = Vector3.ONE * d.display_scale
				else: model.free()
			else:
				# Simple per-unit packages make quantity and occupied space visible now.
				var size := SaleStock.item_size(d.id)
				Geometry.box(anchor,Vector3(0,0.07,0),Vector3(size.x*width/surface.size.x*0.8,0.14,size.y*depth/surface.size.y*0.8),Color("a38a62"),false)
				if d.icon:
					var icon := Sprite3D.new()
					icon.texture = d.icon
					icon.pixel_size = 0.002
					icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
					icon.position.y = 0.17
					anchor.add_child(icon)
	var height: float = surface.heights.back() + 0.3
	var title := "FOR SALE · %d item(s)\n[E] Stock & prices" % count if count > 0 else "EMPTY DISPLAY\n[E] Stock items"
	var tag := Geometry.label(root,Vector3(0,height,0),title,17)
	tag.pixel_size = 0.0035
	tag.modulate = Color("a1f1b2") if count > 0 else Color("d8cfb6")
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
