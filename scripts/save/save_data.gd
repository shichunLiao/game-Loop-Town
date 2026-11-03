class_name SaveData
extends Resource

## 存档数据结构（提示词【七】【二十六】：存档统一由 SaveManager 处理）。
##
## 只保存“必要且可序列化”的状态；任何运行期节点引用都不进存档。

const CURRENT_VERSION: int = 1

@export var version: int = CURRENT_VERSION

# --- 循环（LoopManager） ---
@export var loop_count: int = 247
@export var previous_loop_count: int = 246

# --- 世界状态（WorldStateManager） ---
@export var world_state_index: int = 0
@export var completed_chapters: PackedStringArray = PackedStringArray()

# --- 位置 ---
@export var current_map_id: StringName = &"town_entrance"
@export var spawn_id: StringName = &"default"
@export var checkpoint_map_id: StringName = &"town_entrance"
@export var checkpoint_spawn_id: StringName = &"default"
@export var checkpoint_position: Vector2 = Vector2.ZERO

# --- 玩家 ---
@export var player_max_health: int = 100
@export var player_health: int = 100

# --- 收集与剧情 ---
@export var collected_memory_ids: PackedStringArray = PackedStringArray()
@export var flags: Dictionary = {}
@export var item_counts: Dictionary = {}
@export var solved_puzzles: PackedStringArray = PackedStringArray()

# --- Boss 进度 ---
@export var boss_progress: Dictionary = {}

# --- 结局 ---
@export var ending_state: int = 0  ## 0 = 未定，见 LoopManager.EndingState

# --- 统计（仅供开发与调试） ---
@export var play_seconds: float = 0.0
@export var death_count: int = 0


func to_dict() -> Dictionary:
	return {
		"version": version,
		"loop_count": loop_count,
		"previous_loop_count": previous_loop_count,
		"world_state_index": world_state_index,
		"completed_chapters": Array(completed_chapters),
		"current_map_id": String(current_map_id),
		"spawn_id": String(spawn_id),
		"checkpoint_map_id": String(checkpoint_map_id),
		"checkpoint_spawn_id": String(checkpoint_spawn_id),
		"checkpoint_position": [checkpoint_position.x, checkpoint_position.y],
		"player_max_health": player_max_health,
		"player_health": player_health,
		"collected_memory_ids": Array(collected_memory_ids),
		"flags": flags.duplicate(true),
		"item_counts": item_counts.duplicate(true),
		"solved_puzzles": Array(solved_puzzles),
		"boss_progress": boss_progress.duplicate(true),
		"ending_state": ending_state,
		"play_seconds": play_seconds,
		"death_count": death_count,
	}


func from_dict(data: Dictionary) -> void:
	version = int(data.get("version", CURRENT_VERSION))
	loop_count = int(data.get("loop_count", 247))
	previous_loop_count = int(data.get("previous_loop_count", loop_count - 1))
	world_state_index = int(data.get("world_state_index", 0))
	completed_chapters = _to_string_array(data.get("completed_chapters", []))
	current_map_id = StringName(str(data.get("current_map_id", "town_entrance")))
	spawn_id = StringName(str(data.get("spawn_id", "default")))
	checkpoint_map_id = StringName(str(data.get("checkpoint_map_id", "town_entrance")))
	checkpoint_spawn_id = StringName(str(data.get("checkpoint_spawn_id", "default")))
	checkpoint_position = _to_vector2(data.get("checkpoint_position", [0.0, 0.0]))
	player_max_health = int(data.get("player_max_health", 100))
	player_health = int(data.get("player_health", player_max_health))
	collected_memory_ids = _to_string_array(data.get("collected_memory_ids", []))
	flags = (data.get("flags", {}) as Dictionary).duplicate(true)
	item_counts = (data.get("item_counts", {}) as Dictionary).duplicate(true)
	solved_puzzles = _to_string_array(data.get("solved_puzzles", []))
	boss_progress = (data.get("boss_progress", {}) as Dictionary).duplicate(true)
	ending_state = int(data.get("ending_state", 0))
	play_seconds = float(data.get("play_seconds", 0.0))
	death_count = int(data.get("death_count", 0))


static func _to_string_array(value: Variant) -> PackedStringArray:
	var out := PackedStringArray()
	if value is Array:
		for entry in value:
			out.append(str(entry))
	return out


static func _to_vector2(value: Variant) -> Vector2:
	if value is Array and (value as Array).size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO
