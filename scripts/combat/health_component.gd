class_name HealthComponent
extends Node

## 生命组件。玩家与所有敌人共用，集中处理“掉血 / 无敌 / 死亡”三件事。
##
## 严格区分：本组件不知道谁是玩家谁是敌人，只负责数值与广播。
## 敌我的区分由 HurtBox 的碰撞层完成（提示词【六】：必须区分 HitBox / HurtBox）。

signal health_changed(current: int, maximum: int)
signal damaged(info: DamageInfo, remaining: int)
signal healed(amount: int, remaining: int)
signal died(info: DamageInfo)
signal invincibility_started(duration: float)
signal invincibility_ended

@export var max_health: int = 100
@export var start_full: bool = true
## 默认受击无敌时间（秒）。0 表示没有无敌帧。
@export var default_invincibility: float = 0.6
## 死亡后是否把节点从场景里移除。
@export var free_on_death: bool = false
## 死亡后延迟多少秒移除（给死亡动画留时间）。
@export var free_delay: float = 1.2

var current_health: int = 100
var is_dead: bool = false

var _invincible_timer: float = 0.0
var _forced_invincible: bool = false
var _free_timer: float = 0.0
var _pending_free: bool = false


func _ready() -> void:
	if start_full:
		current_health = max_health
	health_changed.emit(current_health, max_health)


func _process(delta: float) -> void:
	if _invincible_timer > 0.0:
		_invincible_timer = maxf(_invincible_timer - delta, 0.0)
		if _invincible_timer <= 0.0 and not _forced_invincible:
			invincibility_ended.emit()

	if _pending_free:
		_free_timer -= delta
		if _free_timer <= 0.0:
			_pending_free = false
			var host := get_parent()
			if host != null and is_instance_valid(host):
				host.queue_free()


# ---------------------------------------------------------------------------
# 查询
# ---------------------------------------------------------------------------

func is_invincible() -> bool:
	return _forced_invincible or _invincible_timer > 0.0


func get_health_ratio() -> float:
	if max_health <= 0:
		return 0.0
	return float(current_health) / float(max_health)


# ---------------------------------------------------------------------------
# 变更
# ---------------------------------------------------------------------------

## 受到伤害。返回是否真的生效（被无敌帧挡下返回 false）。
func take_damage(info: DamageInfo) -> bool:
	if is_dead or info == null:
		return false
	if info.can_be_blocked and is_invincible():
		return false
	if info.amount <= 0:
		return false

	current_health = maxi(current_health - info.amount, 0)
	damaged.emit(info, current_health)
	health_changed.emit(current_health, max_health)

	var invincibility := info.invincible_time
	if invincibility <= 0.0:
		invincibility = default_invincibility
	if invincibility > 0.0 and not _forced_invincible:
		_invincible_timer = invincibility
		invincibility_started.emit(invincibility)

	if current_health <= 0:
		_die(info)
	return true


func heal(amount: int) -> void:
	if is_dead or amount <= 0:
		return
	var before := current_health
	current_health = mini(current_health + amount, max_health)
	if current_health != before:
		healed.emit(current_health - before, current_health)
		health_changed.emit(current_health, max_health)


func set_health(value: int) -> void:
	current_health = clampi(value, 0, max_health)
	health_changed.emit(current_health, max_health)


func revive(health_value: int = -1) -> void:
	is_dead = false
	_pending_free = false
	_forced_invincible = false
	_invincible_timer = 0.0
	current_health = max_health if health_value < 0 else clampi(health_value, 1, max_health)
	health_changed.emit(current_health, max_health)


## 剧情需要时强制无敌（例如最终火海里居民打不死玩家）。
func set_forced_invincible(value: bool) -> void:
	if _forced_invincible == value:
		return
	_forced_invincible = value
	if value:
		invincibility_started.emit(-1.0)
	else:
		invincibility_ended.emit()


func _die(info: DamageInfo) -> void:
	if is_dead:
		return
	is_dead = true
	current_health = 0
	died.emit(info)
	if free_on_death:
		_pending_free = true
		_free_timer = free_delay
