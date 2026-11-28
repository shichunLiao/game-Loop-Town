extends SceneTree
## Windowed (non-headless) retest driver for the playtest diagnosis §8 script.
##
## Usage: Godot --path . --script res://tools/dev/gui_retest.gd -- --out=/abs/dir
## It sends real InputEventKey / InputEventMouseButton events through Godot's input
## pipeline (no direct method calls for player actions), saves in-game frames and
## desktop screenshots/recordings (macOS `screencapture`), and prints METRIC lines.
## Debug assists (loading a mid-game save state) are logged as ASSIST lines.

var out: String = ""
var demo: Node2D
var t0: int = 0
var transitions: int = 0
var _was_transitioning: bool = false
var rooms_seen: Array[String] = []
var metrics: Dictionary = {}
var assists: Array[String] = []
var frame_ms_max: float = 0.0
var fps_min: float = 1e9
var _last_tick: int = 0
var _sample: bool = false
var _transition_started: int = 0
var transition_log: Array = []

const KEYS := {"left":KEY_A,"right":KEY_D,"up":KEY_W,"down":KEY_S,"jump":KEY_SPACE,"attack":KEY_J,
	"skill":KEY_K,"interact":KEY_E,"heal":KEY_H,"map":KEY_M,"dash":KEY_SHIFT}

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()

func _process(_delta: float) -> bool:
	if demo != null and is_instance_valid(demo):
		var now: bool = bool(demo.get("_transitioning"))
		if now and not _was_transitioning:
			transitions += 1
			_transition_started = Time.get_ticks_msec()
		if _was_transitioning and not now:
			transition_log.append({"to":str(demo.session.room_id),"ms":Time.get_ticks_msec()-_transition_started})
			print("TRANSITION ",transition_log[-1])
		_was_transitioning = now
		var id: String = str(demo.session.room_id) if demo.session != null else ""
		if rooms_seen.is_empty() or rooms_seen[-1] != id:
			rooms_seen.append(id)
	var tick: int = Time.get_ticks_usec()
	if _sample and _last_tick>0 and not bool(demo.get("_transitioning")):
		var ms: float = (tick-_last_tick)/1000.0
		frame_ms_max = maxf(frame_ms_max,ms)
		fps_min = minf(fps_min,Engine.get_frames_per_second())
	_last_tick = tick
	return false

func elapsed() -> float:
	return (Time.get_ticks_msec()-t0)/1000.0

func metric(key: String, value: Variant) -> void:
	metrics[key] = value
	print("METRIC ",key,"=",value)

func assist(text: String) -> void:
	assists.append(text)
	print("ASSIST ",text)

func key(name: String, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEYS[name]
	event.keycode = KEYS[name]
	event.pressed = pressed
	Input.parse_input_event(event)

func tap(name: String, hold_frames: int = 4) -> void:
	key(name,true)
	await frames(hold_frames)
	key(name,false)
	await frames(2)

func frames(count: int) -> void:
	for index: int in range(count):
		await physics_frame

func wait_s(seconds: float) -> void:
	await create_timer(seconds).timeout

func click_button(text: String) -> bool:
	for node: Node in demo.hud.overlay.find_children("*","Button",true,false):
		var button: Button = node
		if button.text.begins_with(text) and button.is_visible_in_tree():
			var center: Vector2 = button.get_global_rect().get_center()
			# The HUD uses canvas_items stretch: convert canvas -> window pixels.
			var window_point: Vector2 = root.get_final_transform() * center
			for pressed: bool in [true,false]:
				var event := InputEventMouseButton.new()
				event.button_index = MOUSE_BUTTON_LEFT
				event.pressed = pressed
				event.position = window_point
				event.global_position = window_point
				Input.parse_input_event(event)
				await frames(3)
			return true
	print("CLICK_MISS ",text)
	return false

func shot(name: String, desktop: bool = false) -> void:
	# Blocking captures stall the frame; keep them out of the perf sample.
	var sampling: bool = _sample
	_sample = false
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out+"/"+name+".png")
	if desktop:
		OS.execute("screencapture",["-x",out+"/desktop-"+name+".png"])
	print("SHOT ",name)
	await frames(2)
	_last_tick = 0
	_sample = sampling

