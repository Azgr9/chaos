shader_type canvas_item;

// Pixel Art Slash Effect Shader
// Creates pixelated, retro-style slash trails for melee weapons

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 slash_color : source_color = vec4(1.0, 1.0, 1.0, 0.9);
uniform vec4 edge_color : source_color = vec4(0.8, 0.8, 0.8, 0.7);
uniform float pixel_size : hint_range(1.0, 16.0) = 4.0;
uniform float dither_amount : hint_range(0.0, 1.0) = 0.3;
uniform float edge_thickness : hint_range(0.0, 0.5) = 0.15;

// Pixelate UV coordinates
vec2 pixelate(vec2 uv, float size) {
	vec2 pixel_uv = floor(uv * size) / size;
	return pixel_uv;
}

// Simple dither pattern
float dither(vec2 uv, float threshold) {
	vec2 grid = floor(mod(uv * 8.0, 2.0));
	float pattern = mod(grid.x + grid.y, 2.0);
	return pattern * threshold;
}

void fragment() {
	vec2 uv = UV;

	// Pixelate the UV coordinates for blocky look
	float pixel_scale = 1.0 / pixel_size;
	vec2 pixel_uv = pixelate(uv, 32.0 / pixel_size);

	// Taper at ends for slash shape
	float taper = step(0.05, pixel_uv.x) * step(pixel_uv.x, 0.95);

	// Hard edge detection (no smoothstep for pixel look)
	float center_dist = abs(pixel_uv.y - 0.5) * 2.0;

	// Core (bright center)
	float core = step(center_dist, 0.3);

	// Edge (darker outline)
	float edge = step(center_dist, 0.5 + edge_thickness) * (1.0 - core);

	// Combine with taper
	float alpha = (core + edge * 0.7) * taper;

	// Apply dithering for fade effect
	float dither_threshold = dither(uv * 64.0, dither_amount);
	float fade = 1.0 - progress;
	alpha *= step(dither_threshold, fade);

	// Color - core is bright, edge is darker
	vec3 final_color = mix(edge_color.rgb, slash_color.rgb, core);

	COLOR = vec4(final_color, alpha * slash_color.a);
}
