shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

varying vec3 world_position;
varying vec3 world_normal;

uniform vec2 route_origin = vec2(0.0, -207.0);
uniform vec2 route_axis = vec2(1.0, 0.0);
uniform float route_half_length = 42.0;
uniform float route_bend = 0.0;
uniform float route_bend_extent = 42.0;
uniform float route_strength = 0.38;

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
	vec3 color = mix(snow_tint, slate_tint, rock_break);

	// STRATOS-derived grade and route grammar, restrained to physical field marks.
	float contour = 1.0 - smoothstep(0.035, 0.11, abs(fract((world_position.y + 64.0) / 3.25) - 0.5));
	color *= mix(1.0, 0.72, contour * (1.0 - rock_break * 0.55));
	vec2 route_delta = world_position.xz - route_origin;
	vec2 route_normal = vec2(-route_axis.y, route_axis.x);
	float route_progress = dot(route_delta, route_axis);
	float route_across = dot(route_delta, route_normal);
	float bend_progress = clamp(abs(route_progress) / route_bend_extent, 0.0, 1.0);
	route_across -= route_bend * (1.0 - bend_progress * bend_progress);
	float field = 1.0 - smoothstep(route_half_length - 10.0, route_half_length, abs(route_progress));
	float lane = 1.0 - smoothstep(2.55, 3.25, abs(route_across));
	float red_side = 1.0 - smoothstep(-3.0, 1.5, route_progress);
	float blue_side = smoothstep(-1.5, 3.0, route_progress);
	color = mix(color, vec3(0.42, 0.075, 0.045), lane * red_side * field * route_strength * (1.0 - rock_break));
	color = mix(color, vec3(0.035, 0.20, 0.38), lane * blue_side * field * route_strength * (1.0 - rock_break));
	float timing = 1.0 - smoothstep(0.035, 0.09, abs(fract((route_progress + 3.0) / 12.0) - 0.5));
	float timing_lane = 1.0 - smoothstep(3.25, 4.0, abs(route_across));
	color = mix(color, vec3(0.055, 0.07, 0.075), timing * timing_lane * field * 0.68);
	ALBEDO = color;
	ROUGHNESS = mix(0.88, 0.72, rock_break) + (crust - 0.5) * 0.08;
	METALLIC = 0.0;
	// Wind scoring and contour strata survive at traversal distance without tiling maps.
	NORMAL_MAP = normalize(vec3((wind - 0.5) * 0.12, (crust - 0.5) * 0.08, 1.0));
	NORMAL_MAP_DEPTH = mix(0.22, 0.38, rock_break);
}
