class_name ExplorationCatalog
extends RefCounted
## One shared source for room geometry, exits, world-map layout and progression.

const DATA_PATH: String = "res://data/exploration/world.json"
static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		if parsed is Dictionary:
			_data = parsed
	return _data

static func room(id: String) -> Dictionary:
	return data().get("rooms", {}).get(id, {})

static func vec(value: Array) -> Vector2:
	return Vector2(float(value[0]), float(value[1]))

static func color_for(theme: String) -> Color:
	return Color(str(data().get("themes", {}).get(theme, {}).get("accent", "88d3dd")))

static func title(id: String) -> String:
	return str(room(id).get("name", id))
