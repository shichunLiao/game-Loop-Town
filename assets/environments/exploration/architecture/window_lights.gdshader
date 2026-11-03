shader_type canvas_item;
uniform bool lights_on = true;
varying vec4 building_tint;
void vertex() { building_tint = COLOR; }
void fragment() {
	vec4 ink = texture(TEXTURE,UV);
	if (!lights_on && ink.r>0.35 && ink.r>ink.b*1.4 && ink.g>ink.b*1.15) {
		ink.rgb *= vec3(0.20,0.27,0.34);
	}
	COLOR = ink*building_tint;
}
