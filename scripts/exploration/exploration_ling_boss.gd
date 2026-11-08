class_name ExplorationLingBoss
extends ExplorationEnemy
## Ling at the bottom of the well: a body of mud and thorned vine that fills half the chamber.
## Mud rises without pause, vines lash from every side, hands take Jerry by the ankles and her
## voice turns left and right around. Cutting a glowing knot makes the mud fall back and bares
## her body for a few seconds; only then can she be hurt.

const EXPOSE_TIME: float = 5.0
const RECEDE: float = 170.0
const DROWN_DEPTH: float = 88.0
const DROWN_TIME: float = 1.5
const HOLD_TIME: float = 2.6
const GRIP: int = 6
const RISE: Array[float] = [0.0,10.0,13.0,16.0]
const WRAPPED: String = "藤蔓裹身 · 砍断发光的藤结"
const BARED: String = "藤蔓松开了 · 攻击她的身体"
const VOICES: Array[String] = ["「杰利……你在哪里……」","「为什么不说话？」","童谣声从四面八方传来","哭声盖过了一切"]

var phase: int = 1
var pattern: int = 0
var arena: Vector2
var floor_y: float
var mud_y: float
var dark: float = 0
var attack: String = "lash"
var attack_name: String = ""
var phase_title: String = WRAPPED
var boss_title: String = "玲"
var _top: float = 2150
var _rise: float = 0
var _collapse: float = 0
var _wrap: float = 1
var _recede: float = 0
var _drown: float = 0
var _held: float = 0
var _gripped: bool = false
var _dragged: bool = false
var _warned: float = -9
var _windup_length: float = 1
var _knot: ExplorationLingKnot
var _knot_wait: float = 0
var _knot_index: int = 0
var _lash_count: int = 0
var _cage: Array[StaticBody2D] = []
var _strands: Array[PackedVector2Array] = []
var _thorns: PackedVector2Array = PackedVector2Array()

func _ready() -> void:
	boss = true
	data = {"hp":int(spec.get("hp",1800)),"height":580,"damage":12,"atlas":"hero","speed":0,"behavior":"boss"}
	arena = ExplorationCatalog.vec(spec.get("arena",[215,1660]))
	floor_y = float(spec.get("floor",spec["pos"][1]))
	_top = float(spec.get("top",2150))
	mud_y = floor_y+14
	state = "sleep"
	timer = .9
	super._ready()
	visual.hide()
	z_index = -2
	var hurtbox: Area2D = get_node("Hurtbox") as Area2D
	hurtbox.position = Vector2(0,-290)
	((hurtbox.get_child(0) as CollisionShape2D).shape as RectangleShape2D).size = Vector2(420,560)
	_create_cage()
	_grow_thicket()
	var mud := ExplorationLingMud.new()
	mud.boss = self
	add_child(mud)

func _create_cage() -> void:
	var height: float = floor_y-_top
	for rect: Rect2 in [Rect2(arena.x,_top+height*.5,22,height),Rect2(arena.y,_top+height*.5,22,height),Rect2((arena.x+arena.y)*.5,_top,arena.y-arena.x,20)]:
		var wall := StaticBody2D.new()
		wall.position = rect.position
		wall.collision_layer = 0
		wall.collision_mask = 0
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = rect.size
		shape.shape = box
		wall.add_child(shape)
		get_parent().add_child.call_deferred(wall)
		_cage.append(wall)

func _set_cage(locked: bool) -> void:
	for wall: StaticBody2D in _cage:
		if is_instance_valid(wall):
			wall.set_deferred("collision_layer",1 if locked else 0)

## Thorned vines on every side of the chamber, fixed so they do not crawl between frames.
func _grow_thicket() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2840
	var roots: Array = []
	for i: int in range(9):
		var y: float = lerpf(_top+30,floor_y-30,float(i)/8)
		roots.append([Vector2(arena.x,y),Vector2(1,rng.randf_range(-.5,.5))])
		roots.append([Vector2(arena.y,y),Vector2(-1,rng.randf_range(-.5,.5))])
	for i: int in range(16):
		roots.append([Vector2(lerpf(arena.x,arena.y,float(i)/15),_top),Vector2(rng.randf_range(-.4,.4),1)])
	for root: Array in roots:
		var point: Vector2 = root[0]-position
		var heading: Vector2 = (root[1] as Vector2).normalized()
		var strand := PackedVector2Array([point])
		for s: int in range(rng.randi_range(4,8)):
			heading = heading.rotated(rng.randf_range(-.5,.5))
			point += heading*rng.randf_range(24,40)
			strand.append(point)
			var thorn: Vector2 = heading.orthogonal()*(10 if s%2==0 else -10)
			_thorns.append(point)
			_thorns.append(point+thorn+heading*6)
		_strands.append(strand)

