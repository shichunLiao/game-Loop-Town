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
	await _check_area_death_regression()
	await _check_all_exit_spawns()
	await _check_continuous_transitions()
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
	# Geometry isolation: suppress boss intros and story grabs so every authored
	# arrival receives the full 0.5 s physics-settle window under player control.
	for flag: String in ["boss_morris","boss_void","boss_ling","fury_done","keeper_truth","echo_morris","echo_void"]:
		demo.session.items[flag] = true
	demo.mode = "play"
	demo.hud.overlay.hide()
	for id: String in rooms:
		for exit: Dictionary in rooms[id]["exits"]:
			var target: String = str(exit["target"])
			var reciprocal: bool = false
			for incoming: Dictionary in rooms[target]["exits"]:
				if str(incoming["id"])==str(exit["id"]) and str(incoming["target"])==id:
					reciprocal = true
			valid = valid and reciprocal
			demo._health = 100
			demo.load_room.call_deferred(target,str(exit["id"]))
			await process_frame
			demo.player.grant_safe_window(2.0)
			await frames(31)
			var in_bounds: bool = Rect2(Vector2.ZERO,demo.room.bounds).has_point(demo.player.position)
			valid = valid and demo.player.is_on_floor() and in_bounds
			if not demo.player.is_on_floor():
				print("UNSAFE EXIT ",id," -> ",target," ",demo.player.position)
			count += 1
	check(valid,"All %d reciprocal exits spawn above safe collidable ground" % count)
	check(count==92,"Demo 9 has exactly 92 directed exits")
	check(rooms.size()==69,"All 69 Demo 9 room scenes instantiate")

func _check_continuous_transitions() -> void:
	var safe: bool = true
	demo.mode = "play"
	demo.hud.overlay.hide()
	for round_index: int in range(10):
		demo.load_room("town_entrance")
		demo.player.grant_safe_window(2.0)
		await frames(3)
		demo.request_room("passage_00","town_entrance--ring_west_a")
		while demo._transitioning:
			await frames(1)
		await frames(31)
		safe = safe and demo.session.room_id=="wax_lane" and demo.player.is_on_floor()
		if not demo.player.is_on_floor():
			print("CONTINUOUS ROUTE UNSAFE town -> wax_lane round ",round_index," at ",demo.player.position)
		demo.request_room("passage_05","ring_west--wax_lane_b")
		while demo._transitioning:
			await frames(1)
		await frames(31)
		safe = safe and demo.session.room_id=="town_entrance" and demo.player.is_on_floor()
		if not demo.player.is_on_floor():
			print("CONTINUOUS ROUTE UNSAFE wax_lane -> town round ",round_index," at ",demo.player.position)
	check(safe,"Ten continuous first-chapter round trips never fall through geometry")

func _check_area_death_regression() -> void:
	demo.load_room("town_entrance")
	await frames(10)
	var before: int = demo.session.deaths
	var safe: bool = true
	for index: int in range(30):
		var hit := ExplorationHitArea.new()
		hit.damage = 999
		hit.target_layer = 8
		hit.dimensions = Vector2(70,90)
		hit.position = demo.player.position+Vector2(0,-31)
		hit.lifetime = .3
		demo.add_child(hit)
		await frames(75)
		safe = safe and demo.mode=="play" and demo.player.health==100
	check(safe and demo.session.deaths==before+30,"30 Area2D kills respawn through deferred physics-safe flow")