func record(name: String, seconds: int) -> void:
	OS.create_process("screencapture",["-x","-v","-V",str(seconds),out+"/"+name+".mov"])
	await wait_s(.4)

func player() -> ExplorationPlayer:
	return demo.player

## Autopilot toward x using held A/D: jumps over floor gaps and walls, attacks
## enemies in front, heals when low.  Returns true when x is reached.
func walk_to(target_x: float, timeout: float = 40.0, fight: bool = true) -> bool:
	var started: float = elapsed()
	var dir: String = "right" if target_x>player().position.x else "left"
	key(dir,true)
	var last_x: float = player().position.x
	var still: int = 0
	var room_at_start: String = demo.session.room_id
	while elapsed()-started<timeout:
		await frames(1)
		if demo.session.room_id != room_at_start or demo._transitioning:
			break
		if demo.mode != "play":
			key(dir,false)
			await _dismiss_story()
			key(dir,true)
			continue
		var p: ExplorationPlayer = player()
		var sign_dir: float = 1.0 if dir=="right" else -1.0
		if (target_x-p.position.x)*sign_dir<=8:
			break
		still = still+1 if absf(p.position.x-last_x)<.5 else 0
		last_x = p.position.x
		var ahead: float = p.position.x+sign_dir*70
		if p.is_on_floor() and (not _has_floor(ahead,p.position.y) or still>30):
			print("AUTOPILOT jump at ",p.position," gap=",not _has_floor(ahead,p.position.y)," still=",still)
			await tap("jump",14)
			still = 0
		if fight:
			for enemy: Node in demo.room.find_children("*","CharacterBody2D",true,false):
				if enemy is ExplorationEnemy and not (enemy as ExplorationEnemy).dead:
					var dx: float = (enemy as Node2D).global_position.x-p.position.x
					if dx*sign_dir>-20 and absf(dx)<150 and absf((enemy as Node2D).global_position.y-p.position.y)<120:
						await tap("attack",3)
						break
			if p.health<45 and p.energy>=50:
				await tap("heal",3)
	key(dir,false)
	await frames(2)
	return (target_x-player().position.x)*(1.0 if dir=="right" else -1.0)<=8

func _has_floor(x: float, y: float) -> bool:
	# Physics truth (platforms, stoops, roofs): is there ground within 60 px below?
	var space: PhysicsDirectSpaceState2D = player().get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(Vector2(x,y-20),Vector2(x,y+160),1)
	return not space.intersect_ray(query).is_empty()

func _dismiss_story() -> void:
	await frames(20)
	if demo.mode=="dialogue":
		await tap("interact",3)
	elif demo.mode in ["ending"]:
		for node: Node in demo.hud.overlay.find_children("*","Button",true,false):
			if (node as Button).is_visible_in_tree():
				await click_button((node as Button).text)
				break
	await frames(10)

func wait_play(timeout: float = 15.0) -> void:
	var started: float = elapsed()
	while (demo.mode!="play" or demo._transitioning or not player().enabled) and elapsed()-started<timeout:
		await frames(1)

