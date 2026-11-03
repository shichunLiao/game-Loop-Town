extends SceneTree

## 开发期运行时校验（临时）：
##   1. 实例化玩家场景，确认子系统装配成功
##   2. 实例化每张地图场景，确认地形 / 出生点 / 出口生成成功
##   3. 检查玩家是否真的被放进地图并能受重力落到地面
##
## 注意：autoload 全局名在本脚本里不可见（本脚本是 MainLoop，编译早于 autoload 注册），
## 因此一律通过 root.get_node_or_null() 取。

const PLAYER_SCENE := "res://scenes/player/Player.tscn"
const MAP_SCENES: Array[String] = [
	"res://scenes/maps/town_entrance.tscn",
	"res://scenes/maps/town_hub.tscn",
	"res://scenes/maps/wax_lane.tscn",
	"res://scenes/maps/wax_museum.tscn",
	"res://scenes/maps/wax_basement.tscn",
	"res://scenes/maps/old_theater.tscn",
	"res://scenes/maps/back_stage.tscn",
	"res://scenes/maps/dry_well.tscn",
	"res://scenes/maps/well_interior.tscn",
	"res://scenes/maps/clock_tower.tscn",
	"res://scenes/maps/final_fire_town.tscn",
	"res://scenes/maps/shadow_boss.tscn",
	"res://scenes/maps/train_station.tscn",
]

var _failures: int = 0
var _map_index: int = 0


func _initialize() -> void:
	print("=== 运行时校验开始 ===")
	# 本校验要驱动真实物理（验证重力与地面碰撞），因此必须确保游戏树没有暂停。
	# GameManager 在标题界面默认暂停，这里通过 autoload 节点把它解除。
	var game_manager := root.get_node_or_null("GameManager")
	if game_manager != null:
		if game_manager.has_method("set_paused"):
			game_manager.call("set_paused", false)
		game_manager.set("is_paused", false)
	paused = false
	_test_player_scene()


func _test_player_scene() -> void:
	var packed := load(PLAYER_SCENE) as PackedScene
	if packed == null:
		_fail("玩家场景加载失败")
		_next_map()
		return

	var player := packed.instantiate()
	root.add_child(player)
	# 等两帧让 @onready 与 _ready 跑完。
	await process_frame
	await process_frame

	_check(player.get_node_or_null("AnimatedSprite2D") != null, "玩家有 AnimatedSprite2D")
	_check(player.get_node_or_null("HealthComponent") != null, "玩家有 HealthComponent")
	_check(player.get_node_or_null("HurtBox") != null, "玩家有 HurtBox")
	_check(player.get_node_or_null("HitBox") != null, "玩家有 HitBox")
	_check(player.get_node_or_null("StateMachine") != null, "玩家有 StateMachine")
	_check(player.get_node_or_null("Camera2D") != null, "玩家有 Camera2D")

	var sm := player.get_node_or_null("StateMachine")
	if sm != null:
		var state_count := sm.get_child_count()
		_check(state_count >= 9, "状态机有 %d 个子状态" % state_count)
		var current: Variant = sm.get("current_state_name")
		print("     状态机已启动，当前状态 = %s，子状态 %d 个" % [current, state_count])

	var sprite := player.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite != null:
		if sprite.sprite_frames == null:
			_fail("AnimatedSprite2D 没有 SpriteFrames")
		else:
			var names := sprite.sprite_frames.get_animation_names()
			print("     动画数量 = %d，包含 idle=%s run=%s attack=%s" % [
				names.size(),
				names.has("idle"), names.has("run"), names.has("attack"),
			])
			_check(names.has("idle") and names.has("run") and names.has("attack"),
				"动画包含 idle/run/attack")
			# 验证每帧都能取到贴图（AtlasTexture 区域正确）
			var idle_frames := sprite.sprite_frames.get_frame_count(&"idle")
			_check(idle_frames == 6, "idle 帧数 = %d（应为 6）" % idle_frames)
			var tex := sprite.sprite_frames.get_frame_texture(&"idle", 0)
			_check(tex != null, "idle 第 0 帧有贴图")
			var run_frames := sprite.sprite_frames.get_frame_count(&"run")
			_check(run_frames == 8, "run 帧数 = %d（应为 8）" % run_frames)

	player.queue_free()
	await process_frame
	_next_map()


func _next_map() -> void:
	if _map_index >= MAP_SCENES.size():
		_finish()
		return
	var path := MAP_SCENES[_map_index]
	_map_index += 1
	_test_map(path)


func _test_map(path: String) -> void:
	var packed := load(path) as PackedScene
	if packed == null:
		_fail("%s 加载失败" % path)
		_next_map()
		return

	var map := packed.instantiate()
	root.add_child(map)
	paused = false
	await process_frame
	await process_frame
	await process_frame

	var map_name := path.get_file().get_basename()
	var gameplay := map.get_node_or_null("Gameplay")
	var spawn := map.get_node_or_null("PlayerSpawn")
	var triggers := map.get_node_or_null("Triggers")

	_check(gameplay != null and gameplay.get_node_or_null("Ground") != null,
		"%s 生成地面" % map_name)
	_check(spawn != null and spawn.get_child_count() > 0,
		"%s 生成出生点" % map_name)
	_check(triggers != null and triggers.get_child_count() > 0,
		"%s 生成出口/检查点" % map_name)

	var players := map.get_children()
	var player_found: Node = null
	for node in players:
		if node.is_in_group(&"player"):
			player_found = node
	if player_found == null:
		players = get_nodes_in_group(&"player")
		if not players.is_empty():
			player_found = players[0]

	if player_found != null:
		var start_y := (player_found as Node2D).global_position.y
		# 让物理跑几帧，验证重力与地面碰撞可用。
		for i in 40:
			await physics_frame
		var end_y := (player_found as Node2D).global_position.y
		var vy := (player_found as CharacterBody2D).velocity.y
		var on_floor := (player_found as CharacterBody2D).is_on_floor()
		print("     %s: 玩家 y %.1f -> %.1f, vy=%.1f, on_floor=%s" % [
			map_name, start_y, end_y, vy, on_floor,
		])
		_check(on_floor, "%s 玩家没有落到地面上（重力或碰撞有问题）" % map_name)
	else:
		_fail("%s 没有生成玩家" % map_name)

	map.queue_free()
	await process_frame
	_next_map()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok   %s" % message)
	else:
		_fail(message)


func _fail(message: String) -> void:
	_failures += 1
	print("  FAIL %s" % message)


func _finish() -> void:
	print("")
	print("=== 校验结束：失败 %d 项 ===" % _failures)
	quit(0 if _failures == 0 else 1)
