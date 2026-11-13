shader_type canvas_item;
#include "res://night.gdshaderinc"
#include "res://rain.gdshaderinc"
// Ponds, the canal and the brook get the RIVER's water (water.gdshader v5, Link 2026-11-12 "hiệu ứng nước như sông
// đâu"): the same layered wave field from the noise map, gusts, sky in the wave faces, sun glitter, the light web in the
// shallows and the white flecks riding the current. Body colour = the game's pond shade map (as ground.gdshader pond()),
// so the water keeps the ponds' own colour. Drawn over the ground (z -38): fades in from the shore so the ground's
// rim, mud film and the far bank's earth face stay; under the tree reflections, hanging grass and the mats.
// The brook flows down its centre line (FLW), ponds and the canal only drift. 4 samplers.
uniform sampler2D uPF : filter_linear, repeat_disable;
uniform vec4 uPB; uniform vec2 uKH;
uniform sampler2D uN : filter_linear_mipmap, repeat_enable;
uniform sampler2D uTC : filter_nearest, repeat_disable;
uniform vec2 uT0;
uniform vec3 pMid; uniform vec3 pMudS; uniform vec3 pDpc; uniform vec3 pSky; uniform vec3 pBand;
uniform vec4 uK = vec4(520., .22, 120., .75);
uniform vec3 uG = vec3(190., 1.1, .12);
uniform vec3 uV = vec3(360., 14., .2);
uniform vec3 uGain = vec3(0.88, 0.914, 0.916);
varying vec2 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy; }
vec2 s2g(vec2 w) { vec2 d = w - uKH; float a = d.x / 32.0, b = d.y / 16.0; return vec2((a + b) * 0.5, (b - a) * 0.5); }
vec4 PFg(vec2 g) {
	vec2 uv = (g - uPB.xy) * 4.0 / uPB.zw;
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) return vec4(-0.1, -0.1, -0.1, 0.0);
	return (texture(uPF, uv) * 255.0 - 20.0) / 200.0;
}
vec4 PF(vec2 w) { return PFg(s2g(w)); }
float sst(float a, float b, float x) { float t = clamp((x - a) / (b - a), 0.0, 1.0); return t * t * (3.0 - 2.0 * t); }
float hh(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vno(vec2 p) { vec2 i = floor(p), f = p - i; f = f * f * (3.0 - 2.0 * f);
	float a = hh(i), b = hh(i + vec2(1.0, 0.0)), c = hh(i + vec2(0.0, 1.0)), d = hh(i + vec2(1.0, 1.0));
	return a + (b - a) * f.x + (c - a) * f.y + (a - b - c + d) * f.x * f.y; }
const vec2 FLW[15] = vec2[](vec2(-7.6, -18.4), vec2(-7.1, -17.2), vec2(-6.5, -15.6), vec2(-5.6, -14.5), vec2(-5.5, -13.5),
	vec2(-5.6, -12.5), vec2(-6.5, -11.5), vec2(-7.5, -10.5), vec2(-7.5, -9.5), vec2(-7.5, -8.5), vec2(-7.6, -7.5),
	vec2(-8.5, -6.5), vec2(-9.5, -5.5), vec2(-9.5, -4.5), vec2(-9.6, -3.4));
vec3 brookAt(vec2 g) {
	float best = 1e9; vec2 dsum = vec2(0.0); float wsum = 0.0;
	for (int k = 0; k < 14; k++) {
		vec2 a = FLW[k], b = FLW[k + 1], ab = b - a;
		float t = clamp(dot(g - a, ab) / dot(ab, ab), 0.0, 1.0);
		float d = length(g - a - ab * t);
		best = min(best, d);
		vec2 sd = vec2((ab.x - ab.y) * 32.0, (ab.x + ab.y) * 16.0);
		float wt = exp(-d * d * 2.0);
		dsum += normalize(sd) * wt; wsum += wt;
	}
	vec2 fd = wsum > 1e-4 ? normalize(dsum) : vec2(0.0, 1.0);
	return vec3(1.0 - smoothstep(1.3, 2.0, best), fd);
}
vec2 nrm(vec2 q) { return texture(uN, q).xy * 2. - 1.; }
float hgt(vec2 q) { return texture(uN, q).z; }
vec3 lay(vec2 x, float th, float lam, float asp, float spd, float t, vec2 off) {
	float c = cos(th), s = sin(th);
	vec2 du = vec2(c, s) / lam, dv = vec2(-s, c) / (lam * asp);
	vec2 xx = x - vec2(c, s) * spd * t;
	vec2 uv = vec2(dot(xx, du), dot(xx, dv)) + off;
	vec3 tx = texture(uN, uv).xyz;
	float k = 2. * tx.z - 1., a = sqrt(k * k + .006);
	vec2 g = (k / a) * 2. * (tx.xy * 2. - 1.);
	return vec3(1. - a, g.x * du + g.y * dv);
}
vec3 HG(vec2 x, float t) {
	vec3 r = lay(x, .66, 520., 2.6, 55., t, vec2(0.)) + .7 * lay(x, 1.08, 300., 2.2, 42., t, vec2(.37, .11))
		+ .45 * lay(x, .21, 170., 2., 34., t, vec2(.71, .53)) + .25 * lay(x, -.52, 95., 1.6, 25., t, vec2(.13, .83));
	return r / 2.4;
}
void fragment() {
	vec2 g = s2g(wpos);
	vec4 f = PFg(g);
	if (f.x < 0.47) discard;
	const float e = 1.5;
	float gx = (PF(wpos + vec2(e, 0.0)).x - PF(wpos - vec2(e, 0.0)).x) / (2.0 * e);
	float gy = (PF(wpos + vec2(0.0, e)).x - PF(wpos - vec2(0.0, e)).x) / (2.0 * e);
	float gl = max(sqrt(gx * gx + gy * gy), 1e-4);
	float dF = (f.x - 0.5) / gl;                  // world px from the shore
	vec2 nn = vec2(gx, gy) / gl;
	float far = clamp((nn.y - 0.25) * 1.6, 0.0, 1.0), nb = 1.0 - smoothstep(0.3, 0.4, far);
	// (n16) the water starts right at the shore, crisp; the banks (pondriver.gd) lie over its edge
	float px = max(fwidth(dF), 1e-3);
	float cov = clamp(dF / px + 0.5, 0.0, 1.0);
	if (cov <= 0.0) discard;
	// the game's pond shade map: darker under the far bank, the muddy bottom by the near one, sky in the middle
	float sky = sst(0.45, 0.95, f.w);
	float fr = sst(0.62, 0.3, PFg(g - 0.2).x) * 0.55 + sst(0.62, 0.3, PFg(g - 0.42).x) * 0.45;
	float rn = vno(vec2(g.x * 0.8 + 3.3, g.y * 1.6 + 1.1)) * 0.6 + vno(vec2(g.x * 2.1 + 7.0, g.y * 0.9 + 2.0)) * 0.4;
	vec3 body = pMid + (pDpc - pMid) * 0.32 * (1.0 - sky);
	body += (pSky - body) * 0.42 * sky;
	// (n16, Link "vẫn mờ": no pale muddy shallows along the near bank - that was the haze)
	body += (pBand - body) * 0.62 * fr;
	body *= 1.0 + 0.07 * (rn - 0.5);
	// the river's wave field: the brook runs down its line, still water only drifts
	vec3 bk = brookAt(g);
	// (n16, Link "mấy vòng tròn gì đây"): one clock everywhere - a speed that changes from place to place shears the
	// waves into rings round the brook's mouth that grow denser with time. The brook runs by its flow offset only.
	float uT = TIME * 0.55;
	vec2 p = wpos * 4.2;
	float d = dF * 3.0;
	vec2 dir = normalize(mix(vec2(0.62, 0.78), bk.yz, bk.x));
	vec2 q = vec2(p.x, p.y * 2.), dq = normalize(vec2(dir.x, dir.y * 2.));
	float fo = nb;
	float deep = mix(smoothstep(0., 150., d), 0.85, 0.35);
	float calm = 1.0;   // (n16, Link "vẫn mờ": flatter waves by the shore mirrored more pale sky = a pale band; same waves right up to the bank)
	float ph = uT * .3, f0 = fract(ph), f1 = fract(ph + .5), w0 = 1. - abs(2. * f0 - 1.);
	float L = uV.x * mix(0.12, 1.0, bk.x) * mix(.35, 1., deep);
	vec2 a0 = q - dq * f0 * L, a1 = q - dq * f1 * L + vec2(91., 37.);
	mat2 R1 = mat2(vec2(.80, .60), vec2(-.60, .80)), R2 = mat2(vec2(.34, -.94), vec2(.94, .34));
	vec2 wq = (nrm(a0 / 430.) * w0 + nrm(a1 / 430.) * (1. - w0)) * uV.y + nrm(R2 * q / 173.) * uV.y * .35;
	vec2 dr = vec2(.707, .707) * uT;
	float gust = mix(.6, 1.0, hgt(R1 * (q - dr * 40.) / 1100.)) * calm;
	vec2 x = q + wq; vec3 hg = HG(x, uT); float h0 = hg.x;
	vec3 N = normalize(vec3(hg.yz * uK.x * gust, 1.));
	body *= 1. + (h0 - .6) * uK.y * gust;
	vec3 V = normalize(vec3(0., .55, .83)), Rr = reflect(-V, N);
	vec3 env = mix(vec3(.13, .32, .22), vec3(.78, .93, .89), smoothstep(.55, .95, Rr.z));
	vec3 w = mix(body, env, uV.z);
	float sh = (1. - smoothstep(8., 130., d)) * smoothstep(1., 10., d) * (.35 + .65 * fo);
	float cw = lay(x * 1.7, 1.9, 260., 1., 30., uT, vec2(.4, .2)).x * lay(x * 1.7, .3, 330., 1., 24., uT, vec2(.9, .6)).x;
	w += vec3(.95, 1., .9) * smoothstep(.62, .9, cw) * .06 * sh;
	vec3 Ld = normalize(vec3(-.45, -.55, .70)); float sd = max(dot(Rr, Ld), 0.);
	float tw = .5 + hgt(R2 * q / 11. + uT * vec2(.9, .6));
	w += vec3(1., .98, .9) * (pow(sd, uG.x) * uG.y * tw + pow(sd, 24.) * .10) * mix(.5, 1., deep);
	float fk = smoothstep(.70, .80, hgt(a0 / 41.)) * smoothstep(.56, .74, hgt(R1 * a0 / 290. + .5)) * w0
		+ smoothstep(.70, .80, hgt(a1 / 41.)) * smoothstep(.56, .74, hgt(R1 * a1 / 290. + .5)) * (1. - w0);
	w = mix(w, vec3(.90, .94, .90), fk * mix(uG.z, uG.z * 1.4, bk.x) * deep);
	w *= uGain;
	// water on a lot not bought yet: the game's dull wash (as the ground does)
	vec2 lq = g - 0.5 - uT0, l0 = floor(lq), lf = lq - l0;
	float k00 = float((int(texelFetch(uTC, ivec2(l0), 0).a * 255.0 + 0.5) & 2) != 0);
	float k10 = float((int(texelFetch(uTC, ivec2(l0) + ivec2(1, 0), 0).a * 255.0 + 0.5) & 2) != 0);
	float k01 = float((int(texelFetch(uTC, ivec2(l0) + ivec2(0, 1), 0).a * 255.0 + 0.5) & 2) != 0);
	float k11 = float((int(texelFetch(uTC, ivec2(l0) + ivec2(1, 1), 0).a * 255.0 + 0.5) & 2) != 0);
	float lk = mix(mix(k00, k10, lf.x), mix(k01, k11, lf.x), lf.y);
	// (unbought-lot wash off, Link 2026-11-12)
	w = mix(w, vec3(1.), rain_rings(wpos) * .55);
	COLOR = vec4(night_col(w), cov);
}
