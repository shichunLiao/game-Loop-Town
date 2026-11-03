class_name ExplorationEnemy
extends CharacterBody2D
## Eight data-defined enemy silhouettes with patrol, telegraphed melee and ranged AI.

var spec: Dictionary
var session: ExplorationSession
var data: Dictionary
var health: int
var max_health: int
var visual: Sprite2D
var facing: float = -1
var state: String = "patrol"
var timer: float = .8
var stun: float = 0
var dead: bool = false
var _origin: Vector2
var _clock: float = 0
var _flash: float = 0
var _attack_done: bool = false
var boss: bool = false

func _ready() -> void:
	position = ExplorationCatalog.vec(spec["pos"])
	_origin = position
	if not boss:
		data = ExplorationArt.actors()["enemies"][str(spec["type"])]
	max_health = int(data["hp"])
	health = max_health
	collision_layer = 4
	collision_mask = 1
	floor_snap_length = 10
	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(38, minf(80,float(data["height"])*.75)) if not boss else Vector2(75,150)
	collision.position.y = -rectangle.size.y*.5
	collision.shape = rectangle
	add_child(collision)
	ExplorationHitArea.hurtbox(self,16,rectangle.size,collision.position)
	visual = ExplorationArt.visual(self,str(data["atlas"]),float(data["height"]),int(data.get("cell",-1)))
	add_to_group("exploration_enemies")
	if boss:
		add_to_group("exploration_boss")

func _physics_process(delta: float) -> void:
	if dead:
		return
	var rate: float = .3 if session.slow_time > 0 else 1.0
	var dt: float = delta*rate
	_clock += dt
	_flash = maxf(0,_flash-delta)
	stun = maxf(0,stun-dt)
	timer -= dt
	var player: ExplorationPlayer = get_tree().get_first_node_in_group("exploration_player") as ExplorationPlayer
	if player == null or not player.enabled:
		return
	var offset: Vector2 = player.global_position-global_position
	var behavior: String = str(data["behavior"])
	var flying: bool = behavior == "fly"
	if not flying:
		velocity.y = minf(1050,velocity.y+1740*dt)
	if stun > 0:
		velocity.x = move_toward(velocity.x,0,700*dt)
	elif boss:
		_boss_behavior(player,offset,dt)
	elif state == "windup":
		velocity.x = 0
		if timer <= 0:
			state = "active"
			timer = .2 if behavior == "lunge" else .14
			_attack(player,behavior)
	elif state == "active":
		velocity.x = facing*340 if behavior == "lunge" else 0.0
		if timer <= 0:
			state = "recover"
			timer = .8 if behavior != "hesitant" else 1.9
	elif state == "recover":
		velocity.x = 0
		if timer <= 0:
			state = "patrol"
			timer = .4
	else:
		var sensed: bool = offset.length()<650 and absf(offset.y)<190
		if sensed:
			facing = signf(offset.x) if absf(offset.x)>2 else facing
		var distance: float = float(data["range"])
		if sensed and offset.length()<distance and timer <= 0:
			state = "windup"
			timer = .65 if behavior in ["guard","ranged"] else .48
		else:
			if not sensed and absf(position.x-_origin.x)>float(spec.get("patrol",240)):
				facing = -signf(position.x-_origin.x)
			velocity.x = facing*float(data["speed"])
			if behavior == "ranged":
				velocity.x = 0
			if flying:
				velocity.y = clampf(offset.y*1.4,-90,90) if sensed else sin(_clock*2)*35
			elif is_on_floor() and not _floor_ahead():
				velocity.x = 0
				facing = -facing
	var saved_velocity: Vector2 = velocity
	velocity *= rate
	move_and_slide()
	velocity = Vector2(saved_velocity.x,0 if is_on_floor() else saved_velocity.y)
	if is_on_wall():
		facing *= -1
	_visual_update()
	if position.y > _origin.y+800:
		_die()

func _floor_ahead() -> bool:
	var from: Vector2 = global_position+Vector2(facing*48,-25)
	var query := PhysicsRayQueryParameters2D.create(from,from+Vector2(0,100),1)
	return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func _attack(player: ExplorationPlayer, behavior: String) -> void:
	if behavior == "ranged":
		shoot((player.global_position+Vector2(0,-35)-global_position).normalized()*340)
		return
	var hit := ExplorationHitArea.new()
	hit.source = self
	hit.target_layer = 8
	hit.damage = int(data["damage"])
	hit.position = Vector2(facing*46,-40)
	hit.dimensions = Vector2(95,70)
	hit.direction = Vector2(facing,0)
	add_child(hit)

func shoot(speed: Vector2) -> void:
	var projectile := ExplorationProjectile.new()
	projectile.position = position+Vector2(facing*40,-float(data["height"])*.6)
	projectile.velocity = speed
	projectile.damage = int(data["damage"])
	projectile.session = session
	get_parent().add_child(projectile)

func receive_hit(amount: int, origin: Vector2, _kind: String = "slash") -> void:
	if dead:
		return
	if boss and state == "sleep":
		state = "patrol"
		timer = 1
	if str(data["behavior"]) == "guard" and (origin.x-global_position.x)*facing>0:
		amount = maxi(1,amount/2)
	health = maxi(0,health-amount)
	_flash = .12
	stun = .10 if boss else .24
	velocity.x = signf(global_position.x-origin.x)*(70 if boss else 190)
	get_node("/root/AudioManager").play_sfx("sfx_hurt")
	if health <= 0:
		_die()
	queue_redraw()

func _die() -> void:
	if dead:
		return
	dead = true
	session.switches["defeated_"+str(spec.get("id",""))] = true
	if boss:
		session.acquire("boss_morris")
		session.save()
		var demo: Node = get_tree().get_first_node_in_group("exploration_demo")
		demo.hud.toast("莫里斯的蜡壳消散。镜室的机械锁打开了。")
		demo.player.health = mini(100,demo.player.health+35)
		get_node("/root/AudioManager").play_bell()
	var tween := create_tween()
	tween.tween_property(self,"modulate:a",0,.45)
	tween.tween_callback(queue_free)

func _visual_update() -> void:
	visual.flip_h = facing > 0
	visual.position.y = -float(data["height"])*.5 + sin(_clock*(8 if absf(velocity.x)>1 else 2))*2
	visual.rotation = sin(_clock*8)*.025 if absf(velocity.x)>1 else 0
	visual.modulate = Color(3,2,1) if _flash>0 else Color(1.1,.65,.5) if state=="windup" else Color.WHITE
	queue_redraw()

func _draw() -> void:
	if dead:
		return
	if health < max_health and not boss:
		draw_rect(Rect2(-26,-float(data["height"])-12,52,4),Color("281d25"))
		draw_rect(Rect2(-26,-float(data["height"])-12,52*float(health)/max_health,4),Color("c9a16a"))
	if state == "windup":
		draw_circle(Vector2(facing*25,-float(data["height"])*.7),9,Color("f5ac6a"))

func _boss_behavior(_player: ExplorationPlayer, _offset: Vector2, _delta: float) -> void:
	pass
