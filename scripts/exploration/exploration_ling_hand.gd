class_name ExplorationLingHand
extends Node2D
## A hand up out of the mud: a ripple of warning, then it closes on whatever ankle stands there.

var boss: ExplorationLingBoss
var session: ExplorationSession
var warning: float = .8
var _age: float = 0
var _closed: bool = false
var _holding: bool = false

func _ready() -> void:
	z_index = 7
	add_to_group("ling_owned")
	add_to_group("ling_hands")

func let_go() -> void:
	_holding = false

func _physics_process(delta: float) -> void:
	_age += delta*(.3 if session.slow_time>0 else 1.0)
	position.y = minf(boss.mud_y,boss.floor_y)
	if _age>=warning and not _closed:
		_closed = true
		_holding = boss.try_grab(position.x)
	if not _holding and _age>=warning+.45:
		queue_free()
	queue_redraw()

func _draw() -> void:
	var mud := Color("3a2c1c")
	if _age<warning:
		var progress: float = clampf(_age/warning,0,1)
		draw_line(Vector2(-42,-2),Vector2(42,-2),Color("d8394a",.35+progress*.55),4,true)
		draw_arc(Vector2(0,-2),10+progress*26,PI,TAU,18,Color("d8394a"),2,true)
		return
	var rise: float = 1.0 if _holding else sin(clampf((_age-warning)/.45,0,1)*PI)
	# A mud hand out of the mud (Codex art, Demo 9), rising and sinking back.
	var hand: Texture2D = ExplorationArt.sprite("ling_hand")
	if hand!=null and rise>.02:
		var height: float = 96*rise
		var width: float = 96*hand.get_width()/hand.get_height()
		draw_texture_rect(hand,Rect2(Vector2(-width*.5,-height),Vector2(width,height)),false)
	draw_line(Vector2(-24,0),Vector2(24,0),mud,6,true)
