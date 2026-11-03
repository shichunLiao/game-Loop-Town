class_name PlayerController
extends Actor

## 玩家角色（提示词【四】【五】【六】）。
##
## 手感优先（提示词【五】：移动手感明显优先于复杂系统）：
##   - 土狼时间（coyote time）：离开平台后仍可短暂起跳
##   - 跳跃缓冲（jump buffer）：落地前提前按跳会记住
##   - 可变跳跃高度：松开跳跃键立刻削弱上升速度
##   - 加/减速度分离：起速快、停步更干脆，绝不漂移
##
## 结构：本脚本只管“装配 + 输入转发”。所有具体行为在 StateMachine 的状态里，
## 满足提示词【二十七】第 2 条（不允许所有系统堆到 Player.gd）。

signal attacked(direction_name: StringName)
signal interacted(target: Node)
signal damaged_event(info: DamageInfo)
signal died_event
signal respawn_requested

const GROUP_PLAYER: StringName = &"player"

# --- 移动 ---
@export_group("移动")
@export var move_speed: float = 250.0
@export var acceleration: float = 2400.0
@export var deceleration: float = 3000.0
@export var air_acceleration: float = 1500.0
@export var air_deceleration: float = 900.0

@export_group("跳跃")
@export var jump_velocity: float = 620.0
## 最大下落速度，避免高速坠落穿过薄地板。
@export var max_fall_speed: float = 1100.0
## 土狼时间（秒）。
@export var coyote_time: float = 0.11
## 跳跃输入缓冲（秒）。
@export var jump_buffer_time: float = 0.12
## 松开跳跃键时的上升速度上限（可变跳跃高度）。
@export var jump_cut_multiplier: float = 0.42
## 跳跃提前松开后，速度高于该值时立刻削到该值。
@export var jump_release_speed: float = 220.0

@export_group("战斗")
@export var max_health: int = 100
## 一段连击最多几刀，之后必须等后摇结束。
@export var combo_length: int = 3
@export var attack_damage: int = 12
@export var attack_knockback: float = 260.0
@export var attack_hit_stop: float = 0.07
## 击中敌人时玩家自身受到的反向推力（打击感）。
@export var attack_recoil: float = 90.0
## 攻击判定框中心相对角色中心向前的伸出距离。
## 与 HitBox 的形状尺寸共同决定有效攻击范围，改这一个值就能调手感。
@export var attack_reach: float = 42.0

@export_group("交互")
@export var interact_radius: float = 56.0

# --- 运行时状态 ---
var can_move: bool = true
var can_attack: bool = true
## 剧情需要时锁住输入（对话、过场）。
var input_locked: bool = false

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var attack_buffer_timer: float = 0.0
var combo_index: int = 0
var combo_reset_timer: float = 0.0
## 最近的攻击方向（用于方向攻击：前 / 后 / 斜上 / 斜下）。
var attack_direction: StringName = &"forward"
## 当前可交互目标。
var current_interactable: Node = null
## 已解锁能力（冲刺、攀爬为后期预留）。
var unlocked_abilities: Array[StringName] = []
## 上一帧的交互提示，避免每帧都去改 UI 文本。
var _last_interact_prompt: String = ""

@onready var camera: Camera2D = get_node_or_null("Camera2D") as Camera2D
@onready var interaction_area: Area2D = get_node_or_null("InteractionArea") as Area2D
@onready var attack_pivot: Node2D = get_node_or_null("AttackPivot") as Node2D

var _interaction_shape: CollisionShape2D = null
var _interactables_in_range: Array[Node] = []


func _after_ready() -> void:
	add_to_group(GROUP_PLAYER)
	if health != null:
		health.max_health = max_health
		health.current_health = SaveManager.get_player_health()
		if health.current_health <= 0:
			health.current_health = max_health
		health.health_changed.emit(health.current_health, health.max_health)
		health.damaged.connect(_on_player_damaged)
		health.heal(0)
	else:
		push_error("[PlayerController] 缺少 HealthComponent。")

	# 血量变化同步到 HUD（提示词【二十七】第 8 条：UI 不直接改游戏逻辑，
	# 但游戏逻辑可以单向地通知 UI）。
	if health != null:
		health.health_changed.connect(_on_health_changed_for_hud)
		_on_health_changed_for_hud(health.current_health, health.max_health)

	# 注册相机，让 CombatManager 的震屏能找到它。
	if camera != null:
		Combat.set_active_camera(camera)
		if camera.get_node_or_null("CameraShaker") == null:
			var shaker := CameraShaker.new()
			shaker.name = "CameraShaker"
			camera.add_child(shaker)

	_setup_interaction_area()
	Combat.force_clear_hit_stop()

	if state_machine != null:
		state_machine.setup(self)
	else:
		push_error("[PlayerController] 缺少 StateMachine。")


