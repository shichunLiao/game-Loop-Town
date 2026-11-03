class_name ActorFactory
extends RefCounted

## 运行时构建敌人 / NPC 的工具。
##
## 为什么需要它：敌人与 NPC 的节点结构（Body + Sprite + HurtBox + DetectionArea +
## StateMachine + 各状态）是固定的，但**摆放位置和参数**是关卡数据。
## 与其为每种敌人手写一份 .tscn 并在关卡里重复摆放，不如：
##   - 提供 make_wax_dummy() / make_townsman() 等工厂方法
##   - 关卡生成器只给出“在哪个位置放哪一种、用什么参数”
## 这样新增敌人只需要加一个工厂方法，且状态脚本已经存在于磁盘上，可被精确复用。
##
## 注意：状态节点是**按需创建**的，状态脚本路径集中声明在下面的常量里，
## 避免到处写字符串导致改名后静默失效。

const L_WORLD := 1
const L_PLAYER := 2
const L_ENEMY := 3
const L_PLAYER_ATTACK := 10
const L_ENEMY_ATTACK := 11

## 通用敌人状态脚本（enemy_idle / chase / attack / hit / death）。
const GENERIC_ENEMY_STATES: Dictionary = {
	&"idle": "res://scripts/enemy/states/enemy_idle.gd",
	&"chase": "res://scripts/enemy/states/enemy_chase.gd",
	&"attack": "res://scripts/enemy/states/enemy_attack.gd",
	&"hit": "res://scripts/enemy/states/enemy_hit.gd",
	&"death": "res://scripts/enemy/states/enemy_death.gd",
}

## 蜡像的状态：追击与跳扑用蜡像专属脚本。
const WAX_DUMMY_STATES: Dictionary = {
	&"idle": "res://scripts/enemy/states/enemy_idle.gd",
	&"patrol": "res://scripts/enemy/states/enemy_patrol.gd",
	&"chase": "res://scripts/enemy/states/wax_dummy_chase.gd",
	&"jump_lunge": "res://scripts/enemy/states/jump_lunge.gd",
	&"attack": "res://scripts/enemy/states/enemy_attack.gd",
	&"hit": "res://scripts/enemy/states/enemy_hit.gd",
	&"death": "res://scripts/enemy/states/enemy_death.gd",
}

## 镇民的状态：task / staggered / dazed / chase。
const TOWNSMAN_STATES: Dictionary = {
	&"task": "res://scripts/npc/states/task.gd",
	&"staggered": "res://scripts/npc/states/staggered.gd",
	&"dazed": "res://scripts/npc/states/dazed.gd",
	&"chase": "res://scripts/npc/states/chase.gd",
	&"hit": "res://scripts/enemy/states/enemy_hit.gd",
	&"death": "res://scripts/enemy/states/enemy_death.gd",
}


# ---------------------------------------------------------------------------
# 蜡像敌人
# ---------------------------------------------------------------------------

## 造一只蜡像。variant 见 WaxDummy.Variant。
static func make_wax_dummy(
	spawn_position: Vector2,
	variant: int = 0,
	detection_range: float = 260.0,
	patrol_radius: float = 60.0
) -> WaxDummy:
	var actor := WaxDummy.new()
	actor.name = "WaxDummy"
	_configure_body(actor, Vector2(26.0, 52.0))
	_attach_sprite(actor, _wax_dummy_animations(), &"idle", Vector2(0.0, -30.0))
	_attach_health(actor, 46, false)
	_attach_hurt_box(actor, Vector2(0.0, -26.0), 15.0, 50.0)
	_attach_hit_box(actor, Vector2(30.0, -28.0), Vector2(48.0, 34.0))
	_attach_detection(actor, detection_range)
	_attach_states(actor, WAX_DUMMY_STATES, &"idle")
	actor.variant = variant as WaxDummy.Variant
	actor.patrol_radius = patrol_radius
	actor.position = spawn_position
	return actor


# ---------------------------------------------------------------------------
# 镇民 NPC
# ---------------------------------------------------------------------------

