class_name FurnitureFactory
extends RefCounted
## GLBs carry visuals only; catalog dimensions define placement/collision.
static func create(id: String, ghost: bool) -> Node3D:
	var root := Node3D.new()
	var d: Dictionary = Catalog.FURNITURE[id]
	var path := "res://assets/furniture/" + id + ".glb"
	var visual: Node3D
	if ResourceLoader.exists(path):
		visual = (load(path) as PackedScene).instantiate()
		root.add_child(visual)
	else:
		# Deliberate fallback if an artist temporarily removes a prototype GLB.
		visual = Geometry.box(root, Vector3(0,float(d.height)/2,0), Vector3(d.size[0]*0.5-0.05,d.height,d.size[1]*0.5-0.05), Color("946337"), false)
	var lift := 1.35 if d.get("wall",false) else 0.0
	# Blender +Y maps to Godot -Z; align model backs with grid turn zero (+Z).
	visual.rotation.y = PI
	visual.position.y += lift
	if not ghost:
		var body := StaticBody3D.new()
		root.add_child(body)
		var c := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(d.size[0]*0.5-0.04,d.height,d.size[1]*0.5-0.04)
		c.shape = shape
		c.position.y = d.height/2.0 + lift
		body.add_child(c)
	return root

static func tint(node: Node, color: Color) -> void:
	if node is MeshInstance3D:
		var m := Geometry.material(color)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		node.material_override = m
	for child in node.get_children(): tint(child,color)
