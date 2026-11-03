class_name Morris
extends BossBase

## 第一章 Boss · 莫里斯（提示词【十三】）。
##
## 三个阶段的设计意图（不要为了“难”而破坏它）：
##   PHASE 1  热蜡喷射：左喷 / 右喷 / 高位喷射 / 地面流蜡
##   PHASE 2  召唤蜡像替身。替身与真身几乎一样，**只有真身眼睛里有高光**。
##            所以这一阶段不是战斗，是识别解谜。
##   PHASE 3  熔蜡炉过热：场地被蜡覆盖，安全平台越来越少。
##            玩家被热蜡命中过多会 Wax_Death —— 变成蜡像然后循环回溯。
##
## 因此本脚本把“识别”做成机制：decoy_count 个替身与真身共享外形，
## 真身额外挂一个 EyeHighlight 节点，玩家必须靠它分辨。

signal decoys_spawned(count: int, real_index: int)
signal decoys_cleared
signal wax_floor_advanced(level: int)
signal wax_death_triggered

## --- 热蜡 ---
@export var spray_damage: int = 14
@export var spray_speed: float = 420.0
@export var spray_cooldown: float = 2.1
## 被热蜡命中多少次会变成蜡像。
@export var wax_death_threshold: int = 6

## --- 替身 ---
@export var decoy_count: int = 3
@export var decoy_health: int = 30
## 替身出现的横向偏移，交替分列真身左右。
@export var decoy_offsets: PackedFloat32Array = PackedFloat32Array([-220.0, 240.0, -380.0, 400.0])

## --- 熔蜡炉 ---
## 场地被蜡覆盖的层数上限。
@export var max_wax_floor_level: int = 3
@export var wax_floor_interval: float = 18.0

var wax_hit_count: int = 0
var wax_floor_level: int = 0
var decoys: Array[Node] = []
## 真身是哪一只（0 = 本体，1..n = 替身）。
var real_index: int = 0

var _spray_cooldown_remaining: float = 0.0
var _wax_floor_timer: float = 0.0
var _furnace: Node2D = null
## 本阶段是否已经召唤过替身，避免 chase 状态反复进入 summon。
var _summoned_this_phase: bool = false


## 供 chase 状态查询：本阶段是否已经召唤过替身。
func has_summoned() -> bool:
	return _summoned_this_phase


## 由 summon 状态在进入时调用。
func mark_summoned() -> void:
	_summoned_this_phase = true


func _after_ready() -> void:
	boss_id = &"morris"
	total_phases = 3
	phase_thresholds = PackedFloat32Array([0.66, 0.33])
	arena_half_width = 800.0
	intro_dialogue_path = "res://data/dialogue/morris_pre_boss.tres"
	defeat_dialogue_path = "res://data/dialogue/morris_defeat.tres"
	super._after_ready()
	_furnace = get_node_or_null("Furnace") as Node2D
	_ensure_eye_highlight()


## 真身独有：眼睛里的高光。替身没有 —— 这是玩家唯一的辨别依据。
func _ensure_eye_highlight() -> void:
	var highlight := get_node_or_null("EyeHighlight") as Node2D
	if highlight == null:
		highlight = Node2D.new()
		highlight.name = "EyeHighlight"
		add_child(highlight)
		var glow := PointLight2D.new()
		glow.name = "Glow"
		glow.color = Color(1.0, 0.86, 0.42)
		glow.energy = 1.4
		glow.texture_scale = 0.7
		highlight.add_child(glow)
	highlight.visible = true
	highlight.z_index = 20


# ---------------------------------------------------------------------------
# 各阶段参数
# ---------------------------------------------------------------------------

func _base_move_speed() -> float:
	return 78.0


func _base_attack_damage() -> int:
	return 12


func defense_multiplier_for_phase() -> float:
	# 提示词【十三】：每剪断一条线皮埃罗防御降低；莫里斯这里用“越到后面蜡越脆”。
	match current_phase:
		1: return 1.0
		2: return 1.15
		3: return 1.35
	return 1.0


func stats_multiplier_for_phase() -> float:
	match current_phase:
		1: return 1.0
		2: return 1.18
		3: return 1.35
	return 1.0


func _on_phase_enter(phase: int) -> void:
	# 进入新阶段时重置召唤标记，让每个阶段都会重新召唤替身。
	_summoned_this_phase = false
	match phase:
		2:
			AudioManager.play_sfx("wax_crack")
		3:
			AudioManager.play_sfx("furnace_overheat")
			_start_wax_floor()
			_clear_decoys()


# ---------------------------------------------------------------------------
# PHASE 1 / 2：热蜡
# ---------------------------------------------------------------------------

