shader_type canvas_item;
#include "res://night.gdshaderinc"
// Native village ground (no captured pictures).
// Layer 1 (n41, NEN2.draw): bought land = the game's lawn (n2_co recoloured C.base), unbought land = wild grass (n2_codai,
// C.wild) as NEN2's zone 2: per-tile value (1 unbought, else the rough round a wild bush still standing), eased between tile
// centres + the game's own value noise (Me() lattice in uNZ), cut at .5, with the soft outside fade of NEN2 soft().
// Layer 2: tiles with their own ground (paddy, rubber, tram, cu lao, yard) from per-tile data: kind + the game's tile colour.
//   Paddy = TH.pad: tile colour, rice rows (TH rowPat), raised bunds every 3 tiles (bu: t%3==0, bv: a%3==1).
uniform sampler2D uNZ : filter_nearest;   // R: Me lattice for vn(x/8.5..), G: for vn(x/23..), B: per-tile wild value (run time)
uniform vec4 uNL = vec4(-1.0, 12.0, 31.0, 8.0);   // lattice origins: /8.5 i0 j0, /23 i0 j0
uniform vec2 uNL4 = vec2(6.0, 12.0);   // A: /8.5 lattice of the yard zone
uniform vec3 gY = vec3(1.0173, 1.0118, 1.0097);   // NEN2 C.yard recolour of n2_dat
uniform vec3 oY = vec3(0.0129, 0.0074, 0.0044);
uniform float tY = 153.6;      // 128 * 1.2
uniform vec3 gC = vec3(1.06);
uniform vec3 oC = vec3(0.2453, 0.3123, 0.1303);   // NEN2 lawn (C.base) recolour of n2_co, same +offset as the wild grass
uniform float tC = 179.2;      // world units per lawn texture repeat (128 * 1.4)
uniform sampler2D uTC : filter_nearest;   // tile colour (RGB) + A = kind*16 + flags (flag 1: rows run the other way, 2: unbought lot)
uniform vec3 gW = vec3(1.06);
uniform vec3 oW = vec3(0.1700, 0.2650, 0.0920);   // NEN2 wild recolour, +6/+3/+3 to match the game's unbought grass on screen
uniform float tS = 281.6;      // world units per grass texture repeat (128 * 2.2, as the game)
uniform vec4 uT;               // ki, hi, F0, vo
uniform vec2 uTN;              // tile texture size
// Layer 3: roads (DUONG). Per tile: R tier (2 earth band, 3 footpath, 4 laid road), G connections (bit k = D4[k]:
// +u, -u, +v, -v), B kind (dat do cat soi gach da). Surfaces are the game's own dg2_<kind> textures, recoloured like dtx().
uniform sampler2D uRD : filter_nearest;
// the 6 road surfaces (+ 6 wild grass, 7 lawn, 8 yard earth) in one texture array: phones allow few textures per shader (Adreno: 16 incl. Godot's own)
uniform sampler2DArray uRA : repeat_enable, filter_linear_mipmap;
uniform vec3 rG[6];
uniform vec3 rO[6];
uniform vec3 rRG[6];
uniform vec3 rRO[6];
uniform vec3 eSg; uniform vec3 eSo; uniform vec3 eBg; uniform vec3 eBo; uniform vec3 eEg; uniform vec3 eEo;
uniform float uRoads = 0.0;
uniform float uWet = 0.0;   // mưa: đất cỏ thấm nước, sẫm lại (lên dần khi mưa, khô dần khi tạnh)
// Layer 4: ponds, canal and ditches (AOW, the game's non-WebGL path). Fields at 4 samples a tile (n/pond.png: shore F,
// mud Fm, grass lip Fl, depth D), the game's colours, and its bank detail textures laid in "overlay" like BTX.
uniform sampler2D uPF : filter_linear, repeat_disable;
uniform vec4 uPB = vec4(0.0, 0.0, 1.0, 1.0);   // X0, Y0, NX, NY (samples)
uniform sampler2D uPT1 : repeat_enable, filter_linear_mipmap;   // co, vach, bun, dat
uniform sampler2D uPT2 : repeat_enable, filter_linear_mipmap;   // ria grey, ria alpha, rach alpha, loang alpha
uniform sampler2D uPT3 : repeat_enable, filter_linear_mipmap;   // glint streaks
uniform vec3 pMid; uniform vec3 pMudS; uniform vec3 pDpc; uniform vec3 pSky; uniform vec3 pBand;
uniform vec3 pLip; uniform vec3 pMud; uniform vec3 pFace; uniform vec3 pFaceW; uniform vec3 pFaceD;
uniform float uPond = 0.0;
varying vec2 wp;
void vertex() { wp = VERTEX; }