func _setup_interaction_area() -> void:
	if interaction_area == null:
		interaction_area = Area2D.new()
		interaction_area.name = "InteractionArea"
		add_child(interaction_area)
	interaction_area.collision_layer = 0
	interaction_area.collision_mask = 1 << 5  # layer 6 = interactable
	_interaction_shape = interaction_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if _interaction_shape == null:
		_interaction_shape = CollisionShape2D.new()
		_interaction_shape.name = "CollisionShape2D"
		interaction_area.add_child(_interaction_shape)
	var circle := CircleShape2D.new()
	circle.radius = interact_radius
	_interaction_shape.shape = circle
	interaction_area.area_entered.connect(_on_interaction_area_entered)
	interaction_area.area_exited.connect(_on_interaction_area_exited)


# ---------------------------------------------------------------------------
# 帧循环
# ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if GameManager.is_paused:
		return

	_update_timers(delta)

	if state_machine != null:
		state_machine.physics_update(delta)
	else:
		# 没有状态机时退化成最简移动，保证角色不会完全不动。
		_fallback_movement(delta)

	# 下落速度封顶。
	if velocity.y > max_fall_speed:
		velocity.y = max_fall_speed

	_update_interact_prompt()


## 交互提示：每帧同步到 HUD。放在玩家身上而不是 HUD 里，
## 因为「离哪个可交互物最近」只有玩家知道（提示词【二十七】第 8 条：UI 不改游戏逻辑）。
func _update_interact_prompt() -> void:
	var prompt := get_interact_prompt()
	if prompt == _last_interact_prompt:
		return
	_last_interact_prompt = prompt
	var hud := get_tree().get_first_node_in_group(&"game_hud")
	if hud == null or not hud.has_method("show_interact_prompt"):
		return
	hud.call("show_interact_prompt", prompt)


func _process(delta: float) -> void:
	if state_machine != null:
		state_machine.update(delta)


func _unhandled_input(event: InputEvent) -> void:
	if GameManager.is_paused:
		return
	# 对话进行中不把输入交给角色，避免一边说话一边挥刀。
	if DialogueManager != null and DialogueManager.is_active:
		return
	if state_machine != null:
		state_machine.handle_input(event)


func _update_timers(delta: float) -> void:
	if is_on_floor():
		coyote_timer = coyote_time
	else:
		coyote_timer = maxf(coyote_timer - delta, 0.0)

	if jump_buffer_timer > 0.0:
		jump_buffer_timer = maxf(jump_buffer_timer - delta, 0.0)
	if attack_buffer_timer > 0.0:
		attack_buffer_timer = maxf(attack_buffer_timer - delta, 0.0)
	if combo_reset_timer > 0.0:
		combo_reset_timer = maxf(combo_reset_timer - delta, 0.0)
		if combo_reset_timer <= 0.0:
			combo_index = 0


func _fallback_movement(delta: float) -> void:
	if not can_move or input_locked:
		velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
	else:
		var direction := get_move_input()
		velocity.x = move_toward(velocity.x, direction * move_speed, acceleration * delta)
		if not is_zero_approx(direction):
			set_facing(int(signf(direction)))
	apply_gravity_and_move(delta)


# ---------------------------------------------------------------------------
# 输入读取（状态通过公开方法读取，不自己调 Input，便于统一加锁）
# ---------------------------------------------------------------------------

func get_move_input() -> float:
	if input_locked or not can_move:
		return 0.0
	return Input.get_axis(&"move_left", &"move_right")


func get_vertical_input() -> float:
	if input_locked:
		return 0.0
	return Input.get_axis(&"move_up", &"move_down")


func is_jump_just_pressed() -> bool:
	if input_locked or not can_move:
		return false
	return Input.is_action_just_pressed(&"jump")


func is_jump_pressed() -> bool:
	if input_locked:
		return false
	return Input.is_action_pressed(&"jump")


func is_jump_just_released() -> bool:
	return Input.is_action_just_released(&"jump")


func is_attack_just_pressed() -> bool:
	if input_locked or not can_attack:
		return false
	return Input.is_action_just_pressed(&"attack")


func is_interact_just_pressed() -> bool:
	if input_locked:
		return false
	return Input.is_action_just_pressed(&"interact")


