# SCRIPT: DebugMenu.gd
# ATTACH TO: DebugMenu (CanvasLayer) root node
# LOCATION: res://Scripts/Ui/DebugMenu.gd
# PURPOSE: Debug menu for testing - pause waves, spawn enemies, kill all, heal all

class_name DebugMenu
extends CanvasLayer

# ============================================
# ENEMY SCENES FOR SPAWNING
# ============================================
const ENEMY_SCENES = {
	"Slime": preload("res://Scenes/Enemies/Slime.tscn"),
	"GoblinArcher": preload("res://Scenes/Enemies/GoblinArcher.tscn"),
	"GoblinDual": preload("res://Scenes/Enemies/GoblinDual.tscn"),
	"Healer": preload("res://Scenes/Enemies/Healer.tscn"),
	"Spawner": preload("res://Scenes/Enemies/Spawner.tscn"),
	"Boss": preload("res://Scenes/Enemies/Boss.tscn")
}

# ============================================
# HAZARD SCENES FOR SPAWNING
# ============================================
const HAZARD_SCENES = {
	"FireGrate": preload("res://Scenes/hazards/FireGrate.tscn"),
	"FloorSpikes": preload("res://Scenes/hazards/FloorSpikes.tscn"),
	"SpikeWall": preload("res://Scenes/hazards/SpikeWall.tscn"),
	"Crusher": preload("res://Scenes/hazards/Crusher.tscn")
}

# ============================================
# STATE
# ============================================
var is_open: bool = false
var is_dragging_enemy: bool = false
var is_dragging_hazard: bool = false
var dragging_enemy_type: String = ""
var dragging_hazard_type: String = ""
var drag_preview: ColorRect = null
var wave_manager: WaveManager = null
var player_reference: Node2D = null
var was_wave_active: bool = false
var enemies_frozen: bool = true  # Toggle for freezing enemies

# UI References
var panel: PanelContainer = null
var enemy_buttons: Dictionary = {}
var hazard_buttons: Dictionary = {}
var freeze_button: Button = null
var gold_label: Label = null

# ============================================
# SIGNALS
# ============================================
signal debug_mode_changed(is_active: bool)

func _ready():
	# Start hidden
	visible = false
	layer = 100  # On top of everything

	# Build the UI
	_build_debug_ui()

	# Find references
	_find_references()

func _find_references():
	# Find wave manager
	wave_manager = get_tree().get_first_node_in_group("wave_manager")
	if not wave_manager:
		var wm = get_node_or_null("/root/Game/WaveManager")
		if wm:
			wave_manager = wm

	# Find player
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player_reference = players[0]

func _input(event):
	# Toggle debug menu with O key
	if event is InputEventKey and event.pressed and event.keycode == KEY_O:
		toggle_debug_menu()
		get_viewport().set_input_as_handled()
		return

	# Handle drag and drop for enemy/hazard spawning
	if is_open and (is_dragging_enemy or is_dragging_hazard):
		if event is InputEventMouseMotion:
			if drag_preview:
				drag_preview.global_position = get_viewport().get_mouse_position() - Vector2(20, 20)

		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if not event.pressed:  # Mouse released
				if is_dragging_enemy:
					_spawn_enemy_at_mouse()
				elif is_dragging_hazard:
					_spawn_hazard_at_mouse()
				_end_drag()

func toggle_debug_menu():
	if is_open:
		close_debug_menu()
	else:
		open_debug_menu()

func open_debug_menu():
	is_open = true
	visible = true
	enemies_frozen = true  # Start with enemies frozen

	# Re-find references in case they changed
	_find_references()

	# Pause wave manager
	if wave_manager:
		was_wave_active = wave_manager.wave_active
		wave_manager.wave_active = false
		wave_manager.set_process(false)

	# Pause enemy movement but keep them visible
	_set_enemies_frozen(true)

	# Update button text
	_update_freeze_button()

	# Update gold display
	_update_gold_display()

	debug_mode_changed.emit(true)
	print("[DEBUG] Debug menu opened - waves paused, enemies frozen")

