extends State

## 交互状态：执行一次互动（拾取、读信、和 NPC 说话、推动镜子）。
##
## 极短，只负责“播一下动作并把交互请求交给目标”，交互逻辑本身在目标节点里。

## 交互动作最短持续时间，避免瞬间闪过。
const MIN_TIME: float = 0.22

var _elapsed: float = 0.0
var _requested: bool = false


func enter(_previous_state: StringName = &"", _data: Dictionary = {}) -> void:
	_elapsed = 0.0
	_requested = false
	play_animation(&"interact", true)

	var player := owner_node as PlayerController
	if player != null:
		# 交互时停住，让玩家看清楚发生了什么。
		player.velocity.x = 0.0


func physics_update(delta: float) -> StringName:
	var player := owner_node as PlayerController
	if player == null:
		return &""

	if player.is_dead:
		return &"death"

	_elapsed += delta
	player.apply_gravity_and_move(delta)

	if not _requested:
		_requested = true
		var handled := player.try_interact()
		if not handled:
			# 没有可交互目标：立刻退出，不惩罚玩家。
			return _exit_state(player)
		AudioManager.play_sfx("interact")

	if _elapsed >= MIN_TIME:
		return _exit_state(player)
	return &""


func _exit_state(player: PlayerController) -> StringName:
	if not player.is_on_floor():
		return &"fall"
	if is_zero_approx(player.get_move_input()):
		return &"idle"
	return &"run"
