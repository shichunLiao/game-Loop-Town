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
		get_node("/root/AudioManager").play_sfx("sfx_mud_grab")
	if not _holding and _age>=warning+.45:
		queue_free()
	queue_redraw()

func _draw() -> void:
	var mud := Color("3a2c1c")
	if _age<warning:
		var progress: float = clampf(_age/warning,0,1)
		var marker: Texture2D = ExplorationArt.sprite("ground_hand",-1,"props")
		if marker!=null:
			draw_texture_rect(marker,Rect2(-42,-18,84,20),false,Color(1,1,1,.35+progress*.55))
		return
	var rise: float = 1.0 if _holding else sin(clampf((_age-warning)/.45,0,1)*PI)
	# A mud hand out of the mud (Codex art, Demo 9), rising and sinking back.
	var hand: Texture2D = ExplorationArt.sprite("ling_hand")
	if hand!=null and rise>.02:
		var height: float = 96*rise
		var width: float = 96*hand.get_width()/hand.get_height()
		draw_texture_rect(hand,Rect2(Vector2(-width*.5,-height),Vector2(width,height)),false)
	draw_line(Vector2(-24,0),Vector2(24,0),mud,6,true)
