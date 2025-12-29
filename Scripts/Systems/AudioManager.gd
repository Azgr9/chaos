# SCRIPT: AudioManager.gd
# AUTOLOAD: AudioManager
# LOCATION: res://Scripts/Systems/AudioManager.gd
# PURPOSE: Centralized audio management with pooling and categories

extends Node

# ============================================
# AUDIO CATEGORIES
# ============================================
enum SFXCategory {
	PLAYER_ATTACK,
	PLAYER_HIT,
	PLAYER_DASH,
	PLAYER_SKILL,
	ENEMY_ATTACK,
	ENEMY_HIT,
	ENEMY_DEATH,
	BOSS,
	UI,
	PICKUP,
	AMBIENT,
	MUSIC
}

# ============================================
# AUDIO BUS NAMES
# ============================================
const BUS_MASTER = "Master"
const BUS_SFX = "SFX"
const BUS_MUSIC = "Music"
const BUS_UI = "UI"

# ============================================
# SETTINGS
# ============================================
var master_volume: float = 1.0
var sfx_volume: float = 0.8
var music_volume: float = 0.6
var ui_volume: float = 0.9

# Pitch variation for natural sound
const PITCH_VARIATION: float = 0.1
const MAX_CONCURRENT_SOUNDS: int = 32

# Cooldown to prevent sound spam
var _sound_cooldowns: Dictionary = {}
const DEFAULT_COOLDOWN: float = 0.05

# ============================================
# SOUND DEFINITIONS
# ============================================
# These will be paths to audio files when you add them
# For now, they're placeholders that the system will skip if not found

