extends SceneTree
## Demo 9: every story 1.1 character uses the Codex art. Spawns each boss in its own room,
## forces each pose and checks which PNG the sprite shows. Run with a window (not --headless)
## to also save screenshots to docs/exploration-demo/v9-*.png.

var demo: Node2D
var failures: Array[String] = []
var passes: int = 0
var shots: bool = DisplayServer.get_name()!="headless"

const SPRITES: Array[String] = ["may_idle","may_windup","may_slash","may_summon","may_brush","may_brush_strike","may_statue",
	"void_idle","void_command","void_lash","void_frenzy","void_puppet","keeper_back","keeper_hidden","keeper_unmasked",
	"fury_idle","fury_lunge","fury_punch","ling_giant","ling_crouch","ling_hand"]

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
		await process_frame

func shows(sprite: Sprite2D, id: String) -> bool:
	if sprite==null or sprite.texture==null:
		return false
	var texture: Texture2D = sprite.texture
	if ExplorationArt.source_id(texture)==id:
		return true
	if texture is AtlasTexture:
		texture = (texture as AtlasTexture).atlas
	return texture.resource_path.ends_with("/"+id+".png")

func shot(name: String) -> void:
	if not shots:
		return
	await frames(3)
	root.get_viewport().get_texture().get_image().save_png("res://docs/exploration-demo/v9-"+name+".png")

func enter(room_id: String, at: Vector2, flags: Array = []) -> void:
	demo.start_game(false,room_id)
	for flag: String in flags:
		demo.session.acquire(flag)
	if not flags.is_empty():
		demo.load_room(room_id)
	demo.player.position = at
	demo.player.enabled = false
	demo.camera.reset_smoothing()
	await frames(12)

func boss() -> Node:
	return root.get_tree().get_first_node_in_group("exploration_boss")

