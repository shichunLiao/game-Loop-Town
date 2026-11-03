extends Control

## 标题界面控制器（提示词【三十二】：标题也要显示"第 N 次循环"）。
##
## 职责：
##   - 显示 LoopManager 的循环计数
##   - 新手 / 继续 / 退出三个入口
##   - 开场淡入
##   - 彩蛋：在标题静置 60 秒后，画面缓慢"偏移"到第 248 次循环的色调
##
## 本脚本不直接读写存档、不直接切场景，全部委托 GameManager。

## 静置多久触发彩蛋（秒）。
const IDLE_TIMEOUT_SECONDS: float = 60.0
## 彩蛋里替换的循环文案。
const IDLE_LOOP_TEXT: String = "第 248 次循环"
## 开场淡入时长（秒）。
const FADE_IN_SECONDS: float = 0.8
## 副标题默认文案。
const SUBTITLE_DEFAULT: String = "LOOP TOWN"
## 继续失败时的提示。
const CONTINUE_FAILED_TEXT: String = "存档读取失败。"
## 彩蛋：背景变暖变暗。
const IDLE_BACKGROUND_COLOR: Color = Color(0.12, 0.07, 0.05, 1.0)
## 彩蛋：暗角变成暖色调。
const IDLE_VIGNETTE_COLOR: Color = Color(0.16, 0.06, 0.02, 1.0)
## 彩蛋：暗角加深后的不透明度。
const IDLE_VIGNETTE_ALPHA: float = 0.62
## 彩蛋过渡时长（秒）。
const IDLE_SHIFT_SECONDS: float = 2.4

@onready var background: ColorRect = $Background
@onready var vignette: ColorRect = $Vignette
@onready var subtitle: Label = $Layout/Subtitle
@onready var loop_label: Label = $Layout/LoopLabel
@onready var new_game_button: Button = $Layout/Buttons/NewGameButton
@onready var continue_button: Button = $Layout/Buttons/ContinueButton
@onready var quit_button: Button = $Layout/Buttons/QuitButton
@onready var fade_overlay: ColorRect = $FadeOverlay

## 防止按钮被连点 / 重复触发。
var _busy: bool = false
var _idle_timer: Timer = null
var _idle_triggered: bool = false
var _subtitle_tween: Tween = null


func _ready() -> void:
	_busy = false
	_idle_triggered = false

	if loop_label != null and LoopManager != null:
		loop_label.text = LoopManager.get_loop_label()

	if continue_button != null:
		# 只有当盘上真有存档时才允许"继续"。
		continue_button.disabled = SaveManager == null or not SaveManager.has_save

	_connect_signals()
	_setup_focus_neighbours()
	_setup_idle_timer()
	_play_fade_in()

	if new_game_button != null:
		new_game_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if _idle_triggered or _busy or _idle_timer == null:
		return
	if event is InputEventKey and (event as InputEventKey).echo:
		return
	# 任何真实的输入都说明玩家还在，于是重新计时。
	_idle_timer.start()


# ---------------------------------------------------------------------------
# 公开接口
# ---------------------------------------------------------------------------

## 在副标题上短暂显示一条消息，随后恢复默认文案。
func show_subtitle_message(message: String) -> void:
	if subtitle == null:
		return
	if _subtitle_tween != null and _subtitle_tween.is_valid():
		_subtitle_tween.kill()
	subtitle.text = message
	subtitle.modulate.a = 0.0
	_subtitle_tween = create_tween()
	_subtitle_tween.tween_property(subtitle, "modulate:a", 1.0, 0.15)
	_subtitle_tween.tween_interval(2.5)
	_subtitle_tween.tween_callback(_restore_subtitle)


# ---------------------------------------------------------------------------
# 内部
# ---------------------------------------------------------------------------

func _connect_signals() -> void:
	if new_game_button != null:
		new_game_button.pressed.connect(_on_new_game_pressed)
	if continue_button != null:
		continue_button.pressed.connect(_on_continue_pressed)
	if quit_button != null:
		quit_button.pressed.connect(_on_quit_pressed)


