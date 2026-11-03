class_name ActorDefinition
extends Resource

## 一个可动角色的完整资源定义（玩家 / 敌人 / NPC / Boss 共用）。
##
## 为什么需要它：原先「这个角色长什么样、多大、多少帧、有哪些状态」散落在
## ActorFactory 的代码常量里，美术在编辑器里点开 assets/ 只能看到一堆 PNG，
## 不知道哪张图属于谁、有多少帧、怎么用。
##
## 有了这份定义：
##   - 编辑器里点开 data/assets/actors/morris.tres 就能看到他的全部动画与帧数
##   - ActorFactory 从它读取装配信息，不再有代码里的硬编码表
##   - 换美术素材只需覆盖同名 PNG，帧数变了改这里一个数字

enum Kind {
	PLAYER,
	ENEMY,
	NPC,
	BOSS,
}

@export var id: StringName = &""
@export var kind: Kind = Kind.ENEMY
@export var display_name: String = ""
## 素材所在目录（相对 res://），便于美术定位。
@export var source_dir: String = ""
## 运行时脚本路径。
@export_file("*.gd") var script_path: String = ""
## 单帧尺寸（正方形，例如玩家 64、莫里斯 128）。
@export var frame_size: int = 64
## 碰撞胶囊的尺寸 (直径, 总高)。
@export var body_size: Vector2 = Vector2(26.0, 52.0)
## 状态脚本目录。
@export var states_dir: String = ""
## 该角色使用的状态名（对应目录下的同名 .gd）。
@export var state_names: PackedStringArray = PackedStringArray()
## 美术与设计说明（编辑器里直接能看到）。
@export_multiline var note: String = ""
## 动画条目列表，元素类型是 AnimationEntry。
@export var animations: Array = []


## 按名字取动画条目。
func get_animation(animation_name: StringName) -> AnimationEntry:
	for entry: Variant in animations:
		var typed := entry as AnimationEntry
		if typed != null and typed.name == animation_name:
			return typed
	return null


func has_animation(animation_name: StringName) -> bool:
	return get_animation(animation_name) != null


## 动画名列表。
func animation_names() -> Array[StringName]:
	var out: Array[StringName] = []
	for entry: Variant in animations:
		var typed := entry as AnimationEntry
		if typed != null:
			out.append(typed.name)
	return out


## 状态脚本的完整路径（供工厂装配状态机）。
func state_script_paths() -> Dictionary:
	var out: Dictionary = {}
	for state_name in state_names:
		out[state_name] = "%s/%s.gd" % [states_dir, state_name]
	return out


## 动画总帧数，用于体检（例如「每个角色至少 20 帧」）。
func total_frames() -> int:
	var total := 0
	for entry: Variant in animations:
		var typed := entry as AnimationEntry
		if typed != null:
			total += typed.frames
	return total