const SOUNDS = {
	# Player sounds
	"sword_swing": { "path": "res://Assets/Audio/SFX/sword_swing.wav", "category": SFXCategory.PLAYER_ATTACK, "volume": 0.0, "pitch_variance": 0.15 },
	"sword_hit": { "path": "res://Assets/Audio/SFX/sword_hit.wav", "category": SFXCategory.PLAYER_ATTACK, "volume": 0.0, "pitch_variance": 0.1 },
	"staff_fire": { "path": "res://Assets/Audio/SFX/staff_fire.wav", "category": SFXCategory.PLAYER_ATTACK, "volume": -3.0, "pitch_variance": 0.1 },
	"player_hurt": { "path": "res://Assets/Audio/SFX/player_hurt.wav", "category": SFXCategory.PLAYER_HIT, "volume": 0.0, "pitch_variance": 0.1 },
	"player_dash": { "path": "res://Assets/Audio/SFX/dash.wav", "category": SFXCategory.PLAYER_DASH, "volume": -3.0, "pitch_variance": 0.05 },
	"skill_activate": { "path": "res://Assets/Audio/SFX/skill_activate.wav", "category": SFXCategory.PLAYER_SKILL, "volume": 0.0, "pitch_variance": 0.05 },

	# Weapon-specific sounds
	"katana_slash": { "path": "res://Assets/Audio/SFX/katana_slash.wav", "category": SFXCategory.PLAYER_ATTACK, "volume": 0.0, "pitch_variance": 0.1 },
	"hammer_slam": { "path": "res://Assets/Audio/SFX/hammer_slam.wav", "category": SFXCategory.PLAYER_ATTACK, "volume": 3.0, "pitch_variance": 0.05 },
	"axe_swing": { "path": "res://Assets/Audio/SFX/axe_swing.wav", "category": SFXCategory.PLAYER_ATTACK, "volume": 0.0, "pitch_variance": 0.1 },
	"rapier_thrust": { "path": "res://Assets/Audio/SFX/rapier_thrust.wav", "category": SFXCategory.PLAYER_ATTACK, "volume": -3.0, "pitch_variance": 0.15 },
	"scythe_sweep": { "path": "res://Assets/Audio/SFX/scythe_sweep.wav", "category": SFXCategory.PLAYER_ATTACK, "volume": 0.0, "pitch_variance": 0.1 },
	"spear_thrust": { "path": "res://Assets/Audio/SFX/spear_thrust.wav", "category": SFXCategory.PLAYER_ATTACK, "volume": -3.0, "pitch_variance": 0.1 },

	# Magic sounds
	"fire_cast": { "path": "res://Assets/Audio/SFX/fire_cast.wav", "category": SFXCategory.PLAYER_ATTACK, "volume": 0.0, "pitch_variance": 0.1 },
	"ice_cast": { "path": "res://Assets/Audio/SFX/ice_cast.wav", "category": SFXCategory.PLAYER_ATTACK, "volume": 0.0, "pitch_variance": 0.1 },
	"lightning_cast": { "path": "res://Assets/Audio/SFX/lightning_cast.wav", "category": SFXCategory.PLAYER_ATTACK, "volume": 0.0, "pitch_variance": 0.1 },
	"void_cast": { "path": "res://Assets/Audio/SFX/void_cast.wav", "category": SFXCategory.PLAYER_ATTACK, "volume": -3.0, "pitch_variance": 0.1 },
	"necro_summon": { "path": "res://Assets/Audio/SFX/necro_summon.wav", "category": SFXCategory.PLAYER_SKILL, "volume": 0.0, "pitch_variance": 0.05 },

	# Enemy sounds
	"enemy_hit": { "path": "res://Assets/Audio/SFX/enemy_hit.wav", "category": SFXCategory.ENEMY_HIT, "volume": -3.0, "pitch_variance": 0.2 },
	"enemy_death": { "path": "res://Assets/Audio/SFX/enemy_death.wav", "category": SFXCategory.ENEMY_DEATH, "volume": 0.0, "pitch_variance": 0.15 },
	"enemy_attack": { "path": "res://Assets/Audio/SFX/enemy_attack.wav", "category": SFXCategory.ENEMY_ATTACK, "volume": -3.0, "pitch_variance": 0.1 },
	"slime_death": { "path": "res://Assets/Audio/SFX/slime_death.wav", "category": SFXCategory.ENEMY_DEATH, "volume": 0.0, "pitch_variance": 0.2 },
	"archer_shoot": { "path": "res://Assets/Audio/SFX/arrow_shoot.wav", "category": SFXCategory.ENEMY_ATTACK, "volume": -3.0, "pitch_variance": 0.1 },
	"elite_spawn": { "path": "res://Assets/Audio/SFX/elite_spawn.wav", "category": SFXCategory.ENEMY_ATTACK, "volume": 3.0, "pitch_variance": 0.05 },
	"elite_death": { "path": "res://Assets/Audio/SFX/elite_death.wav", "category": SFXCategory.ENEMY_DEATH, "volume": 3.0, "pitch_variance": 0.05 },

	# Boss sounds
	"boss_intro": { "path": "res://Assets/Audio/SFX/boss_intro.wav", "category": SFXCategory.BOSS, "volume": 6.0, "pitch_variance": 0.0 },
	"boss_slam": { "path": "res://Assets/Audio/SFX/boss_slam.wav", "category": SFXCategory.BOSS, "volume": 6.0, "pitch_variance": 0.05 },
	"boss_charge": { "path": "res://Assets/Audio/SFX/boss_charge.wav", "category": SFXCategory.BOSS, "volume": 3.0, "pitch_variance": 0.05 },
	"boss_summon": { "path": "res://Assets/Audio/SFX/boss_summon.wav", "category": SFXCategory.BOSS, "volume": 3.0, "pitch_variance": 0.05 },
	"boss_phase": { "path": "res://Assets/Audio/SFX/boss_phase.wav", "category": SFXCategory.BOSS, "volume": 6.0, "pitch_variance": 0.0 },
	"boss_death": { "path": "res://Assets/Audio/SFX/boss_death.wav", "category": SFXCategory.BOSS, "volume": 6.0, "pitch_variance": 0.0 },

	# Status effect sounds
	"burn_tick": { "path": "res://Assets/Audio/SFX/burn_tick.wav", "category": SFXCategory.ENEMY_HIT, "volume": -6.0, "pitch_variance": 0.2 },
	"freeze": { "path": "res://Assets/Audio/SFX/freeze.wav", "category": SFXCategory.ENEMY_HIT, "volume": 0.0, "pitch_variance": 0.1 },
	"shock": { "path": "res://Assets/Audio/SFX/shock.wav", "category": SFXCategory.ENEMY_HIT, "volume": 0.0, "pitch_variance": 0.15 },
	"bleed_tick": { "path": "res://Assets/Audio/SFX/bleed_tick.wav", "category": SFXCategory.ENEMY_HIT, "volume": -6.0, "pitch_variance": 0.2 },

	# UI sounds
	"ui_click": { "path": "res://Assets/Audio/SFX/ui_click.wav", "category": SFXCategory.UI, "volume": -6.0, "pitch_variance": 0.05 },
	"ui_hover": { "path": "res://Assets/Audio/SFX/ui_hover.wav", "category": SFXCategory.UI, "volume": -9.0, "pitch_variance": 0.05 },
	"ui_confirm": { "path": "res://Assets/Audio/SFX/ui_confirm.wav", "category": SFXCategory.UI, "volume": -3.0, "pitch_variance": 0.0 },
	"ui_cancel": { "path": "res://Assets/Audio/SFX/ui_cancel.wav", "category": SFXCategory.UI, "volume": -3.0, "pitch_variance": 0.0 },
	"menu_open": { "path": "res://Assets/Audio/SFX/menu_open.wav", "category": SFXCategory.UI, "volume": -3.0, "pitch_variance": 0.0 },
	"menu_close": { "path": "res://Assets/Audio/SFX/menu_close.wav", "category": SFXCategory.UI, "volume": -3.0, "pitch_variance": 0.0 },

	# Pickup sounds
	"crystal_pickup": { "path": "res://Assets/Audio/SFX/crystal_pickup.wav", "category": SFXCategory.PICKUP, "volume": -3.0, "pitch_variance": 0.1 },
	"gold_pickup": { "path": "res://Assets/Audio/SFX/gold_pickup.wav", "category": SFXCategory.PICKUP, "volume": -3.0, "pitch_variance": 0.15 },
	"health_pickup": { "path": "res://Assets/Audio/SFX/health_pickup.wav", "category": SFXCategory.PICKUP, "volume": 0.0, "pitch_variance": 0.05 },
	"relic_pickup": { "path": "res://Assets/Audio/SFX/relic_pickup.wav", "category": SFXCategory.PICKUP, "volume": 3.0, "pitch_variance": 0.0 },
	"weapon_pickup": { "path": "res://Assets/Audio/SFX/weapon_pickup.wav", "category": SFXCategory.PICKUP, "volume": 0.0, "pitch_variance": 0.0 },

	# Game events
	"wave_start": { "path": "res://Assets/Audio/SFX/wave_start.wav", "category": SFXCategory.AMBIENT, "volume": 0.0, "pitch_variance": 0.0 },
	"wave_complete": { "path": "res://Assets/Audio/SFX/wave_complete.wav", "category": SFXCategory.AMBIENT, "volume": 3.0, "pitch_variance": 0.0 },
	"level_up": { "path": "res://Assets/Audio/SFX/level_up.wav", "category": SFXCategory.AMBIENT, "volume": 3.0, "pitch_variance": 0.0 },
	"portal_open": { "path": "res://Assets/Audio/SFX/portal_open.wav", "category": SFXCategory.AMBIENT, "volume": 0.0, "pitch_variance": 0.0 },
	"portal_enter": { "path": "res://Assets/Audio/SFX/portal_enter.wav", "category": SFXCategory.AMBIENT, "volume": 0.0, "pitch_variance": 0.0 },
	"game_over": { "path": "res://Assets/Audio/SFX/game_over.wav", "category": SFXCategory.AMBIENT, "volume": 0.0, "pitch_variance": 0.0 },
	"victory": { "path": "res://Assets/Audio/SFX/victory.wav", "category": SFXCategory.AMBIENT, "volume": 3.0, "pitch_variance": 0.0 },

	# Combat feedback
	"crit_hit": { "path": "res://Assets/Audio/SFX/crit_hit.wav", "category": SFXCategory.PLAYER_ATTACK, "volume": 3.0, "pitch_variance": 0.05 },
	"combo_finisher": { "path": "res://Assets/Audio/SFX/combo_finisher.wav", "category": SFXCategory.PLAYER_ATTACK, "volume": 3.0, "pitch_variance": 0.05 },
	"parry": { "path": "res://Assets/Audio/SFX/parry.wav", "category": SFXCategory.PLAYER_ATTACK, "volume": 0.0, "pitch_variance": 0.1 },
	"block": { "path": "res://Assets/Audio/SFX/block.wav", "category": SFXCategory.PLAYER_HIT, "volume": 0.0, "pitch_variance": 0.1 },
}

