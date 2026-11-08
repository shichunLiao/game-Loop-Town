class_name ExplorationFuryScene
extends Node2D
## Story 1.1 at the well mouth. Fury stands behind Jerry and attacks; the screen flashes and the
## player's hands are on Fury's body. He beats Jerry to the last of his blood and pushes him in.

signal answered

var session: ExplorationSession
var spec: Dictionary
var stage: String = "wait"
var body: ExplorationFuryBody
var _well: Vector2
var _arena: Vector2
var _fences: Array[StaticBody2D] = []
var _caged: bool = false

func _ready() -> void:
	z_index = 6
	_well = ExplorationCatalog.vec(spec["well"])
	_arena = ExplorationCatalog.vec(spec["arena"])
	for x: float in [_arena.x,_arena.y]:
		var fence := StaticBody2D.new()
		fence.position = Vector2(x,_well.y-450)
		fence.collision_layer = 0
		fence.collision_mask = 0
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = Vector2(22,900)
		shape.shape = box
		fence.add_child(shape)
		add_child(fence)
		_fences.append(fence)

func _physics_process(_delta: float) -> void:
	if stage=="fury":
		# His own bar drains with Jerry's: the two of them have one body.
		_demo().player.health = body.health
		return
	if stage!="wait" or session.has("fury_done") or not session.has("keeper_truth"):
		return
	var demo: Node = _demo()
	if demo.mode!="play":
		return
	var player: ExplorationPlayer = demo.player
	if player.global_position.x>=float(spec["trigger"]) and player.is_on_floor() and absf(player.global_position.y-_well.y)<20:
		_open()

func _open() -> void:
	stage = "standoff"
	var demo: Node = _demo()
	var room: ExplorationRoom = get_parent() as ExplorationRoom
	var audio: Node = get_node("/root/AudioManager")
	_lock(true)
	demo.player.health = 100
	demo.player.velocity = Vector2.ZERO
	audio.stop_music()
	audio.stop_ambient()
	# The well bottom is the same audio area; this makes its music start again down there.
	audio.current_area = &""
	# Nobody else is left on this road.
	for npc: ExplorationNPC in room.npcs:
		npc.queue_free()
	room.npcs.clear()
	room.interactables.clear()
	for enemy: Node in get_tree().get_nodes_in_group("exploration_enemies"):
		enemy.queue_free()
	_face(demo.player,1)
	await demo.caption("井口边有一块深褐色的痕迹。",2.0)
	audio.play_sfx("sfx_ghost_whisper")
	await get_tree().create_timer(.8).timeout
	_face(demo.player,-1)
	body = ExplorationFuryBody.new()
	body.spec = {"id":"fury","pos":[demo.player.global_position.x-float(spec.get("behind",330)),_well.y]}
	body.session = session
	room.actors.add_child(body)
	body.glitch = .6
	await get_tree().create_timer(1.0).timeout
	demo.show_dialogue("弗瑞","「你想起来了？」\n\n杰利没有回答。两人对峙着，四周十分安静。",[{"label":"……", "action":answer}])
	demo.mode = "ending"
	await answered
	await demo.caption("我得快除掉他。",1.8)
	_set_cage(true)
	_lock(false)
	stage = "dodge"
	demo.hud.toast("躲开他！")
	body.begin_lunges()
	await body.lunged_out
	await _switch()

func answer() -> void:
	_demo().close_overlay()
	_lock(true)
	answered.emit()

func _switch() -> void:
	stage = "switch"
	var demo: Node = _demo()
	var player: ExplorationPlayer = demo.player
	_lock(true)
	get_node("/root/AudioManager").play_bell()
	await demo.flash_to(1,.1)
	var jerry_at := Vector2(player.global_position.x,_well.y)
	player.global_position = Vector2(body.global_position.x,_well.y-3)
	player.velocity = Vector2.ZERO
	player._last_ground_y = player.position.y
	body.global_position = jerry_at
	player.wear("fury_idle",118,-1,"fury_punch",true)
	body.become_jerry(player.health)
	_face(player,signf(jerry_at.x-player.global_position.x))
	demo.camera.reset_smoothing()
	await get_tree().create_timer(.18).timeout
	await demo.flash_to(0,.35)
	_lock(false)
	stage = "fury"
	demo.hud.toast("J 攻击 · 这是弗瑞的手")
	await body.beaten
	await _push()

func _push() -> void:
	stage = "push"
	var demo: Node = _demo()
	var player: ExplorationPlayer = demo.player
	player.health = body.health
	_lock(true)
	_set_cage(false)
	var side: float = 1.0 if body.global_position.x>=player.global_position.x else -1.0
	body.collapse(side)
	await get_tree().create_timer(.7).timeout
	# He walks over, takes Jerry by the collar and drags him to the rim.
	var beside := Vector2(body.global_position.x-side*60,_well.y-3)
	_face(player,side)
	var tween := create_tween()
	tween.tween_property(player,"global_position",beside,absf(beside.x-player.global_position.x)/260.0+.05)
	await tween.finished
	var rim_side: float = 1.0 if _well.x>=body.global_position.x else -1.0
	var drag: float = minf(3,absf(_well.x-body.global_position.x)/170.0+.25)
	_face(player,rim_side)
	tween = create_tween().set_parallel()
	tween.tween_property(body,"global_position",Vector2(_well.x-rim_side*118,_well.y),drag)
	tween.tween_property(player,"global_position",Vector2(_well.x-rim_side*190,_well.y-3),drag)
	await tween.finished
	await demo.caption("「那你也去死吧」",1.6)
	body.drop_in(_well)
	await demo._fade_to(1,.55)
	await demo.caption("杰利掉进井口，往下坠。黑暗吞没了他。",2.6)
	session.switches["fury_done"] = true
	session.changed.emit()
	stage = "done"
	demo.fall_into(str(spec["target"]),ExplorationCatalog.vec(spec["arrival"]))

func _lock(locked: bool) -> void:
	var demo: Node = _demo()
	demo.mode = "cutscene" if locked else "play"
	demo.player.enabled = not locked
	demo.hud.prompt_label.text = ""

func _face(player: ExplorationPlayer, side: float) -> void:
	player.facing = side
	player.visual.flip_h = side<0

func _set_cage(locked: bool) -> void:
	_caged = locked
	for fence: StaticBody2D in _fences:
		fence.set_deferred("collision_layer",1 if locked else 0)
	queue_redraw()

func _demo() -> Node:
	return get_tree().get_first_node_in_group("exploration_demo")

## Codex props: dug-out well mouth, ground-hand stain and caution tape (Demo 9 item 3).
func _draw() -> void:
	var well: Texture2D = ExplorationArt.sprite("well_mouth",-1,"props")
	var mark: Texture2D = ExplorationArt.sprite("ground_hand",-1,"props")
	if mark!=null:
		draw_texture_rect(mark,Rect2(_well+Vector2(-252,-26),Vector2(124,38)),false)
	if well!=null:
		draw_texture_rect(well,Rect2(_well+Vector2(-100,-82),Vector2(200,84)),false)
	_tape(_well.x-170,_well.x+170,_well.y)
	if _caged:
		_tape(_arena.x,_arena.x+150,_well.y)
		_tape(_arena.y-150,_arena.y,_well.y)

func _tape(from_x: float, to_x: float, y: float) -> void:
	var tape: Texture2D = ExplorationArt.sprite("caution_tape",-1,"props")
	if tape!=null:
		draw_texture_rect(tape,Rect2(from_x,y-92,to_x-from_x,92),false)
