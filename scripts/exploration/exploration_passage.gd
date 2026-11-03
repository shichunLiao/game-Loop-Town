class_name ExplorationPassage
extends ExplorationInteractable
## A door, winding mechanism or bridge blocks the actual road until operated.

var barrier: StaticBody2D
var _opening: bool = false
var _blend: float = 0.0
var _door_texture: Texture2D

func _ready() -> void:
	super._ready()
	spec["kind"] = "passage"
	var style: String = str(spec.get("gate_type",""))
	var cell: int = 2 if style.begins_with("clock") else 1 if style in ["fire_door","shears_door"] else 3 if style in ["drain_gate","well_hatch"] else 0
	_door_texture = ExplorationArt.sprite("gate_panels",cell,"gates")
	barrier = StaticBody2D.new()
	barrier.position = Vector2(0,-105)
	barrier.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(32,210)
	shape.shape = rectangle
	barrier.add_child(shape)
	add_child(barrier)
	_refresh()
	_blend = 1.0 if is_open() else 0.0
	session.changed.connect(_refresh)

func _refresh() -> void:
	barrier.set_deferred("collision_layer",0 if is_open() or bool(spec.get("manual_entry",false)) else 1)
	queue_redraw()

func is_finished() -> bool:
	if bool(spec.get("manual_entry",false)):
		return false
	return spec.get("requires",[]).is_empty() or is_open()

func is_open() -> bool:
	return spec.get("requires",[]).is_empty() or session.has("opened_"+str(spec.get("gate_id",spec["id"])))

func prompt() -> String:
	var title: String = str(spec.get("gate_title","街道通路"))
	if _opening:
		return title+" · 机关正在运转"
	if bool(spec.get("manual_entry",false)) and is_open():
		return "E  进入 · "+str(spec.get("label",title))
	return "E  "+("启动机关 · " if session.satisfies(spec.get("requires",[])) else "检查封闭原因 · ")+title

