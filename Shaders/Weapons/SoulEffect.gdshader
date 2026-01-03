shader_type canvas_item;

// Soul/Spirit Effect Shader
// For Scythe lifesteal, death effects, and spirit particles

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 soul_color : source_color = vec4(0.4, 0.9, 0.5, 0.8);
uniform vec4 inner_color : source_color = vec4(0.8, 1.0, 0.9, 1.0);
uniform float wobble_speed : hint_range(0.0, 20.0) = 5.0;
uniform float wobble_amount : hint_range(0.0, 0.3) = 0.1;
uniform float ethereal_fade : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	vec2 uv = UV - 0.5;

	// Wobbling distortion for ethereal look
	float wobble = sin(TIME * wobble_speed + uv.y * 10.0) * wobble_amount;
	uv.x += wobble * (1.0 - progress);

	float dist = length(uv) * 2.0;

	// Soft glowing orb
	float glow = smoothstep(1.0, 0.0, dist);

	// Inner bright core
	float core = smoothstep(0.4, 0.0, dist);

	// Ethereal edge fade
	float edge = smoothstep(1.0, ethereal_fade, dist);

	// Fade with progress
	float fade = 1.0 - pow(progress, 0.6);

	// Flickering effect
	float flicker = sin(TIME * 15.0 + uv.x * 20.0) * 0.1 + 0.9;

	float alpha = glow * edge * fade * flicker;

	// Color blend
	vec3 final_color = mix(soul_color.rgb, inner_color.rgb, core);

	COLOR = vec4(final_color, alpha * soul_color.a);
}
