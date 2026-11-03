class_name LevelLoader
extends RefCounted

## 关卡内容加载器。
##
## 读取 data/levels/<map_id>.json（由 tools/build_chapter1.py 生成），
## 并用 ActorFactory / 各系统脚本把内容实例化到地图里。
##
## 为什么用 JSON + 运行时装配，而不是把内容写进 .tscn：
## 敌人需要 Body + Sprite + HurtBox + DetectionArea + StateMachine + 状态子节点，
## 几十个位置手写一遍必然漏东西。这里只有**一条装配路径**，
## 所以“所有敌人都一定有血条”这件事是结构性保证，而不是靠人检查。
##
## 若地图没有对应的 JSON，本加载器安静跳过 —— 地图依然可玩（只是空）。

const LEVEL_DIR := "res://data/levels"
const ENV_DIR := "res://data/assets/environments"
const ACTOR_DIR := "res://data/assets/actors"

## 创建出来的内容节点统一挂到这个组，便于 QA 统计与清理。
const CONTENT_GROUP := &"level_content"

## 资源定义缓存：id -> ActorDefinition
static var _actor_cache: Dictionary = {}


## 取一个角色的资源定义。资源库是「长什么样」的唯一真相。
static func get_actor_definition(actor_id: StringName) -> ActorDefinition:
	if _actor_cache.has(actor_id):
		return _actor_cache[actor_id]
	var path := "%s/%s.tres" % [ACTOR_DIR, String(actor_id)]
	var definition: ActorDefinition = null
	if ResourceLoader.exists(path):
		definition = load(path) as ActorDefinition
	if definition == null:
		push_warning("[LevelLoader] 角色资源定义缺失: %s" % path)
	_actor_cache[actor_id] = definition
	return definition


## 把 level JSON 里的内容铺进地图。
## [param map] 需要提供 gameplay / enemies_root / interactables_root / triggers_root。
static func populate(map: MapRoot) -> int:
	if map == null or map.map_id == &"":
		return 0

	var path := "%s/%s.json" % [LEVEL_DIR, String(map.map_id)]
	if not ResourceLoader.exists(path):
		# 该地图还没有内容数据：不是错误。
		return 0

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("[LevelLoader] 无法读取关卡数据: %s" % path)
		return 0
	var text := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_error("[LevelLoader] 关卡数据不是合法 JSON: %s" % path)
		return 0

	var data: Dictionary = parsed
	var items: Array = data.get("items", [])
	var created := 0
	for item: Variant in items:
		if not (item is Dictionary):
			continue
		if _spawn_item(map, item as Dictionary) != null:
			created += 1
	return created


static func _spawn_item(map: MapRoot, item: Dictionary) -> Node:
	var kind := str(item.get("kind", ""))
	var position := Vector2(float(item.get("x", 0.0)), float(item.get("y", 0.0)))

	match kind:
		"fog":
			return _spawn_fog(map, item, position)
		"parallax":
			return _spawn_parallax(map, item, position)
		"townsman":
			return _spawn_townsman(map, item, position)
		"wax_dummy":
			return _spawn_wax_dummy(map, item, position)
		"statue_row":
			return _spawn_statue_row(map, item)
		"wax_director":
			return _spawn_wax_director(map, item)
		"memory_pickup":
			return _spawn_memory_pickup(map, item, position)
		"signboard":
			return _spawn_signboard(map, item, position)
		"morris":
			return _spawn_morris(map, item, position)
		"furnace":
			return _spawn_furnace(map, item, position)
		"arena_gate":
			return _spawn_arena_gate(map, item, position)
		"mirror_puzzle":
			return _spawn_mirror_puzzle(map, item, position)
		_:
			push_warning("[LevelLoader] 未知的内容类型: %s" % kind)
			return null


# ---------------------------------------------------------------------------
# 环境
# ---------------------------------------------------------------------------

## 取一张地图的环境层定义。
static func _get_environment_definition(map_id: StringName) -> EnvironmentDefinition:
	var path := "%s/%s.tres" % [ENV_DIR, String(map_id)]
	if not ResourceLoader.exists(path):
		return null
	return load(path) as EnvironmentDefinition


