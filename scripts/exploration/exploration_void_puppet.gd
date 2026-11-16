class_name ExplorationVoidPuppet
extends ExplorationEnemy
## A seat puppet on Void's red thread. Its blows soften Jerry into cloth; once down it stays down.

var controller: Node2D
var thread: ExplorationVoidThread

func _ready() -> void:
	super._ready()
	data = data.duplicate(true)
	data["damage"] = 9
	data["speed"] = 120
	add_to_group("void_owned")

func _physics_process(delta: float) -> void:
	if not is_instance_valid(controller) or controller.dead:
		_die()
		return
	super._physics_process(delta)

func _attack(_player: ExplorationPlayer, _behavior: String) -> void:
	var hit := ExplorationHitArea.new()
	hit.source = self
	hit.target_layer = 8
	hit.damage = int(data["damage"])
	hit.kind = "puppet"
	hit.position = Vector2(facing*46,-40)
	hit.dimensions = Vector2(95,70)
	hit.direction = Vector2(facing,0)
	add_child(hit)

func _die() -> void:
	if is_instance_valid(thread):
		thread.queue_free()
	super._die()
