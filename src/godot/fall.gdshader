shader_type canvas_item;
render_mode blend_premul_alpha;
// The hill fall's moving water, the game's own v739 WebGL shader (src/thacnuoc/nuoc.js) ported: the stream in the
// notch above the lip, two drops (glassy where the water rolls over, torn into white strands that speed up as they
// fall, edges fraying, threads peeling off), the churn on the ledge and at the foot with spray and mist, lace foam
// drifting out over the plunge pool, ripple rings, the fall's broken reflection, spray drops and (by day) the faint
// rainbow in the spray. Coordinates: world units from (xw, lip). Phases come from main.gd FallFX, wrapped to the noise
// period so the numbers stay small and the water never jumps.
uniform vec2 uW;          // xw, lip (world)
uniform vec4 uG;          // ledge y, foot y, pool y (from the lip)
uniform vec4 uF; uniform vec4 uB; uniform vec4 uD; uniform vec4 uK;
uniform float uNight = 0.0;
uniform sampler2D uPF : filter_linear, repeat_disable;   // the ponds' field (R = F, .5 = the shore)
uniform vec4 uPB; uniform vec2 uKH;
uniform sampler2D uRk : filter_linear, repeat_disable;   // the pool rocks (n/fallrock.webp), drawn over this
uniform vec4 uRkR = vec4(0.0, 0.0, 1.0, 1.0);             // their world rect
float rkA(vec2 w) { vec2 uv = (w - uRkR.xy) / uRkR.zw; if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) return 0.0; return texture(uRk, uv).a; }
varying vec2 wp;
const float P = 32.0;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy; }
float fF(vec2 w) {
	vec2 d = w - uKH; float a = d.x / 32.0, b = d.y / 16.0;
	vec2 uv = (vec2((a + b) * 0.5, (b - a) * 0.5) - uPB.xy) * 4.0 / uPB.zw;
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) return 0.0;
	return (texture(uPF, uv).r * 255.0 - 20.0) / 200.0;
}
float h(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
float np(vec2 p, float Q) {
	vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
	float y0 = mod(i.y, P), y1 = mod(i.y + 1.0, P), x0 = i.x, x1 = i.x + 1.0;
	if (Q > 0.0) { x0 = mod(x0, Q); x1 = mod(x1, Q); }
	return mix(mix(h(vec2(x0, y0)), h(vec2(x1, y0)), f.x), mix(h(vec2(x0, y1)), h(vec2(x1, y1)), f.x), f.y);
}
float hw(float y, float s) {
	// (n15: one drop, lip to pool - the cliff has no ledge, so the half width grows smoothly all the way down)
	float bt = uG.y;
	float f = clamp(y / bt, 0.0, 1.0);
	// (n16b, Link "thác rộng hơn ở dưới"): straight sides that open out evenly from the lip to the pool
	return 12.5 + 15.0 * f;
}
float tf(float d, float v0) { return (sqrt(v0 * v0 + 840.0 * max(d, 0.0)) - v0) / 420.0; }
float strk(float X, float t, float sd) {
	float rb = np(vec2(X * 0.3 + sd, sd * 3.0), 0.0) * 0.6 + np(vec2(X * 0.75 + sd * 2.0, sd * 5.0 + 1.0), 0.0) * 0.4;
	float mv = np(vec2(X * 0.3 + sd, t * uK.x - uF.x), 0.0) * 0.55 + np(vec2(X * 0.72 + sd * 3.0, t * uK.x * 2.0 - uF.y), 0.0) * 0.3
		+ np(vec2(X * 1.6 + sd * 7.0, t * uK.x * 4.0 - uF.z), 0.0) * 0.15;
	return rb * 0.38 + mv * 0.62;
}
vec4 over(vec4 a, vec4 b) { return b + a * (1.0 - b.a); }
vec3 cA() { return mix(vec3(0.173, 0.408, 0.459), vec3(0.114, 0.259, 0.337), uNight); }
vec3 cB() { return mix(vec3(0.235, 0.561, 0.612), vec3(0.165, 0.353, 0.439), uNight); }
vec3 cC() { return mix(vec3(0.373, 0.714, 0.690), vec3(0.208, 0.424, 0.502), uNight); }
vec3 cD() { return mix(vec3(0.612, 0.780, 0.816), vec3(0.498, 0.604, 0.706), uNight); }
vec3 cE() { return mix(vec3(0.965, 0.992, 1.0), vec3(0.706, 0.784, 0.863), uNight); }
vec3 cS() { return mix(vec3(1.0), vec3(0.788, 0.847, 0.933), uNight); }
// ---- v2 (Link 2026-11-12 "méo giống thật"): a real fall, not a pipe of white. The curtain spreads as it falls and
// its sides fray in and out; it splits into ribbons with thin see-through gaps where the wet rock shows; the white is
// fine strands with heavier clumps of water racing down them (streaked like a long exposure); where it hits the ledge
// it bursts into spray and spills on, no flat ring; at the foot a big boiling white mound under a drifting cloud of
// spray, the plunge water bright with air under the surface, foam rafts breaking away over the pool; the rock either
// side is dark and glistening with spray.
float edgeN(float y, float t, float sd, float amp) {
	return (np(vec2(y * 0.09 + sd, t * uK.x * 1.5 - uF.y), 0.0) - 0.5) * amp + (np(vec2(y * 0.031 + sd * 2.0, uB.z * 0.5), 0.0) - 0.5) * amp * 1.4;
}
vec4 sheet(vec2 p, float y0, float y1, float v0, float wh, float sd, float px) {
	float y = p.y; if (y < y0 - 2.0 || y > y1 + 2.0 || abs(p.x) > hw(y, 1.0) * 1.35 + 16.0) return vec4(0.0);
	float L = y1 - y0, fy = clamp((y - y0) / L, 0.0, 1.0), d = y - y0, t = tf(d, v0);
	float spr = 1.0;
	float hl = hw(y, -1.0) * spr, hr = hw(y, 1.0) * spr;
	float amp = 0.8 + 1.6 * fy;   // (n16c) the sides breathe in and out a little, slowly: not ruled lines
	float eL = p.x + hl + edgeN(y, t, sd + 1.0, amp), eR = hr - p.x + edgeN(y, t, sd + 9.0, amp);
	float e = min(eL, eR);
	float tg = wh > 0.5 ? 1.0 + 4.0 * np(vec2(p.x * 0.35 + sd, uB.x), 0.0) : 0.0;
	float ytop = wh > 0.5 ? smoothstep(y0 + tg - px, y0 + tg + px + 3.0, y) : smoothstep(y0 - 3.0, y0 + 4.0, y + (np(vec2(p.x * 0.5 + sd, uF.x * 0.3), 0.0) - 0.5) * 4.0);   // (n15) the curtain grows out of the lip water, no cut line
	float ins = smoothstep(-px * 0.7 - 3.0, px * 0.7 + 1.0, e) * ytop * (1.0 - smoothstep(y1 - px * 2.0, y1, y));
	// the upper drop ends INTO the splash on the ledge: it thins away over its last few units, no cut edge
	if (wh < 0.5) ins *= 1.0 - smoothstep(y1 - 9.0, y1 - 1.0, y + (np(vec2(p.x * 0.4 + sd, uB.x * 2.0), 0.0) - 0.5) * 5.0);
	// threads peeling off the frayed sides
	float out1 = 0.0;
	if (false) {   // (n16: no threads peeling off the sides - the sides stay straight)
		float th0 = np(vec2(-e * 0.9 + sd * 5.0 + (eL < eR ? 2.0 : 7.0), t * uK.x * 2.0 - uF.y), 0.0);
		float brk = smoothstep(0.55, 0.7, np(vec2(y * 0.12 + sd * 7.0 + (eL < eR ? 0.0 : 20.0), t * uK.x * 1.5 - uF.x), 0.0));
		out1 = smoothstep(0.66, 0.74, th0) * smoothstep(-9.0 * fy, -1.5, e) * smoothstep(0.15, 0.45, fy) * brk * (1.0 - smoothstep(y1 - 8.0, y1 - 1.0, y));
	}
	if (ins < 0.001 && out1 < 0.001) return vec4(0.0);
	float w = hl + hr, u = clamp((p.x + hl) / w * 2.0 - 1.0, -1.0, 1.0), lt = u * 0.5 + 0.5;
	float X = p.x * 1.45 + 3.0 * (np(vec2(y * 0.025, sd + 4.0), 0.0) - 0.5);
	float s = strk(X, t, sd);
	float s2 = strk(X * 2.1 + 17.0, t * 1.08, sd + 3.0);
	// clumps of water racing down, each with a long streaked tail above it
	float ck = np(vec2(X * 0.22 + sd * 2.0, t * uK.x * 1.3 - uF.x * 1.3), 0.0);
	float clump = smoothstep(0.66, 0.82, ck);
	// ribbons: slow see-through gaps between them, more and wider lower down and towards the sides
	float gq = np(vec2(p.x * 0.085 + sd * 3.0, y * 0.006 + uB.z * 0.12), 0.0) * 0.7 + np(vec2(p.x * 0.21 + sd, y * 0.012), 0.0) * 0.3;
	float gap = smoothstep(0.34, 0.2, gq - 0.1 * smoothstep(0.5, 1.0, abs(u))) * smoothstep(0.08, 0.35, fy) * (wh > 0.5 ? 0.6 : 1.0);
	float th = wh > 0.5 ? mix(0.32, 0.5, smoothstep(0.0, 0.25, fy)) - 0.1 * fy : mix(0.9, 0.42, smoothstep(0.0, 0.03 + 0.11 * np(vec2(X * 0.3 + sd + 21.0, 2.0), 0.0), fy)) - 0.14 * smoothstep(0.05, 0.5, fy);   // (n15b) each strand tears at its own height, no ruled line
	float pu = np(vec2(sd + 13.0, t * uK.x * 0.5 - uD.y), 0.0);
	th -= 0.1 * (pu - 0.5) + 0.12 * smoothstep(0.6, 1.0, abs(u));
	// sides: torn along the strands over a few units, the rock showing between them
	float sideT = smoothstep(-1.8, 2.4, e + (s - 0.5) * 2.4 + (s2 - 0.5) * 1.2);
	ins *= sideT;
	float f = smoothstep(th - 0.025, th + 0.025, s * 0.7 + s2 * 0.3);
	f = max(f, clump * smoothstep(0.08, 0.2, fy));
	float fw = smoothstep(th + 0.07, th + 0.15, s);
	// glassy water rolling over the lip: clear green-teal, darker where it is thick, a sky line on its bend
	vec3 wc = mix(mix(cC(), cB(), smoothstep(0.0, 0.3, fy)), cA(), 0.55 * smoothstep(0.1, 0.6, fy) * (1.0 - s));
	wc *= 0.82 + 0.3 * lt - 0.12 * u * u;
	// (n15b) glassy part is not one flat teal: fast lines in it, a pale crest on the bend, darker cords between
	float gtop = 1.0 - smoothstep(0.02, 0.2, fy);
	wc *= 1.0 + gtop * (0.42 * (s - 0.5) + 0.25 * (s2 - 0.5));
	wc = mix(wc, mix(cC(), cS(), 0.45), gtop * 0.3 * smoothstep(0.55, 0.75, s2) * (1.0 - smoothstep(0.0, 0.08, fy)));
	float sun = mix(1.0, 0.45, uNight);
	float g2 = np(vec2(X * 0.42 + sd * 11.0, t * uK.x - uF.x), 0.0);
	wc = mix(wc, cS(), (1.0 - smoothstep(0.0, 0.035, abs(g2 - 0.5))) * 0.5 * (1.0 - smoothstep(0.1, 0.35, fy)) * (1.0 - wh) * sun);
	// the white: brighter on the sun side and on the clumps, grey-blue in the shade and between strands
	vec3 fc = mix(cD() * 0.78, cE(), clamp(0.0 + 0.55 * lt + 2.6 * (s - th) + 1.2 * (s2 - 0.5) + 0.25 * fw + 0.35 * clump - 0.22 * u * u, 0.0, 1.0));
	float aw = mix(0.9, 0.55, smoothstep(0.1, 0.8, fy)) * (1.0 - 0.45 * smoothstep(0.6, 1.0, abs(u)));
	vec3 col = mix(wc, fc, f);
	// (n16c) the curtain is not one flat sheet: thicker brighter ribs and thinner shaded runs side by side, lit from the left
	float rib = np(vec2(p.x * 0.32 + sd + 2.0, y * 0.004), 0.0) * 0.65 + np(vec2(p.x * 0.9 + sd, y * 0.01 + 5.0), 0.0) * 0.35;
	col *= 0.84 + 0.3 * rib + 0.08 * (0.5 - u);
	float a = mix(aw, 0.96, f) * ins;
	// in a gap only a thin film runs over the rock: dark, see-through, a few threads in it
	float thr = smoothstep(0.72, 0.8, np(vec2(X * 0.9 + 40.0, t * uK.x * 2.0 - uF.y), 0.0));
	col = mix(col, mix(cA() * 0.55, fc, thr), gap);
	a = mix(a, ins * (0.28 + 0.6 * thr), gap);
	if (out1 > 0.0) { col = mix(col, fc, 1.0 - ins); a = max(a, out1 * 0.75); }
	return vec4(col * a, a);
}
// white water boiling up where a drop lands: lumpy mound, its top torn into spray, dark pockets, soft at the bottom
vec4 churn(vec2 p, vec2 c, float rx, float ry, float sd, float px) {
	vec2 q = (p - c) / vec2(rx, ry); if (abs(q.x) > 1.2 || q.y < -2.6 || q.y > 1.3) return vec4(0.0);
	float b = np(vec2(p.x * 0.13 + sd, uB.y * 1.3), 0.0), b2 = np(vec2(p.x * 0.37 + sd * 3.0, uB.x * 2.2), 0.0), b3 = np(vec2(p.x * 0.85 + sd * 5.0, uB.y * 3.0), 0.0);
	float dm = sqrt(max(0.0, 1.0 - q.x * q.x * 0.85));
	float tp = -dm * (0.35 + 0.8 * b + 0.4 * b2 + 0.2 * b3), bo = dm * (0.5 + 0.4 * np(vec2(p.x * 0.25 + sd * 5.0, uB.x), 0.0));
	float ax = px / ry; float a = smoothstep(tp - ax * 2.0, tp + ax * 2.0, q.y) * (1.0 - smoothstep(bo - 1.0, bo + 0.7, q.y)) * smoothstep(1.1, 0.7, abs(q.x)) * smoothstep(0.2, 0.5, dm);
	float ab = tp - q.y, nu = np(vec2(p.x * 0.32 + sd, p.y * 0.3 + uB.z * 2.5), 0.0), nu2 = np(vec2(p.x * 0.7 + sd * 2.0, p.y * 0.6 + uB.w * 3.0), 0.0);
	float sp = (ab > 0.0 && q.y < bo) ? smoothstep(1.6, 0.0, ab) * smoothstep(0.3, 0.8, nu * 0.65 + nu2 * 0.35) * 0.8 * dm : 0.0;
	if (a < 0.001 && sp < 0.001) return vec4(0.0);
	float n = np(vec2(p.x * 0.35 + sd, p.y * 0.45 + uB.y), 0.0) * 0.6 + np(vec2(p.x * 0.8, p.y + uB.w), 0.0) * 0.4;
	float hg = (q.y - tp) / max(bo - tp, 0.01);
	float sh = smoothstep(0.3, 1.0, hg + (n - 0.5) * 0.6);
	vec3 col = mix(cE(), cD() * 0.9, clamp(sh * 0.85 - smoothstep(-0.8, 0.8, q.x) * 0.25, 0.0, 1.0));
	float pk = smoothstep(0.32, 0.2, n) * smoothstep(0.2, 0.5, hg); col = mix(col, cA() * 0.9, pk * 0.4);
	a *= 0.96; col = mix(cE(), col, a); a = max(a, sp); return vec4(col * a, a);
}
// the cloud of spray: puffs that rise, drift with the breeze and thin out
vec4 mist(vec2 p, vec2 c, float rx, float ry, float al) {
	vec2 q = (p - c) / vec2(rx, ry); if (abs(q.x) > 1.3 || q.y < -1.4 || q.y > 0.4) return vec4(0.0);
	float r = length(vec2(q.x * 0.85 - 0.12 * (q.y + 0.2), (q.y + 0.2) * 0.8));
	vec2 dr = vec2(p.x * 0.06 - uB.w * 0.35, p.y * 0.06 + uB.z * 1.2);
	float m = np(dr, 0.0) * 0.5 + np(dr * 2.1 + vec2(3.0, 1.0), 0.0) * 0.3 + np(dr * 4.3 + vec2(7.0, 2.0), 0.0) * 0.2;
	float a = smoothstep(1.15, 0.05, r) * smoothstep(0.2, 0.7, m) * al * smoothstep(0.4, -0.05, q.y);
	return vec4(cE() * a, a);
}
void fragment() {
	vec2 p = wp - uW;
	float px = max(fwidth(p.x), 1e-4), yL = uG.x, bt = uG.y;
	vec4 o = vec4(0.0);
	float wm = smoothstep(0.45, 0.62, fF(wp));
	float wb = hw(bt, 1.0) * 1.28;
	// the rock either side of the fall, wet with spray: darker, with glints that come and go
	if (p.y > 2.0 && p.y < bt - 3.0 && wm < 0.5) {
		float spr = 1.0;
		float hx = hw(p.y, sign(p.x)) * spr;
		float dx = abs(p.x) - hx;
		if (dx > -6.0 && dx < 22.0) {
			float wet = smoothstep(22.0, 3.0, dx) * (0.55 + 0.45 * np(vec2(p.x * 0.2, p.y * 0.05), 0.0)) * smoothstep(2.0, 12.0, p.y);
			wet *= 0.75 + 0.45 * smoothstep(bt * 0.4, bt, p.y);
			wet *= smoothstep(0.3, 0.6, np(vec2(p.x * 0.09 + 5.0, p.y * 0.03), 0.0) * 0.6 + np(vec2(p.x * 0.3, p.y * 0.11 + 2.0), 0.0) * 0.4);
			float a = 0.24 * wet; o = over(o, vec4(vec3(0.04, 0.07, 0.07) * a, a));
			float gl = smoothstep(0.86, 0.95, np(vec2(p.x * 0.7 + 3.0, p.y * 0.45 + uB.x * 2.0), 0.0)) * wet;
			o = over(o, vec4(cS() * 0.4 * gl * mix(1.0, 0.4, uNight), 0.4 * gl));
			// thin trickles down the wet rock
			float tr = smoothstep(0.9, 0.96, np(vec2(p.x * 0.6 + 11.0, p.y * 0.02 - uF.x * 0.25), 0.0)) * smoothstep(18.0, 6.0, dx) * smoothstep(-2.0, 2.0, dx);
			o = over(o, vec4(cD() * 0.6 * tr, 0.6 * tr));
		}
	}
	if (wm > 0.0 && p.y > bt - 6.0) {
		vec2 dc = p - vec2(1.0, bt + 7.0); float r = length(vec2(dc.x, dc.y * 2.0)), an = atan(dc.y * 2.0, dc.x);
		vec4 pc = vec4(0.0);
		// plunge water full of air: pale turquoise under the surface, boiling
		float bo1 = np(vec2(p.x * 0.12 + uB.x, p.y * 0.2 - uB.y), 0.0) * 0.6 + np(vec2(p.x * 0.3 - uB.z, p.y * 0.5 + uB.w), 0.0) * 0.4;
		float aer = smoothstep(70.0, 18.0, r + (bo1 - 0.5) * 20.0);
		vec3 ac = mix(vec3(0.42, 0.72, 0.72), vec3(0.62, 0.86, 0.85), bo1);
		ac = mix(ac, ac * 0.45, uNight);
		pc = over(pc, vec4(ac * 0.55 * aer, 0.55 * aer));
		// foam rafts tearing off the mound and drifting out, lacy, thinning as they go
		float rr = max(r, 4.0); vec2 lp = vec2((an / 6.2832 + 0.5) * 14.0, log(rr) * 6.0 - uD.x);
		float n = np(lp, 14.0) * 0.55 + np(lp * 2.0 + vec2(3.0, 0.0), 28.0) * 0.3 + np(lp * 4.0 + vec2(1.0, 0.0), 56.0) * 0.15;
		float fade = smoothstep(110.0, 35.0, r);
		float raft = smoothstep(0.52, 0.7, n) * smoothstep(95.0, 25.0, r);
		float lace = (1.0 - smoothstep(0.0, 0.07, abs(n - 0.48))) * fade * 0.7;
		// (holes from rotated, warped noise: thresholded straight value noise read as square blocks)
		vec2 hq = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * vec2(p.x * 0.32, p.y * 0.62) + uB.xy * 0.3;
		hq += vec2(np(hq * 0.45 + 7.0, 0.0), np(hq * 0.45 + 3.0, 0.0)) * 1.6;
		float holes = smoothstep(0.38, 0.68, np(hq, 0.0) * 0.65 + np(hq * 2.3 + 5.0, 0.0) * 0.35);
		float brk2 = smoothstep(0.4, 0.6, np(vec2(an * 3.0, r * 0.08 - uD.x * 0.3), 0.0));
		float fa = max(raft * holes, lace * 0.45 * brk2) * smoothstep(8.0, 20.0, r) * 0.85;
		pc = over(pc, vec4(mix(cD(), cE(), 0.65 + 0.3 * holes) * fa, fa));
		// the fall's broken reflection under the foot
		if (dc.y > 4.0 && dc.y < 40.0) {
			float rx = p.x + 2.0 * sin(p.y * 0.35 + uK.z * 6.2832); float hb = wb + 4.0;
			if (abs(rx) < hb) {
				float yr = 2.0 * bt - p.y; float rs = strk(rx, tf(yr - yL - 2.0, 16.0), 5.0);
				float rf = smoothstep(0.45, 0.6, rs) * smoothstep(40.0, 8.0, dc.y) * smoothstep(hb, hb - 6.0, abs(rx));
				float ra = rf * 0.22; pc = over(vec4(cE() * ra, ra), pc);
			}
		}
		o = over(o, pc * wm);
	}
	float bx = p.x - 1.0;
	// the stream in the notch: running water, not a flat strip - streaks racing to the lip, darker and deeper in the
	// middle, ragged where it laps the stone either side, a sky sheen and a glassy bend at the lip
	if (p.y > -19.0 && p.y < 9.0) {
		float f = clamp((p.y + 11.0) / 13.0, 0.0, 1.0), nh = hw(0.0, 1.0) * mix(0.86, 1.0, f);
		float rag = (np(vec2(p.y * 0.5 + (bx > 0.0 ? 9.0 : 0.0), uF.w * 1.5), 0.0) - 0.5) * 2.2;
		nh *= 1.0 - 0.12 * smoothstep(-1.0, 8.0, p.y);   // no shoulders where it meets the falling sheet
		float e = nh - abs(bx) + rag;
		if (e > -1.0) {
			// (n15) the top runs on into the pool behind (no edge), the sides sink under the stones' shadow
			float a = smoothstep(-px * 0.8, px * 0.8 + 1.6, e) * smoothstep(-19.0, -13.0, p.y + rag * 1.5) * (1.0 - smoothstep(-3.0, 4.0, p.y + rag * 2.0 + (np(vec2(bx * 0.6, uF.x * 0.5), 0.0) - 0.5) * 6.0)) * 0.97;
			// the water gathers to the middle as it speeds to the lip: its lines bend inwards
			float sx = bx * (0.9 - 0.35 * f) + 2.0 * (np(vec2(p.y * 0.08, 5.0), 0.0) - 0.5);
			float st = np(vec2(sx, p.y * 0.12 - uF.x * 1.4), 0.0) * 0.55 + np(vec2(sx * 2.3 + 4.0, p.y * 0.25 - uF.y * 1.4), 0.0) * 0.3
				+ np(vec2(sx * 5.0 + 9.0, p.y * 0.5 - uF.z * 1.4), 0.0) * 0.15;
			float cen = 1.0 - smoothstep(0.0, 1.0, abs(bx) / max(nh, 1.0));
			vec3 c = mix(cC(), cA(), 0.55 * cen + 0.25 * (1.0 - f));
			c = mix(c, cB(), 0.2 * f);
			c = mix(c, mix(cC(), cS(), 0.35), 0.22 * smoothstep(0.4, 1.0, f));   // (n15b) shallow and quick at the lip: lighter, not a dark band
			c *= 0.86 + 0.3 * st;
			float ln = smoothstep(0.62, 0.72, st) * (0.5 + 0.5 * f);
			c = mix(c, cD(), ln * 0.55);
			float sk = (1.0 - smoothstep(0.0, 0.08, abs(np(vec2(sx * 0.35 + 3.0, p.y * 0.06 - uF.w), 0.0) - 0.55))) * 0.5;
			c = mix(c, cS(), sk * mix(1.0, 0.4, uNight));
			float edgeW = (1.0 - smoothstep(0.0, 2.2, e)) * smoothstep(0.4, 0.7, np(vec2(p.y * 0.7, bx * 0.3 + uB.x * 2.0), 0.0));
			c = mix(c, cE(), edgeW * 0.6);
			c *= 0.72 + 0.28 * smoothstep(0.0, 5.0, e);
			// glassy bulge where it rolls over the lip, broken by the ripples
			c = mix(c, mix(cC(), cS(), 0.5), 0.14 * smoothstep(0.3, 1.0, f) * smoothstep(0.4, 0.65, st));
			c *= mix(1.0, 0.62, uNight);
			o = over(o, vec4(c * a, a));
		}
	}
	o = over(o, sheet(p, 0.0, bt, 55.0, 0.0, 0.0, px));
	if (p.y > -1.0 && p.y < 9.0) {
		float hl = hw(p.y, -1.0), hr = hw(p.y, 1.0); float e = min(p.x + hl, hr - p.x);
		if (e > 0.0) {
			float ln = (1.0 - smoothstep(px * 0.6, px * 1.8, abs(p.y - 1.6 - 0.5 * sin(p.x * 0.35)))) * smoothstep(0.55, 0.7, np(vec2(p.x * 0.5 - uF.w * 2.0, 1.0), 0.0)); float sk = smoothstep(0.0, 3.0, e);
			// (n15: no ruled highlight along the lip - it read as the rim of a box)
			float shd = smoothstep(3.0, 5.0, p.y) * smoothstep(10.0, 6.0, p.y) * smoothstep(0.0, 2.0, e) * 0.12; o.rgb *= 1.0 - shd;
		}
	}
	// the foot
	o = over(o, churn(p, vec2(1.0, bt + 5.0), wb + 18.0, 13.0, 7.0, px));
	o = over(o, mist(p, vec2(4.0, bt + 2.0), wb + 40.0, 50.0, mix(0.32, 0.12, uNight)));
	// spray drops flung out of the foot and off the ledge
	for (int lv = 0; lv < 0; lv++) {   // (n16: the spray is Godot particles now, main.gd _fall_particles)
		float yy = lv == 0 ? bt : yL;
		float span = wb + 34.0;
		vec2 g = floor(p / 2.2) + float(lv) * 31.0; float hs = h(g);
		if (hs > 0.86 && abs(p.y - yy) < 26.0 && abs(p.x) < span) {
			float ph = fract(uK.w * (0.9 + 0.7 * h(g + 7.0)) + hs * 7.0); vec2 st = vec2((h(g + 3.0) - 0.5) * (span * 1.4), yy + 2.0);
			vec2 dp = st + vec2(sign(st.x) * ph * 14.0, -ph * (1.0 - ph) * 4.0 * (7.0 + 14.0 * h(g + 5.0)));
			float dr = length(p - dp); float a = (1.0 - smoothstep(0.5, 0.5 + px * 1.2, dr)) * (1.0 - ph) * 0.85; o = over(o, vec4(cE() * a, a));
		}
	}
	// the rainbow in the spray by day (game fx(): 5 bands round (xw+8, base+26), r 46 - 2.4k, a = .2 + .05 sin)
	if (uNight < 0.5) {
		vec2 rc = p - vec2(8.0, bt + 26.0); float rd = length(rc), ra = atan(rc.y, rc.x) + 6.2832;
		if (rd > 34.0 && rd < 48.0 && ra > 3.85 && ra < 5.38) {
			float al = (0.2 + 0.05 * sin(uK.w * 0.4)) * sin((ra - 3.85) / 1.53 * 3.1416);
			float k = (46.0 - rd) / 2.4;
			vec3 rb = k < 0.5 ? vec3(1.0, 0.478, 0.408) : k < 1.5 ? vec3(1.0, 0.812, 0.345) : k < 2.5 ? vec3(0.541, 0.847, 0.447) : k < 3.5 ? vec3(0.392, 0.714, 1.0) : vec3(0.612, 0.549, 1.0);
			float band = smoothstep(-0.6, -0.2, k) * smoothstep(4.6, 4.2, k);
			float a = al * band;
			o = over(o, vec4(rb * a, a));
		}
	}
	// at night the white water catches only the moon: keep it from glowing against the dark village
	o.rgb *= mix(1.0, 0.72, uNight);
	COLOR = o;
}
