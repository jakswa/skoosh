shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D detail_albedo : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D detail_normal : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D detail_roughness : hint_default_white, repeat_enable, filter_linear_mipmap_anisotropic;
uniform float detail_scale = 13.0;
uniform float macro_scale = 92.0;
uniform float normal_strength = 0.22;

varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec2 detail_uv = world_position.xz / detail_scale;
	vec2 macro_uv = world_position.xz / macro_scale + vec2(0.173, 0.417);
	float detail = texture(detail_albedo, detail_uv).r;
	float macro = texture(detail_albedo, macro_uv).r;
	float value_multiplier = mix(0.82, 1.12, detail) * mix(0.91, 1.08, macro);
	ALBEDO = COLOR.rgb * value_multiplier;
	ROUGHNESS = clamp(texture(detail_roughness, detail_uv).r, 0.64, 0.98);
	METALLIC = 0.0;

	vec3 sampled = texture(detail_normal, detail_uv).xyz * 2.0 - 1.0;
	vec3 detail_world = normalize(vec3(sampled.x, sampled.z, sampled.y));
	vec3 combined_world = normalize(world_normal + (detail_world - vec3(0.0, 1.0, 0.0)) * normal_strength);
	NORMAL = normalize((VIEW_MATRIX * vec4(combined_world, 0.0)).xyz);
}
