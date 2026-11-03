shader_type canvas_item;
varying vec4 scenery_tint;
void vertex() { scenery_tint=COLOR; }
void fragment() {
	vec4 ink=texture(TEXTURE,UV);
	// Continuous side piers frame the deep wall without floating panels or alpha fades.
	float piers=max(step(UV.x,.16),step(.84,UV.x));
	float edge=max(step(abs(UV.x-.16),.002),step(abs(UV.x-.84),.002));
	vec3 stone=mix(ink.rgb*scenery_tint.rgb,vec3(.13,.18,.19),edge);
	COLOR=vec4(stone,max(piers,edge));
}
