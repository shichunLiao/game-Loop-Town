class_name AnimationEntry
extends Resource

## 一个动画条目：一个动作对应一张横向平铺的图集。
##
## 独立成全局类（而不是 ActorDefinition 的内部类）的原因：
## Godot 从 .tres 读回来的是裸 Resource，内部类无法用 `as` 判定类型，
## 会静默失效。这个坑在 MapData.ExitLink 上已经踩过一次。

@export var name: StringName = &""
## 图集路径。横向平铺，帧数由 [member frames] 决定。
@export var path: String = ""
@export var frames: int = 1
@export var texture: Texture2D = null
## 播放速度（帧/秒）。
@export var speed: float = 8.0
@export var loop: bool = true


## 单帧宽度（由图集宽度与帧数推导）。
func frame_width() -> int:
	if texture == null or frames <= 0:
		return 0
	return texture.get_width() / frames


## 单帧高度（等于图集高度，因为图集是横向一维平铺）。
func frame_height() -> int:
	if texture == null:
		return 0
	return texture.get_height()
