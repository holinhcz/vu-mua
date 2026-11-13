shader_type canvas_item;
#include "res://night.gdshaderinc"
#include "res://rain.gdshaderinc"
// River water v5 (song test page), ported. Drawn under the ground pieces; the river is a hole in them, so only the
// water shows here, and what stands over the water (boats, overhanging leaves, stakes) is in the pieces above.
// The shore is the river's own outline only: nothing standing in the water gets foam, shallows or rings.
// Works in "capture pixels" (3 per world unit) like the test page, so all the tuned numbers stay the same.
uniform sampler2D uA : filter_linear, repeat_disable;   // up/1020, dist/255, earth bank, near-tree shade
uniform sampler2D uB : filter_linear, repeat_disable;   // flow x, flow y, mirror weight, (unused)
uniform sampler2D uR : filter_linear, repeat_disable;   // the whole map, small (0.375 px/unit): what the far bank mirrors
uniform sampler2D uN : filter_linear_mipmap, repeat_enable; // tiling wave height + slope
uniform vec4 uMap;      // world x, y, w, h of uA/uB
uniform vec4 uRef;      // world x, y, w, h of uR
uniform vec3 uDeep;
uniform vec3 uShal;
uniform vec4 uK = vec4(900., .4, 120., .75);
uniform vec3 uG = vec3(190., 2.2, .3);
uniform vec3 uV = vec3(360., 22., .24);
uniform vec4 uDbg = vec4(1.);   // test switches: shallows, foam, mirror, light web
uniform vec3 uGain = vec3(1.);
// nước nổi: the flood map (tools/floodmap.py; R = signed distance to the flood's edge, 128 + 4 per world px) and the switch
uniform sampler2D uF : filter_linear, repeat_disable;
uniform float uFlood = 0.;  // brings the average water colour onto the game's (measured: v5 came out lighter and greener)

