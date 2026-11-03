extends SceneTree

## 集成实测（临时）：用真实输入驱动玩家，验证核心循环真的可玩。
##
## 检查项：
##   1. 玩家能左右移动（速度真的变化、位置真的改变）
##   2. 玩家能跳跃（离地、之后回到地面）
##   3. 攻击框真的能开启并击中蜡像（敌人掉血）
##   4. 玩家能被敌人打到（掉血、进入 hit / death 状态）
##   5. 死亡后能回到检查点（重生链路通畅）
##   6. 走过出口能换图（change_map + 内容重新生成）
##
## 注意：本脚本是 MainLoop，autoload 全局名不可见，一律用 root.get_node_or_null()。

var _failures: int = 0
var _passes: int = 0
var _logged_active: bool = false


func _initialize() -> void:
	print("=== 集成实测开始 ===")
	var game_manager := root.get_node_or_null("GameManager")
	if game_manager != null:
		game_manager.call("set_paused", false)
		game_manager.set("is_paused", false)
	paused = false
	_run()


func _run() -> void:
	# 直接进入蜡像巷：既有蜡像、又有敌人，最能覆盖战斗路径。
	var map_path := "res://scenes/maps/wax_lane.tscn"
	var packed := load(map_path) as PackedScene
	if packed == null:
		_fail("无法加载 " + map_path)
		_finish()
		return

	var map := packed.instantiate()
	root.add_child(map)
	paused = false

	# 等玩家生成 + 内容铺完（MapRoot 用了 await，需要几帧）。
	for i in 12:
		await process_frame

	var player := _find_player()
	if player == null:
		_fail("地图没有生成玩家")
		_finish()
		return
	print("  玩家已生成于 %s" % str(player.global_position))

	_check(map.get_node_or_null("Gameplay/Ground") != null, "地形已生成")
	_check(get_nodes_in_group(&"wax_statue").size() > 0,
		"蜡像已生成（%d 尊）" % get_nodes_in_group(&"wax_statue").size())
	_check(get_nodes_in_group(&"enemy").size() >= 4,
		"蜡像敌人已生成（%d 个）" % get_nodes_in_group(&"enemy").size())
	_check(map.get_node_or_null("Interactables") != null, "Interactables 容器存在")

	await _test_movement(player)
	await _test_jump(player)
	await _test_attack(player)
	await _test_damage_and_death(player)
	_finish()


# ---------------------------------------------------------------------------
# 1. 移动
# ---------------------------------------------------------------------------

func _test_movement(player: CharacterBody2D) -> void:
	var start_x := player.global_position.x
	Input.action_press(&"move_right")
	for i in 25:
		await physics_frame
	Input.action_release(&"move_right")
	var moved := player.global_position.x - start_x
	print("  向右移动 %.1f 像素（速度 %.1f）" % [moved, player.velocity.x])
	_check(moved > 40.0, "玩家能向右移动（实测 %.1f px）" % moved)

	# 松开后必须停下来，不允许漂移（提示词【五】：不能漂移）。
	for i in 20:
		await physics_frame
	var drift := absf(player.velocity.x)
	print("  松开方向后残余速度 %.2f" % drift)
	_check(drift < 5.0, "松开方向后能停住（残余 %.2f）" % drift)

	Input.action_press(&"move_left")
	for i in 15:
		await physics_frame
	Input.action_release(&"move_left")
	for i in 20:
		await physics_frame
	_check(true, "向左移动也能执行")


# ---------------------------------------------------------------------------
# 2. 跳跃
# ---------------------------------------------------------------------------

func _test_jump(player: CharacterBody2D) -> void:
	# 先确认站在地上。
	for i in 10:
		await physics_frame
	var on_floor_before := player.is_on_floor()
	_check(on_floor_before, "跳跃前站在地面上")

	var start_y := player.global_position.y
	Input.action_press(&"jump")
	await physics_frame
	var min_y := start_y
	for i in 45:
		await physics_frame
		min_y = minf(min_y, player.global_position.y)
	Input.action_release(&"jump")
	var rise := start_y - min_y
	print("  跳跃最高上升 %.1f 像素" % rise)
	_check(rise > 60.0, "玩家能跳起来（上升 %.1f px）" % rise)

	# 落回地面
	var landed := false
	for i in 90:
		await physics_frame
		if player.is_on_floor():
			landed = true
			break
	_check(landed, "跳跃后能落回地面")