static func _host_for_environment(map: MapRoot) -> Node:
	# 背景 / 雾挂在 Gameplay 之前的层，保证渲染顺序在角色之后。
	return map.get_node_or_null("Midground") if map.get_node_or_null("Midground") != null else map


static func _spawn_fog(map: MapRoot, item: Dictionary, position: Vector2) -> Node:
	var fog := FogLayer.new()
	fog.name = "Fog"
	fog.position = position
	fog.band_count = int(item.get("bands", 5))
	fog.base_alpha = float(item.get("alpha", 0.16))
	var coverage: Array = item.get("coverage", [3000, 700])
	if coverage.size() >= 2:
		fog.coverage = Vector2(float(coverage[0]), float(coverage[1]))
	fog.add_to_group(CONTENT_GROUP)
	var host := _host_for_environment(map)
	host.add_child(fog)
	return fog


static func _spawn_parallax(map: MapRoot, item: Dictionary, position: Vector2) -> Node:
	# 优先使用资源库里的环境层定义（data/assets/environments/<map>.tres）：
	# 那是「这张图用哪几张背景、视差系数多少」的唯一真相，美术在编辑器里能直接看到。
	# 关卡 JSON 里的 layers 只作为回退，避免新地图还没写定义时背景消失。
	var layers: Array = []
	var definition := _get_environment_definition(map.map_id)
	if definition != null:
		for layer in definition.valid_layers():
			layers.append([
				layer.texture_path, layer.scroll_scale, layer.offset_y, layer.modulate_a
			])
	if layers.is_empty():
		layers = item.get("layers", [])
	if layers.is_empty():
		return null

	var root_node := Node2D.new()
	root_node.name = "Parallax"
	root_node.position = position

	for index in layers.size():
		var spec: Variant = layers[index]
		if not (spec is Array) or (spec as Array).size() < 2:
			continue
		var texture_path := str(spec[0])
		var scroll_scale := float(spec[1])
		var offset_y := float(spec[2]) if (spec as Array).size() > 2 else 0.0
		var alpha := float(spec[3]) if (spec as Array).size() > 3 else 1.0

		if not ResourceLoader.exists(texture_path):
			continue
		var texture := load(texture_path) as Texture2D
		if texture == null:
			continue

		# Parallax2D（Godot 4.3+ 原生节点）负责相机联动，里面放一个不居中的 Sprite2D。
		var parallax := Parallax2D.new()
		parallax.name = "Layer%d" % index
		parallax.scroll_scale = Vector2(scroll_scale, 1.0)
		parallax.position = Vector2(0.0, offset_y)
		parallax.repeat_size = Vector2(texture.get_width(), 0.0)
		parallax.repeat_times = 8
		root_node.add_child(parallax)

		var sprite := Sprite2D.new()
		sprite.name = "Sprite"
		sprite.texture = texture
		sprite.centered = false
		sprite.modulate = Color(1.0, 1.0, 1.0, alpha)
		parallax.add_child(sprite)

	if root_node.get_child_count() == 0:
		root_node.queue_free()
		return null

	root_node.add_to_group(CONTENT_GROUP)
	var host := _host_for_environment(map)
	host.add_child(root_node)
	return root_node


# ---------------------------------------------------------------------------
# 角色
# ---------------------------------------------------------------------------

static func _host_for_actors(map: MapRoot) -> Node:
	return map.enemies_root if map.enemies_root != null else map


static func _host_for_interactables(map: MapRoot) -> Node:
	return map.interactables_root if map.interactables_root != null else map


static func _spawn_townsman(map: MapRoot, item: Dictionary, position: Vector2) -> Node:
	var actor := Townsman.new()
	actor.name = "Townsman"
	_configure_npc(actor, position)
	actor.mood = int(item.get("mood", 0)) as Townsman.Mood
	actor.dialogue_path = str(item.get("dialogue", ""))
	actor.interact_prompt = "交谈" if not actor.dialogue_path.is_empty() else ""
	actor.add_to_group(CONTENT_GROUP)
	_host_for_actors(map).add_child(actor)
	return actor


