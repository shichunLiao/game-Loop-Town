class_name ExplorationLingMud
extends Node2D
## The mud across the whole chamber, drawn above Jerry, and the dark her voice brings with it.

var boss: ExplorationLingBoss
var _clock: float = 0

func _ready() -> void:
	top_level = true
	global_position = Vector2.ZERO
	z_as_relative = false
	z_index = 6

func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()

func _draw() -> void:
	var y: float = boss.mud_y
	var bottom: float = boss.floor_y+8
	if y<bottom:
		draw_rect(Rect2(0,y,2400,bottom-y),Color("2b2116",.93))
		var surface := PackedVector2Array()
		for x: int in range(0,2400,28):
			surface.append(Vector2(x,y+sin(x*.025+_clock*1.8)*5))
		draw_polyline(surface,Color("6f5a3a"),3,true)
		for i: int in range(8):
			var x: float = fmod(i*271.0+_clock*(9+i),2000.0)+200
			draw_arc(Vector2(x,y+7+i%3*5),3+i%3*2,PI,TAU,10,Color("8a7350",.7),1.5,true)
	var player: ExplorationPlayer = get_tree().get_first_node_in_group("exploration_player") as ExplorationPlayer
	if player==null:
		return
	var at: Vector2 = player.global_position+Vector2(0,-50)
	if player.grip>0:
		draw_arc(at,62,-PI*.5,-PI*.5+TAU*(1.0-boss.hold_ratio()),40,Color("e9c78a"),5,true)
	var shade: float = clampf(boss.dark/.5,0,1)*clampf((3.2-boss.dark)/.3,0,1)*.88
	if shade>0:
		for i: int in range(6):
			draw_arc(at,250+i*46,0,TAU,72,Color(0,0,0,shade*(i+1)/6.0),46)
		draw_arc(at,1700,0,TAU,72,Color(0,0,0,shade),2400)
