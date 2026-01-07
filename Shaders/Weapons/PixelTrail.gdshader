shader_type canvas_item;

// Pixel Art Trail Shader for Line2D
// Creates blocky, retro-style weapon trails

uniform vec4 trail_color : source_color = vec4(1.0, 1.0, 1.0, 0.9);
uniform vec4 edge_color : source_color = vec4(0.7, 0.7, 0.7, 0.6);
uniform float pixel_size : hint_range(1.0, 16.0) = 4.0;
uniform float dither_fade : hint_range(0.0, 1.0) = 0.4;
uniform float core_width : hint_range(0.1, 0.5) = 0.25;

vec2 pixelate(vec2 uv, float size) {
	return floor(uv * size) / size;
}

float dither_pattern(vec2 uv) {
	vec2 grid = floor(mod(uv * 16.0, 2.0));
	return mod(grid.x + grid.y, 2.0);
}

void fragment() {
	vec2 uv = UV;

	// Pixelate along the trail
	float pixel_scale = 16.0 / pixel_size;
	vec2 pixel_uv = pixelate(uv, pixel_scale);

	// Distance from center line (Y = 0.5 is center)
	float center_dist = abs(pixel_uv.y - 0.5) * 2.0;

	// Core (bright center) - hard edge
	float core = step(center_dist, core_width);

	// Edge (darker border) - hard edge
	float edge = step(center_dist, core_width + 0.3) * (1.0 - core);

	// Fade from new (x=1) to old (x=0) using dithering
	float age_fade = pixel_uv.x;  // 0 at start, 1 at end
	float dither = dither_pattern(uv * 32.0);
	float dither_threshold = age_fade * dither_fade + (1.0 - dither_fade);
	float fade_alpha = step(dither * dither_fade, dither_threshold);

	// Combine
	float alpha = (core + edge * 0.6) * fade_alpha;

	// Taper at the old end
	alpha *= smoothstep(0.0, 0.15, pixel_uv.x);

	vec3 final_color = mix(edge_color.rgb, trail_color.rgb, core);

	COLOR = vec4(final_color, alpha * trail_color.a);
}
