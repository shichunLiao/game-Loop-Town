extends State

## 镇民的茫然状态（提示词【十二】：战斗后露出茫然表情）。
##
## 这是全游戏最重要的一条暗示之一：被击败的居民不是死掉，而是**茫然**。
## 他们不是自愿攻击你的——玩家应该在第一次见到这个表情时就开始怀疑。
##
## 注意：文件名 dazed.gd 就是状态名 &"dazed"，不要改名。

## 茫然持续时间（秒）。之后回到重复动作。
const DAZED_DURATION: float = 4.0

var _elapsed: float = 0.0


func enter(_previous_state: StringName = &"", _data: Dictionary = {}) -> void:
	_elapsed = 0.0
	play_animation(&"dazed", true)
	# 茫然时不看玩家 —— 他连你在哪都不知道了。
	var townsman := owner_node as Townsman
	if townsman != null and townsman.health != null:
		townsman.health.set_forced_invincible(true)


func physics_update(delta: float) -> StringName:
	var townsman := owner_node as Townsman
	if townsman == null:
		return &""

	townsman.velocity.x = 0.0
	townsman.apply_gravity_and_move(delta)

	_elapsed += delta
	if _elapsed >= DAZED_DURATION:
		return &"task"
	return &""