func can_spray() -> bool:
	if not is_engaged or is_dead:
		return false
	if _spray_cooldown_remaining > 0.0:
		return false
	if not is_target_valid():
		return false
	return distance_to_target_x() <= 460.0


## 由 spray 状态在生效帧调用。direction 由状态机决定：
## left / right / high / floor。
func fire_wax_spray(direction: StringName) -> void:
	if _spray_cooldown_remaining > 0.0:
		return
	_spray_cooldown_remaining = spray_cooldown
	AudioManager.play_sfx("wax_spray", &"BossSFX")

	var origin := global_position + Vector2(0.0, -40.0)
	match direction:
		&"left":
			_spawn_spray(origin, Vector2(-1.0, -0.12), 10)
		&"right":
			_spawn_spray(origin, Vector2(1.0, -0.12), 10)
		&"high":
			_spawn_spray(origin + Vector2(0.0, -30.0), Vector2(0.0, -1.0), 8)
		&"floor":
			# 地面流蜡：从脚下向两侧铺开，范围伤害。
			_spawn_spray(global_position + Vector2(0.0, -8.0), Vector2(1.0, 0.0), 12)
			_spawn_spray(global_position + Vector2(0.0, -8.0), Vector2(-1.0, 0.0), 12)
		_:
			_spawn_spray(origin, Vector2(float(facing), -0.1), 10)


func _spawn_spray(origin: Vector2, direction: Vector2, count: int) -> void:
	var projectile_script := load("res://scripts/boss/wax_projectile.gd")
	var host := get_parent()
	if host == null:
		host = self
	for i in count:
		var projectile := Area2D.new()
		projectile.set_script(projectile_script)
		host.add_child(projectile)
		projectile.global_position = origin
		var spread := deg_to_rad(randf_range(-16.0, 16.0))
		var velocity := direction.normalized().rotated(spread) * spray_speed * randf_range(0.82, 1.18)
		projectile.set("velocity", velocity)
		projectile.set("damage", spray_damage)
		projectile.set("source_actor", self)


## 计时器由状态机的每个状态在物理帧调用，避免依赖 _process
## （Boss 的行为全部走状态机，这样顿帧 / 暂停时计时也正确）。
func update_timers(delta: float) -> void:
	if _spray_cooldown_remaining > 0.0:
		_spray_cooldown_remaining = maxf(_spray_cooldown_remaining - delta, 0.0)
	if _wax_floor_timer > 0.0:
		_wax_floor_timer = maxf(_wax_floor_timer - delta, 0.0)
		if _wax_floor_timer <= 0.0 and current_phase >= 3 and is_engaged:
			_advance_wax_floor()


## 被热蜡命中：累计到阈值就触发热蜡死亡。
func register_wax_hit() -> void:
	wax_hit_count += 1
	if wax_hit_count >= wax_death_threshold:
		_trigger_wax_death()


func _trigger_wax_death() -> void:
	wax_death_triggered.emit()
	AudioManager.play_sfx("wax_crack")
	# 变成蜡像 → 循环回溯（提示词【十三】：Wax_Death）。
	var player := get_tree().get_first_node_in_group(&"player")
	if player != null:
		var health := player.get_node_or_null("HealthComponent") as HealthComponent
		if health != null:
			var info := DamageInfo.create(9999, self, Vector2.UP, 0.0)
			info.damage_type = &"wax"
			info.invincible_time = 0.0
			health.take_damage(info)


# ---------------------------------------------------------------------------
# PHASE 2：蜡像替身
# ---------------------------------------------------------------------------

## 供 summon 状态在演出结束时调用。
func spawn_decoys_now() -> void:
	_spawn_decoys()


