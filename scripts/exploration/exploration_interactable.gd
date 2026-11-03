class_name ExplorationInteractable
extends Node2D
## Shared environment-only affordances: passages, lamps, memories and puzzles.

var spec: Dictionary
var session: ExplorationSession
var focused: bool = false
var _clock: float = 0.0
var _arch: Texture2D
var _lantern: Texture2D
var _mirror: Texture2D
var _font: Font

func _ready() -> void:
	position = ExplorationCatalog.vec(spec.get("pos", [0, 0]))
	_arch = load("res://assets/environments/exploration/props/arch.png") as Texture2D
	_lantern = load("res://assets/environments/exploration/props/lantern.png") as Texture2D
	_mirror = load("res://assets/environments/exploration/props/mirror.png") as Texture2D
	_font = load("res://assets/ui/exploration/chinese.tres") as Font

func is_finished() -> bool:
	var kind: String = str(spec.get("kind", ""))
	if kind in ["memory", "ability", "relic", "flashback", "true_memory"]:
		return session.has(str(spec.get("item", "true_memory" if kind=="true_memory" else ""))) or bool(session.collected.get(str(spec.get("uid","")),false))
	if kind in ["switch", "thread"]:
		return session.has(str(spec.get("flag", "")))
	return false

func prompt() -> String:
	var kind: String = str(spec.get("kind", ""))
	if kind == "exit":
		return "E  前往 · " + ExplorationCatalog.title(str(spec["target"]))
	if kind == "checkpoint":
		return "E  点亮路灯 · 保存 / 恢复"
	if kind == "interior_exit":
		return "E  推门返回 · "+ExplorationCatalog.title(str(spec["target"]))
	if kind == "mirror":
		var index: int = int(spec["index"])
		return "E  转动第 %d 面镜子 · 当前刻度 %d" % [index + 1, int(session.mirrors[index]) + 1]
	return "E  " + str(spec.get("title", "调查"))

func _process(delta: float) -> void:
	_clock += delta
	visible = not (str(spec.get("kind","")) in ["memory","ability","relic","flashback","true_memory"] and is_finished())
	queue_redraw()