# ============================================
# STATE
# ============================================
var _audio_pool: Array[AudioStreamPlayer] = []
var _2d_audio_pool: Array[AudioStreamPlayer2D] = []
var _loaded_sounds: Dictionary = {}

# Music
var _music_player: AudioStreamPlayer = null
var _current_music: String = ""
var _music_fade_tween: Tween = null

# ============================================
# LIFECYCLE
# ============================================
func _ready():
	_setup_audio_buses()
	_create_audio_pools()
	_preload_common_sounds()
	_connect_game_events()

func _setup_audio_buses():
	# Create audio buses if they don't exist
	# This is usually done in project settings, but we can check
	var sfx_idx = AudioServer.get_bus_index(BUS_SFX)
	if sfx_idx == -1:
		# Buses should be set up in project settings
		# For now, we'll use Master for everything
		pass

func _create_audio_pools():
	# Create pool of AudioStreamPlayers for non-positional audio
	@warning_ignore("integer_division")
	var half_pool_size: int = MAX_CONCURRENT_SOUNDS / 2
	for i in range(half_pool_size):
		var player = AudioStreamPlayer.new()
		player.bus = BUS_SFX
		add_child(player)
		_audio_pool.append(player)

	# Create pool for positional audio
	for i in range(half_pool_size):
		var player = AudioStreamPlayer2D.new()
		player.bus = BUS_SFX
		player.max_distance = 1000.0
		add_child(player)
		_2d_audio_pool.append(player)

	# Create music player
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = BUS_MUSIC
	add_child(_music_player)

