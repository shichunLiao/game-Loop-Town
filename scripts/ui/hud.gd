extends CanvasLayer

## 战斗 HUD 控制器（生命豆 / 记忆计数 / 道具名 / 互动提示 / 区域名）。
##
## 所有对外方法都是"被别的系统调用"的入口，因此任何一条都做了空值防护：
## 玩家、道具、地图触发器可以在任意时机调用它们而不会让 HUD 崩掉。

## 生命豆数量（100 点生命 / 20 点一颗）。
const PIP_COUNT: int = 5
## 满血量默认值，仅用于没有其他信息时的兜底。
const DEFAULT_MAX_HEALTH: int = 100
## 生命豆贴图（由美术并行产出，可能不存在）。
const PIP_FULL_PATH: String = "res://assets/ui/hp_pip_full.png"
const PIP_EMPTY_PATH: String = "res://assets/ui/hp_pip_empty.png"
## 贴图缺失时的兜底颜色。
const PIP_FALLBACK_FULL: Color = Color(0.85, 0.26, 0.30, 1.0)
const PIP_FALLBACK_EMPTY: Color = Color(0.22, 0.20, 0.25, 0.85)
## 单颗生命豆尺寸。
const PIP_SIZE: Vector2 = Vector2(22.0, 22.0)
## 记忆计数文案。
const MEMORY_TEXT_FORMAT: String = "记忆  %d/%d"
## 记忆总数兜底值（场景默认显示 0/7）。
const FALLBACK_MEMORY_TOTAL: int = 7
## 道具槽为空时的占位符。
const ITEM_EMPTY_TEXT: String = "—"
## 区域名停留时长（秒）。
const AREA_NAME_HOLD_SECONDS: float = 2.0
## 区域名淡入淡出时长（秒）。
const AREA_NAME_FADE_SECONDS: float = 0.45

@onready var pips: HBoxContainer = $Root/HPBar/Pips
@onready var memory_label: Label = $Root/MemoryCounter/MemoryLabel
@onready var item_label: Label = $Root/ItemSlot/ItemLabel
@onready var interact_prompt: Label = $Root/InteractPrompt
@onready var area_name_label: Label = $Root/AreaName

var _full_texture: Texture2D = null
var _empty_texture: Texture2D = null
var _pip_textures: Array[TextureRect] = []
var _pip_blocks: Array[ColorRect] = []
var _health: int = DEFAULT_MAX_HEALTH
var _max_health: int = DEFAULT_MAX_HEALTH
var _memory_collected: int = 0
var _memory_total: int = FALLBACK_MEMORY_TOTAL
var _area_name_tween: Tween = null


func _ready() -> void:
	if interact_prompt != null:
		# 互动提示永远不参与鼠标拾取。
		interact_prompt.visible = false
		interact_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_load_pip_textures()
	_build_pips()
	_connect_signals()

	var health: int = DEFAULT_MAX_HEALTH
	var max_health: int = DEFAULT_MAX_HEALTH
	if SaveManager != null:
		health = SaveManager.get_player_health()
		max_health = SaveManager.get_player_max_health()
	set_health(health, max_health)

	_memory_total = _resolve_memory_total()
	set_memory_count(_resolve_memory_collected(), _memory_total)
	set_item_name("")


# ---------------------------------------------------------------------------
# 公开接口
# ---------------------------------------------------------------------------

## 刷新生命豆。`current` 会被夹在 0..`maximum` 之间。
func set_health(current: int, maximum: int) -> void:
	_max_health = maxi(maximum, 1)
	_health = clampi(current, 0, _max_health)
	_refresh_pips()


## 刷新记忆计数。格式固定为 "记忆  %d/%d"。
func set_memory_count(collected: int, total: int) -> void:
	_memory_collected = maxi(collected, 0)
	_memory_total = maxi(total, 0)
	if memory_label != null:
		memory_label.text = MEMORY_TEXT_FORMAT % [_memory_collected, _memory_total]


## 刷新当前持有的道具名。空字符串显示占位符。
func set_item_name(item_name: String) -> void:
	if item_label == null:
		return
	var trimmed: String = item_name.strip_edges()
	item_label.text = ITEM_EMPTY_TEXT if trimmed.is_empty() else trimmed


## 显示互动提示（例如 "E  交谈"）。
func show_interact_prompt(text: String) -> void:
	if interact_prompt == null:
		return
	interact_prompt.text = text
	interact_prompt.visible = not text.strip_edges().is_empty()