func _draw() -> void:
	var kind: String = str(spec.get("kind", "memory"))
	var accent := Color("8ed9de")
	if is_finished():
		accent = Color("658078")
	if kind == "exit":
		var unlocked: bool = session.satisfies(spec.get("requires", []))
		accent = Color("8fcbd3") if unlocked else Color("ad6d62")
		if _arch != null:
			draw_texture_rect(_arch, Rect2(-63, -165, 126, 171), false)
		draw_arc(Vector2(0, -77), 42, PI, TAU, 24, Color(accent, 0.45), 2.0, true)
		if not unlocked:
			for i: int in range(-2, 3):
				draw_line(Vector2(i*13, -113), Vector2(i*13, -4), Color(accent, .6), 3.0, true)
	elif kind == "interior_exit":
		var door: Texture2D = ExplorationArt.sprite("gate_panels",0,"gates")
		if door != null:
			draw_texture_rect(door,Rect2(-53,-191,106,191),false,Color(.8,.87,.81))
		draw_circle(Vector2(29,-87),5,Color("e3c98e"))
		draw_line(Vector2(-20,-82),Vector2(15,-82),Color("a9d9cc"),3,true)
		draw_line(Vector2(-20,-82),Vector2(-6,-96),Color("a9d9cc"),3,true)
	elif kind == "checkpoint":
		if _lantern != null:
			draw_texture_rect(_lantern, Rect2(-42, -174, 84, 180), false)
		for radius: float in [78.0, 50.0, 24.0]:
			draw_circle(Vector2(0, -127), radius, Color(1, 0.7, 0.32, 0.035))
	elif kind == "mirror":
		var index: int = int(spec["index"])
		var solved: bool = int(session.mirrors[index]) == int(ExplorationCatalog.data()["mirror_solution"][index])
		if _mirror != null:
			draw_texture_rect(_mirror,Rect2(-36,-124,72,124),false,Color(1,1,1) if solved else Color(.7,.8,.85))
		else:
			draw_style_box(_mirror_style(solved), Rect2(-24, -95, 48, 92))
		draw_line(Vector2(-14, -55).rotated(float(session.mirrors[index])*PI*.25)+Vector2(0,-10), Vector2(14,-25).rotated(float(session.mirrors[index])*PI*.25)+Vector2(0,-10), Color("cfe6df"), 3, true)
		draw_string(_font, Vector2(-6, -107), str(int(session.mirrors[index])+1), HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color("e2c48d"))
	elif kind == "thread":
		if not is_finished():
			draw_line(Vector2(-55, -155), Vector2(55, 0), Color("d97277"), 2.5, true)
			draw_line(Vector2(55, -155), Vector2(-55, 0), Color("d97277"), 2.5, true)
	elif kind == "lift_call":
		draw_rect(Rect2(-20,-66,40,66),Color("263339"))
		draw_rect(Rect2(-17,-63,34,54),Color("68614a"),false,3)
		draw_circle(Vector2(0,-35),14,Color("9d8155"))
		draw_circle(Vector2(0,-35),8,Color("263339"))
		draw_line(Vector2(0,-35),Vector2(18,-52),Color("bd9b65"),5,true)
		draw_circle(Vector2(18,-52),5,Color("ded0a2"))
		draw_circle(Vector2(0,-79),4,Color("8dd5bb") if session.has(str(spec["unlock"])) else Color("a87653"))
	elif kind == "switch":
		draw_rect(Rect2(-22, -25, 44, 25), Color("554c40"))
		draw_line(Vector2(0,-12), Vector2(19 if is_finished() else -19,-55), Color("cca475"), 7.0, true)
	elif kind == "sign":
		for x: float in [-25,25]:
			draw_line(Vector2(x,-60),Vector2(x,-3),Color("30281f"),10,true)
			draw_line(Vector2(x-2,-58),Vector2(x-2,-4),Color("8c7250"),2,true)
			draw_rect(Rect2(x-8,-7,16,8),Color("5a6054"))
		draw_rect(Rect2(-40,-80,80,53),Color("251f19"))
		for row: int in range(3):
			draw_rect(Rect2(-36,-76+row*15,72,13),Color("67533c"))
			draw_line(Vector2(-33,-73+row*15),Vector2(33,-73+row*15),Color("988363"),1,true)
		for x: float in [-30,30]:
			for y: float in [-70,-39]:
				draw_circle(Vector2(x,y),2,Color("ba9e6e"))
	elif kind=="memory" and spec.get("style","")=="paper" and not is_finished():
		draw_rect(Rect2(-37,-70,74,12),Color("806e50"))
		for leg: float in [-28,28]:
			draw_line(Vector2(leg,-58),Vector2(leg,0),Color("3c3a30"),7,true)
		draw_rect(Rect2(-18,-89,36,19),Color("d9d5b7"))
		for y: int in [-85,-80,-75]:
			draw_line(Vector2(-12,y),Vector2(12,y),Color("7b8476"),1,true)
		for radius: float in [28,15]:
			draw_circle(Vector2(0,-88),radius,Color(.7,.95,.86,.05))
	elif not is_finished():
		var bob: float = sin(_clock * 2.2) * 5.0
		for radius: float in [35.0,22.0,12.0]:
			draw_circle(Vector2(0,-50+bob),radius,Color(accent,0.055))
		draw_colored_polygon(PackedVector2Array([Vector2(0,-71+bob),Vector2(13,-51+bob),Vector2(0,-30+bob),Vector2(-13,-51+bob)]), accent)
		draw_arc(Vector2(0,-51+bob), 23, _clock*.3, _clock*.3 + PI*1.6, 28, Color(accent,.65), 1.5, true)
	if focused:
		draw_circle(Vector2(0, -197 if kind in ["exit","checkpoint"] else -137), 13, Color("18242a"))
		draw_string(_font, Vector2(-5, -191 if kind in ["exit","checkpoint"] else -131), "E", HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("d8e6db"))

func _mirror_style(correct: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("24434a") if correct else Color("2a2b37")
	style.border_color = Color("cfb27b")
	style.set_border_width_all(4)
	style.set_corner_radius_all(18)
	return style
