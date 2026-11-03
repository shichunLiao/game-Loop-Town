extends State

## 死亡状态（提示词【七】：播放死亡动画 → 屏幕渐黑 → 回到最近 CheckPoint）。
##
## 本状态负责完整演完并触发重生，重生目标由 LoopManager 的检查点决定。
## 死亡计数交给 LoopManager，因为「循环」是本作的核心系统。

## 保持倒地姿态的时间（秒），之后开始淡出并重生。
const HOLD_TIME: float = 1.1
## 已经触发过重生就不再重复触发。
var _triggered: bool = false
var _elapsed: float = 0.0


func enter(_previous_state: StringName = &"", _data: Dictionary = {}) -> void:
	_elapsed = 0.0
	_triggered = false

	var player := owner_node as PlayerController
	if player == null:
		return

	play_animation(&"death", true)
	AudioManager.play_sfx("death")

	if player.hit_box != null:
		player.hit_box.deactivate()
	# 死亡瞬间停住水平移动，让死亡动画读得清楚。
	player.velocity.x = 0.0
	# 把当前血量写回存档，重生时不会带着 0 血复活。
	player.persist_health()


func physics_update(delta: float) -> StringName:
	var player := owner_node as PlayerController
	if player == null:
		return &""

	_elapsed += delta
	# 死亡后仍受重力，否则空中死亡会停在半空。
	player.apply_gravity_and_move(delta)

	if not _triggered and _elapsed >= HOLD_TIME:
		_triggered = true
		_do_respawn()
	return &""


func _do_respawn() -> void:
	var player := owner_node as PlayerController
	# 通知关心死亡的 UI / 关卡逻辑。
	if player != null:
		player.respawn_requested.emit()
	# 钟声在每次循环里都会响，是「有人想告诉你什么，但每次都被打断」的听觉线索。
	AudioManager.play_bell(true)
	# 重生：LoopManager 里记录最近检查点，GameManager 负责换图与淡入。
	GameManager.respawn_at_checkpoint()
