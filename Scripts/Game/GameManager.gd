# SCRIPT: GameManager.gd (Enhanced)
# ATTACH TO: GameManager node in Game.tscn
# LOCATION: res://scripts/game/GameManager.gd

class_name GameManager
extends Node

# Game state
enum GameState { MENU, PLAYING, PAUSED, UPGRADE, GAME_OVER, VICTORY }
var current_state: GameState = GameState.PLAYING

# Stats tracking
var waves_completed: int = 0
var enemies_killed_total: int = 0
var time_played: float = 0.0
var damage_dealt: float = 0.0
var damage_taken: float = 0.0
var gold: int = 0
var total_gold_collected: int = 0

# References
@onready var wave_manager: WaveManager = $"../WaveManager"
var player_reference: Node2D = null
var game_over_screen: GameOverScreen = null
var pause_menu: PauseMenu = null

# Signals
signal game_started()
signal game_over()
@warning_ignore("unused_signal")
signal game_paused()
@warning_ignore("unused_signal")
signal game_resumed()
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

	# Create game over screen and pause menu
	await _create_game_over_screen()
	await _create_pause_menu()

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

func _on_player_died():
	if current_state == GameState.GAME_OVER:
		return

	current_state = GameState.GAME_OVER
	game_over.emit()

	# Prepare stats for game over screen
	var stats = {
		"waves": waves_completed,
		"enemies_killed": enemies_killed_total,
		"gold_collected": total_gold_collected,
		"time": time_played,
		"damage_dealt": damage_dealt,
		"damage_taken": damage_taken
	}

	# Show game over with delay for drama
	await get_tree().create_timer(1.0).timeout

	if game_over_screen:
		game_over_screen.show_game_over(stats)

func _on_wave_completed(wave_number: int):
	if current_state != GameState.PLAYING:
		return

	waves_completed = wave_number

	# Show upgrade menu after wave (except last wave)
	if wave_number < 5:
		current_state = GameState.UPGRADE
		# Wait 0.5 seconds after last enemy dies before showing upgrade menu
		await get_tree().create_timer(0.5).timeout
		_show_upgrade_menu()

	# Achievement check
	_check_achievements()

func _on_all_waves_completed():
	current_state = GameState.VICTORY

	# Show victory screen
	_show_victory_screen()

func _on_enemy_killed(enemies_remaining: int):
	if current_state != GameState.PLAYING and current_state != GameState.UPGRADE:
		return

	enemies_killed_total += 1

func _on_player_damaged(_current_health: float, _max_health: float):
	# Track damage taken (could be expanded for more complex tracking)
	pass

func _show_upgrade_menu():
	# Get upgrade menu (it's a sibling in the Game scene)
	var upgrade_menu = get_node_or_null("../UpgradeMenu")

	if not upgrade_menu:
		# Load and instance upgrade menu if it doesn't exist
		var menu_scene = load("res://Scenes/Ui/UpgradeMenu.tscn")
		upgrade_menu = menu_scene.instantiate()
		get_parent().add_child(upgrade_menu)
		print("Created new UpgradeMenu instance")
	else:
		print("Found existing UpgradeMenu")

	# Connect to menu closed signal
	if upgrade_menu and not upgrade_menu.menu_closed.is_connected(_on_upgrade_menu_closed):
		upgrade_menu.menu_closed.connect(_on_upgrade_menu_closed)

	# Show upgrades
	if upgrade_menu and upgrade_menu.has_method("show_upgrades"):
		print("Calling show_upgrades on menu")
		upgrade_menu.show_upgrades(player_reference)
	else:
		print("ERROR: Could not show upgrades - menu or method missing")

func _on_upgrade_menu_closed():
	current_state = GameState.PLAYING

func _show_victory_screen():
	# Similar to game over but with victory message
	var stats = {
		"waves": 5,
		"enemies_killed": enemies_killed_total,
		"gold_collected": total_gold_collected,
		"time": time_played
	}

	if game_over_screen:
		game_over_screen.title_label.text = "VICTORY!"
		game_over_screen.title_label.modulate = Color.GOLD
		game_over_screen.show_game_over(stats)

func _check_achievements():
	# Check for various achievements
	if waves_completed == 1 and player_reference.stats.current_health == player_reference.stats.max_health:
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
