class_name WaxDummy
extends EnemyBase

## 蜡像敌人（提示词【十三】）：缓慢接近、挥拳、跳扑、假人包围。
##
## 视觉上刻意**没有眼部高光**——这是第一章 Boss 战“识别真身”解谜的前提：
## 玩家先学会“假人没有眼睛”，才能在莫里斯的替身阶段一眼分辨真身。
##
## 行为差异用 [member variant] 区分，而不是写三个敌人脚本：
##   PUNCHER  普通拳击型（默认）
##   LUNGER   会跳扑的突进型
##   SWARMER  血少速度快，用于“假人包围”

enum Variant {
	PUNCHER,
	LUNGER,
	SWARMER,
}

@export var variant: Variant = Variant.PUNCHER
## 跳扑的触发距离与速度。
@export var lunge_speed: float = 300.0
@export var lunge_vertical: float = 340.0
@export var lunge_cooldown: float = 2.4

var _lunge_cooldown_remaining: float = 0.0
var _is_lunging: bool = false


func _after_ready() -> void:
	enemy_id = &"wax_dummy"
	add_to_group(&"wax_dummy")
	super._after_ready()
	_apply_variant()
	AudioManager.play_sfx("wax_crack")


## 变体参数在运行时压到基类字段上，避免为每种蜡像各写一套资源。
func _apply_variant() -> void:
	match variant:
		Variant.PUNCHER:
			max_health = 46
			move_speed = 62.0
			attack_damage = 10
			attack_range = 50.0
			detection_range = 250.0
		Variant.LUNGER:
			max_health = 54
			move_speed = 78.0
			attack_damage = 12
			attack_range = 130.0
			detection_range = 320.0
		Variant.SWARMER:
			max_health = 26
			move_speed = 104.0
			attack_damage = 7
			attack_range = 42.0
			detection_range = 300.0

	if health != null:
		health.max_health = int(round(float(max_health) * stat_multiplier))
		health.current_health = health.max_health
		health.health_changed.emit(health.current_health, health.max_health)


func _process(delta: float) -> void:
	if _lunge_cooldown_remaining > 0.0:
		_lunge_cooldown_remaining = maxf(_lunge_cooldown_remaining - delta, 0.0)


## 由 jump_lunge 状态查询是否允许起跳扑击。
func can_lunge() -> bool:
	if variant != Variant.LUNGER:
		return false
	if _lunge_cooldown_remaining > 0.0 or _is_lunging:
		return false
	if not is_target_valid():
		return false
	return distance_to_target_x() <= attack_range and is_on_floor()


func begin_lunge() -> void:
	_is_lunging = true
	_lunge_cooldown_remaining = lunge_cooldown
	if not is_target_valid():
		return
	var to_target := (target as Node2D).global_position - global_position
	var horizontal := signf(to_target.x)
	set_facing(int(horizontal) if not is_zero_approx(horizontal) else facing)
	velocity = Vector2(float(facing) * lunge_speed, -lunge_vertical)
	play_animation(&"attack", true)
	AudioManager.play_sfx("wax_crack")


func end_lunge() -> void:
	_is_lunging = false


func is_lunging() -> bool:
	return _is_lunging
