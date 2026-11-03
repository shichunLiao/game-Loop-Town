class_name ExplorationWorldMap
extends Control
## Draws all 18 actual rooms, platform silhouettes, reciprocal links and lock state.

signal travel_requested(room_id: String)
var session: ExplorationSession
var overview: bool = false
var font: Font
var _rectangles: Dictionary = {}

func _ready() -> void:
	font = load("res://assets/ui/exploration/chinese.tres") as Font
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		accept_event()

func _process(_delta: float) -> void:
	if visible:
		queue_redraw()

func _draw() -> void:
	if session == null or font == null:
		return
	var ratio: float = size.x / 1280.0
	draw_rect(Rect2(Vector2.ZERO, size), Color("101a20"))
	for x: int in range(0,int(size.x),int(40*ratio)):
		draw_line(Vector2(x,0),Vector2(x,size.y),Color(0.4,.6,.65,.035),1)
	for y: int in range(0,int(size.y),int(40*ratio)):
		draw_line(Vector2(0,y),Vector2(size.x,y),Color(0.4,.6,.65,.035),1)
	draw_string(font, Vector2(46,47)*ratio, "回环镇 · 全域地图", HORIZONTAL_ALIGNMENT_LEFT,-1,int(27*ratio), Color("e4d7b6"))
	draw_string(font, Vector2(46,74)*ratio, "18 个主要区域 / 23 段实体楼梯、井道与连廊 / 上下方向对应实际通路", HORIZONTAL_ALIGNMENT_LEFT,-1,int(13*ratio), Color("849c9f"))
	var scale_factor := Vector2(size.x / 18.0, (size.y-150.0*ratio)/13.3)
	var offset := Vector2(42.0*ratio, 111.0*ratio) - Vector2(0,-3.1)*scale_factor
	var rooms: Dictionary = ExplorationCatalog.data()["rooms"]
	_rectangles.clear()
	for id: String in rooms:
		if not bool(rooms[id].get("main_region",true)):
			continue
		var r: Array = rooms[id]["map_rect"]
		_rectangles[id] = Rect2(Vector2(float(r[0]),float(r[1]))*scale_factor+offset,Vector2(float(r[2]),float(r[3]))*scale_factor)
	for id: String in rooms:
		if not rooms[id].has("region_pair"):
			continue
		var pair: Array = rooms[id]["region_pair"]
		var a: Vector2 = (_rectangles[str(pair[0])] as Rect2).get_center()
		var b: Vector2 = (_rectangles[str(pair[1])] as Rect2).get_center()
		var midpoint := Vector2(b.x,a.y)
		var unlocked: bool = true
		for exit: Dictionary in rooms[str(pair[0])]["exits"]:
			if str(exit["target"])==id:
				unlocked = exit.get("requires",[]).is_empty() or session.has("opened_"+str(exit.get("gate_id",exit["id"])))
		var current: bool = id==session.room_id and not overview
		var line_color := Color("efd097") if current else Color("698b88") if unlocked or overview else Color("784f46")
		draw_polyline(PackedVector2Array([a,midpoint,b]),line_color,(3 if current else 1.5)*ratio,true)
		draw_circle(a.lerp(b,.5),3*ratio,Color("d4af76") if unlocked else Color("a55b54"))
	for id: String in rooms:
		if not _rectangles.has(id):
			continue
		var r: Dictionary = rooms[id]
		var box: Rect2 = _rectangles[id]
		var visited: bool = session.visited.has(id) or overview
		var accent: Color = ExplorationCatalog.color_for(str(r["theme"]))
		var current: bool = id == session.room_id and not overview
		if not overview:
			var task: Dictionary = ExplorationJournal.target(session)
			var target_id: String = str(task.get("room",""))
			var region: String = str(ExplorationCatalog.room(target_id).get("parent_region",target_id))
			if region==id:
				draw_colored_polygon(PackedVector2Array([box.position+Vector2(-7,-15)*ratio,box.position+Vector2(0,-8)*ratio,box.position+Vector2(-7,-1)*ratio,box.position+Vector2(-14,-8)*ratio]),Color("e9c37f"))
		var style := StyleBoxFlat.new()
		style.bg_color = Color(accent.darkened(.79),1) if visited else Color("19242a")
		style.border_color = Color("f0d49b") if current else Color(accent,.9 if visited else .3)
		style.set_border_width_all(int(2*ratio) if current else maxi(1,int(ratio)))
		style.set_corner_radius_all(int(3*ratio))
		draw_style_box(style,box)
		var world_size: Vector2 = ExplorationCatalog.vec(r["size"])
		for platform: Dictionary in r["platforms"]:
			var rect: Array = platform["rect"]
			var pos := Vector2(float(rect[0]),float(rect[1]))/world_size
			var dimensions := Vector2(float(rect[2]),maxf(15.0,float(rect[3])))/world_size
			var platform_box := Rect2(box.position+pos*box.size,Vector2(dimensions.x*box.size.x,maxf(1*ratio,dimensions.y*box.size.y)))
			draw_rect(platform_box.intersection(box),Color(accent,.3))
		for route: Dictionary in r.get("street_access",[]):
			var path := PackedVector2Array()
			for point: Array in route["points"]:
				path.append(box.position+ExplorationCatalog.vec(point)/world_size*box.size)
			if path.size()>1:
				draw_polyline(path,Color(accent,.5),maxf(1,ratio),true)
		var label: String = str(r["name"]).replace(" · ","\n")
		var lines: PackedStringArray = label.split("\n")
		for i: int in range(lines.size()):
			draw_string(font,box.position+Vector2(0,18*ratio+i*14*ratio),lines[i],HORIZONTAL_ALIGNMENT_CENTER,box.size.x,int(12*ratio),Color("e4e2cf") if visited else Color("839193"))
		if bool(session.switches.get("lamp_"+id,false)) or overview:
			draw_circle(box.end-Vector2(9,9)*ratio,3.0*ratio,Color("e0b56d"))
		if current:
			draw_circle(box.get_center()+Vector2(0,18*ratio),4*ratio,Color("b2e8e6"))
	draw_string(font,Vector2(46,size.y/ratio-25)*ratio,"浅色轮廓：已探索    金点：存档路灯    红点：未解锁通路    金线：当前连接道路    M / Esc 关闭",HORIZONTAL_ALIGNMENT_LEFT,-1,int(13*ratio),Color("a0b9b6"))
