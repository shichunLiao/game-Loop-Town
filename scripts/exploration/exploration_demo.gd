extends Node2D
## Playable scene-art demo: room lifecycle, input routing and UI orchestration.

var session: ExplorationSession
var hud: ExplorationHUD
var room: ExplorationRoom
var player: ExplorationPlayer
var camera: Camera2D
var actions: ExplorationActions
var mode: String = "menu"
var _return_mode: String = "play"
var _transitioning: bool = false
var _focused: ExplorationInteractable
var _fade: ColorRect
var _capture_request: String = ""
var _npc_focused: ExplorationNPC
var _passage_cooldown: float = 0.0
var _health: int = 100
var _energy: float = 100
var _shake: float = 0
var _arrival: Vector2 = Vector2.INF
var _arrival_exit: String = ""
var _arrival_anchor: Vector2
var _arrival_released: bool = true
var _story_slot: String = "exploration_v2"
var _starting_practice: bool = false

func _ready() -> void:
	add_to_group("exploration_demo")
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture"):
			get_node("/root/SaveManager").exploration_slot_name = "exploration_preview"
	_setup_inputs()
	_story_slot = get_node("/root/SaveManager").exploration_slot_name
	session = ExplorationSession.new()
	session.name = "ExplorationSession"
	add_child(session)
	session.reset()
	var saved: Dictionary = get_node("/root/SaveManager").load_exploration()
	session.loop_count = int(saved.get("loop",247))
	actions = ExplorationActions.new()
	actions.demo = self
	hud = ExplorationHUD.new()
	hud.name = "ExplorationHUD"
	hud.controller = self
	add_child(hud)
	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 80
	add_child(fade_layer)
	_fade = ColorRect.new()
	_fade.size = Vector2(1280,720)
	_fade.color = Color(0.015,0.025,0.035,0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_layer.add_child(_fade)
	hud.show_menu()
	_check_capture_arguments.call_deferred()

func _setup_inputs() -> void:
	for action: String in {"explore_quests":KEY_L,"explore_map":KEY_M, "explore_dash":KEY_SHIFT, "explore_respawn":KEY_R,"explore_time":KEY_Q,"explore_heal":KEY_H}:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var event := InputEventKey.new()
			event.physical_keycode = int({"explore_quests":KEY_L,"explore_map":KEY_M, "explore_dash":KEY_SHIFT, "explore_respawn":KEY_R,"explore_time":KEY_Q,"explore_heal":KEY_H}[action])
			InputMap.action_add_event(action,event)

func start_game(continue_game: bool = false, initial_room: String = "") -> void:
	if not _starting_practice:
		restore_story_slot()
	_health = 100
	_energy = 100
	if is_instance_valid(player):
		player.health = 100
		player.energy = 100
	if continue_game:
		if not session.restore():
			hud.toast("没有可读取的探索存档。")
			return
	else:
		session.reset()
		if not initial_room.is_empty():
			session.room_id = initial_room
	hud.overlay.hide()
	mode = "play"
	load_room(session.room_id)
	if continue_game:
		player.position = session.checkpoint
		camera.reset_smoothing()

func request_room(id: String, source_exit: String = "") -> void:
	if _transitioning:
		return
	_transitioning = true
	_load_deferred.call_deferred(id,source_exit)

func restore_story_slot() -> void:
	get_node("/root/SaveManager").exploration_slot_name = _story_slot

func start_boss_practice() -> void:
	_starting_practice = true
	get_node("/root/SaveManager").exploration_slot_name = "exploration_boss_practice"
	start_game(false,"wax_museum")
	_starting_practice = false
	session.acquire("scissors")
	player.position = Vector2(2600,1137)
	session.save_at("wax_museum",Vector2(2600,1137))
	camera.reset_smoothing()
	hud.toast("莫里斯演练 · 大剪刀已装备 · J 连击 / K 突进 / H 恢复")

func enter_building(building: Dictionary) -> void:
	request_room(str(building["interior_scene"]))

func leave_building() -> void:
	_arrival = ExplorationCatalog.vec(room.data["return_pos"])
	request_room(str(room.data["return_room"]))

func _load_deferred(id: String, source_exit: String) -> void:
	_set_playing(false)
	await _fade_to(.8,.12)
	load_room(id,source_exit)
	await _fade_to(0,.14)
	_transitioning = false
	_set_playing(mode=="play")

func load_room(id: String, source_exit: String = "") -> void:
	if is_instance_valid(room):
		remove_child(room)
		room.queue_free()
	if is_instance_valid(player):
		_health = player.health
		_energy = player.energy
		remove_child(player)
		player.queue_free()
	_focused = null
	_arrival_exit = source_exit
	_arrival_released = source_exit.is_empty()
	_npc_focused = null
	_passage_cooldown = .65
	var packed: PackedScene = load("res://scenes/exploration/maps/"+id+".tscn") as PackedScene
	room = packed.instantiate() as ExplorationRoom
	room.session = session
	add_child(room)
	var spawn: Vector2 = ExplorationCatalog.vec(room.data["spawn"])
	if not source_exit.is_empty():
		for exit: Dictionary in room.data["exits"]:
			if str(exit["id"]) == source_exit:
				spawn = ExplorationCatalog.vec(exit.get("spawn",exit["pos"]))
	player = ExplorationPlayer.new()
	if _arrival != Vector2.INF:
		spawn = _arrival
		_arrival = Vector2.INF
	if source_exit == "__lamp":
		spawn = ExplorationCatalog.vec(room.data["checkpoint"])+Vector2(65,-2)
	player.name = "DetectivePrototype"
	player.session = session
	player.health = _health
	player.energy = _energy
	player.position = spawn
	_arrival_anchor = spawn
	player.died.connect(_on_died)
	add_child(player)
	camera = Camera2D.new()
	camera.name = "ExplorationCamera"
	camera.position = Vector2(0,-205)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	camera.limit_left = 0
	camera.limit_right = int(room.bounds.x)
	camera.limit_top = 0
	camera.limit_bottom = int(room.bounds.y)
	player.add_child(camera)
	camera.make_current()
	camera.reset_smoothing()
	session.visit(id)
	get_node("/root/AudioManager").enter_area(StringName(str(room.data["audio"])))
	session.save()
	hud.toast(ExplorationCatalog.title(id))
	_set_playing(mode == "play")

func _physics_process(delta: float) -> void:
	if mode != "play" or not is_instance_valid(player) or _transitioning:
		return
	session.elapsed += delta
	session.slow_time = maxf(0,session.slow_time-delta)
	_passage_cooldown = maxf(0,_passage_cooldown-delta)
	if not _arrival_released and player.position.distance_to(_arrival_anchor)>150:
		_arrival_released = true
	_shake = maxf(0,_shake-delta)
	camera.offset = Vector2(sin(session.elapsed*120),cos(session.elapsed*97))*_shake*38
	player.position.x = clampf(player.position.x, 20, room.bounds.x-20)
	if player.position.y > room.bounds.y+70:
		player.take_damage(100)
	player.near_vine = false
	for vine: Array in room.data.get("vines",[]):
		if Rect2(float(vine[0]),float(vine[1]),float(vine[2]),float(vine[3])).grow(35).has_point(player.position):
			player.near_vine = true
	var nearest: ExplorationInteractable
	var best: float = 112.0
	for candidate: ExplorationInteractable in room.interactables:
		candidate.focused = false
		if candidate.is_finished():
			continue
		var distance: float = (candidate.global_position+Vector2(0,-45)).distance_to(player.global_position+Vector2(0,-32))
		if distance < best:
			best = distance
			nearest = candidate
	_focused = nearest
	_npc_focused = null
	for npc: ExplorationNPC in room.npcs:
		npc.focused = false
		if not npc.visible:
			continue
		var npc_distance: float = npc.global_position.distance_to(player.global_position)
		if npc_distance<minf(105,best):
			best = npc_distance
			_npc_focused = npc
	if _npc_focused != null:
		_npc_focused.focused = true
		_focused = null
	if _focused != null:
		_focused.focused = true
		hud.prompt_label.text = _focused.prompt()
	elif player.near_vine and session.has("vine"):
		hud.prompt_label.text = "W / S  抓住藤蔓攀爬"
	else:
		hud.prompt_label.text = ""
	if _npc_focused != null:
		hud.prompt_label.text = _npc_focused.interaction_prompt()
	for passage: ExplorationPassage in room.passages:
		if str(passage.spec["id"])==_arrival_exit and not _arrival_released:
			continue
		if passage.contains_player(player):
			if passage.is_open():
				if bool(passage.spec.get("manual_entry",false)):
					continue
				if _passage_cooldown<=0 and passage.moving_toward(player):
					if session.room_id=="well_interior" and session.has("well_seal"):
						session.switches["well_escaped"] = true
					request_room(str(passage.spec["target"]),str(passage.spec["id"]))
					return
			else:
				ExplorationJournal.discover(session,str(passage.spec.get("gate_id",passage.spec["id"])))
				hud.prompt_label.text = passage.prompt()
		elif not passage.is_open() and player.position.distance_to(passage.position)<185:
			ExplorationJournal.discover(session,str(passage.spec.get("gate_id",passage.spec["id"])))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if event.is_action_pressed("explore_quests"):
		if mode == "quests":
			close_overlay()
		elif mode == "play":
			_return_mode = "play"
			mode = "quests"
			_set_playing(false)
			hud.show_quests()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("explore_map"):
		if mode == "map":
			close_overlay()
		elif mode == "play":
			open_map()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("open_notebook"):
		if mode == "notebook":
			close_overlay()
		elif mode == "play":
			_return_mode = "play"
			mode = "notebook"
			_set_playing(false)
			hud.show_notebook()
	elif event.is_action_pressed("pause"):
		if mode in ["map","notebook","dialogue","pause","cast","quests"]:
			close_overlay()
		elif mode == "play":
			show_pause()
	elif mode == "dialogue" and (event.is_action_pressed("interact") or event.is_action_pressed("jump")):
		close_overlay()
		get_viewport().set_input_as_handled()
	elif mode == "play" and event.is_action_pressed("interact"):
		if _npc_focused != null:
			_npc_focused.talk()
		elif _focused != null:
			actions.activate(_focused)
	elif mode == "play" and event.is_action_pressed("explore_respawn"):
		_on_died()

func _set_playing(playing: bool) -> void:
	if is_instance_valid(player):
		player.enabled = playing
		player.process_mode = Node.PROCESS_MODE_INHERIT if playing else Node.PROCESS_MODE_DISABLED
	if is_instance_valid(room):
		room.process_mode = Node.PROCESS_MODE_INHERIT if playing else Node.PROCESS_MODE_DISABLED

func open_map(from_menu: bool = false) -> void:
	_return_mode = "menu" if from_menu else "play"
	mode = "map"
	_set_playing(false)
	hud.show_map(from_menu)

func close_overlay() -> void:
	if _return_mode == "menu":
		mode = "menu"
		hud.show_menu()
	else:
		mode = "play"
		hud.overlay.hide()
		_set_playing(true)

func open_cast() -> void:
	_return_mode = "menu" if mode=="menu" else "play"
	mode = "cast"
	_set_playing(false)
	hud.show_cast()

func show_dialogue(title: String, text: String, choices: Array = []) -> void:
	_return_mode = "play"
	mode = "dialogue"
	_set_playing(false)
	hud.show_dialogue(title,text,choices)

func show_pause() -> void:
	_return_mode = "play"
	mode = "pause"
	_set_playing(false)
	hud.show_dialogue("留在灯光下", "探索已暂停。路灯会记住你走过的地方。", [
		{"label":"继续探索", "action":close_overlay},
		{"label":"保存并回到标题", "action":func(): session.save(); mode = "menu"; hud.show_menu()}
	])

func fast_travel(id: String) -> void:
	hud.toast("地图用于查看通路。请沿实际道路前往目的地。")

func _on_died() -> void:
	if mode != "play":
		return
	mode = "respawn"
	_set_playing(false)
	session.deaths += 1
	await _fade_to(1,.35)
	load_room(session.checkpoint_room)
	player.position = session.checkpoint
	player.health = 100
	player.energy = 100
	camera.reset_smoothing()
	mode = "play"
	_set_playing(true)
	await _fade_to(0,.35)
	hud.toast("回到最近点亮的路灯。记忆仍然留在笔记本中。")

func screen_shake(duration: float) -> void:
	_shake = maxf(_shake,duration)

func _fade_to(alpha: float, seconds: float) -> void:
	var tween := create_tween()
	tween.tween_property(_fade,"color:a",alpha,seconds)
	await tween.finished

func show_ending(title: String, text: String) -> void:
	show_dialogue(title,text,[{"label":"返回标题", "action":func(): session.save(); mode="menu"; hud.show_menu()}])
	mode = "ending"

func _check_capture_arguments() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	for arg: String in arguments:
		if arg.begins_with("--capture="):
			_capture_request = arg.trim_prefix("--capture=")
		if arg.begins_with("--room="):
			start_game(false,arg.trim_prefix("--room="))
	if arguments.has("--practice"):
		start_boss_practice()
	for arg: String in arguments:
		if arg.begins_with("--at=") and is_instance_valid(player):
			var coordinates: PackedStringArray = arg.trim_prefix("--at=").split(",")
			player.position = Vector2(float(coordinates[0]),float(coordinates[1]))
			camera.reset_smoothing()
		if arg.begins_with("--arrive-via=") and not _capture_request.is_empty():
			load_room(session.room_id,arg.trim_prefix("--arrive-via="))
		if arg.begins_with("--preview-stage=") and not _capture_request.is_empty():
			var preview_stage: int = int(arg.trim_prefix("--preview-stage="))
			for pair: Array in [[1,"scissors"],[2,"theater_seal"],[2,"double_jump"],[2,"vine"],[3,"well_seal"],[3,"dash"],[4,"time_slow"]]:
				if preview_stage>=int(pair[0]):
					session.acquire(str(pair[1]))
	if arguments.has("--capture-cast"):
		open_cast()
	for arg: String in arguments:
		if arg.begins_with("--building-view=") and not _capture_request.is_empty():
			var index: int = int(arg.trim_prefix("--building-view="))
			if index>=0 and index<room.buildings.size():
				var building: ExplorationBuilding = room.buildings[index]
				player.position = building.global_position+Vector2(-building.width*.19,-3)
				building.interact("door")
				await get_tree().create_timer(.5).timeout
				camera.reset_smoothing()
		if arg.begins_with("--camera-pan=") and not _capture_request.is_empty():
			camera.position.x = float(arg.trim_prefix("--camera-pan="))
			camera.reset_smoothing()
		if arg.begins_with("--window-view=") and not _capture_request.is_empty():
			var parts: PackedStringArray = arg.trim_prefix("--window-view=").split(",")
			var index: int = int(parts[0])
			if index>=0 and index<room.buildings.size():
				if parts.size()>1 and parts[1]=="broken":
					room.buildings[index].break_window()
				else:
					room.buildings[index].interact("window")
	# Documentation previews use a separate preview save slot.
	for arg: String in arguments:
		if _capture_request.is_empty():
			continue
		if arg.begins_with("--inside-at="):
			var parts: PackedStringArray = arg.trim_prefix("--inside-at=").split(",")
			player.position = Vector2(float(parts[0]),float(parts[1]))
			camera.reset_smoothing()
		if arg.begins_with("--lift-view="):
			for fixture: ExplorationInteractable in room.interactables:
				if str(fixture.spec.get("kind",""))=="lift_call" and bool(fixture.spec.get("opens",false)):
					actions.activate(fixture)
					break
			if arg.trim_prefix("--lift-view=")=="upper":
				load_room(session.room_id)
			for platform: ExplorationPlatform in room.platforms:
				if not platform.manual_lift:
					continue
				player.position = platform.position+Vector2(platform.dimensions.x*.5,-2)
				player._last_ground_y = player.position.y
				camera.reset_smoothing()
				break
		if arg.begins_with("--npc-view="):
			var index: int = int(arg.trim_prefix("--npc-view="))
			if index>=0 and index<room.npcs.size():
				player.position = room.npcs[index].position+Vector2(-75,-2)
				camera.reset_smoothing()
				room.npcs[index].talk()
		if arg.begins_with("--gate-view="):
			var parts: PackedStringArray = arg.trim_prefix("--gate-view=").split(",")
			var index: int = int(parts[0])
			if index>=0 and index<room.passages.size():
				var gate: ExplorationPassage = room.passages[index]
				player.position = gate.position+Vector2(-100 if str(gate.spec.get("direction","right"))=="right" else 100,-2)
				camera.reset_smoothing()
				ExplorationJournal.discover(session,str(gate.spec.get("gate_id",gate.spec["id"])))
				if parts.size()>1 and parts[1]=="open":
					for requirement: String in gate.spec.get("requires",[]):
						session.acquire(requirement)
					gate.operate()
					await get_tree().create_timer(1.0).timeout
		if arg=="--quest-view":
			for task: Dictionary in ExplorationJournal.definitions()["side"]:
				if str(task["return_room"])==session.room_id:
					ExplorationJournal.accept(session,str(task["id"]))
			mode = "quests"
			_return_mode = "play"
			_set_playing(false)
			hud.show_quests()
	if arguments.has("--capture-map"):
		await _export_world_map()
		get_node("/root/AudioManager").stop_all()
		await get_tree().create_timer(.1).timeout
		get_tree().quit()
	elif not _capture_request.is_empty():
		for arg: String in arguments:
			if arg.begins_with("--boss-view="):
				player._invulnerability = 10
		await get_tree().create_timer(1.3).timeout
		for arg: String in arguments:
			if arg.begins_with("--boss-view="):
				await _capture_boss_action(arg.trim_prefix("--boss-view="))
		if arguments.has("--attack-frame"):
			player.begin_attack()
			await get_tree().create_timer(.10).timeout
		player.set_physics_process(false)
		player.visual.modulate.a = 1.0
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(_capture_request)
		get_node("/root/AudioManager").stop_all()
		await get_tree().create_timer(.1).timeout
		get_tree().quit()

func _capture_boss_action(value: String) -> void:
	var boss: ExplorationBoss = get_tree().get_first_node_in_group("exploration_boss") as ExplorationBoss
	if boss == null:
		return
	var parts: PackedStringArray = value.split(",")
	var phase_value: int = clampi(int(parts[0]),1,3)
	boss.phase = phase_value
	boss.phase_title = "蜡匠的执念" if phase_value==1 else "蜡壳裂开" if phase_value==2 else "熔炉中的真身"
	boss.health = int(boss.max_health*(1 if phase_value==1 else .58 if phase_value==2 else .24))
	boss._clear_owned()
	boss.position = Vector2(3220,1140)
	player.position = Vector2(2830,1137)
	player._invulnerability = 10
	var requested: String = parts[1] if parts.size()>1 else "fan"
	var sequence: Array = ["fan","cleave","slam"] if phase_value==1 else ["rush","fan","copies","slam","cleave"] if phase_value==2 else ["rain","rush","fan","slam","copies","cleave"]
	boss.pattern = maxi(0,sequence.find(requested))
	boss._select_attack(player)
	if parts.size()>2 and parts[2]=="active":
		await get_tree().create_timer(boss._windup_length+(.38 if requested=="rain" else .14)).timeout
	else:
		await get_tree().create_timer(.35).timeout
	camera.reset_smoothing()

func _export_world_map() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(3840,2160)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var map := ExplorationWorldMap.new()
	map.session = session
	map.overview = true
	map.size = Vector2(3840,2160)
	viewport.add_child(map)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var output: String = "res://docs/exploration-demo/world-map.png"
	viewport.get_texture().get_image().save_png(output)
	print("WORLD_MAP_EXPORTED ",ProjectSettings.globalize_path(output))