## 记录跳跃缓冲。
func buffer_jump() -> void:
	jump_buffer_timer = jump_buffer_time


func buffer_attack() -> void:
	attack_buffer_timer = jump_buffer_time


func has_buffered_jump() -> bool:
	return jump_buffer_timer > 0.0


func has_buffered_attack() -> bool:
	return attack_buffer_timer > 0.0


func consume_jump_buffer() -> void:
	jump_buffer_timer = 0.0


func consume_attack_buffer() -> void:
	attack_buffer_timer = 0.0


func can_use_coyote() -> bool:
	return coyote_timer > 0.0


func consume_coyote() -> void:
	coyote_timer = 0.0


## 方向攻击（提示词【五】：向前 / 向后 / 斜上 / 斜下）。
func read_attack_direction() -> StringName:
	var vertical := get_vertical_input()
	var horizontal := get_move_input()
	if vertical < -0.5:
		attack_direction = &"up" if absf(horizontal) < 0.5 else &"up_diagonal"
	elif vertical > 0.5 and not is_on_floor():
		attack_direction = &"down" if absf(horizontal) < 0.5 else &"down_diagonal"
	elif not is_zero_approx(horizontal) and signf(horizontal) != float(facing):
		attack_direction = &"back"
	else:
		attack_direction = &"forward"
	return attack_direction


## 把 HitBox 摆到对应方向。
##
## 坐标系要点（曾经在这里出过 bug）：
##   HitBox 是 Player 的子节点，HitBox/CollisionShape2D 又是 HitBox 的子节点。
##   因此形状的**世界位置 = Player + HitBox.position + CollisionShape2D.position**。
##   这里只改 HitBox.position，形状节点保持在原点，避免偏移被算两次。
func place_attack_hit_box(direction_name: StringName) -> void:
	if hit_box == null:
		return
	# 形状放在 HitBox 原点，伸出的距离全部由 HitBox.position 表达。
	var shape_node := hit_box.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node != null:
		shape_node.position = Vector2.ZERO

	var reach := attack_reach
	var offsets := {
		&"forward": Vector2(reach, -28.0),
		&"back": Vector2(-reach, -28.0),
		&"up": Vector2(0.0, -28.0 - reach),
		&"down": Vector2(0.0, -28.0 + reach),
		&"up_diagonal": Vector2(reach * 0.75, -28.0 - reach * 0.75),
		&"down_diagonal": Vector2(reach * 0.75, -28.0 + reach * 0.75),
	}
	var target: Vector2 = offsets.get(direction_name, Vector2(reach, -28.0))
	var x_sign := float(facing)
	if direction_name == &"back":
		x_sign = -float(facing)
	hit_box.position = Vector2(target.x * x_sign, target.y)


# ---------------------------------------------------------------------------
# 交互
# ---------------------------------------------------------------------------

func _on_interaction_area_entered(area: Area2D) -> void:
	var target := area.get_parent()
	if target == null:
		return
	if not target.has_method("interact"):
		return
	if _interactables_in_range.has(target):
		return
	_interactables_in_range.append(target)
	_refresh_interact_target()


func _on_interaction_area_exited(area: Area2D) -> void:
	var target := area.get_parent()
	if target == null:
		return
	_interactables_in_range.erase(target)
	_refresh_interact_target()


func _refresh_interact_target() -> void:
	# 选最近的一个，并且它当前可用。
	var best: Node = null
	var best_distance := INF
	for target in _interactables_in_range:
		if target == null or not is_instance_valid(target):
			continue
		if target.has_method("can_interact") and not bool(target.call("can_interact")):
			continue
		var target_position: Vector2 = (target as Node2D).global_position if target is Node2D else global_position
		var distance := global_position.distance_squared_to(target_position)
		if distance < best_distance:
			best_distance = distance
			best = target
	current_interactable = best
	# 目标变了立刻更新提示，不用等下一帧。
	_last_interact_prompt = ""
	_update_interact_prompt()


func try_interact() -> bool:
	if current_interactable == null or not is_instance_valid(current_interactable):
		return false
	if current_interactable.has_method("can_interact") and not bool(current_interactable.call("can_interact")):
		return false
	interacted.emit(current_interactable)
	if current_interactable.has_method("interact"):
		current_interactable.call("interact", self)
	return true


func get_interact_prompt() -> String:
	if current_interactable == null or not is_instance_valid(current_interactable):
		return ""
	if current_interactable.has_method("get_interact_prompt"):
		return str(current_interactable.call("get_interact_prompt"))
	return "互动"


# ---------------------------------------------------------------------------
# 攀爬
# ---------------------------------------------------------------------------

