class_name EnvironmentLayer
extends Resource

## 一层背景（视差层）。
##
## 独立成全局类的原因同 AnimationEntry：内部类从 .tres 读回来无法判定类型。

@export var name: StringName = &""
@export var texture_path: String = ""
## 视差系数：0 = 完全跟随相机（最远），1 = 与玩法平面同速（最近）。
@export_range(0.0, 1.5) var scroll_scale: float = 0.3
## 垂直偏移（相对地表）。
@export var offset_y: float = -200.0
## 整体透明度，用于把远景压淡。
@export_range(0.0, 1.0) var modulate_a: float = 0.7
@export var texture: Texture2D = null