func _boss_behavior(player: ExplorationPlayer, _offset: Vector2, delta: float) -> void:
	velocity.x = 0
	dark = maxf(0,dark-delta)
	if state=="sleep":
		if timer<=0:
			_wake()
		return
	_rise = minf(1,_rise+delta/2.8)
	if state=="intro":
		if timer<=0:
			state = "recover"
			timer = .8
		return
	_flow_mud(delta)
	_sink_or_struggle(player,delta)
	_tend_knot(delta)
	var next_phase: int = 3 if health<=max_health*.30 else 2 if health<=max_health*.65 else 1
	if next_phase>phase:
		_start_phase(next_phase)
		return
	if state=="phase_break":
		if timer<=0:
			state = "recover"
			timer = .8
		return
	if state=="exposed":
		_wrap = move_toward(_wrap,0,delta*3)
		if timer<=0:
			_cover()
		return
	_wrap = move_toward(_wrap,1,delta*2)
	if state=="windup":
		if timer<=0:
			_release(player)
	elif state=="active":
		if timer<=0:
			state = "recover"
			timer = _pace(1.6)
	elif timer<=0:
		_select_attack(player)

func _wake() -> void:
	state = "intro"
	timer = 3.2
	_set_cage(true)
	session.save_at("well_interior",ExplorationCatalog.vec(spec.get("start",[700,2837])))
	_notice("污泥从墙壁和地里汇集起来。双马尾，白衬衫，蓝裙子。只是没有脸。")
	get_node("/root/AudioManager").play_sfx("sfx_boss_roar")
	_shake(.4)

func _pace(seconds: float) -> float:
	return seconds*(1.0 if phase==1 else .88 if phase==2 else .75)

func _flow_mud(delta: float) -> void:
	if _recede>0:
		var step: float = minf(_recede,110*delta)
		_recede -= step
		mud_y = minf(floor_y+14,mud_y+step)
	elif state!="exposed" and state!="phase_break":
		mud_y -= RISE[phase]*delta

## Deep mud slows Jerry and then takes him; so do the hands if he does not kick free in time.
func _sink_or_struggle(player: ExplorationPlayer, delta: float) -> void:
	var depth: float = player.global_position.y-mud_y
	player.mired = clampf(depth/DROWN_DEPTH,0,1)
	_drown = _drown+delta if depth>=DROWN_DEPTH else maxf(0,_drown-delta*2)
	if player.grip>0:
		_gripped = true
		_held += delta
		if _held>=HOLD_TIME:
			_drag_under(player)
	elif _gripped:
		_gripped = false
		player._invulnerability = maxf(player._invulnerability,.9)
		get_tree().call_group("ling_hands","let_go")
	if _drown>=DROWN_TIME:
		_drag_under(player)

func _drag_under(player: ExplorationPlayer) -> void:
	if _dragged:
		return
	_dragged = true
	_notice("泥浆没过头顶。无数只手把你拖了下去。")
	player.grip = 0
	player._invulnerability = 0
	player.take_damage.call_deferred(999)

func hold_ratio() -> float:
	return clampf(_held/HOLD_TIME,0,1)

func try_grab(x: float) -> bool:
	var player: ExplorationPlayer = get_tree().get_first_node_in_group("exploration_player") as ExplorationPlayer
	if player==null or player.grip>0 or player._invulnerability>0 or not player.is_on_floor():
		return false
	if absf(player.global_position.x-x)>60 or player.global_position.y<minf(mud_y,floor_y)-24:
		return false
	player.grip = GRIP
	_held = 0
	_gripped = true
	get_node("/root/AudioManager").play_sfx("sfx_hurt")
	return true

func _tend_knot(delta: float) -> void:
	if is_instance_valid(_knot):
		# A knot the mud has swallowed cannot be cut; another grows higher up.
		if _knot.global_position.y>mud_y-10:
			_knot.queue_free()
			_knot = null
		return
	if state=="exposed" or state=="phase_break":
		return
	_knot_wait -= delta
	if _knot_wait>0:
		return
	var spots: Array = spec.get("knots",[])
	for i: int in range(spots.size()):
		var spot: Vector2 = ExplorationCatalog.vec(spots[(_knot_index+i)%spots.size()])
		if spot.y<mud_y-50:
			_knot_index += i+1
			_knot = ExplorationLingKnot.new()
			_knot.boss = self
			_knot.position = spot
			get_parent().add_child(_knot)
			return

