class_name BossBase
extends EnemyBase

## Boss 基类 — 提示词【二十七】第 6 条：Boss 状态必须使用状态机。
##
## Boss 与普通敌人的三个关键区别都收在这里：
##   1. **分阶段**：phase 变化广播给 HUD（血条分段）与状态机（换招式）
##   2. **竞技场**：进入 Boss 房后锁门、限制玩家活动范围、调整相机
##   3. **强制受击反馈**：提示词【六】明确要求 Boss 必须有受击反馈
##
## 具体招式写在各自 Boss 的状态脚本里，本类不写任何 if/else 招式分支。

signal boss_engaged(boss_id: StringName)
signal phase_changed(boss_id: StringName, phase: int)
signal boss_hit(boss_id: StringName, remaining_ratio: float)
signal boss_defeated_signal(boss_id: StringName)

## Boss 标识，用于 LoopManager 的 boss_progress。
@export var boss_id: StringName = &"boss"
## 总阶段数。
@export var total_phases: int = 3
## 每个阶段的血量阈值（占总血量的比例，从高到低）。
## 例如 [0.66, 0.33] 表示血量降到 66% 进二阶段、33% 进三阶段。
@export var phase_thresholds: PackedFloat32Array = PackedFloat32Array([0.66, 0.33])
## 竞技场半宽（玩家不能跑出这个范围）。
@export var arena_half_width: float = 780.0
## 是否在战斗开始时锁住出口。
@export var lock_arena: bool = true
## 击败后是否留在场上（用于剧情演出）。
@export var linger_after_death: bool = true
## 战斗开始时的对白。
@export_file("*.tres") var intro_dialogue_path: String = ""
## 被击败时的对白。
@export_file("*.tres") var defeat_dialogue_path: String = ""

var current_phase: int = 1
var is_engaged: bool = false
var arena_center: Vector2 = Vector2.ZERO

var _arena_locked: bool = false
var _phase_thresholds_sorted: Array[float] = []


func _after_ready() -> void:
	add_to_group(&"boss")
	enemy_id = boss_id
	# Boss 的死亡不移除自身，交给剧情决定。
	remove_on_death = false
	super._after_ready()

	arena_center = global_position
	# 阈值从高到低排序，便于顺序推进阶段。
	_phase_thresholds_sorted.clear()
	for value in phase_thresholds:
		_phase_thresholds_sorted.append(value)
	_phase_thresholds_sorted.sort()
	_phase_thresholds_sorted.reverse()

	if health != null:
		health.damaged.connect(_on_boss_damaged)
		health.died.connect(_on_boss_health_died)

	current_phase = 1
	LoopManager.set_boss_phase(boss_id, current_phase)


# ---------------------------------------------------------------------------
# 交战
# ---------------------------------------------------------------------------

## 由地图的 BossArena 触发，或玩家进入范围时自动触发。
func engage() -> void:
	if is_engaged or is_dead:
		return
	is_engaged = true
	if lock_arena:
		_lock_arena(true)
	if stats_multiplier_for_phase() > 1.0:
		_apply_phase_stats()
	boss_engaged.emit(boss_id)
	AudioManager.play_sfx("boss_roar")

	if not intro_dialogue_path.is_empty():
		DialogueManager.start_from_path(intro_dialogue_path)


func _lock_arena(locked: bool) -> void:
	_arena_locked = locked
	for node in get_tree().get_nodes_in_group(&"arena_gate"):
		if node is Node2D:
			(node as Node2D).visible = locked
			if node.has_method("set_gate_closed"):
				node.call("set_gate_closed", locked)
				continue
			# 没有自定义实现的普通门：直接开关它的碰撞体。
			for child in node.get_children():
				var static_body := child as StaticBody2D
				if static_body != null:
					for shape_owner in static_body.get_children():
						var shape := shape_owner as CollisionShape2D
						if shape != null:
							shape.set_deferred("disabled", not locked)


