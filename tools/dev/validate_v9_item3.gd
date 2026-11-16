extends SceneTree
## Focused asset/room smoke check; no save progress or full playthrough.
var failures: int = 0
func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:
		failures += 1
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	for id: String in ["well_mouth","caution_tape","vine","red_thread","ground_hand"]:
		var texture: Texture2D = ExplorationArt.sprite(id,-1,"props")
		check(texture!=null,"prop loads: "+id)
		if texture!=null:
			check(texture.get_image().detect_alpha()!=Image.ALPHA_NONE,"transparent: "+id)
	for cell: int in [0,1]:
		check(ExplorationArt.sprite("red_thread",cell,"props") is AtlasTexture,"thread region "+str(cell))
	var demo: Node = load("res://scenes/exploration/ExplorationDemo.tscn").instantiate()
	demo.set("_story_slot","item3_validation")
	root.add_child(demo)
	current_scene = demo
	await process_frame
	for room_id: String in ["dry_well","well_interior","old_theater"]:
		demo.start_game(false,room_id)
		demo.player.enabled = false
		for i: int in range(3):
			await process_frame
		check(demo.room.room_id==room_id,"room instantiates: "+room_id)
	demo.queue_free()
	await process_frame
	await process_frame
	print("ITEM3 failures: ",failures)
	quit(0 if failures==0 else 1)