func close_debug_menu():
	is_open = false
	visible = false

	# Cancel any drag
	_end_drag()

	# Resume wave manager
	if wave_manager:
		wave_manager.wave_active = was_wave_active
		wave_manager.set_process(true)

	# Resume enemy movement (always unfreeze when closing)
	_set_enemies_frozen(false)

	debug_mode_changed.emit(false)
	print("[DEBUG] Debug menu closed - waves resumed")

func _set_enemies_frozen(frozen: bool):
	enemies_frozen = frozen
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.set_physics_process(not frozen)
			# Also pause/unpause timers on enemies (like Spawner's spawn timer, Healer's heal timer)
			_set_enemy_timers_paused(enemy, frozen)

func _set_enemy_timers_paused(enemy: Node, paused: bool):
	# Find all Timer children and pause/unpause them
	for child in enemy.get_children():
		if child is Timer:
			child.paused = paused

func _update_freeze_button():
	if freeze_button:
		if enemies_frozen:
			freeze_button.text = "Unfreeze Enemies"
		else:
			freeze_button.text = "Freeze Enemies"

# ============================================
# BUILD UI
# ============================================
func _build_debug_ui():
	# Main panel on right side - use most of screen height
	var viewport_size = get_viewport().get_visible_rect().size
	var panel_height = viewport_size.y - 40  # 20px margin top and bottom

	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(260, panel_height)
	panel.position = Vector2(viewport_size.x - 280, 20)
	add_child(panel)

	# Style the panel
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	style.border_color = Color(0.8, 0.2, 0.2)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)

	# Add ScrollContainer for scrollable content
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "DEBUG MENU"
	title.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	title.add_theme_font_size_override("font_size", 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var subtitle = Label.new()
	subtitle.text = "Press O to close"
	subtitle.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)

	vbox.add_child(HSeparator.new())

	# === GOLD CONTROLS ===
	var gold_section_label = Label.new()
	gold_section_label.text = "GOLD"
	gold_section_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	gold_section_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(gold_section_label)

	# Gold display
	gold_label = Label.new()
	gold_label.text = "Gold: 0"
	gold_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	gold_label.add_theme_font_size_override("font_size", 16)
	gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(gold_label)

	# Gold buttons row
	var gold_hbox = HBoxContainer.new()
	gold_hbox.add_theme_constant_override("separation", 5)
	vbox.add_child(gold_hbox)

	var add_10_btn = _create_small_button("+10", Color(0.2, 0.8, 0.2))
	add_10_btn.pressed.connect(_on_add_gold.bind(10))
	gold_hbox.add_child(add_10_btn)

	var add_50_btn = _create_small_button("+50", Color(0.3, 0.9, 0.3))
	add_50_btn.pressed.connect(_on_add_gold.bind(50))
	gold_hbox.add_child(add_50_btn)

	var add_100_btn = _create_small_button("+100", Color(0.4, 1.0, 0.4))
	add_100_btn.pressed.connect(_on_add_gold.bind(100))
	gold_hbox.add_child(add_100_btn)

	# Open Shop button
	var shop_btn = _create_button("Open Shop", Color(1.0, 0.85, 0.0))
	shop_btn.pressed.connect(_on_open_shop_pressed)
	vbox.add_child(shop_btn)

	vbox.add_child(HSeparator.new())

	# === ACTION BUTTONS ===
	var actions_label = Label.new()
	actions_label.text = "ACTIONS"
	actions_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4))
	actions_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(actions_label)

	# Kill All button
	var kill_btn = _create_button("Kill All Enemies", Color(0.9, 0.2, 0.2))
	kill_btn.pressed.connect(_on_kill_all_pressed)
	vbox.add_child(kill_btn)

	# Heal All button
	var heal_btn = _create_button("Heal All Enemies", Color(0.2, 0.8, 0.4))
	heal_btn.pressed.connect(_on_heal_all_pressed)
	vbox.add_child(heal_btn)

	# Heal Player button
	var heal_player_btn = _create_button("Heal Player", Color(0.4, 0.6, 0.9))
	heal_player_btn.pressed.connect(_on_heal_player_pressed)
	vbox.add_child(heal_player_btn)

	# Skip Wave button
	var skip_btn = _create_button("Skip Wave", Color(0.9, 0.6, 0.2))
	skip_btn.pressed.connect(_on_skip_wave_pressed)
	vbox.add_child(skip_btn)

	vbox.add_child(HSeparator.new())

	# === ENEMY CONTROL ===
	var control_label = Label.new()
	control_label.text = "ENEMY CONTROL"
	control_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4))
	control_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(control_label)

	# Freeze/Unfreeze toggle button
	freeze_button = _create_button("Unfreeze Enemies", Color(0.4, 0.7, 0.9))
	freeze_button.pressed.connect(_on_freeze_toggle_pressed)
	vbox.add_child(freeze_button)

	vbox.add_child(HSeparator.new())

	# === SPAWN ENEMIES ===
	var spawn_label = Label.new()
	spawn_label.text = "SPAWN ENEMIES"
	spawn_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4))
	spawn_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(spawn_label)

	var spawn_hint = Label.new()
	spawn_hint.text = "Click & drag to arena"
	spawn_hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	spawn_hint.add_theme_font_size_override("font_size", 11)
	vbox.add_child(spawn_hint)

	# Enemy spawn buttons (2 columns)
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 5)
	vbox.add_child(grid)

	var enemy_colors = {
		"Slime": Color(0.0, 0.8, 0.0),
		"GoblinArcher": Color(0.3, 0.5, 0.2),
		"GoblinDual": Color(0.5, 0.4, 0.2),
		"Healer": Color(0.2, 0.8, 0.4),
		"Spawner": Color(0.6, 0.3, 0.8),
		"Boss": Color(0.9, 0.1, 0.1)
	}

	for enemy_name in ENEMY_SCENES.keys():
		var btn = _create_spawn_button(enemy_name, enemy_colors.get(enemy_name, Color.WHITE))
		btn.pressed.connect(_on_spawn_button_pressed.bind(enemy_name))
		grid.add_child(btn)
		enemy_buttons[enemy_name] = btn

	vbox.add_child(HSeparator.new())

	# === SPAWN HAZARDS ===
	var hazard_label = Label.new()
	hazard_label.text = "SPAWN HAZARDS"
	hazard_label.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))
	hazard_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(hazard_label)

	var hazard_hint = Label.new()
	hazard_hint.text = "Click & drag to arena"
	hazard_hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	hazard_hint.add_theme_font_size_override("font_size", 11)
	vbox.add_child(hazard_hint)

	# Hazard spawn buttons (2 columns)
	var hazard_grid = GridContainer.new()
	hazard_grid.columns = 2
	hazard_grid.add_theme_constant_override("h_separation", 5)
	hazard_grid.add_theme_constant_override("v_separation", 5)
	vbox.add_child(hazard_grid)

	var hazard_colors = {
		"FireGrate": Color(1.0, 0.5, 0.1),
		"FloorSpikes": Color(0.5, 0.5, 0.6),
		"SpikeWall": Color(0.6, 0.6, 0.7),
		"Crusher": Color(0.4, 0.3, 0.5)
	}

	for hazard_name in HAZARD_SCENES.keys():
		var btn = _create_spawn_button(hazard_name, hazard_colors.get(hazard_name, Color.WHITE))
		btn.pressed.connect(_on_hazard_button_pressed.bind(hazard_name))
		hazard_grid.add_child(btn)
		hazard_buttons[hazard_name] = btn

	# Clear All Hazards button
	var clear_hazards_btn = _create_button("Clear All Hazards", Color(0.8, 0.3, 0.3))
	clear_hazards_btn.pressed.connect(_on_clear_hazards_pressed)
	vbox.add_child(clear_hazards_btn)

	vbox.add_child(HSeparator.new())

	# === INFO ===
	var info_label = Label.new()
	info_label.text = "Waves are PAUSED"
	info_label.add_theme_color_override("font_color", Color(1, 0.5, 0.2))
	info_label.add_theme_font_size_override("font_size", 12)
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(info_label)

