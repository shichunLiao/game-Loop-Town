class_name ExplorationStreetAccess
extends Node2D
## Short timber stairs and the visible house roof share authored surface points.

var routes: Array = []

func _ready() -> void:
	z_index = -6
	for entry: Dictionary in routes:
		var points: PackedVector2Array = _points(entry)
		var body := StaticBody2D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		add_child(body)
		for i: int in range(points.size()-1):
			var start: Vector2 = points[i]
			var end: Vector2 = points[i+1]
			var polygon := CollisionPolygon2D.new()
			polygon.polygon = PackedVector2Array([start,end,end+Vector2(0,9),start+Vector2(0,9)])
			polygon.one_way_collision = true
			polygon.one_way_collision_margin = 8
			body.add_child(polygon)
	queue_redraw()

func _points(entry: Dictionary) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point: Array in entry["points"]:
		result.append(ExplorationCatalog.vec(point))
	return result

func _draw() -> void:
	for entry: Dictionary in routes:
		if str(entry["kind"])!="stairs":
			continue
		var points: PackedVector2Array = _points(entry)
		var a: Vector2 = points[0]
		var b: Vector2 = points[1]
		var steps: int = maxi(6,int(absf(b.y-a.y)/13))
		var dark := Color("30271f")
		var timber := Color("78624a")
		draw_line(a+Vector2(0,17),b+Vector2(0,17),dark,17,true)
		draw_line(a+Vector2(0,13),b+Vector2(0,13),Color("574536"),4,true)
		for i: int in range(steps+1):
			var t: float = float(i)/steps
			var p: Vector2 = a.lerp(b,t)
			var tread: float = (b.x-a.x)/steps+5
			draw_rect(Rect2(p-Vector2(tread*.5,1),Vector2(tread,7)),dark)
			draw_line(p-Vector2(tread*.5,1),p+Vector2(tread*.5,-1),timber,3,true)
			if i%3==0:
				draw_line(p,p+Vector2(0,-42),dark,5,true)
				draw_circle(p+Vector2(0,7),2,Color("a69168"))
		draw_line(a+Vector2(0,-42),b+Vector2(0,-42),dark,6,true)
		draw_line(a+Vector2(0,-45),b+Vector2(0,-45),timber,2,true)
		draw_line(b+Vector2(-6,6),Vector2(b.x-6,a.y),dark,10,true)
		draw_line(b+Vector2(-8,6),Vector2(b.x-8,a.y),timber,2,true)
