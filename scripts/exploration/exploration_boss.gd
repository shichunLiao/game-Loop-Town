class_name ExplorationBoss
extends ExplorationEnemy
## May Morley: three forms, directional anticipation, committed attacks, recovery windows.
## Art (Codex, Demo 9): may_idle / may_windup / may_slash / may_summon / may_brush / may_brush_strike.

var phase: int = 1
var pattern: int = 0
var arena: Vector2 = Vector2(2350,3780)
var attack: String = "fan"
var attack_name: String = ""
var phase_title: String = "恩师的面孔"
var boss_title: String = "梅·莫里"
var echo: bool = false
var _floor: float = 1140
var _locked_facing: float = -1
var _target_x: float = 0
var _elapsed_active: float = 0
var _active_length: float = 0
var _windup_length: float = 1
var _fired: bool = false
var _second_fired: bool = false
var _stagger: int = 0
var _phase_invulnerability: float = 0
var _fences: Array[StaticBody2D] = []
var _pose_cache: Dictionary = {}
var _pose_key: String = ""
var _base_scale: Vector2 = Vector2.ONE
var _rush_hit: ExplorationHitArea
var _ending_sent: bool = false
var _intro_done: bool = false
var _covers: Array = []
const DEFEATS := {
	"torn": ["结局 · 被撕碎", "美工刀切开你的时候，身体像纸一样裂开、飘落。\n画框里只剩下一地碎屑。\n钟声响起——你又站在美术馆门口。"],
	"sculpted": ["结局 · 雕塑", "纯白的替身把你按进石膏里。\n凝固的瞬间，你看见自己也成了廊上的一座未完成雕像。\n钟声响起——你又站在美术馆门口。"],
	"painted": ["结局 · 入画", "画笔在虚空里划开一道口子，把你拖进画布。\n颜料漫过脚踝、膝盖，你成了墙上的一笔。\n钟声响起——你又站在美术馆门口。"],
}

func _ready() -> void:
	boss = true
	add_to_group("may_boss")
	data = {"hp":int(spec.get("hp",840)),"height":235,"damage":20,"atlas":"may_idle","speed":55,"behavior":"boss"}
	arena = ExplorationCatalog.vec(spec.get("arena",[2350,3780]))
	_floor = float(spec.get("floor",spec["pos"][1]))
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

func _create_fences() -> void:
	for x: float in [arena.x,arena.y]:
		var fence := StaticBody2D.new()
		fence.position = Vector2(x,_floor-125)
		fence.collision_layer = 0
		fence.collision_mask = 0
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = Vector2(22,250)
		shape.shape = box
		fence.add_child(shape)
		get_parent().add_child.call_deferred(fence)
		_fences.append(fence)

func _boss_behavior(player: ExplorationPlayer, offset: Vector2, delta: float) -> void:
	_phase_invulnerability = maxf(0,_phase_invulnerability-delta)
	_watch_player(player)
	velocity.x = 0
	if state=="sleep":
		if player.position.x>arena.x+40 and player.position.x<arena.y and absf(offset.y)<220:
			_begin_intro()
			_notice("梅·莫里 · 别碰那些画")
		return
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
		# Facing and aim are committed before the strike: the player can dodge behind.
		if timer<=0:
			state = "active"
			_active_length = .55 if attack=="rush" else .7 if attack=="rain" else .32
			timer = _active_length
			_elapsed_active = 0
			_release_attack(player)
	elif state=="active":
		_elapsed_active += delta
		if attack=="rush":
			velocity.x = _locked_facing*(490 if phase==2 else 570)
		if phase==3 and attack=="fan" and not _second_fired and _elapsed_active>.17:
			_second_fired = true
			_fan(player,5,.11)
		if timer<=0:
			state = "recover"
			timer = 1.15 if attack in ["slam","rain"] else .95 if phase==1 else .82
			if is_instance_valid(_rush_hit):
				_rush_hit.queue_free()
	elif timer<=0:
		_select_attack(player)
	position.x = clampf(position.x,arena.x+85,arena.y-85)

