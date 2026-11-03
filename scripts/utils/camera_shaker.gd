class_name CameraShaker
extends Node

## 相机震动（提示词【六】【三十五】）。
##
## 挂在 Camera2D 下。用 trauma 模型：多次小震动会累积，但衰减平滑，
## 不会像直接叠加偏移那样在连续命中时抖到看不清。

## trauma 衰减速度（每秒）。
@export var decay: float = 2.4
## 最大位移（像素）。
@export var max_offset: Vector2 = Vector2(14.0, 10.0)
## 最大旋转（弧度）。
@export var max_roll: float = 0.035
@export var noise_speed: float = 24.0

var _trauma: float = 0.0
var _camera: Camera2D = null
var _base_offset: Vector2 = Vector2.ZERO
var _time: float = 0.0
var _noise: FastNoiseLite = null


func _ready() -> void:
	_camera = get_parent() as Camera2D
	if _camera == null:
		push_warning("[CameraShaker] 父节点不是 Camera2D，震动将不生效。")
		set_process(false)
		return
	_base_offset = _camera.offset
	_noise = FastNoiseLite.new()
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise.frequency = 0.9
	_noise.seed = 20261006


## 施加一次震动。strength 0..1。
func shake(strength: float, _duration: float = 0.22) -> void:
	_trauma = clampf(_trauma + clampf(strength, 0.0, 1.0), 0.0, 1.0)


func _process(delta: float) -> void:
	if _camera == null:
		return
	if _trauma <= 0.0:
		if _camera.offset != _base_offset:
			_camera.offset = _base_offset
		if not is_zero_approx(_camera.rotation):
			_camera.rotation = 0.0
		return

	_time += delta * noise_speed
	_trauma = maxf(_trauma - decay * delta, 0.0)

	# 用 trauma^2 让衰减前段更明显、尾段更柔和。
	var amount := _trauma * _trauma
	var offset_x := _sample(_time, 0.0) * max_offset.x * amount
	var offset_y := _sample(_time, 100.0) * max_offset.y * amount
	_camera.offset = _base_offset + Vector2(offset_x, offset_y)
	_camera.rotation = _sample(_time, 200.0) * max_roll * amount


func _sample(x: float, y: float) -> float:
	if _noise == null:
		return randf_range(-1.0, 1.0)
	return _noise.get_noise_2d(x, y)


## 场景切换时复位，避免把偏移带进新地图。
func reset() -> void:
	_trauma = 0.0
	if _camera != null:
		_camera.offset = _base_offset
		_camera.rotation = 0.0
