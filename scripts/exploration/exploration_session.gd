class_name ExplorationSession
extends Node
## Session state survives room changes. All persistence goes through SaveManager.

signal changed
signal message(text: String)

var room_id: String = "town_entrance"
var checkpoint_room: String = "town_entrance"
var checkpoint: Vector2 = Vector2(160, 800)
var items: Dictionary = {}
var visited: Array = []
var switches: Dictionary = {}
var mirrors: Array = [0, 0, 0, 0, 0, 0, 0]
var loop_count: int = 0
var stage: int = 0
var deaths: int = 0
var elapsed: float = 0.0
var slow_time: float = 0.0
var collected: Dictionary = {}
var quest_state: Dictionary = {"tracked":"main"}

func reset() -> void:
	room_id = "town_entrance"
	checkpoint_room = room_id
	checkpoint = ExplorationCatalog.vec(ExplorationCatalog.room(room_id)["spawn"])
	items.clear()
	visited.clear()
	switches.clear()
	collected.clear()
	quest_state = {"tracked":"main"}
	mirrors = [0, 0, 0, 0, 0, 0, 0]
	stage = 0
	deaths = 0
	elapsed = 0.0
	slow_time = 0.0
	changed.emit()

func has(id: String) -> bool:
	return id.is_empty() or bool(items.get(id, false)) or bool(switches.get(id, false))

func satisfies(requirements: Array) -> bool:
	for id: String in requirements:
		if not has(id):
			return false
	return true

func acquire(id: String) -> void:
	if id.is_empty() or has(id):
		return
	items[id] = true
	stage = maxi(stage, mini(seal_count(), 3))
	changed.emit()

func chase_done() -> bool:
	return has("echo_morris") and has("echo_void")

## The bell and Ling's mud both put the lamps out until the fight is over.
func lamps_out() -> bool:
	return (room_id=="clock_tower" and not chase_done()) or (room_id=="well_interior" and has("fury_done") and not has("boss_ling"))

func seal_count() -> int:
	var count: int = 0
	for id: String in ["wax_seal", "theater_seal", "well_seal"]:
		if has(id):
			count += 1
	return count

func memory_count() -> int:
	var count: int = 0
	for id: String in items:
		if ExplorationCatalog.data().get("memories", {}).has(id):
			count += 1
	return count

func visit(id: String) -> void:
	room_id = id
	if not visited.has(id):
		visited.append(id)
	changed.emit()

func save_at(id: String, point: Vector2) -> bool:
	checkpoint_room = id
	checkpoint = point
	return save()

func save() -> bool:
	return get_node("/root/SaveManager").save_exploration({"version": 2, "room": checkpoint_room,
		"collected":collected,"quests":quest_state,"revision":9,
		"checkpoint": [checkpoint.x, checkpoint.y], "items": items,
		"visited": visited, "switches": switches, "mirrors": mirrors,
		"loop": loop_count, "stage": stage, "deaths": deaths, "elapsed": elapsed})

func restore() -> bool:
	var saved: Dictionary = get_node("/root/SaveManager").load_exploration()
	if saved.is_empty() or not ExplorationCatalog.data().get("rooms", {}).has(str(saved.get("room", ""))):
		return false
	checkpoint_room = str(saved["room"])
	room_id = checkpoint_room
	checkpoint = ExplorationCatalog.vec(saved.get("checkpoint", [160, 800]))
	items = saved.get("items", {}).duplicate(true)
	visited = saved.get("visited", []).duplicate()
	switches = saved.get("switches", {}).duplicate(true)
	collected = saved.get("collected",{}).duplicate(true)
	quest_state = saved.get("quests",{"tracked":"main"}).duplicate(true)
	mirrors = saved.get("mirrors", [0, 0, 0, 0, 0, 0, 0]).duplicate()
	loop_count = int(saved.get("loop", 0))
	stage = int(saved.get("stage", 0))
	deaths = int(saved.get("deaths", 0))
	elapsed = float(saved.get("elapsed", 0.0))
	# The previous exploration save did not have combat unlock flags.
	if has("warden_note"):
		items["time_slow"] = true
	if has("wax_seal"):
		items["boss_morris"] = true
	# Story 1.1 moved dash to the theater and the keeper's choice before the well.
	if has("theater_seal"):
		items["dash"] = true
		items["boss_void"] = true
	if has("clock_memory"):
		items["echo_morris"] = true
		items["echo_void"] = true
	if has("clock_memory") and (visited.has("fire_town") or has("true_memory")):
		items["keeper_truth"] = true
	# Story 1.1: Jerry only reaches the well bottom by being pushed in, so saves past the
	# ending skip it, and saves on the far side of the keeper's gates go back to town.
	if has("true_memory"):
		items["fury_done"] = true
		items["boss_ling"] = true
	if not has("fury_done"):
		switches.erase("opened_dry_well--well_interior")
		if checkpoint_room=="well_interior" or (checkpoint_room in ["dry_well","fire_town"] and not has("keeper_truth")):
			checkpoint_room = "dry_well" if has("keeper_truth") else "town_entrance"
			room_id = checkpoint_room
			checkpoint = ExplorationCatalog.vec(ExplorationCatalog.room(checkpoint_room)["spawn"])
	changed.emit()
	return true

func tower_checkpoint_tier() -> int:
	return int(switches.get("tower_checkpoint_tier",0))

func save_tower_section(tier: int, point: Vector2) -> bool:
	if tier<=tower_checkpoint_tier():
		return false
	switches["tower_checkpoint_tier"] = tier
	checkpoint_room = "clock_tower"
	checkpoint = point
	changed.emit()
	return save()

func objective() -> String:
	if has("boss_ling"):
		return "倒悬之井 · 走到角落里，那里蹲着真正的玲"
	if has("fury_done"):
		return "倒悬之井 · 砍断发光的藤结，趁泥浆退去攻击玲的身体"
	if has("keeper_truth"):
		return "丰收祭之夜 · 穿过安静的小镇，走到枯井边的警戒线"
	if has("clock_memory"):
		return "钟楼顶 · 守钟人在等你做出选择"
	if not has("scissors"):
		return "沿小镇西环前往美术馆 · 找到美工刀"
	if not has("wax_seal"):
		if not has("boss_morris"):
			return "美术馆走廊 · 击败梅·莫里，打开地下画室"
		return "美术馆地下画室 · 按墙上的刻度转动七面镜子"
	if not has("theater_seal"):
		return "旧剧院 · 剪断三道红线，在后台击败沃伊德，取回布偶"
	if chase_done():
		return "七层钟楼 · 只剩下守钟人了，去钟楼顶"
	if visited.has("clock_tower"):
		return "七层钟楼 · 追赶守钟人，击败完美版本的梅·莫里与沃伊德"
	return "两枚记忆印记已齐 · 返回广场，进入钟楼"
