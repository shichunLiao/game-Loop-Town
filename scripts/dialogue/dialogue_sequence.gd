class_name DialogueSequence
extends Resource

## 一段完整对白（一个 NPC 的一次完整谈话）。
##
## 支持条件分支：条件不满足的行会被跳过，因此同一份资源可以在不同进度下
## 表现出不同内容——这正是“同一文本、不同语境”的实现方式。

@export var id: StringName = &""
@export var lines: Array[DialogueLine] = []
## 对话结束后执行的 flag 操作，形如 ["set:talked_morris"]。
@export var effects_on_finish: PackedStringArray = PackedStringArray()
## 对话结束时是否自动触发一次存档点（重要剧情节点用）。
@export var autosave_on_finish: bool = false

## 返回在给定条件下实际会播放的行。
## [param resolver] 需要提供 has_flag(flag) / has_memory(id) / 判定条件字符串。
func resolve_lines(resolver: Object) -> Array[DialogueLine]:
	var out: Array[DialogueLine] = []
	for line in lines:
		if line == null:
			continue
		if line.has_condition() and not _check(line.condition, resolver):
			continue
		out.append(line)
	return out


func _check(condition: StringName, resolver: Object) -> bool:
	if resolver == null:
		return true
	if resolver.has_method("evaluate_condition"):
		return bool(resolver.call("evaluate_condition", condition))
	return true
