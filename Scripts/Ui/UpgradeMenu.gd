# SCRIPT: UpgradeMenu.gd
# ATTACH TO: UpgradeMenu (CanvasLayer) root in UpgradeMenu.tscn
# LOCATION: res://scripts/ui/UpgradeMenu.gd

class_name UpgradeMenu
extends CanvasLayer

# Nodes
@onready var control: Control = $Control
@onready var background: ColorRect = $Control/Background
@onready var container: VBoxContainer = $Control/Container
@onready var title_label: Label = $Control/Container/Title
@onready var subtitle_label: Label = $Control/Container/Subtitle
@onready var upgrade_cards: HBoxContainer = $Control/Container/UpgradeCards
@onready var weapon_shop_button: Button = $Control/WeaponShopButton
@onready var skip_button: Button = $Control/SkipButton

const KATANA_SCENE = preload("res://Scenes/Weapons/Katana.tscn")
const KATANA_PRICE = 1

# Card references
var card_panels: Array = []
var card_data: Array = []
var player_reference: Node2D = null
var upgrade_system: UpgradeSystem = null
var katana_purchased: bool = false

# Signals
signal upgrade_selected(upgrade: Dictionary)
signal menu_closed()

func _ready():
	# Hide initially
	visible = false

	# Set to process when paused so menu works during pause
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Create upgrade system instance
	upgrade_system = UpgradeSystem.new()
	add_child(upgrade_system)

	# Get card panels
	for child in upgrade_cards.get_children():
		if child is Panel:
			card_panels.append(child)

			# Connect button
			var button = child.get_node("VBox/SelectButton")
			if button:
				button.pressed.connect(_on_card_selected.bind(card_panels.size() - 1))

	# Connect skip button if it exists
	if skip_button:
		skip_button.pressed.connect(_on_skip_pressed)

	# Connect weapon shop button
	if weapon_shop_button:
		weapon_shop_button.pressed.connect(_on_weapon_shop_pressed)

func show_upgrades(player: Node2D):
	player_reference = player

	# Update weapon shop button
	_update_weapon_shop_button()

	# Get random upgrades
	card_data = upgrade_system.get_random_upgrades(3)

	# Pause game
	get_tree().paused = true

	# Show menu with animation
	visible = true
	control.modulate.a = 0.0

	var tween = create_tween()
	tween.tween_property(control, "modulate:a", 1.0, 0.3)

	# Animate container
	container.position.y = -50
	tween.parallel().tween_property(container, "position:y", 0, 0.3)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Setup cards
	_setup_cards()

	# Animate cards appearing
	_animate_cards_in()

func _setup_cards():
	for i in range(min(card_data.size(), card_panels.size())):
		var card = card_panels[i]
		var data = card_data[i]

		# Set card info
		var icon = card.get_node("VBox/Icon")
		var name_label = card.get_node("VBox/Name")
		var desc_label = card.get_node("VBox/Description")

		if icon:
			icon.color = data.icon_color
		if name_label:
			name_label.text = data.name
		if desc_label:
			desc_label.text = data.description

		# Style the panel
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.1, 0.15, 0.9)
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
		style.border_color = data.icon_color * 0.8
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8
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

	# Apply the upgrade
	if upgrade_system and player_reference:
		upgrade_system.apply_upgrade(player_reference, selected_upgrade)

	# Emit signal
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

	# Close menu after animation
	tween.tween_callback(_close_menu)

func _on_skip_pressed():
	_close_menu()

func _on_weapon_shop_pressed():
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if not game_manager:
		return

	# Check if player has enough crystals
	if game_manager.get_crystal_count() >= KATANA_PRICE:
		if game_manager.spend_crystals(KATANA_PRICE):
			_swap_weapon_to_katana()
			_update_weapon_shop_button()

func _update_weapon_shop_button():
	if not weapon_shop_button:
		return

	# Hide button if already purchased
	if katana_purchased:
		weapon_shop_button.visible = false
		return

	weapon_shop_button.visible = true
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if not game_manager:
		return

	var crystals = game_manager.get_crystal_count()
	if crystals >= KATANA_PRICE:
		weapon_shop_button.disabled = false
		weapon_shop_button.text = "Buy Katana (%d Crystal)" % KATANA_PRICE
	else:
		weapon_shop_button.disabled = true
		weapon_shop_button.text = "Need %d Crystals" % KATANA_PRICE

func _swap_weapon_to_katana():
	if not player_reference:
		return

	# Mark as purchased
	katana_purchased = true

	# Reset player attack state to prevent being stuck
	player_reference.is_attacking = false

	# Remove old weapon
	if player_reference.current_weapon:
		player_reference.current_weapon.queue_free()
		player_reference.weapon_inventory.clear()

	# Add new katana
	var new_weapon = KATANA_SCENE.instantiate()
	var weapon_holder = player_reference.get_node("WeaponPivot/WeaponHolder")
	weapon_holder.add_child(new_weapon)
	new_weapon.position = Vector2.ZERO

	player_reference.current_weapon = new_weapon
	player_reference.weapon_inventory.append(new_weapon)

	# Connect signals
	if new_weapon.has_signal("attack_finished"):
		new_weapon.attack_finished.connect(player_reference._on_attack_finished)

	# Reset attack state again after frame to ensure it's cleared
	await get_tree().process_frame
	player_reference.is_attacking = false

func _close_menu():
	# Animate out
	var tween = create_tween()
	tween.tween_property(control, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func():
		visible = false
		get_tree().paused = false
		menu_closed.emit()
	)
