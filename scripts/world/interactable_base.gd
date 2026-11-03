class_name InteractableBase
extends Area2D

## 可交互物基类。信件、镜子、拉杆、布偶、纽扣、剧情触发都用它。
##
## 玩家侧的 InteractionArea 只认两个方法：can_interact() / interact(player)。
## 新增交互物不需要改玩家代码（提示词【二十七】第 13 条：用 signal 解耦）。

signal interacted(player: Node)

## 交互提示。
@export var interact_prompt: String = "互动"
## 满足该条件才能交互（空 = 无限制）。
@export var require_condition: StringName = &""
## 条件不满足时显示的话。
@export var blocked_message: String = ""
## 是否只能交互一次。
@export var one_shot: bool = false
## 交互后置位的 flag。
@export var set_flag: StringName = &""
## 交互时播放的音效。
@export var sfx: String = "interact"

var has_been_used: bool = false


func _ready() -> void:
	add_to_group(&"interactable")
	collision_layer = 1 << 5   # layer 6 = interactable
	collision_mask = 0
	_ensure_shape()
	_interactable_ready()


## 子类重写做自己的初始化。
func _interactable_ready() -> void:
	pass


func _ensure_shape() -> void:
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node != null and shape_node.shape != null:
		return
	if shape_node == null:
		shape_node = CollisionShape2D.new()
		shape_node.name = "CollisionShape2D"
		add_child(shape_node)
	var circle := CircleShape2D.new()
	circle.radius = 28.0
	shape_node.shape = circle


# ---------------------------------------------------------------------------
# 玩家接口
# ---------------------------------------------------------------------------

func can_interact() -> bool:
	if one_shot and has_been_used:
		return false
	if DialogueManager != null and DialogueManager.is_active:
		return false
	if not require_condition.is_empty() and not GameManager.evaluate_condition(require_condition):
		return false
	return true


func get_interact_prompt() -> String:
	return interact_prompt


func interact(player: Node) -> void:
	if one_shot and has_been_used:
		return
	if not require_condition.is_empty() and not GameManager.evaluate_condition(require_condition):
		if not blocked_message.is_empty():
			_show_message(blocked_message)
		return

	has_been_used = true
	if not set_flag.is_empty():
		GameManager.set_flag(set_flag, true)
	if not sfx.is_empty():
		AudioManager.play_sfx(sfx)
	interacted.emit(player)
	_on_interacted(player)


## 子类重写它实现具体行为。
func _on_interacted(_player: Node) -> void:
	pass


## 用一行对白显示提示，不额外引入 UI。
func _show_message(message: String) -> void:
	var sequence := DialogueSequence.new()
	sequence.id = &"hint"
	var line := DialogueLine.new()
	line.speaker = ""
	line.text = message
	sequence.lines = [line] as Array[DialogueLine]
	DialogueManager.start(sequence)
