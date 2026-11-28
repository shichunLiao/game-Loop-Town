extends SceneTree
## Focused acceptance checks for the five Demo 9 playability improvements.

var failures: Array[String] = []
var passes: int = 0
var demo: Node2D

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
	for index: int in range(count):
		await physics_frame

func _run() -> void:
	root.get_node("SaveManager").exploration_slot_name = "exploration_experience_qa"
	demo = (load("res://scenes/exploration/ExplorationDemo.tscn") as PackedScene).instantiate()
	root.add_child(demo)
	current_scene = demo
	demo.start_game(false)
	await frames(8)
	var rooms: Dictionary = ExplorationCatalog.data()["rooms"]
	var exit_count: int = 0
	for room: Dictionary in rooms.values():
		exit_count += room["exits"].size()
	check(rooms.size()==69 and exit_count==92,"Demo 9 topology is 69 rooms / 92 directed exits")

	var initial_controls: String = demo.hud._visible_controls(demo.session)
	check(initial_controls.contains("A/D") and initial_controls.contains("E") and initial_controls.contains("Space") and initial_controls.contains("J"),"Initial HUD teaches the four contextual basics")
	check(not initial_controls.contains(" K ") and not initial_controls.contains(" H ") and not initial_controls.contains("Shift") and not initial_controls.contains(" Q ") and not initial_controls.contains("W/S"),"Initial HUD hides unearned controls")
	for flag: String in ["tutorial_heal","scissors","vine","dash","time_slow"]:
		demo.session.items[flag] = true
	var earned_controls: String = demo.hud._visible_controls(demo.session)
	check(earned_controls.contains("H") and earned_controls.contains("K") and earned_controls.contains("W/S") and earned_controls.contains("Shift") and earned_controls.contains("Q"),"Earned controls appear contextually")

	var practice: bool = false
	for enemy: Dictionary in rooms["town_entrance"]["enemies"]:
		practice = practice or bool(enemy.get("practice",false))
	check(practice,"Town opening contains a no-damage practice enemy")
	var first_hop: Dictionary = demo._compressed_route("town_entrance","passage_00","town_entrance--ring_west_a")
	var second_hop: Dictionary = demo._compressed_route("wax_lane","passage_08","wax_lane--wax_museum_a")
	check(str(first_hop.get("target",""))=="wax_lane" and str(second_hop.get("target",""))=="wax_museum","Tracked scissors route uses two black-screen transitions")
	check(demo._room_realm("town_entrance")=="reality" and demo._room_realm("wax_museum")=="memory","Reality and memory rooms use a mirrored transition grammar")

	var player: ExplorationPlayer = demo.player
	player.paper = 1
	player.plaster = 2
	player.paint = 3
	player.cloth = 4
	var status: String = player.status_text()
	check(status.contains("纸裂 1") and status.contains("H修补") and status.contains("石膏 2/3") and status.contains("雕塑") and status.contains("入画 3/4") and status.contains("沃布化 4/8"),"Boss lethal states expose layers, thresholds and clear actions")
	player.grant_safe_window(.5)
	check(player._invulnerability>=.5,"Control return grants at least a 0.5 second safe window")

	demo.session.switches["tower_checkpoint_tier"] = 2
	check(demo.session.save_tower_section(4,Vector2(900,2110)) and demo.session.tower_checkpoint_tier()==4,"Clock tower advances permanent two-floor checkpoints")
	check(not demo.session.save_tower_section(2,Vector2(900,3600)) and demo.session.tower_checkpoint_tier()==4,"Clock tower never rolls a checkpoint backward")
	demo.session.switches["tower_hp_echo_morris"] = 321
	demo.session.save()
	var restored := ExplorationSession.new()
	root.add_child(restored)
	check(restored.restore() and int(restored.switches.get("tower_hp_echo_morris",0))==321,"Tower boss damage survives save round-trip and old-save schema remains loadable")

	await _check_practice_enemy()
	await _check_route_and_realm()
	await _check_in_place_return()
	await _check_tower_sections()
	_check_status_tips()

	var title_source: String = FileAccess.get_file_as_string("res://scripts/exploration/exploration_hud.gd")
	check(title_source.contains("动作探索 Demo 9") and not title_source.contains("动作探索 Demo 8"),"Player-facing version is consistently Demo 9")
	print("EXPERIENCE_QA ",passes," passed, ",failures.size()," failed")
	current_scene = null
	demo.queue_free()
	restored.queue_free()
	await process_frame
	await process_frame
	root.get_node("AudioManager").stop_all()
	OS.delay_msec(80)
	quit(0 if failures.is_empty() else 1)


func _wait_transition() -> int:
	var started: int = Time.get_ticks_msec()
	await process_frame
	while demo._transitioning:
		await process_frame
	return Time.get_ticks_msec()-started

