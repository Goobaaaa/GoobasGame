class_name ShopNaming
extends RefCounted
## Validation shared by the naming UI, save validation, and authoritative actions.
const MIN_LENGTH := 3
const MAX_LENGTH := 30

static func normalize(value: String) -> String:
	var result := value.strip_edges().replace("\r", " ").replace("\n", " ").replace("\t", " ")
	while result.contains("  "): result = result.replace("  ", " ")
	return result.strip_edges()

static func validate(value: String) -> String:
	var name := normalize(value)
	if name.is_empty(): return "Enter a name for your shop."
	if name.length() < MIN_LENGTH: return "Shop names must be at least %d characters." % MIN_LENGTH
	if name.length() > MAX_LENGTH: return "Shop names can be at most %d characters." % MAX_LENGTH
	for character in name:
		if character.unicode_at(0) < 32: return "That shop name contains an invalid control character."
	return ""
