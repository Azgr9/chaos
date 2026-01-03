shader_type canvas_item;

// Energy Glow Shader
// For charged attacks, skills, and power effects

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 energy_color : source_color = vec4(1.0, 0.8, 0.3, 1.0);
uniform vec4 core_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float pulse_speed : hint_range(0.0, 20.0) = 8.0;
uniform float pulse_intensity : hint_range(0.0, 1.0) = 0.3;
uniform float glow_size : hint_range(0.0, 2.0) = 1.0;

void fragment() {
	vec2 uv = UV - 0.5;
	float dist = length(uv) * 2.0;

	// Pulsing effect
	float pulse = sin(TIME * pulse_speed) * pulse_intensity + 1.0;

	// Core glow (bright center)
	float core = smoothstep(0.6 * glow_size, 0.0, dist) * pulse;

	// Outer glow
	float outer = smoothstep(1.0 * glow_size, 0.3 * glow_size, dist);

	// Fade with progress
	float fade = 1.0 - progress;

	// Combine
	float alpha = (core * 0.8 + outer * 0.4) * fade;

	// Color - core is white/bright
	vec3 final_color = mix(energy_color.rgb, core_color.rgb, core * 0.6);
	final_color *= pulse;

	COLOR = vec4(final_color, alpha * energy_color.a);
}
