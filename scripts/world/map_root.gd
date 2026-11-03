class_name MapRoot
extends Node2D

## 地图根节点基类（提示词【二十五】）。
##
## 每张地图都是独立 Scene，根节点挂本脚本的派生类（或直接用它）。
## 要求的节点结构（缺哪个都能跑，但建议齐全）：
##
##   MapRoot                 ← 本脚本
##   ├── WorldEnvironment / CanvasModulate
##   ├── Background          ← Parallax2D 层（远 / 中 / 近）
##   ├── Midground
##   ├── Gameplay            ← 地形、平台、静态碰撞
##   ├── Foreground          ← 视差前景（栏杆、枯树）
##   ├── Enemies
##   ├── Interactables       ← 可交互物、NPC、道具
##   ├── Triggers            ← 出口、检查点、剧情触发
##   └── PlayerSpawn         ← 出生点标记（Marker2D，子节点名即 spawn_id）
##
## 地图必须能独立运行：按 F6 直接运行本场景时，如果没有玩家就自己生成一个。

signal player_spawned(player: PlayerController, spawn_id: StringName)
signal area_entered_by_player(area_id: StringName)

## 与 MapRegistry 中注册的 id 对应。留空则由注册表反查。
@export var map_id: StringName = &""
## 玩家场景路径。默认使用通用玩家场景。
@export_file("*.tscn") var player_scene_path: String = "res://scenes/player/Player.tscn"
## 进入本图时是否重新放置玩家（从存档/调试直接进入时为 true）。
@export var auto_spawn_player: bool = true
## 无玩家时的默认出生点 id。
@export var default_spawn_id: StringName = &"default"

var player: PlayerController = null
var current_spawn_id: StringName = &""
## 关卡内容是否已经铺过（防止两条生成路径重复铺）。
var _level_populated: bool = false

@onready var gameplay: Node2D = get_node_or_null("Gameplay") as Node2D
@onready var enemies_root: Node2D = get_node_or_null("Enemies") as Node2D
@onready var interactables_root: Node2D = get_node_or_null("Interactables") as Node2D
@onready var triggers_root: Node2D = get_node_or_null("Triggers") as Node2D


func _ready() -> void:
	add_to_group(&"map")
	AudioManager.enter_area(_resolve_audio_area())

	# 在生成玩家之前先把地形与出生点建好。
	_build_map_geometry()

	# 世界状态变化时，地图外观跟着变（提示词【十】：同一场景必须能改变外观）。
	if WorldStateManager != null:
		WorldStateManager.world_state_changed.connect(_on_world_state_changed)
		_on_world_state_changed(WorldStateManager.current_profile)

	if auto_spawn_player and get_tree().get_nodes_in_group(&"player").is_empty():
		# 独立运行地图场景（F6）时自备一个玩家，保证任何地图都能单跑。
		_spawn_player_for_standalone(default_spawn_id)
		# 这条路径不会经过 place_player_at_spawn，所以要在这里铺内容。
		_populate_level_content()

	_map_ready()


# ---------------------------------------------------------------------------
# 依据 MapData 生成地形
# ---------------------------------------------------------------------------

