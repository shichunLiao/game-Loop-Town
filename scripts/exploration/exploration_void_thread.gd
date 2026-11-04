class_name ExplorationVoidThread
extends Node2D
## The cuttable knot on one red thread, low enough for a standing swing to reach.

var puppet: ExplorationVoidPuppet
var controller: Node2D
var _clock: float = 0

func _ready() -> void:
	ExplorationHitArea.hurtbox(self,16,Vector2(54,64),Vector2.ZERO)
	z_index = 9

func _physics_process(delta: float) -> void:
	if not is_instance_valid(puppet) or puppet.dead or not is_instance_valid(controller) or controller.dead:
		queue_free()
		return
	_clock += delta
	var body: Vector2 = puppet.global_position+Vector2(0,-70)
	global_position = body.lerp(controller.hand_position(),.28)
	global_position.y = clampf(global_position.y,controller.floor_y-150,controller.floor_y-70)
	queue_redraw()

func can_receive_hit() -> bool:
	return is_instance_valid(puppet) and not puppet.dead

func receive_hit(_amount: int, _origin: Vector2, _kind: String = "slash") -> void:
	if not can_receive_hit():
		return
	controller.on_thread_cut()
	puppet._die()

func _draw() -> void:
	draw_circle(Vector2.ZERO,7+sin(_clock*6)*1.5,Color("d8394a"))
	draw_arc(Vector2.ZERO,13,0,TAU,20,Color("f18fa2",.6),2,true)