func _check_vertical_route() -> void:
	# Geometry pass with the chase settled so limbs/echoes cannot mask a missing step.
	demo.session.items["echo_morris"] = true
	demo.session.items["echo_void"] = true
	demo.mode = "play"
	demo.hud.overlay.hide()
	demo.load_room("clock_tower")
	await frames(31)
	var tiers: Array[float] = []
	var route: Array[Dictionary] = []
	for entry: Dictionary in demo.room.data["platforms"]:
		var rect: Array = entry["rect"]
		var geometry: String = str(entry.get("geometry",""))
		if geometry in ["ground","rest"] and float(rect[2])>1000:
			tiers.append(float(rect[1]))
		# Main climbing column: every static ledge/rest left of the lift wall.
		if geometry in ["ledge","rest"] and float(rect[0])<1300 and float(rect[1])<4840 and bool(entry.get("one_way",false)):
			route.append({"x":float(rect[0]),"y":float(rect[1]),"w":float(rect[2])})
	tiers.sort()
	route.sort_custom(func(a: Dictionary,b: Dictionary)->bool:return float(a["y"])>float(b["y"]))
	check(tiers.size()==8,"Clock tower has ground + seven rest floors for three checkpoint sections")
	# Physically climb the whole tower with base jumps and real input actions.
	demo.player.grant_safe_window(999)
	var current: Dictionary = {"x":0.0,"y":4840.0,"w":1800.0}
	demo.player.position = Vector2(300,4837)
	demo.player.velocity = Vector2.ZERO
	await frames(10)
	var jumps: int = 0
	var started_ms: int = Time.get_ticks_msec()
	var sim_frames: int = 0
	var blocked: bool = false
	for step: Dictionary in route:
		var lo: float = maxf(float(current["x"]),float(step["x"]))+40
		var hi: float = minf(float(current["x"])+float(current["w"]),float(step["x"])+float(step["w"]))-40
		var direction: String = ""
		if lo<=hi:
			demo.player.position.x = (lo+hi)*.5
		elif float(step["x"])>float(current["x"]):
			demo.player.position.x = float(current["x"])+float(current["w"])-30
			direction = "move_right"
		else:
			demo.player.position.x = float(current["x"])+30
			direction = "move_left"
		demo.player.velocity = Vector2.ZERO
		await frames(4)
		Input.action_press("jump")
		if not direction.is_empty():
			Input.action_press(direction)
		await frames(26)
		Input.action_release("jump")
		await frames(10)
		if not direction.is_empty():
			Input.action_release(direction)
		var waited: int = 0
		while not demo.player.is_on_floor() and waited<90:
			await frames(1)
			waited += 1
		sim_frames += 40+waited+4
		jumps += 1
		if absf(demo.player.position.y-float(step["y"]))>6 or not demo.player.is_on_floor():
			print("VERTICAL BLOCK step ",jumps," player=",demo.player.position," target=",step)
			blocked = true
			break
		current = step
	check(not blocked and demo.player.position.y<=195,"Entire seven-floor tower is physically climbable with base jumps (%d jumps)" % jumps)
	# A two-floor checkpoint section is ~1/3 of the climb; redo = respawn fade + section climb.
	var section_seconds: float = float(sim_frames)/60.0*2.0/7.0+0.7
	print("TOWER_SECTION_REDO_SECONDS ",snappedf(section_seconds,.1)," full_climb_sim_s=",snappedf(float(sim_frames)/60.0,.1)," wall_ms=",Time.get_ticks_msec()-started_ms)
	check(section_seconds<90.0,"One checkpoint section can be redone in under 90 s (%.1f s simulated)" % section_seconds)
	var moving: ExplorationPlatform
	for platform: ExplorationPlatform in demo.room.platforms:
		if platform.manual_lift:
			moving = platform
			break
	var before: Vector2 = moving.position
	demo.session.switches[moving.lift_unlock] = true
	demo.session.switches[moving.lift_up] = true
	await frames(45)
	check(moving.position.distance_to(before)>200 and moving.position.y<before.y,"Mechanical elevator moves under physics once unlocked")
	demo.session.switches.erase(moving.lift_up)
	await frames(10)
	demo.session.switches.erase(moving.lift_unlock)
	demo.session.items.erase("echo_morris")
	demo.session.items.erase("echo_void")

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
	var mirror_presses: int = 0
	for object: ExplorationInteractable in demo.room.interactables:
		if object.spec.get("kind","")=="mirror":
			mirror_presses += 1
			demo.actions.activate(object)
			demo.close_overlay()
	check(demo.session.has("wax_seal") and mirror_presses==7,"Seven mirrors solve in seven deliberate interactions (%d)" % mirror_presses)
	demo.load_room("old_theater")
	for object: ExplorationInteractable in demo.room.interactables:
		if object.spec.get("kind","")=="thread":
			demo.actions.activate(object)
			demo.close_overlay()
	check(demo.session.satisfies(["thread_0","thread_1","thread_2"]),"All three red threads can be severed")
	demo.load_room("back_stage")
	demo.session.acquire("boss_void")
	for object: ExplorationInteractable in demo.room.interactables:
		if object.spec.get("item","")=="theater_seal":
			demo.actions.activate(object)
			demo.close_overlay()
	check(demo.session.has("doll") and demo.session.has("double_jump") and demo.session.has("vine") and demo.session.has("dash"),"Backstage grants the doll and staged traversal abilities")
	demo.session.acquire("echo_morris")
	demo.session.acquire("echo_void")
	check(demo.session.chase_done(),"Both persistent clock-tower echoes unlock the final choice section")
	await _check_earned_abilities()
	demo.load_room("clock_top")
	for object: ExplorationInteractable in demo.room.interactables:
		if object.spec.get("kind","")=="flashback":
			demo.actions.activate(object)
			demo.close_overlay()
	check(demo.session.stage==4 and demo.session.has("clock_memory"),"Clock memory opens the final reality section")
	demo.session.acquire("keeper_truth")
	demo.session.acquire("boss_ling")
	demo.load_room("well_interior")
	await _check_well_traversal()
	for object: ExplorationInteractable in demo.room.interactables:
		if object.spec.get("item","")=="well_seal":
			demo.actions.activate(object)
			demo.close_overlay()
	for object: ExplorationInteractable in demo.room.interactables:
		if object.spec.get("kind","")=="true_memory":
			demo.actions.activate(object)
			demo.close_overlay()
	check(demo.session.has("true_memory"),"Final-loop well revisit grants the full memory")
	demo.actions._confirm_ending("accept")
	check(demo.mode=="dialogue","Keeper's hat after the truth points Jerry back to the well")
	demo.close_overlay()
	demo.actions._resolve_ending("zero")
	check(demo.mode=="ending","True ending presentation is reachable")
	demo.close_overlay()
	demo.actions._resolve_ending("keeper")
	check(demo.mode=="ending","Keeper ending presentation is reachable")
	demo.close_overlay()
	var loops_before: int = demo.session.loop_count
	demo.actions._resolve_ending("loop")
	check(demo.session.loop_count==loops_before+1,"Loop ending increments the persistent loop count")
	demo.close_overlay()

