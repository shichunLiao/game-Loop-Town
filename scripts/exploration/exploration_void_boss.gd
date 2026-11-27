class_name ExplorationVoidBoss
extends ExplorationEnemy
## Void, the theater's prop master. He stays at stage center and fights through red threads:
## seat puppets, a floor lash, a noose and, at the end, a frenzy of falling threads.

const CLOTH_LIMIT: int = 8
const DEFEATS := {
	"broken_puppet": ["结局 · 破败的人偶", "红线勒住了你的脖子。\n沃伊德把你挂回观众席，和那些缺了手脚的人偶坐在一起。\n戏还没有散场。"],
	"doll": ["结局 · 布偶", "你的手脚越来越软，越来越轻，美工刀从布做的手里滑落。\n最后你成了一只没有裂痕的布偶，被放回后台的木箱里。"],
}
var phase: int = 1
var pattern: int = 0
var arena: Vector2 = Vector2(960,2120)
var floor_y: float = 940
var attack: String = "command"
var attack_name: String = ""
var phase_title: String = "丝线操控"
var boss_title: String = "沃伊德"
var cuts: int = 0
var _windup_length: float = 1
var _target: Vector2
var _columns: Array = []
var _fences: Array[StaticBody2D] = []
var _phase_invulnerability: float = 0
var _ending_sent: bool = false
var echo: bool = false

func _ready() -> void:
	boss = true
	data = {"hp":int(spec.get("hp",760)),"height":210,"damage":12,"atlas":"void_idle","speed":0,"behavior":"boss"}
	arena = ExplorationCatalog.vec(spec.get("arena",[960,2120]))
	floor_y = float(spec.get("floor",spec["pos"][1]))
	state = "sleep"
	super._ready()
	_create_fences()
	# The keeper's perfect version skips the opening form and looks too clean.
	echo = bool(spec.get("echo",false))
	if echo:
		phase = 2
		phase_title = "完美版本"
		boss_title = str(spec.get("label",boss_title))
		modulate = Color(.86,.9,1)
		if session.switches.has("tower_hp_"+str(spec["id"])):
			health = clampi(int(session.switches["tower_hp_"+str(spec["id"])]),1,max_health)

func hand_position() -> Vector2:
	return global_position+Vector2(facing*34,-150)

func _create_fences() -> void:
	for x: float in [arena.x,arena.y]:
		var fence := StaticBody2D.new()
		fence.position = Vector2(x,floor_y-125)
		fence.collision_layer = 0
		fence.collision_mask = 0
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = Vector2(22,250)
		shape.shape = box
		fence.add_child(shape)
		get_parent().add_child.call_deferred(fence)
		_fences.append(fence)

func _set_fences(locked: bool) -> void:
	for fence: StaticBody2D in _fences:
		if is_instance_valid(fence):
			fence.set_deferred("collision_layer",1 if locked else 0)

func _boss_behavior(player: ExplorationPlayer, offset: Vector2, delta: float) -> void:
	_phase_invulnerability = maxf(0,_phase_invulnerability-delta)
	velocity.x = 0
	if player.cloth >= CLOTH_LIMIT:
		_defeat("doll")
		return
	if state=="sleep":
		if player.position.x>arena.x+40 and player.position.x<arena.y and absf(offset.y)<240:
			_wake()
		return
	if absf(offset.x)>6 and state!="windup":
		facing = signf(offset.x)
	if state=="intro" or state=="phase_break":
		if timer<=0:
			state = "recover"
			timer = .6
		return
	var next_phase: int = 3 if health<=max_health*.30 else 2 if health<=max_health*.65 else 1
	if next_phase>phase:
		_start_phase(next_phase)
		return
	if state=="windup":
		if timer<=0:
			_release(player)
	elif state=="active":
		if timer<=0:
			state = "recover"
			timer = _pace(1.25 if attack=="rain" else 1.0)
	elif timer<=0:
		_select_attack(player)