func _select_attack(player: ExplorationPlayer) -> void:
	var sequence: Array = ["fan","cleave","slam"] if phase==1 else ["rush","fan","copies","slam","cleave"] if phase==2 else ["rain","rush","fan","slam","copies","cleave"]
	attack = str(sequence[pattern%sequence.size()])
	pattern += 1
	var distance: float = absf(player.position.x-position.x)
	if attack=="cleave" and distance>285:
		attack = "fan"
	_locked_facing = signf(player.position.x-position.x) if distance>8 else facing
	facing = _locked_facing
	_target_x = clampf(player.position.x,arena.x+115,arena.y-115)
	attack_name = str({"fan":"颜料散射 · 留意弹道间隙","cleave":"美工刀横扫 · 跳起或绕后","slam":"石膏地刺 · 离开地面标记","rush":"画笔突进 · 跳跃越过","copies":"雕像替身 · 认出真身","rain":"坠落颜料 · 留在预警间隙"}[attack])
	_windup_length = 1.05 if attack in ["slam","rain","copies"] else .85 if phase==1 else .74
	timer = _windup_length
	state = "windup"
	_second_fired = false
	if attack=="slam":
		var xs: Array = [_target_x] if phase==1 else [_target_x-185,_target_x+185] if phase==2 else [_target_x-260,_target_x,_target_x+260]
		for x: float in xs:
			_effect(Vector2(clampf(x,arena.x+80,arena.y-80),_floor),"pillar",_windup_length,.5,85,155 if phase<3 else 195)
	elif attack=="rain":
		var gap: int = pattern%5
		for i: int in range(5):
			if i==gap:
				continue
			var x: float = lerpf(arena.x+140,arena.y-140,float(i)/4)
			_effect(Vector2(x,_floor),"rain",_windup_length+.2+float(i)*.12,.65,78,350)

func _release_attack(player: ExplorationPlayer) -> void:
	if attack=="copies":
		get_node("/root/AudioManager").play_sfx("sfx_statue_crack")
	elif attack in ["cleave","rush","fan","slam","rain"]:
		get_node("/root/AudioManager").play_sfx("sfx_brush_slash")
	else:
		get_node("/root/AudioManager").play_sfx("sfx_attack_swing")
	if attack=="fan":
		_fan(player,3 if phase==1 else 5 if phase==2 else 7,.19 if phase<3 else .16)
	elif attack=="cleave":
		_melee(Vector2(205,118),Vector2(_locked_facing*100,-67),.22,24 if phase<3 else 29)
	elif attack=="rush":
		_rush_hit = _melee(Vector2(120,125),Vector2(_locked_facing*50,-68),.55,24 if phase==2 else 28)
	elif attack=="slam":
		if phase>=2:
			_effect(Vector2(position.x,_floor),"pool",.05,2.6,145,21)
	elif attack=="copies":
		_summon_copies()
	var demo: Node = get_tree().get_first_node_in_group("exploration_demo")
	if demo!=null and attack in ["slam","rush","rain"]:
		demo.screen_shake(.14)

func _melee(size: Vector2, point: Vector2, length: float, damage_value: int) -> ExplorationHitArea:
	var hit := ExplorationHitArea.new()
	hit.source = self
	hit.target_layer = 8
	hit.damage = damage_value
	hit.dimensions = size
	hit.position = point
	hit.direction = Vector2(_locked_facing,0)
	hit.lifetime = length
	hit.kind = "may_brush" if phase >= 3 else "may_slash"
	add_child(hit)
	return hit

func _fan(player: ExplorationPlayer, count: int, spacing: float) -> void:
	var origin := Vector2(position.x+_locked_facing*60,position.y-135)
	var aim: Vector2 = (player.position+Vector2(0,-40)-origin).normalized()
	# Once casting begins the fan cannot turn through the sculptor's back.
	if aim.x*_locked_facing<.1:
		aim = Vector2(_locked_facing,-.1).normalized()
	for i: int in range(count):
		var projectile := ExplorationProjectile.new()
		projectile.position = origin
		projectile.velocity = aim.rotated((i-(count-1)*.5)*spacing)*(315+phase*25)
		projectile.damage = 16+phase*2
		projectile.session = session
		projectile.tint = Color("f9bc68") if phase<3 else Color("f28b58")
		get_parent().add_child(projectile)
		projectile.add_to_group("morris_owned")
		projectile.set_meta("boss_id",get_instance_id())

func _effect(point: Vector2, style_value: String, delay: float, length: float, w: float, h: float) -> void:
	var effect := ExplorationBossAttack.new()
	effect.position = point
	effect.owner_boss = self
	effect.session = session
	effect.style = style_value
	effect.warning = delay
	effect.duration = length
	effect.width = w
	effect.height = h
	effect.damage = 18+phase*3 if style_value!="pool" else 10
	effect.phase = phase
	get_parent().add_child(effect)

func _summon_copies() -> void:
	var alive: int = 0
	for node: Node in get_tree().get_nodes_in_group("morris_owned"):
		if node is ExplorationMorrisDouble and not node.dead:
			alive += 1
	for i: int in range(maxi(0,2-alive)):
		var copy := ExplorationMorrisDouble.new()
		copy.spec = {"id":"morris_copy_"+str(pattern)+"_"+str(i),"type":"wax_walker","pos":[clampf(position.x+(-220 if i==0 else 220),arena.x+105,arena.y-105),_floor],"patrol":170}
		copy.session = session
		copy.summoner = self
		get_parent().add_child(copy)

