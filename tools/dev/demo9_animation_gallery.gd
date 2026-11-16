extends SceneTree
## Optional review tool, no game session or saves touched. Left/right change page; Escape exits.
var clips: Array = []
var actors: Array[Sprite2D] = []
var labels: Array[Label] = []
var page: int = 0
var age: float = 0
var heading: Label

func _initialize() -> void:
	_build.call_deferred()

func _build() -> void:
	root.size = Vector2i(1280,720)
	root.window_input.connect(_input)
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene
	clips = ExplorationArt.animation_manifest().clips.keys()
	clips.sort()
	heading = Label.new()
	heading.position = Vector2(24,10)
	heading.add_theme_font_size_override("font_size",23)
	scene.add_child(heading)
	for i: int in 12:
		var sprite := Sprite2D.new()
		sprite.position = Vector2(155+(i%4)*320,190+(i/4)*220)
		scene.add_child(sprite)
		actors.append(sprite)
		var label := Label.new()
		label.position = Vector2(20+(i%4)*320,240+(i/4)*220)
		label.add_theme_font_size_override("font_size",17)
		scene.add_child(label)
		labels.append(label)
	_update_page()

func _update_page() -> void:
	age = 0
	heading.text = "Demo 9 · CG animation gallery · %d/%d · ← → pages · Esc exits" % [page+1,ceili(clips.size()/12.0)]
	for i: int in 12:
		var at: int = page*12+i
		actors[i].visible = at<clips.size()
		labels[i].text = str(clips[at]) if at<clips.size() else ""

func _process(delta: float) -> bool:
	if actors.is_empty():
		return false
	age += delta
	for i: int in 12:
		var at: int = page*12+i
		if at>=clips.size():
			continue
		var id: String = str(clips[at])
		var duration: float = float(ExplorationArt.clip_info(id).duration)
		actors[i].texture = ExplorationArt.animation_frame(id,ExplorationArt.animation_index(id,fmod(age,duration)))
		actors[i].scale = Vector2.ONE*minf(180.0/actors[i].texture.get_height(),290.0/actors[i].texture.get_width())
	return false

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			quit()
		elif event.keycode in [KEY_RIGHT,KEY_LEFT,KEY_SPACE]:
			page = posmod(page+(-1 if event.keycode==KEY_LEFT else 1),ceili(clips.size()/12.0))
			_update_page()
