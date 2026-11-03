extends Node

## 存档管理器（autoload）— 提示词【二十七】第 9 条：存档统一由 SaveManager 处理。
##
## 设计要点：
##   - 所有系统只通过 collect_save_data / apply_save_data 与存档交互，谁都不直接写盘。
##   - 支持自动存档（章节通关、检查点、退出、切图）。
##   - 写入使用原子替换：先写 .tmp 再改名，避免断电 / 崩溃留下半个存档。
##   - 单槽位 + 一份自动备份，够 Demo 用且不会让 UI 复杂化。

signal game_saved(slot: StringName)
signal game_loaded(slot: StringName)
signal save_failed(reason: String)

const SAVE_DIR: String = "user://saves"
const SAVE_PATH: String = "user://saves/slot_0.save"
const BACKUP_PATH: String = "user://saves/slot_0.save.bak"
const AUTOSAVE_DEBOUNCE_SECONDS: float = 2.0

## 最近一次存档时间戳（Unix 秒）。0 表示本会话没存过。
var last_save_unix: int = 0
## 是否存在可继续的存档（标题界面据此启用“继续”）。
var has_save: bool = false
## QA and preview runners select a separate slot without touching user progress.
var exploration_slot_name: String = "exploration_v2"

var _dirty: bool = false
var _autosave_timer: Timer = null
var _loading: bool = false

## 道具计数表：String(item_id) -> int。
var _item_counts: Dictionary = {}

## 玩家生命（由玩家脚本读写，避免玩家自己开存档字段）。
var _player_max_health: int = 100
var _player_health: int = 100


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	has_save = FileAccess.file_exists(SAVE_PATH)

	_autosave_timer = Timer.new()
	_autosave_timer.name = "AutosaveTimer"
	_autosave_timer.one_shot = true
	_autosave_timer.wait_time = AUTOSAVE_DEBOUNCE_SECONDS
	_autosave_timer.timeout.connect(_on_autosave_timeout)
	add_child(_autosave_timer)


func _notification(what: int) -> void:
	# 关窗 / 切后台时兜底保存，避免玩家丢掉进度。
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		if _dirty:
			save_game("auto_quit")


# ---------------------------------------------------------------------------
# 存档 / 读档
# ---------------------------------------------------------------------------

func mark_dirty() -> void:
	_dirty = true


## 请求一次带防抖的自动存档。频繁调用只会存一次。
func request_save(reason: String = "auto") -> void:
	mark_dirty()
	if _autosave_timer == null:
		save_game(reason)
		return
	if _autosave_timer.is_stopped():
		_autosave_timer.start()


func _on_autosave_timeout() -> void:
	if _dirty:
		save_game("autosave")


## 立即存档。返回是否成功。
func save_game(reason: String = "manual") -> bool:
	var data := SaveData.new()
	_collect(data)

	var json := JSON.stringify(data.to_dict(), "  ")
	if json.is_empty():
		save_failed.emit("序列化失败")
		push_error("[SaveManager] 序列化存档失败 (%s)" % reason)
		return false

	if not _write_atomic(SAVE_PATH, json):
		save_failed.emit("写入失败")
		return false

	_dirty = false
	has_save = true
	last_save_unix = int(Time.get_unix_time_from_system())
	game_saved.emit(&"slot_0")
	return true


func load_game() -> bool:
	if not has_save and not FileAccess.file_exists(SAVE_PATH):
		save_failed.emit("没有存档")
		return false

	var text := _read_text(SAVE_PATH)
	if text.is_empty() and FileAccess.file_exists(BACKUP_PATH):
		# 主存档损坏时回退到备份。
		push_warning("[SaveManager] 主存档不可读，尝试备份。")
		text = _read_text(BACKUP_PATH)
	if text.is_empty():
		save_failed.emit("存档不可读")
		return false

	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_error("[SaveManager] 存档 JSON 解析失败。")
		save_failed.emit("存档损坏")
		return false

	var data := SaveData.new()
	data.from_dict(parsed)
	_apply(data)

	_dirty = false
	_loading = false
	has_save = true
	game_loaded.emit(&"slot_0")
	return true


