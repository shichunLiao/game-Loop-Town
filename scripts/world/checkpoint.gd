class_name Checkpoint
extends Area2D

## 存档点（路灯）。玩家进入范围并按互动键即记录检查点。
##
## 提示词【七】：普通死亡回到最近 CheckPoint。检查点写进 LoopManager，
## 由 SaveManager 统一落盘，本节点不碰文件。

signal checkpoint_activated(map_id: StringName, spawn_id: StringName)

## 本检查点对应的出生点 id。死亡重生时会回到这个 spawn。
@export var spawn_id: StringName = &"checkpoint_a"
## 是否要求玩家按互动键（false = 走进去自动记录）。
@export var requires_interact: bool = true
## 是否在激活时回复满血。
@export var heal_on_activate: bool = true
## 激活后播放的音效。
@export var activate_sfx: String = "pickup"
@export var interact_prompt: String = "在此休息"

var is_activated: bool = false

@onready var _sprite: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D
@onready var _glow: PointLight2D = get_node_or_null("PointLight2D") as PointLight2D


func _ready() -> void:
	add_to_group(&"checkpoint")
	collision_layer = 1 << 5   # layer 6 = interactable，让玩家的 InteractionArea 能找到
	collision_mask = 0
	body_entered.connect(_on_body_entered)
	_configure_shape()
	_refresh_visual()


func _configure_shape() -> void:
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		shape_node = CollisionShape2D.new()
		shape_node.name = "CollisionShape2D"
		add_child(shape_node)
	if shape_node.shape == null:
		var rect := RectangleShape2D.new()
		rect.size = Vector2(64.0, 96.0)
		shape_node.shape = rect


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group(&"player"):
		return
	if is_activated:
		return
	if requires_interact:
		# 提示由玩家的 InteractionArea 负责，这里不做事。
		return
	activate()


func can_interact() -> bool:
	return requires_interact and not is_activated


func get_interact_prompt() -> String:
	return interact_prompt


func interact(_player: Node) -> void:
	activate()


## 记录检查点。
func activate() -> void:
	if is_activated:
		return
	is_activated = true

	var map_id := &""
	if GameManager != null:
		map_id = GameManager.current_map_id
	LoopManager.set_checkpoint(map_id, spawn_id, global_position)

	if heal_on_activate:
		var player := get_tree().get_first_node_in_group(&"player")
		if player != null and player.has_method("heal"):
			player.call("heal", 9999)
		var players := get_tree().get_nodes_in_group(&"player")
		for node in players:
			var health := node.get_node_or_null("HealthComponent") as HealthComponent
			if health != null:
				health.heal(health.max_health)

	AudioManager.play_sfx(activate_sfx)
	_refresh_visual()
	checkpoint_activated.emit(map_id, spawn_id)


func _refresh_visual() -> void:
	# 视觉反馈：激活后灯更亮、颜色更暖。没有贴图也不报错。
	if _glow != null:
		_glow.energy = 1.6 if is_activated else 0.9
		_glow.color = Color(1.0, 0.78, 0.42) if is_activated else Color(0.85, 0.72, 0.55)
	if _sprite != null:
		_sprite.modulate = Color(1.0, 0.96, 0.88) if is_activated else Color(0.78, 0.78, 0.82)
