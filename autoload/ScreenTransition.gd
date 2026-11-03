extends CanvasLayer

## 全屏淡入淡出（autoload）。
##
## 独立成一个层，任何系统都能 await 它做转场，不需要自己去摸 UI 树。
## layering：转场层必须盖住 HUD，但低于暂停菜单与笔记本。

const FADE_DURATION: float = 0.45

var _rect: ColorRect = null
var _busy: bool = false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.name = "FadeRect"
	_rect.color = Color(0, 0, 0, 0)
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 铺满任意分辨率。
	_rect.anchor_right = 1.0
	_rect.anchor_bottom = 1.0
	add_child(_rect)


## 变黑。已经全黑时立刻返回。
func fade_out(duration: float = FADE_DURATION) -> void:
	await _fade_to(1.0, duration)


## 变透明。
func fade_in(duration: float = FADE_DURATION) -> void:
	await _fade_to(0.0, duration)


## 立即设定遮罩透明度，不做动画。
func set_alpha(alpha: float) -> void:
	if _rect != null:
		_rect.color.a = clampf(alpha, 0.0, 1.0)


func get_alpha() -> float:
	return _rect.color.a if _rect != null else 0.0


func _fade_to(target: float, duration: float) -> void:
	if _rect == null:
		return
	# 同时只允许一个淡入淡出，避免转场互相打断画面。
	while _busy:
		await get_tree().process_frame
	var from := _rect.color.a
	if is_equal_approx(from, target):
		_rect.color.a = target
		return
	_busy = true
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_rect, "color:a", target, maxf(duration, 0.01))
	await tween.finished
	_busy = false
