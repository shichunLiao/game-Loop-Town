class_name DamageInfo
extends RefCounted

## 一次伤害的完整描述。战斗系统各环节只传递这个对象，避免到处传一长串参数。

var amount: int = 0
## 伤害来源节点（敌人或玩家）。用于归属判定与击杀统计。
var source: Node = null
## 受击方向（单位向量）。演员据此做击退与受击动画朝向。
var direction: Vector2 = Vector2.RIGHT
## 击退力度（像素/秒）。
var knockback: float = 220.0
## 顿帧时长（秒）。0 表示不顿帧。
var hit_stop: float = 0.06
## 命中后给予受击者的无敌时间。
var invincible_time: float = 0.6
## 是否可以被格挡 / 无敌帧抵消。
var can_be_blocked: bool = true
## 伤害类型标识，用于表现（例如 "wax" 会走蜡化死亡）。
var damage_type: StringName = &"normal"
## 是否强制造成受击闪白。
var flash: bool = true
## 屏幕震动强度 0..1。
var shake: float = 0.25

## 复制一份并按倍率缩放伤害。HurtBox 的 damage_multiplier 用它。
func duplicate_for_multiplier(multiplier: float) -> DamageInfo:
	if is_equal_approx(multiplier, 1.0):
		return self
	var copy := DamageInfo.new()
	copy.amount = maxi(int(round(float(amount) * maxf(multiplier, 0.0))), 0)
	copy.source = source
	copy.direction = direction
	copy.knockback = knockback * maxf(multiplier, 0.0)
	copy.hit_stop = hit_stop
	copy.invincible_time = invincible_time
	copy.can_be_blocked = can_be_blocked
	copy.damage_type = damage_type
	copy.flash = flash
	copy.shake = shake
	return copy


static func create(
	amount_value: int,
	source_node: Node,
	direction_value: Vector2 = Vector2.RIGHT,
	knockback_value: float = 220.0
) -> DamageInfo:
	var info := DamageInfo.new()
	info.amount = maxi(amount_value, 0)
	info.source = source_node
	info.direction = direction_value.normalized() if direction_value.length_squared() > 0.0 else Vector2.RIGHT
	info.knockback = knockback_value
	return info
