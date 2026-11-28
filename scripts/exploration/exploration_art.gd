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

static func still_sprite(id: String, cell: int = -1, folder: String = "actors") -> Texture2D:
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

static func visual(host: Node2D, id: String, height: float, cell: int = -1, role: String = "npc") -> Sprite2D:
	var visual := Sprite2D.new()
	visual.texture = sprite(id,cell)
	if visual.texture != null:
		visual.scale = Vector2.ONE * height / visual.texture.get_height()
	visual.position.y = -height*.5
	var material := ShaderMaterial.new()
	material.shader = load("res://assets/environments/exploration/actors/rim_light.gdshader") as Shader
	ExplorationVisualProfile.configure_actor(material, role)
	visual.material = material
	host.add_child(visual)
	var grounding := ExplorationActorGrounding.new()
	grounding.name = "VisualGrounding"
	grounding.visual = visual
	grounding.role = role
	host.add_child(grounding)
	var animation := ExplorationPoseAnimation.new()
	animation.name = "CGAnimation"
	animation.visual = visual
	visual.add_child(animation)
	return visual

## Where the feet stand across a sprite, 0..1 from the left edge: the mean x of opaque pixels
## in the bottom rows. Wide poses (a whip, a brush, a lunge) are not centred on the body.
static func foot_center(id: String) -> float:
	if _feet.has(id):
		return _feet[id]
	var result: float = .5
	var texture: Texture2D = still_sprite(id)
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


static var _animation_manifest: Dictionary = {}
static var _animation_frames: Dictionary = {}

static func animation_manifest() -> Dictionary:
	if _animation_manifest.is_empty() and FileAccess.file_exists("res://data/exploration/animations.json"):
		_animation_manifest = JSON.parse_string(FileAccess.get_file_as_string("res://data/exploration/animations.json"))
	return _animation_manifest

static func default_clip(id: String, cell: int = -1) -> String:
	return str(animation_manifest().get("sources",{}).get(id+"/"+str(cell),""))

static func has_clip(id: String) -> bool:
	return animation_manifest().get("clips",{}).has(id)

static func clip_info(id: String) -> Dictionary:
	return animation_manifest().get("clips",{}).get(id,{})

static func animation_source(texture: Texture2D) -> Dictionary:
	if texture.has_meta("animation_source"):
		return texture.get_meta("animation_source")
	return {}

static func source_id(texture: Texture2D) -> String:
	return str(animation_source(texture).get("id",texture.resource_path.get_file().get_basename()))

static func animation_index(id: String, age: float, duration: float = -1.0) -> int:
	var info: Dictionary = clip_info(id)
	var count: int = int(info.get("frames",1))
	var length: float = duration if duration>0 else float(info.get("duration",.8))
	var index: int = int(maxf(age,0)/length*count)
	return index%count if bool(info.get("loop",true)) else mini(index,count-1)

static func animation_frame(id: String, index: int) -> Texture2D:
	var key: String = id+"/"+str(index)
	if _animation_frames.has(key):
		return _animation_frames[key]
	var info: Dictionary = clip_info(id)
	if info.is_empty():
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = load(str(info.path)) as Texture2D
	var size := Vector2(float(info.width),float(info.height))
	var cell: int = clampi(index,0,int(info.frames)-1)+int(info.get("offset",0))
	atlas.region = Rect2(Vector2(cell%int(info.columns),cell/int(info.columns))*size,size)
	atlas.filter_clip = true
	atlas.set_meta("animation_source",{"id":str(info.source),"cell":int(info.get("cell",-1))})
	atlas.set_meta("animation_clip",id)
	_animation_frames[key] = atlas
	return atlas

static func sprite(id: String, cell: int = -1, folder: String = "actors") -> Texture2D:
	if folder == "actors":
		var clip: String = default_clip(id,cell)
		if has_clip(clip):
			return animation_frame(clip,0)
	return still_sprite(id,cell,folder)

static func moving_sprite(id: String, age: float) -> Texture2D:
	var clip: String = default_clip(id)
	if has_clip(clip):
		return animation_frame(clip,animation_index(clip,age))
	return sprite(id)