## 造一个镇民。mood 见 Townsman.Mood。
static func make_townsman(
	spawn_position: Vector2,
	mood: int = 0,
	dialogue_path: String = "",
	interact_prompt: String = "交谈"
) -> Townsman:
	var actor := Townsman.new()
	actor.name = "Townsman"
	_configure_body(actor, Vector2(28.0, 54.0))
	_attach_sprite(actor, _townsman_animations(), &"task", Vector2(0.0, -31.0))
	_attach_health(actor, 40, false)
	_attach_hurt_box(actor, Vector2(0.0, -27.0), 14.0, 50.0)
	_attach_hit_box(actor, Vector2(28.0, -28.0), Vector2(46.0, 32.0))
	_attach_detection(actor, 300.0)
	_attach_states(actor, TOWNSMAN_STATES, &"task")
	actor.mood = mood as Townsman.Mood
	actor.dialogue_path = dialogue_path
	actor.interact_prompt = interact_prompt
	actor.position = spawn_position
	return actor


# ---------------------------------------------------------------------------
# 通用装配
# ---------------------------------------------------------------------------

static func _configure_body(actor: CharacterBody2D, capsule_size: Vector2) -> void:
	actor.collision_layer = 1 << (L_ENEMY - 1)
	actor.collision_mask = 1 << (L_WORLD - 1)
	# motion_mode 必须是默认的 0 (GROUNDED)，否则 is_on_floor() 永远为 false。
	actor.floor_snap_length = 8.0

	var shape_node := CollisionShape2D.new()
	shape_node.name = "CollisionShape2D"
	shape_node.position = Vector2(0.0, -capsule_size.y * 0.5)
	var capsule := CapsuleShape2D.new()
	capsule.radius = capsule_size.x * 0.5
	capsule.height = capsule_size.y
	shape_node.shape = capsule
	actor.add_child(shape_node)


static func _attach_sprite(
	actor: Actor,
	animations: Dictionary,
	default_animation: StringName,
	sprite_offset: Vector2
) -> void:
	var sprite := AnimatedSprite2D.new()
	sprite.name = "AnimatedSprite2D"
	sprite.sprite_frames = _build_sprite_frames(animations)
	sprite.animation = default_animation
	sprite.position = sprite_offset
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(default_animation):
		sprite.play(default_animation)
	actor.add_child(sprite)


static func _attach_health(actor: Actor, maximum: int, free_on_death: bool) -> void:
	var health := HealthComponent.new()
	health.name = "HealthComponent"
	health.max_health = maximum
	health.free_on_death = free_on_death
	actor.add_child(health)


static func _attach_hurt_box(actor: Actor, offset: Vector2, radius: float, height: float) -> void:
	var hurt := HurtBox.new()
	hurt.name = "HurtBox"
	hurt.collision_layer = 1 << (L_ENEMY - 1)
	hurt.collision_mask = 1 << (L_PLAYER_ATTACK - 1)
	hurt.monitoring = false
	var shape_node := CollisionShape2D.new()
	shape_node.name = "CollisionShape2D"
	shape_node.position = offset
	var capsule := CapsuleShape2D.new()
	capsule.radius = radius
	capsule.height = height
	shape_node.shape = capsule
	hurt.add_child(shape_node)
	actor.add_child(hurt)


static func _attach_hit_box(actor: Actor, offset: Vector2, size: Vector2) -> void:
	var hit := HitBox.new()
	hit.name = "HitBox"
	hit.collision_layer = 1 << (L_ENEMY_ATTACK - 1)
	hit.collision_mask = 1 << (L_PLAYER - 1)
	hit.monitoring = false
	var shape_node := CollisionShape2D.new()
	shape_node.name = "CollisionShape2D"
	shape_node.position = offset
	var rect := RectangleShape2D.new()
	rect.size = size
	shape_node.shape = rect
	hit.add_child(shape_node)
	actor.add_child(hit)


static func _attach_detection(actor: Actor, radius: float) -> void:
	var area := Area2D.new()
	area.name = "DetectionArea"
	area.collision_layer = 0
	area.collision_mask = 1 << (L_PLAYER - 1)
	var shape_node := CollisionShape2D.new()
	shape_node.name = "CollisionShape2D"
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape_node.shape = circle
	area.add_child(shape_node)
	actor.add_child(area)


static func _attach_states(actor: Actor, states: Dictionary, initial: StringName) -> void:
	var machine := StateMachine.new()
	machine.name = "StateMachine"
	machine.initial_state = initial
	for state_name: Variant in states.keys():
		var path: String = states[state_name]
		if not ResourceLoader.exists(path):
			push_warning("[ActorFactory] 状态脚本缺失: %s" % path)
			continue
		var script := load(path) as Script
		if script == null:
			continue
		var state := State.new()
		state.name = String(state_name)
		state.set_script(script)
		machine.add_child(state)
	actor.add_child(machine)


