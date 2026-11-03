class_name ExplorationHitArea
extends Area2D
## Short lived, overlap driven hitbox. A swing can hit each hurtbox only once.

var damage: int = 20
var lifetime: float = .14
var dimensions: Vector2 = Vector2(100,65)
var target_layer: int = 16
var source: Node2D
var kind: String = "slash"
var direction: Vector2 = Vector2.RIGHT
var _hit: Dictionary = {}
var _age: float = 0.0
var finisher: bool = false

func _ready() -> void:
	collision_layer = 0
	collision_mask = target_layer
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = dimensions
	shape.shape = rectangle
	add_child(shape)
	area_entered.connect(_on_area)
	z_index = 12

func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
	queue_redraw()

func _on_area(area: Area2D) -> void:
	var receiver: Node = area.get_parent()
	if receiver == source or not receiver.has_method("receive_hit") or _hit.has(receiver.get_instance_id()):
		return
	if receiver.has_method("can_receive_hit") and not bool(receiver.call("can_receive_hit")):
		return
	_hit[receiver.get_instance_id()] = true
	receiver.call("receive_hit",damage,source.global_position if is_instance_valid(source) else global_position,kind)
	if is_instance_valid(source) and source.has_method("on_attack_landed"):
		source.call("on_attack_landed",receiver,direction)

func _draw() -> void:
	var tint: Color = Color({"notebook":"b5f2e3","shears":"e2e8cf","thread":"f18fa2","ember":"72eee3","clock":"f2ca82"}.get(kind,"a9f3ef")) if target_layer==16 else Color("efb078")
	var progress: float = clampf(_age/lifetime,0,1)
	tint.a = 1-progress*.7
	draw_set_transform(Vector2.ZERO,direction.angle())
	if kind=="clock":
		draw_line(Vector2(-dimensions.x*.45,0),Vector2(dimensions.x*.62,0),tint,7 if finisher else 4,true)
		draw_arc(Vector2.ZERO,40+progress*28,0,TAU,48,Color(tint,.6-progress*.5),2,true)
		for i: int in range(12):
			var ray := Vector2.from_angle(i*TAU/12)
			draw_line(ray*38,ray*46,Color(tint,.65),2,true)
	elif kind=="thread":
		for i: int in range(3):
			draw_arc(Vector2.ZERO,dimensions.x*(.35+i*.065),-PI+progress*TAU+i,progress*TAU+i,36,Color(tint,.72-i*.17),2,true)
	elif kind=="notebook":
		draw_arc(Vector2(-25,0),dimensions.x*.7,-1.2+progress*.8,.8+progress*.8,24,tint,3,true)
		for i: int in range(6):
			var point := Vector2(-25+i*17,-45+sin(i*2+progress*4)*20)
			draw_set_transform(point,progress+i*.5)
			draw_rect(Rect2(-4,-6,8,12),Color(tint,(1-progress)*.7))
		draw_set_transform(Vector2.ZERO,direction.angle())
	else:
		for i: int in range(3):
			draw_arc(Vector2(-dimensions.x*.3,0),dimensions.x*(.55+i*.06),-.95+progress*.7,.95+progress*.7,28,Color(tint,tint.a*(1-i*.28)),5-i,true)
		if kind=="shears":
			draw_line(Vector2(-40,-30),Vector2(dimensions.x*.5,18-progress*36),tint,2,true)
			draw_line(Vector2(-40,30),Vector2(dimensions.x*.5,-18+progress*36),tint,2,true)
		if kind=="ember":
			for i: int in range(12):
				var point := Vector2(i*11-60,sin(i*2.5+progress*3)*34)
				draw_line(point,point-Vector2(18+progress*25,6),Color(tint,(1-progress)*.7),2,true)
	if finisher:
		for i: int in range(8):
			var ray := Vector2.from_angle(i*TAU/8+progress)
			draw_line(ray*18,ray*(35+progress*65),Color(tint,.5*(1-progress)),2,true)
	draw_set_transform(Vector2.ZERO)

static func hurtbox(host: Node2D, layer: int, dimensions: Vector2, offset: Vector2) -> Area2D:
	var area := Area2D.new()
	area.name = "Hurtbox"
	area.collision_layer = layer
	area.collision_mask = 0
	area.position = offset
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = dimensions
	shape.shape = rectangle
	area.add_child(shape)
	host.add_child(area)
	return area
