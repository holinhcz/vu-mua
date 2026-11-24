shader_type canvas_item;
// Boss map ground: same layers + numbers as the village ground.gdshader (lawn n2_co, wild n2_codai, yard n2_dat,
// paddy TH.pad rows + bunds, laid road dg2_dat), driven by a small per-tile map instead of the village data.
uniform sampler2D uK : filter_nearest;   // RGB tile colour (paddy), A kind*16: 0 lawn, 1 paddy, 2 yard, 3 wild
uniform sampler2D uRD : filter_nearest;  // R tier, G conn mask, B road kind
uniform sampler2DArray uRA : repeat_enable, filter_linear_mipmap;   // 0 dg2_dat, 1 codai, 2 co, 3 n2_dat, 4 dg2_gach
uniform vec2 uT0;   // first tile index
uniform vec2 uTN;   // tiles
uniform vec3 gY = vec3(1.0173, 1.0118, 1.0097);
uniform vec3 oY = vec3(0.0129, 0.0074, 0.0044);
uniform float tY = 153.6;
uniform vec3 gC = vec3(1.06);
uniform vec3 oC = vec3(0.2453, 0.3123, 0.1303);
uniform float tC = 179.2;
uniform vec3 gW = vec3(1.06);
uniform vec3 oW = vec3(0.1700, 0.2650, 0.0920);
uniform float tS = 281.6;
uniform vec3 rG0 = vec3(0.9783, 0.972, 0.9531);
uniform vec3 rO0 = vec3(-0.0146, -0.016, -0.0197);
uniform vec3 rRG0 = vec3(0.9151, 0.901, 0.87);
uniform vec3 rRO0 = vec3(-0.0535, -0.0526, -0.0498);
uniform vec3 rG4 = vec3(1.0221, 0.9761, 0.9666);
uniform vec3 rO4 = vec3(0.0148, -0.009, -0.0085);
varying vec2 wp;
void vertex() { wp = VERTEX; }

float hh(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vno(vec2 p) { vec2 i = floor(p), f = p - i; f = f * f * (3.0 - 2.0 * f);
	float a = hh(i), b = hh(i + vec2(1.0, 0.0)), c = hh(i + vec2(0.0, 1.0)), d = hh(i + vec2(1.0, 1.0));
	return a + (b - a) * f.x + (c - a) * f.y + (a - b - c + d) * f.x * f.y; }
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
float line(float d, float w, float px) { return clamp((w * 0.5 - abs(d)) / px + 0.5, 0.0, 1.0); }
int kindAt(ivec2 t) {
	ivec2 q = t - ivec2(uT0);
	if (q.x < 0 || q.y < 0 || q.x >= int(uTN.x) || q.y >= int(uTN.y)) return 3;
	return int(texelFetch(uK, q, 0).a * 255.0 + 0.5) / 16;
}
float isk(ivec2 t, int k) { return kindAt(t) == k ? 1.0 : 0.0; }
float zone(vec2 uv, int k) {
	vec2 i0 = floor(uv - 0.5), f = uv - 0.5 - i0;
	f = f * f * (3.0 - 2.0 * f);
	ivec2 t = ivec2(i0);
	float a = isk(t, k), b = isk(t + ivec2(1, 0), k), c = isk(t + ivec2(0, 1), k), e = isk(t + ivec2(1, 1), k);
	return a + (b - a) * f.x + (c - a) * f.y + (a - b - c + e) * f.x * f.y;
}
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
void fragment() {
	vec3 cw = texture(uRA, vec3(wp / tS, 1.0)).rgb * gW + oW;
	vec3 cl = texture(uRA, vec3(wp / tC, 2.0)).rgb * gC + oC;
	float pw = length(vec2(dFdx(wp.x), dFdy(wp.x)));
	float u = (wp.y / 16.0 + wp.x / 32.0) / 2.0;
	float v = (wp.y / 16.0 - wp.x / 32.0) / 2.0;
	vec2 uv = vec2(u, v);
	float wv = zone(uv, 3) + (vno(wp / 23.0 + 34.6) * 0.7 + vno(wp / 8.5 + 6.6) * 0.3 - 0.5) * 0.84;
	vec3 c = mix(cl, cw, softz(wv, pw));
	float yv = zone(uv, 2) + (vno(wp / 23.0 + 69.2) * 0.9 + vno(wp / 8.5 + 13.2) * 0.1 - 0.5) * 0.6;
	c = mix(c, texture(uRA, vec3(wp / tY, 3.0)).rgb * gY + oY, softz(yv, pw));
	vec2 tf = floor(uv);
	ivec2 ti = ivec2(tf - uT0);
	bool inside = ti.x >= 0 && ti.y >= 0 && ti.x < int(uTN.x) && ti.y < int(uTN.y);
	if (inside) {
		vec4 kk = texelFetch(uK, ti, 0);
		int kind = int(kk.a * 255.0 + 0.5) / 16;
		if (kind == 1) {
			c = kk.rgb;
			float px = max(fwidth(wp.x), 1e-4);
			float base = wp.y + 0.5 * wp.x;
			float e1 = (fract((base - 0.4) / 4.0 + 0.5) - 0.5) * 4.0 * 0.894;
			float sa = mod((wp.x + 2.0) * 1.118, 2.98);
			float da = max(0.0, max(-sa, sa - 1.6));
			da = min(da, 2.98 - sa);
			float r1 = sqrt(da * da + e1 * e1);
			c = mix(c, vec3(30.0, 40.0, 10.0) / 255.0, 0.2 * clamp((0.55 - r1) / px + 0.5, 0.0, 1.0));
			float e2 = (fract((base + 0.6) / 4.0 + 0.5) - 0.5) * 4.0 * 0.894;
			c = mix(c, vec3(255.0, 255.0, 230.0) / 255.0, 0.15 * line(e2, 0.7, px));
			float fu = u - tf.x, fv = v - tf.y;
			bool bu = int(mod(tf.x, 3.0)) == 0;
			bool bv = int(mod(tf.y, 3.0)) == 1;
			const float W = 0.085;
			const float K = 28.62;
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
		vec4 rd = texelFetch(uRD, ti, 0);
		int tier = int(rd.r * 255.0 + 0.5);
		if (tier == 4) {
			int m = int(rd.g * 255.0 + 0.5);
			vec2 f = uv - tf;
			float px = max(fwidth(u), 1e-5) * 0.7;
			int rk = int(rd.b * 255.0 + 0.5);
			vec3 tex = texture(uRA, vec3(wp / 112.0, 0.0)).rgb;
			vec3 sur = rk == 4 ? texture(uRA, vec3(uv / 2.0, 4.0)).rgb * rG4 + rO4 : tex * rG0 + rO0;
			c = mix(c, tex * rRG0 + rRO0, clamp(-rsd(f, m, 0.5) / px + 0.5, 0.0, 1.0));
			c = mix(c, sur, clamp(-rsd(f, m, 0.455) / px + 0.5, 0.0, 1.0));
		}
	}
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
