extends Node

## 记忆 / 线索管理器（autoload）— 提示词【八】【三十一】。
##
## 所有记忆内容都放在 data/memories/*.tres，本管理器只负责：
##   - 载入与索引
##   - 收集状态
##   - 解锁条件判定（委托 GameManager.evaluate_condition）
##   - 变化时广播（笔记本 UI 与 HUD 各自响应）
##
## 关键设计（必须保留）：文本只有一套，[MemoryData] 同时记录
## 「第一次理解」与「第五章之后重读」，绝不写两套文案。

signal memory_collected(memory: MemoryData)
signal memory_unlocked(memory: MemoryData)
signal memory_reset

const MEMORY_DIR: String = "res://data/memories"

## 真结局判定所需的核心记忆碎片 id（提示词【三十一】）。
const CORE_FRAGMENT_IDS: Array[StringName] = [
	&"wax_order",
	&"final_ticket",
	&"summer_camp_photo",
	&"fire_brigade_tag",
	&"well_full_memory",
	&"seven_selves",
]

var _all: Array[MemoryData] = []
var _by_id: Dictionary = {}
var _collected: Dictionary = {}
var _unlocked: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_all()
	# 进度变化可能解锁新的条目，交给 GameManager 的 flag 广播驱动。
	if GameManager != null:
		GameManager.flag_changed.connect(_on_flag_changed)


# ---------------------------------------------------------------------------
# 载入
# ---------------------------------------------------------------------------

func _load_all() -> void:
	_all.clear()
	_by_id.clear()

	var dir := DirAccess.open(MEMORY_DIR)
	if dir == null:
		push_warning("[MemoryManager] 记忆目录不存在: %s" % MEMORY_DIR)
		return

	var file_names := dir.get_files()
	file_names.sort()
	for file_name in file_names:
		# 导出后 .tres 会变成 .remap，这里两种都接受。
		var clean := file_name.trim_suffix(".remap")
		if not clean.ends_with(".tres"):
			continue
		var path := "%s/%s" % [MEMORY_DIR, clean]
		var memory := load(path) as MemoryData
		if memory == null:
			push_warning("[MemoryManager] 记忆资源加载失败: %s" % path)
			continue
		if memory.id == &"":
			memory.id = StringName(clean.get_basename())
		_all.append(memory)
		_by_id[memory.id] = memory

	_all.sort_custom(_sort_by_category)
	_refresh_unlocked(true)


func _sort_by_category(a: MemoryData, b: MemoryData) -> bool:
	if a.category == b.category:
		return String(a.id) < String(b.id)
	return int(a.category) < int(b.category)


# ---------------------------------------------------------------------------
# 查询
# ---------------------------------------------------------------------------

func has_memory(memory_id: StringName) -> bool:
	return _collected.has(memory_id)


func is_unlocked(memory_id: StringName) -> bool:
	return _unlocked.has(memory_id)


func get_memory(memory_id: StringName) -> MemoryData:
	return _by_id.get(memory_id, null)


## 已收集的条目（笔记本「已记录」页用）。
func get_all_memories() -> Array[MemoryData]:
	var out: Array[MemoryData] = []
	for memory in _all:
		if _collected.has(memory.id):
			out.append(memory)
	return out


## 全部条目，含尚未收集的（笔记本用「？？？」占位）。
func get_all_definitions() -> Array[MemoryData]:
	return _all.duplicate()


## 当前已解锁（可以出现在笔记本里）的条目。未解锁的连占位都不显示。
func get_unlocked_memories() -> Array[MemoryData]:
	var out: Array[MemoryData] = []
	for memory in _all:
		if _unlocked.has(memory.id):
			out.append(memory)
	return out


func get_collected_count() -> int:
	return _collected.size()


## 只统计真正的记忆碎片（影响结局判定）。
func get_fragment_count() -> int:
	var count := 0
	for id: Variant in _collected.keys():
		var memory: MemoryData = _by_id.get(id, null)
		if memory != null and memory.is_fragment:
			count += 1
	return count


func get_core_fragment_total() -> int:
	return CORE_FRAGMENT_IDS.size()


## 是否已集齐真结局所需的全部核心碎片。
func has_all_core_fragments() -> bool:
	for id in CORE_FRAGMENT_IDS:
		if not _collected.has(id):
			return false
	return true


func get_by_category(category: MemoryData.Category) -> Array[MemoryData]:
	var out: Array[MemoryData] = []
	for memory in _all:
		if _unlocked.has(memory.id) and memory.category == category:
			out.append(memory)
	return out


# ---------------------------------------------------------------------------
# 变更
# ---------------------------------------------------------------------------

## 收集一条记忆。返回是否真的新增（重复收集返回 false）。
func collect(memory_id: StringName) -> bool:
	var memory: MemoryData = _by_id.get(memory_id, null)
	if memory == null:
		push_warning("[MemoryManager] 未知记忆 id: %s" % memory_id)
		return false
	if _collected.has(memory_id):
		return false

	_collected[memory_id] = true
	_unlocked[memory_id] = true
	memory_collected.emit(memory)
	if SaveManager != null:
		SaveManager.mark_dirty()
	return true


## 直接收集一份资源对象（地图里的 MemoryPickup 用它）。
func collect_resource(memory: MemoryData) -> bool:
	if memory == null:
		return false
	return collect(memory.id)


func reset() -> void:
	_collected.clear()
	_unlocked.clear()
	_refresh_unlocked(true)
	memory_reset.emit()


# ---------------------------------------------------------------------------
# 解锁判定
# ---------------------------------------------------------------------------

func _on_flag_changed(_flag: StringName, _value: bool) -> void:
	_refresh_unlocked(false)


## 重新计算哪些条目已经“可见”。已收集的条目永远可见。
func _refresh_unlocked(silent: bool) -> void:
	for memory in _all:
		if _unlocked.has(memory.id):
			continue
		if memory.unlock_condition == &"":
			_unlocked[memory.id] = true
			if not silent:
				memory_unlocked.emit(memory)
			continue
		if _evaluate(memory.unlock_condition):
			_unlocked[memory.id] = true
			if not silent:
				memory_unlocked.emit(memory)


func _evaluate(condition: StringName) -> bool:
	if GameManager == null:
		return false
	return GameManager.evaluate_condition(condition)


# ---------------------------------------------------------------------------
# 存档对接
# ---------------------------------------------------------------------------

func collect_save_data(data: SaveData) -> void:
	var ids := PackedStringArray()
	for id: Variant in _collected.keys():
		ids.append(String(id))
	data.collected_memory_ids = ids


func apply_save_data(data: SaveData) -> void:
	_collected.clear()
	for raw in data.collected_memory_ids:
		_collected[StringName(raw)] = true
	_refresh_unlocked(true)


## 供 HUD 使用的「已收集 / 总数」。
func get_progress_text() -> String:
	return "%d/%d" % [get_collected_count(), maxi(get_core_fragment_total(), get_collected_count())]
