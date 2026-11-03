extends Node

## 对话管理器（autoload）— 提示词【十】【三十】。
##
## 职责边界：本类只负责**对话流程**（推进、条件过滤、选项、效果），
## 逐字显示与排版属于 DialogueBox.tscn，两者通过信号解耦。
## 剧情文本不写死在 NPC 脚本里，全部来自 data/dialogue/*.tres。

signal dialogue_started(sequence: DialogueSequence)
signal line_shown(line: DialogueLine, index: int, total: int)
signal choices_shown(choices: Array)
signal dialogue_finished(sequence: DialogueSequence)
signal effect_applied(effect: String)

## 当前是否处于对话中。玩家、敌人、UI 都用它来屏蔽输入。
var is_active: bool = false
var current_line: DialogueLine = null
var current_index: int = -1
var current_total: int = 0

var _sequence: DialogueSequence = null
var _lines: Array[DialogueLine] = []
var _pending_choices: Array = []
var _waiting_for_choice: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


# ---------------------------------------------------------------------------
# 启动 / 结束
# ---------------------------------------------------------------------------

## 用一份 DialogueSequence 资源开始对话。
func start(sequence: DialogueSequence) -> bool:
	if sequence == null:
		push_warning("[DialogueManager] start() 收到空的对白资源。")
		return false
	if is_active:
		# 已在对话中则不再重入，避免 NPC 重叠触发。
		return false

	_sequence = sequence
	_lines = sequence.resolve_lines(GameManager)
	if _lines.is_empty():
		# 条件把整段都过滤光了：直接算作完成，仍执行 finish 效果。
		_run_effects(sequence.effects_on_finish)
		return false

	is_active = true
	current_index = -1
	current_total = _lines.size()
	_waiting_for_choice = false
	_pending_choices.clear()

	dialogue_started.emit(sequence)
	_advance()
	return true


## 用资源路径开始对话（地图里的 DialogueTrigger 用）。
func start_from_path(path: String) -> bool:
	if path.is_empty():
		return false
	var sequence := load(path) as DialogueSequence
	if sequence == null:
		push_error("[DialogueManager] 无法加载对白资源: %s" % path)
		return false
	return start(sequence)


## 推进到下一句。由 DialogueBox 在玩家按确认时调用。
func advance() -> void:
	if not is_active:
		return
	if _waiting_for_choice:
		# 等待选项时忽略推进，必须调用 choose()。
		return
	_advance()


## 强制结束（玩家按 Esc 或场景切换）。
func force_stop() -> void:
	if not is_active:
		return
	var finished := _sequence
	_clear()
	if finished != null:
		dialogue_finished.emit(finished)


# ---------------------------------------------------------------------------
# 选项
# ---------------------------------------------------------------------------

## 玩家选择了一个选项（下标对应 choices_shown 广播的数组）。
func choose(choice_index: int) -> void:
	if not is_active or not _waiting_for_choice:
		return
	if choice_index < 0 or choice_index >= _pending_choices.size():
		return

	var choice: Variant = _pending_choices[choice_index]
	_waiting_for_choice = false
	_pending_choices.clear()

	var effects: PackedStringArray = choice.effects
	_run_effects(effects)

	var next_path: String = choice.next_sequence
	if next_path.is_empty():
		finish()
		return

	# 跳转到另一段对白：先结束当前段（不广播 finished，避免 UI 闪一下）。
	var previous := _sequence
	_clear()
	if previous != null:
		dialogue_finished.emit(previous)
	var next_sequence := load(next_path) as DialogueSequence
	if next_sequence == null:
		push_error("[DialogueManager] 选项跳转目标不存在: %s" % next_path)
		return
	start(next_sequence)


func get_current_choices() -> Array:
	return _pending_choices.duplicate()


func is_waiting_for_choice() -> bool:
	return _waiting_for_choice


# ---------------------------------------------------------------------------
# 流程
# ---------------------------------------------------------------------------