func is_arena_locked() -> bool:
	return _arena_locked


# ---------------------------------------------------------------------------
# 阶段
# ---------------------------------------------------------------------------

## 当前阶段的速度 / 伤害倍率。子类可重写做更细腻的曲线。
func stats_multiplier_for_phase() -> float:
	return 1.0 + 0.1 * float(current_phase - 1)


func _on_boss_damaged(info: DamageInfo, _remaining: int) -> void:
	# 提示词【六】：Boss 必须有受击反馈。除了基类的闪白，再加一点震屏与音效。
	AudioManager.play_sfx("enemy_hit")
	var ratio := health.get_health_ratio() if health != null else 1.0
	boss_hit.emit(boss_id, ratio)
	_evaluate_phase(ratio)


func _evaluate_phase(ratio: float) -> void:
	var previous := current_phase
	var target_phase := 1
	for index in _phase_thresholds_sorted.size():
		if ratio <= _phase_thresholds_sorted[index]:
			target_phase = index + 2
	if target_phase > total_phases:
		target_phase = total_phases
	if target_phase != previous:
		current_phase = target_phase
		LoopManager.set_boss_phase(boss_id, current_phase)
		_apply_phase_stats()
		_on_phase_enter(current_phase)
		phase_changed.emit(boss_id, current_phase)


func _apply_phase_stats() -> void:
	var multiplier := stats_multiplier_for_phase()
	move_speed = _base_move_speed() * multiplier
	attack_damage = int(round(float(_base_attack_damage()) * multiplier))
	if hurt_box != null:
		# 提示词【十三】皮埃罗「速度提升、防御降低」：用受伤倍率表达防御。
		hurt_box.set_damage_multiplier(defense_multiplier_for_phase())


## 子类重写：各阶段的基础速度 / 伤害 / 防御倍率。
func _base_move_speed() -> float:
	return move_speed


func _base_attack_damage() -> int:
	return attack_damage


func defense_multiplier_for_phase() -> float:
	return 1.0


## 子类重写：进入某阶段的表现（换招式、召唤、场地变化）。
func _on_phase_enter(_phase: int) -> void:
	pass


## 供状态机查询：当前是否允许使用某个招式。
func phase_at_least(phase: int) -> bool:
	return current_phase >= phase


# ---------------------------------------------------------------------------
# 死亡
# ---------------------------------------------------------------------------

func _on_boss_health_died(_info: DamageInfo) -> void:
	is_dead = true
	if hit_box != null:
		hit_box.deactivate()
	if hurt_box != null:
		hurt_box.set_deferred("monitorable", false)
	if _arena_locked:
		_lock_arena(false)

	LoopManager.mark_boss_defeated(boss_id)
	boss_defeated_signal.emit(boss_id)
	AudioManager.play_sfx("boss_roar")
	AudioManager.play_bell()

	if not defeat_dialogue_path.is_empty():
		DialogueManager.start_from_path(defeat_dialogue_path)

	_on_defeated()


## 子类重写：死亡演出（消散、掉落、开门）。
func _on_defeated() -> void:
	if not linger_after_death and is_instance_valid(self):
		queue_free()


## Boss 默认不通过 EnemyBase.on_died 走通用掉落。
func on_died() -> void:
	pass


# ---------------------------------------------------------------------------
# 竞技场限制
# ---------------------------------------------------------------------------

## 给玩家用的边界钳制。BossArena 每帧调用。
func clamp_to_arena(position: Vector2) -> Vector2:
	if not _arena_locked:
		return position
	var min_x := arena_center.x - arena_half_width
	var max_x := arena_center.x + arena_half_width
	return Vector2(clampf(position.x, min_x, max_x), position.y)


## 玩家是否已经进入竞技场（用于自动开战）。
func is_player_inside_arena() -> bool:
	if not is_target_valid():
		return false
	var distance := absf((target as Node2D).global_position.x - arena_center.x)
	return distance <= arena_half_width * 0.8
