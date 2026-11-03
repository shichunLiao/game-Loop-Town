class_name MapData
extends Resource

## 一张地图的静态描述（提示词【二十五】）。
##
## 地图本身是独立 Scene，本资源只描述“它叫什么、多大、连到哪、属于哪个音区”。
## 这样地图切换逻辑永远不需要知道任何具体关卡，新增地图只加一份 .tres。

@export var id: StringName = &""
@export var display_name: String = ""
@export_file("*.tscn") var scene_path: String = ""
## 设计尺寸，用于小地图与校验（提示词【三十八】）。
@export var map_size: Vector2i = Vector2i(3000, 1000)
## 所属音频区域，AudioManager 用它切换环境声与音乐。
@export var audio_area: StringName = &"Town"
## 世界状态阶段对该地图外观的影响开关（提示词【十】）。
@export var reacts_to_world_state: bool = true
## 出口列表。元素类型是 MapExitLink。
##
## 注意：这里刻意用**无类型** Array。
## 若声明为 Array[MapExitLink]，Godot 在加载 .tres 时会做容器类型校验，
## 而资源文本里的 SubResource 会被实例化成裸 Resource，于是报
## "Attempted to assign an object into a TypedArray" 并让整份地图数据加载失败。
@export var exits: Array = []
## 该地图的默认出生点（从标题界面直接进入调试时用）。
@export var default_spawn_id: StringName = &"default"


## 按 exit_id 查找出口。同时做类型与属性双重保险，避免资源里写了脏数据。
func find_exit(exit_id: StringName) -> MapExitLink:
	for link: Variant in exits:
		var typed := _as_exit_link(link)
		if typed != null and typed.exit_id == exit_id:
			return typed
	return null


## 返回所有合法出口，供 MapRoot 生成出口节点使用。
func get_exit_links() -> Array[MapExitLink]:
	var out: Array[MapExitLink] = []
	for link: Variant in exits:
		var typed := _as_exit_link(link)
		if typed != null:
			out.append(typed)
	return out


## 把 .tres 里读回来的裸 Resource 归一化成 MapExitLink。
##
## 为什么需要它：Godot 从 .tres 读子资源时不会自动套上内部类，
## 极端情况下（例如资源被手工编辑过）也可能不是 MapExitLink 实例。
## 这里做一次属性搬运，保证后续代码永远拿到有类型的对象。
static func _as_exit_link(link: Variant) -> MapExitLink:
	if link == null:
		return null
	var typed := link as MapExitLink
	if typed != null:
		return typed
	var resource := link as Resource
	if resource == null:
		return null

	var converted := MapExitLink.new()
	for property: Dictionary in converted.get_property_list():
		var property_name: String = str(property.get("name", ""))
		if property_name.is_empty() or not (property_name in resource):
			continue
		converted.set(property_name, resource.get(property_name))
	# 兼容旧资源里把出口 id 写成 id 的情况。
	if converted.exit_id == &"" and resource.get("id") != null:
		converted.exit_id = StringName(str(resource.get("id")))
	return converted
