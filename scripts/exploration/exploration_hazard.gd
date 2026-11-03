class_name ExplorationHazard
extends Area2D
## Telegraphs alternate with damaging windows. Physical overlaps drive damage.

var spec: Dictionary
var _clock: float = 0.0
var dimensions: Vector2
var active: bool = false
var session: ExplorationSession

func _ready() -> void:
	var rect: Array = spec["rect"]
	position = Vector2(float(rect[0]), float(rect[1]))
	dimensions = Vector2(float(rect[2]), float(rect[3]))
	collision_layer = 0
	collision_mask = 2
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = dimensions
	shape.shape = box
	shape.position = dimensions*.5
	add_child(shape)
	_clock = float(spec.get("phase", 0.0))

func _physics_process(delta: float) -> void:
	_clock += delta*(.3 if session != null and session.slow_time>0 else 1.0)
	active = fposmod(_clock, float(spec.get("period", 4.0))) > 1.7
	if active:
		for body: Node2D in get_overlapping_bodies():
			if body is ExplorationPlayer:
				body.take_damage(25)
	queue_redraw()

func _draw() -> void:
	var bright := Color("d88b58") if str(spec.get("kind", "")) == "wax" else Color("d16b67")
	var color := Color(bright, .9 if active else .32)
	draw_rect(Rect2(Vector2.ZERO, dimensions), Color("33232a"))
	for x: int in range(0, int(dimensions.x), 12):
		var h: float = 18.0 + sin(_clock * 7.0 + x*.08)*12.0 if active else 3.0
		draw_colored_polygon(PackedVector2Array([Vector2(x,dimensions.y),Vector2(x+7,-h),Vector2(x+13,dimensions.y)]), color)