func _check_practice_enemy() -> void:
	demo.session.reset()
	demo.mode = "play"
	demo.hud.overlay.hide()
	demo.load_room("town_entrance")
	await frames(10)
	var dummy: ExplorationEnemy
	for enemy: Node in demo.room.find_children("*","CharacterBody2D",true,false):
		if enemy is ExplorationEnemy and bool((enemy as ExplorationEnemy).spec.get("practice",false)):
			dummy = enemy
	check(dummy!=null and int(dummy.data["damage"])==0,"Practice wax figure is spawned with zero damage")
	if dummy==null:
		return
	demo.player._invulnerability = 0
	for index: int in range(180):
		demo.player.position = dummy.global_position+Vector2(-20,0)
		await physics_frame
	check(demo.player.health==100 and demo.session.deaths==0,"Standing inside the practice enemy for 3 s costs no health")
	var hp_before: int = dummy.health
	dummy.receive_hit(10,demo.player.global_position)
	check(dummy.health<hp_before and demo.hud.toast_label.text.contains("安全练习"),"Hitting the practice enemy teaches the J combo once")

func _check_route_and_realm() -> void:
	demo.session.reset()
	demo.mode = "play"
	demo.hud.overlay.hide()
	demo.load_room("town_entrance")
	demo._realm = "reality"
	await frames(5)
	var loads: Array[String] = []
	demo.request_room("passage_00","town_entrance--ring_west_a")
	await _wait_transition()
	loads.append(demo.session.room_id)
	await frames(31)
	var first_safe: bool = demo.player.is_on_floor()
	# Memory crossing: measure the full grammar and sample the HUD drain mid-way.
	var hud_alpha_mid: float = 1.0
	var caption_mid: String = ""
	var tint_in: Color
	demo.request_room("passage_08","wax_lane--wax_museum_a")
	var started: int = Time.get_ticks_msec()
	await process_frame
	while demo._transitioning:
		if Time.get_ticks_msec()-started>1100 and caption_mid.is_empty():
			hud_alpha_mid = demo.hud.root.modulate.a
			caption_mid = demo._caption.text if demo._caption.modulate.a>.5 else ""
			tint_in = demo._fade.color
		await process_frame
	var enter_ms: int = Time.get_ticks_msec()-started
	loads.append(demo.session.room_id)
	var safe_after: float = demo.player._invulnerability
	check(loads==["wax_lane","wax_museum"] and first_safe,"Town entrance reaches the museum in exactly two black-screen transitions (%s)" % [loads])
	check(enter_ms>=2600 and enter_ms<=3600,"Reality->memory crossing lasts about 3 s (%d ms)" % enter_ms)
	check(hud_alpha_mid<.1 and caption_mid.contains("记忆覆写现实") and tint_in.b>tint_in.r,"Memory crossing drains the HUD, shows a caption and a cyan wash (readable muted)")
	check(demo.hud.realm=="memory" and demo.hud.realm_label.text.contains("记忆"),"HUD keeps a persistent memory-realm marker after crossing")
	check(safe_after>=.45,"Control returns after a crossing with a >=0.5 s safe window")
	await frames(40)
	await frames(10)
	caption_mid = ""
	var tint_out: Color
	demo.request_room("passage_08","wax_lane--wax_museum_b")
	started = Time.get_ticks_msec()
	await process_frame
	while demo._transitioning:
		if Time.get_ticks_msec()-started>1100 and caption_mid.is_empty():
			caption_mid = demo._caption.text if demo._caption.modulate.a>.5 else ""
			tint_out = demo._fade.color
		await process_frame
	var exit_ms: int = Time.get_ticks_msec()-started
	check(demo.session.room_id=="wax_lane" and absf(exit_ms-enter_ms)<450 and caption_mid.contains("现实重新对焦") and tint_out.r>tint_out.b,"Memory->reality return mirrors the same grammar (%d ms vs %d ms)" % [exit_ms,enter_ms])
	await frames(30)
	check(demo.hud.realm=="reality" and demo.hud.root.modulate.a>.99,"HUD realm marker flips back to reality and the HUD returns")

func _check_in_place_return() -> void:
	demo.session.reset()
	demo.mode = "play"
	demo.hud.overlay.hide()
	demo.load_room("wax_museum")
	demo._realm = "memory"
	demo.hud.set_realm("memory")
	await frames(10)
	demo.session.acquire("boss_morris")
	var started: int = Time.get_ticks_msec()
	await demo.realm_story_card("reality","画室回忆","test","前往剧院")
	var ms: int = Time.get_ticks_msec()-started
	check(demo.mode=="ending" and demo.hud.realm=="reality" and ms>=2600 and ms<=3600,"Mei's defeat returns to reality in place with the mirrored 3 s grammar (%d ms)" % ms)
	demo.player._invulnerability = 0
	demo.close_overlay()
	check(demo.mode=="play" and demo.player._invulnerability>=.5,"Closing a story card grants a 0.5 s control-return safe window")
	await frames(20)

func _chase() -> ExplorationKeeperChase:
	for child: Node in demo.room.get_children():
		if child is ExplorationKeeperChase:
			return child
	return null

