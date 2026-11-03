shader_type canvas_item;
uniform float open_amount : hint_range(0.0,1.0) = 0.0;
uniform vec4 atlas_region = vec4(0.0,0.0,1.0,1.0);
uniform bool lights_on = true;
varying vec4 building_tint;
void vertex() { building_tint = COLOR; }
void fragment() {
	vec4 ink = texture(TEXTURE,UV);
	if (!lights_on && ink.r>0.35 && ink.r>ink.b*1.4 && ink.g>ink.b*1.15) {
		ink.rgb *= vec3(0.20,0.27,0.34);
	}
	vec2 local_uv = (UV-atlas_region.xy)/atlas_region.zw;
	float facade = smoothstep(0.22,0.36,local_uv.y);
	ink.a *= 1.0-open_amount*facade*0.98;
	COLOR = ink*building_tint;
}
