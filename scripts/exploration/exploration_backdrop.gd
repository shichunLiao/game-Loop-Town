class_name ExplorationBackdrop
extends Node2D
## Distant panorama and atmosphere only. Reachable architecture belongs to Room.

var room: Dictionary
var session: ExplorationSession
var theme: String = "town"
var far_layer: Node2D
var far_sprite: Sprite2D
var _time: float = 0.0
var _camera: Camera2D

func _ready() -> void:
	theme = str(room.get("theme", "town"))
	if bool(room.get("vertical",false)):
		far_layer = Node2D.new()
	else:
		var distant := Parallax2D.new()
		distant.scroll_scale = Vector2(0.12,0.035)
		far_layer = distant
	far_layer.name = "BG_04_Far"
	far_layer.z_index = -50
	add_child(far_layer)
	far_sprite = Sprite2D.new()
	far_layer.add_child(far_sprite)
	_update_theme()
	session.changed.connect(_update_theme)

func _update_theme() -> void:
	var display_theme: String = str(room.get("background",theme))
	if session.stage >= 4 and theme == "town":
		display_theme = "fire"
	if session.has("zero_loop") and theme == "town":
		display_theme = "station"
	var path: String = "res://assets/environments/exploration/backgrounds/" + display_theme + ".png"
	if bool(room.get("vertical",false)) and not str(room.get("depth_background","")).is_empty():
		path = "res://assets/environments/exploration/depth/"+str(room["depth_background"])+".png"
	far_sprite.texture = load(path) as Texture2D
	if far_sprite.texture == null:
		return
	var room_size: Vector2 = ExplorationCatalog.vec(room["size"])
	var width: float = 1500.0 + room_size.x * 0.12
	var vertical: bool = bool(room.get("vertical",false))
	var height: float = 1100.0+room_size.y*.24 if vertical else 1000.0
	far_sprite.scale = Vector2(width / far_sprite.texture.get_width(), height / far_sprite.texture.get_height())
	far_sprite.position = Vector2(640+room_size.x*.06,360+room_size.y*(.12 if vertical else .0175))
	if vertical:
		far_sprite.scale = (room_size+Vector2(120,120))/far_sprite.texture.get_size()
		far_sprite.position = room_size*.5
	far_sprite.modulate = Color(.55,.66,.73) if session.stage<4 else Color(.63,.48,.43)

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	_camera = get_viewport().get_camera_2d()
	if _camera == null:
		return
	var center: Vector2 = _camera.get_screen_center_position()
	var rect := Rect2(center - Vector2(850, 520), Vector2(1700, 1040))
	var fire: bool = theme == "fire" or session.stage >= 4
	# Thin, independently drifting mist bands separate middle planes without
	# concealing playable ledges or creating a bright opaque blanket.
	for band: int in range(4):
		var y: float = rect.position.y+430+band*100+sin(_time*.18+band)*18
		var vertices := PackedVector2Array([Vector2(rect.position.x,y),Vector2(rect.end.x,y-20),Vector2(rect.end.x,y+85),Vector2(rect.position.x,y+75)])
		var tint := Color(.2,.32,.38,.032) if not fire else Color(.32,.18,.13,.025)
		draw_polygon(vertices,PackedColorArray([Color(tint,0),Color(tint,0),tint,tint]))
	for i: int in range(50):
		var x: float = fposmod(i * 173.2 + sin(_time * 0.1 + i) * 38.0 + _time * (14 if fire else 5), 1700)
		var y: float = fposmod(i * 71.5 - _time * (35 if fire else 9), 1040)
		var color := Color(1, 0.55, 0.2, 0.4) if fire else Color(0.62, 0.82, 0.87, 0.14)
		draw_circle(rect.position + Vector2(x, y), 1.0 + i % 3 * 0.5, color)
	if str(room.get("id","")) == "dry_well":
		for i: int in range(100):
			var point: Vector2 = rect.position + Vector2(fposmod(i*73.7+_time*130,1700),fposmod(i*139.9+_time*720,1040))
			draw_line(point,point+Vector2(8,24),Color(.6,.75,.85,.18),1,true)
		if fposmod(_time,11.0)<.09:
			draw_rect(rect,Color(.8,.9,1,.19))
