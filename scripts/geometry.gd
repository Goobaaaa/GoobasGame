class_name Geometry
extends RefCounted

static var _material_cache: Dictionary = {}

static func material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if _material_cache.has(key):
		return _material_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85
	_material_cache[key] = m
	return m

static func box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, solid: bool = true, material_name: String = "") -> Node3D:
	var root: Node3D = StaticBody3D.new() if solid else Node3D.new()
	parent.add_child(root)
	root.position = pos
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = MaterialLibrary.get_material(material_name) if not material_name.is_empty() else material(color)
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
	# The roof now has explicit UVs and a shared stylised material so it can scale
	# beyond the original flat-colour blockout.
	var w := width / 2.0
	var d := depth / 2.0
	var points := [
		Vector3(-w,0,-d), Vector3(w,0,-d),
		Vector3(-w,0,d), Vector3(w,0,d),
		Vector3(-w,1.3,0), Vector3(w,1.3,0)
	]
	var indices := [0,1,5,0,5,4,2,4,5,2,5,3,0,4,2,1,3,5]
	var uvs := [
		Vector2(0,1), Vector2(1,1), Vector2(0,0),
		Vector2(1,0), Vector2(0,0.5), Vector2(1,0.5)
	]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in indices:
		surface.set_uv(uvs[index])
		surface.add_vertex(points[index])
	surface.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.mesh = surface.commit()
	var mat := MaterialLibrary.get_material("wood")
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material_override = mat
	parent.add_child(mesh)
	mesh.position = pos
