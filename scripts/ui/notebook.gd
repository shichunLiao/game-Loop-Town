extends CanvasLayer

## 笔记本（线索本）控制器 —— 提示词【八】【三十一】。
##
## 关键约束：**绝不显示 `MemoryData.double_meaning`**，那是开发者专用字段。
## 玩家在笔记本里读到的永远只有 `MemoryData.text` 这一版文本。
##
## 【实现方案说明 · 必读】
## 需求给了两条路线，本脚本采用第一条（运行时插入第二个 ItemList）：
##   - `Categories`（场景里的 ItemList）只负责列出**分类**；
##   - 脚本在 `_ready()` 里 `ItemList.new()` 出 `Entries`，插入 `Categories`
##     的父容器（`Book/HBox/LeftPage/CategoryList` 这个 VBoxContainer），
##     用来列出当前分类下的**条目**。
##   选它的理由：不需要修改 .tscn，也不需要自己在 `_unhandled_input` 里
##   手工维护条目游标，方向键 / 鼠标选择交给 ItemList 自己处理。
##   若极端情况下拿不到父容器（理论不会发生），退化为"只显示第一条"的
##   只读模式，不崩。

## 打开 / 关闭笔记本的动作名。
const OPEN_ACTION: StringName = &"open_notebook"
## Esc：关闭笔记本。
const CLOSE_ACTION: StringName = &"pause"
## 正在接管输入的全屏覆盖层都会加入这个组（暂停菜单据此避让）。
const MODAL_OVERLAY_GROUP: StringName = &"ui_modal_overlay"
## 一条记忆都没有时的提示。
const EMPTY_HINT_TEXT: String = "笔记本还是空白的。"
## 右侧页面为空时的占位标题。
const EMPTY_TITLE: String = "—"

@onready var categories: ItemList = $Book/HBox/LeftPage/CategoryList/Categories
@onready var entry_title: Label = $Book/HBox/RightPage/VBox/EntryTitle
@onready var entry_speaker: Label = $Book/HBox/RightPage/VBox/EntrySpeaker
@onready var entry_text: Label = $Book/HBox/RightPage/VBox/Scroll/EntryText
@onready var empty_hint: Label = $Book/HBox/RightPage/VBox/EmptyHint
@onready var close_button: Button = $Close

## 运行时插入的条目列表（见文件头的方案说明）。
var _entries_list: ItemList = null
## 与 `categories` 行号一一对应的分类枚举值。
var _all_categories: Array[int] = []
## 当前分类下的条目。
var _entries: Array[MemoryData] = []
## 当前选中的分类在 `_all_categories` 里的下标，-1 表示未选。
var _current_category: int = -1
## 刚收集到、等下次打开笔记本时自动跳转的分类枚举值，-1 表示没有。
var _pending_category: int = -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	if empty_hint != null:
		empty_hint.text = EMPTY_HINT_TEXT

	_build_entries_list()
	_connect_signals()
	rebuild()


func _unhandled_input(event: InputEvent) -> void:
	var wants_open: bool = event.is_action_pressed(OPEN_ACTION)
	var wants_close: bool = event.is_action_pressed(CLOSE_ACTION)

	if not visible:
		if not wants_open or _is_blocked_by_other_ui():
			return
		open()
		get_viewport().set_input_as_handled()
		return

	if wants_open or wants_close:
		close()
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------------------
# 公开接口
# ---------------------------------------------------------------------------

## 笔记本当前是否展开。
func is_open() -> bool:
	return visible


## 打开笔记本：重建列表、跳到待选分类、暂停游戏。
func open() -> void:
	rebuild()
	if _pending_category >= 0:
		var index: int = _index_of_category(_pending_category)
		_pending_category = -1
		if index >= 0:
			_select_category(index, 0)
	visible = true
	add_to_group(MODAL_OVERLAY_GROUP)
	if GameManager != null:
		GameManager.set_paused(true)
	if close_button != null:
		close_button.grab_focus()


## 关闭笔记本并解除暂停。
func close() -> void:
	visible = false
	remove_from_group(MODAL_OVERLAY_GROUP)
	if GameManager != null:
		GameManager.set_paused(false)


## 开关切换。
func toggle() -> void:
	if visible:
		close()
	else:
		open()


## 依据 MemoryManager 的当前状态重建分类 / 条目列表。
##
## 剧透保护（重要）：
##   1. 只显示**已经拥有可见条目**的分类。空白分类一律不出现，
##      否则玩家会在第一章就看到「小铃」这个分类名，等于提前被告知谜底。
##   2. 「小铃」分类在第五章之前显示为未命名的「？？？」，因为主角此刻
##      还不知道这个名字意味着什么（提示词【八】：不要把真相直接告诉玩家）。
##   3. 同理，「结局」分类要到结局阶段才出现。
func rebuild() -> void:
	if categories == null:
		return
	_all_categories.clear()
	categories.clear()

	var visible_categories := _visible_categories()
	for category: int in visible_categories:
		_all_categories.append(category)
		categories.add_item(_display_category_label(category))

	_update_empty_hint()

	if _all_categories.is_empty():
		_clear_right_page()
		return
	var wanted: int = _current_category if _current_category >= 0 and _current_category < _all_categories.size() else 0
	_select_category(wanted, 0)


## 只保留有可见条目的分类。
func _visible_categories() -> Array[int]:
	var out: Array[int] = []
	for raw: Variant in MemoryData.category_order():
		var category: int = int(raw)
		if MemoryManager.get_by_category(category as MemoryData.Category).is_empty():
			continue
		out.append(category)
	return out


