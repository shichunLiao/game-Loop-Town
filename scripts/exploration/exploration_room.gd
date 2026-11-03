class_name ExplorationRoom
extends Node2D
## Each room is an independent scene, assembled from the same audited geometry data.

@export var room_id: String = "town_entrance"
var data: Dictionary
var session: ExplorationSession
var interactables: Array[ExplorationInteractable] = []
var platforms: Array[ExplorationPlatform] = []
var passages: Array[ExplorationPassage] = []
var npcs: Array[ExplorationNPC] = []
var actors: Node2D
var buildings: Array[ExplorationBuilding] = []
var bounds: Vector2
var _flood_time: float = 0.0
var _flood_y: float = 10000.0

func _ready() -> void:
	data = ExplorationCatalog.room(room_id)
	if session == null:
		_launch_standalone.call_deferred()
		return
	bounds = ExplorationCatalog.vec(data["size"])
	if not bool(data.get("interior",false)):
		var environment := ExplorationBackdrop.new()
		environment.name = "Background"
		environment.room = data
		environment.session = session
		add_child(environment)
	var rear := ExplorationScenery.new()
	rear.name = "WorldRearScenery"
	rear.data = data
	add_child(rear)
	var structure := ExplorationStructure.new()
	structure.name = "ArchitectureSupports"
	structure.data = data
	add_child(structure)
	var gameplay := Node2D.new()
	gameplay.name = "Gameplay"
	add_child(gameplay)
	for entry: Dictionary in data.get("platforms", []):
		var platform := ExplorationPlatform.new()
		var rect: Array = entry["rect"]
		platform.position = Vector2(float(rect[0]),float(rect[1]))
		platform.dimensions = Vector2(float(rect[2]),float(rect[3]))
		platform.one_way = bool(entry.get("one_way",false))
		platform.theme = str(entry.get("material",data["terrain"]))
		platform.variant = int(entry.get("variant",0))
		platform.travel = ExplorationCatalog.vec(entry.get("travel", [0,0]))
		platform.period = float(entry.get("period", 4.5))
		platform.geometry = str(entry.get("geometry",""))
		platform.masonry = int(entry.get("masonry",data.get("masonry",0)))
		platform.manual_lift = bool(entry.get("manual_lift",false))
		platform.lift_unlock = str(entry.get("lift_unlock",""))
		platform.lift_up = str(entry.get("lift_up",""))
		platform.lift_speed = float(entry.get("lift_speed",430))
		platform.session = session
		gameplay.add_child(platform)
		platforms.append(platform)
	for entry: Dictionary in data.get("hazards", []):
		var hazard := ExplorationHazard.new()
		hazard.spec = entry
		hazard.session = session
		gameplay.add_child(hazard)
	if not data.get("street_access",[]).is_empty():
		var access := ExplorationStreetAccess.new()
		access.routes = data["street_access"]
		gameplay.add_child(access)
	var objects := Node2D.new()
	objects.name = "Interactables"
	add_child(objects)
	for platform: ExplorationPlatform in platforms:
		if platform.manual_lift:
			var lever := ExplorationLiftFeature.new()
			lever.lift = platform
			lever.session = session
			lever.spec = {"kind":"lift_cabin","pos":[platform.position.x+platform.dimensions.x*.5,platform.position.y]}
			objects.add_child(lever)
			interactables.append(lever)
	if bool(data.get("main_region",true)):
		_add_interactable({"kind":"checkpoint", "pos":data["checkpoint"]}, objects)
	for entry: Dictionary in data["objects"]:
		_add_interactable(entry, objects)
	for entry: Dictionary in data["exits"]:
		var passage := ExplorationPassage.new()
		passage.spec = entry
		passage.session = session
		objects.add_child(passage)
		passages.append(passage)
		interactables.append(passage)
	var architecture := Node2D.new()
	architecture.name = "WorldArchitecture"
	add_child(architecture)
	for entry: Dictionary in data.get("buildings",[]):
		var building := ExplorationBuilding.new()
		building.spec = entry
		building.room = self
		building.session = session
		architecture.add_child(building)
		buildings.append(building)
	var details := Node2D.new()
	details.name = "WorldStreetDetails"
	details.z_index = -5
	add_child(details)
	for entry: Dictionary in data.get("street_props",[]):
		var decoration := Sprite2D.new()
		decoration.texture = ExplorationArt.sprite(str(entry["asset"]),int(entry["cell"]),str(entry["folder"]))
		if decoration.texture == null:
			continue
		var display_height: float = float(entry["height"])
		decoration.scale = Vector2.ONE*display_height/decoration.texture.get_height()
		decoration.position = ExplorationCatalog.vec(entry["pos"])-Vector2(0,display_height*.5)
		decoration.position.y += ExplorationArt.foot_gap(str(entry["asset"]),int(entry["cell"]))*decoration.scale.y
		details.add_child(decoration)
	actors = Node2D.new()
	actors.name = "Actors"
	add_child(actors)
	for entry: Dictionary in data.get("npcs",[]):
		var npc := ExplorationNPC.new()
		npc.spec = entry
		npc.session = session
		actors.add_child(npc)
		npcs.append(npc)
	for entry: Dictionary in data.get("enemies",[]):
		if session.has("defeated_"+str(entry["id"])):
			continue
		var enemy := ExplorationEnemy.new()
		enemy.spec = entry
		enemy.session = session
		actors.add_child(enemy)
	if data.has("boss") and not session.has("boss_morris"):
		var enemy := ExplorationBoss.new()
		enemy.spec = data["boss"].duplicate(true)
		enemy.spec["id"] = "morris"
		enemy.session = session
		actors.add_child(enemy)
	var foreground := Node2D.new()
	foreground.name = "Foreground"
	foreground.z_index = 30
	add_child(foreground)
	var texture: Texture2D = load("res://assets/environments/exploration/props/foreground.png") as Texture2D
	for x: int in range(-160, int(bounds.x)+100 if not bool(data.get("interior",false)) else -160, 1350):
		var decoration := Sprite2D.new()
		decoration.texture = texture
		decoration.position = Vector2(x, float(data["floor"]) + 320)
		decoration.scale = Vector2(.42,.42)
		decoration.flip_h = x % 2 == 0
		decoration.modulate = Color(0.4,0.53,0.61,.85)
		foreground.add_child(decoration)
	queue_redraw()

