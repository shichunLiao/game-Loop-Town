class_name StateMachine
extends Node

## 通用状态机（提示词【二十七】第 6、7 条：Player 与 Boss 都必须用状态机）。
##
## 状态是子节点，节点名即状态名（snake_case）。切换状态用 change_state(&"run")。
## 提供调试用 history，便于 QA 复现“卡在某个状态”的问题。

signal state_changed(from_state: StringName, to_state: StringName)

## 初始状态名。留空则使用第一个子状态。
@export var initial_state: StringName = &""
## 是否把状态切换打进日志（开发期排查用）。
@export var debug_logging: bool = false

var current_state: State = null
var current_state_name: StringName = &""
var previous_state_name: StringName = &""
## 最近若干次状态切换，最新在末尾。
var history: Array[StringName] = []

var _states: Dictionary = {}
var _owner_node: Node = null


## 由宿主在 _ready 中调用，注入宿主并完成初始化。
func setup(owner_node_value: Node) -> void:
	_owner_node = owner_node_value
	_states.clear()
	for child in get_children():
		var state := child as State
		if state == null:
			continue
		state.owner_node = _owner_node
		state.machine = self
		_states[state.get_state_name()] = state

	var start_name := initial_state
	if start_name == &"" and not _states.is_empty():
		start_name = _states.keys()[0]
	if not _states.has(start_name):
		push_error("[StateMachine] 初始状态不存在: %s（可用: %s）" % [start_name, _states.keys()])
		return
	_transition_to(start_name, {})


func has_state(state_name: StringName) -> bool:
	return _states.has(state_name)


func get_state(state_name: StringName) -> State:
	return _states.get(state_name, null)


## 请求切换状态。相同状态会被忽略（除非 force）。
func change_state(state_name: StringName, data: Dictionary = {}, force: bool = false) -> void:
	if not force and state_name == current_state_name:
		return
	if not _states.has(state_name):
		push_error("[StateMachine] 未知状态: %s" % state_name)
		return
	_transition_to(state_name, data)


func _transition_to(state_name: StringName, data: Dictionary) -> void:
	var exit_data: Dictionary = {}
	if current_state != null:
		exit_data = current_state.exit()

	previous_state_name = current_state_name
	current_state_name = state_name
	current_state = _states[state_name]

	history.append(state_name)
	if history.size() > 32:
		history.remove_at(0)

	if debug_logging:
		print("[StateMachine] %s -> %s" % [previous_state_name, state_name])

	# 把上一状态的 exit 数据与调用方数据合并，exit 数据优先。
	var merged := data.duplicate()
	for key: Variant in exit_data.keys():
		merged[key] = exit_data[key]

	current_state.enter(previous_state_name, merged)
	state_changed.emit(previous_state_name, state_name)


func physics_update(delta: float) -> void:
	if current_state == null:
		return
	var next := current_state.physics_update(delta)
	if next != &"":
		change_state(next)


func update(delta: float) -> void:
	if current_state == null:
		return
	current_state.update(delta)


func handle_input(event: InputEvent) -> void:
	if current_state == null:
		return
	var next := current_state.handle_input(event)
	if next != &"":
		change_state(next)


func get_available_states() -> Array[StringName]:
	var out: Array[StringName] = []
	for key: Variant in _states.keys():
		out.append(StringName(key))
	return out
