class_name DialogueTrigger
extends InteractableBase

## 直接展示一段文字的可交互物。
##
## 用于木牌、公告栏、海报这类“环境叙事”载体（提示词【四十四】：
## 不要用纯文本解释，必须让玩家从场景与文字里自己拼）。
##
## 与 NPCBase 的区别：这里没有角色形象，文字直接写在关卡数据里，
## 不需要为一块木牌单独做一个 .tres 对白资源。

## 要显示的文字。\n 表示换行（JSON 里写 \n）。
@export_multiline var inline_text: String = ""
## 是否在显示后同时置位一个 flag（环境叙事常常也是进度条件）。
@export var set_flag_on_read: StringName = &""

var _has_been_read: bool = false


func _interactable_ready() -> void:
	if interact_prompt.is_empty():
		interact_prompt = "查看"
	sfx = "interact"


func can_interact() -> bool:
	if not super.can_interact():
		return false
	return not inline_text.is_empty()


func _on_interacted(_player: Node) -> void:
	if inline_text.is_empty():
		return
	_has_been_read = true
	if not set_flag_on_read.is_empty():
		GameManager.set_flag(set_flag_on_read, true)

	# 用一行对白展示，不引入额外 UI。
	var sequence := DialogueSequence.new()
	sequence.id = &"inline_text"
	var line := DialogueLine.new()
	line.speaker = ""
	line.text = inline_text
	sequence.lines = [line] as Array[DialogueLine]
	DialogueManager.start(sequence)


func has_been_read() -> bool:
	return _has_been_read
