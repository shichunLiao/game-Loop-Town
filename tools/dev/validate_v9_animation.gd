extends SceneTree
## Real Demo 9 routing + every cel's atlas region + gaze under the parallax transform.
var passed: int = 0
var failures: Array[String] = []
var demo: Node2D

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS ",label)
	else:
		failures.append(label)
		print("FAIL ",label)

func frames(n: int) -> void:
	for i: int in n:
		await process_frame

func advance(sprite: Sprite2D, expected: String) -> void:
	var animation: ExplorationPoseAnimation = sprite.get_node("CGAnimation") as ExplorationPoseAnimation
	animation._process(.001)
	var first: int = animation.frame_index
	animation._process(.24)
	check(animation.clip==expected and animation.frame_index!=first,"plays "+expected)

func _run() -> void:
	var manifest: Dictionary = ExplorationArt.animation_manifest()
	check(manifest.clips.size()>=77,"complete clip inventory")
	for clip: String in manifest.clips:
		var info: Dictionary = manifest.clips[clip]
		var regions: Array[Rect2] = []
		for i: int in int(info.frames):
			var cel: AtlasTexture = ExplorationArt.animation_frame(clip,i) as AtlasTexture
			check(cel!=null and cel.atlas!=null and cel.region.end.x<=cel.atlas.get_width() and cel.region.end.y<=cel.atlas.get_height(),"cel loads "+clip+"/"+str(i))
			if cel!=null:
				regions.append(cel.region)
		check(regions.size()==8 and regions[0]!=regions[7],"8 distinct atlas regions "+clip)
		var seen_indices: Dictionary = {}
		for i: int in 8:
			seen_indices[ExplorationArt.animation_index(clip,(i+.5)/8.0*float(info.duration))] = true
		check(seen_indices.size()==8,"all 8 cels advance "+clip)
	root.get_node("SaveManager").exploration_slot_name = "exploration_animation_qa"
	demo = (load("res://scenes/exploration/ExplorationDemo.tscn") as PackedScene).instantiate()
	demo.set("_story_slot","exploration_animation_qa")
	root.add_child(demo)
	current_scene = demo
	await frames(4)
	demo.start_game(false,"wax_museum")
	await frames(6)
	demo.player.enabled = false
	demo.player.set_physics_process(false)
	for state: String in ["idle","run","jump","fall","climb","dash","death"]:
		demo.player.state = state
		demo.player.attack_phase = "ready"
		advance(demo.player.visual,"hero_"+state)
	for phase: String in ["windup","active","recover"]:
		demo.player.attack_phase = phase
		demo.player._attack_timer = .7
		advance(demo.player.visual,"hero_"+phase)
	demo.player.attack_phase = "ready"
	demo.player.state = "idle"
	for id: String in ExplorationArt.actors().enemies:
		var enemy := ExplorationEnemy.new()
		enemy.spec = {"id":"qa_"+id,"type":id,"pos":[300,1140]}
		enemy.session = demo.session
		demo.room.actors.add_child(enemy)
		enemy.set_physics_process(false)
		var cell: int = int(enemy.data.get("cell",-1))
		var stem: String = str(enemy.data.atlas)+("_"+str(cell) if cell>=0 else "")
		for state: String in ["patrol","windup","active","recover"]:
			enemy.state = state
			enemy.timer = .7
			advance(enemy.visual,stem+"_"+("move" if state=="patrol" else state))
		enemy.queue_free()
	var may: Node = get_first_node_in_group("exploration_boss")
	may.set_physics_process(false)
	for pose: Array in [[1,"sleep","fan","may_idle"],[1,"windup","cleave","may_windup"],[1,"active","cleave","may_slash"],[2,"active","copies","may_summon"],[3,"recover","rain","may_brush"],[3,"active","rush","may_brush_strike"]]:
		may.phase = pose[0]
		may.state = pose[1]
		may.attack = pose[2]
		may.timer = .7
		may._visual_update()
		advance(may.visual,str(pose[3]))
	may.state = "sleep"
	var background: Node = demo.room.get_node("Background")
	var gaze: ExplorationMuseumGaze = background.far_sprite.get_node("PortraitGaze") as ExplorationMuseumGaze
	check(gaze!=null and gaze.eyes.size()==6,"six independent museum irises")
	if gaze!=null and not gaze.eyes.is_empty():
		var eye: Dictionary = gaze.eyes[0]
		demo.player.global_position = gaze.to_global(eye.origin+Vector2(-700,-300))
		gaze._process(1)
		var left: Vector2 = eye.sprite.position
		demo.player.global_position = gaze.to_global(eye.origin+Vector2(700,400))
		gaze._process(1)
		var right: Vector2 = eye.sprite.position
		check(right.x-left.x>4 and right.y-left.y>1,"gaze tracks both axes through background transform")
		check(absf(right.x-eye.origin.x)<=eye.travel.x+.001 and absf(right.y-eye.origin.y)<=eye.travel.y+.001,"gaze stays inside eye travel")
		may.state = "active"
		gaze._process(.1)
		check(gaze.tracked_actor==may,"portraits watch attacking opponent")
		demo.player.attack_phase = "active"
		gaze._process(.1)
		check(gaze.tracked_actor==demo.player,"portraits watch attacking player")
	# Short visual actions must finish their cel sequence inside existing state lifetimes.
	var fury := ExplorationFuryBody.new()
	fury.spec = {"id":"qa_fury","type":"fury","pos":[300,1140]}
	fury.session = demo.session
	demo.room.actors.add_child(fury)
	fury.set_physics_process(false)
	fury._step = "lunge"
	fury.timer = .36
	fury._visual_update()
	var animation: ExplorationPoseAnimation = fury.visual.get_node("CGAnimation")
	animation._process(.001)
	fury.timer = .01
	animation._process(.34)
	check(animation.clip=="fury_lunge" and animation.frame_index==7,"Fury lunge reaches last cel within .36s")
	fury.queue_free()
	demo.player.visual.texture = ExplorationArt.sprite("hero")
	demo.player.state = "dash"
	demo.player.attack_phase = "ready"
	demo.player._dash = .16
	animation = demo.player.visual.get_node("CGAnimation")
	animation._process(.001)
	demo.player._dash = .001
	animation._process(.15)
	check(animation.clip=="hero_dash" and animation.frame_index==7,"hero dash reaches last cel within .16s")
	demo.player._dash = 0
	demo.player.wear("fury_idle",118,-1,"fury_punch",true)
	demo.player.attack_phase = "ready"
	advance(demo.player.visual,"fury_idle")
	demo.player.attack_phase = "active"
	demo.player._worn_pose()
	demo.player._attack_timer = .7
	advance(demo.player.visual,"fury_punch")
	print("V9_ANIMATION_QA %d passed, %d failed" % [passed,failures.size()])
	demo.queue_free()
	await frames(3)
	ExplorationArt._animation_frames.clear()
	ExplorationArt._textures.clear()
	quit(1 if not failures.is_empty() else 0)
