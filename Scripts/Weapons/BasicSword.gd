# SCRIPT: BasicSword.gd
# ATTACH TO: BasicSword (Node2D) root node in BasicSword.tscn
# LOCATION: res://Scripts/Weapons/BasicSword.gd

class_name BasicSword
extends MeleeWeapon

# ============================================
# SWORD-SPECIFIC SETTINGS
# ============================================
const SKILL_SCENE = preload("res://Scenes/Weapons/BasicSword/BasicSwordSkill.tscn")

# Sprite2D texture reference (ColorRect "Sprite" is hidden for base class compatibility)
@onready var sword_sprite: Sprite2D = $Pivot/SwordTexture

# Visual colors
const SWORD_BLADE_COLOR: Color = Color(0.85, 0.85, 0.9)  # Polished silver
const SWORD_EDGE_COLOR: Color = Color(1.0, 1.0, 1.0)  # Bright edge

# Shaders
var spark_shader: Shader = preload("res://Shaders/Weapons/SparkBurst.gdshader")

func _weapon_ready():
	# BasicSword - balanced all-rounder
	damage = 10.0
	attack_duration = 0.22  # Slightly faster for responsiveness
	attack_cooldown = 0.32  # Quick recovery
	swing_arc = 150.0
	weapon_length = 80.0
	weapon_color = SWORD_BLADE_COLOR
	skill_cooldown = 8.0

	# Idle - Sword held at ready, classic guard position
	idle_rotation = 45.0  # Diagonal guard
	idle_position = Vector2(3, -3)  # Slightly forward and up
	idle_scale = Vector2(0.6, 0.6)

	# Cone Hitbox - adjusted for new character size
	attack_range = 180.0  # Extended range to match visual sword reach
	attack_cone_angle = 100.0  # 50 degrees each side - balanced arc

	# Attack Speed Limits (balanced)
	max_attacks_per_second = 3.0  # ~3 attacks per second base
	min_cooldown = 0.18  # Cannot go below 180ms between attacks

	# Balanced knockback
	base_knockback = 350.0
	finisher_knockback = 600.0

	# Walk animation - balanced sword
	walk_bob_amount = 8.0
	walk_sway_amount = 12.0
	walk_anim_speed = 1.0

	# Apply idle state after setting custom values
	_setup_idle_state()

func _get_attack_pattern(attack_index: int) -> String:
	# BasicSword: horizontal -> horizontal_reverse -> overhead
	match attack_index:
		1: return "horizontal"
		2: return "horizontal_reverse"
		3: return "overhead"
		_: return "horizontal"

func _perform_skill() -> bool:
	# Spin Slash skill
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return false

	var skill_instance = SKILL_SCENE.instantiate()
	get_tree().current_scene.add_child(skill_instance)

	var slash_damage = damage * 2.0 * damage_multiplier
	skill_instance.initialize(player.global_position, slash_damage, player)

	if skill_instance.has_signal("dealt_damage"):
		var sword_ref = weakref(self)
		skill_instance.dealt_damage.connect(func(target, dmg):
			var sword = sword_ref.get_ref()
			if sword:
				sword.dealt_damage.emit(target, dmg)
		)

	return true

func _get_hit_color(combo_finisher: bool, dash_attack: bool, crit: bool) -> Color:
	if crit:
		return Color.RED
	elif combo_finisher:
		return Color.GOLD
	elif dash_attack:
		return Color.CYAN
	return SWORD_BLADE_COLOR

func _on_combo_finisher_hit(_target: Node2D):
	# Create flash effect on finisher
	DamageNumberManager.shake(0.3)
	_create_finisher_flash()

func _create_finisher_flash():
	if not player_reference:
		return

	var scene = get_tree().current_scene
	if not scene:
		return

	var hit_pos = player_reference.global_position + current_attack_direction * 50

	# Spark burst with shader
	var spark_burst = ColorRect.new()
	spark_burst.size = Vector2(120, 120)
	spark_burst.pivot_offset = Vector2(60, 60)
	spark_burst.global_position = hit_pos - Vector2(60, 60)

	var mat = ShaderMaterial.new()
	mat.shader = spark_shader
	mat.set_shader_parameter("spark_color", Color(0.8, 0.9, 1.0, 0.9))
	mat.set_shader_parameter("hot_color", SWORD_EDGE_COLOR)
	mat.set_shader_parameter("spark_count", 8.0)
	mat.set_shader_parameter("rotation_speed", 5.0)
	mat.set_shader_parameter("progress", 0.0)
	spark_burst.material = mat

	scene.add_child(spark_burst)

	var tween = TweenHelper.new_tween()
	tween.tween_method(func(p): mat.set_shader_parameter("progress", p), 0.0, 1.0, 0.25)
	tween.tween_callback(spark_burst.queue_free)

	# Additional glow flash
	var flash = ColorRect.new()
	flash.size = Vector2(80, 80)
	flash.color = Color(1.0, 1.0, 0.9, 0.6)
	flash.pivot_offset = Vector2(40, 40)
	scene.add_child(flash)
	flash.global_position = hit_pos - Vector2(40, 40)

	var flash_tween = TweenHelper.new_tween()
	flash_tween.set_parallel(true)
	flash_tween.tween_property(flash, "scale", Vector2(2.5, 2.5), 0.15)
	flash_tween.tween_property(flash, "modulate:a", 0.0, 0.15)
	flash_tween.tween_callback(flash.queue_free)