## 从 MapData 推导出地面、两侧墙、出生点、检查点与出口。
##
## 这样做的好处（见 tools/build_scenes.py 的说明）：地图尺寸、出口、跳转条件
## 只有 data/maps/*.tres 一处真相，.tscn 不需要手写一堆坐标。
## 关卡美术需要在编辑器里手工摆放细节时，把细节放进 Gameplay / Interactables 容器即可，
## 本方法只生成“保证地图可玩”的最小地形。
func _build_map_geometry() -> void:
	var map_data := MapRegistry.get_map(map_id)
	if map_data == null:
		push_warning("[MapRoot] 没有 MapData，跳过地形生成: %s" % map_id)
		return

	var size := Vector2(map_data.map_size)
	if size.x <= 0.0 or size.y <= 0.0:
		size = Vector2(4000.0, 1200.0)

	var ground_thickness := 200.0
	var ground_y := size.y - ground_thickness * 0.5

	# --- 地面 ---
	if gameplay != null and gameplay.get_node_or_null("Ground") == null:
		var ground := StaticBody2D.new()
		ground.name = "Ground"
		ground.position = Vector2(size.x * 0.5, ground_y)
		ground.collision_layer = 1 << 0   # layer 1 = world
		ground.collision_mask = 0
		gameplay.add_child(ground)
		_add_rect_shape(ground, Vector2(size.x, ground_thickness))

	# --- 两侧墙（防止跑出地图）---
	if gameplay != null:
		for side in [["WallLeft", -40.0], ["WallRight", size.x + 40.0]]:
			var wall_name: String = side[0]
			var wall_x: float = side[1]
			if gameplay.get_node_or_null(wall_name) != null:
				continue
			var wall := StaticBody2D.new()
			wall.name = wall_name
			wall.position = Vector2(wall_x, size.y * 0.5)
			wall.collision_layer = 1 << 0
			wall.collision_mask = 0
			gameplay.add_child(wall)
			_add_rect_shape(wall, Vector2(80.0, size.y))

	# --- 出生点 ---
	var spawn_container := _spawn_container()
	var spawn_y := ground_y - 70.0
	var base_x := clampf(size.x * 0.08, 160.0, 420.0)

	if spawn_container.get_node_or_null(String(map_data.default_spawn_id)) == null:
		_add_spawn_marker(spawn_container, map_data.default_spawn_id, Vector2(base_x, spawn_y))

	# 每个出口目标都保证有一个对应出生点，否则从那张图回来时会落错位置。
	var exit_links := map_data.get_exit_links()
	var index := 0
	for link in exit_links:
		index += 1
		if spawn_container.get_node_or_null(String(link.target_spawn_id)) != null:
			continue
		var step := size.x / float(maxi(exit_links.size() + 1, 2))
		_add_spawn_marker(
			spawn_container,
			link.target_spawn_id,
			Vector2(base_x + step * float(index), spawn_y)
		)

	# --- 出口 ---
	if triggers_root != null:
		for i in exit_links.size():
			var link := exit_links[i]
			var node_name := "Exit_%s" % String(link.exit_id)
			if triggers_root.get_node_or_null(node_name) != null:
				continue
			var trigger := Area2D.new()
			trigger.name = node_name
			trigger.position = Vector2(
				clampf(size.x * 0.35 + 520.0 * float(i), 200.0, size.x - 120.0),
				ground_y - 110.0
			)
			trigger.set_script(load("res://scripts/world/exit_trigger.gd"))
			trigger.set("exit_id", link.exit_id)
			triggers_root.add_child(trigger)
			_add_rect_shape(trigger, Vector2(64.0, 220.0), true)

	# --- 检查点（每张图一个，放在起点附近）---
	if triggers_root != null and triggers_root.get_node_or_null("CheckpointA") == null:
		var checkpoint := Area2D.new()
		checkpoint.name = "CheckpointA"
		checkpoint.position = Vector2(base_x + 300.0, ground_y - 60.0)
		checkpoint.set_script(load("res://scripts/world/checkpoint.gd"))
		checkpoint.set("spawn_id", default_spawn_id)
		triggers_root.add_child(checkpoint)
		_add_rect_shape(checkpoint, Vector2(72.0, 120.0), true)
		# 给检查点一盏灯，符合「路灯即存档点」的视觉约定。
		var glow := PointLight2D.new()
		glow.name = "PointLight2D"
		glow.color = Color(1.0, 0.78, 0.42)
		glow.energy = 1.1
		glow.texture_scale = 1.6
		checkpoint.add_child(glow)