float hh(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vno(vec2 p) { vec2 i = floor(p), f = p - i; f = f * f * (3.0 - 2.0 * f);
	float a = hh(i), b = hh(i + vec2(1.0, 0.0)), c = hh(i + vec2(0.0, 1.0)), d = hh(i + vec2(1.0, 1.0));
	return a + (b - a) * f.x + (c - a) * f.y + (a - b - c + d) * f.x * f.y; }
// road texture of kind k: dat/do/cat/soi anchored to the world (112 / 96 units a repeat), gach/da on the tile grid (2 tiles)
vec3 rtex(int k, vec2 w, vec2 t) {
	if (k < 3) return texture(uRA, vec3(w / 112.0, float(k))).rgb;
	if (k == 3) return texture(uRA, vec3(w / 96.0, 3.0)).rgb;
	return texture(uRA, vec3(t / 2.0, float(k))).rgb;
}
// signed distance (tile units, < 0 inside) of a laid road of half width w: a bar from the centre to every connected edge,
// and a rounded square (|x|^4+|y|^4) at the centre unless the road runs straight through
float rsd(vec2 f, int m, float w) {
	float d = 1e3;
	vec2 q = f - 0.5;
	if ((m & 1) != 0) d = min(d, max(-q.x, abs(q.y) - w));
	if ((m & 2) != 0) d = min(d, max(q.x, abs(q.y) - w));
	if ((m & 4) != 0) d = min(d, max(-q.y, abs(q.x) - w));
	if ((m & 8) != 0) d = min(d, max(q.y, abs(q.x) - w));
	if (m != 3 && m != 12) d = min(d, pow(pow(abs(q.x), 4.0) + pow(abs(q.y), 4.0), 0.25) - w);
	return d;
}
// distance to the footpath centre lines (centre to each connected edge)
float fpd(vec2 f, int m) {
	vec2 q = f - 0.5;
	float d = length(q);
	if ((m & 1) != 0) d = min(d, length(vec2(q.x - clamp(q.x, 0.0, 0.5), q.y)));
	if ((m & 2) != 0) d = min(d, length(vec2(q.x - clamp(q.x, -0.5, 0.0), q.y)));
	if ((m & 4) != 0) d = min(d, length(vec2(q.x, q.y - clamp(q.y, 0.0, 0.5))));
	if ((m & 8) != 0) d = min(d, length(vec2(q.x, q.y - clamp(q.y, -0.5, 0.0))));
	return d;
}

// coverage of a line at perpendicular distance d (world units), width w, with pixel-size anti-aliasing
float line(float d, float w, float px) { return clamp((w * 0.5 - abs(d)) / px + 0.5, 0.0, 1.0); }

// ---- layer 4 helpers
vec2 s2g(vec2 w) { vec2 d = w - uT.xy; float a = d.x / 32.0, b = d.y / 16.0; return vec2((a + b) * 0.5, (b - a) * 0.5); }
vec4 PFg(vec2 g) {
	vec2 uv = (g - uPB.xy) * 4.0 / uPB.zw;
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) return vec4(-0.1, -0.1, -0.1, 0.0);
	return (texture(uPF, uv) * 255.0 - 20.0) / 200.0;
}
vec4 PF(vec2 w) { return PFg(s2g(w)); }
float sst(float a, float b, float x) { float t = clamp((x - a) / (b - a), 0.0, 1.0); return t * t * (3.0 - 2.0 * t); }
vec3 ovl(vec3 b, float s) { return mix(2.0 * b * s, 1.0 - 2.0 * (1.0 - b) * (1.0 - s), step(0.5, b)); }
float aa(float d, float px) { return clamp(d / px + 0.5, 0.0, 1.0); }
// (n16, Link "làm mới, bỏ code cũ"): the ground only lays the water's bed colour under the pond; the water is
// pondwater.gdshader, the banks are the river's bank drawing (pondriver.gd)
vec3 pond(vec3 c, vec2 w) {
	vec2 g = s2g(w);
	vec4 f = PFg(g);
	if (f.x < 0.3) return c;
	float px = max(fwidth(w.x), 1e-4);
	const float e = 1.5;
	float gx = (PF(w + vec2(e, 0.0)).x - PF(w - vec2(e, 0.0)).x) / (2.0 * e);
	float gy = (PF(w + vec2(0.0, e)).x - PF(w - vec2(0.0, e)).x) / (2.0 * e);
	float dF = (f.x - 0.5) / max(sqrt(gx * gx + gy * gy), 1e-4);
	return mix(c, pMid * 0.92, aa(dF, px));
}


