class_name MaterialLibrary
extends RefCounted

## Shared stylised materials for the 1080p PC art pass.
## Keeping these resources cached prevents hundreds of near-identical material instances.
static var _cache: Dictionary = {}

static func get_material(name: String) -> StandardMaterial3D:
	if _cache.has(name):
		return _cache[name]

	var material := StandardMaterial3D.new()
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3(0.75, 0.75, 0.75)

	match name:
		"wood":
			material.albedo_texture = load("res://assets/textures/stylized/wood_planks_albedo.svg")
			material.roughness = 0.72
		"stone":
			material.albedo_texture = load("res://assets/textures/stylized/stone_floor_albedo.svg")
			material.roughness = 0.92
			material.uv1_scale = Vector3(0.55, 0.55, 0.55)
		"plaster":
			material.albedo_texture = load("res://assets/textures/stylized/plaster_wall_albedo.svg")
			material.roughness = 0.96
			material.uv1_scale = Vector3(0.45, 0.45, 0.45)
		"brass":
			material.albedo_texture = load("res://assets/textures/stylized/aged_brass_albedo.svg")
			material.metallic = 0.78
			material.roughness = 0.5
			material.uv1_scale = Vector3(1.2, 1.2, 1.2)
		_:
			material.albedo_color = Color.WHITE
			material.roughness = 0.85

	_cache[name] = material
	return material
