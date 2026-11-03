extends CanvasLayer

## 暂停菜单控制器（提示词【二十七】：暂停 / 手动存档 / 回标题 / 退出）。
##
## 场景的 process_mode 是 ALWAYS，所以就算 SceneTree 被暂停，本菜单依然
## 收得到输入、按钮也点得动。
##
## 注意：SaveButton 只存档，**不解除暂停**（需求明确要求）。

## 暂停动作名。
const PAUSE_ACTION: StringName = &"pause"
## 正在接管输入的全屏覆盖层都会加入这个组（笔记本等）。
const MODAL_OVERLAY_GROUP: StringName = &"ui_modal_overlay"
## 存档成功文案。
const SAVE_OK_FORMAT: String = "已保存  %s"
## 存档失败文案。
const SAVE_FAILED_TEXT: String = "保存失败"

@onready var resume_button: Button = $Panel/VBox/ResumeButton
@onready var save_button: Button = $Panel/VBox/SaveButton
@onready var title_button: Button = $Panel/VBox/TitleButton
@onready var quit_button: Button = $Panel/VBox/QuitButton
@onready var save_hint: Label = $Panel/VBox/SaveHint


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	if save_hint != null:
		save_hint.text = ""

	_connect_signals()


func _connect_signals() -> void:
	if resume_button != null:
		resume_button.pressed.connect(_on_resume_pressed)
	if save_button != null:
		save_button.pressed.connect(_on_save_pressed)
	if title_button != null:
		title_button.pressed.connect(_on_title_pressed)
	if quit_button != null:
		quit_button.pressed.connect(_on_quit_pressed)
	if GameManager != null:
		GameManager.game_paused.connect(_on_game_paused)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(PAUSE_ACTION):
		return
	# 对话进行中时 Esc 属于对话系统（强制结束对话），不该弹出暂停菜单。
	if DialogueManager != null and DialogueManager.is_active:
		return
	# 已有别的全屏覆盖层（笔记本）在接管输入时不重复处理。
	if get_tree() != null and get_tree().get_first_node_in_group(MODAL_OVERLAY_GROUP) != null:
		return
	if GameManager == null:
		return
	GameManager.toggle_pause()
	get_viewport().set_input_as_handled()


# ---------------------------------------------------------------------------
# 公开接口
# ---------------------------------------------------------------------------

## 显示 / 隐藏暂停菜单。由 GameManager.game_paused 驱动。
func set_menu_visible(is_visible: bool) -> void:
	visible = is_visible
	if is_visible:
		if save_hint != null:
			save_hint.text = ""
		if resume_button != null:
			resume_button.grab_focus()


# ---------------------------------------------------------------------------
# 回调
# ---------------------------------------------------------------------------

func _on_game_paused(is_paused: bool) -> void:
	# 笔记本这类全屏覆盖层会借用同一个"暂停"状态，此时暂停菜单不插队。
	if is_paused and get_tree() != null and get_tree().get_first_node_in_group(MODAL_OVERLAY_GROUP) != null:
		return
	set_menu_visible(is_paused)


func _on_resume_pressed() -> void:
	if GameManager != null:
		GameManager.set_paused(false)


func _on_save_pressed() -> void:
	# 需求：手动存档**不解除暂停**。
	var saved: bool = false
	if SaveManager != null:
		saved = SaveManager.save_game("manual")
	if save_hint == null:
		return
	if saved:
		save_hint.text = SAVE_OK_FORMAT % Time.get_time_string_from_system()
	else:
		save_hint.text = SAVE_FAILED_TEXT


func _on_title_pressed() -> void:
	if GameManager != null:
		GameManager.return_to_title()


func _on_quit_pressed() -> void:
	if GameManager != null:
		GameManager.quit_game()
