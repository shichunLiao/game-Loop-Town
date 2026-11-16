class_name ExplorationPoseAnimation
extends Node
## Presentation only: advances generated CG cels; combat clocks and hitboxes remain with hosts.
var visual: Sprite2D
var clip: String = ""
var age: float = 0.0
var frame_index: int = 0
var _source: String = ""
var _cell: int = -1
var _phase_token: String = ""

func _process(delta: float) -> void:
	if not is_instance_valid(visual) or visual.texture == null:
		return
	var source: Dictionary = ExplorationArt.animation_source(visual.texture)
	if source.is_empty():
		return
	_source = str(source.id)
	_cell = int(source.cell)
	var host: Node = visual.get_parent()
	var wanted: String = ExplorationArt.default_clip(_source,_cell)
	if host is ExplorationPlayer and _source == "hero":
		wanted = "hero_" + (host.state if host.attack_phase == "ready" else host.attack_phase)
	elif host is ExplorationFuryBody and host.victim and _source == "hero":
		wanted = "hero_death" if host._down else "hero_recover" if host.stun>0 else "hero_run" if absf(host.velocity.x)>1 else "hero_idle"
	elif host is ExplorationEnemy and not host.boss:
		var stem: String = _source + ("_"+str(_cell) if _cell>=0 else "")
		var action: String = host.state if host.state in ["windup","active","recover"] else "move"
		if ExplorationArt.has_clip(stem+"_"+action):
			wanted = stem+"_"+action
	if not ExplorationArt.has_clip(wanted):
		wanted = ExplorationArt.default_clip(_source,_cell)
	var phase_token: String = host.attack_phase if host is ExplorationPlayer else host._step if host is ExplorationFuryBody else ""
	if wanted != clip or phase_token != _phase_token:
		clip = wanted
		_phase_token = phase_token
		age = 0.0
	var speed: float = 1.0
	if "session" in host and host.session != null and host.session.slow_time>0:
		speed = .3
	age += delta*speed
	var info: Dictionary = ExplorationArt.clip_info(clip)
	if info.is_empty():
		return
	# Fit attack cels to the existing remaining state time without changing that state.
	var duration: float = float(info.get("duration",.8))
	if not bool(info.get("loop",true)):
		var remaining: float = -1.0
		if host is ExplorationPlayer:
			remaining = host._attack_timer if host.attack_phase != "ready" else host._dash if host.state == "dash" else maxf(0,-host.velocity.y/host.GRAVITY) if host.state == "jump" else -1.0
		elif host is ExplorationFuryBody and not host.victim and host._step == "lunge":
			remaining = host.timer
		elif host is ExplorationEnemy:
			remaining = host.timer if host.state in ["windup","active","recover"] else -1.0
		if remaining > 0:
			duration = maxf(age+remaining,.06)
	frame_index = ExplorationArt.animation_index(clip,age,duration)
	visual.texture = ExplorationArt.animation_frame(clip,frame_index)
	visual.set_meta("animation_clip",clip)
	visual.set_meta("animation_frame",frame_index)
