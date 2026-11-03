extends Node

## 循环管理器（autoload）— 提示词【七】【三十二】。
##
## 「247」必须在系统里真实存在，不能只是一个剧情数字：
##   - loop_count 初始 247，坏结局后 +1（248）
##   - 标题界面显示「第 N 次循环」
##   - 检查点、记忆碎片、Boss 进度、结局状态都在这里汇总
##
## 与 SaveManager 的分工：本类只持有运行时状态，落盘永远经过 SaveManager。

signal loop_started(loop_count: int)
signal loop_advanced(new_count: int)
signal checkpoint_reached(map_id: StringName, spawn_id: StringName)
signal boss_progress_changed(boss_id: StringName, phase: int)
signal boss_defeated(boss_id: StringName)
signal ending_triggered(ending: EndingState)

const INITIAL_LOOP_COUNT: int = 247
const BAD_ENDING_LOOP_COUNT: int = 248

enum EndingState {
	NONE = 0,
	PERFECT_LOOP = 1,     ## 结局一：完美循环（记忆不全 / 举起武器）
	STOPPED_CLOCK = 2,    ## 结局二：停摆的钟（帮看守拧发条）
	ZEROTH_LOOP = 3,      ## 结局三：第零次循环（真结局）
}

## 真相闪回之后才能触发的选择，用这个 flag 表示已经看过闪回。
const FLAG_SAW_FLASHBACK: StringName = &"saw_flashback"
## 是否已经在最终战前完成过井底真实记忆。
const FLAG_WELL_TRUE_MEMORY: StringName = &"well_true_memory"

var loop_count: int = INITIAL_LOOP_COUNT
var previous_loop_count: int = INITIAL_LOOP_COUNT - 1

## 最近检查点。
var checkpoint_map_id: StringName = &"town_entrance"
var checkpoint_spawn_id: StringName = &"start"
var checkpoint_position: Vector2 = Vector2.ZERO
var has_checkpoint: bool = false

## Boss 进度：String(boss_id) -> int(phase)。0 表示未遭遇。
var boss_progress: Dictionary = {}
var defeated_bosses: Array[StringName] = []
var completed_chapter_numbers: Array[int] = []

var ending_state: EndingState = EndingState.NONE
## 死亡次数，用于开发期评估难度。
var death_count: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


# ---------------------------------------------------------------------------
# 循环
# ---------------------------------------------------------------------------

## 开始一次新的循环（新游戏）。
func begin_new_loop() -> void:
	loop_count = INITIAL_LOOP_COUNT
	previous_loop_count = INITIAL_LOOP_COUNT - 1
	_reset_loop_progress()
	loop_started.emit(loop_count)


## 推进循环（坏结局 / 触发回溯）。编号 +1，并清空本轮的浅层进度。
func advance_loop() -> void:
	previous_loop_count = loop_count
	loop_count += 1
	_reset_loop_progress()
	if GameManager != null:
		GameManager.set_flag(&"loop_advanced", true)
	loop_advanced.emit(loop_count)


## 坏结局专用：把循环推到 248 并进入结局一。
func trigger_perfect_loop_ending() -> void:
	if loop_count < BAD_ENDING_LOOP_COUNT:
		previous_loop_count = loop_count
		loop_count = BAD_ENDING_LOOP_COUNT
		loop_advanced.emit(loop_count)
	_apply_ending(EndingState.PERFECT_LOOP)


## 标题界面用。提示词【三十二】：标题也可以显示第 248 次。
func get_loop_label() -> String:
	return "第 %d 次循环" % loop_count


func _reset_loop_progress() -> void:
	# 循环重置只清「浅层」进度：检查点、Boss 阶段。
	# 记忆碎片会被看守刻意保留下来（剧情设定），因此**不清空**。
	checkpoint_map_id = &"town_entrance"
	checkpoint_spawn_id = &"start"
	checkpoint_position = Vector2.ZERO
	has_checkpoint = false
	boss_progress.clear()
	defeated_bosses.clear()


# ---------------------------------------------------------------------------
# 检查点
# ---------------------------------------------------------------------------

func set_checkpoint(map_id: StringName, spawn_id: StringName, position: Vector2 = Vector2.ZERO) -> void:
	checkpoint_map_id = map_id
	checkpoint_spawn_id = spawn_id
	checkpoint_position = position
	has_checkpoint = true
	checkpoint_reached.emit(map_id, spawn_id)
	if SaveManager != null:
		SaveManager.request_save("checkpoint")