func _create_button(text: String, color: Color) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 35)

	# Style
	var style = StyleBoxFlat.new()
	style.bg_color = color * 0.3
	style.border_color = color
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", style)

	var hover_style = style.duplicate()
	hover_style.bg_color = color * 0.5
	btn.add_theme_stylebox_override("hover", hover_style)

	var pressed_style = style.duplicate()
	pressed_style.bg_color = color * 0.7
	btn.add_theme_stylebox_override("pressed", pressed_style)

	return btn

func _create_small_button(text: String, color: Color) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(65, 30)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style = StyleBoxFlat.new()
	style.bg_color = color * 0.3
	style.border_color = color
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", style)

	var hover_style = style.duplicate()
	hover_style.bg_color = color * 0.5
	btn.add_theme_stylebox_override("hover", hover_style)

	return btn

func _create_spawn_button(enemy_name: String, color: Color) -> Button:
	var btn = Button.new()
	btn.text = enemy_name
	btn.custom_minimum_size = Vector2(105, 30)
	btn.add_theme_font_size_override("font_size", 12)

	var style = StyleBoxFlat.new()
	style.bg_color = color * 0.25
	style.border_color = color
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	btn.add_theme_stylebox_override("normal", style)

	var hover_style = style.duplicate()
	hover_style.bg_color = color * 0.4
	btn.add_theme_stylebox_override("hover", hover_style)

	return btn

