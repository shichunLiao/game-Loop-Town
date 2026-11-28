class_name ExplorationVisualProfile
extends RefCounted
## Visual-only tuning for the first dark-stage picture-book pass.
## Gameplay surfaces stay outside the atmosphere shader so their edges remain crisp.

const DEFAULT := {
	"far_contrast": 0.78, "far_saturation": 0.82, "far_brightness": 0.78, "far_fog": 0.18,
	"mid_contrast": 0.88, "mid_saturation": 0.90, "mid_brightness": 0.88, "mid_fog": 0.08,
	"fog_color": Color(0.12, 0.17, 0.20), "play_accent": Color(0.72, 0.78, 0.74)
}

const PROFILES := {
	"town_entrance": {
		"far_contrast": 0.76, "far_saturation": 0.82, "far_brightness": 0.76, "far_fog": 0.22,
		"mid_contrast": 0.88, "mid_saturation": 0.89, "mid_brightness": 0.86, "mid_fog": 0.10,
		"fog_color": Color(0.105, 0.17, 0.215), "play_accent": Color(0.69, 0.82, 0.82)
	},
	"wax_museum": {
		"far_contrast": 0.77, "far_saturation": 0.81, "far_brightness": 0.74, "far_fog": 0.20,
		"mid_contrast": 0.89, "mid_saturation": 0.88, "mid_brightness": 0.86, "mid_fog": 0.09,
		"fog_color": Color(0.105, 0.16, 0.135), "play_accent": Color(0.73, 0.62, 0.38)
	},
	"clock_tower": {
		"far_contrast": 0.75, "far_saturation": 0.80, "far_brightness": 0.72, "far_fog": 0.21,
		"mid_contrast": 0.87, "mid_saturation": 0.88, "mid_brightness": 0.84, "mid_fog": 0.08,
		"fog_color": Color(0.085, 0.09, 0.085), "play_accent": Color(0.93, 0.48, 0.17)
	}
}

static func room_profile(room_id: String) -> Dictionary:
	var result: Dictionary = DEFAULT.duplicate(true)
	if PROFILES.has(room_id):
		result.merge(PROFILES[room_id], true)
	return result

static func atmosphere(profile: Dictionary, plane: String) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load("res://assets/environments/exploration/architecture/atmosphere.gdshader") as Shader
	material.set_shader_parameter("contrast", float(profile[plane+"_contrast"]))
	material.set_shader_parameter("saturation", float(profile[plane+"_saturation"]))
	material.set_shader_parameter("brightness", float(profile[plane+"_brightness"]))
	material.set_shader_parameter("fog_strength", float(profile[plane+"_fog"]))
	material.set_shader_parameter("fog_color", profile["fog_color"])
	return material

static func configure_actor(material: ShaderMaterial, role: String) -> void:
	var outline := Color(0.13, 0.075, 0.055, 0.98)
	var rim := Color(0.91, 0.69, 0.39, 0.78)
	var outline_width: float = 1.85
	var rim_width: float = 0.82
	var body_brightness: float = 1.14
	var face_lift: float = 0.07
	if role == "npc":
		outline = Color(0.14, 0.09, 0.07, 0.90)
		rim = Color(0.78, 0.61, 0.38, 0.48)
		outline_width = 1.55
		rim_width = 0.62
		body_brightness = 1.07
		face_lift = 0.035
	elif role == "enemy":
		outline = Color(0.19, 0.045, 0.035, 0.98)
		rim = Color(0.76, 0.24, 0.14, 0.58)
		outline_width = 1.9
		rim_width = 0.68
		body_brightness = 1.08
		face_lift = 0.02
	elif role in ["boss", "keeper"]:
		outline = Color(0.17, 0.045, 0.035, 1.0)
		rim = Color(0.98, 0.50, 0.20, 0.72)
		outline_width = 2.0
		rim_width = 0.95
		body_brightness = 1.13
		face_lift = 0.075
	material.set_shader_parameter("outline_color", outline)
	material.set_shader_parameter("rim_color", rim)
	material.set_shader_parameter("outline_width", outline_width)
	material.set_shader_parameter("rim_width", rim_width)
	material.set_shader_parameter("body_brightness", body_brightness)
	material.set_shader_parameter("black_point", 0.025)
	material.set_shader_parameter("white_point", 0.84)
	material.set_shader_parameter("face_lift", face_lift)
