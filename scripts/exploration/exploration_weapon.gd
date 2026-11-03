class_name ExplorationWeapon
extends Node2D
## A separately animated weapon pivot, driven by actual combat phases.

static var _profiles: Array = []
var fighter: ExplorationPlayer
var blade: Sprite2D
var _selected: String = ""
var _angle: float = .6
var _reach: float = 75
var _ink: Color = Color("b8f2e4")

static func profile(session: Node) -> Dictionary:
	if _profiles.is_empty():
		_profiles = JSON.parse_string(FileAccess.get_file_as_string("res://data/exploration/weapons.json"))
	var result: Dictionary = _profiles[0]
	for entry: Dictionary in _profiles:
		if str(entry["requires"]).is_empty() or session.has(str(entry["requires"])):
			result = entry
	return result

func _ready() -> void:
	z_index = 8
	blade = Sprite2D.new()
	add_child(blade)

func _process(_delta: float) -> void:
	if not is_instance_valid(fighter):
		return
	var stats: Dictionary = profile(fighter.session)
	if _selected != str(stats["id"]):
		_selected = str(stats["id"])
		blade.texture = ExplorationArt.sprite("stage_weapons",int(stats["cell"]),"weapons") if int(stats["cell"])>=0 else null
		_ink = Color(str(stats["color"]))
	var phase: String = fighter.attack_phase
	var ratio: float = 0.0
	if phase=="windup":
		ratio = 1-clampf(fighter._attack_timer/(float(stats["windup"])* (1.7 if fighter._special_attack else 1.0)),0,1)
		_angle = lerpf(.5,-1.9,ratio)
		_reach = lerpf(63,80,ratio)
	elif phase=="active":
		ratio = 1-clampf(fighter._attack_timer/float(stats["active"]),0,1)
		_angle = lerpf(-1.9,1.3,ratio)
		if fighter.combo==2:
			_angle = lerpf(1.3,-1.9,ratio)
		if fighter.combo==3:
			_angle = lerpf(-2.1,4.2,ratio)
		if fighter._special_attack and _selected=="clock":
			_angle = -.08
		_reach = float(stats["reach"])*(.84 if fighter.combo==3 else .7)
	elif phase=="recover":
		ratio = 1-clampf(fighter._attack_timer/float(stats["recovery"]),0,1)
		_angle = lerpf(1.3,.5,ratio)
		_reach = lerpf(95,63,ratio)
	else:
		_angle = .55+sin(fighter._clock*2)*.045
		_reach = 63
	var facing: float = fighter.facing
	position = Vector2(12*facing,-42)
	var aim: float = fighter._attack_direction.angle() if phase!="ready" else (0.0 if facing>0 else PI)
	var swing: float = _angle*facing if fighter._attack_direction.y==0 or phase=="ready" else _angle
	blade.rotation = aim+swing
	if blade.texture != null:
		blade.scale = Vector2.ONE*_reach/blade.texture.get_width()
		blade.position = Vector2.from_angle(blade.rotation)*_reach*.32
	blade.modulate = Color(1,1,1,.72 if phase=="ready" else 1)
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(fighter):
		return
	var phase: String = fighter.attack_phase
	var facing: float = fighter.facing
	var hand := Vector2(9*facing,0)
	draw_line(Vector2(-12*facing,4),hand,Color("18252b"),9,true)
	draw_line(Vector2(-12*facing,1),hand-Vector2(0,3),Color("7a9c9e"),1.2,true)
	draw_circle(hand,4,Color("a8b6a9"))
	if _selected=="notebook" and phase!="ready":
		draw_set_transform(hand,_angle*facing)
		draw_rect(Rect2(-4,-16,20,30),Color("304e52"))
		draw_rect(Rect2(0,-13,14,24),_ink)
		for y: int in [-8,-2,4]:
			draw_line(Vector2(3,y),Vector2(11,y),Color("5b9b9b"),1,true)
		draw_set_transform(Vector2.ZERO)
	if phase=="windup":
		for i: int in range(4):
			draw_line(Vector2.from_angle(i*TAU/4)*20,Vector2.from_angle(i*TAU/4)*10,Color(_ink,.45),1.5,true)
	if phase=="active" and fighter.combo==3:
		draw_arc(Vector2(-12*facing,0),48,-2.4,2.4,30,Color(_ink,.4),2,true)
