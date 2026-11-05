class_name ExplorationKeeperLimb
extends Node2D
## A hand out of the tower floor: a short warning, then one grab at that spot.

var session: ExplorationSession
var warning: float = .75
var damage: int = 10
var _age: float = 0
var _struck: bool = false

func _ready() -> void:
	z_index = 7

func _physics_process(delta: float) -> void:
	_age += delta*(.3 if session.slow_time>0 else 1.0)
	if _age>=warning and not _struck:
		_struck = true
		var hit := ExplorationHitArea.new()
		hit.source = self
		hit.target_layer = 8
		hit.damage = damage
		hit.dimensions = Vector2(70,110)
		hit.position = Vector2(0,-55)
		hit.direction = Vector2.UP
		hit.lifetime = .22
		add_child(hit)
	if _age>=warning+.4:
		queue_free()
	queue_redraw()

func _draw() -> void:
	var red := Color("d8394a")
	if _age<warning:
		var progress: float = clampf(_age/warning,0,1)
		draw_line(Vector2(-35,-3),Vector2(35,-3),Color(red,.4+progress*.5),4,true)
		draw_arc(Vector2(0,-5),12+progress*18,PI,TAU,20,red,2,true)
		return
	# Forearm and five fingers, rising then sinking back.
	var rise: float = sin(clampf((_age-warning)/.4,0,1)*PI)
	var skin := Color("3a2a2c")
	var wrist := Vector2(0,-92*rise)
	draw_line(Vector2.ZERO,wrist,skin,16,true)
	for i: int in range(5):
		var finger := Vector2.from_angle(-PI*.5+(i-2)*.32)
		draw_line(wrist,wrist+finger*30*rise,skin,5,true)
