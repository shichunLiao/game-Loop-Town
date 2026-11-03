class_name Townsman
extends NPCBase

## 镇民（提示词【十二】）。
##
## 全镇最重要的一个设定必须在代码里成立：
##   玩家碰到 NPC → NPC 短暂停止动作 → **卡顿 0.2~0.5 秒** → 继续执行原动作。
## 因为「被打断就会卡顿」正是他们不是活人、而是记忆截面的证据。
##
## 三类镇民：
##   PEACEFUL  可以正常对话
##   WATCHER   不对话，只是转头看向玩家
##   HOSTILE   靠近即进入攻击；**被击败后露出茫然表情**，暗示他们不是自愿攻击

enum Mood {
	PEACEFUL,
	WATCHER,
	HOSTILE,
}

@export var mood: Mood = Mood.PEACEFUL
## 重复动作时长的取值范围（秒），每个镇民随机取，避免全镇同步。
@export var action_min_time: float = 1.8
@export var action_max_time: float = 3.6
## 被玩家碰到时的卡顿时长（0.2~0.5 秒，提示词【十二】明确给出）。
@export var stagger_min_time: float = 0.2
@export var stagger_max_time: float = 0.5
## 卡顿后恢复原动作的概率（其余情况会换一个动作）。
@export var resume_action_chance: float = 0.75

## 正在循环播放的动作名。用于卡顿后“继续执行原动作”。
var current_action: StringName = &"task"
var action_remaining: float = 0.0
var _last_action: StringName = &"task"


func _after_ready() -> void:
	add_to_group(&"townsman")
	add_to_group(&"npc")
	enemy_id = &"townsman"

	# 镇民默认不作为敌人出现：只有 HOSTILE 才有攻击性。
	if mood != Mood.HOSTILE:
		if health != null:
			health.set_forced_invincible(true)
		if hit_box != null:
			hit_box.deactivate()

	# 每个人都错开一个相位，避免整条街同时做同一个动作。
	action_remaining = randf_range(action_min_time, action_max_time)
	if state_machine != null:
		state_machine.setup(self)


## 被玩家碰到（或走进玩家）时调用。由镇民碰撞检测或玩家侧触发。
func on_player_touch() -> void:
	if is_dead:
		return
	if state_machine == null:
		return
	# 只在“正在做事”或“待机”时被打断，攻击/受击途中不打断。
	if state_machine.current_state_name != &"task" and state_machine.current_state_name != &"idle":
		return
	state_machine.change_state(&"staggered")


## 取一个随机动作名。占位美术里只有 task / idle 两个循环动作可用。
func pick_action() -> StringName:
	var candidates: Array[StringName] = [&"task", &"task", &"task", &"idle"]
	if has_animation(&"task_b"):
		candidates.append(&"task_b")
	if has_animation(&"task_c"):
		candidates.append(&"task_c")
	# 大部分时候维持同一个动作，符合“每天重复同样的行为”。
	if randf() < resume_action_chance:
		return current_action
	var picked: StringName = candidates[randi() % candidates.size()]
	_last_action = picked
	return picked


func roll_action_duration() -> float:
	return randf_range(action_min_time, action_max_time)


func is_hostile() -> bool:
	return mood == Mood.HOSTILE


## 战斗结束后进入茫然状态（提示词【十二】：战斗后露出茫然表情）。
func become_dazed() -> void:
	if state_machine != null and state_machine.has_state(&"dazed"):
		state_machine.change_state(&"dazed")


## HOSTILE 镇民被击败时不该“死掉消失”，而是回到茫然状态。
func on_died() -> void:
	AudioManager.play_sfx("enemy_death")
	# 镇民不是真敌人：不播放死亡移除，而是转成茫然。
	if health != null:
		health.revive(health.max_health)
		health.set_forced_invincible(true)
	become_dazed()
