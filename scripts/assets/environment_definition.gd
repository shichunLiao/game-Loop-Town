class_name EnvironmentDefinition
extends Resource

## 一张地图的背景层定义（视差）。
##
## 原先每张地图的背景层硬编码在 data/levels/*.json 里，美术看不到
## 「这张图用哪几张背景、视差系数多少」。现在独立成 data/assets/environments/<map>.tres，
## 编辑器里点开就能看到每层的贴图、视差系数、垂直偏移、透明度。

@export var map_id: StringName = &""
## 层列表，元素类型是 EnvironmentLayer。
@export var layers: Array = []


## 有效的层（已过滤掉加载失败的项）。
func valid_layers() -> Array[EnvironmentLayer]:
	var out: Array[EnvironmentLayer] = []
	for layer: Variant in layers:
		var typed := layer as EnvironmentLayer
		if typed != null:
			out.append(typed)
	return out


func layer_count() -> int:
	return valid_layers().size()
