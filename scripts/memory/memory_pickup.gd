class_name MemoryPickup
extends InteractableBase

## 记忆碎片拾取物（提示词【三十一】）。
##
## 玩家拾取后：触发笔记本动画（由 HUD / Notebook 响应 memory_collected 信号），
## 记忆自动进入笔记本。本节点只负责“把这条记忆交给 MemoryManager”。

## 要交给玩家的记忆。直接引用资源，避免路径字符串写错。
@export var memory: MemoryData = null
## 也可以只写 id，从 data/memories/ 里加载（便于地图里批量摆放）。
@export var memory_id: StringName = &""
## 拾取后是否自动打开笔记本。
@export var open_notebook: bool = true
## 是否播放拾取特效。
@export var play_effect: bool = true

@onready var _sprite: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D


func _interactable_ready() -> void:
	interact_prompt = "拾取"
	sfx = "pickup"
	if memory != null:
		memory_id = memory.id
	_refresh_visual()


func _on_interacted(_player: Node) -> void:
	var target_memory := _resolve_memory()
	if target_memory == null:
		push_warning("[MemoryPickup] 没有可拾取的记忆（id=%s）。" % memory_id)
		return

	var collected := MemoryManager.collect_resource(target_memory)
	if not collected:
		# 已经拿过了：不再重复弹笔记本。
		return

	if play_effect:
		_spawn_pickup_effect()
	AudioManager.play_sfx("notebook_open")

	if open_notebook:
		var notebook := get_tree().get_first_node_in_group(&"notebook_ui")
		if notebook != null and notebook.has_method("open_for_memory"):
			notebook.call("open_for_memory", target_memory.id)

	# 拾取后从场景里消失。
	visible = false
	set_deferred("monitorable", false)
	queue_free()


func _resolve_memory() -> MemoryData:
	if memory != null:
		return memory
	if memory_id == &"":
		return null
	# 先按 id 从已加载的记忆里找，避免路径拼错。
	var found := MemoryManager.get_memory(memory_id)
	if found != null:
		return found
	var path := "res://data/memories/%s.tres" % String(memory_id)
	if ResourceLoader.exists(path):
		return load(path) as MemoryData
	return null


func _refresh_visual() -> void:
	if _sprite != null:
		_sprite.modulate = Color(1.0, 0.92, 0.72)


func _spawn_pickup_effect() -> void:
	var effect := HitEffect.spawn(get_parent(), global_position, Vector2.UP)
	if effect != null:
		effect.z_index = 30