func on_knot_cut() -> void:
	_knot = null
	_knot_wait = .6
	_recede += RECEDE
	state = "exposed"
	timer = EXPOSE_TIME
	phase_title = BARED
	_notice("藤结断了 · 泥浆退去，藤蔓松开了她")
	get_node("/root/AudioManager").play_sfx("sfx_doll_snap")
	_shake(.2)

func _cover() -> void:
	state = "recover"
	timer = .9
	phase_title = WRAPPED

func _near_mud(player: ExplorationPlayer) -> bool:
	return player.global_position.y>=minf(mud_y,floor_y)-60

func _select_attack(player: ExplorationPlayer) -> void:
	var sequence: Array = ["lash","hands","lash","hands"] if phase==1 else ["voice","hands","lash","lash","hands"] if phase==2 else ["hands","lash","voice","lash","hands","lash"]
	attack = str(sequence[pattern%sequence.size()])
	pattern += 1
	# Hands only reach out of the mud, and a second song would add nothing to the first.
	if attack=="hands" and not _near_mud(player):
		attack = "lash"
	if attack=="voice" and player.confused>0:
		attack = "lash"
	attack_name = str({"lash":"藤蔓抽打 · 看清红线，躲开","hands":"手抓脚踝 · 离开泥面","voice":"声音干扰 · 左右方向即将颠倒"}[attack])
	_windup_length = _pace(float({"lash":.45,"hands":.55,"voice":1.1}[attack]))
	timer = _windup_length
	state = "windup"

func _release(player: ExplorationPlayer) -> void:
	state = "active"
	timer = .4
	if attack=="lash":
		for i: int in range(phase):
			_lash(player,_lash_count)
			_lash_count += 1
	elif attack=="hands":
		for offset: float in [-130.0,0.0,130.0]:
			var hand := ExplorationLingHand.new()
			hand.boss = self
			hand.session = session
			hand.position = Vector2(clampf(player.global_position.x+offset,arena.x+40,arena.y-40),minf(mud_y,floor_y))
			get_parent().add_child(hand)
	elif attack=="voice":
		player.confused = 2.0
		dark = 3.2
		_notice(VOICES[pattern%VOICES.size()])
		get_node("/root/AudioManager").play_nursery_rhyme(true)
		_shake(.15)

## Vines come from the walls, the ceiling and the corners, aimed at where Jerry stands now.
func _lash(player: ExplorationPlayer, index: int) -> void:
	var target: Vector2 = player.global_position+Vector2(0,-42)
	var from: Vector2
	var to: Vector2
	match index%3:
		0:
			var from_right: bool = target.x<(arena.x+arena.y)*.5
			from = Vector2(arena.y if from_right else arena.x,target.y)
			to = Vector2(arena.x if from_right else arena.y,target.y)
		1:
			from = Vector2(target.x-26,_top)
			to = Vector2(target.x+26,minf(mud_y,floor_y))
		_:
			from = Vector2(arena.x if index%2==0 else arena.y,_top)
			to = from+(target-from).normalized()*1500
	var vine := ExplorationLingVine.new()
	vine.session = session
	vine.position = from
	vine.to = to-from
	vine.damage = 12 if phase<3 else 15
	get_parent().add_child(vine)

func _start_phase(value: int) -> void:
	phase = value
	pattern = 0
	state = "phase_break"
	timer = 1.5
	phase_title = WRAPPED
	_notice("哭声大了起来 · 泥浆涌得更快了" if phase==2 else "喊声撕开了童谣 · 泥浆翻涌")
	get_node("/root/AudioManager").play_sfx("sfx_boss_roar")
	_shake(.3)

func can_receive_hit() -> bool:
	return not dead and state!="sleep" and state!="intro"

func receive_hit(amount: int, _origin_value: Vector2, _kind: String = "slash") -> void:
	if not can_receive_hit():
		return
	if state!="exposed":
		get_node("/root/AudioManager").play_sfx("sfx_damage_blocked")
		if _clock-_warned>3:
			_warned = _clock
			_notice("藤蔓裹住了她的身体 · 先砍断发光的藤结")
		return
	health = maxi(0,health-amount)
	_flash = .11
	get_node("/root/AudioManager").play_sfx("sfx_hurt")
	if health<=0:
		_die()

