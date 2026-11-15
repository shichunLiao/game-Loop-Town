class_name ExplorationMuseumGaze
extends Node2D
## Coordinates are original museum.png pixels; parenting to FarSprite preserves parallax.
var eyes: Array[Dictionary] = []
var tracked_actor: Node2D

func _ready() -> void:
	var path: String = "res://data/exploration/museum-eyes.json"
	if not FileAccess.file_exists(path):
		return
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	for entry: Dictionary in manifest.eyes:
		var pupil := Sprite2D.new()
		pupil.name = str(entry.id)
		pupil.texture = load(str(entry.path)) as Texture2D
		var origin: Vector2 = ExplorationCatalog.vec(entry.center)-ExplorationCatalog.vec(manifest.canvas)*.5
		pupil.position = origin
		add_child(pupil)
		eyes.append({"sprite":pupil,"origin":origin,"travel":ExplorationCatalog.vec(entry.travel)})

func _process(delta: float) -> void:
	var player: Node2D = get_tree().get_first_node_in_group("exploration_player") as Node2D
	tracked_actor = player
	# A striking participant draws the portraits' attention. Otherwise they watch Jerry.
	if player != null and player.attack_phase == "ready":
		for fighter: Node in get_tree().get_nodes_in_group("exploration_enemies"):
			if fighter is Node2D and not fighter.dead and fighter.state == "active":
				tracked_actor = fighter
				break
	if tracked_actor == null:
		return
	var target: Vector2 = to_local(tracked_actor.global_position+Vector2(0,-55))
	for eye: Dictionary in eyes:
		var direction: Vector2 = target-eye.origin
		var travel: Vector2 = eye.travel
		var offset := Vector2(clampf(direction.x/200.0,-1,1)*travel.x,clampf(direction.y/180.0,-1,1)*travel.y)
		var pupil: Sprite2D = eye.sprite
		pupil.position = pupil.position.lerp(eye.origin+offset,1-exp(-delta*9))
