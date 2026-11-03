extends SceneTree
## Integration checks use real physics and input; QA selects a dedicated save slot.

var demo: Node2D
var failures: Array[String] = []
var passes: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, description: String) -> void:
	if ok:
		passes += 1
		print("PASS ",description)
	else:
		failures.append(description)
		print("FAIL ",description)

func frames(count: int) -> void:
	for i: int in range(count):
		await physics_frame

func _run() -> void:
	root.get_node("SaveManager").exploration_slot_name = "exploration_qa"
	demo = (load("res://scenes/exploration/ExplorationDemo.tscn") as PackedScene).instantiate()
	root.add_child(demo)
	current_scene = demo
	demo.start_game(false)
	await frames(25)
	check(demo.player.is_on_floor(),"Player settles on real collision floor")
	var start_x: float = demo.player.position.x
	Input.action_press("move_right")
	await frames(30)
	Input.action_release("move_right")
	await frames(2)
	check(demo.player.position.x > start_x+140,"Run input moves the player")
	check(absf(demo.player.velocity.x)<1,"Release stops drift")
	var ground_y: float = demo.player.position.y
	Input.action_press("jump")
	await frames(20)
	check(demo.player.position.y < ground_y-120,"Base jump clears a 120px step")
	Input.action_release("jump")
	await frames(55)
	check(demo.player.is_on_floor(),"Player lands after a jump")
	# Cross the actual 190px opening with base movement, without extra abilities.
	demo.player.position = Vector2(1490,940)
	demo.player.velocity = Vector2.ZERO
	await frames(4)
	Input.action_press("move_right")
	Input.action_press("jump")
	await frames(45)
	Input.action_release("jump")
	await frames(9)
	Input.action_release("move_right")
	await frames(12)
	check(demo.player.position.x>1730 and demo.player.is_on_floor(),"190px pit is physically crossable with the base jump")
	var lamp: ExplorationInteractable = demo.room.interactables[0]
	demo.actions.activate(lamp)
	var checkpoint: Vector2 = demo.session.checkpoint
	demo.player.take_damage(35)
	check(demo.player.health==65,"Damage reduces health")
	demo.player.take_damage(35)
	check(demo.player.health==65,"Invulnerability prevents repeated instant damage")
	await frames(80)
	demo.player.take_damage(100)
	await frames(100)
	check(demo.player.health==100 and demo.player.position.distance_to(checkpoint)<5,"Death returns to the saved lamp")
	await _check_all_exit_spawns()
	await _check_vertical_route()
	await _check_progression()
	await _check_save_and_ui()
	var report: Dictionary = {"passes":passes,"failures":failures,"room_count":ExplorationCatalog.data()["rooms"].size()}
	var file := FileAccess.open("res://docs/exploration-demo/qa-report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	print("EXPLORATION_QA ",passes," passed, ",failures.size()," failed")
	demo.queue_free()
	await process_frame
	await process_frame
	root.get_node("AudioManager").stop_all()
	OS.delay_msec(80)
	quit(0 if failures.is_empty() else 1)

func _check_all_exit_spawns() -> void:
	var rooms: Dictionary = ExplorationCatalog.data()["rooms"]
	var count: int = 0
	var valid: bool = true
	for id: String in rooms:
		for exit: Dictionary in rooms[id]["exits"]:
			var target: String = str(exit["target"])
			var reciprocal: bool = false
			for incoming: Dictionary in rooms[target]["exits"]:
				if str(incoming["id"])==str(exit["id"]) and str(incoming["target"])==id:
					reciprocal = true
			valid = valid and reciprocal
			demo.load_room(target,str(exit["id"]))
			await frames(22)
			valid = valid and demo.player.is_on_floor() and demo.player.position.y < demo.room.bounds.y
			if not demo.player.is_on_floor():
				print("UNSAFE EXIT ",id," -> ",target," ",demo.player.position)
			count += 1
	check(valid,"All %d reciprocal exits spawn above safe collidable ground" % count)
	check(rooms.size()==18,"All 18 independent room scenes instantiate")

func _check_vertical_route() -> void:
	demo.load_room("clock_tower")
	await frames(12)
	var ascending: Array = []
	for platform: ExplorationPlatform in demo.room.platforms:
		if platform.one_way and platform.travel==Vector2.ZERO:
			ascending.append(platform)
	ascending.sort_custom(func(a: ExplorationPlatform,b: ExplorationPlatform)->bool:return a.position.y>b.position.y)
	var previous: ExplorationPlatform
	var reached: int = 0
	var reached_top: bool = false
	for platform: ExplorationPlatform in ascending:
		if previous == null:
			demo.player.position = Vector2(platform.position.x+100,demo.room.data["floor"])
			await frames(3)
		else:
			# Walk to the edge of the current step, then physically jump to the next.
			var rightward: bool = platform.position.x>previous.position.x
			var launch_x: float = previous.position.x+previous.dimensions.x-32 if rightward else previous.position.x+32
			demo.player.position.x = launch_x
			await frames(2)
			Input.action_press("move_right" if rightward else "move_left")
		Input.action_press("jump")
		await frames(28)
		Input.action_release("move_right")
		Input.action_release("move_left")
		await frames(20)
		Input.action_release("jump")
		await frames(14)
		if demo.player.position.y <= 195 and demo.player.is_on_floor():
			reached_top = true
			reached += 1
			break
		if demo.player.position.y>platform.position.y+5 or not demo.player.is_on_floor():
			print("VERTICAL BLOCK ",reached," player=",demo.player.position," platform=",platform.position)
			break
		reached += 1
		previous = platform
	check(reached_top,"Entire seven-floor tower is physically climbable with base jumps (%d jumps)" % reached)
	var moving: ExplorationPlatform
	for platform: ExplorationPlatform in demo.room.platforms:
		if platform.travel!=Vector2.ZERO:
			moving = platform
			break
	var before: Vector2 = moving.position
	await frames(45)
	check(moving.position.distance_to(before)>8,"Mechanical elevators move under physics")

func _check_progression() -> void:
	demo.session.reset()
	check(not demo.session.satisfies(["wax_seal","theater_seal","well_seal"]),"Clocktower is initially gated")
	demo.load_room("wax_museum")
	for object: ExplorationInteractable in demo.room.interactables:
		if object.spec.get("item","")=="scissors":
			demo.actions.activate(object)
			demo.close_overlay()
	check(demo.session.has("scissors"),"Museum scissors unlock thread interactions")
	demo.load_room("wax_basement")
	for object: ExplorationInteractable in demo.room.interactables:
		if object.spec.get("kind","")=="mirror":
			var target: int = ExplorationCatalog.data()["mirror_solution"][int(object.spec["index"])]
			for turn: int in range(target):
				demo.actions.activate(object)
				demo.close_overlay()
	check(demo.session.has("wax_seal"),"Seven-mirror solution grants the first seal")
	demo.load_room("old_theater")
	for object: ExplorationInteractable in demo.room.interactables:
		if object.spec.get("kind","")=="thread":
			demo.actions.activate(object)
			demo.close_overlay()
	check(demo.session.satisfies(["thread_0","thread_1","thread_2"]),"All three red threads can be severed")
	demo.load_room("back_stage")
	for object: ExplorationInteractable in demo.room.interactables:
		if object.spec.get("item","")=="theater_seal":
			demo.actions.activate(object)
			demo.close_overlay()
	check(demo.session.has("doll") and demo.session.has("double_jump") and demo.session.has("vine"),"Backstage grants the doll and traversal abilities")
	demo.load_room("well_interior")
	for object: ExplorationInteractable in demo.room.interactables:
		if object.spec.get("item","")=="well_seal":
			demo.actions.activate(object)
			demo.close_overlay()
	check(demo.session.satisfies(["wax_seal","theater_seal","well_seal"]) and demo.session.has("dash"),"Third seal opens the tower and grants dash")
	await _check_earned_abilities()
	demo.load_room("clock_top")
	for object: ExplorationInteractable in demo.room.interactables:
		if object.spec.get("kind","")=="flashback":
			demo.actions.activate(object)
			demo.close_overlay()
	check(demo.session.stage==4,"Clock memory changes the same town into its fire state")
	demo.load_room("well_interior")
	for object: ExplorationInteractable in demo.room.interactables:
		if object.spec.get("kind","")=="true_memory":
			demo.actions.activate(object)
			demo.close_overlay()
	check(demo.session.has("true_memory"),"Final-loop well revisit grants the full memory")
	demo.actions._resolve_ending("accept")
	check(demo.session.has("zero_loop"),"Accepting the full memory opens the station route")
	demo.actions._resolve_ending("zero")
	check(demo.mode=="ending","True ending presentation is reachable")
	demo.close_overlay()
	demo.actions._resolve_ending("keeper")
	check(demo.mode=="ending","Keeper ending presentation is reachable")
	demo.close_overlay()
	var before: int = demo.session.loop_count
	demo.actions._resolve_ending("loop")
	check(demo.session.loop_count==before+1,"Loop ending increments the persistent loop count")
	demo.close_overlay()

func _check_save_and_ui() -> void:
	check(demo.session.save(),"Exploration save writes successfully")
	var expected_items: Dictionary = demo.session.items.duplicate()
	demo.session.items.clear()
	check(demo.session.restore() and demo.session.items==expected_items,"Save round-trip preserves inventory and progression")
	demo.mode="play"
	demo.open_map()
	check(demo.mode=="map" and demo.hud.current_map!=null and not demo.player.enabled,"Full map opens and pauses movement")
	demo.close_overlay()
	check(demo.mode=="play" and demo.player.enabled,"Closing the map restores control")
	demo.hud.show_notebook()
	check(demo.hud.overlay.get_child_count()>0,"Notebook renders collected memory records")

func _check_earned_abilities() -> void:
	await frames(20)
	check(demo.room._flood_y < 10000,"Collecting the well seal starts the rising-black-water escape")
	demo.player.position = Vector2(850,2750)
	demo.player.velocity = Vector2.ZERO
	var y_before: float = demo.player.position.y
	Input.action_press("move_up")
	await frames(20)
	Input.action_release("move_up")
	check(demo.player.position.y<y_before-45,"Earned vine ability physically climbs the well")
	var x_before: float = demo.player.position.x
	Input.action_press("move_right")
	Input.action_press("explore_dash")
	await frames(4)
	Input.action_release("explore_dash")
	Input.action_release("move_right")
	check(demo.player.position.x>x_before+30,"Earned dash travels faster than running")
	await frames(25)
	demo.player.position = Vector2(600,2840)
	demo.player.velocity = Vector2.ZERO
	await frames(5)
	Input.action_press("jump")
	await frames(20)
	Input.action_release("jump")
	await frames(2)
	Input.action_press("jump")
	await frames(3)
	check(demo.player.velocity.y < -600,"Double jump supplies a real second airborne impulse")
	Input.action_release("jump")
	await frames(80)
	demo.player.position = Vector2(1100,1600)
	demo.player.velocity = Vector2.ZERO
	await frames(5)
	demo.player.position.x = 1900
	var deaths_before: int = demo.session.deaths
	await frames(170)
	check(demo.session.deaths>deaths_before,"A long well fall triggers death instead of skipping the descent")
