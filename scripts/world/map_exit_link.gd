class_name MapExitLink
extends Resource

## 一条地图出口：走到 [member exit_id] 的 Exit 区域时，去哪张地图的哪个出生点。
##
## 为什么是独立文件而不是 MapData 的内部类：
## Godot 加载 .tres 时，只有**全局 class_name** 的资源才能被识别成具体类型。
## 内部类（MapData.ExitLink）在读回来时只是裸 Resource，
## `link is MapData.ExitLink` 会返回 false，出口就会全部失效。

@export var exit_id: StringName = &""
@export var target_map_id: StringName = &""
@export var target_spawn_id: StringName = &"default"
## 需要满足的条件（空 = 无条件）。例如 &"flag:theater_open"。
@export var condition: StringName = &""
## 条件不满足时给玩家看的一句话。
@export var locked_message: String = ""
