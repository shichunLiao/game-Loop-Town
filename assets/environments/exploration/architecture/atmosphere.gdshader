shader_type canvas_item;

uniform float contrast = 0.8;
uniform float saturation = 0.85;
uniform float brightness = 0.8;
uniform float fog_strength = 0.18;
uniform vec4 fog_color : source_color = vec4(0.12, 0.17, 0.20, 1.0);
varying vec4 source_tint;

void vertex() {
	source_tint = COLOR;
}

void fragment() {
	vec4 ink = texture(TEXTURE, UV);
	float luma = dot(ink.rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 muted = mix(vec3(luma), ink.rgb, saturation);
	muted = (muted - vec3(0.5)) * contrast + vec3(0.5);
	muted *= brightness;
	muted = mix(muted, fog_color.rgb, fog_strength);
	COLOR = vec4(clamp(muted, 0.0, 1.0), ink.a) * source_tint;
}
