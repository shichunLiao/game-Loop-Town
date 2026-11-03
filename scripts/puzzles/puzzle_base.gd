class_name PuzzleBase
extends Node2D

## 解谜框架基类（提示词【二十九】）。
##
## 所有谜题共享同一套接口与生命周期，因此：
##   - 存档只需要记录 solved_puzzles 里的 id
##   - 剧情可以统一用 "puzzle:<id>" 作为条件
##   - 新增谜题类型只需继承本类，不用改关卡代码
##
## 必须提供：is_solved / solve() / reset() / check_condition()

signal solved(puzzle_id: StringName)
signal reset_done(puzzle_id: StringName)
signal progress_changed(puzzle_id: StringName, progress: float)
signal step_completed(puzzle_id: StringName, step_index: int)

## 谜题唯一标识。用于存档与剧情条件判定。
@export var puzzle_id: StringName = &""
## 解谜后置位的 flag。
@export var solve_flag: StringName = &""
## 解谜后奖励的记忆碎片。
@export var reward_memory_id: StringName = &""
## 解谜时播放的音效。
@export var solve_sfx: String = "light_focus"
## 是否在进入场景时按存档恢复已解状态。
@export var restore_from_save: bool = true

var is_solved: bool = false


func _ready() -> void:
	add_to_group(&"puzzle")
	if restore_from_save and _was_solved_before():
		# 已经解过的谜题：直接进入已解状态，不重播演出。
		is_solved = true
		_apply_solved_state(true)
	else:
		_puzzle_ready()
		_refresh_progress()


## 子类重写它做初始化。
func _puzzle_ready() -> void:
	pass


# ---------------------------------------------------------------------------
# 统一接口
# ---------------------------------------------------------------------------

## 判定当前是否满足解谜条件。子类必须实现。
func check_condition() -> bool:
	return false


## 尝试解谜。条件满足则完成。
func solve() -> bool:
	if is_solved:
		return false
	if not check_condition():
		return false
	is_solved = true
	_apply_solved_state(true)
	_on_solved()
	if not solve_flag.is_empty():
		GameManager.set_flag(solve_flag, true)
	if not reward_memory_id.is_empty():
		MemoryManager.collect(reward_memory_id)
	if not solve_sfx.is_empty():
		AudioManager.play_sfx(solve_sfx)
	_persist_solved()
	solved.emit(puzzle_id)
	return true


## 重置谜题（玩家死亡回溯 / 主动重来）。
func reset() -> void:
	if not is_solved:
		# 未解的谜题也可能需要重置机关状态（例如镜子回到初始角度）。
		_apply_solved_state(false)
		_refresh_progress()
	elif _can_reset_after_solved():
		is_solved = false
		_apply_solved_state(false)
		_forget_solved()
		_refresh_progress()
		reset_done.emit(puzzle_id)


## 供子类判定“解完之后还能不能重置”。默认不能（避免剧情倒退）。
func _can_reset_after_solved() -> bool:
	return false


## 子类重写：把机关表现切换到已解 / 未解状态。
func _apply_solved_state(_solved: bool) -> void:
	pass


## 子类重写：解谜成功时的额外演出（开门、融化蜡像等）。
func _on_solved() -> void:
	pass


## 子类重写：返回 0..1 的完成度。
func get_progress() -> float:
	return 1.0 if is_solved else 0.0


func _refresh_progress() -> void:
	progress_changed.emit(puzzle_id, get_progress())


## 子类在状态变化时调用，广播进度。
func notify_progress() -> void:
	_refresh_progress()
	if check_condition():
		solve()


# ---------------------------------------------------------------------------
# 存档
# ---------------------------------------------------------------------------

func _was_solved_before() -> bool:
	if puzzle_id == &"":
		return false
	if not SaveManager.has_save:
		return false
	# solved_puzzles 在读档时写入 GameManager 的 flag，这里用 flag 判定。
	if not solve_flag.is_empty():
		return GameManager.has_flag(solve_flag)
	return false


func _persist_solved() -> void:
	if SaveManager != null:
		SaveManager.mark_dirty()


func _forget_solved() -> void:
	if not solve_flag.is_empty():
		GameManager.set_flag(solve_flag, false)
