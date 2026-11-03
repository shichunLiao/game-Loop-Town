extends SceneTree

## 换图实测（临时）：验证「走过出口 → 切到下一张地图 → 内容重新生成」这条链路。

var _failures: int = 0


func _initialize() -> void:
	# 重要：_initialize() 早于 autoload 入树执行，此时 get_tree() 仍是 null。
	# 必须等到第一帧之后再驱动 GameManager，否则会报 "data.tree is null"。
	_deferred_start()


func _deferred_start() -> void:
	await process_frame
	await process_frame
	print("=== 换图实测开始 ===")
	var gm := root.get_node_or_null("GameManager")
	if gm != null:
		gm.call("set_paused", false)
		gm.set("is_paused", false)
	paused = false
	_run()


func _run() -> void:
	# 用 GameManager 正常入口进入游戏，这样走的是玩家真实路径。
	var gm := root.get_node_or_null("GameManager")
	if gm == null:
		_fail("没有 GameManager autoload")
		_finish()
		return

	# 注意：起新游戏会 await change_map，这里不等它，直接轮询结果。
	gm.call("start_new_game")

	# 等玩家出现在序幕地图。
	var player := await _wait_for_player(240)
	if player == null:
		_fail("start_new_game 后没有生成玩家")
		_finish()
		return

	var map := get_first_node_in_group(&"map")
	print("  当前地图 = %s" % (str(map.get("map_id")) if map != null else "?"))
	_check(map != null, "序幕地图已加载")
	if map != null:
		_check(String(map.get("map_id")) == "town_entrance", "起始地图是 town_entrance")
	_check(get_nodes_in_group(&"townsman").size() > 0,
		"序幕有镇民（%d 个）" % get_nodes_in_group(&"townsman").size())

	var hud := root.get_node_or_null("GameHUD")
	_check(hud != null, "游戏内 UI 已挂载")
	if hud != null:
		_check(get_nodes_in_group(&"game_hud").size() > 0, "GameHUD 已注册到组")

	# 找出口并走过去。
	var exits := get_nodes_in_group(&"exit")
	if exits.is_empty() and map != null:
		# 诊断：检查 MapData.exits 到底加载出了什么。
		var registry := root.get_node_or_null("MapRegistry")
		if registry != null:
			var map_data: Variant = registry.call("get_map", map.get("map_id"))
			if map_data != null:
				var raw_exits: Variant = map_data.get("exits")
				print("  诊断 MapData.exits 类型 = %s 大小 = %s" % [
					type_string(typeof(raw_exits)),
					str((raw_exits as Array).size()) if raw_exits is Array else "n/a",
				])
				if raw_exits is Array:
					for item: Variant in raw_exits:
						print("    项 class=%s is_MapExitLink=%s exit_id=%s target=%s" % [
							item.get_class() if item != null else "null",
							str(item is MapExitLink),
							str(item.get("exit_id")) if item != null else "?",
							str(item.get("target_map_id")) if item != null else "?",
						])
	_check(exits.size() > 0, "序幕地图有出口（%d 个）" % exits.size())
	if exits.is_empty():
		_finish()
		return

	var exit_node := exits[0] as Area2D
	var exit_position := exit_node.global_position
	print("  走向出口 %s @ %s" % [exit_node.name, str(exit_position)])

	# 直接驱动玩家朝出口移动（比模拟长时间按键更稳定）。
	var map_id_before: String = String(map.get("map_id"))
	player.global_position = exit_position + Vector2(0.0, 40.0)
	for i in 30:
		await physics_frame

	# 换图是异步的，轮询等待。
	var switched := false
	for i in 240:
		await process_frame
		var current := get_first_node_in_group(&"map")
		if current != null and String(current.get("map_id")) != map_id_before:
			switched = true
			print("  已切换到 %s" % String(current.get("map_id")))
			_check(String(current.get("map_id")) == "town_hub", "从序幕切到了小镇 Hub")
			_check(current.get_node_or_null("Gameplay/Ground") != null, "新地图有地形")
			_check(get_nodes_in_group(&"townsman").size() > 0,
				"新地图内容已重新生成（%d 个镇民）" % get_nodes_in_group(&"townsman").size())
			_check(get_nodes_in_group(&"player").size() == 1,
				"换图后只有 1 个玩家（没有重复生成）")
			break
	_check(switched, "走过出口能触发换图")
	_finish()


func _wait_for_player(max_frames: int) -> CharacterBody2D:
	for i in max_frames:
		await process_frame
		var players := get_nodes_in_group(&"player")
		if not players.is_empty():
			return players[0] as CharacterBody2D
	return null


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
	print("=== 换图实测结束：失败 %d 项 ===" % _failures)
	quit(0 if _failures == 0 else 1)
