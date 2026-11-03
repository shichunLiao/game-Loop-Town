class_name FurnaceVisual
extends Node2D

## 熔蜡炉的程序化视觉（提示词【十三】：Boss 房后方有巨大熔蜡炉）。
##
## 不依赖贴图：一个大圆 + 内部更亮的芯 + 随世界状态变化的脉动。
## PHASE 3 过热时颜色会明显偏向赤红，玩家能从背景看出“场地要变了”。

@export var outer_radius: float = 132.0
@export var inner_radius: float = 74.0
@export var wax_color: Color = Color(0.85, 0.62, 0.22)
@export var heat: float = 0.0
@export var pulse_speed: float = 1.4

var _time: float = 0.0


func _ready() -> void:
	z_index = -5


func _process(delta: float) -> void:
	_time += delta * pulse_speed
	# 过热时炉体更亮、更红。
	heat = clampf(heat, 0.0, 1.0)
	queue_redraw()


## 由 Morris 在进入 PHASE 3 时调用。
func set_overheated(value: bool) -> void:
	heat = 1.0 if value else 0.0


func _draw() -> void:
	var pulse := 0.9 + 0.1 * sin(_time)
	var hot := wax_color.lerp(Color(1.0, 0.35, 0.18), heat)

	# 炉体：外圈暗、内芯亮。
	draw_circle(Vector2.ZERO, outer_radius, Color(0.18, 0.14, 0.12, 0.95))
	draw_circle(Vector2.ZERO, outer_radius * 0.92, Color(0.30, 0.20, 0.14, 0.9))
	draw_circle(Vector2.ZERO, inner_radius * pulse, Color(hot, 0.85))
	draw_circle(Vector2.ZERO, inner_radius * 0.55 * pulse, Color(1.0, 0.92, 0.72, 0.9))

	# 顶部开口：一条向上飘的暖色光带，暗示热蜡是从这里喷出来的。
	var glow := Color(hot, 0.25 + 0.35 * heat)
	for i in 3:
		var offset := float(i) * 16.0
		draw_rect(
			Rect2(Vector2(-26.0, -outer_radius - offset - 40.0), Vector2(52.0, 44.0)),
			glow,
			true
		)