static func _configure_npc(actor: Townsman, position: Vector2) -> void:
	# 这里复刻 ActorFactory 的装配路径。之所以不直接调用工厂：
	# 工厂返回的是配置好的实例，而这里需要控制实例的创建与命名，
	# 但装配逻辑共用同一组私有方法会破坏封装，因此宁愿显式写清楚。
	ActorFactory._configure_body(actor, Vector2(28.0, 54.0))
	ActorFactory._attach_sprite(actor, ActorFactory._townsman_animations(), &"task", Vector2(0.0, -31.0))
	ActorFactory._attach_health(actor, 40, false)
	ActorFactory._attach_hurt_box(actor, Vector2(0.0, -27.0), 14.0, 50.0)
	ActorFactory._attach_hit_box(actor, Vector2(28.0, -28.0), Vector2(46.0, 32.0))
	ActorFactory._attach_detection(actor, 300.0)
	ActorFactory._attach_states(actor, ActorFactory.TOWNSMAN_STATES, &"task")
	actor.position = position


static func _spawn_wax_dummy(map: MapRoot, item: Dictionary, position: Vector2) -> Node:
	var actor := ActorFactory.make_wax_dummy(
		position,
		int(item.get("variant", 0)),
		float(item.get("detection", 280.0)),
		float(item.get("patrol", 70.0))
	)
	actor.add_to_group(CONTENT_GROUP)
	_host_for_actors(map).add_child(actor)
	return actor


static func _spawn_statue_row(map: MapRoot, item: Dictionary) -> Node:
	var row := Node2D.new()
	row.name = "StatueRow"
	var count := int(item.get("count", 6))
	var spacing := float(item.get("spacing", 320))
	var start_x := float(item.get("x", 0.0))
	var y := float(item.get("y", 0.0))

	for i in count:
		var statue := WaxStatue.new()
		statue.name = "Statue%d" % (i + 1)
		statue.position = Vector2(start_x + spacing * float(i), y)
		statue.pose_index = i % 3
		row.add_child(statue)

	row.add_to_group(CONTENT_GROUP)
	_host_for_interactables(map).add_child(row)
	return row


static func _spawn_wax_director(map: MapRoot, item: Dictionary) -> Node:
	var director := WaxLaneDirector.new()
	director.name = "WaxLaneDirector"
	director.ambush_after_triggers = int(item.get("ambush_after", 3))
	director.ambush_statue_count = int(item.get("ambush_count", 4))
	var triggers: Array = item.get("trigger_positions", [])
	var packed := PackedFloat32Array()
	for value: Variant in triggers:
		packed.append(float(value))
	director.trigger_positions = packed
	director.add_to_group(CONTENT_GROUP)
	map.add_child(director)
	# 导演会在自己的 _ready 里收集场上的蜡像，这里不需要额外处理。
	return director


# ---------------------------------------------------------------------------
# 交互物
# ---------------------------------------------------------------------------

static func _spawn_memory_pickup(map: MapRoot, item: Dictionary, position: Vector2) -> Node:
	var memory_id := str(item.get("memory", ""))
	if memory_id.is_empty():
		return null

	var pickup := MemoryPickup.new()
	pickup.name = "MemoryPickup"
	pickup.position = position
	pickup.memory_id = StringName(memory_id)
	pickup.memory = _load_memory(memory_id)
	pickup.interact_prompt = str(item.get("prompt", "拾取"))
	pickup.add_to_group(CONTENT_GROUP)

	# 拾取物需要一个可见的小图形，否则玩家看不到它。
	if pickup.memory != null and not pickup.memory.title.is_empty():
		var label := Label.new()
		label.name = "Label"
		label.text = pickup.memory.title
		label.position = Vector2(-40.0, -34.0)
		label.modulate = Color(1.0, 0.92, 0.72, 0.85)
		pickup.add_child(label)

	_host_for_interactables(map).add_child(pickup)
	return pickup


static func _load_memory(memory_id: String) -> MemoryData:
	var path := "res://data/memories/%s.tres" % memory_id
	if not ResourceLoader.exists(path):
		push_warning("[LevelLoader] 记忆资源缺失: %s" % path)
		return null
	return load(path) as MemoryData


static func _spawn_signboard(map: MapRoot, item: Dictionary, position: Vector2) -> Node:
	var message := str(item.get("message", ""))
	if message.is_empty():
		return null

	var sign_node := DialogueTrigger.new()
	sign_node.name = "Signboard"
	sign_node.position = position
	sign_node.inline_text = message
	sign_node.set_flag = StringName(str(item.get("flag", "")))
	sign_node.interact_prompt = str(item.get("prompt", "查看"))
	sign_node.one_shot = true
	sign_node.add_to_group(CONTENT_GROUP)
	_host_for_interactables(map).add_child(sign_node)
	return sign_node


