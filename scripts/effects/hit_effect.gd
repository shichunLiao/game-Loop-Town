class_name HitEffect
extends Node2D

## 一次命中的小特效（提示词【六】：攻击命中后要有小型 Hit Effect）。
##
## 完全程序化：用 hit_spark.png 生成少量粒子 + 一个短暂的扩散环，
## 播完自己销毁。缺失贴图时退化为纯色圆环，保证打击感不会因为缺素材消失。

const LIFETIME: float = 0.28
const SPARK_COUNT: int = 6

var _elapsed: float = 0.0
var _spark_texture: Texture2D = null
var _color: Color = Color(1.0, 0.92, 0.78)
var _direction: Vector2 = Vector2.RIGHT
var _sparks: Array = []


## 在指定父节点下生成一次命中特效。
static func spawn(parent: Node, position: Vector2, direction: Vector2) -> HitEffect:
	if parent == null or not is_instance_valid(parent):
		return null
	var effect := HitEffect.new()
	effect._direction = direction.normalized() if direction.length_squared() > 0.0 else Vector2.RIGHT
	parent.add_child(effect)
	effect.global_position = position
	return effect


func _ready() -> void:
	z_index = 40
	_spark_texture = _load_texture()
	_build_sparks()
	set_process(true)


func _load_texture() -> Texture2D:
	var path := "res://assets/vfx/hit_spark.png"
	if ResourceLoader.exists(path):
		var texture := load(path)
		if texture is Texture2D:
			return texture as Texture2D
	return null


func _build_sparks() -> void:
	# 沿受击方向的反方向溅射，让打击有方向感。
	var base_angle := (-_direction).angle()
	for i in SPARK_COUNT:
		var spread := deg_to_rad(randf_range(-55.0, 55.0))
		var angle := base_angle + spread
		var speed := randf_range(180.0, 420.0)
		_sparks.append({
			"position": Vector2.ZERO,
			"velocity": Vector2(cos(angle), sin(angle)) * speed,
			"scale": randf_range(0.35, 0.9),
			"life": randf_range(0.55, 1.0),
			"age": 0.0,
		})
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed += delta
	for spark: Dictionary in _sparks:
		spark["age"] = float(spark["age"]) + delta
		var velocity: Vector2 = spark["velocity"]
		velocity.y += 900.0 * delta
		velocity *= 1.0 - minf(delta * 6.0, 0.9)
		spark["velocity"] = velocity
		spark["position"] = (spark["position"] as Vector2) + velocity * delta
	queue_redraw()
	if _elapsed >= LIFETIME:
		queue_free()


func _draw() -> void:
	var ring_progress := clampf(_elapsed / LIFETIME, 0.0, 1.0)
	var ring_alpha := 1.0 - ring_progress

	if _spark_texture != null:
		for spark: Dictionary in _sparks:
			var life: float = float(spark["life"])
			var age: float = float(spark["age"])
			var alpha := clampf(1.0 - age / maxf(life, 0.01), 0.0, 1.0)
			var size := _spark_texture.get_size() * float(spark["scale"])
			var rect := Rect2(
				(spark["position"] as Vector2) - size * 0.5,
				size
			)
			draw_texture_rect(_spark_texture, rect, false, Color(1.0, 1.0, 1.0, alpha))
	else:
		for spark: Dictionary in _sparks:
			var life: float = float(spark["life"])
			var age: float = float(spark["age"])
			var alpha := clampf(1.0 - age / maxf(life, 0.01), 0.0, 1.0)
			draw_circle(spark["position"] as Vector2, 2.5 * float(spark["scale"]), Color(_color, alpha))

	# 扩散环：让“命中”这件事在低分辨率下也看得清。
	var ring_radius := 6.0 + ring_progress * 22.0
	draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 24, Color(_color, ring_alpha * 0.7), 2.0)
