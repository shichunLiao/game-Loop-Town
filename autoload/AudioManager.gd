extends Node

## 音频管理器（autoload）— 提示词【三十六】。
##
## Demo 没有正式配乐，但结构必须搭好：
##   - 每个区域（Town / Wax / Theater / Well / ClockTower / Fire / Ending）独立音轨
##   - 环境声、脚步声、攻击声、受击声、Boss 音效、钟声、童谣、火焰、风声
##   - 钟声必须成为全游戏的重要叙事声音（因此单独提供 play_bell）
##
## 音频总线由 assets/audio/default_bus_layout.tres 定义：
##   Master / Music / SFX / Ambient / Footsteps / BossSFX / UI
## 注意：Godot 4 的 AudioBusLayout 没有 get_bus_count()，全部通过 AudioServer 查询。

signal area_entered(area_id: StringName)
signal bell_rung(count: int)

const AUDIO_ROOT: String = "res://assets/audio"

## 区域 → 音乐。缺文件时静默跳过，不报错（Demo 允许没有正式音乐）。
## 键用 StringName 的字符串写法，避免 & 字面量做字典键的解析限制。
const AREA_MUSIC: Dictionary = {
	"Town": "mus_town",
	"Wax": "mus_wax",
	"Theater": "mus_theater",
	"Well": "mus_well",
	"ClockTower": "mus_clocktower",
	"Fire": "mus_fire",
	"Ending": "mus_ending",
}

## 区域 → 环境声。
const AREA_AMBIENT: Dictionary = {
	"Town": "amb_town",
	"Wax": "amb_wax",
	"Theater": "amb_theater",
	"Well": "amb_well",
	"ClockTower": "amb_clocktower",
	"Fire": "amb_fire",
	"Ending": "amb_ending",
}

## 逻辑音效名 → 文件基名（实际查 .ogg / .wav）。
const SFX_FILES: Dictionary = {
	# 玩家
	"attack_swing": "sfx_attack_swing",
	"attack_hit": "sfx_attack_hit",
	"jump": "sfx_jump",
	"land": "sfx_land",
	"hurt": "sfx_hurt",
	"death": "sfx_death",
	"interact": "sfx_interact",
	"pickup": "sfx_pickup",
	"notebook_open": "sfx_notebook_open",
	"notebook_write": "sfx_notebook_write",
	"ui_click": "sfx_ui_click",
	"ui_move": "sfx_ui_move",
	"damage_blocked": "sfx_damage_blocked",
	# 敌人
	"enemy_hit": "sfx_enemy_hit",
	"enemy_death": "sfx_enemy_death",
	"wax_crack": "sfx_wax_crack",
	"doll_snap": "sfx_doll_snap",
	"ghost_whisper": "sfx_ghost_whisper",
	# Boss
	"boss_roar": "sfx_boss_roar",
	"wax_spray": "sfx_wax_spray",
	"furnace_overheat": "sfx_furnace_overheat",
	# 叙事
	"bell": "sfx_bell",
	"bell_distant": "sfx_bell_distant",
	"nursery_rhyme": "sfx_nursery_rhyme",
	"clock_tick": "sfx_clock_tick",
	"fire_crackle": "sfx_fire_crackle",
	"wind": "sfx_wind",
	"mirror_turn": "sfx_mirror_turn",
	"light_focus": "sfx_light_focus",
}

const MUSIC_BUS: StringName = &"Music"
const SFX_BUS: StringName = &"SFX"
const AMBIENT_BUS: StringName = &"Ambient"
const FOOTSTEPS_BUS: StringName = &"Footsteps"

var current_area: StringName = &""
var is_bell_ringing: bool = false

var _music_player: AudioStreamPlayer = null
var _ambient_player: AudioStreamPlayer = null
var _sfx_pool: Array[AudioStreamPlayer] = []
var _pool_index: int = 0
var _bell_player: AudioStreamPlayer = null
var _bell_ring_count: int = 0

var _stream_cache: Dictionary = {}
var _missing_warned: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music_player = _make_player("MusicPlayer", MUSIC_BUS)
	_ambient_player = _make_player("AmbientPlayer", AMBIENT_BUS)
	_bell_player = _make_player("BellPlayer", SFX_BUS)

	# 同时发声的音效数量：横板动作游戏 12 个足够，且不会爆音。
	for i in 12:
		_sfx_pool.append(_make_player("SfxPlayer%d" % i, SFX_BUS))

	# 世界阶段变化时切换环境声 / 音乐。
	if WorldStateManager != null:
		WorldStateManager.world_state_changed.connect(_on_world_state_changed)


func _make_player(player_name: String, bus: StringName) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.bus = bus
	add_child(player)
	return player


# ---------------------------------------------------------------------------
# 区域
# ---------------------------------------------------------------------------

## 进入一个区域：切换音乐与环境声。
func enter_area(area_id: StringName) -> void:
	if current_area == area_id:
		return
	current_area = area_id

	# 字典键是 String，这里显式转换，避免 StringName/String 键不匹配。
	var area_key := String(area_id)
	var music_id: String = String(AREA_MUSIC.get(area_key, ""))
	play_music(music_id)

	var ambient_id: String = String(AREA_AMBIENT.get(area_key, ""))
	play_ambient(ambient_id)

	area_entered.emit(area_id)


