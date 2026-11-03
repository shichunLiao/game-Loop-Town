class_name EnemyBase
extends Actor

## 敌人基类（提示词【二十八】：每个敌人都有 EnemyBody / HurtBox / HitBox /
## AnimationPlayer / StateMachine）。
##
## 所有敌人都复用 Actor 的生命、受击盒、闪白与状态机装配；
## 具体行为写在各自的 State 里，本类只提供巡逻、追击、面朝玩家等公共能力。

signal player_spotted(player: Node)
signal player_lost

## 敌人类型标识，供世界状态变体与掉落判定使用。
@export var enemy_id: StringName = &"enemy"
@export var max_health: int = 40
@export var move_speed: float = 70.0
@export var contact_damage: int = 8
@export var attack_damage: int = 10
@export var attack_range: float = 48.0
@export var detection_range: float = 260.0
## 失去目标后继续追多远。
@export var lose_range: float = 420.0
## 巡逻半径（围绕出生点）。
@export var patrol_radius: float = 90.0
## 是否掉落道具。
@export var drop_item_id: StringName = &""
## 被击败后是否留在地上（Boss / 剧情敌人用）。
@export var remove_on_death: bool = true

var spawn_position: Vector2 = Vector2.ZERO
var target: Node2D = null
var is_aware: bool = false
## 世界状态对敌人的强度加成，进入场景时由地图注入。
var stat_multiplier: float = 1.0

@onready var detection_area: Area2D = get_node_or_null("DetectionArea") as Area2D


func _after_ready() -> void:
	add_to_group(&"enemy")
	add_to_group(enemy_id)
	spawn_position = global_position

	stat_multiplier = WorldStateManager.get_enemy_stat_multiplier()
	if health != null:
		health.max_health = int(round(float(max_health) * stat_multiplier))
		health.current_health = health.max_health
		health.health_changed.emit(health.current_health, health.max_health)
		health.free_on_death = false

	_setup_detection()
	if state_machine != null:
		state_machine.setup(self)


func _setup_detection() -> void:
	if detection_area == null:
		detection_area = Area2D.new()
		detection_area.name = "DetectionArea"
		add_child(detection_area)
	detection_area.collision_layer = 0
	detection_area.collision_mask = 1 << 1  # layer 2 = player
	var shape_node := detection_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		shape_node = CollisionShape2D.new()
		shape_node.name = "CollisionShape2D"
		detection_area.add_child(shape_node)
	var circle := CircleShape2D.new()
	circle.radius = detection_range
	shape_node.shape = circle
	detection_area.body_entered.connect(_on_detection_body_entered)
	detection_area.body_exited.connect(_on_detection_body_exited)


func _on_detection_body_entered(body: Node2D) -> void:
	if not body.is_in_group(&"player"):
		return
	target = body
	is_aware = true
	player_spotted.emit(body)


func _on_detection_body_exited(body: Node2D) -> void:
	if target == body:
		target = null
		is_aware = false
		player_lost.emit()


## 玩家离得太远就放弃追击。
func is_target_valid() -> bool:
	if target == null or not is_instance_valid(target):
		return false
	if not is_instance_valid(target):
		return false
	return global_position.distance_to((target as Node2D).global_position) <= lose_range


## 朝目标移动，并在接近时自动停下（避免贴着玩家抖动）。
func move_toward_target(delta: float, speed: float = -1.0, stop_distance: float = 26.0) -> void:
	if not is_target_valid():
		velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
		return
	var effective_speed := (move_speed if speed < 0.0 else speed) * stat_multiplier
	var to_target := (target as Node2D).global_position - global_position
	if absf(to_target.x) > stop_distance:
		var direction := signf(to_target.x)
		velocity.x = move_toward(velocity.x, direction * effective_speed, 900.0 * delta)
		set_facing(int(direction))
	else:
		velocity.x = move_toward(velocity.x, 0.0, 1200.0 * delta)


## 巡逻：在出生点左右来回。
func patrol(delta: float) -> void:
	var effective_speed := move_speed * 0.55 * stat_multiplier
	var offset := global_position.x - spawn_position.x
	if offset > patrol_radius:
		set_facing(-1)
	elif offset < -patrol_radius:
		set_facing(1)
	velocity.x = move_toward(velocity.x, float(facing) * effective_speed, 500.0 * delta)


func distance_to_target() -> float:
	if not is_target_valid():
		return INF
	return global_position.distance_to((target as Node2D).global_position)


func distance_to_target_x() -> float:
	if not is_target_valid():
		return INF
	return absf((target as Node2D).global_position.x - global_position.x)


func on_died() -> void:
	AudioManager.play_sfx("enemy_death")
	if not drop_item_id.is_empty():
		_spawn_drop()
	if remove_on_death:
		# 死亡动画播完再移除，具体延迟由 state 决定；这里给一个兜底。
		var timer := get_tree().create_timer(1.6)
		timer.timeout.connect(func() -> void:
			if is_instance_valid(self):
				queue_free()
		)


func _spawn_drop() -> void:
	var path := "res://data/items/%s.tres" % String(drop_item_id)
	if not ResourceLoader.exists(path):
		return
	var item := load(path) as ItemData
	if item == null:
		return
	# Demo 里直接进背包，避免再做一套掉落物物理。
	SaveManager.add_item(item, 1)
