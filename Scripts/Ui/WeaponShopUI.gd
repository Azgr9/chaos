# SCRIPT: WeaponShopUI.gd
# Data-driven weapon shop system
# LOCATION: res://Scripts/Ui/WeaponShopUI.gd

class_name WeaponShopUI
extends Control

# ============================================
# SIGNALS
# ============================================
signal weapon_purchased(weapon_id: String)
signal gold_changed()

# ============================================
# STATE
# ============================================
var purchased_weapons: Array[String] = []
var weapon_buttons: Dictionary = {}  # weapon_id -> Button
var player_reference: Node2D = null

# Cached scenes for faster instantiation
var _weapon_scenes: Dictionary = {}

# ============================================
# UI CONTAINERS
# ============================================
var melee_container: VBoxContainer
var staff_container: VBoxContainer
var shop_title: Label

# ============================================
# CONFIGURATION
# ============================================
const BUTTON_MIN_SIZE = Vector2(200, 36)
const MELEE_HEADER_COLOR = Color(0.8, 0.6, 0.4)
const STAFF_HEADER_COLOR = Color(0.5, 0.7, 1.0)

func _ready():
	_build_shop_ui()

func _build_shop_ui():
	# Main container
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	add_child(main_vbox)

	# Shop title
	shop_title = Label.new()
	shop_title.text = "WEAPON SHOP"
	shop_title.add_theme_font_size_override("font_size", 22)
	shop_title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	shop_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(shop_title)

	# Horizontal split: melee left, staffs right
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 30)
	main_vbox.add_child(hbox)

	# Melee weapons column
	var melee_section = VBoxContainer.new()
	melee_section.add_theme_constant_override("separation", 6)
	hbox.add_child(melee_section)

	var melee_header = Label.new()
	melee_header.text = "MELEE"
	melee_header.add_theme_font_size_override("font_size", 16)
	melee_header.add_theme_color_override("font_color", MELEE_HEADER_COLOR)
	melee_section.add_child(melee_header)

	melee_container = VBoxContainer.new()
	melee_container.add_theme_constant_override("separation", 4)
	melee_section.add_child(melee_container)

	# Staff weapons column
	var staff_section = VBoxContainer.new()
	staff_section.add_theme_constant_override("separation", 6)
	hbox.add_child(staff_section)

	var staff_header = Label.new()
	staff_header.text = "MAGIC"
	staff_header.add_theme_font_size_override("font_size", 16)
	staff_header.add_theme_color_override("font_color", STAFF_HEADER_COLOR)
	staff_section.add_child(staff_header)

	staff_container = VBoxContainer.new()
	staff_container.add_theme_constant_override("separation", 4)
	staff_section.add_child(staff_container)

	# Create buttons for all weapons
	_create_weapon_buttons()

func _create_weapon_buttons():
	# Create melee weapon buttons
	for weapon_id in ShopData.MELEE_WEAPONS:
		var data = ShopData.MELEE_WEAPONS[weapon_id]
		var btn = _create_weapon_button(weapon_id, data, ShopData.WeaponType.MELEE)
		melee_container.add_child(btn)
		weapon_buttons[weapon_id] = btn

	# Create staff weapon buttons
	for weapon_id in ShopData.STAFF_WEAPONS:
		var data = ShopData.STAFF_WEAPONS[weapon_id]
		var btn = _create_weapon_button(weapon_id, data, ShopData.WeaponType.STAFF)
		staff_container.add_child(btn)
		weapon_buttons[weapon_id] = btn

func _create_weapon_button(weapon_id: String, data: Dictionary, _type: ShopData.WeaponType) -> Button:
	var btn = Button.new()
	btn.custom_minimum_size = BUTTON_MIN_SIZE
	btn.text = "%s (%d Gold)" % [data["name"], data["price"]]
	btn.pressed.connect(_on_weapon_button_pressed.bind(weapon_id))

	# Style the button
	_style_weapon_button(btn, data.get("icon_color", Color.WHITE))

	return btn

func _style_weapon_button(button: Button, accent_color: Color):
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.2, 0.9)
	style.border_color = accent_color * 0.7
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	button.add_theme_stylebox_override("normal", style)

	var hover_style = style.duplicate()
	hover_style.bg_color = Color(0.2, 0.2, 0.3, 0.95)
	hover_style.border_color = accent_color
	button.add_theme_stylebox_override("hover", hover_style)

	var pressed_style = style.duplicate()
	pressed_style.bg_color = accent_color * 0.5
	button.add_theme_stylebox_override("pressed", pressed_style)

	var disabled_style = style.duplicate()
	disabled_style.bg_color = Color(0.1, 0.1, 0.1, 0.6)
	disabled_style.border_color = Color(0.3, 0.3, 0.3, 0.5)
	button.add_theme_stylebox_override("disabled", disabled_style)

