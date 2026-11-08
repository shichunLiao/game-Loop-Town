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

## Ling crouched in the corner, head down (Codex art, Demo 9); torn cloth lies on the ground around her.
const HEIGHT: float = 78
func _draw() -> void:
	for scrap: Rect2 in [Rect2(-120,-5,26,7),Rect2(-76,-4,18,6),Rect2(-168,-6,30,8),Rect2(52,-4,20,6)]:
		draw_rect(scrap,Color("37506e") if int(scrap.position.x)%4==0 else Color("c4bba6"))
	var girl: Texture2D = ExplorationArt.sprite("ling_crouch")
	if girl!=null:
		var size := Vector2(HEIGHT*girl.get_width()/girl.get_height(),HEIGHT)
		draw_texture_rect(girl,Rect2(Vector2(-size.x*.5,-size.y),size),false)
