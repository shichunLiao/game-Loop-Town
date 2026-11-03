extends State

## 蜡像的跳扑：跃向玩家，落地后进入短暂后摇。
##
## 生帧窗口覆盖整个滞空阶段，因此玩家可以通过侧移躲开——
## 这是「蜡像很慢，但你不能站着不动」这条节奏的来源。

## 落地后的后摇时长。
const LANDING_RECOVERY: float = 0.45
## 滞空最长时长（防止卡在半空）。
const MAX_AIR_TIME: float = 1.4

var _elapsed: float = 0.0
var _landed: bool = false
var _dummy: WaxDummy = null


func enter(_previous_state: StringName = &"", _data: Dictionary = {}) -> void:
	_dummy = owner_node as WaxDummy
	_elapsed = 0.0
	_landed = false
	if _dummy == null:
		return
	_dummy.begin_lunge()
	if _dummy.hit_box != null:
		_dummy.hit_box.configure(_dummy.attack_damage, 260.0, 0.06, &"wax")
		_dummy.hit_box.activate()


func exit() -> Dictionary:
	if _dummy != null:
		_dummy.end_lunge()
		if _dummy.hit_box != null:
			_dummy.hit_box.deactivate()
	return {}


func physics_update(delta: float) -> StringName:
	if _dummy == null:
		return &""

	if _dummy.is_dead:
		if _dummy.hit_box != null:
			_dummy.hit_box.deactivate()
		return &"death"

	_elapsed += delta

	# 滞空阶段只受重力，不再有水平操控，落地才停。
	_dummy.apply_gravity_and_move(delta)

	if not _landed and (_dummy.is_on_floor() or _elapsed >= MAX_AIR_TIME):
		_landed = true
		if _dummy.hit_box != null:
			_dummy.hit_box.deactivate()
		_dummy.velocity.x = 0.0

	if _landed and _elapsed >= MAX_AIR_TIME + LANDING_RECOVERY:
		if _dummy.is_aware and _dummy.is_target_valid():
			return &"chase"
		return &"idle"
	return &""
