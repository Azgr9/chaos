shader_type canvas_item;

// Line2D Trail Shader
// Creates a glowing trail effect that follows the weapon

uniform vec4 trail_color : source_color = vec4(0.8, 0.85, 0.9, 0.9);
uniform vec4 glow_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float glow_intensity : hint_range(0.0, 5.0) = 2.0;
uniform float core_sharpness : hint_range(0.0, 1.0) = 0.5;
uniform float shimmer_speed : hint_range(0.0, 10.0) = 3.0;
uniform float shimmer_amount : hint_range(0.0, 1.0) = 0.3;

void fragment() {
	vec2 uv = UV;

	// UV.x goes along the line (0 = start/old, 1 = end/new)
	// UV.y goes across the line width (0 and 1 = edges, 0.5 = center)

	// Center glow - brighter at the middle of the line width
	float center_dist = abs(uv.y - 0.5) * 2.0;
	float core = pow(1.0 - center_dist, 1.0 + core_sharpness * 2.0);

	// Edge softness
	float edge = 1.0 - smoothstep(0.3, 1.0, center_dist);

	// Fade along length - newer parts (high x) are brighter
	float length_fade = pow(uv.x, 0.5);

	// Shimmer effect
	float shimmer = sin(uv.x * 20.0 + TIME * shimmer_speed) * 0.5 + 0.5;
	shimmer = mix(1.0, shimmer, shimmer_amount);

	// Combine alpha
	float alpha = edge * length_fade * shimmer;

	// Color mixing - core is glow color, edges are trail color
	vec3 final_color = mix(trail_color.rgb, glow_color.rgb, core * 0.8);

	// Add extra glow at core
	final_color += glow_color.rgb * core * glow_intensity * 0.3 * length_fade;

	COLOR = vec4(final_color, alpha * trail_color.a);
}
