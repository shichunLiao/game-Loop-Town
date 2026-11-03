shader_type canvas_item;
varying vec4 actor_tint;
void vertex() { actor_tint=COLOR; }
void fragment() {
	vec4 ink=texture(TEXTURE,UV);
	float gray=dot(ink.rgb,vec3(.22,.60,.18));
	// False copies have no warm eye or candle glow; the true sculptor retains it.
	ink.rgb=mix(ink.rgb,vec3(gray*.64,gray*.77,gray*.78),.90);
	COLOR=ink*actor_tint;
}