func _add_rect_shape(parent: Node2D, size: Vector2, is_area: bool = false) -> void:
	var shape_node := CollisionShape2D.new()
	shape_node.name = "CollisionShape2D"
	var rect := RectangleShape2D.new()
	rect.size = size
	shape_node.shape = rect
	parent.add_child(shape_node)
	if is_area:
		var area := parent as Area2D
		if area != null:
			area.collision_layer = 1 << 5   # layer 6 = interactable
			area.collision_mask = 1 << 1    # 检测玩家本体


func _add_spawn_marker(container: Node2D, spawn_id: StringName, position: Vector2) -> void:
	var marker := Marker2D.new()
	marker.name = String(spawn_id)
	marker.position = position
	container.add_child(marker)


## 子类重写它做地图专属初始化（布置蜡像、启动天气等）。
func _map_ready() -> void:
	pass


## 铺关卡内容（敌人、NPC、道具、雾、蜡像、Boss）。
## 只在第一次调用时生效，避免“独立运行”与“从别的地图进入”两条路径重复生成。
func _populate_level_content() -> void:
	if _level_populated:
		return
	_level_populated = true
	var created := LevelLoader.populate(self)
	if created > 0:
		print("[MapRoot] %s 生成了 %d 项关卡内容。" % [map_id, created])


# ---------------------------------------------------------------------------
# 玩家生成与出生点
# ---------------------------------------------------------------------------

## 由 GameManager.change_map 调用。
func place_player_at_spawn(spawn_id: StringName) -> void:
	var marker := _find_spawn_marker(spawn_id)
	if marker == null:
		push_warning("[MapRoot] %s 找不到出生点 %s，退化到第一个出生点。" % [name, spawn_id])
		marker = _find_first_spawn_marker()

	if player == null or not is_instance_valid(player):
		_spawn_player_at(marker, spawn_id)
	else:
		player.global_position = marker.global_position
		player.velocity = Vector2.ZERO
		player.set_facing(1 if marker.scale.x >= 0.0 else -1)
		_on_player_placed(player, spawn_id)

	current_spawn_id = spawn_id

	# 切图后清一次顿帧，避免上一张图的定帧带过来。
	Combat.force_clear_hit_stop()
	await get_tree().process_frame
	player_spawned.emit(player, spawn_id)
	# 铺内容放在最后：此时玩家已经就位，敌人的检测范围不会漏掉玩家。
	_populate_level_content()


func _spawn_player_for_standalone(spawn_id: StringName) -> void:
	var marker := _find_spawn_marker(spawn_id)
	if marker == null:
		marker = _find_first_spawn_marker()
	_spawn_player_at(marker, spawn_id)


func _spawn_player_at(marker: Marker2D, spawn_id: StringName) -> void:
	if not ResourceLoader.exists(player_scene_path):
		push_error("[MapRoot] 玩家场景不存在: %s" % player_scene_path)
		return
	var packed := load(player_scene_path) as PackedScene
	if packed == null:
		push_error("[MapRoot] 玩家场景加载失败: %s" % player_scene_path)
		return

	player = packed.instantiate() as PlayerController
	if player == null:
		push_error("[MapRoot] 玩家场景根节点不是 PlayerController。")
		return

	# 挂在 Interactables 之外的独立父节点，避免被地图逻辑当成可交互物遍历。
	var host := interactables_root.get_parent() if interactables_root != null else self
	host.add_child(player)
	player.global_position = marker.global_position if marker != null else Vector2.ZERO
	if marker != null:
		player.set_facing(1 if marker.scale.x >= 0.0 else -1)

	current_spawn_id = spawn_id
	_connect_player(player)
	_on_player_placed(player, spawn_id)
	player_spawned.emit(player, spawn_id)


func _on_player_placed(_player_node: PlayerController, _spawn_id: StringName) -> void:
	pass


func _connect_player(player_node: PlayerController) -> void:
	player_node.respawn_requested.connect(_on_player_respawn_requested)


