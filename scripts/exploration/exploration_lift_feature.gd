class_name ExplorationLiftFeature
extends ExplorationInteractable
## A moving interaction target rides with its physical lift platform.

var lift: ExplorationPlatform

func prompt() -> String:
	if not session.has(lift.lift_unlock):
		return "E  检查吊笼 · 上层手柄未接通"
	return "E  操作吊笼 · "+("下降" if session.has(lift.lift_up) else "上升")

func _process(delta: float) -> void:
	_clock += delta
	position = lift.position+Vector2(lift.dimensions.x*.5,-4)
	queue_redraw()

func _draw() -> void:
	if focused:
		ExplorationVisualProfile.draw_guidance(self,_font,Vector2(0,-92))
