extends SceneTree
## Validate museum atlases and capture room views when run with a display.
var demo: Node2D
func frames(count: int) -> void:
	for i: int in range(count):
		await process_frame
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	for id: String in ['museum_mid','museum_depth']:
		for cell: int in range(4):
			var texture := load('res://assets/environments/exploration/atlases/'+id+'_'+str(cell)+'.tres') as AtlasTexture
			assert(texture != null and texture.atlas != null and texture.region.has_area())
			var runtime := ExplorationArt.sprite(id,cell,'midgrounds') as AtlasTexture
			assert(runtime != null and runtime.region == texture.region)
	demo = load('res://scenes/exploration/ExplorationDemo.tscn').instantiate()
	demo.set('_story_slot','exploration_qa')
	root.add_child(demo)
	current_scene = demo
	await frames(5)
	for id: String in ['wax_lane','wax_museum','wax_basement']:
		demo.start_game(false,id)
		demo.player.position = {'wax_lane':Vector2(2970,937),'wax_museum':Vector2(2780,1137),'wax_basement':Vector2(850,837)}[id]
		demo.player.enabled = false
		demo.camera.reset_smoothing()
		await frames(15)
		if DisplayServer.get_name() != 'headless':
			await RenderingServer.frame_post_draw
			root.get_viewport().get_texture().get_image().save_png('res://docs/exploration-demo/v9-museum-mid-'+id+'.png')
		print('PASS museum room loads: ',id)
	print('V9_MUSEUM_MID_QA: 8 atlas cells and 3 rooms passed')
	current_scene = null
	demo.queue_free()
	await process_frame
	await process_frame
	ExplorationArt._animation_frames.clear()
	ExplorationArt._textures.clear()
	root.get_node("AudioManager").stop_all()
	OS.delay_msec(80)
	quit()
