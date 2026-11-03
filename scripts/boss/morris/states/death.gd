extends State

## 莫里斯死亡（提示词【十三】：玩家站在远处看着莫里斯消散，同时响起钟声）。
##
## 关键演出顺序：
##   1. 消散动画
##   2. 钟声
##   3. 循环字幕提示（「这是……？」）
## Boss 实体**不移除**，因为后续剧情（记忆线）还需要它所在的场景。

## 消散时长（秒）。
const DISSOLVE_TIME: float = 2.6

var _elapsed: float = 0.0
var _bell_rung: bool = false


func enter(_previous_state: StringName = &"", _data: Dictionary = {}) -> void:
	_elapsed = 0.0
	_bell_rung = false
	play_animation(&"death", true)

	var morris := owner_node as Morris
	if morris == null:
		return
	if morris.hit_box != null:
		# 死亡时立刻关闭攻击判定，否则玩家会在他倒下后还被打。
		morris.hit_box.deactivate()
	if morris.hurt_box != null:
		morris.hurt_box.set_deferred("monitorable", false)


func physics_update(delta: float) -> StringName:
	var morris := owner_node as Morris
	if morris == null:
		return &""

	_elapsed += delta
	morris.velocity.x = move_toward(morris.velocity.x, 0.0, 400.0 * delta)
	morris.apply_gravity_and_move(delta)

	# 消散：越到后面越透明。
	if morris.sprite != null:
		var ratio := clampf(_elapsed / DISSOLVE_TIME, 0.0, 1.0)
		morris.sprite.modulate.a = 1.0 - ratio
		morris.sprite.modulate = morris.sprite.modulate.lerp(Color(1.2, 0.9, 0.7, 1.0), delta * ratio)

	# 钟声：循环的听觉标志（提示词【三十六】：钟声必须成为重要的叙事声音）。
	if not _bell_rung and _elapsed >= DISSOLVE_TIME * 0.5:
		_bell_rung = true
		AudioManager.play_bell()

	# 停在这个状态，不做任何状态切换 —— 由剧情决定下一步。
	return &""
