class_name ExplorationLingVine
extends Node2D
## One thorned vine whipped across the chamber: a thin red warning line, then the lash.

var session: ExplorationSession
var to: Vector2
var warning: float = .7
var damage: int = 12
var _age: float = 0
var _struck: bool = false

func _ready() -> void:
	z_index = 7
	add_to_group("ling_owned")

func _physics_process(delta: float) -> void:
	_age += delta*(.3 if session.slow_time>0 else 1.0)
	if _age>=warning and not _struck:
		_struck = true
		var hit := ExplorationHitArea.new()
		hit.source = self
		hit.target_layer = 8
		hit.damage = damage
		hit.silent = true
		hit.dimensions = Vector2(to.length(),30)
		hit.position = to*.5
		hit.rotation = to.angle()
		hit.lifetime = .2
		add_child(hit)
		get_node("/root/AudioManager").play_sfx("sfx_attack_swing")
	if _age>=warning+.42:
		queue_free()
	queue_redraw()

func _draw() -> void:
	var red := Color("d8394a")
	if _age<warning:
		var progress: float = clampf(_age/warning,0,1)
		draw_line(Vector2.ZERO,to,Color(red,.25+progress*.6),2+progress*3,true)
		return
	var length: float = clampf((_age-warning)/.1,0,1)*clampf((warning+.42-_age)/.14,0,1)
	var end: Vector2 = to*length
	draw_line(Vector2.ZERO,end,Color("2f4a33"),13,true)
	draw_line(Vector2.ZERO,end,Color("4d6e4a"),5,true)
	var step: Vector2 = to.normalized()*38
	var side: Vector2 = to.normalized().orthogonal()*15
	for i: int in range(int(end.length()/38)):
		draw_line(step*i,step*i+(side if i%2==0 else -side)+step*.2,Color("8fa05f"),3,true)
