# SCRIPT: UpgradeMenu.gd
# ATTACH TO: UpgradeMenu (CanvasLayer) root in UpgradeMenu.tscn
# LOCATION: res://scripts/ui/UpgradeMenu.gd
# Refactored to use WaveShop random shop and HealerUI components

class_name UpgradeMenu
extends CanvasLayer

# ============================================
# NODES
# ============================================
@onready var control: Control = $Control
@onready var background: ColorRect = $Control/Background
@onready var container: VBoxContainer = $Control/Container
@onready var title_label: Label = $Control/Container/Title
@onready var subtitle_label: Label = $Control/Container/Subtitle
@onready var upgrade_cards: HBoxContainer = $Control/Container/UpgradeCards
@onready var skip_button: Button = $Control/SkipButton

# ============================================
# COMPONENT REFERENCES
# ============================================
var wave_shop: WaveShop
var healer_ui: HealerUI

# ============================================
# STATE
# ============================================
var card_panels: Array = []
var card_data: Array = []
var player_reference: Node2D = null
var upgrade_system: UpgradeSystem = null

# ============================================
# SIGNALS
# ============================================
signal upgrade_selected(upgrade: Dictionary)
signal menu_closed()

func _ready():
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Create upgrade system
	upgrade_system = UpgradeSystem.new()
	add_child(upgrade_system)

	# Setup card panels
	_setup_card_panels()

	# Setup skip button
	if skip_button:
		skip_button.pressed.connect(_on_skip_pressed)

	# Create and setup components
	_setup_components()

func _setup_card_panels():
	for child in upgrade_cards.get_children():
		if child is Panel:
			card_panels.append(child)
			var button = child.get_node("VBox/SelectButton")
			if button:
				button.pressed.connect(_on_card_selected.bind(card_panels.size() - 1))

func _setup_components():
	# Create HealerUI (placed higher since shop takes more space)
	healer_ui = HealerUI.new()
	healer_ui.name = "HealerUI"
	control.add_child(healer_ui)
	healer_ui.position = Vector2(20, 550)
	healer_ui.gold_changed.connect(_on_gold_changed)
	healer_ui.healed.connect(_on_player_healed)

# ============================================
# SHOW/HIDE MENU
# ============================================
func show_upgrades(player: Node2D):
	player_reference = player

	# Cleanup active effects before pausing
	_cleanup_active_effects()

	# Update healer UI
	healer_ui.set_player(player)
	healer_ui.update_display()

	# Get random upgrades
	card_data = upgrade_system.get_random_upgrades(3)

	# Pause game
	get_tree().paused = true

	# Show menu with animation
	visible = true
	control.modulate.a = 0.0

	var tween = create_tween()
	tween.tween_property(control, "modulate:a", 1.0, 0.3)

	container.position.y = -50
	tween.parallel().tween_property(container, "position:y", 0, 0.3)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_setup_cards()
	_animate_cards_in()

func _close_menu():
	var tween = create_tween()
	tween.tween_property(control, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func():
		visible = false
		get_tree().paused = false
		menu_closed.emit()
	)

# ============================================
# UPGRADE CARDS
# ============================================
func _setup_cards():
	for i in range(min(card_data.size(), card_panels.size())):
		var card = card_panels[i]
		var upgrade = card_data[i]

		var data = upgrade_system.get_upgrade_display_data(upgrade)

		var icon = card.get_node("VBox/Icon")
		var name_label = card.get_node("VBox/Name")
		var desc_label = card.get_node("VBox/Description")

		if icon:
			icon.color = data.get("icon_color", Color.WHITE)
		if name_label:
			name_label.text = data.get("name", "Unknown")
		if desc_label:
			desc_label.text = data.get("description", "")

		# Style panel
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.1, 0.15, 0.9)
		style.set_border_width_all(2)
		style.border_color = data.get("icon_color", Color.WHITE) * 0.8
		style.set_corner_radius_all(8)
		card.add_theme_stylebox_override("panel", style)

func _animate_cards_in():
	var delay = 0.0
	for card in card_panels:
		card.scale = Vector2(0.8, 0.8)
		card.modulate.a = 0.0

		var tween = create_tween()
		tween.tween_interval(delay)
		tween.tween_property(card, "scale", Vector2.ONE, 0.3)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(card, "modulate:a", 1.0, 0.3)

		delay += 0.1

func _on_card_selected(index: int):
	if index >= card_data.size():
		return

	var selected_upgrade = card_data[index]

	if upgrade_system and player_reference:
		upgrade_system.apply_upgrade(player_reference, selected_upgrade)

	upgrade_selected.emit(selected_upgrade)

	# Animate selection
	var selected_card = card_panels[index]
	selected_card.scale = Vector2(1.1, 1.1)

	var tween = create_tween()
	tween.tween_property(selected_card, "scale", Vector2(1.2, 1.2), 0.2)
	tween.parallel().tween_property(selected_card, "modulate:a", 0.0, 0.3)

	# Fade out other cards
	for i in range(card_panels.size()):
		if i != index:
			var other_tween = create_tween()
			other_tween.tween_property(card_panels[i], "modulate:a", 0.0, 0.2)

	tween.tween_callback(_close_menu)

func _on_skip_pressed():
	_close_menu()

# ============================================
# EVENT HANDLERS
# ============================================
func _on_gold_changed():
	# Update healer display when gold changes
	healer_ui.update_display()

func _on_player_healed(_amount: float):
	# Could add visual feedback here if needed
	pass

# ============================================
# STATE MANAGEMENT
# ============================================
func reset_healer_for_new_wave():
	if healer_ui:
		healer_ui.reset_free_heal()

# ============================================
# CLEANUP
# ============================================
func _cleanup_active_effects():
	if player_reference:
		player_reference.is_attacking = false
		player_reference.is_melee_attacking = false
		player_reference.is_magic_attacking = false

		if player_reference.current_weapon and player_reference.current_weapon.has_method("finish_attack"):
			player_reference.current_weapon.finish_attack()

		if player_reference.current_staff and player_reference.current_staff.has_method("finish_attack"):
			player_reference.current_staff.finish_attack()

	_cleanup_scene_effects()

func _cleanup_scene_effects():
	var scene_root = get_tree().current_scene
	if not scene_root:
		return

	for node in scene_root.get_children():
		if node.get_script() and node.get_script().resource_path.ends_with("DamageNumber.gd"):
			node.queue_free()

	for node in scene_root.get_children():
		if node.is_in_group("projectiles"):
			node.queue_free()
		elif node.is_in_group("effects"):
			node.queue_free()
		elif "effect" in node.name.to_lower() or "projectile" in node.name.to_lower():
			node.queue_free()