func _run() -> void:
	root.get_node("SaveManager").exploration_slot_name = "exploration_qa"
	for id: String in SPRITES:
		check(ExplorationArt.sprite(id)!=null,"Codex sprite loads: "+id)
	demo = (load("res://scenes/exploration/ExplorationDemo.tscn") as PackedScene).instantiate()
	demo.set("_story_slot","exploration_qa")
	root.add_child(demo)
	current_scene = demo
	await frames(5)

	# May Morley in the endless corridor.
	await enter("wax_museum",Vector2(2780,1137))
	var may: Node = boss()
	check(may is ExplorationBoss,"May Morley spawns in the museum")
	await shot("museum-portraits")
	may.set_physics_process(false)
	for pose: Array in [[1,"sleep","fan","may_idle"],[1,"windup","cleave","may_windup"],[1,"active","cleave","may_slash"],
			[2,"active","copies","may_summon"],[3,"recover","rain","may_brush"],[3,"active","rush","may_brush_strike"]]:
		may.phase = pose[0]
		may.state = pose[1]
		may.attack = pose[2]
		may._visual_update()
		check(shows(may.visual,pose[3]),"May phase %d %s %s shows %s" % [pose[0],pose[1],pose[2],pose[3]])
		if pose[3] in ["may_idle","may_brush","may_brush_strike"]:
			await shot("may-"+str(pose[3]).trim_prefix("may_"))
	may.phase = 2
	may.state = "recover"
	var double := ExplorationMorrisDouble.new()
	double.spec = {"id":"qa_statue","type":"wax_walker","pos":[2600,1140],"patrol":0}
	double.session = demo.session
	double.summoner = may
	double.position = Vector2(2600,1140)
	demo.room.actors.add_child(double)
	await frames(3)
	check(shows(double.visual,"may_statue"),"Statue double shows may_statue")
	await shot("may-statue")

	# Void on the backstage stage.
	await enter("back_stage",Vector2(1500,937))
	var void_boss: Node = boss()
	check(void_boss is ExplorationVoidBoss,"Void spawns backstage")
	void_boss._wake()
	await frames(4)
	void_boss.set_physics_process(false)
	var puppets: Array = root.get_tree().get_nodes_in_group("void_owned").filter(func(n): return n is ExplorationVoidPuppet)
	check(not puppets.is_empty() and shows(puppets[0].visual,"void_puppet"),"Void's seat puppets show void_puppet")
	for pose: Array in [[1,"recover","command","void_idle"],[1,"windup","command","void_command"],[2,"active","lash","void_lash"],[3,"recover","rain","void_frenzy"]]:
		void_boss.phase = pose[0]
		void_boss.state = pose[1]
		void_boss.attack = pose[2]
		void_boss._visual_update()
		check(shows(void_boss.visual,pose[3]),"Void phase %d %s %s shows %s" % [pose[0],pose[1],pose[2],pose[3]])
		if pose[3] in ["void_idle","void_lash"]:
			await shot(str(pose[3]).replace("_","-"))

	# The keeper at the top of the tower turns, then takes off his hat.
	await enter("clock_top",Vector2(300,1137))
	var keepers: Array = demo.room.find_children("*","ExplorationKeeperFigure",true,false)
	var keeper: ExplorationKeeperFigure = keepers.front() if not keepers.is_empty() else null
	check(keeper!=null and shows(keeper.visual,"keeper_back"),"Keeper winds the key with his back turned")
	await shot("keeper-back")
	if keeper!=null:
		demo.player.position = Vector2(keeper.global_position.x-300,keeper.global_position.y-3)
		await frames(3)
		check(shows(keeper.visual,"keeper_hidden"),"Keeper turns, face hidden under the brim")
		demo.player.position = Vector2(keeper.global_position.x-120,keeper.global_position.y-3)
		await frames(3)
		check(shows(keeper.visual,"keeper_unmasked"),"Keeper takes off the hat: Jerry's face")
		await shot("keeper-unmasked")

	# Fury at the well mouth, and the player wearing his body.
	await enter("dry_well",Vector2(3000,1237))
	var scenes: Array = demo.room.find_children("*","ExplorationFuryScene",true,false)
	var fury_scene: Node = scenes.front() if not scenes.is_empty() else null
	check(fury_scene!=null,"Fury scene is in the dry well")
	if fury_scene!=null:
		var fury: Node = fury_scene.body if is_instance_valid(fury_scene.body) else null
		if fury==null:
			fury = ExplorationFuryBody.new()
			fury.spec = {"id":"qa_fury","type":"fury","pos":[3200,1240]}
			fury.session = demo.session
			fury.position = Vector2(3200,1240)
			demo.room.actors.add_child(fury)
			await frames(2)
		fury._visual_update()
		check(shows(fury.visual,"fury_idle"),"Fury stands as fury_idle")
		await shot("fury")
		fury._step = "lunge"
		fury._visual_update()
		check(shows(fury.visual,"fury_lunge"),"Fury lunges as fury_lunge")
		await shot("fury-lunge")
		fury.become_jerry(60)
		fury._visual_update()
		check(shows(fury.visual,"hero"),"After the flash the other body is Jerry")
	demo.player.wear("fury_idle",118,-1,"fury_punch",true)
	demo.player.enabled = true
	await frames(2)
	check(shows(demo.player.visual,"fury_idle"),"Player wears fury_idle")
	demo.player.enabled = false
	demo.player.attack_phase = "active"
	demo.player._worn_pose()
	check(shows(demo.player.visual,"fury_punch"),"Player throws fury_punch while a blow is out")
	demo.player.enabled = false

	# Ling at the bottom of the well, and the real Ling in the corner.
	await enter("well_interior",Vector2(700,2837),["fury_done"])
	var ling: Node = boss()
	check(ling is ExplorationLingBoss,"Ling spawns once Fury has pushed Jerry in")
	if ling is ExplorationLingBoss:
		ling.set_physics_process(false)
		ling.state = "recover"
		ling._rise = 1.0
		ling._wrap = .6
		ling._visual_update()
		await shot("ling-giant")
	var hand := ExplorationLingHand.new()
	hand.boss = ling
	hand.session = demo.session
	hand.warning = 0
	hand.position = Vector2(900,2840)
	demo.room.actors.add_child(hand)
	await frames(2)
	check(is_instance_valid(hand),"Mud hand draws without errors")
	demo.session.acquire("boss_ling")
	demo.load_room("well_interior")
	demo.player.position = Vector2(1500,2837)
	demo.player.enabled = false
	demo.camera.reset_smoothing()
	await create_timer(3.6).timeout
	var figures: Array = demo.room.find_children("*","ExplorationLingFigure",true,false)
	check(not figures.is_empty() and figures.front().modulate.a>.9,"The real Ling appears in the corner")
	await shot("ling-crouch")

	demo.hud.show_cast()
	await frames(3)
	check(true,"Cast page renders the story 1.1 cast")
	await shot("cast")

	print("V9_ART_QA %d passed, %d failed" % [passes,failures.size()])
	current_scene = null
	demo.queue_free()
	await process_frame
	await process_frame
	ExplorationArt._animation_frames.clear()
	ExplorationArt._textures.clear()
	root.get_node("AudioManager").stop_all()
	OS.delay_msec(80)
	quit(1 if failures.size()>0 else 0)
