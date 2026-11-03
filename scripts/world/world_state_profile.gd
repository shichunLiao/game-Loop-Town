class_name WorldStateProfile
extends Resource

## 一个世界阶段的完整外观描述（提示词【十】）。
##
## 做成独立类型而不是裸 Dictionary，是为了让地图 / NPC / 特效在拿到它时
## 有明确的字段与类型提示，避免到处 `dict.get("x", default)`。

@export var stage_index: int = 0
@export var label: String = ""
## 全局叠色。
@export var tint: Color = Color.WHITE
## 叠色强度 0..1，交给光照与背景调制使用。
@export var energy: float = 1.0
## 灯源强度倍率（路灯、钟楼、窗户）。
@export var light_energy: float = 1.0
@export var fog_density: float = 0.05
## "clear" | "fog" | "storm" | "fire"
@export var weather: StringName = &"clear"
## AudioManager 的环境声 / 音乐标识。
@export var ambient: String = ""
@export var music: String = ""
## "none" | "normal" | "stronger" | "burning"
@export var enemy_variant: StringName = &"normal"
## "normal" | "uneasy" | "dazed" | "hostile" | "burning"
@export var npc_mood: StringName = &"normal"
## 画面扭曲强度 0..1，交给后处理 / 顶点着色器。
@export var distortion: float = 0.0


static func from_dict(raw: Dictionary, stage_index_value: int) -> WorldStateProfile:
	var profile := WorldStateProfile.new()
	profile.stage_index = stage_index_value
	profile.label = str(raw.get("label", ""))
	profile.tint = raw.get("tint", Color.WHITE)
	profile.energy = float(raw.get("energy", 1.0))
	profile.light_energy = float(raw.get("light_energy", 1.0))
	profile.fog_density = float(raw.get("fog_density", 0.05))
	profile.weather = StringName(raw.get("weather", &"clear"))
	profile.ambient = str(raw.get("ambient", ""))
	profile.music = str(raw.get("music", ""))
	profile.enemy_variant = StringName(raw.get("enemy_variant", &"normal"))
	profile.npc_mood = StringName(raw.get("npc_mood", &"normal"))
	profile.distortion = float(raw.get("distortion", 0.0))
	return profile
