class_name CombatManager
extends Node

## 战斗表现与规则中枢（autoload）— 提示词【二十八】。
##
## 统一管理：Damage / Knockback / Invincible / HitStop / HitEffect / ScreenShake。
## 任何状态、任何 Boss 都只调用这里的接口，绝不自建一套顿帧 / 震屏逻辑。
##
## 顿帧实现说明：用 Engine.time_scale 实现真正的全局定帧（比逐个节点暂停更跟手），
## 但必须保证即使游戏暂停也要能恢复，所以本节点 process_mode = ALWAYS。

signal hit_stop_started(duration: float)
signal hit_stop_ended
signal screen_shake_requested(strength: float)

## 全局顿帧上限。连续命中时取较大值，不叠加成卡死。
const MAX_HIT_STOP: float = 0.25

## 当前的顿帧计时（已被 time_scale 放慢，因此用真实时间递减）。
var _hit_stop_remaining: float = 0.0
var _hit_stop_active: bool = false
var _default_time_scale: float = 1.0

## 需要屏幕震动的相机。玩家相机会在进入场景时注册自己。
var _active_camera: Camera2D = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_default_time_scale = Engine.time_scale


func _process(delta: float) -> void:
	# delta 已经被 time_scale 缩放；顿帧期间我们用真实帧时间推进。
	if not _hit_stop_active:
		return
	var real_delta := delta
	if Engine.time_scale > 0.0:
		real_delta = delta / Engine.time_scale
	_hit_stop_remaining -= real_delta
	if _hit_stop_remaining <= 0.0:
		_end_hit_stop()


# ---------------------------------------------------------------------------
# 顿帧
# ---------------------------------------------------------------------------

## 请求一次顿帧。duration 会被夹到 MAX_HIT_STOP 以内。
func request_hit_stop(duration: float) -> void:
	if duration <= 0.0:
		return
	var clamped := minf(duration, MAX_HIT_STOP)
	if _hit_stop_active:
		# 已经在定帧：延长到较长的那个，不做乘法叠加。
		_hit_stop_remaining = maxf(_hit_stop_remaining, clamped)
		return
	_hit_stop_active = true
	_hit_stop_remaining = clamped
	Engine.time_scale = 0.0
	hit_stop_started.emit(clamped)


func _end_hit_stop() -> void:
	_hit_stop_active = false
	_hit_stop_remaining = 0.0
	Engine.time_scale = _default_time_scale
	hit_stop_ended.emit()


## 场景切换或退出时强制恢复，避免整个游戏定住。
func force_clear_hit_stop() -> void:
	if _hit_stop_active:
		_end_hit_stop()


func is_hit_stop_active() -> bool:
	return _hit_stop_active


# ---------------------------------------------------------------------------
# 屏幕震动
# ---------------------------------------------------------------------------

## 注册当前活跃相机。地图加载玩家时调用。
func set_active_camera(camera: Camera2D) -> void:
	_active_camera = camera


## 请求屏幕震动。strength 0..1。
func request_shake(strength: float, duration: float = 0.22) -> void:
	if strength <= 0.0:
		return
	screen_shake_requested.emit(strength)
	if _active_camera == null or not is_instance_valid(_active_camera):
		_active_camera = _find_player_camera()
	if _active_camera == null:
		return
	var shaker := _active_camera.get_node_or_null("CameraShaker")
	if shaker != null and shaker.has_method("shake"):
		shaker.call("shake", strength, duration)


func _find_player_camera() -> Camera2D:
	var players := get_tree().get_nodes_in_group(&"player")
	if players.is_empty():
		return null
	var player := players[0]
	if player is Node:
		var found := (player as Node).get_node_or_null("Camera2D")
		return found as Camera2D
	return null


# ---------------------------------------------------------------------------
# 命中表现
# ---------------------------------------------------------------------------

## 一次命中要触发的全部表现。状态与 Boss 只需调用这一个方法。
func on_hit_landed(info: DamageInfo, hit_position: Vector2) -> void:
	if info == null:
		return
	request_hit_stop(info.hit_stop)
	request_shake(info.shake)
	_spawn_hit_effect(hit_position, info.direction)
	AudioManager.play_sfx("attack_hit")


## 生成小命中特效。使用程序化生成的贴图，缺失时安静跳过。
func _spawn_hit_effect(hit_position: Vector2, direction: Vector2) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var effect := HitEffect.spawn(scene, hit_position, direction)
	if effect == null:
		return


## 受击闪白。给任何 CanvasItem 用。
func flash_white(target: CanvasItem, duration: float = 0.12) -> void:
	if target == null or not is_instance_valid(target):
		return
	var material := target.material
	if material is ShaderMaterial:
		var shader_material := material as ShaderMaterial
		shader_material.set_shader_parameter("flash_amount", 1.0)
		var tween := create_tween()
		tween.tween_method(
			func(value: float) -> void:
				shader_material.set_shader_parameter("flash_amount", value),
			1.0, 0.0, duration
		)
		return

	# 没有闪白材质时退化为快速提亮，保证“打到了”这件事一定有反馈。
	var original: Color = target.modulate
	var tween := create_tween()
	tween.tween_property(target, "modulate", Color(2.2, 2.2, 2.2, original.a), duration * 0.35)
	tween.tween_property(target, "modulate", original, duration * 0.65)
