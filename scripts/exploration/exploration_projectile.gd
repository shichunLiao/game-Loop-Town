class_name ExplorationProjectile
extends Area2D

var velocity: Vector2 = Vector2.ZERO
var damage: int = 14
var fall_acceleration: float = 0.0
var session: ExplorationSession
var _life: float = 4.5
var _spent: bool = false
var tint: Color = Color("e9b85c")

func _ready() -> void:
	collision_layer = 0
	collision_mask = 9
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 10
	shape.shape = circle
	add_child(shape)
	area_entered.connect(_on_area)
	body_entered.connect(func(_body: Node2D): queue_free())
	z_index = 8

func _physics_process(delta: float) -> void:
	var rate: float = .3 if session != null and session.slow_time > 0 else 1.0
	velocity.y += fall_acceleration*delta*rate
	position += velocity*delta*rate
	_life -= delta*rate
	if _life <= 0:
		queue_free()

func _on_area(area: Area2D) -> void:
	if _spent:
		return
	var receiver: Node = area.get_parent()
	if receiver.has_method("receive_hit"):
		_spent = true
		receiver.call("receive_hit",damage,global_position,"wax")
		queue_free()

func _draw() -> void:
	draw_circle(Vector2.ZERO,17,Color(tint,.12))
	draw_circle(Vector2.ZERO,9,tint)
	draw_circle(Vector2(-3,-3),3,Color("ffebba"))
	draw_line(-velocity.normalized()*24,Vector2.ZERO,Color("bb752e"),5,true)
