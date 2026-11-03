class_name Actor
extends CharacterBody2D

## 所有“可战斗角色”的基类：玩家、敌人、Boss 都继承它。
##
## 提供子系统的统一装配入口与最小公共行为（朝向、速度、动画、闪白）。
## 注意：子类**不**要重复声明 health / hurt_box / hit_box / sprite / state_machine，
## 直接使用基类提供的 @onready 引用即可。

const GRAVITY: float = 1600.0

## 水平朝向：1 = 朝右，-1 = 朝左。与节点的 scale.x 分离，便于单独做动画翻转。
var facing: int = 1
var is_dead: bool = false

@onready var sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
@onready var health: HealthComponent = get_node_or_null("HealthComponent") as HealthComponent
@onready var hurt_box: HurtBox = get_node_or_null("HurtBox") as HurtBox
@onready var hit_box: HitBox = get_node_or_null("HitBox") as HitBox
@onready var state_machine: StateMachine = get_node_or_null("StateMachine") as StateMachine
@onready var body_shape: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D


func _ready() -> void:
	add_to_group(&"actor")
	if health != null:
		health.died.connect(_on_health_died)
		health.damaged.connect(_on_health_damaged)
	_after_ready()


## 子类重写它来初始化自己的子系统（基类 _ready 已完成公共接线）。
func _after_ready() -> void:
	pass


## 供 HitBox / HurtBox 识别宿主。必须保留这个名字。
func is_actor() -> bool:
	return true


# ---------------------------------------------------------------------------
# 状态机辅助（状态通过这两个方法读写速度，不直接碰 velocity）
#
# 命名注意：绝不能叫 get_velocity / set_velocity —— CharacterBody2D 已声明了
# 这两个原生方法，在 GDScript 里覆盖原生方法会直接编译失败。
# ---------------------------------------------------------------------------

func get_actor_velocity() -> Vector2:
	return velocity


func set_actor_velocity(value: Vector2) -> void:
	velocity = value


func get_facing() -> int:
	return facing


func set_facing(value: int) -> void:
	var new_facing := 1 if value >= 0 else -1
	if new_facing == facing:
		return
	facing = new_facing
	if sprite != null:
		sprite.flip_h = facing < 0


## 应用重力并执行移动。所有角色共用，保证手感一致。
func apply_gravity_and_move(delta: float, gravity_scale: float = 1.0) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * gravity_scale * delta
	move_and_slide()


# ---------------------------------------------------------------------------
# 动画
# ---------------------------------------------------------------------------

## 播放动画。不存在则安静跳过（占位美术可能缺少某个动作）。
func play_animation(animation_name: StringName, restart: bool = false) -> void:
	if sprite == null:
		return
	if sprite.sprite_frames == null:
		return
	if not sprite.sprite_frames.has_animation(animation_name):
		return
	if sprite.animation == animation_name and not restart:
		return
	sprite.play(animation_name)


func has_animation(animation_name: StringName) -> bool:
	if sprite == null or sprite.sprite_frames == null:
		return false
	return sprite.sprite_frames.has_animation(animation_name)


# ---------------------------------------------------------------------------
# 受击 / 死亡
# ---------------------------------------------------------------------------

func _on_health_damaged(info: DamageInfo, _remaining: int) -> void:
	if info != null and is_instance_valid(info.source):
		# 受击方向反馈：被从右边打就往左推。
		var source_position := (info.source as Node2D).global_position if info.source is Node2D else global_position
		set_facing(-1 if source_position.x > global_position.x else 1)
	if info != null and info.flash:
		Combat.flash_white(sprite if sprite != null else self)


func _on_health_died(_info: DamageInfo) -> void:
	is_dead = true
	if hit_box != null:
		hit_box.deactivate()
	if hurt_box != null:
		hurt_box.monitorable = false
		hurt_box.set_deferred("monitorable", false)
	on_died()


## 子类重写它做死亡表现（进入 death 状态、掉落、播放音效等）。
func on_died() -> void:
	pass


## 复活（循环重置时用）。
func revive_actor(health_value: int = -1) -> void:
	is_dead = false
	if health != null:
		health.revive(health_value)
	if hurt_box != null:
		hurt_box.monitorable = true
	if state_machine != null and state_machine.has_state(&"idle"):
		state_machine.change_state(&"idle", {}, true)
	on_revived()


func on_revived() -> void:
	pass


# ---------------------------------------------------------------------------
# 便捷访问
# ---------------------------------------------------------------------------

## 角色中心（用于特效定位）。
func get_center() -> Vector2:
	if body_shape != null:
		return body_shape.global_position
	return global_position


func get_half_height() -> float:
	if body_shape != null and body_shape.shape is RectangleShape2D:
		return (body_shape.shape as RectangleShape2D).size.y * 0.5
	if body_shape != null and body_shape.shape is CapsuleShape2D:
		return (body_shape.shape as CapsuleShape2D).height * 0.5
	return 32.0
