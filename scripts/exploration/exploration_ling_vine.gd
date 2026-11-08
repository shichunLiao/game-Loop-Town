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
		get_node("/root/AudioManager").play_sfx("sfx_vine_lash")
	if _age>=warning+.42:
		queue_free()
	queue_redraw()

func _draw() -> void:
	if _age<warning:
		var progress: float = clampf(_age/warning,0,1)
		ExplorationArt.strand(self,"red_thread",Vector2.ZERO,to,2+progress*3,Color(1,1,1,.25+progress*.6))
		return
	var length: float = clampf((_age-warning)/.1,0,1)*clampf((warning+.42-_age)/.14,0,1)
	ExplorationArt.strand(self,"vine",Vector2.ZERO,to*length,30)