func _spawn_decoys() -> void:
	_clear_decoys()
	# 替身用莫里斯的贴图（同样的外形），但**没有** EyeHighlight。
	var morris_animation := get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D

	for i in decoy_count:
		var decoy := CharacterBody2D.new()
		decoy.name = "Decoy%d" % (i + 1)
		decoy.collision_layer = 1 << 2   # layer 3 = enemy，玩家可以打到它
		decoy.collision_mask = 1 << 0
		decoy.add_to_group(&"enemy")
		decoy.add_to_group(&"morris_decoy")

		var shape := CollisionShape2D.new()
		var capsule := CapsuleShape2D.new()
		capsule.radius = 14.0
		capsule.height = 52.0
		shape.shape = capsule
		shape.position = Vector2(0.0, -26.0)
		decoy.add_child(shape)

		if morris_animation != null and morris_animation.sprite_frames != null:
			var decoy_sprite := AnimatedSprite2D.new()
			decoy_sprite.name = "AnimatedSprite2D"
			decoy_sprite.sprite_frames = morris_animation.sprite_frames
			decoy_sprite.animation = &"idle"
			decoy_sprite.play()
			decoy_sprite.position = Vector2(0.0, -32.0)
			# 关键：替身**没有**眼部高光，这是玩家唯一的辨别依据。
			decoy.add_child(decoy_sprite)

		# 替身自己也有受击框，被砍到会消失——但砍替身不推进 Boss 血条。
		var hurt := Area2D.new()
		hurt.name = "HurtBox"
		hurt.set_script(load("res://scripts/combat/hurt_box.gd"))
		hurt.collision_layer = 1 << 2
		hurt.collision_mask = 1 << 9   # layer 10 = player_attack
		hurt.monitoring = false
		var hurt_shape := CollisionShape2D.new()
		hurt_shape.shape = capsule.duplicate()
		hurt_shape.position = Vector2(0.0, -26.0)
		hurt.add_child(hurt_shape)
		decoy.add_child(hurt)

		decoy.set_meta(&"health", decoy_health)
		decoy.set_meta(&"is_decoy", true)
		if hurt.has_signal("hit_received"):
			hurt.connect("hit_received", _on_decoy_hit.bind(decoy))

		get_parent().add_child(decoy)
		var offset_x: float = decoy_offsets[i % decoy_offsets.size()]
		decoy.global_position = global_position + Vector2(offset_x, -20.0)
		decoys.append(decoy)

	real_index = randi() % (decoys.size() + 1)
	decoys_spawned.emit(decoys.size(), real_index)


func _on_decoy_hit(info: DamageInfo, landed: bool, decoy: Node) -> void:
	if not landed or decoy == null or not is_instance_valid(decoy):
		return
	var current := int(decoy.get_meta(&"health", decoy_health)) - info.amount
	if current <= 0:
		AudioManager.play_sfx("wax_crack")
		decoy.queue_free()
		decoys.erase(decoy)
		if decoys.is_empty():
			decoys_cleared.emit()
	else:
		decoy.set_meta(&"health", current)
		# 命中反馈：闪一下，但**不**留下 EyeHighlight —— 玩家必须靠缺席来识别。
		if decoy is CanvasItem:
			Combat.flash_white(decoy as CanvasItem)


func _clear_decoys() -> void:
	for decoy in decoys:
		if decoy != null and is_instance_valid(decoy):
			decoy.queue_free()
	decoys.clear()
	decoys_cleared.emit()


# ---------------------------------------------------------------------------
# PHASE 3：熔蜡炉过热
# ---------------------------------------------------------------------------

func _start_wax_floor() -> void:
	wax_floor_level = 0
	_wax_floor_timer = wax_floor_interval
	_advance_wax_floor()


## 每推进一层，地面上的安全区域就减少一块。
## 用场景中的 WaxFloor 子节点表示熔蜡覆盖范围。
func _advance_wax_floor() -> void:
	if wax_floor_level >= max_wax_floor_level:
		return
	wax_floor_level += 1
	_wax_floor_timer = wax_floor_interval

	var host := get_parent()
	if host == null:
		return
	var floor_node := host.get_node_or_null("WaxFloor%d" % wax_floor_level) as Node2D
	if floor_node == null:
		# 场景里没有预置熔蜡层就用代码造一层，保证机制一定生效。
		floor_node = Node2D.new()
		floor_node.name = "WaxFloor%d" % wax_floor_level
		var area := Area2D.new()
		area.name = "HazardArea"
		area.set_script(load("res://scripts/boss/wax_hazard.gd"))
		area.collision_layer = 1 << 7   # layer 8 = hazard
		area.collision_mask = 1 << 1    # 检测玩家
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(arena_half_width * 1.6, 60.0)
		shape.shape = rect
		area.add_child(shape)
		floor_node.add_child(area)
		floor_node.position = Vector2(0.0, 40.0 * float(wax_floor_level))
		var visual := ColorRect.new()
		visual.color = Color(0.85, 0.62, 0.25, 0.35)
		visual.size = Vector2(arena_half_width * 1.6, 60.0)
		visual.position = -visual.size * 0.5
		floor_node.add_child(visual)
		host.add_child(floor_node)

	floor_node.visible = true
	wax_floor_advanced.emit(wax_floor_level)
	# 场地被蜡覆盖时，玩家可站的地方变少 —— 用视觉 + 伤害区域表达。
	AudioManager.play_sfx("wax_spray")


func _on_defeated() -> void:
	_clear_decoys()
	# 提示词【四十三】：击败莫里斯后蜡像馆部分融化，保留可以二次探索的部分。
	var host := get_parent()
	if host != null:
		for i in 3:
			var floor_node := host.get_node_or_null("WaxFloor%d" % (i + 1)) as Node2D
			if floor_node != null:
				floor_node.visible = false
	GameManager.complete_chapter(1)
