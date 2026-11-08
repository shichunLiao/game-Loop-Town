extends SceneTree
## Demo 9 item 5: story mechanics smoke — scripts, detective, covers, defeat flag, collapse helper.
var failures: int = 0

func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		failures += 1

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	check(ResourceLoader.exists("res://scripts/exploration/exploration_push_cover.gd"), "push cover script")
	check(ResourceLoader.exists("res://scripts/exploration/exploration_boss.gd"), "may boss script")
	check(ResourceLoader.exists("res://assets/environments/exploration/actors/detective.png"), "detective art")
	var actors: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/exploration/actors.json"))
	check(typeof(actors) == TYPE_DICTIONARY and actors.get("npcs", {}).has("detective"), "detective npc def")
	var world: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/exploration/world.json"))
	var town_npcs: Array = world.get("rooms", {}).get("town_entrance", {}).get("npcs", [])
	var has_det := false
	for n in town_npcs:
		if str(n.get("id", "")) == "detective_town_entrance":
			has_det = true
	check(has_det, "detective at town_entrance")
	var dry_npcs: Array = world.get("rooms", {}).get("dry_well", {}).get("npcs", [])
	var has_well_det := false
	for n in dry_npcs:
		if str(n.get("id", "")) == "detective_dry_well":
			has_well_det = true
			check(n.get("requires", []) == ["fury_done"], "detective well requires fury_done")
	check(has_well_det, "detective at dry_well")

	var actions_src := FileAccess.get_file_as_string("res://scripts/exploration/exploration_actions.gd")
	check(actions_src.find("func _clocktower_collapse") >= 0, "clocktower collapse helper")
	var boss_src := FileAccess.get_file_as_string("res://scripts/exploration/exploration_boss.gd")
	check(boss_src.find("torn") >= 0 and boss_src.find("sculpted") >= 0 and boss_src.find("painted") >= 0, "may defeat endings")
	check(boss_src.find("_spawn_covers") >= 0 and boss_src.find("_victory_cutscene") >= 0, "covers + victory cutscene")
	var player_src := FileAccess.get_file_as_string("res://scripts/exploration/exploration_player.gd")
	check(player_src.find("paint_lock") >= 0 and player_src.find("last_may_kind") >= 0, "paint stacks / may kinds")

	var demo: Node = load("res://scenes/exploration/ExplorationDemo.tscn").instantiate()
	demo.set("_story_slot", "item5_validation")
	root.add_child(demo)
	current_scene = demo
	await process_frame
	await process_frame

	for room_id: String in ["wax_museum", "clock_top", "town_entrance", "dry_well", "fire_town"]:
		demo.start_game(false, room_id)
		if demo.player != null:
			demo.player.enabled = false
		for i: int in range(5):
			await process_frame
		check(demo.room != null and demo.room.room_id == room_id, "room " + room_id)
		if room_id == "wax_museum" and demo.room != null:
			var has_may := false
			var covers := 0
			for child: Node in demo.room.actors.get_children():
				if child.is_in_group("may_boss"):
					has_may = true
					child.call("_spawn_covers")
					await process_frame
					await process_frame
			for n: Node in root.get_tree().get_nodes_in_group("morris_owned"):
				if n.get("floor_y") != null and str(n.get_script()).find("push_cover") >= 0:
					covers += 1
				elif n is CharacterBody2D and n.has_method("_physics_process") and n.get("floor_y") != null:
					covers += 1
			check(has_may or demo.session.has("boss_morris"), "may present or already defeated")
			check(covers >= 3 or demo.session.has("boss_morris"), "may covers spawned (%d)" % covers)
		if room_id == "town_entrance" and demo.room != null:
			var seen := false
			for npc in demo.room.npcs:
				if str(npc.spec.get("type", "")) == "detective":
					seen = true
			check(seen, "detective instance in town")
		if room_id == "clock_top" and demo.actions != null:
			check(demo.actions.has_method("_clocktower_collapse"), "actions has collapse")

	demo.start_game(false, "wax_museum")
	await process_frame
	demo.defeat("torn", "结局 · 被撕碎", "test")
	check(bool(demo.session.has("ending_torn")), "defeat flag torn")
	demo.queue_free()
	await process_frame
	await process_frame
	print("ITEM5 failures: ", failures)
	quit(0 if failures == 0 else 1)