func delete_save() -> void:
	for path in [SAVE_PATH, BACKUP_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	has_save = false
	_dirty = false


## 新游戏时清空运行时态（不动盘上的存档，直到下一次保存覆盖）。
func reset_runtime() -> void:
	_dirty = false
	_item_counts.clear()
	_player_max_health = 100
	_player_health = _player_max_health


# ---------------------------------------------------------------------------
# 玩家生命
# ---------------------------------------------------------------------------

func set_player_health(current: int, maximum: int) -> void:
	_player_health = clampi(current, 0, maximum)
	_player_max_health = maximum


func get_player_health() -> int:
	return _player_health


func get_player_max_health() -> int:
	return _player_max_health


# ---------------------------------------------------------------------------
# 道具（计数制，栈式道具可堆叠）
# ---------------------------------------------------------------------------

func add_item(item: ItemData, count: int = 1) -> void:
	if item == null:
		return
	var key := String(item.id)
	var current := int(_item_counts.get(key, 0))
	var cap := item.max_stack if item.is_stackable() else 1
	_item_counts[key] = mini(current + count, cap)
	mark_dirty()


func consume_item(item_id: StringName, count: int = 1) -> bool:
	var key := String(item_id)
	var current := int(_item_counts.get(key, 0))
	if current < count:
		return false
	_item_counts[key] = current - count
	mark_dirty()
	return true


func get_item_count(item_id: StringName) -> int:
	return int(_item_counts.get(String(item_id), 0))


func has_item(item_id: StringName) -> bool:
	return get_item_count(item_id) > 0


# ---------------------------------------------------------------------------
# 内部：收集 / 应用
# ---------------------------------------------------------------------------

func _collect(data: SaveData) -> void:
	data.player_max_health = _player_max_health
	data.player_health = _player_health
	data.item_counts = _item_counts.duplicate(true)

	if GameManager != null:
		GameManager.collect_save_data(data)
	if WorldStateManager != null:
		WorldStateManager.collect_save_data(data)
	if MemoryManager != null:
		MemoryManager.collect_save_data(data)
	if LoopManager != null:
		LoopManager.collect_save_data(data)


func _apply(data: SaveData) -> void:
	_loading = true
	_player_max_health = data.player_max_health
	_player_health = data.player_health
	_item_counts = data.item_counts.duplicate(true)

	if WorldStateManager != null:
		WorldStateManager.apply_save_data(data)
	if LoopManager != null:
		LoopManager.apply_save_data(data)
	if MemoryManager != null:
		MemoryManager.apply_save_data(data)
	if GameManager != null:
		GameManager.apply_save_data(data)


func _write_atomic(path: String, text: String) -> bool:
	# 先备份旧档，再写临时文件，最后原子改名。
	if FileAccess.file_exists(path):
		var old := _read_text(path)
		if not old.is_empty():
			var backup := FileAccess.open(BACKUP_PATH, FileAccess.WRITE)
			if backup != null:
				backup.store_string(old)
				backup.close()

	var tmp_path := path + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		push_error("[SaveManager] 无法写入 %s (错误码 %d)" % [tmp_path, FileAccess.get_open_error()])
		return false
	file.store_string(text)
	file.close()

	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		push_error("[SaveManager] 无法打开存档目录。")
		return false
	var err := dir.rename(tmp_path.get_file(), path.get_file())
	if err != OK:
		# 部分平台不支持直接改名，退化成覆盖写。
		var fallback := FileAccess.open(path, FileAccess.WRITE)
		if fallback == null:
			return false
		fallback.store_string(text)
		fallback.close()
		dir.remove(tmp_path.get_file())
	return true


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


## Exploration demo has its own versioned slot, leaving the story save intact.
func save_exploration(data: Dictionary) -> bool:
	var path: String = SAVE_DIR + "/" + exploration_slot_name + ".json"
	var temporary: String = path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "  "))
	file.close()
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(path, path + ".bak")
	var error: Error = DirAccess.rename_absolute(temporary, path)
	if error != OK:
		return false
	game_saved.emit(&"exploration_v2")
	return true


func load_exploration() -> Dictionary:
	var primary: String = SAVE_DIR + "/" + exploration_slot_name + ".json"
	for path: String in [primary, primary + ".bak"]:
		if FileAccess.file_exists(path):
			var parsed: Variant = JSON.parse_string(_read_text(path))
			if parsed is Dictionary and int(parsed.get("version", 0)) == 2:
				return parsed
	return {}
