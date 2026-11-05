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
		if session.room_id == "clock_tower" and not session.chase_done():
			demo.hud.toast("钟声之下，路灯点不亮。先追上守钟人。")
			return
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
		demo.hud.toast("这段记忆已经留在速写本中。")
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
	if kind == "true_memory":
		# The well is the last level: remembering that day ends the story.
		demo.show_dialogue(str(spec.get("title","留下的线索")),str(spec.get("text","")),[{"label":"醒来", "action":func(): _resolve_ending("zero")}])
		return
	demo.show_dialogue(str(spec.get("title","留下的线索")),str(spec.get("text","")))

func _rotate_mirror(index: int) -> void:
	var session: ExplorationSession = demo.session
	if session.has("wax_seal"):
		demo.hud.toast("光已经汇聚。那幅没有画完的画上，留着两个孩子的签名。")
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
		demo.show_dialogue("光沿着七面镜子汇聚", "画布上的颜料慢慢化开，露出两个孩子的签名：杰利、玲。\n获得美术馆印记。档案门的锁芯已经松开，前往门边按 E 操作。")
	session.save()

func _confirm_ending(id: String) -> void:
	var title: String = "让钟声倒带"
	var text: String = "回到镇口，从头再走一遍。已经想起的事会留在速写本里。\n这个选择会结束本次探索。"
	var choices: Array = [
		{"label":"继续探索", "action":demo.close_overlay},
		{"label":"确认选择", "action":func(): _resolve_ending(id)}
	]
	if id == "keeper":
		# Story 1.1: the keeper's choice comes before the last descent into the well.
		if demo.session.has("keeper_truth"):
			demo.hud.toast("守钟人已经不在这里了。去井边吧。")
			return
		title = "守钟人摘下了帽子"
		text = "那是一张和你一模一样的脸。\n「你不能到达这里，我得保护你。」"
		choices = [
			{"label":"我要知道真相", "action":func(): _resolve_ending("truth")},
			{"label":"听守钟人的话", "action":func(): _resolve_ending("keeper")}
		]
	elif id == "accept":
		title = "守钟人留下的帽子"
		text = "钟停在了丰收祭那一夜。守钟人已经不在这里了。\n去井边吧。她在等你。"
		choices = [{"label":"继续探索", "action":demo.close_overlay}]
	demo.show_dialogue(title,text,choices)

func _resolve_ending(id: String) -> void:
	var session: ExplorationSession = demo.session
	if id == "keeper":
		demo.show_ending("钟声之后", "你没有再问下去。\n第二天清晨，你收拾完姑姑的遗物，离开了小镇。\n井口的警戒线在身后，越来越远。")
	elif id == "truth":
		session.acquire("keeper_truth")
		demo.close_overlay()
		demo.get_node("/root/AudioManager").play_bell()
		demo.hud.toast("守钟人消散了：「去井边吧。她在等你。」通往丰收祭之夜的门打开了。")
		session.save()
	elif id == "loop":
		var next_loop: int = session.loop_count+1
		var memories: Dictionary = {}
		for memory_id: String in ExplorationCatalog.data()["memories"]:
			if session.has(memory_id) and not memory_id.ends_with("_seal") and not memory_id in ["clock_memory","true_memory"]:
				memories[memory_id] = true
		session.reset()
		session.loop_count = next_loop
		for memory_id: String in memories:
			session.acquire(memory_id)
		session.save()
		demo.show_ending("回溯 · 第 %d 次" % session.loop_count, "钟声响起。你又站在镇口，像什么都没有发生过。\n速写本上多了一行小孩的字迹。\n那天的事，你仍然没有想起来。")
	elif id == "zero":
		demo.show_ending("迟到的鲜花", "刑警把你从井底拉上来时，天已经亮了。\n后来，镇上的证人一个个站出来指控弗瑞。玲重新下葬。\n你在她的墓前，放下一束迟到的鲜花。")