# ---------------------------------------------------------------------------
# Boss 与机关
# ---------------------------------------------------------------------------

static func _spawn_morris(map: MapRoot, item: Dictionary, position: Vector2) -> Node:
	var morris := Morris.new()
	morris.name = "Morris"
	# 复用工厂的装配路径，但用莫里斯自己的动画与体型。
	ActorFactory._configure_body(morris, Vector2(30.0, 62.0))
	# 莫里斯的帧是 128x128（不是玩家的 64），所以精灵偏移要按帧高算：
	# 胶囊体高 62、中心在 -31，脚底在 -62；128 高的帧重心在 -64，
	# 因此偏移 = -62 + 64 = +2，脚才会正好落在地面上。
	ActorFactory._attach_sprite(morris, _morris_animations(), &"idle", Vector2(0.0, 2.0))
	ActorFactory._attach_health(morris, 420, false)
	ActorFactory._attach_hurt_box(morris, Vector2(0.0, -31.0), 18.0, 60.0)
	ActorFactory._attach_hit_box(morris, Vector2(40.0, -32.0), Vector2(64.0, 44.0))
	ActorFactory._attach_detection(morris, 620.0)
	ActorFactory._attach_states(morris, _morris_states(), &"idle")
	morris.position = position
	morris.add_to_group(CONTENT_GROUP)
	_host_for_actors(map).add_child(morris)
	return morris


static func _morris_animations() -> Dictionary:
	var base := "res://assets/enemies/"
	return {
		&"idle": {"path": base + "morris_idle.png", "frames": 4, "speed": 5.0, "width": 128, "height": 128},
		&"spray": {"path": base + "morris_spray.png", "frames": 6, "speed": 10.0, "width": 128, "height": 128},
		&"summon": {"path": base + "morris_summon.png", "frames": 5, "speed": 7.0, "width": 128, "height": 128},
		&"hit": {"path": base + "morris_hit.png", "frames": 2, "speed": 12.0, "width": 128, "height": 128},
		&"death": {"path": base + "morris_death.png", "frames": 8, "speed": 7.0, "width": 128, "height": 128},
	}


static func _morris_states() -> Dictionary:
	var base := "res://scripts/boss/morris/states/"
	return {
		&"idle": base + "idle.gd",
		&"chase": base + "chase.gd",
		&"melee": base + "melee.gd",
		&"spray": base + "spray.gd",
		&"summon": base + "summon.gd",
		&"hurt": base + "hurt.gd",
		&"death": base + "death.gd",
	}


static func _spawn_furnace(map: MapRoot, _item: Dictionary, position: Vector2) -> Node:
	var furnace := Node2D.new()
	furnace.name = "Furnace"
	furnace.position = position
	# 熔炉本身用程序化绘制：一个发光的巨大圆，读得出来就行。
	var visual := FurnaceVisual.new()
	furnace.add_child(visual)
	furnace.add_to_group(CONTENT_GROUP)
	map.add_child(furnace)
	return furnace


static func _spawn_arena_gate(map: MapRoot, _item: Dictionary, position: Vector2) -> Node:
	var gate := ArenaGate.new()
	gate.name = "ArenaGate"
	gate.position = position
	gate.add_to_group(CONTENT_GROUP)
	map.add_child(gate)
	return gate


static func _spawn_mirror_puzzle(map: MapRoot, item: Dictionary, position: Vector2) -> Node:
	var puzzle := MirrorPuzzle.new()
	puzzle.name = "MirrorPuzzle"
	puzzle.position = position
	puzzle.puzzle_id = StringName(str(item.get("puzzle_id", "mirror_puzzle")))
	puzzle.solve_flag = StringName(str(item.get("solve_flag", "mirrors_solved")))
	puzzle.reward_memory_id = StringName(str(item.get("reward_memory", "")))
	puzzle.add_to_group(CONTENT_GROUP)
	_host_for_interactables(map).add_child(puzzle)
	return puzzle