func _start_phase(value: int) -> void:
	phase = value
	pattern = 0
	phase_title = "雕像替身" if phase==2 else "入画"
	state = "phase_break"
	timer = 1.55
	_phase_invulnerability = .7
	_clear_owned()
	velocity.x = 0
	_stagger = 0
	_notice("第二阶段 · 雕像替身" if phase==2 else "第三阶段 · 入画")
	get_node("/root/AudioManager").play_bell()
	var demo: Node = get_tree().get_first_node_in_group("exploration_demo")
	if demo!=null:
		demo.screen_shake(.3)
		demo.player.energy = minf(100,demo.player.energy+20)

func can_receive_hit() -> bool:
	return not dead and _phase_invulnerability<=0 and state!="intro"

func receive_hit(amount: int, _origin_value: Vector2, _kind: String = "slash") -> void:
	if not can_receive_hit():
		return
	if state=="sleep":
		_begin_intro()
		return
	health = maxi(0,health-amount)
	_flash = .11
	_stagger += amount
	# Heavy recovery hits can stagger; a light hit cannot repeatedly cancel a skill.
	if _stagger>=125 and state=="recover":
		timer = maxf(timer,.62)
		_stagger = 0
		_notice("画框失衡 · 乘机攻击")
	get_node("/root/AudioManager").play_sfx("sfx_hurt")
	if health<=0:
		_die()

func _set_fences(locked: bool) -> void:
	for fence: StaticBody2D in _fences:
		if is_instance_valid(fence):
			fence.set_deferred("collision_layer",1 if locked else 0)
	queue_redraw()

func _clear_owned() -> void:
	for node: Node in get_tree().get_nodes_in_group("morris_owned"):
		if int(node.get_meta("boss_id",-1))==get_instance_id():
			node.queue_free()
	for child: Node in get_children():
		if child is ExplorationHitArea:
			child.queue_free()

func _die() -> void:
	if dead:
		return
	dead = true
	state = "death"
	_clear_owned()
	_set_fences(false)
	if echo:
		session.switches[str(spec["id"])] = true
		session.changed.emit()
	else:
		session.switches["defeated_morris"] = true
		session.acquire("boss_morris")
		session.save()
	var demo: Node = get_tree().get_first_node_in_group("exploration_demo")
	if demo!=null:
		demo.player.health = mini(100,demo.player.health+35)
		demo.screen_shake(.3)
		if echo:
			demo.hud.toast("完美的梅·莫里碎成了石膏")
		else:
			_victory_cutscene(demo)
	get_node("/root/AudioManager").play_bell()
	var tween := create_tween()
	tween.tween_property(visual,"scale:y",visual.scale.y*.3,.7)
	tween.parallel().tween_property(self,"modulate:a",0,1.15)
	tween.tween_callback(queue_free)

func _notice(text: String) -> void:
	var demo: Node = get_tree().get_first_node_in_group("exploration_demo")
	if demo!=null:
		demo.hud.toast(text)

## On-screen height of each pose. Raised arms and the frenzy form stand taller than the idle teacher.
const POSE_HEIGHT := {"may_idle":235.0,"may_windup":262.0,"may_slash":228.0,"may_summon":250.0,"may_brush":245.0,"may_brush_strike":232.0}

func _pose(pose: String) -> Texture2D:
	if not _pose_cache.has(pose):
		_pose_cache[pose] = ExplorationArt.sprite(pose)
	return _pose_cache[pose]

## Phase 1 is the teacher with the box cutter, phase 2 adds the statue doubles,
## phase 3 swaps the cutter for the brush that cuts into the painting.
func _pose_name() -> String:
	var attacking: bool = state in ["active","windup"]
	if state=="sleep" or not attacking:
		return "may_brush" if phase==3 else "may_idle"
	if attack=="copies":
		return "may_brush" if phase==3 else "may_summon"
	if phase==3:
		return "may_brush" if state=="windup" else "may_brush_strike"
	if state=="windup":
		return "may_windup"
	return "may_summon" if attack=="rain" else "may_slash"

func _visual_update() -> void:
	var key: String = _pose_name()
	if key!=_pose_key:
		_pose_key = key
		visual.texture = _pose(key)
		_base_scale = Vector2.ONE*float(POSE_HEIGHT.get(key,235.0))/visual.texture.get_height()
	visual.flip_h = facing>0
	visual.position = Vector2(ExplorationArt.foot_shift(_pose_key,visual.texture,_base_scale.x,visual.flip_h),-visual.texture.get_height()*_base_scale.y*.5)
	var lean: float = -.1 if state=="windup" else .13 if state=="active" else 0
	visual.rotation = lean*facing+sin(_clock*2)*.015
	visual.scale = _base_scale*Vector2(1.06,.96) if state=="windup" else _base_scale
	visual.modulate = Color(2,1.5,1) if _flash>0 else Color(1.15,.92,.8) if phase==3 else Color.WHITE
	if state=="phase_break":
		visual.position.x += sin(_clock*60)*3
	queue_redraw()