func _on_player_respawn_requested() -> void:
	# 真正的换图重生由 death 状态触发 GameManager.respawn_at_checkpoint()；
	# 这里只做地图侧清理，避免重复触发。
	pass


func _find_spawn_marker(spawn_id: StringName) -> Marker2D:
	var container := _spawn_container()
	if container == null:
		return null
	var node := container.get_node_or_null(String(spawn_id))
	return node as Marker2D


func _find_first_spawn_marker() -> Marker2D:
	var container := _spawn_container()
	if container == null:
		return null
	for child in container.get_children():
		if child is Marker2D:
			return child as Marker2D
	# 没有任何 Marker 时兜底造一个，地图依然可用。
	var fallback := Marker2D.new()
	fallback.name = "fallback_spawn"
	container.add_child(fallback)
	return fallback


func _spawn_container() -> Node2D:
	var container := get_node_or_null("PlayerSpawn") as Node2D
	if container == null:
		container = Node2D.new()
		container.name = "PlayerSpawn"
		add_child(container)
	return container


# ---------------------------------------------------------------------------
# 出口
# ---------------------------------------------------------------------------

## 由 ExitTrigger 调用。检查条件并换图。
func use_exit(exit_id: StringName, activator: Node = null) -> bool:
	var map_data := MapRegistry.get_map(map_id)
	if map_data == null:
		return false
	var link := map_data.find_exit(exit_id)
	if link == null:
		push_warning("[MapRoot] 地图 %s 没有出口 %s" % [map_id, exit_id])
		return false

	if not link.condition.is_empty() and not GameManager.evaluate_condition(link.condition):
		if not link.locked_message.is_empty() and activator is PlayerController:
			_show_locked_message(link.locked_message)
		return false

	# 换图前把血量带走，避免“换张图就满血”。
	if player != null and is_instance_valid(player):
		player.persist_health()

	GameManager.change_map(link.target_map_id, link.target_spawn_id)
	return true


func _show_locked_message(message: String) -> void:
	# 用一行临时对白展示“此路不通”的原因，不引入额外 UI。
	var sequence := DialogueSequence.new()
	sequence.id = &"locked_hint"
	var line := DialogueLine.new()
	line.speaker = ""
	line.text = message
	sequence.lines = [line] as Array[DialogueLine]
	DialogueManager.start(sequence)


# ---------------------------------------------------------------------------
# 世界状态响应
# ---------------------------------------------------------------------------

func _on_world_state_changed(profile: WorldStateProfile) -> void:
	if profile == null:
		return
	apply_world_state_profile(profile)


## 地图对世界状态的响应。默认行为：调整天气节点与灯光强度。
## 子类可重写来做更具体的表现（换背景、加火焰粒子等）。
func apply_world_state_profile(profile: WorldStateProfile) -> void:
	# CanvasModulate 由 WorldStateManager 全局处理，这里只处理地图内的可选节点。
	var weather := get_node_or_null("Weather")
	if weather != null:
		weather.visible = profile.weather != &"clear"
		if weather.has_method("apply_weather"):
			weather.call("apply_weather", profile)

	# 灯光强度：给所有属于 &"light" 组的节点统一调整。
	for light_node in get_tree().get_nodes_in_group(&"world_light"):
		if light_node is PointLight2D:
			(light_node as PointLight2D).energy = profile.light_energy


# ---------------------------------------------------------------------------
# 查询
# ---------------------------------------------------------------------------

func _resolve_audio_area() -> StringName:
	var map_data := MapRegistry.get_map(map_id)
	if map_data != null and not map_data.audio_area.is_empty():
		return map_data.audio_area
	return &"Town"


func get_map_display_name() -> String:
	return MapRegistry.get_map_display_name(map_id)


## 供 HUD 显示当前区域名。
func announce_area_name() -> void:
	var hud := get_tree().get_first_node_in_group(&"hud")
	if hud != null and hud.has_method("show_area_name"):
		hud.call("show_area_name", get_map_display_name())