# ============================================
# BUTTON HANDLERS
# ============================================
func _on_kill_all_pressed():
	var enemies = get_tree().get_nodes_in_group("enemies")
	var count = 0
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.is_dead:
			enemy.die()
			count += 1
	print("[DEBUG] Killed %d enemies" % count)

func _on_heal_all_pressed():
	var enemies = get_tree().get_nodes_in_group("enemies")
	var count = 0
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.is_dead:
			enemy.current_health = enemy.max_health
			enemy.health_changed.emit(enemy.current_health, enemy.max_health)
			count += 1
	print("[DEBUG] Healed %d enemies" % count)

func _on_heal_player_pressed():
	if player_reference and player_reference.stats:
		player_reference.stats.current_health = player_reference.stats.max_health
		player_reference.health_changed.emit(player_reference.stats.current_health, player_reference.stats.max_health)
		print("[DEBUG] Player healed to full")

func _on_skip_wave_pressed():
	# Kill all and let wave manager handle next wave
	_on_kill_all_pressed()
	print("[DEBUG] Wave skipped")

func _on_freeze_toggle_pressed():
	_set_enemies_frozen(not enemies_frozen)
	_update_freeze_button()
	if enemies_frozen:
		print("[DEBUG] Enemies frozen")
	else:
		print("[DEBUG] Enemies unfrozen - they can move now")

func _on_add_gold(amount: int):
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager and game_manager.has_method("add_gold"):
		game_manager.add_gold(amount)
		_update_gold_display()
		print("[DEBUG] Added %d gold" % amount)

func _on_open_shop_pressed():
	# Close debug menu first
	close_debug_menu()

	# Find and open upgrade menu
	var upgrade_menu = get_tree().get_first_node_in_group("upgrade_menu")
	if not upgrade_menu:
		upgrade_menu = get_node_or_null("/root/Game/UI/UpgradeMenu")
	if not upgrade_menu:
		# Try to find it anywhere in the scene
		for node in get_tree().current_scene.get_children():
			if node.name == "UpgradeMenu" or node is CanvasLayer and node.has_method("show_upgrades"):
				upgrade_menu = node
				break

	if upgrade_menu and upgrade_menu.has_method("show_upgrades"):
		if player_reference:
			upgrade_menu.show_upgrades(player_reference)
			print("[DEBUG] Opened shop")
	else:
		print("[DEBUG] Could not find UpgradeMenu")

func _update_gold_display():
	if not gold_label:
		return
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager and game_manager.has_method("get_gold"):
		gold_label.text = "Gold: %d" % game_manager.get_gold()
	else:
		gold_label.text = "Gold: N/A"

# ============================================
# DRAG AND DROP SPAWNING
# ============================================
func _on_spawn_button_pressed(enemy_name: String):
	is_dragging_enemy = true
	dragging_enemy_type = enemy_name

	# Create drag preview
	drag_preview = ColorRect.new()
	drag_preview.size = Vector2(40, 40)
	drag_preview.color = Color(0.8, 0.4, 0.8, 0.7)
	drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(drag_preview)
	drag_preview.global_position = get_viewport().get_mouse_position() - Vector2(20, 20)

	# Add label to preview
	var label = Label.new()
	label.text = enemy_name[0]  # First letter
	label.add_theme_font_size_override("font_size", 20)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(40, 40)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_preview.add_child(label)

	print("[DEBUG] Dragging %s - release to spawn" % enemy_name)

