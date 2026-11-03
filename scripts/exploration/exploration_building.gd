class_name ExplorationBuilding
extends Node2D
## Fixed exterior architecture. Doors load separate room scenes.
## No camera position, screen anchor or Parallax2D is used by this node.

var spec: Dictionary
var session: ExplorationSession
var room: ExplorationRoom
var exterior: Sprite2D
var facade_material: ShaderMaterial
var width: float
var height: float
var _window_offset: Vector2
var _time: float = 0

func _ready() -> void:
	position = ExplorationCatalog.vec(spec["pos"])
	z_index = -10
	var texture: Texture2D = ExplorationArt.sprite(str(spec["asset"]),int(spec.get("cell",-1)),str(spec["folder"]))
	if texture == null:
		return
	var scale_factor: float = minf(float(spec["height"])/texture.get_height(),float(spec["max_width"])/texture.get_width())
	width = texture.get_width()*scale_factor
	height = texture.get_height()*scale_factor
	exterior = Sprite2D.new()
	exterior.texture = texture
	exterior.position.y = -height*.5
	exterior.position.y += ExplorationArt.foot_gap(str(spec["asset"]),int(spec.get("cell",-1)))*scale_factor
	exterior.scale = Vector2.ONE*scale_factor
	exterior.z_index = -1
	add_child(exterior)
	facade_material = ShaderMaterial.new()
	facade_material.shader = load("res://assets/environments/exploration/architecture/window_lights.gdshader") as Shader
	exterior.material = facade_material
	_window_offset = Vector2(width*.25,-height*.29)
	if bool(spec["enterable"]):
		_feature("door",Vector2.ZERO)
		_feature("window",_window_offset)
		if bool(spec.get("balcony",false)):
			var balcony := ExplorationPlatform.new()
			balcony.position = Vector2(width*.08,-118)
			balcony.dimensions = Vector2(minf(230,width*.49),42)
			balcony.one_way = true
			balcony.theme = "wood" if str(spec["terrain"])!="brass" else "brass"
			balcony.variant = 1
			add_child(balcony)
	else:
		_feature("inspect",Vector2.ZERO)

func _feature(kind: String, local_position: Vector2) -> void:
	var point := ExplorationBuildingFeature.new()
	point.building = self
	point.feature = kind
	point.session = session
	point.spec = {"kind":"building_feature","pos":[local_position.x,local_position.y]}
	point.z_index = 20
	add_child(point)
	room.interactables.append(point)

func _flag(action: String) -> String:
	return str(spec["id"])+"_"+action

func light_on() -> bool:
	return bool(session.switches.get(_flag("light"),true)) and not window_broken()

func window_broken() -> bool:
	return bool(session.switches.get(_flag("broken"),false))

func interact(feature: String) -> void:
	var demo: Node = get_tree().get_first_node_in_group("exploration_demo")
	if feature == "door":
		demo.enter_building(spec)
		return
	elif feature == "window":
		if window_broken():
			demo.show_dialogue("破碎的窗", "窗框里卡着一点旧灰。碎玻璃已经不会再恢复成原来的样子。")
		else:
			session.switches[_flag("light")] = not light_on()
			demo.hud.toast("窗灯亮起。" if light_on() else "窗灯熄灭。")
	else:
		session.switches[_flag("examined")] = true
		demo.show_dialogue(str(spec["name"]),str(spec["clue_text"]))
	session.changed.emit()
	session.save()
	queue_redraw()

func break_window() -> void:
	if window_broken():
		return
	session.switches[_flag("broken")] = true
	session.switches[_flag("light")] = false
	var demo: Node = get_tree().get_first_node_in_group("exploration_demo")
	if demo != null:
		demo.player.energy = minf(100,demo.player.energy+12)
		demo.hud.toast("窗玻璃碎裂 · 墨光恢复 12")
	session.changed.emit()
	session.save()
	queue_redraw()

func _process(delta: float) -> void:
	_time += delta
	if facade_material != null:
		facade_material.set_shader_parameter("lights_on",light_on())
	queue_redraw()

func _draw() -> void:
	if not bool(spec.get("enterable",false)) or width<=0:
		return
	var center: Vector2 = _window_offset+Vector2(0,-22)
	# The material changes the actual painted window pixels. Never overlay an
	# estimated rectangular window on the facade.
	if window_broken():
		for i: int in range(7):
			var offset := Vector2(-24+i*8,0)
			draw_line(Vector2(_window_offset.x,0)+offset,Vector2(_window_offset.x+4,-4-i%3*2)+offset,Color("9bb8bd"),2,true)
		for angle: float in [-.9,.4,1.5,2.4]:
			draw_line(center,center+Vector2.from_angle(angle)*19,Color("bdc4ad"),1.3,true)