func _check_save_and_ui() -> void:
	check(demo.session.save(),"Exploration save writes successfully")
	var expected_items: Dictionary = demo.session.items.duplicate()
	demo.session.items.clear()
	var restored: bool = demo.session.restore()
	var preserved: bool = restored
	for id: String in expected_items:
		preserved = preserved and demo.session.items.has(id)
	check(preserved,"Save round-trip preserves inventory and applies compatible Demo 9 grants")
	demo.mode="play"
	demo.open_map()
	check(demo.mode=="map" and demo.hud.current_map!=null and not demo.player.enabled,"Full map opens and pauses movement")
	demo.close_overlay()
	check(demo.mode=="play" and demo.player.enabled,"Closing the map restores control")
	demo.hud.show_notebook()
	check(demo.hud.overlay.get_child_count()>0,"Notebook renders collected memory records")

func _check_earned_abilities() -> void:
	await frames(20)
	check(demo.session.has("vine") and demo.session.has("dash") and demo.session.has("double_jump"),"Demo 9 traversal unlock flags persist together")
	var x_before: float = demo.player.position.x
	Input.action_press("move_right")
	Input.action_press("explore_dash")
	await frames(4)
	Input.action_release("explore_dash")
	Input.action_release("move_right")
	check(demo.player.position.x>x_before+30,"Earned dash travels faster than running")
	await frames(25)
	demo.player.position = Vector2(600,demo.room.data["floor"]-3)
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

func _check_well_traversal() -> void:
	demo.mode = "play"
	demo.hud.overlay.hide()
	await frames(20)
	var vine: Array = demo.room.data["vines"][1]
	demo.player.position = Vector2(float(vine[0])+float(vine[2])*.5,float(vine[1])+float(vine[3])-60)
	demo.player.velocity = Vector2.ZERO
	await frames(3)
	var y_before: float = demo.player.position.y
	Input.action_press("move_up")
	await frames(20)
	Input.action_release("move_up")
	check(demo.player.position.y<y_before-45,"Earned vine ability physically climbs the well")
	await frames(10)
	demo.player.grant_safe_window(0)
	demo.player._invulnerability = 0
	var deaths_before: int = demo.session.deaths
	# The open shaft between the inner wall and the side rests drops straight to the
	# lift dock at the well floor (~2500 px), far past the 650 px survivable fall.
	for platform: ExplorationPlatform in demo.room.platforms:
		if platform.manual_lift:
			demo.session.switches.erase(platform.lift_up)
	await frames(60)
	demo.player.position = Vector2(1800,300)
	demo.player.velocity = Vector2.ZERO
	demo.player._last_ground_y = 300
	var waited: int = 0
	while demo.session.deaths==deaths_before and waited<240:
		await frames(1)
		waited += 1
	check(demo.session.deaths>deaths_before,"A long well fall triggers death instead of skipping the descent")
	while demo.mode!="play" or demo._death_pending or demo._fade.color.a>.01:
		await frames(1)
	await frames(10)
	demo.load_room("well_interior")
	await frames(10)
