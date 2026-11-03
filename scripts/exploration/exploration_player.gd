class_name ExplorationPlayer
extends CharacterBody2D
## Responsive prototype controller: buffered variable jump, coyote time and earned abilities.

signal died
signal landed

const SPEED: float = 365.0
const GRAVITY: float = 1740.0
const JUMP: float = -800.0
var session: ExplorationSession
var enabled: bool = true
var health: int = 100
var energy: float = 100.0
var visual: Sprite2D
var attack_phase: String = "ready"
var combo: int = 0
var _attack_timer: float = 0.0
var _attack_direction: Vector2 = Vector2.RIGHT
var _attack_queued: bool = false
var _combo_window: float = 0.0
var _special_attack: bool = false
var _slow_cooldown: float = 0.0
var _knockback: float = 0.0
var _drop_timer: float = 0.0
var _drop_platform: ExplorationPlatform
var facing: float = 1.0
var state: String = "idle"
var near_vine: bool = false
var _coyote: float = 0.0
var _buffer: float = 0.0
var _invulnerability: float = 0.0
var _dash: float = 0.0
var _dash_cooldown: float = 0.0
var _air_jump: bool = false
var _clock: float = 0.0
var _last_ground_y: float = 0.0
var weapon: ExplorationWeapon

func _ready() -> void:
	_last_ground_y = position.y
	collision_layer = 2
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_GROUNDED
	floor_snap_length = 10.0
	var capsule := CapsuleShape2D.new()
	capsule.radius = 13.0
	capsule.height = 62.0
	var shape := CollisionShape2D.new()
	shape.position = Vector2(0, -31)
	shape.shape = capsule
	add_child(shape)
	add_to_group("exploration_player")
	ExplorationHitArea.hurtbox(self,8,Vector2(28,61),Vector2(0,-31))
	visual = ExplorationArt.visual(self,"hero",105)
	weapon = ExplorationWeapon.new()
	weapon.fighter = self
	add_child(weapon)
	z_index = 5

func _physics_process(delta: float) -> void:
	_clock += delta
	_invulnerability = maxf(0.0, _invulnerability - delta)
	_dash_cooldown = maxf(0.0, _dash_cooldown - delta)
	queue_redraw()
	if not enabled:
		return
	energy = minf(100,energy+delta*7)
	_slow_cooldown = maxf(0,_slow_cooldown-delta)
	_combo_window = maxf(0,_combo_window-delta)
	_knockback = move_toward(_knockback,0,delta*900)
	_update_combat(delta)
	if _drop_timer>0:
		_drop_timer -= delta
		if _drop_timer<=0 and is_instance_valid(_drop_platform):
			remove_collision_exception_with(_drop_platform)
			_drop_platform = null
	var on_floor_before: bool = is_on_floor()
	_coyote = 0.12 if on_floor_before else maxf(0.0, _coyote - delta)
	_buffer = maxf(0.0, _buffer - delta)
	if on_floor_before:
		_air_jump = false
		_last_ground_y = position.y
	if Input.is_action_just_pressed("jump"):
		if Input.is_action_pressed("move_down") and _try_drop():
			_buffer = 0
		else:
			_buffer = 0.14
	var direction: float = Input.get_axis("move_left", "move_right")
	if direction != 0.0:
		facing = direction
	var climbing: bool = near_vine and session != null and session.has("vine") and Input.get_axis("move_up", "move_down") != 0.0
	if climbing:
		_last_ground_y = position.y
		velocity = Vector2(direction * 140.0, Input.get_axis("move_up", "move_down") * 235.0)
		state = "climb"
		_air_jump = false
	else:
		velocity.x = direction * SPEED * (.6 if attack_phase == "windup" else 1.0) + _knockback
		velocity.y = minf(velocity.y + GRAVITY * delta, 1050.0)
		state = "run" if direction != 0.0 else "idle"
		if not on_floor_before:
			state = "jump" if velocity.y < 0.0 else "fall"
	if _buffer > 0.0 and (_coyote > 0.0 or (session != null and session.has("double_jump") and not _air_jump)):
		if _coyote <= 0.0:
			_air_jump = true
		velocity.y = JUMP
		_buffer = 0.0
		_coyote = 0.0
		get_node("/root/AudioManager").play_sfx("sfx_jump")
	if Input.is_action_just_released("jump") and velocity.y < -300.0:
		velocity.y *= 0.5
	if Input.is_action_just_pressed("explore_dash") and session != null and session.has("dash") and _dash_cooldown <= 0.0:
		_dash = 0.16
		_dash_cooldown = 0.7
	if _dash > 0.0:
		_dash -= delta
		velocity = Vector2(facing * 850.0, 0.0)
		state = "dash"
		_invulnerability = maxf(_invulnerability,.05)
	move_and_slide()
	visual.flip_h = facing < 0
	visual.rotation = clampf(velocity.x/6000,-.07,.07) if is_on_floor() else -.06*facing
	visual.position.y = -52.5 + (sin(_clock*17)*2 if state == "run" else sin(_clock*2)*.7)
	visual.scale.y = (105.0/visual.texture.get_height()) * (1.0+sin(_clock*17)*.025 if state=="run" else 1.0)
	visual.modulate = Color(1,1,1,.35 if _invulnerability>0 and int(_clock*15)%2==0 else 1)
	if attack_phase!="ready":
		var pose: float = -0.18 if attack_phase=="windup" else .22 if attack_phase=="active" else .09
		visual.rotation += pose*facing*(-1 if combo==2 else 1)
		visual.position.x = (-5 if attack_phase=="windup" else 8)*facing
		visual.scale.y *= .94 if attack_phase=="windup" else 1.035
	else:
		visual.position.x = move_toward(visual.position.x,0,delta*90)
	if not on_floor_before and is_on_floor():
		landed.emit()
		get_node("/root/AudioManager").play_sfx("sfx_land")
		if position.y-_last_ground_y > 650.0:
			take_damage(100)
	if global_position.y > 6200.0:
		take_damage(100)

