class_name ExplorationPlatform
extends AnimatableBody2D
## Textured gameplay geometry; alpha-trimmed art and collision share the same top edge.

@export var dimensions: Vector2 = Vector2(256, 96)
@export_enum("stone", "wood", "brass") var theme: String = "stone"
@export var one_way: bool = false
@export var travel: Vector2 = Vector2.ZERO
@export var period: float = 4.5
@export_range(0,3) var variant: int = 0
var _origin: Vector2
var _time: float = 0.0
var texture: Texture2D
var session: ExplorationSession
var geometry: String = ""
var masonry: int = 0
var manual_lift: bool = false
var lift_unlock: String = ""
var lift_up: String = ""
var lift_speed: float = 430.0
var _lift_progress: float = 0.0
static var _textures: Dictionary = {}

func _ready() -> void:
	_origin = position
	collision_layer = 1
	collision_mask = 0
	if manual_lift and session != null:
		_lift_progress = 1.0 if session.has(lift_up) else 0.0
		# Restoring a dock is an initial placement, not a multi-storey physics move.
		sync_to_physics = false
		position = _origin+travel*_lift_progress
	sync_to_physics = true
	var rect := RectangleShape2D.new()
	rect.size = Vector2(dimensions.x, 20 if one_way else dimensions.y)
	var shape := CollisionShape2D.new()
	shape.position = rect.size * 0.5
	shape.shape = rect
	shape.one_way_collision = one_way
	shape.one_way_collision_margin = 12.0
	add_child(shape)
	texture = terrain_texture(theme)
	queue_redraw()

static func terrain_texture(id: String) -> Texture2D:
	if _textures.has(id):
		return _textures[id]
	var path: String = "res://assets/environments/exploration/terrain/" + id + ".png"
	if not ResourceLoader.exists(path):
		return null
	var original: Texture2D = load(path) as Texture2D
	# Generated alpha can contain near-transparent fringe. Explicit atlas metadata
	# aligns the opaque walkable edge to collision y=0 without altering the PNG.
	var regions: Dictionary = {"stone":Rect2i(64,242,2040,244), "wood":Rect2i(30,220,2100,281), "brass":Rect2i(45,229,2080,279)}
	var region: Rect2i = regions.get(id, original.get_image().get_used_rect())
	var atlas := AtlasTexture.new()
	atlas.atlas = original
	atlas.region = Rect2(region)
	_textures[id] = atlas
	return atlas

func _physics_process(delta: float) -> void:
	if manual_lift:
		if session != null and session.has(lift_unlock):
			var target: float = 1.0 if session.has(lift_up) else 0.0
			_lift_progress = move_toward(_lift_progress,target,delta*lift_speed/maxf(1,travel.length()))
			position = _origin+travel*_lift_progress
		return
	if travel != Vector2.ZERO:
		_time += delta*(.3 if session != null and session.slow_time>0 else 1.0)
		position = _origin + travel * (0.5 - cos(_time * TAU / period) * 0.5)

func _draw() -> void:
	if geometry == "wall" or geometry == "ground":
		_draw_masonry(Rect2(Vector2.ZERO,dimensions))
		if geometry == "wall":
			draw_line(Vector2(dimensions.x-3,0),Vector2(dimensions.x-3,dimensions.y),Color("121d23"),5)
			return
	var shown_height: float = minf(dimensions.y, 62.0 if not geometry.is_empty() else 110.0)
	if texture != null:
		var x: float = 0.0
		var segment: int = 0
		while x < dimensions.x:
			var tile: Texture2D = ExplorationArt.sprite(theme+"_variants",(variant+segment)%4,"terrain")
			if tile == null:
				tile = texture
			var segment_width: float = tile.get_width()/float(tile.get_height())*shown_height
			var width: float = minf(segment_width, dimensions.x - x)
			draw_texture_rect_region(tile,Rect2(x,0,width,shown_height),Rect2(0,0,tile.get_width()*width/segment_width,tile.get_height()))
			x += width
			segment += 1
	else:
		draw_rect(Rect2(0, 0, dimensions.x, shown_height), Color("343b41"))
	var rim := Color("b4c4be")
	if theme == "brass":
		rim = Color("d8aa64")
	draw_line(Vector2(0, 1), Vector2(dimensions.x, 1), Color(rim, 0.7), 1.5, true)
	if manual_lift:
		_draw_cabin()

func _draw_masonry(area: Rect2) -> void:
	var tile: Texture2D = ExplorationArt.sprite("masonry_tiles_v7",masonry,"masonry")
	if tile == null:
		draw_rect(area,Color("283339"))
		return
	var span := Vector2(288,240)
	for y: int in range(0,int(area.size.y),int(span.y)):
		for x: int in range(0,int(area.size.x),int(span.x)):
			var size := Vector2(minf(span.x,area.size.x-x),minf(span.y,area.size.y-y))
			draw_texture_rect_region(tile,Rect2(area.position+Vector2(x,y),size),Rect2(Vector2.ZERO,tile.get_size()*size/span),Color(.61,.65,.64))

func operate_lift() -> void:
	var demo: Node = get_tree().get_first_node_in_group("exploration_demo")
	if not session.has(lift_unlock):
		demo.hud.toast("吊笼尚未接通 · 沿石廊攀上顶层，操作上层手柄即可开启返程捷径。")
		return
	session.switches[lift_up] = not session.has(lift_up)
	session.changed.emit()
	session.save()
	demo.hud.toast("吊笼正在上行" if session.has(lift_up) else "吊笼正在下行")

func _draw_cabin() -> void:
	# The player stands inside the open-front cage; bars remain behind the actor.
	var iron := Color("28353a")
	var bronze := Color("9a8050")
	for x: float in [8,dimensions.x-8]:
		draw_line(Vector2(x,-148),Vector2(x,0),iron,11,true)
		draw_line(Vector2(x-2,-145),Vector2(x-2,-4),bronze,2,true)
	draw_rect(Rect2(0,-158,dimensions.x,17),iron)
	draw_line(Vector2(0,-158),Vector2(dimensions.x,-158),bronze,3,true)
	for x: int in range(23,int(dimensions.x)-12,25):
		draw_line(Vector2(x,-55),Vector2(x,0),Color("3a4240"),3,true)
	draw_line(Vector2(10,-55),Vector2(dimensions.x-10,-55),bronze,3,true)
	draw_circle(Vector2(dimensions.x*.5,-164),12,iron)
	draw_arc(Vector2(dimensions.x*.5,-164),8,0,TAU,20,bronze,2,true)