func register_death() -> void:
	death_count += 1
	if SaveManager != null:
		SaveManager.mark_dirty()


# ---------------------------------------------------------------------------
# Boss 进度
# ---------------------------------------------------------------------------

func set_boss_phase(boss_id: StringName, phase: int) -> void:
	var key := String(boss_id)
	if int(boss_progress.get(key, 0)) == phase:
		return
	boss_progress[key] = phase
	boss_progress_changed.emit(boss_id, phase)
	if SaveManager != null:
		SaveManager.mark_dirty()


func get_boss_phase(boss_id: StringName) -> int:
	return int(boss_progress.get(String(boss_id), 0))


func is_boss_defeated(boss_id: StringName) -> bool:
	return defeated_bosses.has(boss_id)


func mark_boss_defeated(boss_id: StringName) -> void:
	if defeated_bosses.has(boss_id):
		return
	defeated_bosses.append(boss_id)
	boss_progress[String(boss_id)] = 99
	boss_defeated.emit(boss_id)
	if SaveManager != null:
		SaveManager.request_save("boss_%s" % boss_id)


func mark_chapter_completed(chapter_number: int) -> void:
	if not completed_chapter_numbers.has(chapter_number):
		completed_chapter_numbers.append(chapter_number)


func is_chapter_completed(chapter_number: int) -> bool:
	return completed_chapter_numbers.has(chapter_number)


# ---------------------------------------------------------------------------
# 结局
# ---------------------------------------------------------------------------

## 判定三个结局（提示词【二十一】）。
## 调用方只需说明“最终战里玩家选了什么”。
func evaluate_ending(chose_hat_off: bool) -> EndingState:
	if not chose_hat_off:
		# 举起武器 → 继续战斗 → 死亡 → 回到循环起点
		trigger_perfect_loop_ending()
		return ending_state

	# 摘下帽子：看是否满足真结局的两个条件。
	var well_done: bool = GameManager != null and GameManager.has_flag(FLAG_WELL_TRUE_MEMORY)
	if well_done and MemoryManager != null and MemoryManager.has_all_core_fragments():
		_apply_ending(EndingState.ZEROTH_LOOP)
	else:
		_apply_ending(EndingState.PERFECT_LOOP)
	return ending_state


## 结局二由「我帮你拧发条」显式触发。
func trigger_stopped_clock_ending() -> void:
	_apply_ending(EndingState.STOPPED_CLOCK)


func _apply_ending(ending: EndingState) -> void:
	ending_state = ending
	ending_triggered.emit(ending)
	if SaveManager != null:
		SaveManager.request_save("ending_%d" % int(ending))


func get_ending_name(ending: EndingState) -> String:
	match ending:
		EndingState.PERFECT_LOOP: return "结局一 · 完美循环"
		EndingState.STOPPED_CLOCK: return "结局二 · 停摆的钟"
		EndingState.ZEROTH_LOOP: return "结局三 · 第零次循环"
	return "未定"


# ---------------------------------------------------------------------------
# 存档对接
# ---------------------------------------------------------------------------

func collect_save_data(data: SaveData) -> void:
	data.loop_count = loop_count
	data.previous_loop_count = previous_loop_count
	data.checkpoint_map_id = checkpoint_map_id
	data.checkpoint_spawn_id = checkpoint_spawn_id
	data.checkpoint_position = checkpoint_position
	data.boss_progress = boss_progress.duplicate(true)
	data.ending_state = int(ending_state)
	data.death_count = death_count


func apply_save_data(data: SaveData) -> void:
	loop_count = data.loop_count
	previous_loop_count = data.previous_loop_count
	checkpoint_map_id = data.checkpoint_map_id
	checkpoint_spawn_id = data.checkpoint_spawn_id
	checkpoint_position = data.checkpoint_position
	has_checkpoint = true
	boss_progress = data.boss_progress.duplicate(true)
	ending_state = data.ending_state as EndingState
	death_count = data.death_count

	defeated_bosses.clear()
	for key: Variant in boss_progress.keys():
		if int(boss_progress[key]) >= 99:
			defeated_bosses.append(StringName(key))
