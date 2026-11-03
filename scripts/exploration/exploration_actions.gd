class_name ExplorationActions
extends RefCounted
## Data-driven environment interactions; no map-specific player logic.

var demo: Node2D

func activate(object: ExplorationInteractable) -> void:
	var spec: Dictionary = object.spec
	var session: ExplorationSession = demo.session
	var kind: String = str(spec["kind"])
	if object is ExplorationLiftFeature:
		(object as ExplorationLiftFeature).lift.operate_lift()
		return
	if kind == "lift_call":
		if not session.has(str(spec["unlock"])) and not bool(spec.get("opens",false)):
			demo.hud.toast("先攀上顶层，接通吊笼手柄。")
			return
		session.switches[str(spec["unlock"])] = true
		session.switches[str(spec["flag"])] = bool(spec["value"])
		session.changed.emit()
		session.save()
		demo.hud.toast("返程捷径已接通 · 吊笼正前往上层" if bool(spec["value"]) else "吊笼正返回下层")
		return
	if object is ExplorationPassage:
		(object as ExplorationPassage).operate()
		return
	if kind == "interior_exit":
		demo.leave_building()
		return
	if object is ExplorationBuildingFeature:
		var feature: ExplorationBuildingFeature = object as ExplorationBuildingFeature
		feature.building.interact(feature.feature)
		return
	if kind == "exit":
		if not session.satisfies(spec.get("requires", [])):
			demo.hud.toast(str(spec.get("hint", "这条路暂时无法通行。")))
			return
		if session.room_id == "well_interior" and session.has("well_seal"):
			session.switches["well_escaped"] = true
		demo.request_room(str(spec["target"]), str(spec["id"]))
		return
	if kind == "checkpoint":
		demo.player.health = 100
		demo.player.energy = 100
		session.switches["lamp_" + session.room_id] = true
		var saved: bool = session.save_at(session.room_id, object.position + Vector2(65,-2))
		demo.hud.toast("路灯已点亮 · 进度已保存 · 生命与墨光恢复" if saved else "无法保存，请检查存档目录权限。")
		demo.get_node("/root/AudioManager").play_sfx("sfx_pickup")
		return
	if not session.satisfies(spec.get("requires", [])):
		demo.hud.toast("这里还缺少一段记忆或一件道具。")
		return
	if object.is_finished():
		demo.hud.toast("这段记忆已经留在笔记本中。")
		return
	if kind == "mirror":
		_rotate_mirror(int(spec["index"]))
		return
	if kind == "ending":
		_confirm_ending(str(spec["ending"]))
		return
	if kind in ["switch", "thread"]:
		session.switches[str(spec["flag"])] = true
		session.changed.emit()
	elif kind == "true_memory":
		session.acquire("true_memory")
	else:
		session.acquire(str(spec.get("item", "")))
	for grant: String in spec.get("grants", []):
		session.acquire(grant)
	if str(spec.get("item","")) == "well_seal" and not session.has("well_escaped"):
		session.switches["well_escape_active"] = true
	if kind == "flashback":
		session.stage = 4
		session.changed.emit()
		demo.get_node("/root/AudioManager").play_bell()
	if kind in ["memory","ability","relic","flashback","true_memory"]:
		session.collected[str(spec.get("uid",spec.get("item","true_memory")))] = true
		object.hide()
		session.changed.emit()
	demo.get_node("/root/AudioManager").play_sfx("sfx_notebook_write")
	session.save()
	demo.show_dialogue(str(spec.get("title","留下的线索")),str(spec.get("text","")))

func _rotate_mirror(index: int) -> void:
	var session: ExplorationSession = demo.session
	if session.has("wax_seal"):
		demo.hud.toast("光已经汇聚。未完成的蜡块里留下了第 247 份订单。")
		return
	session.mirrors[index] = (int(session.mirrors[index]) + 1) % 4
	demo.get_node("/root/AudioManager").play_sfx("sfx_mirror_turn")
	var solution: Array = ExplorationCatalog.data()["mirror_solution"]
	var solved: bool = true
	for i: int in range(7):
		if int(session.mirrors[i]) != int(solution[i]):
			solved = false
	if solved:
		session.acquire("wax_seal")
		demo.get_node("/root/AudioManager").play_sfx("sfx_light_focus")
		demo.show_dialogue("光沿着七面镜子汇聚", "蜡块缓慢融化。留下的订货单写着：247。\n获得蜡像印记。档案门的锁芯已经松开，前往门边按 E 操作。")
	session.save()

func _confirm_ending(id: String) -> void:
	var title: String = "最后的选择"
	var text: String = "这一次，你要如何离开那一夜？"
	var choices: Array = [
		{"label":"继续探索", "action":demo.close_overlay},
		{"label":"确认选择", "action":func(): _resolve_ending(id)}
	]
	if id == "keeper":
		title = "我帮你拧发条"
		text = "有些人选择留在那一夜，替所有人记住它。\n这个选择会结束本次探索。"
	elif id == "accept":
		title = "摘下帽子"
		text = "你不用打败我。你只需要，终于肯看我一眼。\n如果还没听完井底的记忆，现在仍可以返回。"
	demo.show_dialogue(title,text,choices)

func _resolve_ending(id: String) -> void:
	var session: ExplorationSession = demo.session
	if id == "keeper":
		demo.show_ending("停摆的钟", "你接过发条。247 个齿轮同时咔哒一声。\n有些人选择留在那一夜，替所有人记住它。")
	elif id == "loop" or (id == "accept" and not session.has("true_memory")):
		var next_loop: int = session.loop_count+1
		var memories: Dictionary = {}
		for memory_id: String in ExplorationCatalog.data()["memories"]:
			if session.has(memory_id) and not memory_id.ends_with("_seal"):
				memories[memory_id] = true
		session.reset()
		session.loop_count = next_loop
		for memory_id: String in memories:
			session.acquire(memory_id)
		session.save()
		demo.show_ending("完美循环 · 第 %d 次" % session.loop_count, "欢迎回来。\n笔记本上多了一行小孩的字迹。\n那句话，你仍然没有听完。")
	elif id == "accept":
		session.acquire("zero_loop")
		session.stage = 5
		session.changed.emit()
		demo.close_overlay()
		demo.hud.toast("钟停了。前往右侧的门，走向火车站。")
		session.save()
	elif id == "zero":
		demo.show_ending("第零次循环", "你不需要被原谅。\n你只是需要，终于记得自己做过什么。\n一列清晨的火车停在站台。")
