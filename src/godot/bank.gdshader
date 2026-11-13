shader_type canvas_item;
#include "res://night.gdshaderinc"
// River bank pictures (songgen.gd): polygons and strokes whose UV carries (mode, amount). Modes lay the game's bank detail
// textures (BTX) over the vertex colour: overlay of a grey texture, or a mask that cuts the stroke (ria grass edge, rach
// ragged edge, streak glints). 4 samplers only (phones).
uniform sampler2D uPT1 : repeat_enable, filter_linear_mipmap;   // co, vach, bun, dat
uniform sampler2D uPT2 : repeat_enable, filter_linear_mipmap;   // ria grey, ria alpha, rach alpha, loang alpha
uniform sampler2D uPT3 : repeat_enable, filter_linear_mipmap;   // glint streaks
uniform sampler2D uPT4 : repeat_enable, filter_linear_mipmap;   // nut (cracked mud)
uniform vec2 uKH;
uniform highp sampler2D uWash : filter_nearest, repeat_disable;   // songgen.wash_image(): per grid spot and arm (c, k, reach -, reach +)
uniform vec3 uWG;   // X0, ST, NJ of that table
// nước nổi: the flood's edge pictures stay off the roads (flood map B = signed distance to the nearest road tile)
uniform sampler2D uF : filter_linear, repeat_disable;
uniform vec4 uFM;
uniform vec4 uDull = vec4(.549, .588, .471, .42);
varying vec2 wp;
varying highp vec2 md;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy; md = UV; }
vec3 ovl(vec3 b, float s) { return mix(2.0 * b * s, 1.0 - 2.0 * (1.0 - b) * (1.0 - s), step(0.5, b)); }
vec2 s2g(vec2 w) { vec2 d = w - uKH; float a = d.x / 32.0, b = d.y / 16.0; return vec2((a + b) * 0.5, (b - a) * 0.5); }
void fragment() {
	int m = int(floor(md.x + 0.001));
	float e = (md.x - float(m)) * 2.0;           // 0..1 across a strip quad, 0.5 elsewhere
	bool dry = m >= 32;                           // nước nổi edge pictures (songgen _flood): kept off the roads, no dull wash
	if (dry) m -= 32;
	float px = max(fwidth(e), 1e-5);
	float cov = clamp(min(e, 1.0 - e) / px + 0.5, 0.0, 1.0);
	float al = md.y;
	vec4 c = COLOR;
	vec2 g = s2g(wp);
	if (m == 1) c.rgb = mix(c.rgb, ovl(c.rgb, texture(uPT1, wp * 10.0 / 1024.0).r), al);
	else if (m == 2) c.rgb = mix(c.rgb, ovl(c.rgb, texture(uPT1, wp * 9.0 / 1024.0).g), al);
	else if (m == 3) c.rgb = mix(c.rgb, ovl(c.rgb, texture(uPT1, g / 2.5).b), al);
	else if (m == 4) c.rgb = mix(c.rgb, ovl(c.rgb, texture(uPT1, g / 2.5).a), al);
	else if (m == 5) c.rgb = mix(c.rgb, ovl(c.rgb, texture(uPT4, g / 3.0).r), al);
	else if (m == 6 || m == 16) {
		vec4 r = texture(uPT2, (m == 6 ? wp : -wp) * 9.0 / 1024.0);
		c.rgb = ovl(c.rgb, r.r); c.a *= r.g * al;
	}
	else if (m == 7) c.a *= texture(uPT2, wp * 10.0 / 1024.0).b * al;
	else if (m == 8) c.a *= texture(uPT3, wp * 10.0 / 1024.0).r * al;
	else if (m == 9) c.a *= texture(uPT2, (wp - uKH) / 480.0).a * al;
	// the dull wash of land nobody has bought, on the bank and the mud only (the water stays clean, as in the game)
	float u = (g.x - uWG.x) / uWG.y;
	int j = clamp(int(floor(u)), 0, int(uWG.z) - 2);
	float f = clamp(u - float(j), 0., 1.);
	float wsh = 0.;
	for (int a = 0; a < 2; a++) {
		vec4 t = mix(texelFetch(uWash, ivec2(j, a), 0), texelFetch(uWash, ivec2(j + 1, a), 0), f);
		float s = (g.y - t.x) / max(t.y, 1e-4);
		wsh = max(wsh, clamp(min(s + t.z, t.w - s) / .04 + .5, 0., 1.));
	}
	if (!dry) c.rgb = mix(c.rgb, uDull.rgb, uDull.a * wsh);
	if (dry) {
		float rd = (texture(uF, (wp - uFM.xy) / uFM.zw).b * 255. - 128.) * .25;
		c.a *= clamp(rd / max(fwidth(wp.x), 1e-3) + .5, 0., 1.);
	}
	c.a *= cov;
	COLOR = vec4(night_col(c.rgb), c.a);
}
