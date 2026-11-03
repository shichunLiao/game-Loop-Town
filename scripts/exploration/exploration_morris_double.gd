class_name ExplorationMorrisDouble
extends ExplorationEnemy
## A solid-looking false Morris, with a cold eye and a brittle wax shell.

var summoner: Node2D

func _ready() -> void:
	super._ready()
	data = data.duplicate(true)
	data["height"] = 180
	data["damage"] = 10
	data["speed"] = 80
	data["range"] = 115
	visual.texture = ExplorationArt.sprite("morris")
	var cold := ShaderMaterial.new()
	cold.shader = load("res://assets/environments/exploration/actors/morris_false.gdshader") as Shader
	visual.material = cold
	visual.scale = Vector2.ONE*180/visual.texture.get_height()
	visual.position.y = -90
	max_health = 1
	health = 1
	modulate = Color(.57,.66,.64,1)
	add_to_group("morris_owned")
	set_meta("boss_id",summoner.get_instance_id())

func _physics_process(delta: float) -> void:
	if not is_instance_valid(summoner) or summoner.dead:
		queue_free()
		return
	super._physics_process(delta)
