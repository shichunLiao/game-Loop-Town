class_name NPCBase
extends EnemyBase

## NPC 基类。镇民、莫里斯、皮埃罗、看守都继承它。
##
## 相对 EnemyBase 增加的是「可对话」与「交互提示」，
## 因此地图上的交互统一走 interact() / get_interact_prompt() 两个接口，
## 玩家不需要认识任何具体 NPC 类型（提示词【二十七】第 13 条：用 signal 解耦）。

signal dialogue_finished(sequence_id: StringName)
signal interacted_with(player: Node)

## 对白资源路径。留空表示该 NPC 不说话。
@export_file("*.tres") var dialogue_path: String = ""
## 满足该条件时才允许对话（例如必须先拿到某道具）。
@export var dialogue_condition: StringName = &""
## 交互提示文案。
@export var interact_prompt: String = "交谈"
## 对话结束后切换到的对白（例如见过面之后换一套台词）。
@export_file("*.tres") var dialogue_path_after: String = ""
## 换台词所依赖的 flag。
@export var dialogue_switch_flag: StringName = &""

var _dialogue_listener_active: bool = false


func _after_ready() -> void:
	add_to_group(&"npc")
	super._after_ready()


# ---------------------------------------------------------------------------
# 交互接口（玩家侧统一调用这两个）
# ---------------------------------------------------------------------------

func can_interact() -> bool:
	if is_dead:
		return false
	if DialogueManager != null and DialogueManager.is_active:
		return false
	if dialogue_path.is_empty():
		return false
	if not dialogue_condition.is_empty():
		return GameManager.evaluate_condition(dialogue_condition)
	return true


func get_interact_prompt() -> String:
	return interact_prompt


func interact(player: Node) -> void:
	interacted_with.emit(player)
	var path := _resolve_dialogue_path()
	if path.is_empty():
		return
	_connect_dialogue_listener()
	DialogueManager.start_from_path(path)


## 按 flag 决定用哪一套台词。这样「同一 NPC 在剧情前后说不同的话」
## 完全由数据驱动，不需要在脚本里写 if 分支。
func _resolve_dialogue_path() -> String:
	if not dialogue_path_after.is_empty() and not dialogue_switch_flag.is_empty():
		if GameManager.has_flag(dialogue_switch_flag):
			return dialogue_path_after
	return dialogue_path


func _connect_dialogue_listener() -> void:
	if _dialogue_listener_active:
		return
	_dialogue_listener_active = true
	DialogueManager.dialogue_finished.connect(_on_any_dialogue_finished, CONNECT_ONE_SHOT)


func _on_any_dialogue_finished(sequence: DialogueSequence) -> void:
	_dialogue_listener_active = false
	if sequence == null:
		return
	dialogue_finished.emit(sequence.id)


# ---------------------------------------------------------------------------
# 面朝玩家
# ---------------------------------------------------------------------------

## 让 NPC 转身看向某个位置。WATCHER 型镇民与莫里斯都会用。
func face_position(world_position: Vector2) -> void:
	var delta_x := world_position.x - global_position.x
	if absf(delta_x) < 2.0:
		return
	set_facing(1 if delta_x > 0.0 else -1)
