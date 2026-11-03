shader_type canvas_item;

uniform vec4 rim_color : source_color = vec4(0.40,0.67,0.72,0.7);
uniform float thickness = 9.0;
varying vec4 actor_tint;

void vertex() {
	actor_tint = COLOR;
}

void fragment() {
	vec4 ink = texture(TEXTURE, UV);
	vec2 step_uv = TEXTURE_PIXEL_SIZE * thickness;
	float edge = max(max(texture(TEXTURE,UV+vec2(step_uv.x,0.0)).a,texture(TEXTURE,UV-vec2(step_uv.x,0.0)).a),max(texture(TEXTURE,UV+vec2(0.0,step_uv.y)).a,texture(TEXTURE,UV-vec2(0.0,step_uv.y)).a));
	if (ink.a < 0.08) {
		COLOR = actor_tint * vec4(rim_color.rgb, edge*rim_color.a*0.65);
	} else {
		COLOR = actor_tint * ink;
	}
}