## 分类在笔记本上显示的名字。
## 「小铃」与「结局」在剧情到达之前不给名字 —— 这本身就是叙事的一部分。
func _display_category_label(category: int) -> String:
	if category == int(MemoryData.Category.Suzu):
		# 第五章之后主角才认得这个名字。
		if not GameManager.is_chapter_cleared(5):
			return "？？？"
	if category == int(MemoryData.Category.ENDING):
		if not GameManager.is_chapter_cleared(5):
			return "？？？"
	return _category_label(category)


## 直接跳到某个分类（枚举值）。
func select_category(category: int) -> void:
	var index: int = _index_of_category(category)
	if index >= 0:
		_select_category(index, 0)


# ---------------------------------------------------------------------------
# 内部：构建
# ---------------------------------------------------------------------------

## 运行时创建"条目" ItemList，插入 Categories 的父容器。见文件头说明。
func _build_entries_list() -> void:
	if categories == null:
		return
	var parent: Node = categories.get_parent()
	if parent == null:
		push_warning("[Notebook] Categories 没有父节点，条目列表退化为只读模式。")
		return

	_entries_list = ItemList.new()
	_entries_list.name = "Entries"
	_entries_list.custom_minimum_size = Vector2(0.0, 180.0)
	_entries_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_entries_list.item_selected.connect(_on_entry_selected)
	parent.add_child(_entries_list)


func _connect_signals() -> void:
	if categories != null:
		categories.item_selected.connect(_on_category_selected)
	if close_button != null:
		close_button.pressed.connect(close)
	if MemoryManager != null:
		MemoryManager.memory_collected.connect(_on_memory_collected)
		MemoryManager.memory_reset.connect(_on_memory_reset)


## 分类枚举值 -> 中文标签。直接问 MemoryData，保证与枚举定义完全一致。
func _category_label(category: int) -> String:
	var probe: MemoryData = MemoryData.new()
	# 枚举在 GDScript 里就是 int，这里用 set() 避免 int/enum 的静态类型摩擦。
	probe.set(&"category", category)
	return probe.get_category_label()


func _entry_label(memory: MemoryData) -> String:
	var title: String = memory.title.strip_edges()
	if not title.is_empty():
		return title
	return String(memory.id)


func _index_of_category(category: int) -> int:
	for index in range(_all_categories.size()):
		if _all_categories[index] == category:
			return index
	return -1


# ---------------------------------------------------------------------------
# 内部：填充
# ---------------------------------------------------------------------------

func _select_category(index: int, entry_index: int) -> void:
	if index < 0 or index >= _all_categories.size():
		return
	_current_category = index
	if categories != null:
		categories.select(index)

	var memories: Array[MemoryData] = []
	if MemoryManager != null:
		memories = MemoryManager.get_by_category(_all_categories[index])
	_entries = memories

	if _entries_list != null:
		_entries_list.clear()
		for memory in _entries:
			_entries_list.add_item(_entry_label(memory))

	if _entries.is_empty():
		_clear_right_page()
		_update_empty_hint()
		return

	var clamped: int = clampi(entry_index, 0, _entries.size() - 1)
	if _entries_list != null:
		_entries_list.select(clamped)
	_show_entry(clamped)
	_update_empty_hint()


func _show_entry(index: int) -> void:
	if index < 0 or index >= _entries.size():
		return
	var memory: MemoryData = _entries[index]

	if entry_title != null:
		entry_title.text = _entry_label(memory)

	if entry_speaker != null:
		var speaker: String = memory.speaker.strip_edges()
		entry_speaker.text = ("—— %s" % speaker) if not speaker.is_empty() else ""

	if entry_text != null:
		# 只给玩家看 memory.text 这一版；double_meaning 是开发者字段，绝不显示。
		entry_text.text = memory.text


## 选中某一个 id 的条目（刚收集到的记忆用它定位）。
func _select_entry_by_id(memory_id: StringName) -> void:
	for index in range(_entries.size()):
		if _entries[index].id == memory_id:
			if _entries_list != null:
				_entries_list.select(index)
			_show_entry(index)
			return


func _clear_right_page() -> void:
	if entry_title != null:
		entry_title.text = EMPTY_TITLE
	if entry_speaker != null:
		entry_speaker.text = ""
	if entry_text != null:
		entry_text.text = ""
	if _entries_list != null:
		_entries_list.clear()


func _update_empty_hint() -> void:
	if empty_hint == null:
		return
	var collected: int = MemoryManager.get_collected_count() if MemoryManager != null else 0
	empty_hint.text = EMPTY_HINT_TEXT
	empty_hint.visible = collected == 0


func _is_blocked_by_other_ui() -> bool:
	# 对话中不叠笔记本。
	if DialogueManager != null and DialogueManager.is_active:
		return true
	# 暂停菜单开着的时候也不叠（它的"暂停"不是笔记本的"暂停"）。
	if GameManager != null and GameManager.is_paused:
		return true
	return false


# ---------------------------------------------------------------------------
# 内部：回调
# ---------------------------------------------------------------------------

func _on_category_selected(index: int) -> void:
	_select_category(index, 0)


func _on_entry_selected(index: int) -> void:
	_show_entry(index)


func _on_memory_collected(memory: MemoryData) -> void:
	if memory == null:
		return
	var category: int = int(memory.category)
	if visible:
		var index: int = _index_of_category(category)
		if index >= 0:
			rebuild()
			_select_category(index, 0)
			_select_entry_by_id(memory.id)
		return
	# 记下来，等玩家下次打开笔记本时自动跳过去。
	_pending_category = category


func _on_memory_reset() -> void:
	if visible:
		rebuild()