func _on_weapon_button_pressed(weapon_id: String):
	if weapon_id in purchased_weapons:
		return

	var data = ShopData.get_weapon_data(weapon_id)
	if data.is_empty():
		return

	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if not game_manager:
		return

	var price = data["price"]
	if game_manager.get_gold() < price:
		return

	# Spend gold and add weapon
	if game_manager.spend_gold(price):
		_add_weapon_to_player(weapon_id, data)
		purchased_weapons.append(weapon_id)
		weapon_purchased.emit(weapon_id)
		gold_changed.emit()
		update_all_buttons()

func _add_weapon_to_player(weapon_id: String, data: Dictionary):
	if not player_reference:
		return

	var weapon_type = data.get("type", ShopData.WeaponType.MELEE)
	var scene_path = data["scene"]

	# Load and cache scene
	if not _weapon_scenes.has(weapon_id):
		_weapon_scenes[weapon_id] = load(scene_path)

	var weapon_scene = _weapon_scenes[weapon_id]
	if not weapon_scene:
		push_warning("WeaponShopUI: Failed to load weapon scene: %s" % scene_path)
		return

	if weapon_type == ShopData.WeaponType.MELEE:
		_add_melee_weapon(weapon_scene)
	else:
		_add_staff_weapon(weapon_scene)

func _add_melee_weapon(weapon_scene: PackedScene):
	var weapon_holder = player_reference.get_node_or_null("WeaponPivot/WeaponHolder")
	if not weapon_holder:
		push_warning("WeaponShopUI: WeaponHolder not found on player")
		return

	var new_weapon = weapon_scene.instantiate()
	weapon_holder.add_child(new_weapon)
	new_weapon.position = Vector2.ZERO

	player_reference.weapon_inventory.append(new_weapon)

	if new_weapon.has_signal("attack_finished"):
		new_weapon.attack_finished.connect(player_reference._on_attack_finished)

	new_weapon.visible = false
	player_reference.switch_to_weapon(player_reference.weapon_inventory.size() - 1)

func _add_staff_weapon(weapon_scene: PackedScene):
	var staff_holder = player_reference.get_node_or_null("StaffPivot/StaffHolder")
	if not staff_holder:
		push_warning("WeaponShopUI: StaffHolder not found on player")
		return

	var new_staff = weapon_scene.instantiate()
	staff_holder.add_child(new_staff)
	new_staff.position = Vector2.ZERO

	player_reference.staff_inventory.append(new_staff)
	new_staff.visible = false
	player_reference.switch_to_staff(player_reference.staff_inventory.size() - 1)

# ============================================
# UPDATE FUNCTIONS
# ============================================
func set_player(player: Node2D):
	player_reference = player

func update_all_buttons():
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	var current_gold = 0
	if game_manager:
		current_gold = game_manager.get_gold()

	# Update melee weapon buttons
	for weapon_id in ShopData.MELEE_WEAPONS:
		_update_weapon_button(weapon_id, ShopData.MELEE_WEAPONS[weapon_id], current_gold)

	# Update staff weapon buttons
	for weapon_id in ShopData.STAFF_WEAPONS:
		_update_weapon_button(weapon_id, ShopData.STAFF_WEAPONS[weapon_id], current_gold)

func _update_weapon_button(weapon_id: String, data: Dictionary, current_gold: int):
	if not weapon_buttons.has(weapon_id):
		return

	var btn = weapon_buttons[weapon_id]
	var price = data["price"]
	var weapon_name = data["name"]

	# Hide if purchased
	if weapon_id in purchased_weapons:
		btn.visible = false
		return

	btn.visible = true

	# Update text and state based on gold
	if current_gold >= price:
		btn.disabled = false
		btn.text = "%s (%d Gold)" % [weapon_name, price]
	else:
		btn.disabled = true
		btn.text = "%s - Need %d" % [weapon_name, price]

# ============================================
# STATE MANAGEMENT
# ============================================
func is_weapon_purchased(weapon_id: String) -> bool:
	return weapon_id in purchased_weapons

func reset_purchases():
	purchased_weapons.clear()
	update_all_buttons()

func get_purchased_weapons() -> Array[String]:
	return purchased_weapons.duplicate()
