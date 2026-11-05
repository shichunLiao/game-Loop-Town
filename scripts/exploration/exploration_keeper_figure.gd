class_name ExplorationKeeperFigure
extends Node2D
## The keeper: Jerry's own silhouette with the hat on, back turned, winding a great key.

var session: ExplorationSession
var leaves_on: String = ""
var visual: Sprite2D
var _clock: float = 0

func _ready() -> void:
	visual = ExplorationArt.visual(self,"hero",118)
	visual.modulate = Color(.36,.27,.31)
	z_index = 4

func _process(delta: float) -> void:
	_clock += delta
	if not leaves_on.is_empty() and session.has(leaves_on):
		leaves_on = ""
		vanish()
	queue_redraw()

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
	draw_circle(Vector2(0,-62),78,Color(.95,.72,.42,.10))
	draw_circle(Vector2(0,-62),54,Color(.95,.72,.42,.14))
	var hub := Vector2(62,-62)
	var ink := Color("3c2a24")
	draw_arc(hub,26,_clock*1.5,_clock*1.5+TAU*.8,28,ink,6,true)
	draw_line(hub,hub+Vector2.from_angle(_clock*1.5)*44,ink,5,true)
	draw_line(Vector2(14,-62),hub,ink,4,true)