func _add_interactable(spec: Dictionary, host: Node2D) -> void:
	var object := ExplorationInteractable.new()
	object.spec = spec
	object.session = session
	host.add_child(object)
	interactables.append(object)

func _launch_standalone() -> void:
	var packed: PackedScene = load("res://scenes/exploration/ExplorationDemo.tscn") as PackedScene
	var demo: Node2D = packed.instantiate()
	get_tree().root.add_child(demo)
	get_tree().current_scene = demo
	demo.call("start_game", false, room_id)
	queue_free()

func _process(_delta: float) -> void:
	if session != null:
		queue_redraw()


func _physics_process(delta: float) -> void:
	if session == null or room_id != "well_interior":
		return
	if session.has("well_escape_active") and not session.has("well_escaped"):
		_flood_time += delta
		_flood_y = bounds.y+650.0-_flood_time*85.0
		var player: ExplorationPlayer = get_tree().get_first_node_in_group("exploration_player") as ExplorationPlayer
		if player != null and player.position.y > _flood_y:
			player.take_damage(100)

func _draw() -> void:
	if session == null:
		return
	if _flood_y < bounds.y:
		draw_rect(Rect2(0,_flood_y,bounds.x,bounds.y-_flood_y+300),Color("10202b"))
		for x: int in range(0,int(bounds.x),24):
			draw_line(Vector2(x,_flood_y+sin(x*.03+_flood_time*2)*6),Vector2(x+24,_flood_y+sin((x+24)*.03+_flood_time*2)*6),Color("77a5ac"),3,true)
	for entry: Array in data.get("vines", []):
		var x: float = float(entry[0]) + float(entry[2])*.5
		for offset: float in [-24.0,0.0,24.0]:
			draw_line(Vector2(x+offset,float(entry[1])),Vector2(x+offset,float(entry[1])+float(entry[3])),Color("44635b"),7,true)
			for y: int in range(int(entry[1]),int(entry[1])+int(entry[3]),30):
				draw_line(Vector2(x+offset,y),Vector2(x+offset+19,y-12),Color("719b7d"),3,true)
	if room_id == "wax_basement":
		var solution: Array = ExplorationCatalog.data()["mirror_solution"]
		var last := Vector2(170, float(data["floor"])-55)
		for i: int in range(7):
			var next := Vector2(310+i*175,float(data["floor"])-55)
			if int(session.mirrors[i]) != int(solution[i]):
				break
			draw_line(last,next,Color("e5d8a1"),3.0,true)
			last = next
