shader_type canvas_item;
#include "res://night.gdshaderinc"
// The hill's top was one flat lime colour in its picture: lay the village's own grass there instead (the ground's
// n2_codai texture with the same wild recolour, in world space so it joins the ground's grain), a little darker and
// drier towards the edge where the soil is thin, the rim band as the earth-and-grass lip of the cliff.
// Mask n/hilltop.webp (tools/fallrock.py): R top, G rim band, B distance in from the edge, A cover. 2 samplers.
uniform sampler2D uCodai : repeat_enable, filter_linear_mipmap;
uniform vec3 gW = vec3(1.06);
uniform vec3 oW = vec3(0.1700, 0.2650, 0.0920);
uniform float tS = 281.6;
varying vec2 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy; }
float hh(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vno(vec2 p) { vec2 i = floor(p), f = p - i; f = f * f * (3.0 - 2.0 * f);
	float a = hh(i), b = hh(i + vec2(1.0, 0.0)), c = hh(i + vec2(0.0, 1.0)), d = hh(i + vec2(1.0, 1.0));
	return a + (b - a) * f.x + (c - a) * f.y + (a - b - c + d) * f.x * f.y; }
// (n15, Link "thác ... logic hơn"): the fall needs water up here. A spring comes out from under the rock at the back
// right, runs as a little brook and gathers in a pool right behind the notch, which spills over the lip.
// Distances on the ground plane (y doubled: iso).
float seg(vec2 p, vec2 a, vec2 b) { vec2 ab = b - a; float t = clamp(dot(p - a, ab) / dot(ab, ab), 0.0, 1.0); return length(p - a - ab * t); }
const vec2 BK[5] = vec2[](vec2(4684.0, 262.0), vec2(4670.0, 268.5), vec2(4655.0, 274.0), vec2(4641.0, 279.0), vec2(4628.0, 284.0));
vec3 spring(vec2 w) {   // x: signed distance to the water's edge (plane units, < 0 in the water), yz: flow direction (screen)
	vec2 q = vec2(w.x, w.y * 2.0);
	vec2 pc = vec2(4624.0, 285.5 * 2.0);
	vec2 pr = vec2(23.0, 17.0);
	float dp = (length((q - pc) / pr) - 1.0) * min(pr.x, pr.y);
	float db = 1e3; vec2 fd = vec2(-0.9, 0.45);
	for (int k = 0; k < 0; k++) {   // (n16, Link: no channel cut across the top - the pool is a spring, wells up in place)
		vec2 a = BK[k] * vec2(1.0, 2.0), b = BK[k + 1] * vec2(1.0, 2.0);
		float wd = mix(2.6, 5.0, float(k) / 3.0);
		float d = seg(q, a, b) - wd;
		if (d < db) { db = d; fd = normalize(BK[k + 1] - BK[k]); }
	}
	float k2 = 5.0, hgap = clamp(0.5 + 0.5 * (db - dp) / k2, 0.0, 1.0);
	float d = mix(db, dp, hgap) - k2 * hgap * (1.0 - hgap);
	d += (vno(w * 0.35) - 0.5) * 2.6 + (vno(w * 1.1 + 5.0) - 0.5) * 0.9;
	vec2 dir = mix(fd, vec2(0.0, 1.0), hgap);
	return vec3(d, dir);
}
void fragment() {
	vec4 m = texture(TEXTURE, UV);
	if (m.a < 0.004) discard;
	vec3 g = texture(uCodai, wp / tS).rgb * gW + oW;
	float n = vno(wp * 0.06) * 0.6 + vno(wp * 0.17 + 3.0) * 0.4;
	float ed = smoothstep(0.0, 0.6, m.b);
	// thin, drier turf near the edge, patchy
	g = mix(g, g * vec3(1.06, 1.0, 0.82), (1.0 - ed) * 0.22 * smoothstep(0.3, 0.7, n));
	g *= 1.0 + 0.04 * ed + 0.05 * (n - 0.5);
	// the lip: grass hanging over a strip of dark earth
	float lipN = vno(vec2(wp.x * 0.5, wp.y * 0.2));
	vec3 earth = mix(vec3(0.30, 0.24, 0.16), vec3(0.42, 0.34, 0.22), lipN);
	vec3 lip = mix(earth, g * 0.78, smoothstep(0.35, 0.65, lipN + 0.25 * (UV.y - 0.5)));
	vec3 c = mix(g, lip, m.g);
	// the notch's two stones were flat grey faces: wet rock with layers, cracks, dark streaks where water runs, moss
	if (m.r + m.g < 0.04) {
		float L = m.b;
		float lay = vno(vec2(wp.x * 0.15, wp.y * 1.1)) * 0.6 + vno(vec2(wp.x * 0.5, wp.y * 2.6) + 4.0) * 0.4;
		float ck = 1.0 - smoothstep(0.0, 0.06, abs(vno(vec2(wp.x * 0.35 + 9.0, wp.y * 0.9)) - 0.5));
		float wet = smoothstep(0.45, 0.75, vno(vec2(wp.x * 0.9, wp.y * 0.08) + 2.0));
		vec3 rk = mix(vec3(0.33, 0.32, 0.29), vec3(0.56, 0.53, 0.48), lay);
		rk *= 0.5 + 0.75 * L;
		rk *= 1.0 - 0.35 * ck - 0.3 * wet;
		float ms = smoothstep(0.68, 0.8, vno(wp * 0.7 + 11.0)) * (1.0 - wet);
		rk = mix(rk, vec3(0.30, 0.38, 0.17), ms * 0.6);
		c = rk;
	}
	if (m.r > 0.3) {
		vec3 sp = spring(wp);
		float d = sp.x;
		if (d < 4.5) {
			float t = TIME;
			// bank: wet dark earth under a lip of lush grass
			float lipN = vno(wp * 0.9 + 3.0);
			vec3 bank = mix(vec3(0.20, 0.17, 0.11), vec3(0.30, 0.25, 0.16), vno(wp * 0.5));
			float bk = (1.0 - smoothstep(0.5 + 0.8 * lipN, 1.4 + 0.8 * lipN, d)) * 0.8;   // a thin wet edge, grass right to the water
			vec3 cg = mix(c, c * vec3(0.82, 0.9, 0.8), 1.0 - smoothstep(2.0, 4.5, d));
			c = mix(cg, bank, bk);
			if (d < 0.6) {
				vec2 fd = sp.yz;
				vec2 fn = vec2(-fd.y, fd.x);
				float al = dot(wp, fd), ac = dot(wp, fn);
				float deep = smoothstep(0.0, 9.0, -d);
				vec3 wc = mix(vec3(0.40, 0.56, 0.44), vec3(0.24, 0.48, 0.48), deep);
				// (n16c) a clear shallow spring: its pebbly bottom shows through, not a dark bowl
				float pb = vno(wp * 1.6 + 3.0) * 0.6 + vno(wp * 3.7) * 0.4;
				wc *= 0.86 + 0.24 * pb;
				float r1 = vno(vec2(al * 0.22 - t * 1.6, ac * 0.7)), r2 = vno(vec2(al * 0.4 - t * 2.4, ac * 1.1) + 7.0);
				wc *= 0.92 + 0.16 * (r1 * 0.6 + r2 * 0.4);
				float sky = smoothstep(0.6, 0.85, r1 * r2 * 1.7);
				wc = mix(wc, vec3(0.72, 0.88, 0.86), 0.35 * sky);
				float glint = smoothstep(0.93, 0.98, vno(vec2(al * 0.9 - t * 3.0, ac * 2.2) + 3.0)) * deep;
				wc = mix(wc, vec3(1.0, 1.0, 0.95), 0.6 * glint);
				// pale bubbles where the spring wells up
				float sw = 1.0 - smoothstep(0.0, 7.0, length((wp - vec2(4627.0, 283.0)) * vec2(1.0, 2.0)) * 0.6);
				wc = mix(wc, vec3(0.85, 0.94, 0.92), sw * smoothstep(0.55, 0.75, vno(wp * 1.4 + vec2(0.0, -t * 2.0))) * 0.6);
				// darker band right under the bank, a thin pale edge line
				wc *= 1.0 - 0.12 * (1.0 - smoothstep(-2.5, 0.0, d)) * smoothstep(-0.2, -1.5, d);
				float a = smoothstep(0.6, -0.4, d);
				c = mix(c, wc, a);
				c = mix(c, vec3(0.75, 0.86, 0.80), 0.35 * (1.0 - smoothstep(0.0, 0.5, abs(d + 0.5))));
			}
			// (n16c) the spring's rim is a ring of mossy stones half in the water, not a bare dark bowl
			if (d > -1.6 && d < 2.8) {
				vec2 q = vec2(wp.x, wp.y * 2.0) / 2.8;
				vec2 ci = floor(q), cf = q - ci;
				float best = 9.0; vec2 bo = vec2(0.0); vec2 bid = vec2(0.0);
				for (int j = -1; j <= 1; j++) for (int i = -1; i <= 1; i++) {
					vec2 id = ci + vec2(float(i), float(j));
					vec2 o = vec2(float(i), float(j)) + 0.25 + 0.5 * vec2(hh(id + 1.0), hh(id + 2.0)) - cf;
					float rr = 0.42 + 0.2 * hh(id + 3.0);
					float e = length(o) / rr;
					if (e < best && hh(id + 5.0) > 0.45) { best = e; bo = o / rr; bid = id; }
				}
				float band = smoothstep(-1.6, -0.6, d) * (1.0 - smoothstep(1.8, 2.8, d));
				float sa = clamp((1.0 - best) * 6.0, 0.0, 1.0) * band;
				if (sa > 0.0) {
					vec3 st = mix(vec3(0.40, 0.39, 0.35), vec3(0.60, 0.57, 0.50), hh(bid + 4.0));
					st *= 1.12 - 0.45 * smoothstep(-0.7, 0.8, -bo.y) * 0.0 - 0.4 * smoothstep(-0.5, 0.9, bo.y);
					st = mix(st, vec3(0.30, 0.38, 0.17), 0.45 * smoothstep(0.62, 0.8, vno(wp * 0.9 + bid)) * smoothstep(0.2, -0.6, bo.y));
					st *= mix(0.72, 1.0, smoothstep(-0.8, 0.8, d));   // wet low down
					c = mix(c * (1.0 - 0.3 * clamp((1.3 - length(bo - vec2(0.0, 0.35))) * 3.0, 0.0, 1.0) * band), st, sa);
				}
			}
		}
	}
	COLOR = vec4(night_col(c), m.a);
}
