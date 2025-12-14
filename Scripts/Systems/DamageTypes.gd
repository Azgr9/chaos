# SCRIPT: DamageTypes.gd
# LOCATION: res://Scripts/Systems/DamageTypes.gd
# Damage type enum for colored damage numbers - standalone to avoid circular dependencies

class_name DamageTypes
extends RefCounted

enum Type {
	PHYSICAL,   # White - melee, basic attacks
	FIRE,       # Orange - fire grates, burn effects
	POISON,     # Green - poison effects
	ELECTRIC,   # Cyan/Blue - lightning, shock
	SPIKE,      # Gray - spikes, crushers
	CRIT,       # Yellow - critical hits
	HEAL,       # Green (bright) - healing numbers
	BLEED       # Dark red - bleed effects
}

# Color mapping for each damage type
const COLORS = {
	Type.PHYSICAL: Color.WHITE,
	Type.FIRE: Color(1.0, 0.5, 0.1, 1.0),      # Orange
	Type.POISON: Color(0.4, 0.9, 0.2, 1.0),    # Green
	Type.ELECTRIC: Color(0.3, 0.8, 1.0, 1.0),  # Cyan
	Type.SPIKE: Color(0.7, 0.7, 0.7, 1.0),     # Gray
	Type.CRIT: Color(1.0, 0.9, 0.2, 1.0),      # Yellow
	Type.HEAL: Color(0.2, 1.0, 0.4, 1.0),      # Bright green
	Type.BLEED: Color(0.8, 0.1, 0.1, 1.0)      # Dark red
}
