class_name ExplorationKeeperChase
extends Node2D
## Story 1.1 clock tower: the keeper climbs ahead of Jerry, raises the perfect versions of Mei
## and Void, and rewinds time with the bell until both have fallen.

var session: ExplorationSession
var spec: Dictionary
var _tiers: Array[float] = []
var _keeper: ExplorationKeeperFigure
var _keeper_tier: int = 1
var _climb: float = 0
var _limb_timer: float = 5
var _bell: float = -1
var _busy: bool = false
var _hooked: bool = false
var _settled: bool = false
var _echoes: Dictionary = {}
var _checkpoint_tier: int = 0

func _ready() -> void:
	z_index = -1
	var room: ExplorationRoom = get_parent() as ExplorationRoom
	for entry: Dictionary in room.data["platforms"]:
		var rect: Array = entry["rect"]
		if str(entry.get("geometry",""))=="ground" or (str(entry.get("geometry",""))=="rest" and float(rect[2])>1000):
			_tiers.append(float(rect[1]))
	_tiers.sort()
	_tiers.reverse()
	_keeper = ExplorationKeeperFigure.new()
	_keeper.session = session
	_keeper.position = _keeper_spot(_keeper_tier)
	room.actors.add_child(_keeper)
	_keeper.visible = not session.chase_done()
	_checkpoint_tier = session.tower_checkpoint_tier()

func _keeper_spot(tier: int) -> Vector2:
	return Vector2(1150 if tier%2==0 else 320,_tiers[tier])

## The highest floor Jerry has climbed past.
func _tier_of(y: float) -> int:
	var result: int = 0
	for i: int in range(_tiers.size()):
		if y<=_tiers[i]+30:
			result = i
	return result

func _physics_process(delta: float) -> void:
	var player: ExplorationPlayer = get_tree().get_first_node_in_group("exploration_player") as ExplorationPlayer
	if player==null or not player.enabled or _busy:
		return
	if not _hooked:
		_hooked = true
		_begin(player)
	# The light reddens with height.
	get_parent().modulate = Color.WHITE.lerp(Color(1,.72,.68),1.0-clampf(player.global_position.y/_tiers[0],0,1))
	if session.chase_done():
		_settle()
		return
	var rate: float = .3 if session.slow_time>0 else 1.0
	_update_section_checkpoint(player)
	_spawn_echoes(player)
	_limb_timer -= delta*rate
	if _limb_timer<=0 and player.is_on_floor():
		_limb_timer = randf_range(5.5,8.5)
		var limb := ExplorationKeeperLimb.new()
		limb.position = player.global_position
		limb.session = session
		(get_parent() as ExplorationRoom).actors.add_child(limb)
	# He keeps one floor ahead, and climbs on his own if Jerry dawdles.
	var top: int = _tiers.size()-1
	var wanted: int = mini(_tier_of(player.global_position.y)+1,top)
	_climb += delta*rate
	if _climb>=float(spec.get("interval",40)):
		_climb = 0
		wanted = mini(maxi(wanted,_keeper_tier+1),top)
	if wanted>_keeper_tier:
		_keeper_tier = wanted
		_keeper.warp_to(_keeper_spot(_keeper_tier))
		if _keeper_tier==top and _bell<0:
			_bell = 3.5
			_notice("守钟人走向钟绳……")
	if _bell>=0:
		_bell -= delta*rate
		if _bell<0:
			_rewind(player)
			return
	# Nobody reaches the top door while the perfect versions stand.
	if player.global_position.y<_tiers[top]+120 and player.global_position.x>1300:
		_rewind(player)

func _begin(player: ExplorationPlayer) -> void:
	player.died.connect(_on_player_died)
	if session.chase_done():
		return
	if session.tower_checkpoint_tier()==0:
		session.save_at("clock_tower",ExplorationCatalog.vec((get_parent() as ExplorationRoom).data["spawn"]))
	_notice("第一段 · 追逐：跟住守钟人；每两层会永久记录进度。",true)