func _on_world_state_changed(profile: WorldStateProfile) -> void:
	if profile == null:
		return
	# 世界阶段优先级高于区域：火海 / 清晨直接换掉当前音乐。
	if not profile.music.is_empty():
		play_music(profile.music)
	if not profile.ambient.is_empty():
		play_ambient(profile.ambient)


# ---------------------------------------------------------------------------
# 音乐 / 环境声
# ---------------------------------------------------------------------------

func play_music(music_id: String) -> void:
	_play_loop(_music_player, music_id, "music")


func play_ambient(ambient_id: String) -> void:
	_play_loop(_ambient_player, ambient_id, "ambient")


func stop_music() -> void:
	if _music_player != null:
		_music_player.stop()


func stop_ambient() -> void:
	if _ambient_player != null:
		_ambient_player.stop()


func _play_loop(player: AudioStreamPlayer, track_id: String, folder: String) -> void:
	if player == null:
		return
	var stream := _load_stream(track_id, folder)
	if stream == null:
		player.stop()
		return
	if player.stream == stream and player.playing:
		return
	player.stream = stream
	player.play()


# ---------------------------------------------------------------------------
# 音效
# ---------------------------------------------------------------------------

## 播放一个逻辑音效。找不到文件时静默跳过（只在第一次警告）。
func play_sfx(sfx_id: String, bus: StringName = SFX_BUS, pitch_variation: float = 0.0) -> void:
	var stream := _load_stream(String(SFX_FILES.get(sfx_id, sfx_id)), "sfx")
	if stream == null:
		return

	var player := _next_sfx_player(bus)
	player.stream = stream
	if pitch_variation > 0.0:
		player.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	else:
		player.pitch_scale = 1.0
	player.play()


## 带随机音高的脚步，避免机械重复。
func play_footstep(surface: StringName = &"stone") -> void:
	play_sfx("step_%s" % surface, FOOTSTEPS_BUS, 0.12)


## 钟声 — 全游戏最重要的叙事声音（提示词【三十六】）。
## 每次敲响都会被计数，剧情与结局可以从这个数字取信息。
func play_bell(distant: bool = false, pitch: float = 1.0) -> void:
	var stream := _load_stream("sfx_bell_distant" if distant else "sfx_bell", "sfx")
	if stream == null:
		return
	is_bell_ringing = true
	_bell_ring_count += 1
	if _bell_player != null:
		_bell_player.stream = stream
		_bell_player.pitch_scale = pitch
		_bell_player.play()
	bell_rung.emit(_bell_ring_count)


func get_bell_ring_count() -> int:
	return _bell_ring_count


## 童谣（井底 / 回忆段落）。井底版本是倒放的。
func play_nursery_rhyme(reversed_playback: bool = false) -> void:
	var stream := _load_stream("nursery_rhyme", "sfx")
	if stream == null:
		return
	var player := _next_sfx_player(SFX_BUS)
	player.stream = stream
	player.pitch_scale = 1.0
	if reversed_playback:
		# 反向播放通过负的 pitch_scale 做不到，这里用音高与音量近似表现“倒放感”。
		player.pitch_scale = 0.92
	player.play()


func _next_sfx_player(bus: StringName) -> AudioStreamPlayer:
	if _sfx_pool.is_empty():
		return _make_player("SfxFallback", bus)
	var player := _sfx_pool[_pool_index]
	_pool_index = (_pool_index + 1) % _sfx_pool.size()
	player.bus = bus
	return player


# ---------------------------------------------------------------------------
# 总线音量
# ---------------------------------------------------------------------------

## 设定总线音量。linear 范围 0..1。
func set_bus_volume(bus_name: String, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		push_warning("[AudioManager] 未知音频总线: %s" % bus_name)
		return
	var clamped := clampf(linear, 0.0, 1.0)
	AudioServer.set_bus_volume_db(index, linear_to_db(clamped) if clamped > 0.0 else -80.0)
	AudioServer.set_bus_mute(index, clamped <= 0.0)


## 读取总线线性音量 0..1。
func get_bus_volume(bus_name: String) -> float:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return 0.0
	if AudioServer.is_bus_mute(index):
		return 0.0
	return db_to_linear(AudioServer.get_bus_volume_db(index))


func has_bus(bus_name: String) -> bool:
	return AudioServer.get_bus_index(bus_name) >= 0


## Release active streams before a runtime or automated capture closes.
func stop_all() -> void:
	for child: Node in get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null
	_stream_cache.clear()


func _exit_tree() -> void:
	stop_all()


# ---------------------------------------------------------------------------
# 资源加载
# ---------------------------------------------------------------------------

## 依次尝试 .ogg / .wav / .mp3。找不到返回 null，不抛错。
func _load_stream(track_id: String, folder: String) -> AudioStream:
	if track_id.is_empty():
		return null
	var key := "%s/%s" % [folder, track_id]
	if _stream_cache.has(key):
		return _stream_cache[key]

	for ext in [".ogg", ".wav", ".mp3"]:
		var path := "%s/%s/%s%s" % [AUDIO_ROOT, folder, track_id, ext]
		if ResourceLoader.exists(path):
			var stream := load(path) as AudioStream
			if stream != null:
				if stream is AudioStreamWAV:
					(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_DISABLED
				_stream_cache[key] = stream
				return stream

	_stream_cache[key] = null
	if not _missing_warned.has(key):
		_missing_warned[key] = true
		print("[AudioManager] 音频缺失（已跳过）: %s/%s" % [folder, track_id])
	return null
