class_name ExplorationBoss
extends ExplorationEnemy
## Morris: three forms, directional anticipation, committed attacks, recovery windows.

var phase: int = 1
var pattern: int = 0
var arena: Vector2 = Vector2(2350,3780)
var attack: String = "fan"
var attack_name: String = ""
var phase_title: String = "蜡匠的执念"
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

func _ready() -> void:
	boss = true
	data = {"hp":int(spec.get("hp",840)),"height":235,"damage":20,"atlas":"morris","speed":55,"behavior":"boss"}
	arena = ExplorationCatalog.vec(spec.get("arena",[2350,3780]))
	_floor = float(spec.get("floor",spec["pos"][1]))
	state = "sleep"
	super._ready()
	_create_fences()

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
	velocity.x = 0
	if state=="sleep":
		if player.position.x>arena.x+40 and player.position.x<arena.y and absf(offset.y)<220:
			state = "intro"
			timer = 1.4
			_set_fences(true)
			_notice("莫里斯 · 别碰那些脸")
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
	attack_name = str({"fan":"烛泪散射 · 留意弹道间隙","cleave":"蜡刃横扫 · 跳起或绕后","slam":"熔蜡地刺 · 离开地面标记","rush":"熔蜡突进 · 跳跃越过","copies":"第 247 张脸 · 真身眼中有火","rain":"坠落烛雨 · 留在预警间隙"}[attack])
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
	hit.kind = "wax_claw"
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
	phase_title = "蜡壳裂开" if phase==2 else "熔炉中的真身"
	state = "phase_break"
	timer = 1.55
	_phase_invulnerability = .7
	_clear_owned()
	velocity.x = 0
	_stagger = 0
	_notice("第二阶段 · 蜡壳裂开" if phase==2 else "第三阶段 · 熔炉中的真身")
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
		state = "intro"
		timer = 1.0
		_set_fences(true)
	health = maxi(0,health-amount)
	_flash = .11
	_stagger += amount
	# Heavy recovery hits can stagger; a light hit cannot repeatedly cancel a skill.
	if _stagger>=125 and state=="recover":
		timer = maxf(timer,.62)
		_stagger = 0
		_notice("蜡壳失衡 · 乘机攻击")
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
	session.switches["defeated_morris"] = true
	session.acquire("boss_morris")
	session.save()
	var demo: Node = get_tree().get_first_node_in_group("exploration_demo")
	if demo!=null:
		demo.player.health = mini(100,demo.player.health+35)
		demo.screen_shake(.3)
		demo.hud.toast("蜡壳崩解 · 镜室门锁已松开")
	get_node("/root/AudioManager").play_bell()
	var tween := create_tween()
	tween.tween_property(visual,"scale:y",visual.scale.y*.3,.7)
	tween.parallel().tween_property(self,"modulate:a",0,1.15)
	tween.tween_callback(queue_free)

func _notice(text: String) -> void:
	var demo: Node = get_tree().get_first_node_in_group("exploration_demo")
	if demo!=null:
		demo.hud.toast(text)

func _pose(atlas_name: String, cell: int) -> Texture2D:
	var key: String = atlas_name+str(cell)
	if not _pose_cache.has(key):
		_pose_cache[key] = ExplorationArt.sprite(atlas_name,cell)
	return _pose_cache[key]

func _visual_update() -> void:
	var attacking: bool = state in ["active","windup"]
	var atlas_name: String = "morris_actions_v2"
	var cell: int = 0 if state=="windup" else 1 if attack in ["cleave","rush"] else 3 if attack=="slam" else 2
	if phase>=2:
		atlas_name = "morris_forms_v2"
		cell = (0 if phase==2 else 2)+(1 if state=="active" else 0)
	var idle: bool = state=="sleep" or (phase==1 and not attacking)
	var key: String = "morris" if idle else atlas_name+str(cell)
	if key!=_pose_key:
		_pose_key = key
		visual.texture = ExplorationArt.sprite("morris") if idle else _pose(atlas_name,cell)
		var reference: Texture2D = ExplorationArt.sprite("morris") if idle else _pose(atlas_name,2 if phase==1 or phase==3 else 0)
		_base_scale = Vector2.ONE*235.0/reference.get_height()
	visual.flip_h = facing>0
	visual.position = Vector2(0,-visual.texture.get_height()*_base_scale.y*.5)
	var lean: float = -.1 if state=="windup" else .13 if state=="active" else 0
	visual.rotation = lean*facing+sin(_clock*2)*.015
	visual.scale = _base_scale*Vector2(1.06,.96) if state=="windup" else _base_scale
	visual.modulate = Color(2,1.5,1) if _flash>0 else Color(1.15,.92,.8) if phase==3 else Color.WHITE
	if state=="phase_break":
		visual.position.x = sin(_clock*60)*3
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
