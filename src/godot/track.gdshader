shader_type canvas_item;
#include "res://night.gdshaderinc"
// footpaths (web NEN2 tracks()): the yard's earth (n2_dat recoloured C.yard, the ground's own uRA layer 8), world-space
uniform sampler2DArray uRA : repeat_enable, filter_linear_mipmap;
uniform vec3 gY = vec3(1.0173, 1.0118, 1.0097);
uniform vec3 oY = vec3(0.0129, 0.0074, 0.0044);
uniform float tY = 153.6;
uniform float uWet = 0.0;
varying vec2 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy; }
void fragment() {
	vec3 c = clamp(texture(uRA, vec3(wpos / tY, 8.0)).rgb * gY + oY, 0.0, 1.0);
	c = mix(c, pow(c, vec3(1.35)) * 0.9, uWet);
	COLOR = vec4(night_col(c), COLOR.a);
}
