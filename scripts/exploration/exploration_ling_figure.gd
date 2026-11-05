class_name ExplorationLingFigure
extends Node2D
## The real Ling once the mud has gone: small and clean, crouched in the corner, head low.

var session: ExplorationSession
var _shown: bool = false

func _ready() -> void:
	z_index = 4
	modulate.a = 0

func _process(_delta: float) -> void:
	if not _shown and session.has("boss_ling"):
		_shown = true
		var tween := create_tween()
		tween.tween_interval(1.6)
		tween.tween_property(self,"modulate:a",1.0,1.6)

## Placeholder art until her sprite exists; the torn cloth lies on the ground around her.
func _draw() -> void:
	for scrap: Rect2 in [Rect2(-120,-5,26,7),Rect2(-76,-4,18,6),Rect2(-168,-6,30,8),Rect2(52,-4,20,6)]:
		draw_rect(scrap,Color("37506e") if int(scrap.position.x)%4==0 else Color("c4bba6"))
	# Knees drawn up under the blue skirt, arms around them, head down on them.
	draw_colored_polygon(PackedVector2Array([Vector2(-32,0),Vector2(30,0),Vector2(26,-22),Vector2(6,-32),Vector2(-24,-26)]),Color("3f6a9a"))
	draw_colored_polygon(PackedVector2Array([Vector2(-24,-24),Vector2(8,-28),Vector2(6,-54),Vector2(-20,-56)]),Color("eee9dc"))
	draw_line(Vector2(-6,-48),Vector2(18,-22),Color("e4dfd2"),8,true)
	draw_circle(Vector2(20,-20),5,Color("e3d2bd"))
	draw_circle(Vector2(6,-58),15,Color("e3d2bd"))
	draw_circle(Vector2(1,-62),15,Color("2a1c14"))
	for tail: Array in [[Vector2(-12,-64),Vector2(-27,-30)],[Vector2(13,-68),Vector2(25,-36)]]:
		draw_line(tail[0],tail[1],Color("2a1c14"),7,true)
