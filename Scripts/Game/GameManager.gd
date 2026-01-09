# SCRIPT: GameManager.gd (Enhanced)
# ATTACH TO: GameManager node in Game.tscn
# LOCATION: res://scripts/game/GameManager.gd

class_name GameManager
extends Node

# Constants
const MAX_WAVES: int = 10
const GAME_OVER_DELAY: float = 1.0
const UPGRADE_MENU_DELAY: float = 0.5
const PORTAL_SPAWN_DELAY: float = 1.5  # Time before portal spawns after wave clear
const WAVE_CLEAR_DISPLAY_TIME: float = 2.0  # How long to show "WAVE COMPLETE"

# Portal scene
const PORTAL_SCENE = preload("res://Scenes/Game/QuartersPortal.tscn")

# Game state
enum GameState { MENU, PLAYING, PAUSED, UPGRADE, GAME_OVER, VICTORY }
var current_state: GameState = GameState.PLAYING

# Portal state machine to prevent race conditions
enum PortalState { NONE, SPAWNING, ACTIVE, ENTERED, DESTROYED }
var _portal_state: PortalState = PortalState.NONE

# Stats tracking
var waves_completed: int = 0
var enemies_killed_total: int = 0
var time_played: float = 0.0
var damage_dealt: float = 0.0
var damage_taken: float = 0.0
var last_player_health: float = -1.0  # Track previous health for cumulative damage
var gold: int = 0
var total_gold_collected: int = 0

# References
@onready var wave_manager: WaveManager = $"../WaveManager"
@onready var arena: Arena = $"../Arena"
var player_reference: Node2D = null
var game_over_screen: GameOverScreen = null
var pause_menu: PauseMenu = null
var debug_menu: DebugMenu = null
var current_portal: QuartersPortal = null
var wave_clear_ui: CanvasLayer = null
var wave_shop: WaveShop = null  # Random weapon/item shop between waves

# Signals
signal game_started()
signal game_over()
signal gold_changed(current_gold: int)

func _ready():
	# Find player
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player_reference = players[0]
		player_reference.player_died.connect(_on_player_died)
		player_reference.health_changed.connect(_on_player_damaged)

	# Connect wave manager signals
	if wave_manager:
		wave_manager.wave_completed.connect(_on_wave_completed)
		wave_manager.all_waves_completed.connect(_on_all_waves_completed)
		wave_manager.enemy_killed.connect(_on_enemy_killed)

	# Add to game_manager group so crystals can find us
	add_to_group("game_manager")

	# Create game over screen, pause menu, debug menu, and wave shop
	await _create_game_over_screen()
	await _create_pause_menu()
	await _create_debug_menu()
	_create_wave_clear_ui()
	_create_wave_shop()

	# Start game
	start_game()

func _process(delta):
	if current_state == GameState.PLAYING:
		time_played += delta

func start_game():
	current_state = GameState.PLAYING
	waves_completed = 0
	enemies_killed_total = 0
	time_played = 0.0
	damage_dealt = 0.0
	damage_taken = 0.0
	gold = 0
	total_gold_collected = 0
	game_started.emit()
	gold_changed.emit(gold)

func _create_game_over_screen():
	var game_over_scene = load("res://Scenes/Ui/GameOverScreen.tscn")
	game_over_screen = game_over_scene.instantiate()
	get_parent().add_child.call_deferred(game_over_screen)
	# Wait for it to be ready
	await get_tree().process_frame

func _create_pause_menu():
	var pause_scene = load("res://Scenes/Ui/PauseMenu.tscn")
	pause_menu = pause_scene.instantiate()
	get_parent().add_child.call_deferred(pause_menu)
	# Wait for it to be ready
	await get_tree().process_frame

func _create_debug_menu():
	var debug_scene = load("res://Scenes/Ui/DebugMenu.tscn")
	debug_menu = debug_scene.instantiate()
	get_parent().add_child.call_deferred(debug_menu)
	# Wait for it to be ready
	await get_tree().process_frame

