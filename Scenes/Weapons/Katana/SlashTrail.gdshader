shader_type canvas_item;

// Katana Dash Slash Trail Shader
// Creates a glowing, fading slash effect

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 slash_color : source_color = vec4(1.0, 0.2, 0.2, 1.0);
uniform vec4 glow_color : source_color = vec4(1.0, 0.5, 0.3, 1.0);
uniform float glow_intensity : hint_range(0.0, 3.0) = 1.5;
uniform float edge_sharpness : hint_range(1.0, 10.0) = 3.0;

void fragment() {
	vec2 uv = UV;

	// Create slash shape - tapered at ends
	float taper = smoothstep(0.0, 0.15, uv.x) * smoothstep(1.0, 0.85, uv.x);

	// Edge glow effect
	float center_dist = abs(uv.y - 0.5) * 2.0;
	float edge = 1.0 - pow(center_dist, edge_sharpness);

	// Core slash (bright center)
	float core = smoothstep(0.6, 0.0, center_dist);

	// Combine with taper
	float alpha = edge * taper;

	// Fade based on progress
	float fade = 1.0 - progress;
	alpha *= fade;

	// Mix colors - core is brighter/whiter
	vec3 final_color = mix(slash_color.rgb, glow_color.rgb, core);
	final_color += vec3(core * 0.5); // Add white to core

	// Glow effect
	final_color *= 1.0 + (glow_intensity * core * fade);

	COLOR = vec4(final_color, alpha * slash_color.a);
}