func _spawn_enemy_at_mouse():
	if dragging_enemy_type == "" or not ENEMY_SCENES.has(dragging_enemy_type):
		return

	var mouse_pos = get_viewport().get_mouse_position()

	# Get camera offset to convert screen position to world position
	var camera = get_viewport().get_camera_2d()
	var world_pos = mouse_pos
	if camera:
		world_pos = camera.get_screen_center_position() - get_viewport().get_visible_rect().size / 2 + mouse_pos

	# Spawn the enemy
	var enemy_scene = ENEMY_SCENES[dragging_enemy_type]
	var enemy = enemy_scene.instantiate()
	enemy.global_position = world_pos

	# Add to game scene
	var game_scene = get_tree().current_scene
	game_scene.add_child(enemy)

	# Set player reference
	if player_reference and enemy.has_method("set_player_reference"):
		enemy.set_player_reference(player_reference)

	# Respect current freeze state
	enemy.set_physics_process(not enemies_frozen)

	# Also pause timers if frozen (need to wait a frame for timers to be ready)
	if enemies_frozen:
		await get_tree().process_frame
		_set_enemy_timers_paused(enemy, true)

	print("[DEBUG] Spawned %s at %s (frozen: %s)" % [dragging_enemy_type, world_pos, enemies_frozen])

func _end_drag():
	is_dragging_enemy = false
	is_dragging_hazard = false
	dragging_enemy_type = ""
	dragging_hazard_type = ""
	if drag_preview:
		drag_preview.queue_free()
		drag_preview = null

# ============================================
# HAZARD SPAWNING
# ============================================
func _on_hazard_button_pressed(hazard_name: String):
	is_dragging_hazard = true
	dragging_hazard_type = hazard_name

	# Create drag preview
	drag_preview = ColorRect.new()
	drag_preview.size = Vector2(40, 40)

	# Color based on hazard type
	var preview_colors = {
		"FireGrate": Color(1.0, 0.5, 0.1, 0.7),
		"FloorSpikes": Color(0.5, 0.5, 0.6, 0.7),
		"SpikeWall": Color(0.6, 0.6, 0.7, 0.7),
		"Crusher": Color(0.4, 0.3, 0.5, 0.7)
	}
	drag_preview.color = preview_colors.get(hazard_name, Color(0.8, 0.4, 0.4, 0.7))
	drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(drag_preview)
	drag_preview.global_position = get_viewport().get_mouse_position() - Vector2(20, 20)

	# Add label to preview
	var label = Label.new()
	label.text = hazard_name[0]  # First letter
	label.add_theme_font_size_override("font_size", 20)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(40, 40)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_preview.add_child(label)

	print("[DEBUG] Dragging %s hazard - release to spawn" % hazard_name)

func _spawn_hazard_at_mouse():
	if dragging_hazard_type == "" or not HAZARD_SCENES.has(dragging_hazard_type):
		return

	var mouse_pos = get_viewport().get_mouse_position()

	# Get camera offset to convert screen position to world position
	var camera = get_viewport().get_camera_2d()
	var world_pos = mouse_pos
	if camera:
		world_pos = camera.get_screen_center_position() - get_viewport().get_visible_rect().size / 2 + mouse_pos

	# Spawn the hazard
	var hazard_scene = HAZARD_SCENES[dragging_hazard_type]
	var hazard = hazard_scene.instantiate()
	hazard.global_position = world_pos

	# Add to game scene
	var game_scene = get_tree().current_scene
	game_scene.add_child(hazard)

	print("[DEBUG] Spawned %s hazard at %s" % [dragging_hazard_type, world_pos])

func _on_clear_hazards_pressed():
	var hazards = get_tree().get_nodes_in_group("hazards")
	var count = 0
	for hazard in hazards:
		if is_instance_valid(hazard):
			hazard.queue_free()
			count += 1
	print("[DEBUG] Cleared %d hazards" % count)