func _on_player_died():
	if current_state == GameState.GAME_OVER:
		return

	current_state = GameState.GAME_OVER
	game_over.emit()

	# Prepare stats for game over screen
	var stats = {
		"waves": waves_completed,
		"enemies_killed": enemies_killed_total,
		"gold": gold,  # Current unspent gold
		"score": total_gold_collected,
		"time": time_played,
		"damage_dealt": damage_dealt,
		"damage_taken": damage_taken
	}

	# Show game over with delay for drama
	await get_tree().create_timer(GAME_OVER_DELAY).timeout

	if game_over_screen:
		game_over_screen.show_game_over(stats)

func _on_wave_completed(wave_number: int):
	if current_state != GameState.PLAYING:
		return

	waves_completed = wave_number

	# Show wave complete feedback
	_show_wave_complete_ui(wave_number)

	# Spawn portal after wave (except last wave - boss wave)
	if wave_number < MAX_WAVES:
		current_state = GameState.UPGRADE
		await get_tree().create_timer(PORTAL_SPAWN_DELAY).timeout

		# Check if still valid after await
		if not is_instance_valid(self):
			return

		_spawn_quarters_portal()

	# Achievement check
	_check_achievements()

func _on_all_waves_completed():
	current_state = GameState.VICTORY

	# Show victory screen
	_show_victory_screen()

func _on_enemy_killed(_enemies_remaining: int):
	if current_state != GameState.PLAYING and current_state != GameState.UPGRADE:
		return

	enemies_killed_total += 1

func _on_player_damaged(current_health: float, _max_health: float):
	# Track cumulative damage taken
	if last_player_health < 0:
		last_player_health = current_health
		return

	var delta = last_player_health - current_health
	if delta > 0:  # Only count actual damage, not healing
		damage_taken += delta
	last_player_health = current_health

func _show_wave_shop():
	if wave_shop and player_reference:
		# Use RunManager's gold (the authoritative gold source for runs)
		var current_run_gold = 0
		if RunManager:
			current_run_gold = RunManager.get_gold()
		else:
			current_run_gold = gold
		wave_shop.open_shop(player_reference, current_run_gold)
		print("[GameManager] Wave shop opened with %d gold" % current_run_gold)

func _on_wave_shop_closed():
	print("[GameManager] Wave shop closed - starting next wave")
	# Shop now includes healer, so go directly to next wave
	current_state = GameState.PLAYING

	# Reset portal state for next wave
	_portal_state = PortalState.NONE

	# Start next wave after shop closes
	if wave_manager:
		wave_manager.start_next_wave()

func _show_victory_screen():
	# Similar to game over but with victory message
	var stats = {
		"waves": MAX_WAVES,
		"enemies_killed": enemies_killed_total,
		"gold": gold,  # Current unspent gold
		"score": total_gold_collected,
		"time": time_played
	}

	if game_over_screen:
		game_over_screen.title_label.text = "VICTORY!"
		game_over_screen.title_label.modulate = Color.GOLD
		game_over_screen.show_game_over(stats)

func _check_achievements():
	# Check for various achievements
	if waves_completed == 1 and player_reference and player_reference.stats:
		if player_reference.stats.current_health == player_reference.stats.max_health:
			_unlock_achievement("Untouchable Wave 1")

	if enemies_killed_total >= 50:
		_unlock_achievement("Slime Slayer")

	if total_gold_collected >= 100:
		_unlock_achievement("Gold Hoarder")