func take_damage(amount: int) -> void:
	if _invulnerability > 0.0 or not enabled:
		return
	health = maxi(0, health - amount)
	_invulnerability = 1.1
	velocity.y = -300.0
	get_node("/root/AudioManager").play_sfx("sfx_hurt")
	if health <= 0:
		enabled = false
		state = "death"
		died.emit()

func receive_hit(amount: int, origin: Vector2, _kind: String = "hit") -> void:
	if _invulnerability > 0 or not enabled:
		return
	_knockback = signf(global_position.x-origin.x)*330
	attack_phase = "ready"
	take_damage(amount)
	var demo: Node = get_tree().get_first_node_in_group("exploration_demo")
	if demo != null:
		demo.screen_shake(.15)

func _try_drop() -> bool:
	if not is_on_floor():
		return false
	for i: int in range(get_slide_collision_count()):
		var collision: KinematicCollision2D = get_slide_collision(i)
		var floor_body: ExplorationPlatform = collision.get_collider() as ExplorationPlatform
		if floor_body != null and floor_body.one_way and collision.get_normal().y<-.5:
			_drop_platform = floor_body
			_drop_timer = .26
			add_collision_exception_with(floor_body)
			position.y += 3
			velocity.y = 140
			return true
	return false

func _update_combat(delta: float) -> void:
	if Input.is_action_just_pressed("attack"):
		if attack_phase == "ready":
			begin_attack()
		else:
			_attack_queued = true
	if Input.is_action_just_pressed("special") and session.has("scissors") and energy>=25 and attack_phase=="ready":
		energy -= 25
		begin_attack(true)
	if Input.is_action_just_pressed("explore_time") and session.has("time_slow") and energy>=35 and _slow_cooldown<=0:
		energy -= 35
		session.slow_time = 2.8
		_slow_cooldown = 9
	if Input.is_action_just_pressed("explore_heal") and energy>=50 and health<100 and attack_phase=="ready":
		energy -= 50
		health = mini(100,health+30)
		_invulnerability = .3
	if attack_phase == "ready":
		return
	_attack_timer -= delta
	if _attack_timer > 0:
		return
	if attack_phase == "windup":
		attack_phase = "active"
		_attack_timer = float(ExplorationWeapon.profile(session)["active"])
		_spawn_swing()
		if _special_attack:
			var style: String = str(ExplorationWeapon.profile(session)["id"])
			if style in ["shears","ember"]:
				_dash = .14
			elif style=="clock":
				session.slow_time = maxf(session.slow_time,.8)
			elif style=="thread":
				var echo := ExplorationHitArea.new()
				echo.source = self
				echo.kind = "thread"
				echo.damage = 18
				echo.dimensions = Vector2(210,145)
				echo.position = Vector2(0,-42)
				echo.lifetime = .27
				add_child(echo)
	elif attack_phase == "active":
		attack_phase = "recover"
		_attack_timer = float(ExplorationWeapon.profile(session)["recovery"])+(0 if combo<3 else .09)
	else:
		attack_phase = "ready"
		_combo_window = .35
		if _attack_queued:
			_attack_queued = false
			begin_attack()

