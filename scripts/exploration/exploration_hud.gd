class_name ExplorationHUD
extends CanvasLayer
## Presentation only: requests go back to the demo controller.

var controller: Node2D
var root: Control
var overlay: Control
var location_label: Label
var objective_label: Label
var ability_label: Label
var prompt_label: Label
var counter_label: Label
var toast_label: Label
var health: ProgressBar
var energy: ProgressBar
var vitals_label: Label
var block_label: Label
var boss_health: ProgressBar
var boss_label: Label
var current_map: ExplorationWorldMap
var _toast_time: float = 0.0
var _font: Font
var direction_label: Label
var _navigation_clock: float = 0

func _ready() -> void:
	layer = 20
	_font = load("res://assets/ui/exploration/chinese.tres") as Font
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	theme.default_font = _font
	theme.default_font_size = 18
	root.theme = theme
	add_child(root)
	location_label = label(root,Vector2(30,24),Vector2(550,38),"",27,Color("eee2c6"))
	health = ProgressBar.new()
	health.position = Vector2(98,72)
	health.size = Vector2(216,12)
	health.scale.y = .38
	health.show_percentage = false
	health.max_value = 100
	health.add_theme_stylebox_override("background",panel_style(Color("20282b"),Color("536467")))
	health.add_theme_stylebox_override("fill",panel_style(Color("8dcaca"),Color("8dcaca")))
	root.add_child(health)
	energy = ProgressBar.new()
	energy.position = Vector2(98,94)
	energy.size = Vector2(178,8)
	energy.scale.y = .27
	energy.show_percentage = false
	energy.max_value = 100
	energy.add_theme_stylebox_override("background",panel_style(Color("20282b"),Color("536467")))
	energy.add_theme_stylebox_override("fill",panel_style(Color("d6b077"),Color("d6b077")))
	root.add_child(energy)
	vitals_label = label(root,Vector2(30,65),Vector2(65,46),"生命\n墨光",13,Color("d7d2ba"))
	block_label = label(root,Vector2(30,148),Vector2(560,28),"",16,Color("e7c894"))
	boss_label = label(root,Vector2(340,608),Vector2(600,32),"",21,Color("ead2a6"))
	boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_health = ProgressBar.new()
	boss_health.position = Vector2(365,649)
	boss_health.size = Vector2(550,12)
	boss_health.scale.y = .38
	boss_health.show_percentage = false
	boss_health.add_theme_stylebox_override("background",panel_style(Color("211d21"),Color("7c6755")))
	boss_health.add_theme_stylebox_override("fill",panel_style(Color("b46f48"),Color("dbad6b")))
	root.add_child(boss_health)
	boss_health.hide()
	objective_label = label(root,Vector2(680,24),Vector2(565,70),"",15,Color("d4cab4"))
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	counter_label = label(root,Vector2(680,104),Vector2(565,28),"",13,Color("a8c2c1"))
	counter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ability_label = label(root,Vector2(30,114),Vector2(830,28),"",13,Color("97b8bb"))
	prompt_label = label(root,Vector2(200,595),Vector2(880,42),"",19,Color("f5e6c6"))
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label(root,Vector2(30,683),Vector2(1220,26),"A/D 移动  Space 跳  J 三连击  K 技能  H 恢复  E 交谈/机关  Shift 冲刺  Q 缓时  L 任务  M 地图  Tab 笔记",13,Color("9cbbb9"))
	direction_label = label(root,Vector2(800,142),Vector2(445,38),"",14,Color("e4c88f"))
	direction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	toast_label = label(root,Vector2(240,140),Vector2(800,48),"",18,Color("e9d19c"))
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(overlay)
	overlay.hide()

func label(host: Node, pos: Vector2, dimensions: Vector2, text: String, font_size: int = 18, color: Color = Color.WHITE) -> Label:
	var node := Label.new()
	node.position = pos
	node.size = dimensions
	node.text = text
	node.add_theme_font_size_override("font_size",font_size)
	node.add_theme_color_override("font_color",color)
	node.add_theme_color_override("font_shadow_color",Color(0,0,0,.9))
	node.add_theme_constant_override("shadow_offset_x",1)
	node.add_theme_constant_override("shadow_offset_y",2)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(node)
	return node

