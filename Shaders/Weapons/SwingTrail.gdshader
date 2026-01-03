shader_type canvas_item;

// Universal Swing Trail Shader
// For all melee weapons - creates a glowing arc trail effect

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 trail_color : source_color = vec4(0.7, 0.8, 1.0, 0.8);
uniform vec4 glow_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float glow_intensity : hint_range(0.0, 5.0) = 2.0;
uniform float edge_softness : hint_range(0.0, 1.0) = 0.3;
uniform float taper_amount : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	vec2 uv = UV;

	// Taper at ends for natural swing look
	float taper = smoothstep(0.0, 0.1 + taper_amount * 0.1, uv.x) * smoothstep(1.0, 0.9 - taper_amount * 0.1, uv.x);

	// Edge glow - brighter at center
	float center_dist = abs(uv.y - 0.5) * 2.0;
	float edge = 1.0 - smoothstep(0.0, edge_softness + 0.3, center_dist);

	// Core brightness
	float core = smoothstep(0.5, 0.0, center_dist);

	// Combine
	float alpha = edge * taper;

	// Fade based on progress (animation)
	float fade = 1.0 - pow(progress, 0.7);
	alpha *= fade;

	// Color mixing - core is brighter
	vec3 final_color = mix(trail_color.rgb, glow_color.rgb, core * 0.7);
	final_color += glow_color.rgb * core * glow_intensity * fade * 0.3;

	COLOR = vec4(final_color, alpha * trail_color.a);
}
