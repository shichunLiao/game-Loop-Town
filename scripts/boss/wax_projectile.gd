class_name WaxProjectile
extends Area2D

## 莫里斯的热蜡弹（提示词【十三】PHASE 1 的热蜡喷射）。
##
## 命中玩家：造成伤害并累加“蜡化”计数（Morris.register_wax_hit）。
## 命中地形或超时：消失。

## 飞行速度（像素/秒），由发射方写入。
@export var velocity: Vector2 = Vector2.ZERO
@export var damage: int = 14
## 存活时长上限，避免飞出地图后永远存在。
@export var lifetime: float = 3.0
## 是否受重力（地面流蜡受，空中喷射不受）。
@export var gravity_scale: float = 0.0
## 发射者，用于伤害归属与敌我判定。
@export var source_actor: Node = null

var _elapsed: float = 0.0
## 命中后立刻失效，避免一次蜡滴连续扣血。
var _consumed: bool = false


func _ready() -> void:
	collision_layer = 1 << 7    # layer 8 = hazard
	collision_mask = 1 << 1     # 只关心玩家
	monitoring = true
	monitorable = false
	_ensure_shape()
	body_entered.connect(_on_body_entered)
	z_index = 12
	queue_redraw()


func _ensure_shape() -> void:
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		shape_node = CollisionShape2D.new()
		shape_node.name = "CollisionShape2D"
		add_child(shape_node)
	if shape_node.shape == null:
		var circle := CircleShape2D.new()
		circle.radius = 7.0
		shape_node.shape = circle


func _process(delta: float) -> void:
	_elapsed += delta
	velocity.y += 1600.0 * gravity_scale * delta
	global_position += velocity * delta
	queue_redraw()
	if _elapsed >= lifetime:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if _consumed:
		return
	if not body.is_in_group(&"player"):
		return
	_consumed = true
	_apply_hit(body)
	queue_free()


func _apply_hit(body: Node2D) -> void:
	var hurt_box := body.get_node_or_null("HurtBox") as HurtBox
	if hurt_box == null:
		return
	var direction := velocity.normalized() if velocity.length_squared() > 0.0 else Vector2.RIGHT
	var info := DamageInfo.create(damage, source_actor, direction, 140.0)
	info.damage_type = &"wax"
	info.invincible_time = 0.7
	if hurt_box.receive_hit(info):
		Combat.on_hit_landed(info, global_position)
		# 蜡化计数交给莫里斯：达到阈值就变成蜡像。
		var morris := source_actor as Morris
		if morris != null:
			morris.register_wax_hit()


func _draw() -> void:
	# 程序化绘制：暖黄蜡滴，带一点点高光，不依赖贴图。
	var radius := 7.0
	draw_circle(Vector2.ZERO, radius, Color(0.92, 0.74, 0.3, 0.95))
	draw_circle(Vector2(-radius * 0.25, -radius * 0.25), radius * 0.42, Color(1.0, 0.94, 0.72, 0.95))
	# 拖尾：朝速度反方向画一小段渐变。
	if velocity.length_squared() > 1.0:
		var tail := -velocity.normalized() * (radius * 1.9)
		draw_line(Vector2.ZERO, tail, Color(0.86, 0.62, 0.24, 0.5), radius * 0.9)
