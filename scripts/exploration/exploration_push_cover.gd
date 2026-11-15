class_name ExplorationPushCover
extends CharacterBody2D
## Unfinished statue that Jerry can shove into place as cover (story 1.1 May arena).

var floor_y: float = 0
var _visual: Sprite2D
var _body: CollisionShape2D
var _shoved: bool = false
var _announced: bool = false

func _ready() -> void:
	collision_layer = 1
	collision_mask = 1
	motion_mode = MOTION_MODE_FLOATING
	_visual = Sprite2D.new()
	var texture: Texture2D = ExplorationArt.sprite("may_statue")
	if texture == null:
		texture = ExplorationArt.sprite("museum_mid", 1, "midgrounds")
	_visual.texture = texture
	if texture != null:
		var height: float = 150.0
		_visual.scale = Vector2.ONE * height / texture.get_height()
		_visual.position.y = -height * 0.5
		_visual.modulate = Color(0.85, 0.88, 0.9, 0.95)
	add_child(_visual)
	var animation := ExplorationPoseAnimation.new()
	animation.visual = _visual
	_visual.add_child(animation)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(54, 140)
	_body = CollisionShape2D.new()
	_body.shape = shape
	_body.position = Vector2(0, -70)
	add_child(_body)
	z_index = 2

func _physics_process(delta: float) -> void:
	var demo: Node = get_tree().get_first_node_in_group("exploration_demo")
	if demo == null or not is_instance_valid(demo.player):
		return
	var player: ExplorationPlayer = demo.player
	var delta_x: float = global_position.x - player.global_position.x
	var near: bool = absf(delta_x) < 70.0 and absf(player.global_position.y - floor_y) < 28.0
	velocity.x = 0
	if near and player.is_on_floor() and absf(player.velocity.x) > 40.0:
		# Shove in the direction Jerry is walking.
		velocity.x = signf(player.velocity.x) * 160.0
		_shoved = true
	velocity.y = 0
	move_and_slide()
	global_position.y = floor_y
	# Soft clamp inside the arena by parent boss if present.
	if demo.hud != null and _shoved and not _announced:
		demo.hud.toast("未完成的雕像可以推倒当作掩体")
		_announced = true
