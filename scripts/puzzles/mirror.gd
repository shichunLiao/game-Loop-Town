class_name Mirror
extends InteractableBase

## 可旋转的镜子（提示词【十三】：地下室 7 面镜子）。
##
## 每次交互旋转 45°，共 8 个档位。镜面朝向决定光线能否被反射到下一面镜子。

signal rotated(mirror: Mirror, angle_index: int)

## 当前的档位（0..7），每档 45°。
@export var angle_index: int = 0
## 解谜所需的正确档位。由 MirrorPuzzle 在生成镜子时写入。
@export var required_angle_index: int = 0
## 是否允许玩家旋转（解谜完成后冻结）。
@export var rotatable: bool = true

## 光线命中这面镜子时的折返方向（世界坐标，单位向量）。
## 由 MirrorPuzzle 在布置光路时写入。
@export var reflect_direction: Vector2 = Vector2.RIGHT

@onready var _mirror_sprite: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D


func _interactable_ready() -> void:
	interact_prompt = "转动镜子"
	sfx = "mirror_turn"
	if _mirror_sprite != null and _mirror_sprite.texture == null:
		var path := "res://assets/props/mirror.png"
		if ResourceLoader.exists(path):
			_mirror_sprite.texture = load(path) as Texture2D
	_apply_angle()


func _on_interacted(_player: Node) -> void:
	if not rotatable:
		return
	rotate_by(1)


## 旋转一步（默认顺时针 45°）。
func rotate_by(steps: int) -> void:
	angle_index = posmod(angle_index + steps, 8)
	_apply_angle()
	rotated.emit(self, angle_index)


func is_correct() -> bool:
	return angle_index == required_angle_index


func _apply_angle() -> void:
	rotation = deg_to_rad(45.0 * float(angle_index))
	# 正确档位给一点视觉反馈（轻微提亮），让玩家能察觉“这一面对了”。
	if _mirror_sprite != null:
		_mirror_sprite.modulate = Color(1.0, 0.98, 0.9) if is_correct() else Color(0.82, 0.86, 0.92)
