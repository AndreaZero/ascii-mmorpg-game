shader_type canvas_item;
render_mode unshaded;

uniform sampler2D glyphs : filter_linear, repeat_disable;
uniform vec2 resolution = vec2(1440.0, 900.0);
uniform float cell_size = 6.0;
uniform float exposure = 2.85;
uniform bool enabled = true;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
void fragment() {
	vec2 cell = vec2(cell_size, cell_size * 1.5);
	vec2 grid = floor(UV * resolution / cell);
	vec2 uv = (grid + 0.5) * cell / resolution;
	vec3 src = texture(TEXTURE, uv).rgb;
	float lum = pow(dot(src, vec3(0.299,0.587,0.114)),1.45);
	float rnd = hash(grid);
	float code = 46.0;
	if (lum > 0.025) code = 44.0;
	if (lum > 0.055) code = 58.0;
	if (lum > 0.09) code = 59.0;
	if (lum > 0.14) code = 43.0;
	if (lum > 0.20) code = 111.0;
	if (lum > 0.29) code = 120.0;
	if (lum > 0.39) code = 79.0;
	if (lum > 0.52) code = 77.0;
	if (lum > 0.70) code = 64.0;
	// Directional marks give foliage a different vocabulary from stone.
	if (src.g > src.r * 1.24 && src.g > src.b * 1.05 && lum > 0.035) {
		code = rnd < 0.30 ? 47.0 : (rnd < 0.60 ? 92.0 : 124.0);
		if (rnd > 0.86) code = 59.0;
		if (lum > 0.36 && rnd > 0.65) code = rnd < 0.8 ? 89.0 : 86.0;
	}
	if (src.b > src.r * 1.35 && src.b > src.g * 1.07) {
		code = rnd < 0.25 ? 126.0 : (rnd < 0.65 ? 45.0 : 46.0);
	}
	vec2 inner = fract(UV * resolution / cell);
	float index = code - 32.0;
	vec2 atlas_uv = (vec2(mod(index,16.0), floor(index/16.0)) + inner) / vec2(16.0,6.0);
	float ink = smoothstep(0.05,0.80,texture(glyphs, atlas_uv).a);
	vec3 paper = vec3(0.008,0.013,0.022);
	vec3 color = src * exposure + vec3(0.015,0.02,0.022);
	vec3 result = paper + color * ink + src * 0.075;
	float vignette = 1.0 - smoothstep(0.28,0.76,length((UV-0.5)*vec2(1.05,1.0))) * 0.64;
	COLOR = vec4((enabled ? result : texture(TEXTURE,UV).rgb) * vignette, 1.0);
}