func _preload_common_sounds():
	# Preload frequently used sounds
	var common_sounds = ["sword_hit", "enemy_hit", "enemy_death", "player_hurt", "crystal_pickup"]
	for sound_name in common_sounds:
		_load_sound(sound_name)

func _load_sound(sound_name: String) -> AudioStream:
	if sound_name in _loaded_sounds:
		return _loaded_sounds[sound_name]

	if sound_name not in SOUNDS:
		return null

	var path = SOUNDS[sound_name].path
	if not ResourceLoader.exists(path):
		# Sound file doesn't exist yet - that's OK, we'll skip it
		return null

	var stream = load(path) as AudioStream
	if stream:
		_loaded_sounds[sound_name] = stream
	return stream

func _connect_game_events():
	# Connect to combat events for automatic sound playing
	if CombatEventBus:
		CombatEventBus.damage_dealt.connect(_on_damage_dealt)
		CombatEventBus.kill.connect(_on_kill)
		CombatEventBus.critical_hit.connect(_on_critical_hit)
		CombatEventBus.player_damaged.connect(_on_player_damaged)

	# Connect to wave events
	await get_tree().process_frame
	var wave_manager = get_tree().get_first_node_in_group("wave_manager")
	if wave_manager:
		if wave_manager.has_signal("wave_started"):
			wave_manager.wave_started.connect(_on_wave_started)
		if wave_manager.has_signal("wave_completed"):
			wave_manager.wave_completed.connect(_on_wave_completed)

