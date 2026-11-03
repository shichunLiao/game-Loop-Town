shader_type canvas_item;
varying vec4 scenery_tint;
void vertex() { scenery_tint=COLOR; }
void fragment() {
	vec4 ink=texture(TEXTURE,UV);
	// Preserve the outer silhouette, but remove ghostlike transparency inside it.
	COLOR=vec4(ink.rgb*scenery_tint.rgb,smoothstep(0.30,0.34,ink.a));
}
