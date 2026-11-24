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
uniform vec4 uYE = vec4(0.0);
uniform vec4 uLP0 = vec4(0.0);   // nong phơi lúa trên sân: u0 v0 u1 v1 (toạ độ ô)
uniform vec4 uLP1 = vec4(0.0);   // sân phơi hình bầu dục: tâm x,y, bán kính x,y (thế giới); rx=0 tắt
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
	{ float gn = vno(wp / 26.0 + 11.0) * 0.7 + vno(wp / 7.0 + 3.0) * 0.3;
	  c = mix(c, c * vec3(0.78, 0.80, 0.70), smoothstep(0.35, 0.75, gn) * 0.7);
	  c = mix(c, c * vec3(1.10, 1.02, 0.78), 0.45 * smoothstep(0.62, 0.85, vno(wp / 18.0 + 40.0)));
	  float l = dot(c, vec3(0.3, 0.59, 0.11)); c = mix(vec3(l), c, 0.82); }
	float yn = (vno(wp / 23.0 + 69.2) * 0.9 + vno(wp / 8.5 + 13.2) * 0.1 - 0.5);
	float yv = zone(uv, 2) + yn * 0.6;
	if (uYE.z > 0.0) { vec2 q = (wp - uYE.xy) / uYE.zw; yv = 1.5 - length(q) + yn * 0.28; }
	c = mix(c, texture(uRA, vec3(wp / tY, 3.0)).rgb * gY + oY, softz(yv, pw));
	// lúa phơi trên sân: hạt vàng, vệt cào song song, mép mềm
	for (int i = 0; i < 2; i++) {
		vec4 r = i == 0 ? uLP0 : uLP1;
		if (r.z <= r.x) continue;
		vec2 dq = max(r.xy - uv, uv - r.zw);
		float dd = max(dq.x, dq.y) + (vno(wp / 4.0 + float(i) * 9.0) - 0.5) * 0.16 + (vno(wp / 1.3) - 0.5) * 0.05;
		float a = clamp(-dd * 28.0 / max(pw, 1e-4) + 0.5, 0.0, 1.0);
		// hạt lúa rơi vãi ngoài mép
		float sp = step(0.86, hh(floor(wp / 0.6) + float(i))) * smoothstep(0.25, 0.0, dd) * step(0.0, dd);
		vec3 gc0 = vec3(214.0, 176.0, 78.0) / 255.0;
		c = mix(c, gc0 * 1.05, sp * 0.8);
		if (a <= 0.0) continue;
		float g = hh(floor(wp / 0.55));
		vec3 gc = gc0 * (0.86 + 0.22 * g) * (0.92 + 0.14 * vno(wp / 6.0 + 2.0));
		// luống cào: gợn sóng sáng/tối theo u
		float rk = sin((uv.x - r.x) * 6.2832 * 4.0 + (vno(wp / 5.0) - 0.5) * 2.0);
		gc *= 1.0 + 0.09 * rk;
		// ụ lúa: giữa sáng, mép tối (dày ở giữa)
		float hgt = clamp(-dd * 3.0, 0.0, 1.0);
		gc *= 0.80 + 0.22 * hgt;
		// trấu/rơm vụn
		gc = mix(gc, vec3(170.0, 140.0, 80.0) / 255.0, 0.5 * step(0.93, hh(floor(wp / 0.9) + 5.0)));
		c = mix(c, gc, a);
	}
	vec2 tf = floor(uv);
	ivec2 ti = ivec2(tf - uT0);
	bool inside = ti.x >= 0 && ti.y >= 0 && ti.x < int(uTN.x) && ti.y < int(uTN.y);
	if (inside) {
		vec4 kk = texelFetch(uK, ti, 0);
		int kind = int(kk.a * 255.0 + 0.5) / 16;
		if (kind == 4) {
			// ruộng mới gặt: nền đất rạ loang, gốc rạ thành bụi (3 cọng + bóng), rơm rớt, bờ đất đắp thưa (6 ô), mép mềm
			float px = max(fwidth(wp.x), 1e-4);
			float tn = vno(wp / 40.0 + 5.3);
			c = mix(kk.rgb, vec3(150.0, 128.0, 80.0) / 255.0, 0.35 * smoothstep(0.45, 0.8, tn));
			c *= (0.92 + 0.12 * vno(wp / 90.0 + 2.1)) * (0.95 + 0.08 * vno(wp / 5.0));
			float base = wp.y + 0.5 * wp.x;
			const float RP = 5.0;
			const float CP = 3.6;
			float ri = floor(base / RP + 0.5);
			float e1 = (base / RP - ri) * RP * 0.894;
			float sx = wp.x * 1.118 + hh(vec2(ri, 3.0)) * CP;
			float ci = floor(sx / CP);
			float dxa = sx - ci * CP - CP * 0.5 + (hh(vec2(ci, ri)) - 0.5) * 1.0;
			if (hh(vec2(ci, ri + 17.0)) > 0.15) {
				float sh = length(vec2(dxa * 0.75, (e1 - 0.3) * 1.6));
				c = mix(c, vec3(92.0, 74.0, 40.0) / 255.0, 0.42 * clamp((1.35 - sh) / px + 0.5, 0.0, 1.0));
				float hgt = 1.6 + 1.0 * hh(vec2(ri, ci));
				for (int k = -1; k <= 1; k++) {
					float fk = float(k);
					float lean = fk * 0.35;
					float t = clamp(-e1 / hgt, 0.0, 1.0);
					float xd = dxa - fk * 0.55 - lean * t * hgt;
					float hk = hgt * (1.0 - 0.25 * abs(fk));
					float st = max(abs(xd) - 0.26, max(e1 - 0.1, -e1 - hk));
					vec3 sc = mix(vec3(176.0, 146.0, 78.0), vec3(242.0, 222.0, 150.0), t) / 255.0;
					sc *= k == 1 ? 0.86 : 1.0;
					c = mix(c, sc, clamp(-st / px + 0.5, 0.0, 1.0));
				}
			}
			vec2 cc = floor(wp / 13.0);
			if (hh(cc + 7.7) < 0.5) {
				float an = hh(cc + 1.3) * 6.2832;
				vec2 dir = vec2(cos(an), sin(an) * 0.5);
				vec2 p0 = (cc + vec2(hh(cc + 2.1), hh(cc + 4.4))) * 13.0;
				vec2 q = wp - p0; float tq = clamp(dot(q, dir) / dot(dir, dir), -5.0, 5.0);
				float dl = length(q - dir * tq);
				c = mix(c, vec3(120.0, 96.0, 52.0) / 255.0, 0.3 * clamp((0.7 - length(q - dir * tq - vec2(0.0, 0.5))) / px + 0.5, 0.0, 1.0));
				c = mix(c, vec3(236.0, 210.0, 128.0) / 255.0, 0.9 * clamp((0.4 - dl) / px + 0.5, 0.0, 1.0));
			}
			// bờ đất đắp: thưa (6 ô), mép uốn theo nhiễu, mặt đất pha cỏ, bóng mềm phía dưới
			float wob = (vno(wp / 9.0 + 1.7) - 0.5) * 0.10;
			float fu = u - tf.x + wob, fv = v - tf.y - wob;
			bool bu = int(mod(tf.x, 6.0)) == 0;
			bool bv = int(mod(tf.y, 6.0)) == 2;
			const float W = 0.17;
			float gt = smoothstep(0.45, 0.7, vno(wp / 3.0 + 3.1));
			vec3 top = mix(vec3(152.0, 126.0, 80.0), vec3(118.0, 136.0, 66.0), gt * 0.75) / 255.0;
			top *= 0.9 + 0.14 * vno(wp / 1.6);
			if (bu) {
				float a = smoothstep(W + 0.02, W - 0.02, fu);
				c = mix(c, c * 0.78, 0.6 * smoothstep(W + 0.12, W, fu) * (1.0 - a));
				c = mix(c, top, a);
			}
			if (bv) {
				float a = smoothstep(W + 0.02, W - 0.02, fv);
				c = mix(c, c * 0.78, 0.6 * smoothstep(W + 0.12, W, fv) * (1.0 - a));
				c = mix(c, top, a);
			}
		}
		if (kind == 1) {
			c = kk.rgb * (0.95 + 0.10 * vno(wp / 70.0 + 5.3));   // tông loang nhẹ, không theo ô
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
