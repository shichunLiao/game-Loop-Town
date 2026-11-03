extends Node

## 世界状态管理器（autoload）— 提示词【十】。
##
## 核心约束：**不能只是加载不同场景**。同一张小镇地图必须能够在
## 灯光、背景、NPC、天气、颜色、音效、特效、敌人、环境动画上表现不同阶段。
##
## 实现方式：
##   1. 本管理器维护一个全局 CanvasModulate（自动挂到根节点），统一叠色。
##   2. 通过信号把“阶段已改变”广播给所有关心的人（地图、NPC、敌人、AudioManager）。
##   3. 每个阶段带一份 WorldStateProfile，描述该阶段的全部外观参数。
## 地图不需要认识阶段编号，只需要响应 world_state_changed。

signal world_state_changed(profile: WorldStateProfile)

enum Stage {
	STATE_0_DUSK = 0,             ## 黄昏
	STATE_1_LATE_DUSK = 1,        ## 黄昏更接近夜晚
	STATE_2_NIGHT = 2,            ## 夜
	STATE_3_DEFORMED_NIGHT = 3,   ## 扭曲之夜
	STATE_4_FIRE = 4,             ## 火海
	STATE_5_MORNING = 5,          ## 清晨
}

const PROFILES: Dictionary = {
	Stage.STATE_0_DUSK: {
		"label": "黄昏",
		"tint": Color(0.98, 0.86, 0.74),
		"energy": 0.92,
		"light_energy": 1.0,
		"fog_density": 0.04,
		"weather": &"fog",
		"ambient": "amb_town_dusk",
		"music": "mus_town",
		"enemy_variant": &"normal",
		"npc_mood": &"normal",
		"distortion": 0.0,
	},
	Stage.STATE_1_LATE_DUSK: {
		"label": "暮色渐深",
		"tint": Color(0.80, 0.72, 0.78),
		"energy": 0.80,
		"light_energy": 1.15,
		"fog_density": 0.07,
		"weather": &"fog",
		"ambient": "amb_town_dusk",
		"music": "mus_town",
		"enemy_variant": &"normal",
		"npc_mood": &"uneasy",
		"distortion": 0.06,
	},
	Stage.STATE_2_NIGHT: {
		"label": "夜",
		"tint": Color(0.58, 0.62, 0.82),
		"energy": 0.62,
		"light_energy": 1.35,
		"fog_density": 0.10,
		"weather": &"clear",
		"ambient": "amb_town_night",
		"music": "mus_night",
		"enemy_variant": &"stronger",
		"npc_mood": &"dazed",
		"distortion": 0.14,
	},
	Stage.STATE_3_DEFORMED_NIGHT: {
		"label": "扭曲之夜",
		"tint": Color(0.52, 0.44, 0.62),
		"energy": 0.52,
		"light_energy": 1.5,
		"fog_density": 0.16,
		"weather": &"storm",
		"ambient": "amb_town_deformed",
		"music": "mus_deformed",
		"enemy_variant": &"stronger",
		"npc_mood": &"hostile",
		"distortion": 0.30,
	},
	Stage.STATE_4_FIRE: {
		"label": "火海",
		"tint": Color(1.0, 0.56, 0.32),
		"energy": 1.0,
		"light_energy": 1.8,
		"fog_density": 0.22,
		"weather": &"fire",
		"ambient": "amb_fire",
		"music": "mus_fire",
		"enemy_variant": &"burning",
		"npc_mood": &"burning",
		"distortion": 0.5,
	},
	Stage.STATE_5_MORNING: {
		"label": "清晨",
		"tint": Color(1.0, 0.97, 0.92),
		"energy": 1.0,
		"light_energy": 0.9,
		"fog_density": 0.02,
		"weather": &"clear",
		"ambient": "amb_morning",
		"music": "mus_morning",
		"enemy_variant": &"none",
		"npc_mood": &"normal",
		"distortion": 0.0,
	},
}

var current_stage: Stage = Stage.STATE_0_DUSK
var current_profile: WorldStateProfile = null