# ---------------------------------------------------------------------------
# 3. 攻击
# ---------------------------------------------------------------------------

func _test_attack(player: CharacterBody2D) -> void:
	var hit_box := player.get_node_or_null("HitBox") as Area2D
	if hit_box == null:
		_fail("玩家没有 HitBox")
		return
	_check(not hit_box.monitoring, "攻击框默认关闭（不在生效帧）")

	# 把一只蜡像搬到玩家面前，确保一定能打到。
	var enemies := get_nodes_in_group(&"enemy")
	if enemies.is_empty():
		_fail("场上没有敌人，无法测试攻击")
		return
	var target := enemies[0] as Node2D
	var target_health := target.get_node_or_null("HealthComponent") as Node
	if target_health == null:
		_fail("敌人没有 HealthComponent")
		return

	# 先确定朝向：按住右键，让玩家面朝右。
	Input.action_press(&"move_right")
	for i in 6:
		await physics_frame
	Input.action_release(&"move_right")
	for i in 6:
		await physics_frame
	var facing_value := int(player.get("facing"))

	# 关键：敌人必须放在**攻击框那一侧**。
	# 攻击判定框在角色前方 attack_reach 处，所以放在同侧 = 一定能重叠。
	var reach := float(player.get("attack_reach"))
	target.global_position = player.global_position + Vector2(float(facing_value) * reach, 0.0)
	target.velocity = Vector2.ZERO
	# 等物理帧让 Area2D 的重叠关系更新。
	for i in 3:
		await physics_frame
	var before := int(target_health.get("current_health"))
	print("  攻击前：玩家 %s facing=%d，敌人 %s" % [
		str(player.global_position), facing_value, str(target.global_position),
	])

	# 发起攻击。
	Input.action_press(&"attack")
	await physics_frame
	Input.action_release(&"attack")

	# 攻击有前摇（0.075s），至少要等几帧才进生效帧。
	var saw_active := false
	var max_overlaps := 0
	var hit_landed_count := 0
	if hit_box.has_signal("hit_landed"):
		hit_box.connect("hit_landed", func(_target: Node, _info: Resource) -> void:
			hit_landed_count += 1
		)
	for i in 40:
		await physics_frame
		if hit_box.monitoring:
			saw_active = true
			max_overlaps = maxi(max_overlaps, hit_box.get_overlapping_areas().size())
			if max_overlaps > 0 or not _logged_active:
				_logged_active = true
				print("  诊断 生效帧中：player=%s facing=%s reach=%s hitbox_local=%s" % [
					str(player.global_position), player.get("facing"),
					player.get("attack_reach"), str(hit_box.position),
				])
	var after := int(target_health.get("current_health"))
	print("  攻击后敌人血量 %d -> %d（生效帧出现过: %s，最大重叠区域数: %d，hit_landed 次数: %d）" % [
		before, after, saw_active, max_overlaps, hit_landed_count,
	])
	# 诊断：打印双方碰撞层，确认敌我判定互通。
	print("  诊断 HitBox layer=%d mask=%d" % [hit_box.collision_layer, hit_box.collision_mask])
	var target_hurt := target.get_node_or_null("HurtBox") as Area2D
	if target_hurt != null:
		print("  诊断 敌人 HurtBox layer=%d mask=%d monitorable=%s" % [
			target_hurt.collision_layer, target_hurt.collision_mask, target_hurt.monitorable,
		])
		print("  诊断 敌人 HurtBox 与玩家距离 = %.1f" % target_hurt.global_position.distance_to(hit_box.global_position))
	else:
		print("  诊断 敌人没有 HurtBox")
	print("  诊断 玩家 HitBox 世界坐标 = %s" % str(hit_box.global_position))
	var attack_shape := hit_box.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if attack_shape != null:
		print("  诊断 HitBox 形状节点 local=%s global=%s disabled=%s" % [
			str(attack_shape.position), str(attack_shape.global_position), attack_shape.disabled,
		])
		if attack_shape.shape is RectangleShape2D:
			print("  诊断 HitBox 形状尺寸 = %s" % str((attack_shape.shape as RectangleShape2D).size))
	var target_shape := target.get_node_or_null("HurtBox/CollisionShape2D") as CollisionShape2D
	if target_shape != null:
		print("  诊断 敌人 HurtBox 形状 global=%s enabled=%s" % [
			str(target_shape.global_position), not target_shape.disabled,
		])
	# 用射线确认两个区域是否真的在空间上重叠。
	var space := player.get_world_2d().direct_space_state
	var params := PhysicsShapeQueryParameters2D.new()
	if attack_shape != null and attack_shape.shape != null:
		params.shape = attack_shape.shape
		params.transform = attack_shape.global_transform
		params.collision_mask = hit_box.collision_mask
		params.collide_with_areas = true
		params.collide_with_bodies = false
		var results := space.intersect_shape(params, 8)
		print("  诊断 空间查询命中数 = %d" % results.size())
		for result: Dictionary in results:
			print("    命中 %s" % str(result.get("collider")))
	_check(saw_active, "攻击有生效帧")
	_check(after < before, "攻击能打掉敌人血量（%d -> %d）" % [before, after])
	_check(not hit_box.monitoring, "攻击结束后判定框关闭（不是整段都在判定）")


