extends Node

## 地图注册表（autoload）。
##
## 把「地图 id → MapData」的映射集中在一处，地图切换逻辑因此完全不需要
## 认识任何具体关卡（提示词【二十七】第 3、4 条：禁止巨型单文件与硬编码分支）。
##
## 新增地图的步骤：往 data/maps/ 放一份 .tres，并在下面的 MAP_RESOURCES 里加一行。

const MAP_RESOURCES: Dictionary = {
	&"town_entrance": "res://data/maps/town_entrance.tres",
	&"town_hub": "res://data/maps/town_hub.tres",
	&"wax_lane": "res://data/maps/wax_lane.tres",
	&"wax_museum": "res://data/maps/wax_museum.tres",
	&"wax_basement": "res://data/maps/wax_basement.tres",
	&"old_theater": "res://data/maps/old_theater.tres",
	&"back_stage": "res://data/maps/back_stage.tres",
	&"dry_well": "res://data/maps/dry_well.tres",
	&"well_interior": "res://data/maps/well_interior.tres",
	&"clock_tower": "res://data/maps/clock_tower.tres",
	&"final_fire_town": "res://data/maps/final_fire_town.tres",
	&"shadow_boss": "res://data/maps/shadow_boss.tres",
	&"train_station": "res://data/maps/train_station.tres",
}

## 地图展示名。用于 HUD 显示区域名（避免每次都读资源）。
const MAP_NAMES: Dictionary = {
	&"town_entrance": "回环镇 · 镇口",
	&"town_hub": "回环镇 · 中央广场",
	&"wax_lane": "蜡像巷",
	&"wax_museum": "蜡像馆",
	&"wax_basement": "蜡像馆 · 地下室",
	&"old_theater": "旧剧院",
	&"back_stage": "剧院 · 后台",
	&"dry_well": "枯井区域",
	&"well_interior": "井底",
	&"clock_tower": "大钟楼",
	&"final_fire_town": "回环镇 · 火海",
	&"shadow_boss": "钟楼顶",
	&"train_station": "火车站",
}

var _cache: Dictionary = {}


func get_map(map_id: StringName) -> MapData:
	if _cache.has(map_id):
		return _cache[map_id]

	var path: String = String(MAP_RESOURCES.get(map_id, ""))
	if path.is_empty():
		push_error("[MapRegistry] 未注册的地图 id: %s" % map_id)
		return null

	var data := load(path) as MapData
	if data == null:
		push_error("[MapRegistry] 地图资源加载失败: %s" % path)
		return null

	# 资源里没写 id 时用注册键补齐，避免两份真相。
	if data.id == &"":
		data.id = map_id
	data.scene_path = _scene_path_for(map_id)

	_cache[map_id] = data
	return data


func get_map_display_name(map_id: StringName) -> String:
	var data := get_map(map_id)
	if data != null and not data.display_name.is_empty():
		return data.display_name
	return String(MAP_NAMES.get(map_id, String(map_id)))


func has_map(map_id: StringName) -> bool:
	return MAP_RESOURCES.has(map_id)


## 场景路径由约定推导，避免在 .tres 里重复写路径导致不一致。
func _scene_path_for(map_id: StringName) -> String:
	return "res://scenes/maps/%s.tscn" % String(map_id)


func get_all_map_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for key: Variant in MAP_RESOURCES.keys():
		out.append(StringName(key))
	return out


## 第一章通关所需的 Boss → 地图映射，供小地图 / 调试面板使用。
func get_boss_arena_map(boss_id: StringName) -> StringName:
	match boss_id:
		&"morris": return &"wax_museum"
		&"pierrot": return &"old_theater"
		&"suzu": return &"well_interior"
		&"warden": return &"clock_tower"
		&"shadow_guilt": return &"shadow_boss"
	return &""
