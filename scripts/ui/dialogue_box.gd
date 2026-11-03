extends CanvasLayer

## 对话框控制器 —— 提示词【十】【三十】。
##
## 与 DialogueManager 完全解耦：DialogueManager 只管流程，本脚本只管表现
## （逐字显示、头像、选项按钮），两者通过信号沟通。
##
## 逐字显示用 RichTextLabel.visible_ratio 实现：**文本只设置一次**，
## 之后只推进 visible_ratio，不做每帧字符串拼接。

## 默认逐字速度（字符/秒）。
const DEFAULT_CHARS_PER_SECOND: float = 45.0
## 推进 / 补完逐字显示的确认动作。
const CONFIRM_ACTION: StringName = &"ui_confirm_dialogue"
## Esc：强制结束对话。
const CANCEL_ACTION: StringName = &"pause"
## 选项按钮的最小高度。
const CHOICE_BUTTON_HEIGHT: float = 40.0

@onready var panel: PanelContainer = $Root/Panel
@onready var portrait: TextureRect = $Root/Panel/VBox/Header/Portrait
@onready var name_label: Label = $Root/Panel/VBox/Header/NameLabel
@onready var text_label: RichTextLabel = $Root/Panel/VBox/TextLabel
@onready var choices_container: VBoxContainer = $Root/Panel/VBox/Choices
@onready var hint: Label = $Root/Panel/VBox/Footer/Hint

## 当前逐字显示的补间。
var _type_tween: Tween = null
## 是否正在逐字显示。
var _is_typing: bool = false
## 当前选项按钮，清空时用。
var _choice_buttons: Array[Button] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	if text_label != null:
		text_label.bbcode_enabled = false
		text_label.text = ""
		text_label.visible_ratio = 0.0
	if choices_container != null:
		choices_container.visible = false
	if portrait != null:
		portrait.visible = false
		portrait.texture = null

	_connect_signals()


func _unhandled_input(event: InputEvent) -> void:
	if DialogueManager == null or not DialogueManager.is_active:
		return

	if event.is_action_pressed(CONFIRM_ACTION):
		# 等待选项时由选项按钮接管输入，这里什么都不做。
		if DialogueManager.is_waiting_for_choice():
			return
		if _is_typing:
			skip_typewriter()
		else:
			DialogueManager.advance()
		# 吃掉确认输入，避免同一次按键又触发攻击。
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed(CANCEL_ACTION):
		DialogueManager.force_stop()
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------------------
# 公开接口
# ---------------------------------------------------------------------------

## 对话进行中时为 true。玩家 / 敌人可以据此屏蔽自己的输入。
func is_blocking_input() -> bool:
	return DialogueManager != null and DialogueManager.is_active


## 对话中是否正在逐字显示。
func is_typing() -> bool:
	return _is_typing


## 立即补完当前这一句的逐字显示。
func skip_typewriter() -> void:
	_kill_type_tween()
	if text_label != null:
		text_label.visible_ratio = 1.0


# ---------------------------------------------------------------------------
# 内部
# ---------------------------------------------------------------------------

func _connect_signals() -> void:
	if DialogueManager == null:
		return
	DialogueManager.dialogue_started.connect(_on_dialogue_started)
	DialogueManager.line_shown.connect(_on_line_shown)
	DialogueManager.choices_shown.connect(_on_choices_shown)
	DialogueManager.dialogue_finished.connect(_on_dialogue_finished)


func _kill_type_tween() -> void:
	if _type_tween != null and _type_tween.is_valid():
		_type_tween.kill()
	_type_tween = null
	_is_typing = false


func _start_typewriter(line: DialogueLine) -> void:
	_kill_type_tween()
	if text_label == null:
		return

	# 文本只设置一次，之后只动 visible_ratio。
	text_label.text = line.text
	text_label.visible_ratio = 0.0

	# bbcode 已关闭，因此角色数就等于文本长度；取两者较大值以防
	# RichTextLabel 还没完成排版时 get_total_character_count() 返回 0。
	var characters: int = maxi(text_label.get_total_character_count(), line.text.length())
	if characters <= 0:
		text_label.visible_ratio = 1.0
		return

	var chars_per_second: float = line.chars_per_second
	if chars_per_second <= 0.0:
		chars_per_second = DEFAULT_CHARS_PER_SECOND
	if chars_per_second <= 0.0:
		text_label.visible_ratio = 1.0
		return

	_is_typing = true
	_type_tween = create_tween()
	_type_tween.tween_property(
		text_label,
		"visible_ratio",
		1.0,
		float(characters) / chars_per_second
	)
	_type_tween.finished.connect(_on_typewriter_finished)


func _clear_choices() -> void:
	for button in _choice_buttons:
		if not is_instance_valid(button):
			continue
		# 立刻从容器摘掉，避免旧按钮和新按钮同帧共存。
		var parent: Node = button.get_parent()
		if parent != null:
			parent.remove_child(button)
		button.queue_free()
	_choice_buttons.clear()


# ---------------------------------------------------------------------------
# 信号回调
# ---------------------------------------------------------------------------

func _on_dialogue_started(_sequence: DialogueSequence) -> void:
	visible = true


func _on_line_shown(line: DialogueLine, _index: int, _total: int) -> void:
	_clear_choices()
	if choices_container != null:
		choices_container.visible = false
	if hint != null:
		hint.visible = true

	if line == null:
		return

	if name_label != null:
		name_label.text = line.speaker
	if portrait != null:
		portrait.texture = line.portrait
		portrait.visible = line.portrait != null

	_start_typewriter(line)


func _on_choices_shown(choices: Array) -> void:
	_clear_choices()
	if choices_container == null or choices.is_empty():
		if choices_container != null:
			choices_container.visible = false
		return

	if hint != null:
		hint.visible = false
	choices_container.visible = true

	for index in range(choices.size()):
		var choice: Variant = choices[index]
		var label_text: String = ""
		var raw: Variant = null
		if choice is Dictionary:
			raw = (choice as Dictionary).get("text", null)
		elif choice != null:
			raw = choice.get(&"text")
		if raw is String:
			label_text = raw

		var button := Button.new()
		button.name = "Choice%d" % index
		button.text = label_text if not label_text.is_empty() else "…"
		button.custom_minimum_size = Vector2(0.0, CHOICE_BUTTON_HEIGHT)
		button.pressed.connect(_on_choice_pressed.bind(index))
		choices_container.add_child(button)
		_choice_buttons.append(button)

	if not _choice_buttons.is_empty():
		_choice_buttons[0].grab_focus()


func _on_dialogue_finished(_sequence: DialogueSequence) -> void:
	_kill_type_tween()
	_clear_choices()
	if choices_container != null:
		choices_container.visible = false
	if text_label != null:
		text_label.text = ""
		text_label.visible_ratio = 0.0
	if name_label != null:
		name_label.text = ""
	if portrait != null:
		portrait.texture = null
		portrait.visible = false
	visible = false


func _on_typewriter_finished() -> void:
	_is_typing = false
	_type_tween = null


func _on_choice_pressed(index: int) -> void:
	if DialogueManager == null:
		return
	DialogueManager.choose(index)