func _unlock_achievement(achievement_name: String):
	# Show achievement notification
	var achievement_label = Label.new()
	achievement_label.text = "Achievement: " + achievement_name
	achievement_label.add_theme_font_size_override("font_size", 20)
	achievement_label.modulate = Color.GOLD
	get_parent().add_child(achievement_label)
	achievement_label.position = Vector2(320, 200)

	var tween = create_tween()
	tween.tween_property(achievement_label, "position:y", 180, 0.5)
	tween.tween_interval(2.0)
	tween.tween_property(achievement_label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(achievement_label.queue_free)

func add_gold(amount: int):
	gold += amount
	total_gold_collected += amount
	gold_changed.emit(gold)

func spend_gold(amount: int) -> bool:
	if gold >= amount:
		gold -= amount
		gold_changed.emit(gold)
		return true
	return false

func get_gold() -> int:
	return gold

# ============================================
# PORTAL SYSTEM
# ============================================

func _spawn_quarters_portal():
	# State machine guard - prevent spawning if already in progress
	if _portal_state != PortalState.NONE:
		print("[GameManager] Portal spawn blocked - state is %s" % PortalState.keys()[_portal_state])
		return

	_portal_state = PortalState.SPAWNING

	if current_portal and is_instance_valid(current_portal):
		current_portal.queue_free()
		current_portal = null

	# Spawn portal at arena center
	var portal_pos = Vector2(1280, 720)  # Arena center
	if arena:
		portal_pos = arena.get_arena_center()

	current_portal = PORTAL_SCENE.instantiate()
	get_parent().add_child(current_portal)
	current_portal.global_position = portal_pos

	# Connect portal signals
	current_portal.portal_entered.connect(_on_portal_entered)
	current_portal.portal_destroyed.connect(_on_portal_destroyed)

	_portal_state = PortalState.ACTIVE
	print("[GameManager] Quarters portal spawned at %s" % portal_pos)

func _on_portal_entered():
	# State machine guard - only process if portal is active
	if _portal_state != PortalState.ACTIVE:
		print("[GameManager] Portal enter blocked - state is %s" % PortalState.keys()[_portal_state])
		return

	_portal_state = PortalState.ENTERED
	print("[GameManager] Player entered portal - opening Armory Shop")
	current_portal = null

	# Award wave tickets and clear bloodlust when entering quarters
	if RunManager:
		var is_boss = (RunManager.get_current_wave() % 5 == 0)  # Every 5 waves is boss
		RunManager.award_wave_tickets(is_boss)
		RunManager.clear_bloodlust()

	# Reset healer for new visit
	if wave_shop and wave_shop.has_method("reset_healer_for_new_wave"):
		wave_shop.reset_healer_for_new_wave()

	# Show wave shop first (random weapons/items), then upgrade menu
	_show_wave_shop()

func _on_portal_destroyed():
	# State machine guard - only process if portal is active
	if _portal_state != PortalState.ACTIVE:
		print("[GameManager] Portal destroy blocked - state is %s" % PortalState.keys()[_portal_state])
		return

	_portal_state = PortalState.DESTROYED
	print("[GameManager] Portal destroyed - BLOODLUST ACTIVATED!")
	current_portal = null

	# Activate bloodlust and mark portal destroyed (no shards this wave)
	if RunManager:
		RunManager.mark_portal_destroyed()
		RunManager.activate_bloodlust()

	# Show bloodlust activation feedback
	_show_bloodlust_activation_ui()

	# Make player briefly invulnerable during transition
	if player_reference and player_reference.has_method("set_invulnerable"):
		player_reference.set_invulnerable(true)
		await get_tree().create_timer(1.0).timeout
		if is_instance_valid(player_reference):
			player_reference.set_invulnerable(false)

	# Start next wave immediately
	current_state = GameState.PLAYING

	# Reset portal state for next wave
	_portal_state = PortalState.NONE

	if wave_manager:
		wave_manager.start_next_wave()

# ============================================
# WAVE CLEAR UI
# ============================================

func _create_wave_clear_ui():
	wave_clear_ui = CanvasLayer.new()
	wave_clear_ui.layer = 10
	add_child(wave_clear_ui)

func _create_wave_shop():
	# Load WaveShop from scene file
	var shop_scene = load("res://Scenes/Ui/WaveShop.tscn")
	wave_shop = shop_scene.instantiate()

	# Add to a CanvasLayer for proper UI rendering
	var shop_layer = CanvasLayer.new()
	shop_layer.layer = 15  # Above other UI
	add_child(shop_layer)
	shop_layer.add_child(wave_shop)

	# Connect shop closed signal
	wave_shop.shop_closed.connect(_on_wave_shop_closed)

func _show_wave_complete_ui(wave_number: int):
	if not wave_clear_ui:
		return

	# Create container
	var container = Control.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	wave_clear_ui.add_child(container)

	# Main text - "WAVE X COMPLETE!"
	var main_label = Label.new()
	main_label.text = "WAVE %d COMPLETE!" % wave_number
	main_label.add_theme_font_size_override("font_size", 64)
	main_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	main_label.set_anchors_preset(Control.PRESET_CENTER)
	main_label.position = Vector2(-200, -100)
	main_label.modulate = Color.GOLD
	main_label.modulate.a = 0.0
	container.add_child(main_label)

	# Sub text - hint
	var sub_label = Label.new()
	sub_label.text = "Portal spawning..."
	sub_label.add_theme_font_size_override("font_size", 24)
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_label.set_anchors_preset(Control.PRESET_CENTER)
	sub_label.position = Vector2(-80, -20)
	sub_label.modulate.a = 0.0
	container.add_child(sub_label)

	# Animation
	var tween = TweenHelper.new_tween()

	# Fade in and scale up
	main_label.scale = Vector2(0.5, 0.5)
	tween.tween_property(main_label, "modulate:a", 1.0, 0.3)
	tween.parallel().tween_property(main_label, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Sub label fade in
	tween.tween_property(sub_label, "modulate:a", 0.7, 0.2)

	# Hold
	tween.tween_interval(WAVE_CLEAR_DISPLAY_TIME - 0.5)

	# Fade out
	tween.tween_property(main_label, "modulate:a", 0.0, 0.3)
	tween.parallel().tween_property(sub_label, "modulate:a", 0.0, 0.3)
	tween.tween_callback(container.queue_free)

	# Screen shake
	if DamageNumberManager:
		DamageNumberManager.shake(0.4)

func _show_bloodlust_activation_ui():
	if not wave_clear_ui:
		return

	var container = Control.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	wave_clear_ui.add_child(container)

	# Bloodlust text
	var main_label = Label.new()
	main_label.text = "BLOODLUST!"
	main_label.add_theme_font_size_override("font_size", 72)
	main_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_label.set_anchors_preset(Control.PRESET_CENTER)
	main_label.position = Vector2(-180, -80)
	main_label.modulate = Color(1.0, 0.2, 0.1)  # Red
	main_label.modulate.a = 0.0
	container.add_child(main_label)

	# Bonus text
	var stacks = 1
	if RunManager:
		stacks = RunManager.get_bloodlust_stacks()

	var bonus_label = Label.new()
	bonus_label.text = "+%d%% DAMAGE  +%d%% GOLD" % [stacks * 15, stacks * 25]
	bonus_label.add_theme_font_size_override("font_size", 28)
	bonus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bonus_label.set_anchors_preset(Control.PRESET_CENTER)
	bonus_label.position = Vector2(-120, 0)
	bonus_label.modulate = Color(1.0, 0.6, 0.2)  # Orange
	bonus_label.modulate.a = 0.0
	container.add_child(bonus_label)

	# Animation - more aggressive
	var tween = TweenHelper.new_tween()

	main_label.scale = Vector2(1.5, 1.5)
	tween.tween_property(main_label, "modulate:a", 1.0, 0.15)
	tween.parallel().tween_property(main_label, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	tween.tween_property(bonus_label, "modulate:a", 1.0, 0.2)

	# Pulse effect
	tween.tween_property(main_label, "scale", Vector2(1.1, 1.1), 0.1)
	tween.tween_property(main_label, "scale", Vector2(1.0, 1.0), 0.1)

	# Hold
	tween.tween_interval(1.0)

	# Fade out
	tween.tween_property(main_label, "modulate:a", 0.0, 0.3)
	tween.parallel().tween_property(bonus_label, "modulate:a", 0.0, 0.3)
	tween.tween_callback(container.queue_free)

	# Big screen shake for bloodlust
	if DamageNumberManager:
		DamageNumberManager.shake(0.7)