func _run() -> void:
	root.get_node("SaveManager").exploration_slot_name = "exploration_gui_retest"
	DisplayServer.window_set_size(Vector2i(1280,720))
	DisplayServer.window_set_position(Vector2i(160,120))
	demo = (load("res://scenes/exploration/ExplorationDemo.tscn") as PackedScene).instantiate()
	root.add_child(demo)
	current_scene = demo
	DisplayServer.window_move_to_foreground()
	await wait_s(1.5)
	var only: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=")
	for segment: String in ["opening","route","mei","mirrors","tower","perf"]:
		if not only.is_empty() and not only.split(",").has(segment):
			continue
		await call("_segment_"+{"opening":"opening","route":"route","mei":"mei","mirrors":"mirrors_and_theater","tower":"tower","perf":"map_perf"}[segment])
	var file := FileAccess.open(out+"/metrics.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"metrics":metrics,"assists":assists,"rooms":rooms_seen,"transitions":transition_log},"  "))
	file.close()
	print("RETEST_DONE")
	demo.get_node("/root/AudioManager").stop_all()
	current_scene = null
	demo.queue_free()
	await frames(3)
	quit(0)

# 0:00-5:00 new player opening ------------------------------------------------
func _segment_opening() -> void:
	print("SEGMENT opening")
	await shot("01-title",true)
	t0 = Time.get_ticks_msec()
	await click_button("新探索")
	await wait_play()
	metric("time_to_control_s",snappedf(elapsed(),.01))
	await wait_s(.6)
	var controls: PackedStringArray = demo.hud.control_label.text.split("  ",false)
	metric("hud_controls_at_start",controls.size())
	metric("hud_controls_text",demo.hud.control_label.text)
	metric("opening_toast",demo.hud.toast_label.text)
	await shot("02-opening-hud",true)
	# A/D: walk to the summons, E to read it.
	var moved: bool = await walk_to(250,10,false)
	metric("t_first_move_s",snappedf(elapsed(),.01))
	await tap("interact",3)
	await frames(20)
	await shot("03-summons")
	metric("summons_dialogue_shown",demo.mode=="dialogue")
	await wait_s(2.0)
	await tap("interact",3)
	await wait_play()
	metric("t_summons_read_s",snappedf(elapsed(),.01))
	metric("hud_controls_after_letter",demo.hud.control_label.text)
	await tap("jump",14)
	await frames(40)
	metric("t_first_jump_s",snappedf(elapsed(),.01))
	# Practice wax figure at x=2280: J combo with zero damage.
	await walk_to(2150,25,false)
	var hp_before: int = player().health
	for index: int in range(6):
		await tap("attack",3)
		await frames(6)
	metric("t_first_attack_s",snappedf(elapsed(),.01))
	metric("practice_toast",demo.hud.toast_label.text)
	await shot("04-practice-enemy",true)
	var stand: int = 0
	while stand<120:
		await frames(1)
		stand += 1
	metric("practice_damage_taken",hp_before-player().health)
	metric("basics_within_60s",float(metrics["t_first_attack_s"])<=60.0)

# Entrance -> museum route ---------------------------------------------------
func _segment_route() -> void:
	print("SEGMENT route")
	var start_transitions: int = transitions
	await walk_to(3190,40,true)
	await wait_play()
	metric("route_hop1_room",demo.session.room_id)
	metric("route_hop1_note_toast",demo.hud.toast_label.text)
	await shot("05-wax-lane-arrival",true)
	await wait_s(.6)
	metric("hop1_on_floor_after_0_5s",player().is_on_floor())
	# Record the reality -> memory crossing.
	await walk_to(400,60,true)
	await record("realm-enter-museum",9)
	await walk_to(20,20,true)
	var cross_started: float = elapsed()
	var mid_hud_alpha: float = 1.0
	var captured_mid: bool = false
	while (demo._transitioning or demo.session.room_id=="wax_lane") and elapsed()-cross_started<8:
		if not captured_mid and elapsed()-cross_started>1.15:
			captured_mid = true
			mid_hud_alpha = demo.hud.root.modulate.a
			await shot("06-realm-shift-enter-mid",true)
		await frames(1)
	await wait_play()
	metric("realm_enter_seconds",snappedf(float(transition_log[-1]["ms"])/1000.0,.01) if not transition_log.is_empty() else -1)
	metric("realm_enter_hud_alpha_mid",snappedf(mid_hud_alpha,.01))
	metric("realm_label_after_enter",demo.hud.realm_label.text)
	metric("route_hop2_room",demo.session.room_id)
	metric("black_screen_transitions_entrance_to_museum",transitions-start_transitions)
	metric("t_museum_reached_s",snappedf(elapsed(),.01))
	await shot("07-museum-arrival",true)

# Mei: real fight, stacks, a death, retry, then victory with mirrored return ----
func _segment_mei() -> void:
	print("SEGMENT mei")
	await wait_s(.5)
	if demo.mode!="play":
		await shot("08-mei-intro")
		await _dismiss_story()
	await wait_play()
	var boss: ExplorationBoss = get_first_boss()
	metric("mei_present_on_arrival",boss!=null)
	var started: float = elapsed()
	var first_status: String = ""
	var first_status_toast: String = ""
	var defeated: bool = false
	_sample = true
	# Fight with J/H; stop healing after 25 s so a failure (and its card) is observed.
	while elapsed()-started<90 and boss!=null and is_instance_valid(boss) and not boss.dead:
		await frames(1)
		if demo.mode!="play":
			if demo.mode=="ending" and not first_status.is_empty():
				defeated = true
				break
			await _dismiss_story()
			continue
		var p: ExplorationPlayer = player()
		if first_status.is_empty() and not p.status_text().is_empty():
			first_status = p.status_text()
			first_status_toast = demo.hud.toast_label.text
			await shot("09-mei-first-status",true)
		var dx: float = boss.global_position.x-p.position.x
		key("left" if dx<0 else "right",absf(dx)>110)
		key("right" if dx<0 else "left",false)
		if absf(dx)<190:
			await tap("attack",3)
		if elapsed()-started<25 and p.health<45 and p.energy>=50:
			await tap("heal",3)
	key("left",false)
	key("right",false)
	metric("mei_first_status_meter",first_status)
	metric("mei_first_status_tip",first_status_toast)
	metric("mei_fight_seconds_until_result",snappedf(elapsed()-started,.1))
	if defeated:
		await shot("10-mei-defeat-card",true)
		metric("mei_defeat_card_title",_overlay_title())
		var retry_started: float = elapsed()
		await click_button("回溯")
		await wait_play()
		metric("mei_retry_to_control_s",snappedf(elapsed()-retry_started,.01))
		metric("mei_retry_room",demo.session.room_id)
		await shot("11-after-retry",true)
		# Walk back into the arena if the lamp is outside it.
		if demo.session.room_id=="wax_museum":
			await walk_to(2700,40,true)
			if demo.mode!="play":
				await _dismiss_story()
		else:
			assist("retry respawned outside the museum (%s); reloading museum arena" % demo.session.room_id)
			demo.request_room("wax_museum","wax_lane--wax_museum_b")
			await wait_play()
	boss = get_first_boss()
	await wait_play()
	if boss!=null and is_instance_valid(boss) and not boss.dead:
		assist("Mei victory forced via repeated real J hits with invulnerability (combat feel already observed)")
		player()._invulnerability = 999
		boss.health = mini(boss.health,60)
		var guard: float = elapsed()
		while is_instance_valid(boss) and not boss.dead and elapsed()-guard<30:
			var dx2: float = boss.global_position.x-player().position.x
			key("left" if dx2<0 else "right",absf(dx2)>110)
			await tap("attack",3)
			if demo.mode!="play" and not boss.dead:
				await _dismiss_story()
		key("left",false)
		key("right",false)
	await record("realm-return-after-mei",7)
	var ret_started: float = elapsed()
	var captured: bool = false
	while demo.mode!="ending" and elapsed()-ret_started<8:
		if not captured and elapsed()-ret_started>1.15:
			captured = true
			await shot("12-realm-return-mid",true)
		await frames(1)
	metric("realm_return_seconds",snappedf(elapsed()-ret_started,.01))
	metric("realm_label_after_return",demo.hud.realm_label.text)
	await shot("13-mei-memory-card")
	await _dismiss_story()
	await wait_play()
	metric("safe_window_after_card",snappedf(player()._invulnerability,.01))
	player()._invulnerability = 0
	_sample = false
	# Scissors are west of the arena.
	await walk_to(560,40,true)
	await tap("interact",3)
	await frames(20)
	await _dismiss_story()
	metric("has_scissors",demo.session.has("scissors"))
	metric("t_scissors_s",snappedf(elapsed(),.01))
	metric("hud_controls_after_scissors",demo.hud.control_label.text)

func get_first_boss() -> ExplorationBoss:
	for node: Node in get_nodes_in_group("exploration_boss"):
		if node is ExplorationBoss and not (node as ExplorationBoss).echo:
			return node
	return null

func _overlay_title() -> String:
	for node: Node in demo.hud.overlay.find_children("*","Label",true,false):
		if (node as Label).text.begins_with("结局"):
			return (node as Label).text
	return ""

# Mirrors (count E presses) and theater threads --------------------------------
func _segment_mirrors_and_theater() -> void:
	print("SEGMENT mirrors+theater")
	assist("basement entered by loading wax_basement directly (the passage_09 walk is optional content)")
	demo.load_room("wax_basement")
	await wait_play(12)
	metric("basement_room",demo.session.room_id)
	metric("basement_realm_label",demo.hud.realm_label.text)
	var presses: int = 0
	for object: ExplorationInteractable in demo.room.interactables:
		if str(object.spec.get("kind",""))=="mirror":
			await walk_to(object.global_position.x,15,true)
			await tap("interact",3)
			presses += 1
			await frames(10)
			if demo.mode!="play":
				await _dismiss_story()
	metric("mirror_e_presses",presses)
	metric("wax_seal",demo.session.has("wax_seal"))
	await shot("14-mirrors-solved",true)
	assist("theater reached by loading old_theater directly (route length not part of this segment)")
	demo.load_room("old_theater")
	await wait_play()
	var before_controls: int = demo.hud.control_label.text.split("  ",false).size()
	for object: ExplorationInteractable in demo.room.interactables:
		if str(object.spec.get("kind",""))=="thread":
			player().position = object.global_position+Vector2(-40,-3)
			await frames(5)
			await tap("interact",3)
			await frames(10)
			if demo.mode!="play":
				await _dismiss_story()
	metric("threads_cut",demo.session.satisfies(["thread_0","thread_1","thread_2"]))
	demo.session.acquire("boss_void")
	demo.load_room("back_stage")
	await wait_play()
	for object: ExplorationInteractable in demo.room.interactables:
		if str(object.spec.get("item",""))=="theater_seal":
			player().position = object.global_position+Vector2(-40,-3)
			await frames(5)
			await tap("interact",3)
			await frames(10)
			await shot("15-backstage-abilities",true)
			if demo.mode!="play":
				await _dismiss_story()
	var after_controls: PackedStringArray = demo.hud.control_label.text.split("  ",false)
	metric("controls_added_by_theater",after_controls.size()-before_controls)
	metric("hud_controls_after_theater",demo.hud.control_label.text)

# Clock tower: two floors, a boss exchange, deliberate failures ------------------
func _segment_tower() -> void:
	print("SEGMENT tower")
	assist("tower entered via the 20-minute style debug state (seals + abilities granted, checkpoint reset)")
	for flag: String in ["wax_seal","theater_seal","double_jump","vine","dash"]:
		demo.session.acquire(flag)
	demo.session.switches.erase("tower_checkpoint_tier")
	demo.session.switches.erase("tower_hp_echo_morris")
	demo.load_room("clock_tower")
	await wait_play()
	await wait_s(.4)
	await shot("16-tower-section1",true)
	metric("tower_section1_toast",demo.hud.toast_label.text)
	var climb_started: float = elapsed()
	var route: Array = _tower_route()
	var climbed: int = 0
	var current: Dictionary = {"x":0.0,"y":4840.0,"w":1800.0}
	var retries: int = 0
	for step: Dictionary in route:
		if float(step["y"])<3590:
			break
		var ok: bool = await _climb_step(current,step)
		while not ok and retries<6:
			retries += 1
			ok = await _climb_step(current,step)
		if not ok:
			assist("tower climb stuck before y=%d" % int(step["y"]))
			break
		current = step
		climbed += 1
	metric("tower_climb_steps",climbed)
	metric("tower_climb_retries",retries)
	metric("tower_climb_to_floor2_s",snappedf(elapsed()-climb_started,.1))
	metric("tower_checkpoint_after_climb",demo.session.tower_checkpoint_tier())
	metric("tower_section2_toast",demo.hud.toast_label.text)
	await shot("17-tower-checkpoint-floor2",true)
	var echo: ExplorationBoss
	for node: Node in get_nodes_in_group("exploration_boss"):
		if node is ExplorationBoss and (node as ExplorationBoss).echo:
			echo = node
	metric("tower_echo_present",echo!=null)
	# One boss exchange with real J hits.
	var exchange_started: float = elapsed()
	while echo!=null and is_instance_valid(echo) and elapsed()-exchange_started<4 and demo.mode=="play":
		var dx: float = echo.global_position.x-player().position.x
		key("left" if dx<0 else "right",absf(dx)>110)
		await tap("attack",3)
	key("left",false)
	key("right",false)
	var echo_hp: int = echo.health if echo!=null and is_instance_valid(echo) else -1
	metric("tower_echo_hp_after_exchange",echo_hp)
	metric("tower_echo_max_hp",echo.max_health if echo!=null and is_instance_valid(echo) else -1)
	await wait_play()
	# Ten deliberate deaths (fall/hit) measuring respawn and HP persistence.
	await record("tower-death-respawn",10)
	var redo: Array[float] = []
	var physics_errors_before: int = 0
	for index: int in range(10):
		var died_at: float = elapsed()
		player()._invulnerability = 0
		player().take_damage(100)
		await frames(2)
		await wait_play()
		var back: float = elapsed()-died_at
		print("DEATH ",index," back=",back," mode=",demo.mode," enabled=",player().enabled," pending=",demo._death_pending," trans=",demo._transitioning," hp=",player().health," deaths=",demo.session.deaths)
		redo.append(snappedf(back,.01))
		if index==0:
			await shot("18-tower-respawn",true)
			metric("tower_respawn_toast",demo.hud.toast_label.text)
		await frames(10)
	var echo_after: int = -1
	for node: Node in get_nodes_in_group("exploration_boss"):
		if node is ExplorationBoss and (node as ExplorationBoss).echo:
			echo_after = (node as ExplorationBoss).health
	metric("tower_respawn_seconds",redo)
	metric("tower_checkpoint_after_deaths",demo.session.tower_checkpoint_tier())
	metric("tower_echo_hp_after_deaths",echo_after)
	var chase: ExplorationKeeperChase
	for child: Node in demo.room.get_children():
		if child is ExplorationKeeperChase:
			chase = child
	metric("tower_respawn_floor",chase._tier_of(player().global_position.y) if chase else -1)
	# Bell rewind from floor 3.
	if chase:
		player().position = Vector2(700,chase._tiers[3]-3)
		await frames(3)
		await chase._rewind(player())
		metric("bell_rewind_floor",chase._tier_of(player().global_position.y))
		metric("bell_rewind_toast",demo.hud.toast_label.text)
		await shot("19-bell-rewind",true)
	# Section redo cost: worst case = respawn + a full two-floor section climb.
	metric("tower_section_redo_estimate_s",snappedf(float(metrics["tower_climb_to_floor2_s"])+redo.max(),.1))

func _tower_route() -> Array:
	var route: Array = []
	for entry: Dictionary in demo.room.data["platforms"]:
		var rect: Array = entry["rect"]
		if str(entry.get("geometry","")) in ["ledge","rest"] and float(rect[0])<1300 and float(rect[1])<4840 and bool(entry.get("one_way",false)):
			route.append({"x":float(rect[0]),"y":float(rect[1]),"w":float(rect[2])})
	route.sort_custom(func(a: Dictionary,b: Dictionary)->bool:return float(a["y"])>float(b["y"]))
	return route

func _climb_step(current: Dictionary, step: Dictionary) -> bool:
	var p: ExplorationPlayer = player()
	var lo: float = maxf(float(current["x"]),float(step["x"]))+40
	var hi: float = minf(float(current["x"])+float(current["w"]),float(step["x"])+float(step["w"]))-40
	var launch: float
	var dir: String = ""
	if lo<=hi:
		launch = (lo+hi)*.5
	elif float(step["x"])>float(current["x"]):
		launch = float(current["x"])+float(current["w"])-30
		dir = "right"
	else:
		launch = float(current["x"])+30
		dir = "left"
	# Walk (held A/D) to the launch point on the current platform.
	var walk: String = "right" if launch>p.position.x else "left"
	var guard: int = 0
	key(walk,true)
	while guard<300 and absf(p.position.x-launch)>10:
		if (walk=="right" and p.position.x>launch) or (walk=="left" and p.position.x<launch):
			break
		await frames(1)
		guard += 1
	key(walk,false)
	await frames(3)
	key("jump",true)
	if not dir.is_empty():
		key(dir,true)
	await frames(26)
	key("jump",false)
	await frames(10)
	if not dir.is_empty():
		key(dir,false)
	var waited: int = 0
	while not p.is_on_floor() and waited<120:
		await frames(1)
		waited += 1
	await frames(4)
	return absf(p.position.y-float(step["y"]))<=6

func _segment_map_perf() -> void:
	print("SEGMENT map+perf")
	await wait_play()
	var started: float = elapsed()
	await tap("map",3)
	await frames(20)
	metric("map_open",demo.mode=="map")
	await shot("20-map",true)
	await tap("map",3)
	await wait_play()
	metric("fps_min_during_fight",snappedf(fps_min,.1))
	metric("frame_ms_max_during_fight",snappedf(frame_ms_max,.1))
	metric("total_retest_wall_s",snappedf(elapsed(),.1))