func _draw() -> void:
	if state=="sleep":
		return
	var accent := Color("e8b36b") if phase<3 else Color("f58a5b")
	for i: int in range(phase+1):
		draw_arc(Vector2(0,-105),70+i*14,_clock*.3+i,_clock*.3+i+PI*1.25,32,Color(accent,.12),2,true)
	if state=="windup":
		var progress: float = clampf(1-timer/_windup_length,0,1)
		draw_arc(Vector2(_locked_facing*60,-133),24+progress*18,-PI,PI,32,accent,2+progress*2,true)
		if attack in ["rush","cleave"]:
			var reach: float = 400 if attack=="rush" else 205
			draw_line(Vector2(0,-4),Vector2(_locked_facing*reach,-4),Color(accent,.5),4,true)
			for i: int in range(1,5):
				var x: float = _locked_facing*reach*i/5
				draw_line(Vector2(x,-4),Vector2(x-_locked_facing*12,-16),accent,2,true)
	if state=="phase_break":
		var radius: float = (1.55-timer)*150
		draw_arc(Vector2(0,-95),radius,0,TAU,60,Color(accent,maxf(0,timer/1.55)),4,true)
		for i: int in range(10):
			var ray := Vector2.from_angle(i*TAU/10)
			draw_line(Vector2(0,-95)+ray*radius*.5,Vector2(0,-95)+ray*radius,accent,3,true)
	# The arena uses wax curtains; they disappear when the encounter is won.
	if not dead:
		for edge: float in [arena.x,arena.y]:
			var local_x: float = edge-position.x
			for i: int in range(4):
				draw_line(Vector2(local_x+i*4-6,0),Vector2(local_x+i*4-6,-245+sin(_clock*3+i)*10),Color("89613c"),3,true)

func _begin_intro() -> void:
	state = "intro"
	timer = 2.4
	_set_fences(true)
	_spawn_covers()
	if _intro_done or echo:
		return
	_intro_done = true
	var demo: Node = get_tree().get_first_node_in_group("exploration_demo")
	if demo == null:
		return
	demo.show_dialogue("梅·莫里", "杰利……你脸上的神情，和玲失踪之后一样。\n他是不是疯了？——不，是这座美术馆在疯。\n画里的人在笑。画框在裂。", [
		{"label":"……准备战斗", "action": demo.close_overlay}
	])
	demo.mode = "ending"

func _spawn_covers() -> void:
	if echo or not _covers.is_empty():
		return
	var xs: Array = [arena.x + 420.0, (arena.x + arena.y) * 0.5, arena.y - 420.0]
	for x in xs:
		var cover := ExplorationPushCover.new()
		cover.position = Vector2(x, _floor)
		cover.floor_y = _floor
		cover.add_to_group("morris_owned")
		cover.set_meta("boss_id", get_instance_id())
		get_parent().add_child(cover)
		_covers.append(cover)

func _watch_player(player: ExplorationPlayer) -> void:
	if echo or _ending_sent or dead or state in ["sleep", "death"]:
		return
	if not is_instance_valid(player) or player.health > 0:
		return
	var kind: String = player.last_may_kind
	if kind == "statue" or player.plaster >= 3:
		_defeat("sculpted")
	elif kind == "may_brush" or phase >= 3 or player.paint >= 3:
		_defeat("painted")
	else:
		_defeat("torn")

func _defeat(id: String) -> void:
	if _ending_sent:
		return
	var demo: Node = get_tree().get_first_node_in_group("exploration_demo")
	if demo == null or not DEFEATS.has(id):
		return
	_ending_sent = true
	demo.defeat.call_deferred(id, str(DEFEATS[id][0]), str(DEFEATS[id][1]))

func _victory_cutscene(demo: Node) -> void:
	demo.hud.toast("梅·莫里消散 · 镜室门锁已松开")
	demo.show_dialogue("画室回忆", "钟声响起。画面闪烁。\n你看见美术室里两个孩子并排画画：文静的你，活泼的玲。\n梅的呼喊把你拉回现实——还是刚才说话的场景。\n他记得：玲失踪那天下午，来要了两张丰收祭演出的海报。\n剧院。线索指向剧院。", [
		{"label":"前往剧院", "action": demo.close_overlay}
	])
	demo.mode = "ending"