func button(host: Node, pos: Vector2, dimensions: Vector2, text: String, action: Callable) -> Button:
	var node := Button.new()
	node.position = pos
	node.size = dimensions
	node.text = text
	node.add_theme_font_size_override("font_size",18)
	node.add_theme_color_override("font_color",Color("dddfcc"))
	node.add_theme_color_override("font_hover_color",Color("fff0cc"))
	node.add_theme_stylebox_override("normal",panel_style(Color("19272c"),Color("536f72")))
	node.add_theme_stylebox_override("hover",panel_style(Color("30494b"),Color("c6b487")))
	node.add_theme_stylebox_override("focus",panel_style(Color(0,0,0,0),Color("bbcebb")))
	node.pressed.connect(action)
	host.add_child(node)
	return node

func panel_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	return style

func clear_overlay() -> void:
	for child: Node in overlay.get_children():
		overlay.remove_child(child)
		child.queue_free()
	current_map = null
	overlay.show()

func shade(alpha: float = .85) -> void:
	var color := ColorRect.new()
	color.color = Color(0.025,.045,.06,alpha)
	color.size = Vector2(1280,720)
	overlay.add_child(color)

func show_menu() -> void:
	controller.restore_story_slot()
	clear_overlay()
	var background := TextureRect.new()
	background.texture = load("res://assets/environments/exploration/backgrounds/town.png") as Texture2D
	background.size = Vector2(1280,720)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	overlay.add_child(background)
	shade(.48)
	label(overlay,Vector2(76,137),Vector2(800,90),"回 环 镇",74,Color("f2e7cc"))
	label(overlay,Vector2(80,235),Vector2(600,30),"L O O P   T O W N   /   第 %d 次循环" % controller.session.loop_count,17,Color("bad1cc"))
	label(overlay,Vector2(80,284),Vector2(610,50),"在一座没有出口的小镇，找回那一夜。",21,Color("d4c5ad"))
	button(overlay,Vector2(80,371),Vector2(270,46),"新探索（重新开始）",func(): controller.start_game(false))
	var continue_button: Button = button(overlay,Vector2(80,430),Vector2(270,46),"继续上一次探索",func(): controller.start_game(true))
	continue_button.disabled = get_node("/root/SaveManager").load_exploration().is_empty()
	button(overlay,Vector2(80,489),Vector2(270,46),"查看完整大地图",func(): controller.open_map(true))
	button(overlay,Vector2(80,548),Vector2(270,46),"退出",func(): get_tree().quit())
	button(overlay,Vector2(370,489),Vector2(220,46),"人物与敌人图鉴",controller.open_cast)
	button(overlay,Vector2(370,548),Vector2(220,46),"莫里斯演练",controller.start_boss_practice)
	label(overlay,Vector2(80,652),Vector2(1100,30),"动作探索 Demo 8  /  连续街道 · 房屋屋顶支路 · 落地中景 · 实体井道 · 三阶段莫里斯",14,Color("aabdb7"))

func show_map(overview: bool = false) -> void:
	clear_overlay()
	current_map = ExplorationWorldMap.new()
	current_map.session = controller.session
	current_map.overview = overview
	current_map.size = Vector2(1280,720)
	overlay.add_child(current_map)
	button(overlay,Vector2(1140,20),Vector2(105,32),"关闭  M",controller.close_overlay)

