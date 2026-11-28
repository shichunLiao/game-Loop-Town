class_name ExplorationVisualProfile
extends RefCounted
## One inherited visual system for every exploration region family. Room data chooses
## a family; reachable geometry and collision remain outside the atmosphere shader.

const DEFAULT := {
	"far_contrast": 0.78, "far_saturation": 0.82, "far_brightness": 0.77, "far_fog": 0.18,
	"mid_contrast": 0.88, "mid_saturation": 0.90, "mid_brightness": 0.87, "mid_fog": 0.08,
	"fog_color": Color(0.12, 0.17, 0.20), "play_accent": Color(0.66, 0.73, 0.71),
	"outline_scale": 1.0, "rim_scale": 1.0, "fog_breath": 0.004
}

## Subregions are intentional variants of a family, not room-specific copies.
const FAMILY_PROFILES := {
	"town": {"fog_color":Color(0.105,0.17,0.215), "play_accent":Color(0.58,0.72,0.73), "outline_scale":0.96, "rim_scale":1.04},
	"theater": {"far_brightness":0.73, "mid_brightness":0.84, "fog_color":Color(0.14,0.105,0.12), "play_accent":Color(0.69,0.56,0.43), "outline_scale":0.91, "rim_scale":1.12},
	"backstage": {"far_brightness":0.70, "far_fog":0.22, "mid_brightness":0.82, "fog_color":Color(0.105,0.09,0.105), "play_accent":Color(0.63,0.52,0.42), "outline_scale":0.87, "rim_scale":1.18},
	"wax": {"far_brightness":0.74, "mid_brightness":0.85, "fog_color":Color(0.105,0.16,0.135), "play_accent":Color(0.65,0.58,0.39), "outline_scale":0.92, "rim_scale":1.10},
	"museum": {"far_contrast":0.76, "far_saturation":0.80, "far_brightness":0.73, "far_fog":0.21, "mid_brightness":0.85, "fog_color":Color(0.095,0.15,0.125), "play_accent":Color(0.67,0.57,0.36), "outline_scale":0.90, "rim_scale":1.12},
	"basement": {"far_contrast":0.74, "far_brightness":0.68, "far_fog":0.24, "mid_brightness":0.80, "fog_color":Color(0.075,0.115,0.105), "play_accent":Color(0.56,0.59,0.43), "outline_scale":0.84, "rim_scale":1.22},
	"station": {"far_saturation":0.80, "far_brightness":0.75, "fog_color":Color(0.115,0.145,0.16), "play_accent":Color(0.61,0.70,0.69), "outline_scale":0.94, "rim_scale":1.08},
	"well": {"far_contrast":0.74, "far_saturation":0.79, "far_brightness":0.69, "far_fog":0.23, "mid_brightness":0.81, "fog_color":Color(0.075,0.125,0.145), "play_accent":Color(0.52,0.67,0.69), "outline_scale":0.84, "rim_scale":1.23},
	"fire": {"far_saturation":0.84, "far_brightness":0.76, "far_fog":0.20, "mid_brightness":0.87, "fog_color":Color(0.20,0.105,0.07), "play_accent":Color(0.72,0.49,0.30), "outline_scale":0.80, "rim_scale":0.94, "fog_breath":0.003},
	"clocktower": {"far_contrast":0.75, "far_saturation":0.80, "far_brightness":0.70, "far_fog":0.22, "mid_brightness":0.82, "fog_color":Color(0.075,0.08,0.075), "play_accent":Color(0.70,0.40,0.22), "outline_scale":0.84, "rim_scale":1.20}
}

const ROLE_SETTINGS := {
	"player":{"outline":Color(0.13,0.075,0.055,0.98),"rim":Color(0.91,0.69,0.39,0.78),"width":1.85,"rim_width":0.82,"brightness":1.14,"face":0.075,"quality":8},
	"npc":{"outline":Color(0.14,0.09,0.07,0.90),"rim":Color(0.78,0.61,0.38,0.48),"width":1.50,"rim_width":0.60,"brightness":1.07,"face":0.035,"quality":4},
	"enemy":{"outline":Color(0.19,0.045,0.035,0.98),"rim":Color(0.76,0.24,0.14,0.58),"width":1.82,"rim_width":0.66,"brightness":1.08,"face":0.02,"quality":4},
	"boss":{"outline":Color(0.17,0.045,0.035,1.0),"rim":Color(0.98,0.50,0.20,0.72),"width":2.0,"rim_width":0.93,"brightness":1.13,"face":0.08,"quality":8},
	"keeper":{"outline":Color(0.17,0.045,0.035,1.0),"rim":Color(0.98,0.50,0.20,0.70),"width":1.94,"rim_width":0.90,"brightness":1.13,"face":0.08,"quality":8}
}

