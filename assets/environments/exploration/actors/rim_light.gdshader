shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(0.13, 0.075, 0.055, 0.98);
uniform vec4 rim_color : source_color = vec4(0.91, 0.69, 0.39, 0.78);
uniform float outline_width = 1.85;
uniform float rim_width = 0.82;
uniform float body_brightness = 1.14;
uniform float black_point = 0.025;
uniform float white_point = 0.84;
uniform float face_lift = 0.07;
uniform vec4 face_region = vec4(0.34, 0.66, 0.15, 0.39);
uniform bool high_quality = true;
uniform vec4 uv_bounds = vec4(0.0, 0.0, 1.0, 1.0);
varying vec4 actor_tint;

void vertex() {
	actor_tint = COLOR;
}

void fragment() {
	vec4 ink = texture(TEXTURE, UV);
	vec2 dx = dFdx(UV) * outline_width;
	vec2 dy = dFdy(UV) * outline_width;
	float edge = 0.0;
	float lit_edge = 0.0;
	// Four cardinal taps are the low-cost path for ordinary NPCs/enemies.
	for (int i = 0; i < 4; i++) {
		float angle = float(i) * 1.57079632679;
		vec2 direction = vec2(cos(angle), sin(angle));
		vec2 sample_uv = UV + dx * direction.x + dy * direction.y;
		float in_bounds = float(sample_uv.x >= uv_bounds.x && sample_uv.y >= uv_bounds.y && sample_uv.x <= uv_bounds.z && sample_uv.y <= uv_bounds.w);
		sample_uv = clamp(sample_uv, uv_bounds.xy + TEXTURE_PIXEL_SIZE * 0.5, uv_bounds.zw - TEXTURE_PIXEL_SIZE * 0.5);
		float sampled = texture(TEXTURE, sample_uv).a * in_bounds;
		edge = max(edge, sampled);
		// Only the upper-left silhouette receives warm reflected light; no full halo.
		float light_side = clamp((direction.x + direction.y) * 0.72, 0.0, 1.0);
		lit_edge = max(lit_edge, sampled * light_side);
	}
	// Player, keeper and bosses retain diagonal samples for a smoother silhouette.
	if (high_quality) {
		for (int i = 0; i < 4; i++) {
			float angle = 0.78539816339 + float(i) * 1.57079632679;
			vec2 direction = vec2(cos(angle), sin(angle));
			vec2 sample_uv = UV + dx * direction.x + dy * direction.y;
			float in_bounds = float(sample_uv.x >= uv_bounds.x && sample_uv.y >= uv_bounds.y && sample_uv.x <= uv_bounds.z && sample_uv.y <= uv_bounds.w);
			sample_uv = clamp(sample_uv, uv_bounds.xy + TEXTURE_PIXEL_SIZE * 0.5, uv_bounds.zw - TEXTURE_PIXEL_SIZE * 0.5);
			float sampled = texture(TEXTURE, sample_uv).a * in_bounds;
			edge = max(edge, sampled);
			float light_side = clamp((direction.x + direction.y) * 0.72, 0.0, 1.0);
			lit_edge = max(lit_edge, sampled * light_side);
		}
	}
	float outer = max(0.0, edge - ink.a) * outline_color.a;
	float warm = max(0.0, lit_edge - ink.a) * rim_color.a * clamp(rim_width, 0.0, 1.0);
	float local_x = (UV.x - uv_bounds.x) / max(uv_bounds.z - uv_bounds.x, 0.0001);
	float local_y = (UV.y - uv_bounds.y) / max(uv_bounds.w - uv_bounds.y, 0.0001);
	vec3 leveled = clamp((ink.rgb - vec3(black_point)) / max(white_point - black_point, 0.001), 0.0, 1.0);
	float feather = 0.035;
	float face_mask = smoothstep(face_region.x - feather, face_region.x + feather, local_x) * (1.0 - smoothstep(face_region.y - feather, face_region.y + feather, local_x));
	face_mask *= smoothstep(face_region.z - feather, face_region.z + feather, local_y) * (1.0 - smoothstep(face_region.w - feather, face_region.w + feather, local_y));
	float luma = dot(leveled, vec3(0.2126, 0.7152, 0.0722));
	leveled += vec3(face_lift * face_mask * (1.0 - luma));
	leveled *= body_brightness;
	float halo = max(outer, warm);
	float alpha = ink.a + halo * (1.0 - ink.a);
	vec3 edge_rgb = mix(outline_color.rgb, rim_color.rgb, clamp(warm / max(outer + warm, 0.0001), 0.0, 0.72));
	vec3 rgb = (leveled * ink.a + edge_rgb * halo * (1.0 - ink.a)) / max(alpha, 0.0001);
	COLOR = vec4(clamp(rgb, 0.0, 1.0), alpha) * actor_tint;
}