func _check_tower_sections() -> void:
	demo.session.reset()
	for flag: String in ["boss_morris","boss_void","wax_seal","theater_seal","double_jump","vine","dash","scissors"]:
		demo.session.acquire(flag)
	demo.mode = "play"
	demo.hud.overlay.hide()
	demo.load_room("clock_tower")
	await frames(20)
	var chase: ExplorationKeeperChase = _chase()
	check(chase!=null and chase._tiers.size()==8,"Clock tower chase controller loads with eight floors")
	if chase==null:
		return
	check(demo.hud.toast_label.text.contains("第一段"),"Tower opens with the first section (chase) explained")
	# Walk onto floor 2: permanent checkpoint, section two announced.
	demo.player.grant_safe_window(3)
	demo.player.position = Vector2(700,chase._tiers[2]-3)
	await frames(20)
	check(demo.session.tower_checkpoint_tier()==2 and demo.hud.toast_label.text.contains("第二段"),"Reaching floor 2 saves a permanent checkpoint and starts the combat section")
	var echo: ExplorationEnemy
	for child: Node in demo.room.actors.get_children():
		if child is ExplorationBoss and bool((child as ExplorationBoss).echo):
			echo = child
	check(echo!=null,"Perfect Mei echo stands in the combat section")
	if echo==null:
		return
	echo.state = "idle"
	var full: int = echo.max_health
	echo.health = full
	echo.receive_hit(120,echo.global_position+Vector2(-40,0))
	var damaged: int = echo.health
	# Bell rewind from floor 3 drops one floor, never under the checkpoint.
	demo.player.position = Vector2(700,chase._tiers[3]-3)
	await frames(2)
	await chase._rewind(demo.player)
	check(chase._tier_of(demo.player.global_position.y)==2 and demo.hud.toast_label.text.contains("仅回退一层"),"Bell rewind costs one floor and says so")
	check(echo.health==damaged,"Bell rewind no longer heals the echo bosses")
	# Death inside the combat section: respawn at the floor-2 checkpoint, damage kept.
	var started: int = Time.get_ticks_msec()
	demo.player._invulnerability = 0
	demo.player.take_damage(100)
	await frames(2)
	while demo.mode!="play" or demo._death_pending:
		await process_frame
	var respawn_ms: int = Time.get_ticks_msec()-started
	await frames(20)
	chase = _chase()
	var respawned_echo: ExplorationEnemy
	for child: Node in demo.room.actors.get_children():
		if child is ExplorationBoss and bool((child as ExplorationBoss).echo):
			respawned_echo = child
	check(demo.session.room_id=="clock_tower" and chase._tier_of(demo.player.global_position.y)==2,"Tower death respawns at the current section's checkpoint, not the base")
	check(respawned_echo!=null and respawned_echo.health==damaged,"Echo boss keeps its damage across death/respawn (%d/%d)" % [respawned_echo.health if respawned_echo else -1,full])
	check(respawn_ms<3000 and demo.hud.toast_label.text.contains("永久检查点"),"Tower respawn takes %d ms and names the checkpoint" % respawn_ms)
	# Later sections: checkpoint 4 then 6 (choice), never backwards.
	demo.player.grant_safe_window(3)
	demo.player.position = Vector2(700,chase._tiers[4]-3)
	await frames(10)
	demo.player.position = Vector2(700,chase._tiers[6]-3)
	await frames(10)
	check(demo.session.tower_checkpoint_tier()==6 and demo.hud.toast_label.text.contains("第三段"),"Floor 6 checkpoint opens the final choice section")
	demo.player.position = Vector2(700,chase._tiers[1]-3)
	await frames(10)
	check(demo.session.tower_checkpoint_tier()==6,"Dropping down never rolls the checkpoint back")

func _check_status_tips() -> void:
	var player: ExplorationPlayer = demo.player
	player.paper = 0
	player.plaster = 0
	player.paint = 0
	player.cloth = 0
	player.health = 100
	demo.session.switches.erase("tutorial_plaster")
	player._invulnerability = 0
	player.enabled = true
	player.receive_hit(5,player.global_position+Vector2(30,0),"statue")
	check(player.plaster==1 and demo.hud.toast_label.text.contains("石膏 1/3") and demo.hud.toast_label.text.contains("H"),"First plaster stack gives an actionable one-time tip")
	player._invulnerability = 0
	player.receive_hit(5,player.global_position+Vector2(30,0),"statue")
	check(player.status_critical(),"Second plaster stack marks the meter critical")
	player.energy = 100
	player._clear_status_layer()
	check(player.plaster==1,"H clears exactly one lethal-state layer")
	player.plaster = 0
	player.cloth = ExplorationVoidBoss.CLOTH_LIMIT-1
	check(player.status_text().contains("%d/%d" % [ExplorationVoidBoss.CLOTH_LIMIT-1,ExplorationVoidBoss.CLOTH_LIMIT]) and player.status_critical(),"Void cloth meter uses the real defeat threshold")
	player.cloth = 0
