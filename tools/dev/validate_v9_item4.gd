extends SceneTree
## Demo 9 item 4: new / remapped story SFX load; museum Wax tracks exist.
var failures: int = 0
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		failures += 1
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var audio: Node = root.get_node_or_null("AudioManager")
	check(audio != null, "AudioManager autoload")
	var ids: Array = [
		"sfx_ling_cry","sfx_vine_lash","sfx_thread_cut",
		"sfx_brush_slash","sfx_mud_grab","sfx_statue_crack",
		"sfx_nursery_rhyme","sfx_nursery_rhyme_reversed",
		"mus_wax","amb_wax","mus_fire","amb_fire","mus_well","amb_well"
	]
	for id in ids:
		var folder: String = "music" if str(id).begins_with("mus_") else ("ambient" if str(id).begins_with("amb_") else "sfx")
		var path: String = "res://assets/audio/%s/%s.wav" % [folder, id]
		check(ResourceLoader.exists(path), "exists " + path)
		if ResourceLoader.exists(path):
			var stream: AudioStream = load(path) as AudioStream
			check(stream != null, "loads " + id)
	if audio != null:
		audio.call("play_sfx", "ling_cry")
		audio.call("play_sfx", "vine_lash")
		audio.call("play_sfx", "thread_cut")
		audio.call("play_sfx", "brush_slash")
		audio.call("play_sfx", "mud_grab")
		audio.call("play_sfx", "statue_crack")
		audio.call("play_nursery_rhyme", true)
		check(true, "AudioManager play calls issued")
		audio.call("stop_all")
	print("ITEM4 failures: ", failures)
	quit(0 if failures == 0 else 1)