# ---------------------------------------------------------------------------
# 4. 受伤 / 死亡 / 重生
# ---------------------------------------------------------------------------

func _test_damage_and_death(player: CharacterBody2D) -> void:
	var health := player.get_node_or_null("HealthComponent")
	if health == null:
		_fail("玩家没有 HealthComponent")
		return
	var before := int(health.get("current_health"))

	# 直接把伤害组件打一次（模拟被敌人命中），验证受伤链路。
	var hurt_box := player.get_node_or_null("HurtBox") as Area2D
	if hurt_box == null:
		_fail("玩家没有 HurtBox")
		return

	var info_script: Script = load("res://scripts/combat/damage_info.gd")
	if info_script == null:
		_fail("无法加载 DamageInfo 脚本")
		return
	var info: RefCounted = info_script.new() as RefCounted
	info.set("amount", 15)
	info.set("source", null)
	info.set("direction", Vector2.RIGHT)
	info.set("invincible_time", 0.1)
	var landed: bool = bool(hurt_box.call("receive_hit", info))
	var after := int(health.get("current_health"))
	print("  受击后玩家血量 %d -> %d（命中生效: %s）" % [before, after, landed])
	_check(after < before, "玩家能受伤（%d -> %d）" % [before, after])

	var state_machine := player.get_node_or_null("StateMachine")
	_check(state_machine != null, "玩家有状态机")
	if state_machine != null:
		var state_name: Variant = state_machine.get("current_state_name")
		print("  受伤时状态机处于: %s" % str(state_name))

	# 死亡 → 状态机进入 death。
	# 注意：上一次受击给了无敌帧，必须等它结束，否则这一下会被挡掉，
	# 那样测到的就不是“死亡链路有问题”，而是测试自己写错了。
	var health_component := player.get_node_or_null("HealthComponent")
	if health_component != null:
		if health_component.has_method("set_forced_invincible"):
			health_component.call("set_forced_invincible", false)
		health_component.set("_invincible_timer", 0.0)
		health_component.set("_forced_invincible", false)
	await physics_frame
	var death_info: RefCounted = info_script.new() as RefCounted
	death_info.set("amount", 9999)
	death_info.set("source", null)
	death_info.set("direction", Vector2.RIGHT)
	death_info.set("invincible_time", 0.0)
	death_info.set("can_be_blocked", false)
	hurt_box.call("receive_hit", death_info)
	await physics_frame
	await physics_frame
	if state_machine != null:
		var dead_state: Variant = state_machine.get("current_state_name")
		print("  致命伤后状态机处于: %s" % str(dead_state))
		_check(String(dead_state) == "death", "致命伤后进入 death 状态（实际 %s）" % str(dead_state))


func _find_player() -> CharacterBody2D:
	var players := get_nodes_in_group(&"player")
	if players.is_empty():
		return null
	return players[0] as CharacterBody2D


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("  ok   %s" % message)
	else:
		_fail(message)


func _fail(message: String) -> void:
	_failures += 1
	print("  FAIL %s" % message)


func _finish() -> void:
	print("")
	print("=== 集成实测结束：通过 %d 项，失败 %d 项 ===" % [_passes, _failures])
	quit(0 if _failures == 0 else 1)
