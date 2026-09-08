class_name ItemRegistry
extends RefCounted
static var definitions: Dictionary = {}

static func ensure_loaded() -> void:
	if not definitions.is_empty(): return
	_load_folder("res://items/definitions")

static func _load_folder(path: String) -> void:
	for filename in DirAccess.get_files_at(path):
		if filename.ends_with(".tres") or filename.ends_with(".tres.remap"):
			var item = load(path.path_join(filename.trim_suffix(".remap")))
			if item is ItemDefinition:
				assert(not definitions.has(item.id), "Duplicate item ID: " + item.id)
				assert(item.grid_size.x > 0 and item.grid_size.y > 0 and item.max_stack > 0)
				definitions[item.id] = item
	for folder in DirAccess.get_directories_at(path): _load_folder(path.path_join(folder))

static func get_item(id: String) -> ItemDefinition:
	ensure_loaded()
	return definitions.get(id)
