class_name ExplorationMorrisDouble
extends ExplorationEnemy
## A statue double of May Morley: his shape, all in white plaster, stiff and slow (art: may_statue).

var summoner: Node2D

func _ready() -> void:
	super._ready()
	data = data.duplicate(true)
	data["height"] = 180
	data["damage"] = 10
	data["speed"] = 80
	data["range"] = 115
	visual.texture = ExplorationArt.sprite("may_statue")
	visual.scale = Vector2.ONE*180/visual.texture.get_height()
	visual.position.y = -90
	max_health = 1
	health = 1
	modulate = Color(.92,.94,.95,1)
	add_to_group("morris_owned")
	set_meta("boss_id",summoner.get_instance_id())

func _physics_process(delta: float) -> void:
	if not is_instance_valid(summoner) or summoner.dead:
		queue_free()
		return
	super._physics_process(delta)

func _attack(player: ExplorationPlayer, behavior: String) -> void:
	if behavior == "ranged":
		shoot((player.global_position+Vector2(0,-35)-global_position).normalized()*340)
		return
	var hit := ExplorationHitArea.new()
	hit.source = self
	hit.target_layer = 8
	hit.damage = int(data["damage"])
	hit.kind = "statue"
	hit.position = Vector2(facing*46,-40)
	hit.dimensions = Vector2(95,70)
	hit.direction = Vector2(facing,0)
	add_child(hit)
