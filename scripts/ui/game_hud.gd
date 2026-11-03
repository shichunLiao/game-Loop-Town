class_name GameHUD
extends Node

## 游戏内 UI 容器 + 全局输入分发。
##
## 为什么要有这一层：HUD / 暂停菜单 / 笔记本 / 对话框都是独立的 CanvasLayer 场景，
## 但项目中必须有**一个**地方负责：
##   1. 在启动时把它们都挂上（否则玩家看不到血条、按 Esc 没反应）
##   2. 处理“同一帧里谁能吃这个输入”（笔记本 > 暂停 > 战斗）
## 把这些判断集中在 GameHUD，各个 UI 就只需要管自己那部分。

const HUD_SCENE := "res://scenes/ui/HUD.tscn"
const PAUSE_SCENE := "res://scenes/ui/PauseMenu.tscn"
const NOTEBOOK_SCENE := "res://scenes/ui/Notebook.tscn"
const DIALOGUE_SCENE := "res://scenes/ui/DialogueBox.tscn"

var hud: CanvasLayer = null
var pause_menu: CanvasLayer = null
var notebook: CanvasLayer = null
var dialogue_box: CanvasLayer = null

var _screen: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"game_hud")

	_screen = get_tree().current_scene
	if _screen == null:
		_screen = get_tree().root

	_instantiate_ui()


func _instantiate_ui() -> void:
	hud = _add_ui(HUD_SCENE, "HUD")
	pause_menu = _add_ui(PAUSE_SCENE, "PauseMenu")
	notebook = _add_ui(NOTEBOOK_SCENE, "Notebook")
	dialogue_box = _add_ui(DIALOGUE_SCENE, "DialogueBox")

	# 血量与记忆数的初始显示。
	if hud != null:
		var health := SaveManager.get_player_health()
		var maximum := SaveManager.get_player_max_health()
		if maximum <= 0:
			maximum = 100
			health = 100
		hud.call("set_health", health, maximum)
		hud.call("set_memory_count", MemoryManager.get_collected_count(), _memory_total())
		# 传送到区域名。
		var map_node := get_tree().get_first_node_in_group(&"map")
		if map_node != null and map_node.has_method("get_map_display_name"):
			hud.call("show_area_name", str(map_node.call("get_map_display_name")))


func _add_ui(scene_path: String, node_name: String) -> CanvasLayer:
	if not ResourceLoader.exists(scene_path):
		push_warning("[GameHUD] UI 场景缺失: %s" % scene_path)
		return null
	var packed := load(scene_path) as PackedScene
	if packed == null:
		return null
	var instance := packed.instantiate() as CanvasLayer
	if instance == null:
		push_warning("[GameHUD] %s 的根节点不是 CanvasLayer。" % scene_path)
		return null
	instance.name = node_name
	_screen.add_child(instance)
	return instance


func _memory_total() -> int:
	var total := MemoryManager.get_core_fragment_total()
	var definitions := MemoryManager.get_all_definitions().size()
	return maxi(total, definitions)


## 记忆总数（供 HUD 使用）。
func get_memory_total() -> int:
	return _memory_total()


# ---------------------------------------------------------------------------
# 全局输入
# ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return

	# 优先级：对话 > 笔记本 > 暂停。对话进行中 Esc 由 DialogueBox 处理。
	if DialogueManager != null and DialogueManager.is_active:
		return

	if event.is_action(&"open_notebook"):
		# 笔记本自己判断能不能开（对话中 / 已暂停时不开）。
		if notebook != null and notebook.has_method("toggle"):
			notebook.call("toggle")
			get_viewport().set_input_as_handled()
		return

	if event.is_action(&"pause"):
		if notebook != null and notebook.has_method("is_open") and bool(notebook.call("is_open")):
			# 笔记本打开时 Esc 属于笔记本。
			return
		GameManager.toggle_pause()
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------------------
# 便捷接口（给玩家 / 地图调用，避免它们直接去找 UI 节点）
# ---------------------------------------------------------------------------

func set_health(current: int, maximum: int) -> void:
	if hud != null:
		hud.call("set_health", current, maximum)


func show_interact_prompt(text: String) -> void:
	if hud == null:
		return
	if text.is_empty():
		hud.call("hide_interact_prompt")
	else:
		hud.call("show_interact_prompt", text)


func show_area_name(area_name: String) -> void:
	if hud != null:
		hud.call("show_area_name", area_name)


func show_item_name(item_name: String) -> void:
	if hud != null:
		hud.call("set_item_name", item_name)


func refresh_memory_count() -> void:
	if hud != null:
		hud.call("set_memory_count", MemoryManager.get_collected_count(), _memory_total())