# ============================================
# AUTOMATIC SOUND EVENTS
# ============================================
func _on_damage_dealt(event: CombatEventBus.DamageEvent):
	if event.target and event.target.is_in_group("enemies"):
		play("enemy_hit", event.hit_position)

func _on_kill(event: CombatEventBus.KillEvent):
	if event.was_boss:
		play("boss_death")
	elif event.was_elite:
		play("elite_death", event.victim.global_position if event.victim else Vector2.ZERO)
	else:
		play("enemy_death", event.victim.global_position if event.victim else Vector2.ZERO)

func _on_critical_hit(_event: CombatEventBus.DamageEvent):
	play("crit_hit")

func _on_player_damaged(_amount: float, _source: Node2D):
	play("player_hurt")

func _on_wave_started(wave_number: int):
	if wave_number == 5:  # Boss wave
		play("boss_intro")
	else:
		play("wave_start")

func _on_wave_completed(_wave_number: int):
	play("wave_complete")

# ============================================
# PLAY SOUNDS
# ============================================
func play(sound_name: String, position: Vector2 = Vector2.ZERO, volume_offset: float = 0.0) -> Node:
	if sound_name not in SOUNDS:
		return null

	# Check cooldown
	var current_time = Time.get_ticks_msec() / 1000.0
	if sound_name in _sound_cooldowns:
		if current_time - _sound_cooldowns[sound_name] < DEFAULT_COOLDOWN:
			return null
	_sound_cooldowns[sound_name] = current_time

	# Load sound
	var stream = _load_sound(sound_name)
	if not stream:
		return null

	var sound_data = SOUNDS[sound_name]

	# Get available player based on whether position is specified
	if position != Vector2.ZERO:
		# Use 2D positional audio
		var player_2d = _get_2d_player(position)
		if not player_2d:
			return null
		player_2d.stream = stream
		player_2d.volume_db = sound_data.volume + volume_offset + _get_category_volume(sound_data.category)
		player_2d.pitch_scale = 1.0 + randf_range(-sound_data.pitch_variance, sound_data.pitch_variance)
		player_2d.play()
		return player_2d
	else:
		# Use non-positional audio
		var player = _get_player()
		if not player:
			return null
		player.stream = stream
		player.volume_db = sound_data.volume + volume_offset + _get_category_volume(sound_data.category)
		player.pitch_scale = 1.0 + randf_range(-sound_data.pitch_variance, sound_data.pitch_variance)
		player.play()
		return player

func play_at(sound_name: String, position: Vector2, volume_offset: float = 0.0) -> AudioStreamPlayer2D:
	if sound_name not in SOUNDS:
		return null

	# Check cooldown
	var current_time = Time.get_ticks_msec() / 1000.0
	if sound_name in _sound_cooldowns:
		if current_time - _sound_cooldowns[sound_name] < DEFAULT_COOLDOWN:
			return null
	_sound_cooldowns[sound_name] = current_time

	# Load sound
	var stream = _load_sound(sound_name)
	if not stream:
		return null

	var sound_data = SOUNDS[sound_name]

	# Get 2D player
	var player = _get_2d_player(position)
	if not player:
		return null

	# Configure and play
	player.stream = stream
	player.volume_db = sound_data.volume + volume_offset + _get_category_volume(sound_data.category)
	player.pitch_scale = 1.0 + randf_range(-sound_data.pitch_variance, sound_data.pitch_variance)
	player.play()

	return player

func _get_player() -> AudioStreamPlayer:
	for player in _audio_pool:
		if not player.playing:
			return player

	# All players busy - steal oldest
	return _audio_pool[0]

