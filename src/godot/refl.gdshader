shader_type canvas_item;
#include "res://night.gdshaderinc"
// Tree reflections: every scenery picture standing at the water's edge is drawn again upside down under its foot
// (main.gd _build_refl), only where the river is (uA distance-to-shore > 0), swaying with the ripples, darker and
// tinted by the water, fading towards the crown. 2 samplers (the picture + the river map).
uniform sampler2D uA : filter_linear, repeat_disable;   // the river map: G = distance to the shore
uniform vec4 uMap;
uniform sampler2D uF : filter_linear, repeat_disable;   // nước nổi map (R: signed distance to the flood's edge)
uniform float uFlood = 0.;
uniform float uPond = 0.;   // 1: the ponds / canal / creek set, clipped to the pond field instead of the river map
uniform sampler2D uPF : filter_linear, repeat_disable;
uniform vec4 uPB;
uniform vec2 uKH;
float fF(vec2 w) {
	vec2 d = w - uKH; float a = d.x / 32.0, b = d.y / 16.0;
	vec2 uv = (vec2((a + b) * 0.5, (b - a) * 0.5) - uPB.xy) * 4.0 / uPB.zw;
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) return 0.0;
	return (texture(uPF, uv).r * 255.0 - 20.0) / 200.0;
}
uniform vec3 uTint = vec3(.165, .306, .267);   // the game's reflection tint #2a4e44
uniform float uAlpha = .3;   // the game draws them at .3 over the GL water
varying vec2 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy; }
void fragment() {
	vec2 muv = (wp - uMap.xy) / uMap.zw;
	float wm;
	if (uPond > .5) wm = smoothstep(.5, .58, fF(wp));
	else wm = smoothstep(.5, 3., texture(uA, muv).g * 255.);
	if (uFlood > .5 && uPond < .5) wm = max(wm, smoothstep(0., 3., (texture(uF, muv).r * 255. - 128.) * .25));
	if (wm <= 0.) discard;
	float t = TIME;
	float wob = sin(wp.y * .55 + t * 2.4 + sin(wp.x * .031 + t * .7) * 2.) * 1.3 + sin(wp.y * .21 - t * 1.3) * .8;
	vec4 c = texture(TEXTURE, UV + vec2(wob, 0.) * TEXTURE_PIXEL_SIZE * 6.);   // pictures are 6 px a world px
	float depth = 1. - UV.y;   // 0 at the foot (the waterline), 1 at the crown (deepest)
	// like the game: fades away towards the crown (1 -> .88 at 30 % -> .12), thin breaks across it where the surface moves
	float fade = depth < .3 ? mix(1., .88, depth / .3) : mix(.88, .12, (depth - .3) / .7);
	float yy = wp.y / 5.5 + sin(wp.x * .02 + t * .5) * .15;
	float cy = floor(yy);
	float h1 = fract(sin(cy * 12.9898) * 43758.547), h2 = fract(sin(cy * 78.233) * 12543.31);
	float cut = step(fract(yy), .1 + .06 * h2) * step(fract(wp.x / (70. + 60. * h2) + h1 + t * .02), .2 + .5 * h1);
	float a = c.a * uAlpha * fade * (1. - .6 * cut) * wm;
	COLOR = vec4(night_col(mix(c.rgb, uTint, .42)), a);
}
