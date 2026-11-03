class_name DialogueLine
extends Resource

## 一句对白。对话系统（提示词【三十】）的最小单位。

@export var speaker: String = ""
@export_multiline var text: String = ""
## 可选头像。为空则不显示头像框。
@export var portrait: Texture2D = null
## 逐字显示速度覆盖（字符/秒）。<= 0 表示使用 DialogueManager 默认值。
@export var chars_per_second: float = 0.0
## 播放这句时附带的表情 / 动画名，交给 NPC 自行解释。
@export var emotion: StringName = &""
## 仅在满足该条件时才会播放这句。空表示无条件。
@export var condition: StringName = &""
## 说出这句后立刻执行的 flag 操作，形如 ["set:met_morris", "add_memory:wax_order"]。
@export var effects: PackedStringArray = PackedStringArray()

func has_condition() -> bool:
	return condition != &""


class Choice:
	extends Resource

	## 玩家可选项。选项可以跳转到别的 DialogueSequence，或直接结束。
	@export var text: String = ""
	## 目标对白资源路径；为空则结束当前对话。
	@export var next_sequence: String = ""
	## 仅在满足条件时显示。
	@export var condition: StringName = &""
	@export var effects: PackedStringArray = PackedStringArray()