## 找出附近属于 &"climbable" 组的攀爬面。井壁藤蔓 / 钟楼机械都挂这个组。
func find_nearby_climbable(max_distance: float = 24.0) -> Area2D:
	var best: Area2D = null
	var best_distance := max_distance * max_distance
	for node in get_tree().get_nodes_in_group(&"climbable"):
		var area := node as Area2D
		if area == null or not is_instance_valid(area):
			continue
		var area_position := area.global_position
		# 用最近点而不是中心点，长条形的藤蔓墙才能正常判定。
		var shape_node := area.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if shape_node != null and shape_node.shape is RectangleShape2D:
			var half := (shape_node.shape as RectangleShape2D).size * 0.5
			var local := global_position - area_position
			var clamped := Vector2(
				clampf(local.x, -half.x, half.x),
				clampf(local.y, -half.y, half.y)
			)
			area_position = area_position + clamped
		var distance := global_position.distance_squared_to(area_position)
		if distance < best_distance:
			best_distance = distance
			best = area
	return best


## 是否处于可攀爬位置。状态机用它决定能否从 fall / jump 切入 climb。
func can_climb_here() -> bool:
	if not is_on_floor() and not is_on_wall():
		# 空中也可以抓藤蔓，所以不强制贴墙，只要附近有攀爬面。
		return find_nearby_climbable(22.0) != null
	return false


# ---------------------------------------------------------------------------
# 战斗
# ---------------------------------------------------------------------------

## 攻击起手。由 attack 状态在进入时调用。
func begin_attack() -> void:
	if hit_box == null:
		return
	var damage := attack_damage
	var knockback := attack_knockback

	# 手里拿着武器道具时用它的数值（例如大剪刀）。
	var weapon := _get_equipped_weapon()
	if weapon != null and weapon.attack_damage > 0:
		damage = weapon.attack_damage

	hit_box.configure(damage, knockback, attack_hit_stop)
	place_attack_hit_box(attack_direction)
	attacked.emit(attack_direction)


func _get_equipped_weapon() -> ItemData:
	# Demo 里只实现了大剪刀这一件武器，按持有情况自动生效。
	var scissors_path := "res://data/items/big_scissors.tres"
	if SaveManager.has_item(&"big_scissors") and ResourceLoader.exists(scissors_path):
		return load(scissors_path) as ItemData
	return null


## 攻击命中反馈（击中敌人时给玩家一点反作用力，强化打击感）。
func on_attack_landed(_target: Node, info: DamageInfo) -> void:
	Combat.on_hit_landed(info, _target_position(_target))
	if attack_recoil > 0.0 and not is_on_floor():
		velocity.x -= info.direction.x * attack_recoil
	elif attack_recoil > 0.0:
		velocity.x -= info.direction.x * attack_recoil * 0.35


func _target_position(target: Node) -> Vector2:
	if target is Node2D:
		return (target as Node2D).global_position
	return hit_box.global_position if hit_box != null else global_position


func _on_player_damaged(info: DamageInfo, _remaining: int) -> void:
	damaged_event.emit(info)
	if SaveManager != null:
		SaveManager.mark_dirty()


## 把血量推给 HUD。找不到 HUD 时安静跳过（例如地图单跑）。
func _on_health_changed_for_hud(current: int, maximum: int) -> void:
	if SaveManager != null:
		SaveManager.set_player_health(current, maximum)
	var hud := get_tree().get_first_node_in_group(&"game_hud")
	if hud != null and hud.has_method("set_health"):
		hud.call("set_health", current, maximum)


func on_died() -> void:
	died_event.emit()
	LoopManager.register_death()
	if SaveManager != null:
		SaveManager.set_player_health(0, max_health)


func on_revived() -> void:
	var health_value := SaveManager.get_player_max_health()
	if health != null:
		health.revive(health_value)
		coyote_timer = 0.0
		jump_buffer_timer = 0.0
		attack_buffer_timer = 0.0
		combo_index = 0


## 同步生命值到 SaveManager，切图后不丢血。
func persist_health() -> void:
	if health != null:
		SaveManager.set_player_health(health.current_health, health.max_health)


func add_ability(ability: StringName) -> void:
	if not unlocked_abilities.has(ability):
		unlocked_abilities.append(ability)


func has_ability(ability: StringName) -> bool:
	return unlocked_abilities.has(ability)


func lock_input(value: bool) -> void:
	input_locked = value
	if value:
		velocity.x = move_toward(velocity.x, 0.0, deceleration * 0.05)
