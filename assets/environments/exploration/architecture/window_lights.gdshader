shader_type canvas_item;
uniform bool lights_on = true;
uniform float depth_contrast = 0.88;
uniform float depth_saturation = 0.90;
uniform float depth_brightness = 0.88;
uniform vec4 fog_color : source_color = vec4(0.12,0.17,0.20,1.0);
uniform float fog_strength = 0.08;
varying vec4 building_tint;
void vertex() { building_tint = COLOR; }
void fragment() {
	vec4 ink = texture(TEXTURE,UV);
	if (!lights_on && ink.r>0.35 && ink.r>ink.b*1.4 && ink.g>ink.b*1.15) {
		ink.rgb *= vec3(0.20,0.27,0.34);
	}
	float luma = dot(ink.rgb,vec3(0.2126,0.7152,0.0722));
	ink.rgb = mix(vec3(luma),ink.rgb,depth_saturation);
	ink.rgb = ((ink.rgb-vec3(0.5))*depth_contrast+vec3(0.5))*depth_brightness;
	ink.rgb = mix(ink.rgb,fog_color.rgb,fog_strength);
	COLOR = ink*building_tint;
}