## 隐藏互动提示。
func hide_interact_prompt() -> void:
	if interact_prompt == null:
		return
	interact_prompt.text = ""
	interact_prompt.visible = false


## 显示区域名：淡入 → 停留约 2 秒 → 淡出。
func show_area_name(area_name: String) -> void:
	if area_name_label == null:
		return
	area_name_label.text = area_name
	if _area_name_tween != null and _area_name_tween.is_valid():
		_area_name_tween.kill()
	area_name_label.modulate.a = 0.0
	_area_name_tween = create_tween()
	_area_name_tween.tween_property(area_name_label, "modulate:a", 1.0, AREA_NAME_FADE_SECONDS)
	_area_name_tween.tween_interval(AREA_NAME_HOLD_SECONDS)
	_area_name_tween.tween_property(area_name_label, "modulate:a", 0.0, AREA_NAME_FADE_SECONDS)


## 当前生命值（只读用途）。
func get_health() -> int:
	return _health


## 当前最大生命值（只读用途）。
func get_max_health() -> int:
	return _max_health


# ---------------------------------------------------------------------------
# 内部：构建
# ---------------------------------------------------------------------------

func _load_pip_textures() -> void:
	# 贴图由美术并行产出，存在才加载；否则走 ColorRect 兜底。
	if ResourceLoader.exists(PIP_FULL_PATH):
		_full_texture = load(PIP_FULL_PATH) as Texture2D
	if ResourceLoader.exists(PIP_EMPTY_PATH):
		_empty_texture = load(PIP_EMPTY_PATH) as Texture2D


func _build_pips() -> void:
	if pips == null:
		return
	for child in pips.get_children():
		pips.remove_child(child)
		child.queue_free()
	_pip_textures.clear()
	_pip_blocks.clear()

	var use_textures: bool = _full_texture != null or _empty_texture != null
	for index in range(PIP_COUNT):
		if use_textures:
			var pip := TextureRect.new()
			pip.name = "Pip%d" % index
			pip.custom_minimum_size = PIP_SIZE
			pip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			pip.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			pip.texture = _empty_texture
			pips.add_child(pip)
			_pip_textures.append(pip)
		else:
			var block := ColorRect.new()
			block.name = "Pip%d" % index
			block.custom_minimum_size = PIP_SIZE
			block.color = PIP_FALLBACK_EMPTY
			block.mouse_filter = Control.MOUSE_FILTER_IGNORE
			pips.add_child(block)
			_pip_blocks.append(block)


func _connect_signals() -> void:
	if MemoryManager != null:
		MemoryManager.memory_collected.connect(_on_memory_collected)
		MemoryManager.memory_reset.connect(_on_memory_reset)
	if LoopManager != null:
		# 循环推进本身不清空记忆，但重新读一次计数可以兜住任何遗漏的广播。
		LoopManager.loop_advanced.connect(_on_loop_advanced)


func _refresh_pips() -> void:
	var segment: float = float(_max_health) / float(PIP_COUNT)
	for index in range(_pip_textures.size()):
		var filled: bool = float(_health) > segment * float(index)
		var texture: Texture2D = _empty_texture
		if filled and _full_texture != null:
			texture = _full_texture
		_pip_textures[index].texture = texture
	for index in range(_pip_blocks.size()):
		var block_filled: bool = float(_health) > segment * float(index)
		_pip_blocks[index].color = PIP_FALLBACK_FULL if block_filled else PIP_FALLBACK_EMPTY


func _resolve_memory_collected() -> int:
	if MemoryManager == null:
		return 0
	return MemoryManager.get_collected_count()


func _resolve_memory_total() -> int:
	var total: int = 0
	if MemoryManager != null:
		total = maxi(MemoryManager.get_all_definitions().size(), MemoryManager.get_core_fragment_total())
	if total <= 0:
		total = FALLBACK_MEMORY_TOTAL
	return total


# ---------------------------------------------------------------------------
# 内部：信号回调
# ---------------------------------------------------------------------------

func _on_memory_collected(_memory: MemoryData) -> void:
	# 不依赖 HUD 自己知道总数：谁调用过 set_memory_count，总数就听谁的。
	set_memory_count(_resolve_memory_collected(), _memory_total)


func _on_memory_reset() -> void:
	set_memory_count(0, _memory_total)


func _on_loop_advanced(_new_count: int) -> void:
	set_memory_count(_resolve_memory_collected(), _memory_total)
