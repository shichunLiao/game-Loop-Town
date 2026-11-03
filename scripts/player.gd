extends CharacterBody2D

## 左右移动速度（像素/秒）
@export var speed: float = 200.0

func _physics_process(_delta: float) -> void:
	# ui_left / ui_right 默认绑定在方向键和 A/D 上
	var direction := Input.get_axis("ui_left", "ui_right")
	velocity.x = direction * speed
	move_and_slide()