varying vec2 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy; }

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
	vec2 muv = (wpos - uMap.xy) / uMap.zw;
	if (muv.x < 0. || muv.y < 0. || muv.x > 1. || muv.y > 1.) discard;
	vec4 ax = texture(uA, muv);
	vec4 fz = texture(uB, muv);
	float d = ax.g * 255., rw = fz.b;
	float fd = -1.;
	if (uFlood > .5) fd = (texture(uF, muv).r * 255. - 128.) * .25;
	bool fland = d < .5 && rw < .01;
	if (fland && fd <= 0.) discard;     // land: nothing to draw (in the flood, land out of the flood's reach)
	float fcov = fland ? clamp(fd / max(fwidth(wpos.x), 1e-3) + .5, 0., 1.) : 1.;
	if (fland) { d = 40.; rw = 0.; }      // flooded land: open water, no far-bank mirror
	if (fd > 0.) { d = max(d, 40.); rw = 0.; }   // under the flood the old shore is gone: one sheet with the river, no far-bank shade
	float uT = TIME;
	vec2 p = wpos * 3.;                   // capture pixels
	float up = ax.r * 1020.;
	vec2 dir = normalize(fz.rg * 2. - 1. + 1e-4);
	vec2 q = vec2(p.x, p.y * 2.), dq = normalize(vec2(dir.x, dir.y * 2.));
	float fo = ax.b, sn = ax.a;
	if (fd > 0.) { fo = 0.; sn = 0.; }   // under the flood the old shore is no shore: no foam, no bed, no tree shade
	if (fland) up = 0.;
	float deep = smoothstep(0., 150., d); deep = mix(max(deep, .8), deep, fo);
	float calm = mix(.45, 1., smoothstep(2., 70., d));
	float ph = uT * .3, f0 = fract(ph), f1 = fract(ph + .5), w0 = 1. - abs(2. * f0 - 1.), L = uV.x * mix(.35, 1., deep);
	vec2 a0 = q - dq * f0 * L, a1 = q - dq * f1 * L + vec2(91., 37.);
	mat2 R1 = mat2(vec2(.80, .60), vec2(-.60, .80)), R2 = mat2(vec2(.34, -.94), vec2(.94, .34));
	vec2 wp = (nrm(a0 / 430.) * w0 + nrm(a1 / 430.) * (1. - w0)) * uV.y + nrm(R2 * q / 173.) * uV.y * .35;
	vec2 dr = vec2(.707, .707) * uT;
	float gust = mix(.55, 1.2, hgt(R1 * (q - dr * 40.) / 1100.)) * calm;
	vec2 x = q + wp; vec3 hg = HG(x, uT); float h0 = hg.x;
	vec3 N = normalize(vec3(hg.yz * uK.x * gust, 1.));
	vec3 body = mix(uShal, uDeep, deep);
	body *= 1. + (h0 - .6) * uK.y * gust;
	body *= mix(1., mix(.78, 1., smoothstep(0., 90., up)), rw) * (1. - .15 * sn);
	float bed = (1. - smoothstep(0., 34., d)) * fo;
	body = mix(body, vec3(.69, .85, .80) * (.92 + .16 * h0), bed * .5 * uDbg.x);
	vec3 V = normalize(vec3(0., .55, .83)), Rr = reflect(-V, N);
	vec3 env = mix(vec3(.13, .32, .22), vec3(.78, .93, .89), smoothstep(.55, .95, Rr.z));
	vec3 w = mix(body, env, uV.z);
	float rk = 0.; vec3 rc = vec3(0.);
	if (up > 0. && up < 520. && uDbg.z > .5) {   // the old captured mirror (off: trees now mirror themselves, refl.gdshader)
		float wob = N.x * (7. + up * .05) + sin(p.y * .42 + uT * 2.6 + N.y * 5.) * (1. + up * .012);
		for (int k = -1; k <= 1; k++) {
			vec2 rp = vec2(p.x + wob + float(k) * (1. + up * .008), p.y - 2. * up + N.y * (6. + up * .06));
			vec2 ruv = (rp / 3. - uRef.xy) / uRef.zw;
			if (ruv.y > 0.) { vec4 rr = texture(uR, ruv); rc += rr.rgb * rr.a / 3.; rk += rr.a / 3.; }
		}
		rk *= exp(-up / uK.z) * rw;
	}
	w = mix(w, rc * .66 + body * .2, uK.w * rk * uDbg.z);
	float sh = (1. - smoothstep(8., 130., d)) * smoothstep(1., 10., d) * (.35 + .65 * fo) * uDbg.w;
	float cw = lay(x * 1.7, 1.9, 260., 1., 30., uT, vec2(.4, .2)).x * lay(x * 1.7, .3, 330., 1., 24., uT, vec2(.9, .6)).x;
	w += vec3(.95, 1., .9) * smoothstep(.62, .9, cw) * .13 * sh * (1. - .6 * rk);
	vec3 Ld = normalize(vec3(-.45, -.55, .70)); float sd = max(dot(Rr, Ld), 0.);
	float tw = .5 + hgt(R2 * q / 11. + uT * vec2(.9, .6));
	w += vec3(1., .98, .9) * (pow(sd, uG.x) * uG.y * tw + pow(sd, 24.) * .10) * (1. - .75 * rk) * mix(.5, 1., deep);
	float fk = smoothstep(.70, .80, hgt(a0 / 41.)) * smoothstep(.56, .74, hgt(R1 * a0 / 290. + .5)) * w0
		+ smoothstep(.70, .80, hgt(a1 / 41.)) * smoothstep(.56, .74, hgt(R1 * a1 / 290. + .5)) * (1. - w0);
	w = mix(w, vec3(.90, .94, .90), fk * uG.z * deep);
	float lap = 1.6 + 1.3 * sin(uT * 1.25 + (p.x + p.y) * .014), br = hgt(q / 64. + uT * .012);
	float foam = (1. - smoothstep(0., 3. + lap + br * 4., d)) * (.25 + .6 * br);
	float band = smoothstep(.72, 1., sin(d * .42 + uT * 2.4 + br * 5.)) * (1. - smoothstep(5., 24., d)) * smoothstep(.5, 3., d);
	foam = max(foam, band * .45 * (.4 + .6 * br)) * fo;
	w = mix(w, vec3(.90, .93, .87), foam * .75 * uDbg.y);
	w = mix(w, vec3(1.) / max(uGain, vec3(.01)), rain_rings(wpos) * .55);   // web: rr*.55 white
	COLOR = vec4(night_col(w * uGain), fland ? .94 * fcov : 1.);
}
