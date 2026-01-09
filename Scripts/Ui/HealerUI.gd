# SCRIPT: HealerUI.gd
# Healer section UI component
# LOCATION: res://Scripts/Ui/HealerUI.gd

class_name HealerUI
extends Control

# ============================================
# SIGNALS
# ============================================
signal healed(amount: float)
signal gold_changed()

# ============================================
# STATE
# ============================================
var free_heal_used: bool = false
var player_reference: Node2D = null

# ============================================
# UI NODES
# ============================================
var title_label: Label
var health_display_label: Label
var free_heal_button: Button
var full_heal_button: Button

func _ready():
	_build_healer_ui()

func _build_healer_ui():
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	add_child(vbox)

	# Title
	title_label = Label.new()
	title_label.text = "HEALER"
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
	vbox.add_child(title_label)

	# Health display
	health_display_label = Label.new()
	health_display_label.text = "HP: ???"
	health_display_label.add_theme_font_size_override("font_size", 18)
	health_display_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.8))
	vbox.add_child(health_display_label)

	# Free heal button
	free_heal_button = Button.new()
	free_heal_button.text = "Free Heal (30%)"
	free_heal_button.custom_minimum_size = Vector2(180, 40)
	free_heal_button.pressed.connect(_on_free_heal_pressed)
	vbox.add_child(free_heal_button)
	_style_button(free_heal_button, Color(0.2, 0.6, 0.2))

	# Full heal button
	full_heal_button = Button.new()
	full_heal_button.text = "Full Heal (%d Gold)" % ShopData.FULL_HEAL_PRICE
	full_heal_button.custom_minimum_size = Vector2(180, 40)
	full_heal_button.pressed.connect(_on_full_heal_pressed)
	vbox.add_child(full_heal_button)
	_style_button(full_heal_button, Color(0.6, 0.5, 0.2))

func _style_button(button: Button, color: Color):
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(6)
	style.set_border_width_all(2)
	style.border_color = color * 1.3
	button.add_theme_stylebox_override("normal", style)

	var hover_style = style.duplicate()
	hover_style.bg_color = color * 1.2
	button.add_theme_stylebox_override("hover", hover_style)

	var pressed_style = style.duplicate()
	pressed_style.bg_color = color * 0.8
	button.add_theme_stylebox_override("pressed", pressed_style)

	var disabled_style = style.duplicate()
	disabled_style.bg_color = Color(0.3, 0.3, 0.3, 0.5)
	disabled_style.border_color = Color(0.4, 0.4, 0.4)
	button.add_theme_stylebox_override("disabled", disabled_style)

# ============================================
# UPDATE FUNCTIONS
# ============================================
func set_player(player: Node2D):
	player_reference = player

func update_display():
	if not player_reference:
		return

	var current_hp = player_reference.current_health if "current_health" in player_reference else 0.0
	var max_hp = player_reference.max_health if "max_health" in player_reference else 100.0

	# Update health display
	if health_display_label:
		health_display_label.text = "HP: %d / %d" % [int(current_hp), int(max_hp)]

		# Color based on health percentage
		var health_percent = current_hp / max_hp if max_hp > 0 else 0.0
		if health_percent > 0.6:
			health_display_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
		elif health_percent > 0.3:
			health_display_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.4))
		else:
			health_display_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))

	# Update free heal button
	_update_free_heal_button(current_hp, max_hp)

	# Update full heal button
	_update_full_heal_button(current_hp, max_hp)

func _update_free_heal_button(current_hp: float, max_hp: float):
	if not free_heal_button:
		return

	if free_heal_used:
		free_heal_button.disabled = true
		free_heal_button.text = "Free Heal (Used)"
	elif current_hp >= max_hp:
		free_heal_button.disabled = true
		free_heal_button.text = "Free Heal (Full HP)"
	else:
		free_heal_button.disabled = false
		free_heal_button.text = "Free Heal (30%)"

func _update_full_heal_button(current_hp: float, max_hp: float):
	if not full_heal_button:
		return

	var game_manager = get_tree().get_first_node_in_group("game_manager")
	var current_gold = 0
	if game_manager:
		current_gold = game_manager.get_gold()

	if current_hp >= max_hp:
		full_heal_button.disabled = true
		full_heal_button.text = "Full Heal (Full HP)"
	elif current_gold < ShopData.FULL_HEAL_PRICE:
		full_heal_button.disabled = true
		full_heal_button.text = "Full Heal - Need %d" % ShopData.FULL_HEAL_PRICE
	else:
		full_heal_button.disabled = false
		full_heal_button.text = "Full Heal (%d Gold)" % ShopData.FULL_HEAL_PRICE

# ============================================
# HEAL FUNCTIONS
# ============================================
func _on_free_heal_pressed():
	if not player_reference or free_heal_used:
		return

	var max_hp = player_reference.max_health if "max_health" in player_reference else 100.0
	var current_hp = player_reference.current_health if "current_health" in player_reference else 0.0

	if current_hp >= max_hp:
		return

	var heal_amount = max_hp * ShopData.FREE_HEAL_PERCENT

	# Apply heal
	_apply_heal(heal_amount)

	# Mark as used
	free_heal_used = true

	# Visual feedback
	_show_heal_effect(heal_amount)

	# Update display
	update_display()
	healed.emit(heal_amount)

func _on_full_heal_pressed():
	if not player_reference:
		return

	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if not game_manager:
		return

	if game_manager.get_gold() < ShopData.FULL_HEAL_PRICE:
		return

	var max_hp = player_reference.max_health if "max_health" in player_reference else 100.0
	var current_hp = player_reference.current_health if "current_health" in player_reference else 0.0

	if current_hp >= max_hp:
		return

	# Spend gold
	if not game_manager.spend_gold(ShopData.FULL_HEAL_PRICE):
		return

	var heal_amount = max_hp - current_hp

	# Apply heal
	_apply_heal(heal_amount)

	# Visual feedback
	_show_heal_effect(heal_amount)

	# Update display and emit signals
	update_display()
	healed.emit(heal_amount)
	gold_changed.emit()

func _apply_heal(amount: float):
	if player_reference.has_method("heal"):
		player_reference.heal(amount)
	else:
		var max_hp = player_reference.max_health if "max_health" in player_reference else 100.0
		player_reference.current_health = min(player_reference.current_health + amount, max_hp)

func _show_heal_effect(heal_amount: float):
	var heal_label = Label.new()
	heal_label.text = "+%d HP" % int(heal_amount)
	heal_label.add_theme_font_size_override("font_size", 28)
	heal_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
	heal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	add_child(heal_label)
	heal_label.position = Vector2(50, -30)

	# Animate float up and fade
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(heal_label, "position:y", heal_label.position.y - 50, 1.0)
	tween.tween_property(heal_label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(heal_label.queue_free)

# ============================================
# STATE MANAGEMENT
# ============================================
func reset_free_heal():
	free_heal_used = false
	update_display()