// ---- layer 1: bought lawn / wild grass (NEN2 zone 2)
float nzL(ivec2 p, int ch) {
	ivec2 q = clamp(p, ivec2(0), ivec2(1023));
	vec4 t = texelFetch(uNZ, q, 0);
	return ch == 0 ? t.r : (ch == 1 ? t.g : t.a);
}
float vnL(vec2 X, int ch) {
	vec2 i0 = floor(X), f = X - i0;
	f = f * f * (3.0 - 2.0 * f);
	ivec2 o = ivec2(i0) - (ch == 0 ? ivec2(int(uNL.x), int(uNL.y)) : (ch == 1 ? ivec2(int(uNL.z), int(uNL.w)) : ivec2(int(uNL4.x), int(uNL4.y))));
	float a = nzL(o, ch), b = nzL(o + ivec2(1, 0), ch), c = nzL(o + ivec2(0, 1), ch), d = nzL(o + ivec2(1, 1), ch);
	return a + (b - a) * f.x + (c - a) * f.y + (a - b - c + d) * f.x * f.y;
}
// B: wild value * 100, + 128 on a yard tile
float tB(ivec2 t) {
	ivec2 q = t - ivec2(uT.zw);
	if (q.x < 0 || q.y < 0 || q.x >= int(uTN.x) || q.y >= int(uTN.y)) return 100.0;
	return floor(texelFetch(uNZ, q, 0).b * 255.0 + 0.5);
}
float twild(ivec2 t) { float b = tB(t); return min(1.0, mod(b, 128.0) / 100.0); }
float tyard(ivec2 t) { return tB(t) >= 128.0 ? 1.0 : 0.0; }
float yardv(vec2 w) {
	vec2 d = w - uT.xy;
	float u = (d.y / 16.0 + d.x / 32.0) / 2.0 - 0.5, v = (d.y / 16.0 - d.x / 32.0) / 2.0 - 0.5;
	vec2 i0 = floor(vec2(u, v)), f = vec2(u, v) - i0;
	f = f * f * (3.0 - 2.0 * f);
	ivec2 t = ivec2(i0);
	float a = tyard(t), b = tyard(t + ivec2(1, 0)), c = tyard(t + ivec2(0, 1)), e = tyard(t + ivec2(1, 1));
	if (a + b + c + e == 0.0) return 0.0;
	float base = a + (b - a) * f.x + (c - a) * f.y + (a - b - c + e) * f.x * f.y;
	float n = vnL(vec2(w.x / 23.0 + 69.2, w.y / 23.0 + 20.4), 1) * 0.9 + vnL(vec2(w.x / 8.5 + 13.2, w.y / 8.5 + 30.8), 2) * 0.1 - 0.5;
	return base + n * 0.36;
}
// NEN2 soft(): the zone filled, plus strokes 18/12/7/3 wide at alpha .14/.18/.22/.28 outside its edge
float softz(float val, float pw) {
	float gl = max(length(vec2(dFdx(val), dFdy(val))) / max(pw, 1e-5), 1e-4);
	float dz = (0.5 - val) / gl;
	float ko = 1.0;
	ko *= 1.0 - 0.14 * clamp((9.0 - dz) / pw + 0.5, 0.0, 1.0);
	ko *= 1.0 - 0.18 * clamp((6.0 - dz) / pw + 0.5, 0.0, 1.0);
	ko *= 1.0 - 0.22 * clamp((3.5 - dz) / pw + 0.5, 0.0, 1.0);
	ko *= 1.0 - 0.28 * clamp((1.5 - dz) / pw + 0.5, 0.0, 1.0);
	return max(clamp(0.5 - dz / pw, 0.0, 1.0), 1.0 - ko);
}
float wildv(vec2 w) {
	vec2 d = w - uT.xy;
	float u = (d.y / 16.0 + d.x / 32.0) / 2.0 - 0.5, v = (d.y / 16.0 - d.x / 32.0) / 2.0 - 0.5;
	vec2 i0 = floor(vec2(u, v)), f = vec2(u, v) - i0;
	f = f * f * (3.0 - 2.0 * f);
	ivec2 t = ivec2(i0);
	float a = twild(t), b = twild(t + ivec2(1, 0)), c = twild(t + ivec2(0, 1)), e = twild(t + ivec2(1, 1));
	if (a + b + c + e == 0.0) return 0.0;
	float base = a + (b - a) * f.x + (c - a) * f.y + (a - b - c + e) * f.x * f.y;
	float n = vnL(vec2(w.x / 23.0 + 34.6, w.y / 23.0 + 10.2), 1) * 0.7 + vnL(vec2(w.x / 8.5 + 6.6, w.y / 8.5 + 15.4), 0) * 0.3 - 0.5;
	return base + n * 0.84;
}
void fragment() {
	if (wp.y < 350.0) { discard; }   // (b60) web TH.hz: above xf + HZL (360 - 10) the ground is cleared, the sky shows
	vec3 cw = texture(uRA, vec3(wp / tS, 6.0)).rgb * gW + oW;
	vec3 cl = texture(uRA, vec3(wp / tC, 7.0)).rgb * gC + oC;
	float pw = length(vec2(dFdx(wp.x), dFdy(wp.x)));               // world units per screen pixel
	vec3 c = mix(cl, cw, softz(wildv(wp), pw));
	// zone 4: swept earth yard round houses, pavilions, shrines (NEN2 YD), the game's n2_dat recoloured C.yard
	float yv = yardv(wp);
	c = mix(c, texture(uRA, vec3(wp / tY, 8.0)).rgb * gY + oY, softz(yv, pw));
	vec2 d = wp - uT.xy;
	float u = (d.y / 16.0 + d.x / 32.0) / 2.0;
	float v = (d.y / 16.0 - d.x / 32.0) / 2.0;
	vec2 tf = vec2(floor(u), floor(v));
	ivec2 ti = ivec2(tf - uT.zw);
	if (ti.x >= 0 && ti.y >= 0 && ti.x < int(uTN.x) && ti.y < int(uTN.y)) {
		int kf = int(texelFetch(uTC, ti, 0).a * 255.0 + 0.5);
		int kind = kf / 16;
		if (kind > 0) {
			vec3 tc = texelFetch(uTC, ti, 0).rgb;
			c = tc;
			if (kind == 1) {
				float px = max(fwidth(wp.x), 1e-4);
				// rice rows: pattern in world space, lines of slope +-1/2 every 4 units (TH rowPat)
				bool al = (kf & 1) == 1;
				float sl = al ? -0.5 : 0.5;
				float base = wp.y + sl * wp.x;
				float e1 = (fract((base - 0.4) / 4.0 + 0.5) - 0.5) * 4.0 * 0.894;
				// dashed 1.6 on / 1.38 off with round caps (canvas lineCap round): a dash is a capsule of radius .55
				float sa = mod((wp.x + 2.0) * 1.118, 2.98);
				float da = max(0.0, max(-sa, sa - 1.6));
				da = min(da, 2.98 - sa);
				float r1 = sqrt(da * da + e1 * e1);
				c = mix(c, vec3(30.0, 40.0, 10.0) / 255.0, 0.2 * clamp((0.55 - r1) / px + 0.5, 0.0, 1.0));
				float e2 = (fract((base + 0.6) / 4.0 + 0.5) - 0.5) * 4.0 * 0.894;
				c = mix(c, vec3(255.0, 255.0, 230.0) / 255.0, 0.15 * line(e2, 0.7, px));
				// bunds (bờ ruộng)
				float fu = u - tf.x, fv = v - tf.y;
				bool bu = int(mod(tf.x, 3.0)) == 0;
				bool bv = int(mod(tf.y, 3.0)) == 1;
				const float W = 0.085;
				const float K = 28.62;   // world units per tile unit across an edge
				vec3 top = vec3(143.0, 162.0, 78.0) / 255.0;
				if (bu) {
					float a = clamp((W - fu) * K / px + 0.5, 0.0, 1.0);
					c = mix(c, top, a);
					c = mix(c, vec3(40.0, 50.0, 20.0) / 255.0, 0.28 * line((fu - W) * K - 0.27, 1.1, px));
					c = mix(c, vec3(255.0, 250.0, 210.0) / 255.0, 0.3 * line(fu * K - 0.1, 0.8, px));
				}
				if (bv) {
					float a = clamp((W - fv) * K / px + 0.5, 0.0, 1.0);
					c = mix(c, top, a);
					c = mix(c, vec3(40.0, 50.0, 20.0) / 255.0, 0.28 * line((fv - W) * K - 0.36, 1.1, px));
					c = mix(c, vec3(255.0, 250.0, 210.0) / 255.0, 0.3 * line(fv * K - 0.45, 0.8, px));
				}
			}
		}
	}
	if (uPond > 0.5) c = pond(c, wp);
	if (uRoads > 0.5 && ti.x >= 0 && ti.y >= 0 && ti.x < int(uTN.x) && ti.y < int(uTN.y)) {
		vec4 rd = texelFetch(uRD, ti, 0);
		int tier = int(rd.r * 255.0 + 0.5);
		if (tier > 0) {
			int m = int(rd.g * 255.0 + 0.5);
			int k = int(rd.b * 255.0 + 0.5);
			vec2 f = vec2(u, v) - tf;
			float px = max(fwidth(u), 1e-5) * 0.7;   // one screen pixel in tile units (across an edge)
			vec3 dat = texture(uRA, vec3(wp / 112.0, 0.0)).rgb;
			if (tier == 4) {
				int rk = (k == 4 || k == 5) ? 0 : k;
				vec3 rim = rtex(rk, wp, vec2(u, v)) * rRG[k] + rRO[k];
				vec3 sur = rtex(k, wp, vec2(u, v)) * rG[k] + rO[k];
				c = mix(c, rim, clamp(-rsd(f, m, 0.5) / px + 0.5, 0.0, 1.0));
				c = mix(c, sur, clamp(-rsd(f, m, 0.455) / px + 0.5, 0.0, 1.0));
			} else if (tier == 3) {
				float dd = fpd(f, m);
				c = mix(c, dat * eEg + eEo, clamp((0.13 - dd) / px + 0.5, 0.0, 1.0));
				c = mix(c, dat * eBg + eBo, clamp((0.11 - dd) / px + 0.5, 0.0, 1.0));
			} else if (tier == 2) {
				// earth band: ragged edges (ew noise), darker rim, lighter top inset on one side
				float n1 = vno(vec2(u, v) * 0.62 * 1.0 + 40.1) - 0.5, n2 = vno(vec2(u, v) * 1.9 + 3.7) - 0.5;
				float wa = 0.5 + 0.11 * n1 + 0.06 * n2;
				float dd = rsd(f, m, wa);
				c = mix(c, dat * eSg + eSo, clamp(-dd / px + 0.5, 0.0, 1.0));
				float ins = 0.045 + 0.05 * vno(vec2(u, v) * 1.3 + vec2(3.3, -8.1));
				c = mix(c, dat * eBg + eBo, clamp(-rsd(f, m, wa - ins) / px + 0.5, 0.0, 1.0));
			}
		}
	}
	if (uWet > 0.0) {
		c = clamp(c, 0.0, 1.0);
		vec3 wc = pow(c, vec3(1.35)) * 0.9;   // ướt: sẫm hơn, màu đậm hơn
		c = mix(c, wc, uWet);
	}
	COLOR = vec4(night_col(clamp(c, 0.0, 1.0)), 1.0);
}
