extends State

## 镇民追击：贴近玩家并造成接触伤害。
##
## 与普通敌人的区别：镇民的攻击是「推搡」而不是挥砍，因此不播放攻击动画，
## 而是靠接触伤害体现，这更符合「他们不是战斗单位，只是被改写过的记忆」。

## 接触伤害的冷却（秒），避免每帧都扣血。
const CONTACT_COOLDOWN: float = 0.9
## 接触判定距离。
const CONTACT_DISTANCE: float = 26.0

var _cooldown: float = 0.0
var _lost_timer: float = 0.0


func enter(_previous_state: StringName = &"", _data: Dictionary = {}) -> void:
	_cooldown = 0.0
	_lost_timer = 0.0
	play_animation(&"walk")


func physics_update(delta: float) -> StringName:
	var townsman := owner_node as Townsman
	if townsman == null:
		return &""

	if townsman.is_dead:
		return &"dazed"

	if _cooldown > 0.0:
		_cooldown = maxf(_cooldown - delta, 0.0)

	if not townsman.is_target_valid():
		_lost_timer += delta
		if _lost_timer >= 1.5:
			return &"task"
	else:
		_lost_timer = 0.0

	townsman.move_toward_target(delta, townsman.move_speed * 0.9, CONTACT_DISTANCE * 0.6)
	townsman.apply_gravity_and_move(delta)

	if townsman.is_target_valid() and _cooldown <= 0.0:
		var distance := townsman.global_position.distance_to((townsman.target as Node2D).global_position)
		if distance <= CONTACT_DISTANCE:
			_deal_contact_damage(townsman)
	return &""


func _deal_contact_damage(townsman: Townsman) -> void:
	if townsman.target == null:
		return
	var hurt_boxes := townsman.target.get_children()
	for child in hurt_boxes:
		var hurt_box := child as HurtBox
		if hurt_box == null:
			continue
		var direction := ((townsman.target as Node2D).global_position - townsman.global_position).normalized()
		var info := DamageInfo.create(townsman.attack_damage, townsman, direction, 200.0)
		info.damage_type = &"contact"
		if hurt_box.receive_hit(info):
			_cooldown = CONTACT_COOLDOWN
			Combat.on_hit_landed(info, (townsman.target as Node2D).global_position)
		return