# ---------------------------------------------------------------------------
# 动画资源
# ---------------------------------------------------------------------------

## 从图集切出动画。图集缺失时返回 null，敌人会退化成无色块但依然可玩。
static func _build_sprite_frames(animations: Dictionary) -> SpriteFrames:
	var frames := SpriteFrames.new()
	# SpriteFrames 默认带一个 default 动画，清掉以免干扰。
	if frames.has_animation(&"default"):
		frames.remove_animation(&"default")

	var any_loaded := false
	for animation_name: Variant in animations.keys():
		var spec: Dictionary = animations[animation_name]
		var path: String = spec.get("path", "")
		var frame_count: int = int(spec.get("frames", 1))
		var frame_width: int = int(spec.get("width", 64))
		var frame_height: int = int(spec.get("height", 64))

		frames.add_animation(StringName(animation_name))
		frames.set_animation_loop(StringName(animation_name), true)
		frames.set_animation_speed(StringName(animation_name), float(spec.get("speed", 8.0)))

		if not ResourceLoader.exists(path):
			continue
		var texture := load(path) as Texture2D
		if texture == null:
			continue
		any_loaded = true
		for index in frame_count:
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(
				float(index * frame_width), 0.0,
				float(frame_width), float(frame_height)
			)
			frames.add_frame(StringName(animation_name), atlas)

	if not any_loaded:
		push_warning("[ActorFactory] 敌人贴图缺失，动画将为空（不影响逻辑，只影响外观）。")
	return frames


static func _wax_dummy_animations() -> Dictionary:
	# 优先从资源库定义读取（data/assets/actors/wax_dummy.tres）。
	var definition := _definition("wax_dummy")
	if definition != null:
		return _animations_from_definition(definition, 64)
	return _legacy_paths("wax_dummy")


static func _townsman_animations() -> Dictionary:
	var definition := _definition("townsman")
	if definition != null:
		return _animations_from_definition(definition, 64)
	return _legacy_paths("townsman")


## 取角色资源定义。找不到时返回 null，调用方回退到内置表。
static func _definition(actor_id: StringName) -> ActorDefinition:
	var path := "res://data/assets/actors/%s.tres" % String(actor_id)
	if not ResourceLoader.exists(path):
		return null
	return load(path) as ActorDefinition


## 把 ActorDefinition 的动画条目转换成 SpriteFrames 构建格式。
static func _animations_from_definition(definition: ActorDefinition,
										default_frame: int) -> Dictionary:
	var out: Dictionary = {}
	for entry in definition.animations:
		var anim := entry as AnimationEntry
		if anim == null:
			continue
		out[anim.name] = {
			"path": anim.path,
			"frames": anim.frames,
			"speed": anim.speed,
			"width": anim.frame_width() if anim.frame_width() > 0 else default_frame,
			"height": anim.frame_height() if anim.frame_height() > 0 else default_frame,
		}
	if out.is_empty():
		push_warning("[ActorFactory] %s 的资源定义里没有可用动画。" % definition.id)
	return out


## 内置回退表（资源定义缺失时使用，保证游戏不会因为少一份 .tres 就跑不起来）。
static func _legacy_paths(actor_id: StringName) -> Dictionary:
	var base := "res://assets/enemies/"
	if actor_id == &"townsman":
		return {
			&"idle": {"path": base + "townsman_idle.png", "frames": 4, "speed": 6.0},
			&"task": {"path": base + "townsman_task.png", "frames": 6, "speed": 6.0},
			&"walk": {"path": base + "townsman_idle.png", "frames": 4, "speed": 8.0},
			&"dazed": {"path": base + "townsman_dazed.png", "frames": 3, "speed": 4.0},
			&"hit": {"path": base + "townsman_dazed.png", "frames": 3, "speed": 12.0},
			&"death": {"path": base + "townsman_dazed.png", "frames": 3, "speed": 6.0},
		}
	return {
		&"idle": {"path": base + "wax_dummy_idle.png", "frames": 4, "speed": 6.0},
		&"walk": {"path": base + "wax_dummy_walk.png", "frames": 6, "speed": 8.0},
		&"attack": {"path": base + "wax_dummy_attack.png", "frames": 5, "speed": 12.0},
		&"hit": {"path": base + "wax_dummy_hit.png", "frames": 2, "speed": 12.0},
		&"death": {"path": base + "wax_dummy_death.png", "frames": 5, "speed": 8.0},
	}
