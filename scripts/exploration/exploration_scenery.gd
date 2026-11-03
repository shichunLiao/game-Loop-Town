class_name ExplorationScenery
extends Node2D
## Both planes are anchored to the level, never to the camera.

var data: Dictionary

func _ready() -> void:
	z_index = -32
	if bool(data.get("interior",false)):
		var wall := Sprite2D.new()
		wall.texture = ExplorationArt.sprite(str(data["interior_art"]),-1,"interiors")
		wall.z_index = -1
		if wall.texture != null:
			wall.scale = Vector2(2300,1050)/wall.texture.get_size()
			wall.position = Vector2(1150,515)
			wall.modulate = Color(.69,.77,.78)
		add_child(wall)
		# Vary indoor furnishings as physical, independently arranged landmarks.
		for i: int in range(3):
			var prop := Sprite2D.new()
			prop.texture = ExplorationArt.sprite("interior_furniture",(i+int(data["house_index"]))%4,"interiors_props")
			if prop.texture == null:
				continue
			var h: float = 155+i*32
			prop.scale = Vector2.ONE*h/prop.texture.get_height()
			prop.position = Vector2(500+i*600,960-h*.5)
			prop.modulate = Color(.65,.72,.71)
			add_child(prop)
		for p: Dictionary in data["platforms"]:
			if not bool(p.get("one_way",false)):
				continue
			var a: Array = p["rect"]
			var shelf := Sprite2D.new()
			shelf.texture = ExplorationArt.sprite("interior_furniture",1,"interiors_props")
			var h: float = float(data["floor"])-float(a[1])
			if shelf.texture == null:
				continue
			shelf.scale = Vector2(float(a[2]),h)/shelf.texture.get_size()
			shelf.position = Vector2(float(a[0])+float(a[2])*.5,float(a[1])+h*.5)
			shelf.modulate = Color(.61,.69,.68)
			add_child(shelf)
	else:
		if bool(data.get("vertical",false)):
			_build_vertical()
			return
		for entry: Dictionary in data.get("rear_scenery",[]):
			var silhouette := Sprite2D.new()
			silhouette.texture = ExplorationArt.sprite(str(entry["asset"]),int(entry["cell"]),"midgrounds")
			if silhouette.texture == null:
				continue
			var h: float = float(entry["height"])
			silhouette.scale = Vector2.ONE*h/silhouette.texture.get_height()
			silhouette.position = ExplorationCatalog.vec(entry["pos"])-Vector2(0,h*.5)
			silhouette.position.y += ExplorationArt.foot_gap(str(entry["asset"]),int(entry["cell"]))*silhouette.scale.y
			silhouette.flip_h = bool(entry.get("flip",false))
			silhouette.modulate = Color(.48,.63,.68,1) if str(data["theme"])!="fire" else Color(.59,.42,.34,1)
			var solid := ShaderMaterial.new()
			solid.shader = load("res://assets/environments/exploration/architecture/opaque_scenery.gdshader") as Shader
			silhouette.material = solid
			add_child(silhouette)
	queue_redraw()

func _build_vertical() -> void:
	# One continuous background; separate, opaque structural props mark each floor.
	for entry: Dictionary in data.get("shaft_details",[]):
		var prop := Sprite2D.new()
		prop.texture = ExplorationArt.sprite(str(entry["asset"]),int(entry["cell"]),"midgrounds")
		if prop.texture == null:
			continue
		var height: float = float(entry["height"])
		prop.scale = Vector2.ONE*height/prop.texture.get_height()
		prop.position = ExplorationCatalog.vec(entry["pos"])-Vector2(0,height*.5)
		prop.position.y += ExplorationArt.foot_gap(str(entry["asset"]),int(entry["cell"]))*prop.scale.y
		prop.flip_h = bool(entry.get("flip",false))
		prop.modulate = Color(.68,.76,.76,1)
		var solid := ShaderMaterial.new()
		solid.shader = load("res://assets/environments/exploration/architecture/opaque_scenery.gdshader") as Shader
		prop.material = solid
		add_child(prop)
	queue_redraw()

func _draw() -> void:
	if not bool(data.get("interior",false)):
		return
	var index: int = int(data.get("house_index",0))
	for i: int in range(3):
		var x: float = 650+i*560+(index%3)*35
		for radius: float in [90,52,25]:
			draw_circle(Vector2(x,365),radius,Color(1,.67,.30,.022))
		draw_line(Vector2(x,120),Vector2(x,352),Color("5c5948"),2,true)
		draw_rect(Rect2(x-10,350,20,30),Color("d5a867"))
