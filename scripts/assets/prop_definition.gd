class_name PropDefinition
extends Resource

## 一个道具 / 场景物的资源定义。
##
## 编辑器里点开就能看到「这张图是什么、多大、干什么用的」，
## 而不是只面对一个 32x32 的 PNG 猜它的用途。

@export var id: StringName = &""
@export var display_name: String = ""
@export var texture_path: String = ""
## 图标边长（像素）。
@export var icon_size: int = 32
## 用途说明 —— 写清楚它在玩法里的角色，便于美术判断该画多细。
@export_multiline var usage: String = ""
@export var icon: Texture2D = null