var _canvas_modulate: CanvasModulate = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_canvas_modulate()
	_apply_stage()
	# 章节通关后自动推进阶段，由 GameManager.chapter_completed 驱动。
	if GameManager != null:
		GameManager.chapter_completed.connect(_on_chapter_completed)


## 保证根节点上恰有一个全局叠色节点。
func _ensure_canvas_modulate() -> void:
	if _canvas_modulate != null and is_instance_valid(_canvas_modulate):
		return
	var root := get_tree().root
	_canvas_modulate = CanvasModulate.new()
	_canvas_modulate.name = "WorldStateTint"
	# 注意：本方法可能在 autoload 的 _ready() 里被调用，此时 root 正在装配子节点，
	# 直接 add_child 会失败（"Parent node is busy setting up children"），
	# 因此必须延迟到下一帧空闲时再挂载。
	root.add_child.call_deferred(_canvas_modulate)


# ---------------------------------------------------------------------------
# 查询
# ---------------------------------------------------------------------------

func get_stage_label() -> String:
	return current_profile.label if current_profile != null else ""


func is_night() -> bool:
	return current_stage == Stage.STATE_2_NIGHT or current_stage == Stage.STATE_3_DEFORMED_NIGHT


func is_fire() -> bool:
	return current_stage == Stage.STATE_4_FIRE


## 当前阶段的敌人强度倍率。地图据此挑选敌人变体。
func get_enemy_stat_multiplier() -> float:
	match current_stage:
		Stage.STATE_0_DUSK: return 1.0
		Stage.STATE_1_LATE_DUSK: return 1.05
		Stage.STATE_2_NIGHT: return 1.15
		Stage.STATE_3_DEFORMED_NIGHT: return 1.3
		Stage.STATE_4_FIRE: return 1.4
		Stage.STATE_5_MORNING: return 0.0
	return 1.0


# ---------------------------------------------------------------------------
# 迁移
# ---------------------------------------------------------------------------

func reset_to_initial() -> void:
	set_stage(Stage.STATE_0_DUSK, false)


## 章节通关推进。映射关系按提示词【十】：
##   第一章 → 暮色渐深；第二章 → 夜；第三章 → 扭曲之夜；
##   第四章 → 火海前夜（保持扭曲之夜，钟楼成为唯一正常区域）；
##   最终   → 火海；真结局 → 清晨。
func advance_for_chapter(chapter_number: int) -> void:
	match chapter_number:
		1:
			set_stage(Stage.STATE_1_LATE_DUSK)
		2:
			set_stage(Stage.STATE_2_NIGHT)
		3:
			set_stage(Stage.STATE_3_DEFORMED_NIGHT)
		4:
			set_stage(Stage.STATE_3_DEFORMED_NIGHT)
		_:
			pass


func set_stage(stage: Stage, animate: bool = true) -> void:
	current_stage = stage
	_apply_stage(animate)
	world_state_changed.emit(current_profile)


func set_stage_index(index: int) -> void:
	var clamped := clampi(index, 0, Stage.size() - 1)
	set_stage(clamped as Stage)


func _on_chapter_completed(chapter_key: StringName) -> void:
	# 章节 key 形如 chapter_1_cleared，这里只做兜底，主推进由
	# GameManager.complete_chapter 直接调用 advance_for_chapter 完成。
	var text := String(chapter_key)
	if not text.begins_with("chapter_"):
		return
	var number_text := text.trim_prefix("chapter_").trim_suffix("_cleared")
	if number_text.is_valid_int():
		advance_for_chapter(int(number_text))


func _apply_stage(animate: bool = true) -> void:
	var raw: Dictionary = PROFILES.get(current_stage, {})
	current_profile = WorldStateProfile.from_dict(raw, current_stage)
	_ensure_canvas_modulate()
	if _canvas_modulate == null:
		return
	if animate and is_inside_tree():
		var tween := create_tween()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_property(_canvas_modulate, "color", current_profile.tint, 1.2)
	else:
		_canvas_modulate.color = current_profile.tint


# ---------------------------------------------------------------------------
# 存档对接
# ---------------------------------------------------------------------------

func collect_save_data(data: SaveData) -> void:
	data.world_state_index = int(current_stage)


func apply_save_data(data: SaveData) -> void:
	set_stage_index(data.world_state_index)
