class_name ExplorationJournal
extends RefCounted
## Quest definitions are immutable; accepted, rewarded, hinted and tracked flags live in Session.

static var _data: Dictionary = {}

static func definitions() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/exploration/quests.json"))
	return _data

static func main_task(session: Node) -> Dictionary:
	for task: Dictionary in definitions()["main"]:
		if not session.has(str(task["flag"])):
			return task
	return {"id":"epilogue","title":"清晨的站台","text":"沿车站道路前进，向列车员告别。","room":"train_station","pos":[1720,840]}

static func side_task(id: String) -> Dictionary:
	for task: Dictionary in definitions()["side"]:
		if str(task["id"]) == id:
			return task
	return {}

static func discover(session: Node, id: String) -> void:
	if session.has("discovered_"+id) or not definitions()["gates"].has(id):
		return
	session.switches["discovered_"+id] = true
	if str(session.quest_state.get("tracked","main")) == "main":
		session.quest_state["tracked"] = "gate:"+id
	session.changed.emit()
	session.save()

static func accept(session: Node, id: String) -> void:
	session.quest_state[id] = "accepted"
	session.quest_state["tracked"] = id
	session.changed.emit()
	session.save()

static func target(session: Node) -> Dictionary:
	var id: String = str(session.quest_state.get("tracked","main"))
	if id.begins_with("gate:"):
		var key: String = id.trim_prefix("gate:")
		if not session.has("opened_"+key):
			var gate: Dictionary = definitions()["gates"].get(key,{})
			if not gate.is_empty():
				var known: bool = session.has("hint_"+key)
				if known:
					var next: Dictionary = gate.duplicate(true) if session.satisfies(gate["requires"]) else main_task(session).duplicate(true)
					next["title"] = gate["title"]
					next["text"] = gate["text"]
					return next
				return {"title":gate["title"],"text":str(gate["text"]) if known else "询问"+str(gate["giver_name"])+"，了解如何打开道路。","room":str(gate["hint_room"]),"pos":_guide_position(str(gate["hint_room"]),str(gate["giver_name"])),"gate":key}
	elif id != "main":
		var task: Dictionary = side_task(id)
		if not task.is_empty() and str(session.quest_state.get(id,"")) != "rewarded":
			var completed: bool = session.has(str(task["flag"]))
			return {"title":task["title"],"text":("返回"+str(task["giver_name"])+"处交谈，交付线索。") if completed else task["text"],"room":task["return_room"] if completed else task["room"],"pos":task["return_pos"] if completed else task["pos"]}
	return main_task(session)

static func _guide_position(room_id: String, role: String) -> Array:
	var people: Array = ExplorationCatalog.room(room_id).get("npcs",[])
	for npc: Dictionary in people:
		if str(npc.get("role","")) == role:
			return npc["pos"]
	return people[0]["pos"] if not people.is_empty() else ExplorationCatalog.room(room_id).get("spawn",[200,800])

static func navigation(session: Node) -> Dictionary:
	var goal: Dictionary = target(session).duplicate(true)
	var current: String = session.room_id
	var destination: String = str(goal.get("room",current))
	if current == destination:
		return goal
	var all: Dictionary = ExplorationCatalog.data()["rooms"]
	if bool(all[current].get("interior",false)):
		goal["pos"] = [170,all[current]["floor"]]
		goal["step"] = "先返回街道"
		return goal
	# Interiors connect to their real front door, separate from the road graph.
	if bool(all.get(destination,{}).get("interior",false)):
		if str(all[destination]["parent_region"]) == current:
			goal["pos"] = all[destination]["return_pos"]
			goal["step"] = "推门进入 "+str(all[destination]["name"])
			return goal
		destination = str(all[destination]["parent_region"])
	var costs: Dictionary = {current:0.0}
	var first: Dictionary = {}
	var pending: Array[String] = [current]
	while not pending.is_empty():
		pending.sort_custom(func(a: String,b: String): return float(costs[a])<float(costs[b]))
		var node: String = pending.pop_front()
		if node == destination:
			break
		for route: Dictionary in all[node].get("exits",[]):
			var next: String = str(route["target"])
			var price: float = float(costs[node])+1.0+(0.0 if session.satisfies(route.get("requires",[])) else 18.0)
			if not costs.has(next) or price<float(costs[next]):
				costs[next] = price
				first[next] = route if node==current else first[node]
				if not pending.has(next):
					pending.append(next)
	if first.has(destination):
		var route: Dictionary = first[destination]
		goal["pos"] = route["pos"]
		goal["step"] = "沿通路前往 "+ExplorationCatalog.title(str(route["target"]))
	return goal
