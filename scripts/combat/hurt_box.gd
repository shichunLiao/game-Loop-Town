class_name HurtBox
extends Area2D

## 受击框（提示词【六】【二十八】）。
##
## 敌人与玩家各自持有一个。碰撞层决定“谁能打到谁”：
##   玩家 HurtBox  在 layer 2，mask layer 5（敌人攻击）
##   敌人 HurtBox  在 layer 3，mask layer 4（玩家攻击）
## 这样就不需要任何 if 判断敌我。

signal hit_received(info: DamageInfo, landed: bool)

## 伤害倍率。Boss 的某些阶段可以调高/调低受伤（提示词【十三】皮埃罗“防御降低”）。
@export var damage_multiplier: float = 1.0
## 受击时把伤害转交的组件。留空则自动向上查找 HealthComponent。
@export var health_component_path: NodePath

var _health: HealthComponent = null


func _ready() -> void:
	monitorable = true
	monitoring = false


func get_health() -> HealthComponent:
	if _health != null and is_instance_valid(_health):
		return _health
	if health_component_path != NodePath():
		_health = get_node_or_null(health_component_path) as HealthComponent
	if _health == null:
		_health = _find_health_in_ancestors()
	return _health


func _find_health_in_ancestors() -> HealthComponent:
	var node := get_parent()
	while node != null:
		for child in node.get_children():
			if child is HealthComponent:
				return child
		node = node.get_parent()
	return null


## 接收一次伤害。返回伤害是否真正生效。
func receive_hit(info: DamageInfo) -> bool:
	if info == null:
		return false

	var health := get_health()
	if health == null:
		# 没有生命组件的受击框（例如纯装饰物）照样广播，交给宿主处理。
		hit_received.emit(info, false)
		return false

	if health.is_dead:
		return false
	if health.is_invincible() and info.can_be_blocked:
		hit_received.emit(info, false)
		return false

	var scaled := info.duplicate_for_multiplier(damage_multiplier)
	var landed := health.take_damage(scaled)
	hit_received.emit(scaled, landed)
	return landed


func set_damage_multiplier(value: float) -> void:
	damage_multiplier = maxf(value, 0.0)


## 持有本框的演员节点。
func get_owner_actor() -> Node:
	var node := get_parent()
	while node != null:
		if node.has_method("is_actor"):
			return node
		node = node.get_parent()
	return owner