func show_dialogue(title: String, text: String, choices: Array = []) -> void:
	clear_overlay()
	shade(.64)
	var panel := Panel.new()
	panel.position = Vector2(235,117)
	panel.size = Vector2(810,485)
	panel.add_theme_stylebox_override("panel",panel_style(Color("101f25"),Color("9c8c69")))
	overlay.add_child(panel)
	label(panel,Vector2(35,26),Vector2(740,48),title,28,Color("e7cf9f"))
	var body := RichTextLabel.new()
	body.position = Vector2(35,86)
	body.size = Vector2(740,310)
	body.text = text
	body.add_theme_font_size_override("normal_font_size",18)
	body.add_theme_color_override("default_color",Color("d8e3d9"))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(body)
	if choices.is_empty():
		button(panel,Vector2(525,421),Vector2(245,42),"继续  E / Space",controller.close_overlay)
	else:
		for i: int in range(choices.size()):
			var choice: Dictionary = choices[i]
			var option: Button = button(panel,Vector2(35+i*370,421),Vector2(350,42),str(choice["label"]),choice["action"])
			if i==0:
				option.grab_focus()

func show_quests() -> void:
	clear_overlay()
	shade(.96)
	label(overlay,Vector2(60,25),Vector2(950,44),"任务日志 · 居民留下的线索",30,Color("ecd7aa"))
	button(overlay,Vector2(1100,28),Vector2(120,38),"关闭 L",controller.close_overlay)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(60,94)
	scroll.size = Vector2(1160,570)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	overlay.add_child(scroll)
	var content := Control.new()
	content.custom_minimum_size = Vector2(1125,1400)
	scroll.add_child(content)
	var y: float = 0
	var session: ExplorationSession = controller.session
	var task: Dictionary = ExplorationJournal.main_task(session)
	y = _quest_card(content,y,"main","主线 · "+str(task["title"]),str(task["text"])+"\n目标："+ExplorationCatalog.title(str(task["room"])),false)
	for request: Dictionary in ExplorationJournal.definitions()["side"]:
		var id: String = str(request["id"])
		var status: String = str(session.quest_state.get(id,""))
		if status.is_empty():
			continue
		var done: bool = status=="rewarded"
		var return_ready: bool = session.has(str(request["flag"]))
		var details: String = "委托人："+str(request["giver_name"])+" · "+ExplorationCatalog.title(str(request["return_room"]))+"\n"+str(request["text"])
		if return_ready and not done:
			details = "已找到线索。回到"+str(request["giver_name"])+"处交谈领取回报。\n地点："+ExplorationCatalog.title(str(request["return_room"]))
		y = _quest_card(content,y,id,("已完成 · " if done else "待交付 · " if return_ready else "委托 · ")+str(request["title"]),details,done)
	for id: String in ExplorationJournal.definitions()["gates"]:
		if not session.has("discovered_"+id):
			continue
		var gate: Dictionary = ExplorationJournal.definitions()["gates"][id]
		var done: bool = session.has("opened_"+id)
		var detail: String = str(gate["text"]) if session.has("hint_"+id) else "询问"+str(gate["giver_name"])+" · "+ExplorationCatalog.title(str(gate["hint_room"]))
		y = _quest_card(content,y,"gate:"+id,("已开启 · " if done else "道路调查 · ")+str(gate["title"]),detail,done)
	for history: Dictionary in ExplorationJournal.definitions()["main"]:
		if session.has(str(history["flag"])):
			y = _quest_card(content,y,str(history["id"]),"已完成主线 · "+str(history["title"]),str(history["text"]),true)
	content.custom_minimum_size.y = y+20

func _quest_card(host: Control, y: float, id: String, title: String, text: String, done: bool) -> float:
	var panel := Panel.new()
	panel.position = Vector2(0,y)
	panel.size = Vector2(1120,128)
	panel.add_theme_stylebox_override("panel",panel_style(Color("15272d"),Color("576d65") if done else Color("8c7959")))
	host.add_child(panel)
	label(panel,Vector2(22,12),Vector2(880,33),title,21,Color("b4c6b6") if done else Color("ebd2a2"))
	var body: Label = label(panel,Vector2(22,50),Vector2(895,69),text,16,Color("b9ceca"))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if not done:
		button(panel,Vector2(948,42),Vector2(148,40),"正在追踪" if str(controller.session.quest_state.get("tracked","main"))==id else "追踪目标",func(): controller.session.quest_state["tracked"]=id; controller.session.changed.emit(); controller.session.save(); show_quests())
	return y+142

