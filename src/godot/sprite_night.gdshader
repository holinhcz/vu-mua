shader_type canvas_item;
#include "res://night.gdshaderinc"
// every plain picture of the village (scenery, objects, verges, pond and bank plants, the sky), then the night colours.
// One shared material, so the pictures still batch.
// Sharpness (Link 11-12 "vẫn mờ"): a picture drawn smaller than its pixels was shrunk by one bilinear lookup (or a
// box-filtered mip), which washes out the thin dark outlines. The web game's canvas shrinks with a sharp filter. Here
// each screen pixel averages its own footprint on the picture (2x2 taps spread over it, no aliasing), then a Lanczos-
// like lift (footprint average minus a wider average) brings the edges and outlines back to full contrast.
varying vec4 vmod;
const float SHARP = 0.6;
uniform float uSway = 0.0;
uniform float uFast = 0.0;   // test ?do2 only: plain lookup, to measure what the sharp filter costs   // 1 while the web would sway plants (zoom >= .7)
void vertex() {
	vmod = COLOR;
	if (COLOR.a > 0.993 && COLOR.a < 0.998) {   // a swaying plant (alpha 254/255): local origin = its foot
		vmod.a = 1.0;
		if (uSway > 0.0) {
			// web: rotate(sin(t*1.1 + ph) * .017) about the foot; ph from the plant's place, so neighbours move apart
			vec2 wo = MODEL_MATRIX[3].xy;
			float ph = fract(sin(dot(floor(wo), vec2(12.9898, 78.233))) * 43758.5453) * 6.2832;
			float a = sin(TIME * 1.1 + ph) * 0.017;
			float c = cos(a), s = sin(a);
			VERTEX = vec2(c * VERTEX.x - s * VERTEX.y, s * VERTEX.x + c * VERTEX.y);
		}
	}
}
vec4 box4(sampler2D t, vec2 uv, vec2 ax, vec2 ay, float lod) {
	return 0.25 * (textureLod(t, uv + ax + ay, lod) + textureLod(t, uv - ax + ay, lod)
		+ textureLod(t, uv + ax - ay, lod) + textureLod(t, uv - ax - ay, lod));
}
void fragment() {
	vec2 ts = vec2(textureSize(TEXTURE, 0));
	vec2 dx = dFdx(UV), dy = dFdy(UV);
	float d = max(length(dx * ts), length(dy * ts));   // picture pixels per screen pixel
	vec4 c;
	if (d <= 1.05 || uFast > 0.5) {
		c = texture(TEXTURE, UV, -1.0);
	} else {
		float lod = max(0.0, log2(d * 0.5));            // each bilinear tap then covers half the footprint
		vec4 a = box4(TEXTURE, UV, dx * 0.25, dy * 0.25, lod);
		vec4 w = box4(TEXTURE, UV, dx * 0.75, dy * 0.75, lod);
		// lift only where the picture is solid, so cut-out edges get no halo
		float k = SHARP * clamp(min(a.a, w.a) * 1.25 - 0.25, 0.0, 1.0);
		c = vec4(clamp(a.rgb + (a.rgb - w.rgb) * k, 0.0, 1.0), a.a);
	}
	c *= vmod;
	c.rgb = night_col(c.rgb);
	COLOR = c;
}