## Story 1.1: beaten by a perfect version, Jerry starts the whole climb over.
func _on_player_died() -> void:
	# Completed echoes and saved boss damage survive a retry.  Respawn is handled by
	# the demo's deferred death flow at the latest two-floor checkpoint.
	pass

func _spawn_echoes(player: ExplorationPlayer) -> void:
	for entry: Dictionary in spec.get("echoes",[]):
		var flag: String = str(entry["flag"])
		if session.has(flag) or _echoes.has(flag) or absf(player.global_position.y-float(entry["floor"]))>760:
			continue
		var boss: ExplorationEnemy = ExplorationVoidBoss.new() if str(entry["type"])=="void" else ExplorationBoss.new()
		boss.spec = entry.duplicate(true)
		boss.spec["id"] = flag
		boss.spec["echo"] = true
		boss.session = session
		(get_parent() as ExplorationRoom).actors.add_child(boss)
		_echoes[flag] = boss
		_notice("发条倒转 · 完美版本的"+str(entry["label"])+"站了起来")

func _rewind(player: ExplorationPlayer) -> void:
	_busy = true
	_bell = -1
	var demo: Node = get_tree().get_first_node_in_group("exploration_demo")
	get_node("/root/AudioManager").play_bell()
	demo.screen_shake(.4)
	demo.hud.toast("钟声响起 · 仅回退一层；已击败的回声与伤害进度保留")
	await demo._fade_to(.85,.12)
	var target: int = maxi(_checkpoint_tier,_tier_of(player.global_position.y)-1)
	player.global_position = Vector2(300,_tiers[target]-3)
	player.velocity = Vector2.ZERO
	player._last_ground_y = player.position.y
	demo.camera.reset_smoothing()
	_keeper_tier = mini(target+1,_tiers.size()-1)
	_climb = 0
	_keeper.warp_to(_keeper_spot(_keeper_tier))
	await demo._fade_to(0,.25)
	_busy = false

func _update_section_checkpoint(player: ExplorationPlayer) -> void:
	var tier: int = _tier_of(player.global_position.y)
	var milestone: int = mini(int(tier/2)*2,6)
	if milestone<=_checkpoint_tier or milestone<=0:
		return
	_checkpoint_tier = milestone
	var point := Vector2(clampf(player.global_position.x,260.0,1540.0),_tiers[milestone]-3.0)
	session.save_tower_section(milestone,point)
	var section: String = "第二段 · 战斗：完美回声不会跨段回血。" if milestone<6 else "第三段 · 选择：登顶面对守钟人。"
	_notice("永久检查点 · 第 %d 层 / %s" % [milestone,section],true)

func _settle() -> void:
	if _settled:
		return
	_settled = true
	if _keeper.visible:
		_keeper.vanish()
		_notice("钟声停了。只剩下守钟人。他在钟楼顶等你。")

func _notice(text: String, pinned: bool = false) -> void:
	var demo: Node = get_tree().get_first_node_in_group("exploration_demo")
	if demo!=null:
		demo.hud.toast(text,pinned)

## Things that should not be there: hands from the walls and button eyes on the beams,
## more of them on every floor.
func _draw() -> void:
	var skin := Color("3a2a2c")
	var red := Color("8c2f3a")
	for tier: int in range(1,_tiers.size()):
		var y: float = _tiers[tier]
		for i: int in range(tier*2):
			var along: float = float((tier*7+i*13)%17)/17
			if i%2==0:
				var point := Vector2(200,y+60+along*300)
				var wrist := point+Vector2(34+along*26,-6)
				draw_line(point,wrist,skin,9,true)
				for f: int in range(4):
					draw_line(wrist,wrist+Vector2.from_angle((f-1.5)*.42)*16,skin,3,true)
			else:
				var eye := Vector2(260+along*950,y+64+along*60)
				draw_line(Vector2(eye.x,y+40),eye,Color(red,.7),1.5,true)
				draw_circle(eye,8,Color("211a1d"))
				draw_circle(eye+Vector2(-2.5,0),1.5,Color("c9b48f"))
				draw_circle(eye+Vector2(2.5,0),1.5,Color("c9b48f"))