func _die() -> void:
	if dead:
		return
	dead = true
	state = "death"
	dark = 0
	_set_cage(false)
	if is_instance_valid(_knot):
		_knot.queue_free()
	get_tree().call_group("ling_owned","queue_free")
	session.switches["defeated_ling"] = true
	session.acquire("boss_ling")
	var demo: Node = get_tree().get_first_node_in_group("exploration_demo")
	if demo!=null:
		var player: ExplorationPlayer = demo.player
		player.mired = 0
		player.grip = 0
		player.confused = 0
		player.health = mini(100,player.health+35)
		_claim_photo(demo)
		demo.screen_shake(.5)
		demo.hud.toast("怪物崩塌了。泥浆退去，藤蔓枯萎，碎布落了一地。")
	session.save()
	get_node("/root/AudioManager").play_bell()
	var tween := create_tween().set_parallel()
	tween.tween_property(self,"_collapse",1.0,2.6)
	tween.tween_property(self,"mud_y",floor_y+14,2.2)
	tween.tween_property(self,"self_modulate:a",0.0,2.6)
	tween.chain().tween_callback(queue_free)

## The photo from the art room was inside her all along; it falls out with the cloth.
func _claim_photo(demo: Node) -> void:
	for object: ExplorationInteractable in demo.room.interactables:
		if str(object.spec.get("item",""))!="well_seal":
			continue
		session.acquire("well_seal")
		for grant: String in object.spec.get("grants",[]):
			session.acquire(grant)
		session.collected[str(object.spec.get("uid","well_seal"))] = true
		object.hide()

func _shake(duration: float) -> void:
	var demo: Node = get_tree().get_first_node_in_group("exploration_demo")
	if demo!=null:
		demo.screen_shake(duration)

func _notice(text: String) -> void:
	var demo: Node = get_tree().get_first_node_in_group("exploration_demo")
	if demo!=null:
		demo.hud.toast(text)

func _process(_delta: float) -> void:
	if dead:
		queue_redraw()

func _visual_update() -> void:
	self_modulate = Color(1.9,1.6,1.4) if _flash>0 else Color(1.2,.8,.75) if state=="windup" and attack=="voice" else Color.WHITE
	queue_redraw()

func _draw() -> void:
	if state=="sleep":
		return
	var withered: float = _collapse
	var vine_color: Color = Color("2f4a33").lerp(Color("4a3a25"),withered)
	for strand: PackedVector2Array in _strands:
		draw_polyline(strand,vine_color,7,true)
	draw_multiline(_thorns,Color("6d7f4a").lerp(Color("4a3a25"),withered),2.5,true)
	draw_set_transform(Vector2(0,_collapse*120),0,Vector2(1.0+(1.0-_rise)*.5,maxf(.02,_rise)*(1.0-_collapse*.75)))
	_draw_body()
	draw_set_transform(Vector2.ZERO)

## The mud giant with Ling's twin tails, white shirt and blue skirt, and no face (Codex art, Demo 9).
const BODY_WIDTH: float = 720
func _draw_body() -> void:
	var sway: float = sin(_clock*1.3)
	var head := Vector2(0,-500)
	var body: Texture2D = ExplorationArt.sprite("ling_giant")
	if body!=null:
		var size := Vector2(BODY_WIDTH,BODY_WIDTH*body.get_height()/body.get_width())
		draw_texture_rect(body,Rect2(Vector2(-size.x*.5+sway*5,-size.y+14),size),false)
	# Vines bind the body until a knot is cut.
	if _wrap>.01:
		var band_color := Color("2f4a33",_wrap)
		for b: int in range(6):
			var band := PackedVector2Array()
			var y: float = -440+b*62
			for i: int in range(10):
				var x: float = lerpf(-150-b*12,150+b*12,float(i)/9)
				band.append(Vector2(x,y+sin(i*.9+b)*(16+(1.0-_wrap)*46)+(b%2*2-1)*(float(i)-4.5)*5))
			draw_polyline(band,band_color,11,true)
			for i: int in range(1,band.size(),2):
				draw_line(band[i],band[i]+Vector2(5,-15),Color("6d7f4a",_wrap),3,true)
	else:
		draw_circle(Vector2(0,-350),46+sin(_clock*5)*6,Color("ffd9a0",.22))
	if state=="windup" and attack=="voice":
		var progress: float = clampf(1-timer/_windup_length,0,1)
		for i: int in range(3):
			draw_arc(head,90+i*34+progress*50,0,TAU,40,Color("e9c78a",.5-i*.13),3,true)
