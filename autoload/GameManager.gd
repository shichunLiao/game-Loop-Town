extends Node

## 全局游戏流程管理器（autoload）。
##
## 职责边界（严格）：
##   - 剧情 flag 的唯一读写入口
##   - 地图切换 / 重生 / 回标题的流程编排
##   - 暂停状态广播
## 不负责：存档落盘（SaveManager）、世界外观（WorldStateManager）、
## 记忆内容（MemoryManager）、循环计数（LoopManager）、音频（AudioManager）。

signal game_started
signal game_paused(is_paused: bool)
signal map_load_started(map_id: StringName)
signal map_load_finished(map_id: StringName, spawn_id: StringName)
signal flag_changed(flag: StringName, value: bool)
signal chapter_completed(chapter_id: StringName)
signal game_over(reason: StringName)

const SAVE_KEYS := {
	"FLAG_CHAPTER_1": &"chapter_1_cleared",
	"FLAG_CHAPTER_2": &"chapter_2_cleared",
	"FLAG_CHAPTER_3": &"chapter_3_cleared",
	"FLAG_CHAPTER_4": &"chapter_4_cleared",
}

var is_paused: bool = false
## 剧情 flag。键为 StringName，值为 bool 或 int。
var flags: Dictionary = {}
## 当前地图与出生点。
var current_map_id: StringName = &"town_entrance"
var current_spawn_id: StringName = &"default"
## 已通关章节。
var completed_chapters: PackedStringArray = PackedStringArray()
## 运行时长统计。
var play_seconds: float = 0.0

var _current_map: Node = null
var _transitioning: bool = false
## 游戏内 UI 容器（HUD / 暂停菜单 / 笔记本 / 对话框）。整个会话只存在一份。
var _game_hud: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"game_manager")


## 保证游戏内 UI 已经挂载。整个游戏只做一次。
func _ensure_game_hud() -> void:
	if _game_hud != null and is_instance_valid(_game_hud):
		return
	var path := "res://scenes/ui/GameHUD.tscn"
	if not ResourceLoader.exists(path):
		push_warning("[GameManager] GameHUD 场景缺失，游戏内 UI 不会出现。")
		return
	var packed := load(path) as PackedScene
	if packed == null:
		return
	_game_hud = packed.instantiate()
	_game_hud.name = "GameHUD"
	# 挂在根节点而不是 current_scene 下，这样换图时 UI 不会被一起销毁。
	get_tree().root.add_child.call_deferred(_game_hud)


func _process(delta: float) -> void:
	if not is_paused:
		play_seconds += delta


# ---------------------------------------------------------------------------
# 剧情 flag
# ---------------------------------------------------------------------------

## 设置一个 flag。写入会被广播，UI 与关卡据此自我更新。
func set_flag(flag: StringName, value: bool = true) -> void:
	if flag == &"":
		return
	flags[flag] = value
	flag_changed.emit(flag, value)
	if SaveManager != null:
		SaveManager.mark_dirty()


## 读取 flag。未设置视为 false。
func has_flag(flag: StringName) -> bool:
	return bool(flags.get(flag, false))


## 一次性置位，返回是否发生了改变。
func set_flag_once(flag: StringName) -> bool:
	if has_flag(flag):
		return false
	set_flag(flag, true)
	return true


func get_flag_int(flag: StringName, default_value: int = 0) -> int:
	var value: Variant = flags.get(flag, default_value)
	if value is bool:
		return 1 if value else 0
	if value is int:
		return value
	if value is float:
		return int(value)
	return default_value


func set_flag_int(flag: StringName, value: int) -> void:
	flags[flag] = value
	flag_changed.emit(flag, value > 0)
	if SaveManager != null:
		SaveManager.mark_dirty()


## 条件表达式求值。支持：
##   ""                        无条件成立
##   "flag:xxx"                拥有该 flag
##   "noflag:xxx"              没有该 flag
##   "memory:xxx"              已收集该记忆
##   "memories>=3"             记忆数量判定
##   "chapter:1"               第一章已通关
##   "item:big_scissors"       持有该道具
##   "and:a|b" / "or:a|b"      组合（子条件用 | 分隔）
func evaluate_condition(condition: StringName) -> bool:
	var text := String(condition).strip_edges()
	if text.is_empty():
		return true

	if text.begins_with("and:"):
		for part in text.substr(4).split("|", false):
			if not evaluate_condition(StringName(part.strip_edges())):
				return false
		return true
	if text.begins_with("or:"):
		for part in text.substr(3).split("|", false):
			if evaluate_condition(StringName(part.strip_edges())):
				return true
		return false

	var colon := text.find(":")
	if colon > 0:
		var kind := text.substr(0, colon)
		var value := text.substr(colon + 1).strip_edges()
		match kind:
			"flag":
				return has_flag(StringName(value))
			"noflag":
				return not has_flag(StringName(value))
			"memory":
				return MemoryManager != null and MemoryManager.has_memory(StringName(value))
			"item":
				return SaveManager != null and SaveManager.get_item_count(StringName(value)) > 0
			"chapter":
				return int(value) > 0 and _is_chapter_cleared(int(value))
			"memories>=":
				var need := int(value)
				var have := MemoryManager.get_collected_count() if MemoryManager != null else 0
				return have >= need
	return false


