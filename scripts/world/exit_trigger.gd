class_name ExitTrigger
extends Area2D

## 地图出口（提示词【二十五】：每张地图都有 Exit）。
##
## 走进范围即换图。条件不满足时显示 locked_message，
## 例如「剧院大门锁着。」——这条提示本身就是环境叙事。

## 出口 id，必须与地图 .tres 的 MapData.ExitLink.exit_id 对应。
@export var exit_id: StringName = &"east"
## 是否要求按互动键（false = 走进去自动触发）。
@export var requires_interact: bool = false
## 触发提示。
@export var interact_prompt: String = "前往"
## 是否显示一个方向箭头提示。
@export var show_marker: bool = true

var _used: bool = false

@onready var _marker: Node2D = get_node_or_null("Marker") as Node2D


func _ready() -> void:
	add_to_group(&"exit")
	collision_layer = 1 << 5   # interactable：让玩家的 InteractionArea 也能发现它
	collision_mask = 1 << 1    # 检测玩家本体
	body_entered.connect(_on_body_entered)
	_ensure_shape()
	if _marker != null:
		_marker.visible = show_marker


func _ensure_shape() -> void:
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node != null and shape_node.shape != null:
		return
	if shape_node == null:
		shape_node = CollisionShape2D.new()
		shape_node.name = "CollisionShape2D"
		add_child(shape_node)
	var rect := RectangleShape2D.new()
	rect.size = Vector2(48.0, 160.0)
	shape_node.shape = rect


func _on_body_entered(body: Node2D) -> void:
	if requires_interact:
		return
	if body.is_in_group(&"player"):
		_trigger()


func can_interact() -> bool:
	return requires_interact and not _used


func get_interact_prompt() -> String:
	return interact_prompt


func interact(_player: Node) -> void:
	_trigger()


func _trigger() -> void:
	if _used:
		return
	var map_root := _find_map_root()
	if map_root == null:
		push_warning("[ExitTrigger] 找不到 MapRoot，无法换图。")
		return
	var success: bool = bool(map_root.call("use_exit", exit_id, get_tree().get_first_node_in_group(&"player")))
	if success:
		_used = true


func _find_map_root() -> Node:
	var node: Node = get_parent()
	while node != null:
		if node.has_method("use_exit"):
			return node
		node = node.get_parent()
	return null
