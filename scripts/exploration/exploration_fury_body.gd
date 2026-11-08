class_name ExplorationFuryBody
extends ExplorationEnemy
## The other body at the well mouth. First Fury, lunging at Jerry; after the flash it is Jerry,
## stumbling away from the player's fists, who cannot fall below the last of his blood.

signal lunged_out
signal beaten

const LUNGES: int = 3
const BLOW: int = 17
var boss_title: String = "杰利"
var phase_title: String = "他还在往后退"
var phase: int = 0
var attack_name: String = ""
var victim: bool = false
var glitch: float = 0
var _step: String = "wait"
var _lunges: int = 0
var _down: bool = false

func _ready() -> void:
	boss = true
	data = {"hp":100,"height":118,"damage":14,"atlas":"fury_idle","speed":0,"behavior":"boss"}
	state = "sleep"
	super._ready()
	z_index = 4
	facing = 1

## Story 1.1: "the picture ripples a little" when he appears.
func _process(delta: float) -> void:
	if glitch<=0:
		return
	glitch -= delta
	visual.position.x += randf_range(-7,7) if glitch>0 else 0.0
	visual.modulate.a = randf_range(.45,1) if glitch>0 else 1.0

func begin_lunges() -> void:
	_step = "windup"
	timer = .6

func become_jerry(blood: int) -> void:
	victim = true
	data["height"] = 105
	visual.texture = ExplorationArt.sprite("hero")
	visual.scale = Vector2.ONE*105.0/visual.texture.get_height()
	max_health = 100
	health = blood
	state = "hurt"
	_flash = 0

func _boss_behavior(_player: ExplorationPlayer, offset: Vector2, _delta: float) -> void:
	velocity.x = 0
	if victim:
		if not _down and absf(offset.x)<260:
			facing = -signf(offset.x) if absf(offset.x)>2 else facing
			velocity.x = facing*75
		return
	if _step=="windup":
		facing = signf(offset.x) if absf(offset.x)>4 else facing
		if timer<=0:
			_step = "lunge"
			timer = .36
			_strike()
	elif _step=="lunge":
		velocity.x = facing*760
		if timer<=0:
			_step = "rest"
			timer = .7
			_lunges += 1
	elif _step=="rest" and timer<=0:
		if _lunges>=LUNGES:
			_step = "done"
			lunged_out.emit()
		else:
			_step = "windup"
			timer = .6

func _strike() -> void:
	var hit := ExplorationHitArea.new()
	hit.source = self
	hit.target_layer = 8
	hit.damage = int(data["damage"])
	hit.position = Vector2(facing*50,-55)
	hit.dimensions = Vector2(120,100)
	hit.direction = Vector2(facing,0)
	hit.lifetime = .36
	add_child(hit)
	get_node("/root/AudioManager").play_sfx("sfx_attack_swing")

func can_receive_hit() -> bool:
	return victim and not _down

func receive_hit(_amount: int, origin: Vector2, _kind: String = "slash") -> void:
	if not can_receive_hit():
		return
	health = maxi(1,health-BLOW)
	_flash = .12
	stun = .22
	velocity.x = signf(global_position.x-origin.x)*150
	get_node("/root/AudioManager").play_sfx("sfx_hurt")
	if health<=1:
		_down = true
		phase_title = "还剩最后一丝血"
		beaten.emit()

## He is never killed here; the well does that.
func _die() -> void:
	pass

func collapse(side: float) -> void:
	velocity = Vector2.ZERO
	var tween := create_tween().set_parallel()
	tween.tween_property(visual,"rotation",side*1.45,.3)
	tween.tween_property(visual,"position:y",-16.0,.3)

func drop_in(point: Vector2) -> void:
	var tween := create_tween()
	tween.tween_property(self,"global_position",point+Vector2(0,-74),.28)
	tween.tween_property(self,"global_position",point+Vector2(0,70),.34)
	tween.parallel().tween_property(visual,"modulate:a",0.0,.34)

## Fury's art (Codex, Demo 9) faces left; Jerry's hero sprite faces right.
func _visual_update() -> void:
	if not victim:
		var pose: String = "fury_lunge" if _step=="lunge" else "fury_idle"
		var texture: Texture2D = ExplorationArt.sprite(pose)
		if visual.texture!=texture:
			visual.texture = texture
			visual.scale = Vector2.ONE*float(data["height"])/texture.get_height()
	visual.flip_h = facing<0 if victim else facing>0
	visual.position.y = -float(data["height"])*.5
	if not victim:
		visual.position.x = ExplorationArt.foot_shift("fury_lunge" if _step=="lunge" else "fury_idle",visual.texture,visual.scale.x,visual.flip_h)
	visual.modulate = Color(3,2,1) if _flash>0 else Color(1.5,.7,.6) if _step=="windup" else Color.WHITE
	queue_redraw()

func _draw() -> void:
	pass
