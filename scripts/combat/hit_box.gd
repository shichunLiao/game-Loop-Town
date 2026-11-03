class_name HitBox
extends Area2D

## 攻击判定框（提示词【六】【二十八】）。
##
## 只负责“在开启的时间窗内，把伤害交给碰到的 HurtBox”。
## 顿帧 / 震屏 / 特效 / 音效统一由 CombatManager 处理，本类不直接碰它们。

signal hit_landed(target: Node, info: DamageInfo)

## 单次攻击的伤害。
@export var damage: int = 10
## 击退力度。
@export var knockback: float = 240.0
## 顿帧时长。
@export var hit_stop: float = 0.06
## 命中后给对方的无敌时间。
@export var invincibility_time: float = 0.6
@export var damage_type: StringName = &"normal"
@export var shake_strength: float = 0.25
## 本次攻击最多命中几个目标（0 = 不限）。
@export var max_targets: int = 0
## 同一次挥击是否可以对同一目标重复命中。
@export var multi_hit_per_swing: bool = false

## 当前是否处于生效帧。
var is_active: bool = false

var _hit_this_swing: Dictionary = {}
var _hit_count: int = 0


func _ready() -> void:
	monitoring = false
	monitorable = false
	area_entered.connect(_on_area_entered)


## 攻击起手：清空本次挥击的命中记录。
func begin_swing() -> void:
	_hit_this_swing.clear()
	_hit_count = 0


## 进入生效帧。
func activate() -> void:
	begin_swing()
	is_active = true
	monitoring = true
	# 已经在范围里的目标不会触发 area_entered，需要主动扫一次。
	call_deferred("_sweep_overlaps")


## 退出生效帧。
func deactivate() -> void:
	is_active = false
	monitoring = false


## 生效帧只持续指定时长（由状态的 Timeout 或这里的计时器驱动）。
func activate_for(duration: float) -> void:
	activate()
	if duration <= 0.0:
		deactivate()
		return
	var timer := get_tree().create_timer(duration, false)
	timer.timeout.connect(_on_window_timeout)


func _on_window_timeout() -> void:
	deactivate()


func _on_area_entered(area: Area2D) -> void:
	if not is_active:
		return
	_try_hit(area)


## 主动扫描当前重叠区域。用于生效帧开启瞬间已经在范围内的目标。
func _sweep_overlaps() -> void:
	if not is_active:
		return
	for area in get_overlapping_areas():
		_try_hit(area)


func _try_hit(area: Area2D) -> void:
	var hurt_box := area as HurtBox
	if hurt_box == null:
		return
	# 不打自己人。
	if hurt_box.get_owner_actor() == get_owner_actor():
		return

	var target := hurt_box.get_owner_actor()
	if target == null:
		return

	var target_id := target.get_instance_id()
	if not multi_hit_per_swing and _hit_this_swing.has(target_id):
		return
	if max_targets > 0 and _hit_count >= max_targets:
		return

	_hit_this_swing[target_id] = true
	_hit_count += 1

	var direction := _compute_direction(hurt_box)
	var info := DamageInfo.create(damage, get_owner_actor(), direction, knockback)
	info.hit_stop = hit_stop
	info.invincible_time = invincibility_time
	info.damage_type = damage_type
	info.shake = shake_strength

	var landed := hurt_box.receive_hit(info)
	if landed:
		hit_landed.emit(target, info)


## 受击方向：从攻击者指向受击者；退化时用攻击者的朝向。
func _compute_direction(hurt_box: HurtBox) -> Vector2:
	var source := get_owner_actor()
	if source is Node2D and hurt_box != null:
		var delta: Vector2 = hurt_box.global_position - (source as Node2D).global_position
		if delta.length_squared() > 1.0:
			return delta.normalized()
	return Vector2.RIGHT


## 找到持有本 HitBox 的“演员”节点（向上找，直到有 hurt_box 或 health 的祖先）。
func get_owner_actor() -> Node:
	var node := get_parent()
	while node != null:
		if node.has_method("is_actor"):
			return node
		node = node.get_parent()
	return owner


## 由外部（状态机）设置的攻击参数。
func configure(
	damage_value: int,
	knockback_value: float,
	stop_value: float,
	types: StringName = &"normal"
) -> void:
	damage = damage_value
	knockback = knockback_value
	hit_stop = stop_value
	damage_type = types
