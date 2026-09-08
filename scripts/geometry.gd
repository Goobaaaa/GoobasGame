class_name Geometry
extends RefCounted

static func material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85
	return m

static func box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, solid: bool = true) -> Node3D:
	var root: Node3D = StaticBody3D.new() if solid else Node3D.new()
	parent.add_child(root)
	root.position = pos
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = material(color)
	root.add_child(mesh)
	if solid:
		var collision := CollisionShape3D.new()
		var s := BoxShape3D.new()
		s.size = size
		collision.shape = s
		root.add_child(collision)
	return root

static func label(parent: Node3D, pos: Vector3, title: String, size: int = 32) -> Label3D:
	var l := Label3D.new()
	l.text = title
	l.font_size = size
	l.pixel_size = 0.008
	l.position = pos
	l.modulate = Color("f4dfaa")
	l.outline_modulate = Color("322a28")
	parent.add_child(l)
	return l

static func roof(parent: Node3D, pos: Vector3, width: float, depth: float) -> void:
	# Simple pitched triangular prism, kept separate from gameplay collision.
	var w := width / 2.0
	var d := depth / 2.0
	var points := [Vector3(-w,0,-d),Vector3(w,0,-d),Vector3(-w,0,d),Vector3(w,0,d),Vector3(-w,1.3,0),Vector3(w,1.3,0)]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in [0,1,5,0,5,4,2,4,5,2,5,3,0,4,2,1,3,5]:
		surface.add_vertex(points[index])
	surface.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.mesh = surface.commit()
	var mat := material(Color("695760"))
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material_override = mat
	parent.add_child(mesh)
	mesh.position = pos