## Every cut thread and the final frenzy make him quicker.
func _pace(seconds: float) -> float:
	return seconds*(1.0-.07*cuts)*(.8 if phase==3 else 1.0)*(.9 if echo else 1.0)

func _wake() -> void:
	state = "intro"
	timer = 1.6
	_set_fences(true)
	_notice("沃伊德 · 你是不是想起来什么……")
	get_node("/root/AudioManager").play_bell()
	var xs: Array = [arena.x+110,arena.x+360,arena.y-330,arena.y-90]
	for i: int in range(xs.size()):
		var puppet := ExplorationVoidPuppet.new()
		puppet.spec = {"id":"void_puppet_"+str(i),"type":"puppet","pos":[xs[i],floor_y],"patrol":160}
		puppet.session = session
		puppet.controller = self
		var thread := ExplorationVoidThread.new()
		thread.puppet = puppet
		thread.controller = self
		puppet.thread = thread
		get_parent().add_child(puppet)
		get_parent().add_child(thread)

func _puppets() -> Array:
	var result: Array = []
	for node: Node in get_tree().get_nodes_in_group("void_owned"):
		if node is ExplorationVoidPuppet and not node.dead and node.controller==self:
			result.append(node)
	return result

func _select_attack(player: ExplorationPlayer) -> void:
	var sequence: Array = ["command","lash","command","lash"] if phase==1 else ["noose","command","lash","noose","lash"] if phase==2 else ["rain","noose","lash","rain","command","noose"]
	attack = str(sequence[pattern%sequence.size()])
	pattern += 1
	if attack=="command" and _puppets().is_empty():
		attack = "lash"
	attack_name = str({"command":"丝线操控 · 人偶会扑过来","lash":"丝线鞭打 · 跳过地上的红线","noose":"丝线绞杀 · 立刻离开圈内","rain":"暴走丝线 · 站到空隙里"}[attack])
	_windup_length = _pace(float({"command":.7,"lash":.85,"noose":1.25,"rain":1.05}[attack]))
	timer = _windup_length
	state = "windup"
	# The noose closes where Jerry stood when it was thrown, not where he runs to.
	_target = Vector2(clampf(player.global_position.x,arena.x+60,arena.y-60),floor_y)
	if attack=="rain":
		_columns.clear()
		var gap: int = pattern%6
		for i: int in range(6):
			if i!=gap:
				_columns.append(lerpf(arena.x+90,arena.y-90,float(i)/5))

func _release(player: ExplorationPlayer) -> void:
	state = "active"
	timer = .35
	get_node("/root/AudioManager").play_sfx("sfx_attack_swing")
	if attack=="command":
		for puppet: ExplorationVoidPuppet in _puppets():
			puppet.facing = signf(player.global_position.x-puppet.global_position.x)
			puppet.state = "windup"
			puppet.timer = .25
	elif attack=="lash":
		var lash := _hit(Vector2(640,44),Vector2(facing*340,-22),.3,12 if phase<3 else 15)
		lash.kind = "void_lash"
	elif attack=="noose":
		var neck: Vector2 = player.global_position+Vector2(0,-50)
		if neck.distance_to(_target+Vector2(0,-50))<=78 and player._invulnerability<=0:
			_defeat("broken_puppet")
	elif attack=="rain":
		for x: float in _columns:
			_hit(Vector2(58,330),Vector2(x-global_position.x,-165),.35,14)
	var demo: Node = get_tree().get_first_node_in_group("exploration_demo")
	if demo!=null and attack in ["lash","rain"]:
		demo.screen_shake(.12)

func _hit(size: Vector2, point: Vector2, length: float, damage_value: int) -> ExplorationHitArea:
	var hit := ExplorationHitArea.new()
	hit.source = self
	hit.target_layer = 8
	hit.damage = damage_value
	hit.dimensions = size
	hit.position = point
	hit.direction = Vector2(facing,0)
	hit.lifetime = length
	add_child(hit)
	return hit

