class_name ExplorationBossAttack
extends Area2D
## World-space warning and damaging wax effect share the same footprint.

var owner_boss: Node2D
var session: ExplorationSession
var style: String = "pillar"
var warning: float = .85
var duration: float = .55
var width: float = 108
var height: float = 160
var damage: int = 20
var speed: float = 0
var phase: int = 1
var _age: float = 0
var _shape: CollisionShape2D
var _struck: Dictionary = {}

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width,80 if style=="rain" else height)
	_shape.shape = rect
	_shape.position.y = -height*.5
	_shape.disabled = true
	add_child(_shape)
	add_to_group("morris_owned")
	set_meta("boss_id",owner_boss.get_instance_id())
	z_index = 7

func _physics_process(delta: float) -> void:
	if not is_instance_valid(owner_boss) or owner_boss.dead:
		queue_free()
		return
	_age += delta*(.3 if session.slow_time>0 else 1.0)
	var active: bool = _age>=warning
	_shape.set_deferred("disabled",not active)
	if active:
		if style=="rain":
			_shape.position.y = -height*(1-clampf((_age-warning)/.4,0,1))-40
		position.x += speed*delta*(.3 if session.slow_time>0 else 1)
		for body: Node2D in get_overlapping_bodies():
			if body is ExplorationPlayer:
				var id: int = body.get_instance_id()
				if not _struck.has(id) or (style=="pool" and _age-float(_struck[id])>1.15):
					body.take_damage(damage)
					_struck[id] = _age
	if _age>=warning+duration:
		queue_free()
	queue_redraw()

func _draw() -> void:
	var ink := Color("ffbd68") if phase<3 else Color("ff865a")
	var active: bool = _age>=warning
	if not active:
		var progress: float = clampf(_age/warning,0,1)
		draw_line(Vector2(-width*.5,-3),Vector2(width*.5,-3),Color(ink,.45+progress*.5),4,true)
		for x: int in range(-int(width*.5),int(width*.5),18):
			draw_line(Vector2(x,-8),Vector2(x+8,-16-progress*10),Color(ink,.65),2,true)
		draw_arc(Vector2(0,-5),12+progress*13,PI,TAU,24,ink,2,true)
		return
	var t: float = clampf((_age-warning)/duration,0,1)
	if style=="rain":
		var drop: float = clampf((_age-warning)/.4,0,1)
		var center := Vector2(0,-height*(1-drop)-40)
		draw_line(center-Vector2(0,85),center,Color(ink,.6),7,true)
		draw_circle(center,20,Color("b66c3e"))
		draw_circle(center,15,ink)
		draw_circle(center+Vector2(-4,-4),5,Color("ffead0"))
	elif style=="pool":
		_draw_pool_ellipse(Vector2.ZERO,Vector2(width*.5,13),Color("77432c"))
		draw_arc(Vector2(0,-3),width*.35,PI,TAU,30,ink,3,true)
		for i: int in range(6):
			draw_circle(Vector2(-width*.4+i*width*.15,-8-sin(_age*8+i)*4),3,ink)
	else:
		var rise: float = minf(1,(_age-warning)*10)*(1-pow(t,5))
		var shape := PackedVector2Array([Vector2(-width*.5,0),Vector2(-width*.32,-height*.35*rise),Vector2(-width*.18,-height*.9*rise),Vector2(0,-height*rise),Vector2(width*.22,-height*.62*rise),Vector2(width*.4,-height*.24*rise),Vector2(width*.5,0)])
		draw_colored_polygon(shape,Color("b66c3e"))
		draw_polyline(shape,ink,3,true)
		for i: int in range(4):
			draw_line(Vector2(-width*.25+i*width*.16,-8),Vector2(-width*.2+i*width*.13,-height*(.3+i*.14)*rise),Color("f6d49b"),3,true)

func _draw_pool_ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i: int in range(40):
		points.append(center+Vector2(cos(i*TAU/40)*radius.x,sin(i*TAU/40)*radius.y))
	draw_colored_polygon(points,color)