func _advance() -> void:
	current_index += 1
	if current_index >= _lines.size():
		finish()
		return

	var line := _lines[current_index]
	current_line = line

	# 行内效果立即生效（例如“说完这句就记下线索”）。
	_run_effects(line.effects)

	if not line.condition.is_empty() and not GameManager.evaluate_condition(line.condition):
		# 条件不满足则静默跳过这一句。
		_advance()
		return

	line_shown.emit(line, current_index, current_total)

	# 该行是否带选项？选项写在 line.effects 之外的独立字段里由地图提供，
	# 这里通过 emotion == "choice" 约定：带选择的台词由 DialogueBox 自行弹出。
	# 为了保持数据驱动，真正的分支选项由 ChoicePrompt 资源提供（见 start_choices）。
	if line.emotion == &"choice" and not _pending_choices.is_empty():
		_waiting_for_choice = true
		choices_shown.emit(_pending_choices)


## 手动挂上一组选项，供 DialogueBox 在当前行展示。
func set_choices(choices: Array) -> void:
	_pending_choices = choices
	if not choices.is_empty():
		_waiting_for_choice = true
		choices_shown.emit(_pending_choices)


func finish() -> void:
	if not is_active:
		return
	var finished := _sequence
	var finish_effects: PackedStringArray = PackedStringArray()
	if finished != null:
		finish_effects = finished.effects_on_finish
	_clear()
	_run_effects(finish_effects)
	if finished != null:
		dialogue_finished.emit(finished)
		if finished.autosave_on_finish and SaveManager != null:
			SaveManager.request_save("dialogue_finish")


func _clear() -> void:
	is_active = false
	current_line = null
	current_index = -1
	current_total = 0
	_sequence = null
	_lines.clear()
	_pending_choices.clear()
	_waiting_for_choice = false


# ---------------------------------------------------------------------------
# 效果
# ---------------------------------------------------------------------------

## 效果语法（写在 DialogueLine.effects / DialogueSequence.effects_on_finish）：
##   "set:met_morris"            置位 flag
##   "clear:met_morris"          清除 flag
##   "memory:wax_order"          收集记忆
##   "item:big_scissors"         获得道具
##   "chapter:1"                 标记第一章通关
##   "bell"                      敲钟
##   "sfx:attack_hit"            播放音效
##   "checkpoint"                设置检查点
func _run_effects(effects: PackedStringArray) -> void:
	for raw in effects:
		var effect := raw.strip_edges()
		if effect.is_empty():
			continue
		_apply_effect(effect)
		effect_applied.emit(effect)


func _apply_effect(effect: String) -> void:
	var colon := effect.find(":")
	var kind := effect if colon < 0 else effect.substr(0, colon)
	var value := "" if colon < 0 else effect.substr(colon + 1).strip_edges()

	match kind:
		"set":
			GameManager.set_flag(StringName(value), true)
		"clear":
			GameManager.set_flag(StringName(value), false)
		"memory":
			MemoryManager.collect(StringName(value))
		"item":
			_grant_item(StringName(value))
		"chapter":
			if value.is_valid_int():
				GameManager.complete_chapter(int(value))
		"bell":
			AudioManager.play_bell()
		"sfx":
			AudioManager.play_sfx(value)
		"checkpoint":
			if GameManager != null:
				LoopManager.set_checkpoint(
					GameManager.current_map_id,
					GameManager.current_spawn_id
				)
		_:
			push_warning("[DialogueManager] 未知效果: %s" % effect)


func _grant_item(item_id: StringName) -> void:
	var path := "res://data/items/%s.tres" % String(item_id)
	if not ResourceLoader.exists(path):
		push_warning("[DialogueManager] 道具资源不存在: %s" % path)
		return
	var item := load(path) as ItemData
	if item == null:
		return
	SaveManager.add_item(item, 1)
	if not item.grants_flag.is_empty():
		GameManager.set_flag(item.grants_flag, true)
