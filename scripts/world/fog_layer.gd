class_name FogLayer
extends Node2D

## 大雾（提示词【十一】：序幕是黄昏 + 大雾）。
##
## 程序化绘制，不依赖贴图：若干缓慢横向漂移的柔和色带，
## 透明度低、对比度低，用来把远景压下去、把玩家的剪影托出来。
## 会跟随世界状态改变浓度与颜色（提示词【十】）。

@export var fog_color: Color = Color(0.72, 0.74, 0.82)
@export var band_count: int = 5
@export var drift_speed: float = 6.0
## 每层的基准透明度，会被世界状态的 fog_density 缩放。
@export var base_alpha: float = 0.16
## 覆盖宽度（应大于视野宽度）。
@export var coverage: Vector2 = Vector2(2400.0, 700.0)
@export var vertical_offset: float = -180.0

var density: float = 1.0

var _bands: Array[Dictionary] = []


func _ready() -> void:
	add_to_group(&"fog")
	z_index = 60
	_build_bands()
	if WorldStateManager != null:
		WorldStateManager.world_state_changed.connect(_on_world_state_changed)
		_on_world_state_changed(WorldStateManager.current_profile)


func _build_bands() -> void:
	_bands.clear()
	for i in band_count:
		_bands.append({
			"offset": Vector2(randf_range(-200.0, 200.0), vertical_offset + float(i) * 96.0),
			"height": randf_range(70.0, 150.0),
			"speed": drift_speed * randf_range(0.5, 1.5) * (1.0 if i % 2 == 0 else -1.0),
			"alpha": base_alpha * randf_range(0.6, 1.3),
			"x": randf_range(0.0, coverage.x),
		})


func _process(delta: float) -> void:
	for band: Dictionary in _bands:
		var x: float = float(band["x"]) + float(band["speed"]) * delta
		# 无缝循环：漂出右边界就从左边回来。
		if x > coverage.x:
			x -= coverage.x
		elif x < 0.0:
			x += coverage.x
		band["x"] = x
	queue_redraw()


func _on_world_state_changed(profile: WorldStateProfile) -> void:
	if profile == null:
		return
	density = clampf(profile.fog_density / 0.10, 0.15, 2.0)
	# 火海阶段雾会变暖，夜里偏冷。
	fog_color = profile.tint.lerp(Color(0.7, 0.72, 0.8), 0.5)
	queue_redraw()


func _draw() -> void:
	for band: Dictionary in _bands:
		var alpha: float = clampf(float(band["alpha"]) * density, 0.0, 0.6)
		if alpha <= 0.001:
			continue
		var height: float = float(band["height"])
		var offset: Vector2 = band["offset"]
		var x: float = float(band["x"])
		# 画三段重叠的椭圆，拼出比矩形柔和的雾带。
		for segment in 3:
			var center := Vector2(x + float(segment) * coverage.x / 3.0, offset.y)
			draw_circle(center, height * 0.9, Color(fog_color, alpha * 0.5))
			draw_rect(
				Rect2(Vector2(center.x - height, center.y - height * 0.35), Vector2(height * 2.0, height * 0.7)),
				Color(fog_color, alpha * 0.35),
				true
			)