func _get_2d_player(position: Vector2) -> AudioStreamPlayer2D:
	for player in _2d_audio_pool:
		if not player.playing:
			player.global_position = position
			return player

	# All players busy - steal oldest
	var player = _2d_audio_pool[0]
	player.global_position = position
	return player

func _get_category_volume(category: SFXCategory) -> float:
	match category:
		SFXCategory.UI:
			return linear_to_db(ui_volume)
		SFXCategory.MUSIC:
			return linear_to_db(music_volume)
		_:
			return linear_to_db(sfx_volume)

# ============================================
# MUSIC
# ============================================
func play_music(music_path: String, fade_duration: float = 1.0):
	if music_path == _current_music and _music_player.playing:
		return

	var stream = load(music_path) as AudioStream
	if not stream:
		push_warning("AudioManager: Music not found at '%s'" % music_path)
		return

	_current_music = music_path

	# Fade out current music
	if _music_fade_tween and _music_fade_tween.is_valid():
		_music_fade_tween.kill()

	if _music_player.playing:
		_music_fade_tween = TweenHelper.new_tween()
		_music_fade_tween.tween_property(_music_player, "volume_db", -40.0, fade_duration * 0.5)
		_music_fade_tween.tween_callback(func():
			_music_player.stream = stream
			_music_player.volume_db = -40.0
			_music_player.play()
		)
		_music_fade_tween.tween_property(_music_player, "volume_db", linear_to_db(music_volume), fade_duration * 0.5)
	else:
		_music_player.stream = stream
		_music_player.volume_db = -40.0
		_music_player.play()

		_music_fade_tween = TweenHelper.new_tween()
		_music_fade_tween.tween_property(_music_player, "volume_db", linear_to_db(music_volume), fade_duration)

func stop_music(fade_duration: float = 1.0):
	if not _music_player.playing:
		return

	if _music_fade_tween and _music_fade_tween.is_valid():
		_music_fade_tween.kill()

	_music_fade_tween = TweenHelper.new_tween()
	_music_fade_tween.tween_property(_music_player, "volume_db", -40.0, fade_duration)
	_music_fade_tween.tween_callback(_music_player.stop)

	_current_music = ""

func pause_music():
	_music_player.stream_paused = true

func resume_music():
	_music_player.stream_paused = false

# ============================================
# VOLUME CONTROLS
# ============================================
func set_master_volume(volume: float):
	master_volume = clamp(volume, 0.0, 1.0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(BUS_MASTER), linear_to_db(master_volume))

func set_sfx_volume(volume: float):
	sfx_volume = clamp(volume, 0.0, 1.0)
	var bus_idx = AudioServer.get_bus_index(BUS_SFX)
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(sfx_volume))

func set_music_volume(volume: float):
	music_volume = clamp(volume, 0.0, 1.0)
	var bus_idx = AudioServer.get_bus_index(BUS_MUSIC)
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(music_volume))
	# Also update currently playing music
	if _music_player.playing:
		_music_player.volume_db = linear_to_db(music_volume)

func set_ui_volume(volume: float):
	ui_volume = clamp(volume, 0.0, 1.0)
	var bus_idx = AudioServer.get_bus_index(BUS_UI)
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(ui_volume))

func get_volumes() -> Dictionary:
	return {
		"master": master_volume,
		"sfx": sfx_volume,
		"music": music_volume,
		"ui": ui_volume
	}

# ============================================
# CONVENIENCE METHODS
# ============================================
func ui_click():
	play("ui_click")

func ui_hover():
	play("ui_hover")

func ui_confirm():
	play("ui_confirm")

func ui_cancel():
	play("ui_cancel")

func sword_swing():
	play("sword_swing")

func sword_hit(position: Vector2 = Vector2.ZERO):
	play("sword_hit", position)

func staff_fire(position: Vector2 = Vector2.ZERO):
	play("staff_fire", position)

func dash():
	play("player_dash")

func skill_activate():
	play("skill_activate")

func crystal_pickup():
	play("crystal_pickup")

func relic_pickup():
	play("relic_pickup")