## 方向键在三个按钮之间循环移动。
func _setup_focus_neighbours() -> void:
	if new_game_button == null or continue_button == null or quit_button == null:
		return
	new_game_button.focus_neighbor_top = new_game_button.get_path_to(quit_button)
	new_game_button.focus_neighbor_bottom = new_game_button.get_path_to(continue_button)
	continue_button.focus_neighbor_top = continue_button.get_path_to(new_game_button)
	continue_button.focus_neighbor_bottom = continue_button.get_path_to(quit_button)
	quit_button.focus_neighbor_top = quit_button.get_path_to(continue_button)
	quit_button.focus_neighbor_bottom = quit_button.get_path_to(new_game_button)


func _play_fade_in() -> void:
	if fade_overlay == null:
		return
	fade_overlay.color.a = 1.0
	var tween := create_tween()
	tween.tween_property(fade_overlay, "color:a", 0.0, FADE_IN_SECONDS).set_trans(Tween.TRANS_SINE)


func _set_buttons_enabled(enabled: bool) -> void:
	if new_game_button != null:
		new_game_button.disabled = not enabled
	if continue_button != null:
		# "继续"取决于是否存在存档，不能因为解锁按钮就忽略这一点。
		continue_button.disabled = (not enabled) or SaveManager == null or not SaveManager.has_save
	if quit_button != null:
		quit_button.disabled = not enabled


func _restore_subtitle() -> void:
	if subtitle == null:
		return
	subtitle.text = SUBTITLE_DEFAULT
	subtitle.modulate.a = 0.6


# ---------------------------------------------------------------------------
# 按钮回调
# ---------------------------------------------------------------------------

func _on_new_game_pressed() -> void:
	if _busy:
		return
	_busy = true
	_set_buttons_enabled(false)
	_stop_idle_timer()
	if GameManager == null:
		_busy = false
		_set_buttons_enabled(true)
		return
	await GameManager.start_new_game()


func _on_continue_pressed() -> void:
	if _busy:
		return
	_busy = true
	_set_buttons_enabled(false)
	_stop_idle_timer()

	var loaded: bool = false
	if GameManager != null:
		loaded = await GameManager.continue_from_save()
	if loaded:
		return

	# 读档失败：把界面还给玩家。
	_busy = false
	_set_buttons_enabled(true)
	show_subtitle_message(CONTINUE_FAILED_TEXT)


func _on_quit_pressed() -> void:
	_stop_idle_timer()
	if GameManager != null:
		GameManager.quit_game()


# ---------------------------------------------------------------------------
# 彩蛋：静置 60 秒后画面缓慢偏移
# ---------------------------------------------------------------------------

func _setup_idle_timer() -> void:
	_idle_timer = Timer.new()
	_idle_timer.name = "IdleTimer"
	_idle_timer.one_shot = true
	_idle_timer.wait_time = IDLE_TIMEOUT_SECONDS
	_idle_timer.timeout.connect(_on_idle_timeout)
	add_child(_idle_timer)
	_idle_timer.start()


func _stop_idle_timer() -> void:
	if _idle_timer == null:
		return
	_idle_timer.stop()


func _on_idle_timeout() -> void:
	if _idle_triggered:
		return
	_idle_triggered = true
	_apply_idle_shift()


## 把整个标题的色调往"第 248 次循环"推。
##
## 说明：String 属性无法被 Tween 插值，所以这里用"淡出 → 换文案 → 淡入"
## 的方式实现"文案缓慢变成 第 248 次循环"，同时并联一条色彩过渡。
func _apply_idle_shift() -> void:
	if loop_label != null:
		var label_tween := create_tween()
		label_tween.tween_property(loop_label, "modulate:a", 0.0, 0.9).set_trans(Tween.TRANS_SINE)
		label_tween.tween_callback(_set_idle_loop_text)
		label_tween.tween_property(loop_label, "modulate:a", 1.0, 0.9).set_trans(Tween.TRANS_SINE)
	else:
		_set_idle_loop_text()

	var tint := create_tween()
	tint.set_parallel(true)
	if background != null:
		tint.tween_property(background, "color", IDLE_BACKGROUND_COLOR, IDLE_SHIFT_SECONDS)
	if vignette != null:
		tint.tween_property(vignette, "color", IDLE_VIGNETTE_COLOR, IDLE_SHIFT_SECONDS)
		tint.tween_property(vignette, "modulate:a", IDLE_VIGNETTE_ALPHA, IDLE_SHIFT_SECONDS)


func _set_idle_loop_text() -> void:
	if loop_label == null:
		return
	loop_label.text = IDLE_LOOP_TEXT
