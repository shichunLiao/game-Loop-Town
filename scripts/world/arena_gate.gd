class_name ArenaGate
extends Node2D

## Boss 房的闸门（提示词【十三】：Boss Arena 需要隔离玩家与外界）。
##
## 开战前是“开着”的（碰撞体禁用、不可见），开战后落下并挡住出口。
## BossBase._lock_arena() 会通过 &"arena_gate" 组找到它并调用 set_gate_closed()。

signal gate_state_changed(closed: bool)

## 门的高度与厚度。
@export var gate_size: Vector2 = Vector2(26.0, 420.0)
## 关门动画时长。
@export var close_duration: float = 0.45

var is_closed: bool = false

var _visual: ColorRect = null
var _body: StaticBody2D = null
var _shape: CollisionShape2D = null


func _ready() -> void:
	add_to_group(&"arena_gate")
	_ensure_nodes()
	set_gate_closed(false)


func _ensure_nodes() -> void:
	_visual = get_node_or_null("Visual") as ColorRect
	if _visual == null:
		_visual = ColorRect.new()
		_visual.name = "Visual"
		_visual.size = gate_size
		_visual.position = -gate_size
		_visual.color = Color(0.82, 0.6, 0.24, 0.0)
		add_child(_visual)

	_body = get_node_or_null("Body") as StaticBody2D
	if _body == null:
		_body = StaticBody2D.new()
		_body.name = "Body"
		_body.position = Vector2(0.0, -gate_size.y * 0.5)
		_body.collision_layer = 1 << 0   # layer 1 = world
		_body.collision_mask = 0
		add_child(_body)

	_shape = _body.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if _shape == null:
		_shape = CollisionShape2D.new()
		_shape.name = "CollisionShape2D"
		_body.add_child(_shape)
	if _shape.shape == null:
		var rect := RectangleShape2D.new()
		rect.size = gate_size
		_shape.shape = rect


## Boss 通过这个接口开关闸门。
func set_gate_closed(closed: bool) -> void:
	if is_closed == closed:
		return
	is_closed = closed
	_ensure_nodes()

	if _shape != null:
		# 物理开关必须延迟一帧，避免在物理回调里改碰撞状态。
		_shape.set_deferred("disabled", not closed)

	if _visual != null:
		_visual.visible = true
		var target_alpha := 0.85 if closed else 0.0
		var tween := create_tween()
		tween.tween_property(_visual, "color:a", target_alpha, close_duration)

	gate_state_changed.emit(closed)
	if closed:
		AudioManager.play_sfx("wax_crack")
