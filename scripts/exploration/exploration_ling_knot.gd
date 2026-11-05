class_name ExplorationLingKnot
extends Node2D
## A glowing knot of thorned vine. Cutting it lets the mud fall back and bares Ling's body.

var boss: ExplorationLingBoss
var _clock: float = 0

func _ready() -> void:
	ExplorationHitArea.hurtbox(self,16,Vector2(64,72),Vector2.ZERO)
	z_index = 9

func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()

func can_receive_hit() -> bool:
	return is_instance_valid(boss) and not boss.dead

func receive_hit(_amount: int, _origin: Vector2, _kind: String = "slash") -> void:
	if not can_receive_hit():
		return
	boss.on_knot_cut()
	queue_free()

func _draw() -> void:
	var root: Vector2 = boss.global_position+Vector2(0,-320)-global_position
	draw_line(Vector2.ZERO,root,Color("3c5a3e",.8),5,true)
	var pulse: float = sin(_clock*5)
	for i: int in range(3):
		draw_arc(Vector2.ZERO,20+i*6,_clock*(1.5+i*.4),_clock*(1.5+i*.4)+TAU*.8,24,Color("3c5a3e"),6,true)
	draw_circle(Vector2.ZERO,13+pulse*2,Color("f0c56a"))
	draw_arc(Vector2.ZERO,38+pulse*5,0,TAU,32,Color("f0c56a",.65),3,true)