func _start_phase(value: int) -> void:
	phase = value
	pattern = 0
	phase_title = "丝线绞杀" if phase==2 else "暴走丝线"
	state = "phase_break"
	timer = 1.5
	_phase_invulnerability = .7
	_clear_hits()
	_notice("第二阶段 · 丝线绞杀" if phase==2 else "第三阶段 · 暴走丝线")
	get_node("/root/AudioManager").play_bell()
	var demo: Node = get_tree().get_first_node_in_group("exploration_demo")
	if demo!=null:
		demo.screen_shake(.3)

func on_thread_cut() -> void:
	cuts += 1
	_notice("沃伊德发出尖叫 · 又一块身体变成了布料")
	get_node("/root/AudioManager").play_sfx("sfx_thread_cut")
	var demo: Node = get_tree().get_first_node_in_group("exploration_demo")
	if demo!=null:
		demo.screen_shake(.18)

func can_receive_hit() -> bool:
	return not dead and _phase_invulnerability<=0 and state!="intro"

func receive_hit(amount: int, _origin_value: Vector2, _kind: String = "slash") -> void:
	if not can_receive_hit():
		return
	if state=="sleep":
		_wake()
		return
	# Threads hold him together: each cut leaves him softer to the blade.
	health = maxi(0,health-maxi(1,roundi(amount*(.4+.15*cuts))))
	if echo:
		session.switches["tower_hp_"+str(spec["id"])] = health
	_flash = .11
	get_node("/root/AudioManager").play_sfx("sfx_hurt")
	if health<=0:
		_die()

func _defeat(id: String) -> void:
	if _ending_sent:
		return
	var demo: Node = get_tree().get_first_node_in_group("exploration_demo")
	if demo==null:
		return
	_ending_sent = true
	# Deferred: the room's bodies must not leave the physics space mid-step.
	demo.defeat.call_deferred(id,str(DEFEATS[id][0]),str(DEFEATS[id][1]))

func _clear_hits() -> void:
	for child: Node in get_children():
		if child is ExplorationHitArea:
			child.queue_free()

func _die() -> void:
	if dead:
		return
	dead = true
	state = "death"
	_clear_hits()
	_set_fences(false)
	if echo:
		session.switches[str(spec["id"])] = true
		session.switches.erase("tower_hp_"+str(spec["id"]))
		session.changed.emit()
		session.save()
	else:
		session.switches["defeated_void"] = true
		session.acquire("boss_void")
		session.save()
	get_node("/root/AudioManager").play_bell()
	var demo: Node = get_tree().get_first_node_in_group("exploration_demo")
	if demo!=null:
		demo.player.health = mini(100,demo.player.health+35)
		demo.screen_shake(.3)
		if echo:
			demo.hud.toast("完美的沃伊德散成了一堆红线")
		else:
			_claim_doll(demo)
	var tween := create_tween()
	tween.tween_property(self,"modulate:a",0,1.15)
	tween.tween_callback(queue_free)

## Story 1.1: the doll is recovered, the bell rings and Jerry comes to in front of the clock tower.
func _claim_doll(demo: Node) -> void:
	for object: ExplorationInteractable in demo.room.interactables:
		var item: String = str(object.spec.get("item",""))
		if item!="theater_seal" or object.is_finished():
			continue
		session.acquire(item)
		for grant: String in object.spec.get("grants",[]):
			session.acquire(grant)
		session.collected[str(object.spec.get("uid",item))] = true
		object.hide()
		session.save()
		demo.show_dialogue(str(object.spec.get("title","")),str(object.spec.get("text",""))+"\n\n钟声响起。眼前的一切开始闪烁、变黑——",[
			{"label":"……", "action":func(): demo.close_overlay(); demo.request_room("clock_exterior")}
		])
		demo.mode = "ending"
		return

func _notice(text: String) -> void:
	var demo: Node = get_tree().get_first_node_in_group("exploration_demo")
	if demo!=null:
		demo.hud.toast(text)

