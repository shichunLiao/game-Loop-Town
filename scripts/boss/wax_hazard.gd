class_name WaxHazard
extends Area2D

## 熔蜡覆盖区域（提示词【十三】PHASE 3：熔蜡炉过热，场地被蜡覆盖，安全平台越来越少）。
##
## 站在里面会持续受伤，并且累加“蜡化”计数：
## 被热蜡命中过多次就会 Wax_Death —— 玩家变成蜡像，然后循环回溯。
## 这里刻意做成**持续伤害**而不是秒杀，让玩家有机会往回跳。

## 每秒造成的伤害。
@export var damage_per_second: float = 22.0
## 两次伤害之间的间隔（秒）。
@export var tick_interval: float = 0.5
## 每次 tick 累加多少蜡化计数。
@export var wax_stacks_per_tick: int = 1
## 归属的莫里斯（用于累加蜡化计数）。
@export var morris_path: NodePath

var _tick_timer: float = 0.0
var _morris: Morris = null


func _ready() -> void:
	add_to_group(&"hazard")
	monitoring = true
	monitorable = false
	if morris_path != NodePath():
		_morris = get_node_or_null(morris_path) as Morris
	if _morris == null:
		var bosses := get_tree().get_nodes_in_group(&"boss")
		if not bosses.is_empty():
			_morris = bosses[0] as Morris
	queue_redraw()


func _process(delta: float) -> void:
	_tick_timer -= delta
	if _tick_timer > 0.0:
		return
	var player := _player_inside()
	if player == null:
		return
	_tick_timer = tick_interval
	_apply_tick(player)


func _player_inside() -> Node2D:
	for body in get_overlapping_bodies():
		if body.is_in_group(&"player"):
			return body as Node2D
	return null


func _apply_tick(player: Node2D) -> void:
	var hurt_box := player.get_node_or_null("HurtBox") as HurtBox
	if hurt_box == null:
		return
	var amount := maxi(int(round(damage_per_second * tick_interval)), 1)
	var info := DamageInfo.create(amount, _morris, Vector2.UP, 80.0)
	info.damage_type = &"wax"
	# 熔蜡不该给长无敌帧，否则站在里面几乎不掉血。
	info.invincible_time = tick_interval * 0.6
	if hurt_box.receive_hit(info):
		Combat.on_hit_landed(info, player.global_position)
		if _morris != null:
			# 持续伤害按较低权重累加，避免站在蜡里瞬间蜡化。
			if wax_stacks_per_tick > 0 and randf() < 0.5:
				_morris.register_wax_hit()


func _draw() -> void:
	# 程序化熔蜡：暖黄底 + 一层更亮的浮沫。
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null or not (shape_node.shape is RectangleShape2D):
		return
	var size := (shape_node.shape as RectangleShape2D).size
	var rect := Rect2(-size * 0.5, size)
	draw_rect(rect, Color(0.80, 0.55, 0.20, 0.42), true)
	draw_rect(rect.grow(-6.0), Color(0.95, 0.78, 0.38, 0.28), true)