func show_notebook() -> void:
	clear_overlay()
	shade(.95)
	label(overlay,Vector2(64,36),Vector2(900,50),"空白笔记本 · 已留下的记忆",31,Color("e5cf9f"))
	button(overlay,Vector2(1080,34),Vector2(140,40),"合上  Tab",controller.close_overlay)
	var body := RichTextLabel.new()
	body.position = Vector2(80,116)
	body.size = Vector2(1120,535)
	body.bbcode_enabled = true
	body.add_theme_font_size_override("normal_font_size",21)
	body.add_theme_color_override("default_color",Color("b9cecb"))
	var memories: Dictionary = ExplorationCatalog.data()["memories"]
	body.append_text("[color=#e9c78a]动作与阶段能力[/color]\n")
	for skill: Dictionary in ExplorationArt.actors()["skills"]:
		var unlocked: bool = str(skill["id"])=="notebook" or controller.session.has(str(skill["id"]))
		body.append_text(("✓ " if unlocked else "○ ")+str(skill["name"])+"  ·  "+str(skill["keys"])+"  ·  "+str(skill["stage"])+"\n")
	body.append_text("\nH：消耗 50 墨光恢复 30 生命。命中敌人与停留可恢复墨光。\n\n[color=#e9c78a]已记录的线索[/color]\n")
	body.append_text("[color=#e9c78a]阶段武器[/color]\n墨页短刃：纸页斩；大剪刀：K 突进剪断；红线双剪：K 环身双重剪击；井火钩刃：K 余火突进；钟钥细剑：K 穿刺并短暂缓时。\nW+J 上挑；空中 S+J 下劈，命中敌人可反弹。连续 J 为三连击，第三击范围与伤害提高。\n\n")
	for id: String in memories:
		if controller.session.has(id):
			body.append_text("[color=#e9c78a]"+str(memories[id]["title"])+"[/color]\n"+str(memories[id]["text"])+"\n\n")
	if controller.session.memory_count() == 0:
		body.append_text("纸上尚无字迹。靠近发光的记忆，按 E 调查。")
	overlay.add_child(body)

func toast(text: String) -> void:
	toast_label.text = text
	_toast_time = 4.0

func show_cast() -> void:
	clear_overlay()
	shade(.98)
	label(overlay,Vector2(42,24),Vector2(900,44),"回环镇 · 人物初版",30,Color("e5cf9f"))
	button(overlay,Vector2(1110,25),Vector2(130,36),"返回",controller.close_overlay)
	var data: Dictionary = ExplorationArt.actors()
	var groups: Array = [data["npcs"].values(),data["enemies"].values()]
	for row: int in range(2):
		label(overlay,Vector2(44,83+row*229),Vector2(900,30),"居民 / 对话与循环动作" if row==0 else "敌人 / 八种外观与行为",18,Color("94b9b8"))
		for i: int in range(groups[row].size()):
			var actor: Dictionary = groups[row][i]
			var portrait := Sprite2D.new()
			portrait.texture = ExplorationArt.sprite(str(actor["atlas"]),int(actor["cell"]))
			portrait.position = Vector2(113+i*148,194+row*229)
			portrait.scale = Vector2.ONE*minf(130.0/portrait.texture.get_width(),150.0/portrait.texture.get_height())
			overlay.add_child(portrait)
			var text := label(overlay,Vector2(42+i*148,276+row*229),Vector2(142,30),str(actor["name"]),15,Color("e2d3b6"))
			text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for i: int in range(2):
		var portrait := Sprite2D.new()
		portrait.texture = ExplorationArt.sprite("hero" if i==0 else "morris")
		portrait.position = Vector2(110+i*300,624)
		portrait.scale = Vector2.ONE*minf(100.0/portrait.texture.get_width(),130.0/portrait.texture.get_height())
		overlay.add_child(portrait)
		label(overlay,Vector2(170+i*300,585),Vector2(180,70),"侦探\n笔记本 / 大剪刀" if i==0 else "莫里斯\n熔蜡 / 突进 / 替身",16,Color("d5c5ab"))
	label(overlay,Vector2(700,584),Vector2(510,80),"他们在重复某个动作，等待一句迟来的回答。\n\n路灯会记住你走过的地方。",17,Color("9fb7b4"))

