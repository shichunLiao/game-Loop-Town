class_name ExplorationStructure
extends Node2D
## Masonry carries the decks into walls; open archways leave routes legible.

var data: Dictionary
var _face: AtlasTexture
var _surface: Texture2D

func _ready() -> void:
	z_index = -7
	_face = ExplorationArt.sprite("masonry_tiles_v7",int(data.get("masonry",0)),"masonry") as AtlasTexture
	if _face != null:
		_surface = ImageTexture.create_from_image(_face.get_image())
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	queue_redraw()

func _draw() -> void:
	if bool(data.get("street_architecture",false)):
		return
	for entry: Dictionary in data.get("platforms",[]):
		var support: String = str(entry.get("support",""))
		if support.is_empty():
			continue
		var a: Array = entry["rect"]
		var x: float = float(a[0])
		var y: float = float(a[1])+20
		var width: float = float(a[2])
		var drop: float = clampf(float(entry.get("support_floor",y+180))-y,75,500)
		if support == "arch" and width>320:
			_draw_arch(x,y,width,drop)
		else:
			var left: bool = support == "left_corbel" or (support=="corbel" and x<float(data["size"][0])*.5)
			var points: PackedVector2Array
			if left:
				points = PackedVector2Array([Vector2(x,y),Vector2(x+width,y),Vector2(x+width-20,y+42),Vector2(x+width*.62,y+70),Vector2(x+width*.28,y+drop),Vector2(x,y+drop)])
			else:
				points = PackedVector2Array([Vector2(x,y),Vector2(x+width,y),Vector2(x+width,y+drop),Vector2(x+width*.72,y+drop),Vector2(x+width*.38,y+70),Vector2(x+20,y+42)])
			_face_polygon(points)
	if bool(data.get("route_layout",{}).get("lift",false)):
		_draw_lift_shaft()

func _draw_arch(x: float,y: float,width: float,drop: float) -> void:
	var pier: float = minf(68,width*.13)
	var top: float = 44
	var points := PackedVector2Array([Vector2(x,y),Vector2(x+width,y),Vector2(x+width,y+drop),Vector2(x+width-pier,y+drop)])
	for j: int in range(17):
		var t: float = float(j)/16
		points.append(Vector2(x+width-pier-(width-2*pier)*t,y+drop-(drop-top)*sin(t*PI)))
	points.append(Vector2(x+pier,y+drop))
	points.append(Vector2(x,y+drop))
	_face_polygon(points)
	var rim := PackedVector2Array()
	for j: int in range(25):
		var t: float = float(j)/24
		rim.append(Vector2(x+pier+(width-2*pier)*t,y+drop-(drop-top)*sin(t*PI)))
	draw_polyline(rim,Color("515b54"),3,true)
	for j: int in range(1,12):
		var t: float = float(j)/12
		var center := Vector2(x+pier+(width-2*pier)*t,y+drop-(drop-top)*sin(t*PI))
		draw_line(center,center+Vector2((t-.5)*14,-15),Color("151f23"),2,true)

func _face_polygon(points: PackedVector2Array) -> void:
	if _face == null:
		draw_colored_polygon(points,Color("303b40"))
		return
	var uv := PackedVector2Array()
	for point: Vector2 in points:
		uv.append(point/Vector2(288,240))
	draw_polygon(points,PackedColorArray([Color(.56,.61,.60)]),uv,_surface)
	var edge := points.duplicate()
	edge.append(points[0])
	draw_polyline(edge,Color("172026"),3,true)

func _draw_lift_shaft() -> void:
	var route: Dictionary = data["route_layout"]
	var x: float = float(route["shaft_x"])
	var rests: Array = route["rests"]
	var top: float = float(rests[-1])-210
	var bottom: float = float(data["floor"])
	for rail_x: float in [x-96,x+96]:
		draw_line(Vector2(rail_x,top),Vector2(rail_x,bottom),Color("172229"),13)
		draw_line(Vector2(rail_x-2,top),Vector2(rail_x-2,bottom),Color("7d7056"),3)
		for y: int in range(int(top),int(bottom),120):
			draw_rect(Rect2(rail_x-13,y,26,10),Color("4b514a"))
			draw_circle(Vector2(rail_x,y+5),2,Color("b19969"))
	for rope: float in [-12,12]:
		draw_line(Vector2(x+rope,top),Vector2(x+rope,bottom),Color("403b30"),3)
	for y: float in [top,bottom]:
		draw_circle(Vector2(x,y),32,Color("17252a"))
		draw_arc(Vector2(x,y),26,0,TAU,32,Color("9a7a47"),5,true)
		for i: int in range(6):
			draw_line(Vector2(x,y),Vector2(x,y)+Vector2.from_angle(i*TAU/6)*24,Color("766247"),3,true)
