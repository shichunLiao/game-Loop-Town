class_name State
extends Node

## 状态基类。Player / Enemy / Boss 的状态机共用它。
##
## 约定：每个具体状态都是一个独立脚本，实现 enter/exit/physics_update/handle_input。
## 状态内部**不允许**直接操作角色节点的其它子系统，只能通过 [member owner_node] 暴露的
## 公开接口与信号，避免状态之间互相纠缠。

## 宿主节点（由 StateMachine 注入）。
var owner_node: Node = null

## 状态机本体。
var machine: StateMachine = null


## 进入该状态。上一个是哪个状态由参数给出，便于做“从跑动转为跳跃”这类衔接。
func enter(_previous_state: StringName = &"", _data: Dictionary = {}) -> void:
	pass


## 离开该状态。返回的字典会传给下一个状态的 enter 的 _data。
func exit() -> Dictionary:
	return {}


## 物理帧更新。返回非空 StringName 表示请求切换状态。
func physics_update(_delta: float) -> StringName:
	return &""


## 普通帧更新，用于动画与视觉反馈。
func update(_delta: float) -> void:
	pass


## 未处理的输入。返回非空 StringName 表示请求切换状态。
func handle_input(_event: InputEvent) -> StringName:
	return &""


## 该状态的名字，默认取脚本文件名（snake_case）。
func get_state_name() -> StringName:
	var script := get_script() as Script
	if script == null:
		return &""
	return StringName(script.resource_path.get_file().get_basename())


## 便捷访问宿主的常用能力（宿主必须实现对应方法，否则返回安全默认值）。
## 注意：方法名不能叫 get_velocity/set_velocity —— CharacterBody2D 已有同名原生方法，
## 覆盖它会导致脚本编译失败。
func get_actor_velocity() -> Vector2:
	if owner_node != null and owner_node.has_method("get_actor_velocity"):
		return owner_node.call("get_actor_velocity")
	return Vector2.ZERO


func set_actor_velocity(value: Vector2) -> void:
	if owner_node != null and owner_node.has_method("set_actor_velocity"):
		owner_node.call("set_actor_velocity", value)


func play_animation(animation_name: StringName, restart: bool = false) -> void:
	if owner_node != null and owner_node.has_method("play_animation"):
		owner_node.call("play_animation", animation_name, restart)