func operate() -> void:
	if bool(spec.get("manual_entry",false)) and is_open() and not _opening:
		get_tree().get_first_node_in_group("exploration_demo").request_room(str(spec["target"]),str(spec["id"]))
		return
	if is_open() or _opening:
		return
	var demo: Node = get_tree().get_first_node_in_group("exploration_demo")
	var key: String = str(spec.get("gate_id",spec["id"]))
	ExplorationJournal.discover(session,key)
	if not session.satisfies(spec.get("requires",[])):
		var clue: Dictionary = ExplorationJournal.definitions()["gates"].get(key,{})
		var known: bool = session.has("hint_"+key)
		demo.show_dialogue(str(spec.get("gate_title","封闭的道路")),str(clue.get("text",spec.get("hint","机关被锁住了。"))) if known else "门轴与道路机关被锁住了。\n向"+str(clue.get("giver_name","附近的居民"))+"询问开启的方法。\n\n已记入任务日志（L），地图会标出目标街区。")
		return
	_opening = true
	demo.hud.toast(str(spec.get("gate_title","道路"))+" · 机关开始运转")
	var tween := create_tween()
	tween.tween_property(self,"_blend",1.0,.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	session.switches["opened_"+key] = true
	if str(session.quest_state.get("tracked",""))=="gate:"+key:
		session.quest_state["tracked"] = "main"
	_opening = false
	session.changed.emit()
	session.save()
	demo.hud.toast("侧门已开启 · 靠近按 E 进入" if bool(spec.get("manual_entry",false)) else "通路已打开 · 可以沿道路继续前进")

func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()

func contains_player(player: ExplorationPlayer) -> bool:
	var center: Vector2 = player.global_position+Vector2(0,-32)
	return Rect2(global_position+Vector2(-58,-128),Vector2(116,138)).has_point(center)

func moving_toward(player: ExplorationPlayer) -> bool:
	var axis: float = Input.get_axis("move_left","move_right")
	return axis < -.1 if str(spec.get("direction","right")) == "left" else axis > .1

func _draw() -> void:
	if bool(spec.get("manual_entry",false)):
		_draw_street_door()
		return
	var unlocked: bool = is_open()
	var accent := Color("bdc9ae") if unlocked else Color("c07c67")
	var side: float = -1 if str(spec.get("direction","right"))=="left" else 1
	if spec.get("requires",[]).is_empty():
		draw_string(_font,Vector2(-140,-110),str(spec.get("label","通路")),HORIZONTAL_ALIGNMENT_CENTER,280,14,Color(accent,.7))
		return
	draw_line(Vector2(-side*40,-90),Vector2(side*18,-90),accent,2,true)
	draw_line(Vector2(side*18,-90),Vector2(side*5,-100),accent,2,true)
	draw_line(Vector2(side*18,-90),Vector2(side*5,-80),accent,2,true)
	draw_string(_font,Vector2(-160,-265),str(spec.get("gate_title","街道门")),HORIZONTAL_ALIGNMENT_CENTER,320,15,accent)
	var style: String = str(spec.get("gate_type","street_door"))
	var masonry := Color("26373b")
	var stone_edge := Color("60706b")
	var timber := Color("4c3c32")
	# Full masonry jambs and a lintel make this a building entrance.
	if style != "drawbridge":
		if _arch != null:
			draw_texture_rect(_arch,Rect2(-125,-330,250,330),false,Color(.74,.81,.80))
		var door_width: float = 146*(1-_blend)
		if door_width>2:
			draw_rect(Rect2(-73,-227,door_width,227),timber)
			if _door_texture != null:
				draw_texture_rect(_door_texture,Rect2(-73,-227,door_width,227),false,Color(.85,.91,.87))
		if style.begins_with("clock"):
			draw_circle(Vector2(0,-239),27,Color("293638"))
			draw_arc(Vector2(0,-239),27,0,TAU,40,Color("c5a76e"),3,true)
			for i: int in range(12):
				var a: float = i*TAU/12
				draw_line(Vector2(0,-239)+Vector2.from_angle(a)*19,Vector2(0,-239)+Vector2.from_angle(a)*24,Color("c5a76e"),2,true)
			draw_line(Vector2(0,-239),Vector2(0,-239)+Vector2.from_angle(-PI*.5+_blend*PI)*20,Color("e4cf98"),2,true)
		elif style in ["shears_door","fire_door"] and _blend<.85:
			draw_line(Vector2(-57,-213),Vector2(52,-32),Color("a95360"),3,true)
			draw_line(Vector2(57,-213),Vector2(-52,-32),Color("a95360"),3,true)
	else:
		# A hinged timber deck drops into the travel line, with chain supports.
		draw_rect(Rect2(-115,0,230,90),Color("0e1c24"))
		draw_set_transform(Vector2(-90,0),-PI*.48*(1-_blend))
		for i: int in range(10):
			draw_rect(Rect2(i*18,-16,17,16),timber)
			draw_line(Vector2(i*18,-16),Vector2(i*18+17,-16),Color("a28b68"),2,true)
		draw_set_transform(Vector2.ZERO)
		draw_line(Vector2(-92,-210),Vector2(-90+180*sin(_blend*PI*.5),-180*cos(_blend*PI*.5)),Color("8f8c70"),3,true)
		draw_line(Vector2(-94,-215),Vector2(-94,0),masonry,14,true)
	# The handle remains visible after opening, matching saved mechanical state.
	draw_circle(Vector2(-112,-61),19,Color("232e31"))
	draw_arc(Vector2(-112,-61),18,0,TAU,20,Color("c2a26b"),3,true)
	draw_line(Vector2(-112,-61),Vector2(-112,-61)+Vector2.from_angle(-2.4+_blend*2.8)*27,Color("c2a26b"),5,true)
	if focused and not unlocked:
		draw_circle(Vector2(-112,-104),12,Color("14262d"))
		draw_string(_font,Vector2(-117,-98),"E",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("ecdbb4"))

func _draw_street_door() -> void:
	var face: Texture2D = ExplorationArt.sprite("masonry_tiles_v7",0,"masonry")
	if face != null:
		draw_texture_rect(face,Rect2(-77,-208,154,208),false,Color(.49,.55,.55))
	draw_rect(Rect2(-45,-153,90,153),Color("101e25"))
	if _arch != null:
		draw_texture_rect(_arch,Rect2(-84,-228,168,228),false,Color(.65,.75,.74))
	var panel_width: float = 88*(1-_blend)
	if panel_width>2 and _door_texture != null:
		draw_texture_rect(_door_texture,Rect2(-44,-151,panel_width,151),false,Color(.75,.82,.76))
	var title: String = str(spec.get("gate_title",spec.get("label","侧廊入口")))
	draw_rect(Rect2(-95,-254,190,23),Color("26302e"))
	draw_string(_font,Vector2(-92,-237),title,HORIZONTAL_ALIGNMENT_CENTER,184,13,Color("cfc3a1"))
	if not is_open():
		draw_circle(Vector2(24,-78),7,Color("b19263"))
	else:
		draw_line(Vector2(-15,-73),Vector2(15,-73),Color("9fcab9"),2,true)
		draw_line(Vector2(15,-73),Vector2(4,-82),Color("9fcab9"),2,true)
	if focused:
		draw_circle(Vector2(0,-273),12,Color("17242a"))
		draw_string(_font,Vector2(-5,-267),"E",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("e2d9ba"))