## Normalized atlas-local face windows. They lift faces, not the whole upper torso.
const FACE_REGIONS := {
	"hero":Vector4(0.34,0.66,0.15,0.39), "may_idle":Vector4(0.34,0.66,0.13,0.38),
	"keeper_back":Vector4(0.35,0.65,0.13,0.36), "keeper_hidden":Vector4(0.34,0.66,0.12,0.36),
	"keeper_unmasked":Vector4(0.34,0.66,0.12,0.38), "detective":Vector4(0.33,0.67,0.14,0.39)
}

static func family_for_room(room_id: String) -> String:
	var room := ExplorationCatalog.room(room_id)
	if room.is_empty():
		return ""
	var seen: Dictionary = {}
	while not room.is_empty():
		var background := str(room.get("background",""))
		if background in ["backstage","museum","basement"]:
			return background
		var theme := str(room.get("theme","town"))
		if FAMILY_PROFILES.has(theme):
			return theme
		var parent := str(room.get("parent_region",""))
		if parent.is_empty() or seen.has(parent):
			break
		seen[parent] = true
		room = ExplorationCatalog.room(parent)
	return ""

static func room_profile(room_id: String) -> Dictionary:
	var result: Dictionary = DEFAULT.duplicate(true)
	var family := family_for_room(room_id)
	result.merge(FAMILY_PROFILES.get(family,{}),true)
	result["family"] = family
	return result

static func atmosphere(profile: Dictionary, plane: String) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load("res://assets/environments/exploration/architecture/atmosphere.gdshader") as Shader
	material.set_shader_parameter("contrast",float(profile[plane+"_contrast"]))
	material.set_shader_parameter("saturation",float(profile[plane+"_saturation"]))
	material.set_shader_parameter("brightness",float(profile[plane+"_brightness"]))
	material.set_shader_parameter("fog_strength",float(profile[plane+"_fog"]))
	material.set_shader_parameter("fog_color",profile["fog_color"])
	material.set_shader_parameter("breath_amount",float(profile["fog_breath"]) if plane=="far" else 0.0)
	return material

static func configure_actor(material: ShaderMaterial, role: String, actor_id: String = "", room_id: String = "") -> void:
	var settings: Dictionary = ROLE_SETTINGS.get(role,ROLE_SETTINGS["npc"])
	var profile := room_profile(room_id)
	material.set_shader_parameter("outline_color",settings["outline"])
	material.set_shader_parameter("rim_color",settings["rim"])
	material.set_shader_parameter("outline_width",float(settings["width"])*float(profile["outline_scale"]))
	material.set_shader_parameter("rim_width",minf(0.98,float(settings["rim_width"])*float(profile["rim_scale"])))
	material.set_shader_parameter("body_brightness",settings["brightness"])
	material.set_shader_parameter("black_point",0.025)
	material.set_shader_parameter("white_point",0.84)
	material.set_shader_parameter("face_lift",settings["face"])
	material.set_shader_parameter("face_region",FACE_REGIONS.get(actor_id,Vector4(0.36,0.64,0.16,0.38)))
	material.set_shader_parameter("high_quality",int(settings["quality"])==8)

## Doors, exits and lift/ladder mechanisms share one quiet local cue: a small key
## badge with a short grounding stroke. It appears only while focused.
static func draw_guidance(host: CanvasItem, font: Font, position: Vector2) -> void:
	host.draw_line(position+Vector2(-18,17),position+Vector2(18,17),Color(0.63,0.76,0.70,0.48),1.0,true)
	host.draw_circle(position,12,Color(0.07,0.12,0.14,0.94))
	host.draw_arc(position,12,0,TAU,20,Color(0.76,0.69,0.53,0.82),1.0,true)
	host.draw_string(font,position+Vector2(-5,6),"E",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("e9dcc0"))
