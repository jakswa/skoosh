shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

varying vec3 world_position;
varying vec3 world_normal;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 fraction = fract(p);
	fraction = fraction * fraction * (3.0 - 2.0 * fraction);
	return mix(
		mix(hash21(cell), hash21(cell + vec2(1.0, 0.0)), fraction.x),
		mix(hash21(cell + vec2(0.0, 1.0)), hash21(cell + vec2(1.0)), fraction.x),
		fraction.y
	);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	float slope = 1.0 - clamp(world_normal.y, 0.0, 1.0);
	float broad = value_noise(world_position.xz / 38.0);
	float crust = value_noise(world_position.xz / 3.7);
	float wind = sin(world_position.x * 0.34 + world_position.z * 0.09 + broad * 2.5) * 0.5 + 0.5;
	float strata = smoothstep(0.43, 0.57, fract((world_position.y + broad * 1.6) / 3.25));
	float hardpack = (crust - 0.5) * 0.11 + (wind - 0.5) * 0.055;
	float rock_break = smoothstep(0.22, 0.58, slope) * mix(0.82, 1.08, strata);
	vec3 snow_tint = COLOR.rgb * (0.96 + hardpack);
	vec3 slate_tint = COLOR.rgb * mix(0.9, 1.08, broad) * mix(0.86, 1.05, strata);
	ALBEDO = mix(snow_tint, slate_tint, rock_break);
	ROUGHNESS = mix(0.88, 0.72, rock_break) + (crust - 0.5) * 0.08;
	METALLIC = 0.0;
	// Wind scoring and contour strata survive at traversal distance without tiling maps.
	NORMAL_MAP = normalize(vec3((wind - 0.5) * 0.12, (crust - 0.5) * 0.08, 1.0));
	NORMAL_MAP_DEPTH = mix(0.22, 0.38, rock_break);
}