func begin_attack(special: bool = false) -> void:
	combo = combo%3+1 if _combo_window>0 else 1
	_special_attack = special
	_attack_direction = Vector2(facing,0)
	if Input.is_action_pressed("move_up"):
		_attack_direction = Vector2.UP
	elif Input.is_action_pressed("move_down") and not is_on_floor():
		_attack_direction = Vector2.DOWN
	attack_phase = "windup"
	_attack_timer = float(ExplorationWeapon.profile(session)["windup"])*(1.7 if special else 1.0)
	get_node("/root/AudioManager").play_sfx("sfx_attack_swing")

func _spawn_swing() -> void:
	var hit := ExplorationHitArea.new()
	hit.source = self
	hit.target_layer = 16
	var stats: Dictionary = ExplorationWeapon.profile(session)
	hit.damage = int(stats["damage"]) + (12 if combo==3 else 0)
	if _special_attack:
		hit.damage += 24
	hit.kind = str(stats["id"])
	hit.finisher = combo==3 or _special_attack
	hit.lifetime = float(stats["active"])
	hit.direction = _attack_direction
	hit.dimensions = Vector2(float(stats["reach"]),96 if combo==3 else 86)
	if _special_attack:
		hit.dimensions.x *= 1.5
	if _attack_direction.y != 0:
		hit.dimensions = Vector2(80,110)
	hit.position = Vector2(0,-35)+_attack_direction*(float(stats["reach"])*.5)
	add_child(hit)
	# Threads are also physical targets: the blade must overlap their short
	# interaction bounds, so a remote attack cannot open a whole stage.
	if session.has("scissors"):
		var demo: Node = get_tree().get_first_node_in_group("exploration_demo")
		for object: ExplorationInteractable in demo.room.interactables:
			if str(object.spec["kind"])=="thread" and not object.is_finished() and Rect2(hit.position-hit.dimensions*.5,hit.dimensions).has_point(object.global_position+Vector2(0,-65)-global_position):
				session.switches[str(object.spec["flag"])] = true
				session.changed.emit()
				session.save()

func on_attack_landed(_target: Node, direction: Vector2) -> void:
	get_node("/root/AudioManager").play_sfx("sfx_attack_hit")
	energy = minf(100,energy+8)
	if direction.y>0:
		velocity.y = -520
		_air_jump = false
	var demo: Node = get_tree().get_first_node_in_group("exploration_demo")
	if demo != null:
		demo.screen_shake(.065)

func _draw() -> void:
	# The generated character is animated as a cutout; attack arcs are separate
	# timed hitbox visuals. No environment artwork contains a baked-in hero.
	if visual != null:
		if _dash>0:
			for i: int in range(1,4):
				draw_circle(Vector2(-facing*i*24,-40),22-i*4,Color(.4,.9,1,.12))
		return
	if _invulnerability > 0.0 and int(_clock * 15.0) % 2 == 0:
		return
	var bob: float = sin(_clock * 12.0) * 2.0 if state == "run" else sin(_clock * 2.0)
	var ink := Color("10171e")
	var outline := Color("70a5ae")
	var stride: float = sin(_clock * 16.0) * 12.0 if state == "run" else 4.0
	draw_line(Vector2(-5, -20), Vector2(-7 + stride, -2), ink, 9.0, true)
	draw_line(Vector2(5, -20), Vector2(7 - stride, -2), ink, 9.0, true)
	var cloak := PackedVector2Array([Vector2(-12, -52 + bob), Vector2(11, -50 + bob), Vector2(19, -17), Vector2(-12, -22), Vector2(-30, -12)])
	draw_colored_polygon(cloak, ink)
	draw_polyline(cloak, outline, 1.4, true)
	draw_circle(Vector2(0, -56 + bob), 12.0, ink)
	draw_colored_polygon(PackedVector2Array([Vector2(-20, -66 + bob), Vector2(-11, -89 + bob), Vector2(14, -69 + bob)]), ink)
	draw_line(Vector2(-29, -66 + bob), Vector2(30, -62 + bob), outline, 5.0, true)
	draw_line(Vector2(-29, -64 + bob), Vector2(30, -60 + bob), ink, 5.0, true)
	draw_circle(Vector2(6 * facing, -55 + bob), 2.1, Color("edbf77"))
	for radius: float in [30.0, 20.0, 12.0]:
		draw_circle(Vector2(17 * facing, -34), radius, Color(0.3, 0.9, 1.0, 0.035))
	draw_set_transform(Vector2(16 * facing, -34), -0.22 * facing)
	draw_rect(Rect2(-7, -10, 16, 20), Color("c9f2eb"))
	draw_line(Vector2(0, -8), Vector2(0, 8), Color("55949e"), 1.0)
	draw_set_transform(Vector2.ZERO)
