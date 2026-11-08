class_name ExplorationArt
extends RefCounted
## Atlas regions are metadata; original generated PNG pixels remain untouched.

static var _textures: Dictionary = {}
static var _actors: Dictionary = {}
static var _regions: Dictionary = {}
static var _anchors: Dictionary = {}
static var _feet: Dictionary = {}

static func foot_gap(id: String,cell: int = -1) -> float:
	if _anchors.is_empty() and FileAccess.file_exists("res://data/exploration/art-anchors.json"):
		_anchors = JSON.parse_string(FileAccess.get_file_as_string("res://data/exploration/art-anchors.json"))
	return float(_anchors.get(id+"/"+str(cell),{}).get("bottom_gap",0))

static func actors() -> Dictionary:
	if _actors.is_empty():
		_actors = JSON.parse_string(FileAccess.get_file_as_string("res://data/exploration/actors.json"))
	return _actors

static func sprite(id: String, cell: int = -1, folder: String = "actors") -> Texture2D:
	var key: String = folder+"/"+id+"/"+str(cell)
	if _textures.has(key):
		return _textures[key]
	var path: String = "res://assets/environments/exploration/"+folder+"/"+id+".png"
	if not ResourceLoader.exists(path):
		return null
	var texture: Texture2D = load(path) as Texture2D
	if _regions.is_empty() and FileAccess.file_exists("res://data/exploration/art-regions.json"):
		_regions = JSON.parse_string(FileAccess.get_file_as_string("res://data/exploration/art-regions.json"))
	var lookup: String = id+"/"+str(cell)
	if _regions.has(lookup):
		var region: Array = _regions[lookup]
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(float(region[0]),float(region[1]),float(region[2]),float(region[3]))
		atlas.filter_clip = true
		texture = atlas
	elif cell >= 0:
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2((cell%2)*texture.get_width()*.5,(cell/2)*texture.get_height()*.5,texture.get_width()*.5,texture.get_height()*.5)
		texture = atlas
	_textures[key] = texture
	return texture

static func visual(host: Node2D, id: String, height: float, cell: int = -1) -> Sprite2D:
	var visual := Sprite2D.new()
	visual.texture = sprite(id,cell)
	if visual.texture != null:
		visual.scale = Vector2.ONE * height / visual.texture.get_height()
	visual.position.y = -height*.5
	var material := ShaderMaterial.new()
	material.shader = load("res://assets/environments/exploration/actors/rim_light.gdshader") as Shader
	visual.material = material
	host.add_child(visual)
	return visual

## Where the feet stand across a sprite, 0..1 from the left edge: the mean x of opaque pixels
## in the bottom rows. Wide poses (a whip, a brush, a lunge) are not centred on the body.
static func foot_center(id: String) -> float:
	if _feet.has(id):
		return _feet[id]
	var result: float = .5
	var texture: Texture2D = sprite(id)
	if texture!=null and not texture is AtlasTexture:
		var image: Image = texture.get_image()
		if image!=null:
			if image.is_compressed():
				image.decompress()
			var total: float = 0
			var count: int = 0
			var w: int = image.get_width()
			var h: int = image.get_height()
			for y: int in range(int(h*.93),h,3):
				for x: int in range(0,w,4):
					if image.get_pixel(x,y).a>.5:
						total += x
						count += 1
			if count>0:
				result = total/count/w
	_feet[id] = result
	return result

## Local x for a sprite drawn left-facing (flipped when facing right) so its feet sit on the origin.
static func foot_shift(id: String, texture: Texture2D, scale_x: float, flipped: bool) -> float:
	var shift: float = (.5-foot_center(id))*texture.get_width()*scale_x
	return -shift if flipped else shift

## Draw generated horizontal prop pixels along a segment; collision stays with callers.
static func strand(host: Node2D, id: String, start: Vector2, end: Vector2, width: float, tint: Color = Color.WHITE) -> void:
	var texture: Texture2D = sprite(id,0 if id=="red_thread" else -1,"props")
	if texture==null or start.distance_to(end)<.01:
		return
	host.draw_set_transform(start,(end-start).angle())
	host.draw_texture_rect(texture,Rect2(0,-width*.5,start.distance_to(end),width),false,tint)
	host.draw_set_transform(Vector2.ZERO)

static func thread_ring(host: Node2D, center: Vector2, radius: float, width: float, tint: Color = Color.WHITE) -> void:
	for i: int in range(48):
		strand(host,"red_thread",center+Vector2.from_angle(TAU*i/48)*radius,center+Vector2.from_angle(TAU*(i+1)/48)*radius,width,tint)
