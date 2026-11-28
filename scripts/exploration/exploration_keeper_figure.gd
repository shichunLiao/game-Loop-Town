class_name ExplorationKeeperFigure
extends Node2D
## The keeper: a figure in a wide-brimmed hat, features lost under the brim, back turned,
## winding a great key. At the top of the tower (leaves_on set) he turns as Jerry comes near,
## and takes the hat off when Jerry reaches him: the face underneath is Jerry's own.
## Art by Codex (Demo 9): keeper_back, keeper_hidden, keeper_unmasked.

const HEIGHT := {"keeper_back":124.0,"keeper_hidden":118.0,"keeper_unmasked":118.0}
const TURN_DISTANCE: float = 380
const UNMASK_DISTANCE: float = 190

var session: ExplorationSession
var leaves_on: String = ""
var visual: Sprite2D
var _pose: String = ""
var _clock: float = 0

func _ready() -> void:
	visual = ExplorationArt.visual(self,"keeper_back",HEIGHT["keeper_back"],-1,"keeper",session.room_id,"keeper_back")
	_pose = "keeper_back"
	visual.position.x = 25
	z_index = 4

func _process(delta: float) -> void:
	_clock += delta
	if not leaves_on.is_empty() and session.has(leaves_on):
		leaves_on = ""
		vanish()
	if not leaves_on.is_empty():
		var player: Node2D = get_tree().get_first_node_in_group("exploration_player") as Node2D
		if player!=null:
			var distance: float = absf(player.global_position.x-global_position.x)
			_wear("keeper_unmasked" if distance<UNMASK_DISTANCE else "keeper_hidden" if distance<TURN_DISTANCE else "keeper_back")
			if _pose!="keeper_back":
				visual.flip_h = player.global_position.x>global_position.x
	# Winding: the back sways a little with each turn of the key.
	if _pose=="keeper_back":
		visual.rotation = sin(_clock*1.5)*.025
	else:
		visual.rotation = 0
	queue_redraw()

func _wear(pose: String) -> void:
	if pose==_pose:
		return
	_pose = pose
	visual.texture = ExplorationArt.sprite(pose)
	ExplorationVisualProfile.configure_actor(visual.material as ShaderMaterial,"keeper",pose,session.room_id)
	visual.scale = Vector2.ONE*float(HEIGHT[pose])/visual.texture.get_height()
	visual.position.y = -float(HEIGHT[pose])*.5
	# keeper_back carries the key on its right; keep his body, not the key, over his feet.
	visual.position.x = 25.0 if pose=="keeper_back" else 0.0

func warp_to(point: Vector2) -> void:
	var tween := create_tween()
	tween.tween_property(self,"modulate:a",0,.25)
	tween.tween_callback(func(): position = point)
	tween.tween_property(self,"modulate:a",1,.35)

func vanish() -> void:
	var tween := create_tween()
	tween.tween_property(self,"modulate:a",0,1.0)
	tween.tween_callback(queue_free)

func _draw() -> void:
	# A faint warm halo so the dark figure reads against the red tower.
	draw_circle(Vector2(0,-62),78,Color(.95,.72,.42,.10))
	draw_circle(Vector2(0,-62),54,Color(.95,.72,.42,.14))