func _process(delta: float) -> void:
	_toast_time = maxf(0.0,_toast_time-delta)
	toast_label.modulate.a = minf(1,_toast_time)
	if controller == null or controller.session == null:
		return
	var session: ExplorationSession = controller.session
	location_label.text = ExplorationCatalog.title(session.room_id)
	var objective: Dictionary = ExplorationJournal.target(session)
	objective_label.text = "[ L 任务 ] "+str(objective["title"])+"\n"+str(objective["text"])
	var practice: bool = get_node("/root/SaveManager").exploration_slot_name=="exploration_boss_practice"
	if practice:
		objective_label.text = "莫里斯演练 · 观察预警，利用收招反击\n跳过突进，绕到横扫背后，离开地刺与烛雨标记。"
	_navigation_clock -= delta
	if _navigation_clock<=0 and is_instance_valid(controller.player):
		_navigation_clock = .25
		var navigation: Dictionary = ExplorationJournal.navigation(session)
		var point: Vector2 = ExplorationCatalog.vec(navigation.get("pos",[0,0]))
		var relative: Vector2 = point-controller.player.position
		var arrow: String = "↑" if absf(relative.y)>absf(relative.x)*.75 and relative.y< -100 else "↓" if absf(relative.y)>absf(relative.x)*.75 and relative.y>100 else "→" if relative.x>0 else "←"
		direction_label.text = arrow+" "+str(navigation.get("step",ExplorationCatalog.title(str(navigation.get("room",session.room_id)))))+" · %d 米" % int(relative.length()/64)
		if practice:
			direction_label.text = "J 连击 / K 剪刃突进 / H 墨光恢复"
	var main_count: int = 0
	for id: String in session.visited:
		if bool(ExplorationCatalog.room(id).get("main_region",true)):
			main_count += 1
	counter_label.text = "第 %d 次循环   ·   印记 %d / 3   ·   记忆 %d   ·   区域 %d / 18" % [session.loop_count,session.seal_count(),session.memory_count(),main_count]
	var abilities: Array[String] = []
	abilities.append("J "+str(ExplorationWeapon.profile(session)["name"])+" · 三连击"+(" / K 阶段技能" if session.has("scissors") else ""))
	for pair: Array in [["double_jump","二段跳"],["vine","W/S 攀爬"],["dash","Shift 冲刺"],["time_slow","Q 缓时"]]:
		if session.has(str(pair[0])):
			abilities.append(str(pair[1]))
	ability_label.text = "  /  ".join(abilities)
	if is_instance_valid(controller.player):
		health.value = controller.player.health
		energy.value = controller.player.energy
		health.tooltip_text = "%d / 100" % controller.player.health
		var nearest: String = ""
		var distance: float = INF
		for block: Dictionary in controller.room.data.get("blocks",[]):
			var candidate: float = controller.player.position.distance_to(Vector2(float(block["x"]),float(block["y"])))
			if candidate<distance:
				distance = candidate
				nearest = str(block["name"])
		block_label.text = nearest
	var boss: Node = get_tree().get_first_node_in_group("exploration_boss")
	var show_boss: bool = boss != null and not boss.dead and boss.state!="sleep" and controller.mode=="play"
	boss_health.visible = show_boss
	boss_label.visible = show_boss
	if show_boss:
		boss_health.max_value = boss.max_health
		boss_health.value = boss.health
		boss_label.text = "莫里斯 · "+str(boss.phase_title)+" / 阶段 %d" % boss.phase
		if boss.state=="windup":
			boss_label.text = str(boss.attack_name)
