class_name ExplorationActorGrounding
extends Node2D
## Soft contact projection and atlas bounds; visual only, never touches actor physics.

var visual: Sprite2D
var role: String = "npc"
var _ground := Vector2.ZERO
var _strength: float = 0.0
var _texture: Texture2D

func _ready() -> void:
	z_index = -1
	_update_region()

func _process(_delta: float) -> void:
	_update_region()

func _update_region() -> void:
	if visual == null or visual.texture == _texture:
		return
	_texture = visual.texture
	var bounds := Vector4(0, 0, 1, 1)
	if _texture is AtlasTexture:
		var atlas := _texture as AtlasTexture
		var size := atlas.atlas.get_size()
		bounds = Vector4(atlas.region.position.x/size.x, atlas.region.position.y/size.y, atlas.region.end.x/size.x, atlas.region.end.y/size.y)
	(visual.material as ShaderMaterial).set_shader_parameter("uv_bounds", bounds)

func _physics_process(_delta: float) -> void:
	if not is_inside_tree():
		return
	var query := PhysicsRayQueryParameters2D.create(global_position-Vector2(0,4), global_position+Vector2(0,220), 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	_strength = 0.0
	if not hit.is_empty():
		var point: Vector2 = hit.position
		var height: float = maxf(0.0, point.y-global_position.y)
		_strength = clampf(1.0-height/220.0, 0.0, 1.0)
		_ground = to_local(point)+Vector2(0,-1)
	queue_redraw()

func _draw() -> void:
	if _strength <= 0.0 or visual == null or not visual.visible:
		return
	var radius := Vector2(25, 6) if role in ["player", "boss", "keeper"] else Vector2(21, 5)
	for i: int in range(3):
		var spread: float = 1.0-i*0.18
		draw_set_transform(_ground, 0.0, radius*spread)
		draw_circle(Vector2.ZERO, 1.0, Color(0.025, 0.018, 0.017, _strength*(0.12+i*0.035)), true, -1, true)
	draw_set_transform(Vector2.ZERO)