## On-screen height of each pose (art by Codex, Demo 9). Raised arms stand taller.
const POSE_HEIGHT := {"void_idle":210.0,"void_command":238.0,"void_lash":200.0,"void_frenzy":222.0}
var _pose_key: String = ""

func _pose_name() -> String:
	if state in ["windup","active"]:
		if attack=="lash":
			return "void_lash"
		if attack=="rain":
			return "void_frenzy"
		return "void_command"
	return "void_frenzy" if phase==3 else "void_idle"

func _visual_update() -> void:
	var key: String = _pose_name()
	if key!=_pose_key:
		_pose_key = key
		visual.texture = ExplorationArt.sprite(key)
		visual.scale = Vector2.ONE*float(POSE_HEIGHT[key])/visual.texture.get_height()
	visual.flip_h = facing>0
	visual.position = Vector2(ExplorationArt.foot_shift(key,visual.texture,visual.scale.x,visual.flip_h),-float(POSE_HEIGHT[key])*.5+sin(_clock*1.6)*4)
	visual.modulate = Color(2,1.4,1.4) if _flash>0 else Color(1.25,.78,.78) if state=="windup" else Color.WHITE.lerp(Color("e6c1b1"),cuts*.15)
	queue_redraw()

func _draw() -> void:
	if dead or state=="sleep":
		return
	var red := Color("d8394a")
	var hand: Vector2 = hand_position()-global_position
	for puppet: ExplorationVoidPuppet in _puppets():
		if is_instance_valid(puppet.thread):
			var knot: Vector2 = puppet.thread.global_position-global_position
			ExplorationArt.strand(self,"red_thread",hand,knot,3,Color(1,1,1,.85))
			ExplorationArt.strand(self,"red_thread",knot,puppet.global_position+Vector2(0,-70)-global_position,3,Color(1,1,1,.85))
	# Stitched cloth patches spread down his right side as threads are cut (overlay on the sprite).
	for i: int in range(cuts):
		var patch := Vector2(-facing*(10+i*6),-178+i*34)
		draw_rect(Rect2(patch-Vector2(11,12),Vector2(22,24)),Color("cdb39a",.88))
		for s: int in range(3):
			draw_line(patch+Vector2(-11,-8+s*8),patch+Vector2(-5,-8+s*8),Color("7a2f3a"),1.5,true)
	if state in ["windup","active"]:
		var progress: float = clampf(1-timer/_windup_length,0,1)
		if attack=="lash":
			ExplorationArt.strand(self,"red_thread",Vector2(0,-6),Vector2(facing*660,-6),3+progress*3,Color(1,1,1,.4+progress*.5))
		elif attack=="noose":
			var ring: Vector2 = _target+Vector2(0,-50)-global_position
			ExplorationArt.strand(self,"red_thread",hand,ring,3,Color(1,1,1,.7))
			ExplorationArt.thread_ring(self,ring,78+(1-progress)*60,3+progress*2,Color(1,1,1,.45+progress*.5))
			ExplorationArt.thread_ring(self,ring,78,2,Color(1,1,1,.35))
		elif attack=="rain":
			for x: float in _columns:
				var local_x: float = x-global_position.x
				ExplorationArt.strand(self,"red_thread",Vector2(local_x,-330),Vector2(local_x,0),2+progress*4,Color(1,1,1,.25+progress*.55))
		elif attack=="command":
			draw_arc(hand,14+progress*16,0,TAU,24,Color(red,.8),2,true)
	if state=="phase_break":
		var radius: float = (1.5-timer)*150
		draw_arc(Vector2(0,-110),radius,0,TAU,60,Color(red,maxf(0,timer/1.5)),4,true)
	# Red curtains close the stage until he falls.
	for edge: float in [arena.x,arena.y]:
		var local_x: float = edge-position.x
		for i: int in range(4):
			ExplorationArt.strand(self,"red_thread",Vector2(local_x+i*4-6,0),Vector2(local_x+i*4-6,-245+sin(_clock*3+i)*10),3)