# ---------------------------------------------------------------------------
# 章节进度
# ---------------------------------------------------------------------------

func complete_chapter(chapter_number: int) -> void:
	var key := "chapter_%d_cleared" % chapter_number
	if not completed_chapters.has(key):
		completed_chapters.append(key)
	set_flag(StringName(key), true)
	chapter_completed.emit(StringName(key))
	if WorldStateManager != null:
		WorldStateManager.advance_for_chapter(chapter_number)
	if LoopManager != null:
		LoopManager.mark_chapter_completed(chapter_number)
	if SaveManager != null:
		SaveManager.request_save("chapter_%d" % chapter_number)


func _is_chapter_cleared(chapter_number: int) -> bool:
	return completed_chapters.has("chapter_%d_cleared" % chapter_number)


func is_chapter_cleared(chapter_number: int) -> bool:
	return _is_chapter_cleared(chapter_number)


# ---------------------------------------------------------------------------
# 流程
# ---------------------------------------------------------------------------

## 开始新游戏：清空全部运行时状态，然后进入序幕。
func start_new_game() -> void:
	reset_runtime_state()
	if LoopManager != null:
		LoopManager.begin_new_loop()
	if WorldStateManager != null:
		WorldStateManager.reset_to_initial()
	if MemoryManager != null:
		MemoryManager.reset()
	if SaveManager != null:
		SaveManager.reset_runtime()
	_ensure_game_hud()
	game_started.emit()
	await change_map(&"town_entrance", &"start")


## 从存档继续。
func continue_from_save() -> bool:
	var loaded := SaveManager != null and SaveManager.load_game()
	if not loaded:
		return false
	_ensure_game_hud()
	game_started.emit()
	await change_map(current_map_id, current_spawn_id)
	return true


## 清空运行时状态。不删除存档文件。
func reset_runtime_state() -> void:
	flags.clear()
	completed_chapters = PackedStringArray()
	play_seconds = 0.0
	current_map_id = &"town_entrance"
	current_spawn_id = &"default"
	if is_paused:
		set_paused(false)


## 切换地图（异步）。同一时刻只允许一次切换。
func change_map(map_id: StringName, spawn_id: StringName = &"default") -> void:
	if _transitioning:
		push_warning("[GameManager] change_map 重入被忽略: %s" % map_id)
		return
	var map_data := MapRegistry.get_map(map_id)
	if map_data == null:
		push_error("[GameManager] 未知地图: %s" % map_id)
		return

	_transitioning = true
	map_load_started.emit(map_id)
	set_paused(false)

	await ScreenTransition.fade_out()

	if _current_map != null and is_instance_valid(_current_map):
		_current_map.queue_free()
		_current_map = null
		# 等一帧，确保旧地图的物理体全部退出场景树。
		await get_tree().process_frame

	var packed := load(map_data.scene_path) as PackedScene
	if packed == null:
		push_error("[GameManager] 无法加载地图场景: %s" % map_data.scene_path)
		_transitioning = false
		await ScreenTransition.fade_in()
		return

	_current_map = packed.instantiate()
	var host := get_tree().current_scene
	if host == null:
		# 没有 current_scene 时（例如从脚本直接启动）挂到根节点。
		host = get_tree().root
	host.add_child(_current_map)

	current_map_id = map_id
	current_spawn_id = spawn_id

	# 让地图把玩家放到正确出生点。
	if _current_map.has_method("place_player_at_spawn"):
		await _current_map.call("place_player_at_spawn", spawn_id)

	if AudioManager != null:
		AudioManager.enter_area(map_data.audio_area)

	map_load_finished.emit(map_id, spawn_id)
	_transitioning = false
	await ScreenTransition.fade_in()


## 死亡后回到最近检查点。
func respawn_at_checkpoint() -> void:
	if LoopManager == null:
		await change_map(&"town_entrance", &"start")
		return
	await change_map(LoopManager.checkpoint_map_id, LoopManager.checkpoint_spawn_id)


func set_paused(value: bool) -> void:
	if is_paused == value:
		return
	is_paused = value
	get_tree().paused = value
	game_paused.emit(value)


func toggle_pause() -> void:
	set_paused(not is_paused)


func return_to_title() -> void:
	set_paused(false)
	if SaveManager != null:
		SaveManager.request_save("return_to_title")
	_transitioning = false
	get_tree().change_scene_to_file("res://scenes/ui/TitleScreen.tscn")


func quit_game() -> void:
	if SaveManager != null:
		SaveManager.request_save("quit")
	get_tree().quit()


# ---------------------------------------------------------------------------
# 存档对接
# ---------------------------------------------------------------------------

func apply_save_data(data: SaveData) -> void:
	flags = data.flags.duplicate(true)
	completed_chapters = data.completed_chapters.duplicate()
	current_map_id = data.current_map_id
	current_spawn_id = data.spawn_id
	play_seconds = data.play_seconds


func collect_save_data(data: SaveData) -> void:
	data.flags = flags.duplicate(true)
	data.completed_chapters = completed_chapters.duplicate()
	data.current_map_id = current_map_id
	data.spawn_id = current_spawn_id
	data.play_seconds = play_seconds
