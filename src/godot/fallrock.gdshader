shader_type canvas_item;
#include "res://night.gdshaderinc"
// (n16, Link "đá ngay chân thác thì cứ như lơ lửng trên mặt nước"): the pool rocks (n/fallrock.webp, padded below
// by main.gd) sit IN the water. Their lowest part is under the surface (seen through teal water, fading out), a
// broken ring of foam laps at the waterline and moves, and a dark wobbling reflection lies on the water under them.
// Distances are found by walking the picture's alpha up/down this column (picture px, 6 px = 1 world unit).
float hh(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
float vno(vec2 p) { vec2 i = floor(p), f = p - i; f = f * f * (3.0 - 2.0 * f);
	float a = hh(i), b = hh(i + vec2(1.0, 0.0)), c = hh(i + vec2(0.0, 1.0)), d = hh(i + vec2(1.0, 1.0));
	return a + (b - a) * f.x + (c - a) * f.y + (a - b - c + d) * f.x * f.y; }
varying vec2 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy; }
void fragment() {
	vec2 tp = TEXTURE_PIXEL_SIZE;
	vec4 c = texture(TEXTURE, UV);
	float t = TIME;
	vec3 wat = vec3(0.30, 0.58, 0.58);
	float wl = 11.0 + 2.2 * sin(wp.x * 0.9 + t * 1.7) + 1.4 * sin(wp.x * 2.3 - t * 2.6) + 2.0 * (vno(vec2(wp.x * 0.6, t * 0.7)) - 0.5);
	vec4 o = vec4(0.0);
	if (c.a > 0.05) {
		// how far down this column the rock goes on from here
		float db = 60.0;
		for (int k = 1; k <= 20; k++) {
			float dy = float(k) * 1.5;
			if (texture(TEXTURE, UV + vec2(0.0, dy * tp.y)).a < 0.3) { db = dy; break; }
		}
		vec3 rc = c.rgb;
		float sub = smoothstep(wl + 1.0, wl - 1.0, db);
		// under water: darker, teal, then gone into the water
		vec3 uc = mix(rc * 0.55, wat * 0.8, 0.55);
		float ua = mix(0.85, 0.0, smoothstep(wl - 1.0, 0.0, db));
		// wet dark band just above the waterline
		float wetB = smoothstep(wl + 9.0, wl + 1.0, db) * (1.0 - sub);
		rc *= 1.0 - 0.3 * wetB;
		vec3 col = mix(rc, uc, sub);
		float a = mix(c.a, c.a * ua, sub);
		// foam lapping at the waterline, broken and moving
		float fl = (1.0 - smoothstep(0.0, 1.6, abs(db - wl))) * smoothstep(0.35, 0.6, vno(vec2(wp.x * 1.3 - t * 1.2, 3.0)));
		col = mix(col, vec3(0.93, 0.97, 0.97), fl * 0.85);
		a = max(a, fl * 0.85 * c.a);
		o = vec4(col, a);
	} else {
		// water below a rock: its reflection (the rock flipped at its waterline), wobbling, and a ring of foam
		float du = 60.0;
		for (int k = 1; k <= 20; k++) {
			float dy = float(k) * 1.5;
			if (texture(TEXTURE, UV - vec2(0.0, dy * tp.y)).a > 0.3) { du = dy; break; }
		}
		if (du < 30.0) {
			float wob = 1.6 * sin(wp.y * 3.0 + t * 3.0) + 1.0 * sin(wp.x * 1.7 - t * 2.0);
			vec4 rf = texture(TEXTURE, UV + vec2(wob * tp.x, -(2.0 * du + 2.0 * wl) * tp.y));
			float ra = rf.a * 0.55 * (1.0 - du / 30.0) * smoothstep(0.25, 0.55, vno(vec2(wp.x * 0.8, wp.y * 2.4 - t * 1.5)) + 0.2);
			vec3 rcol = mix(rf.rgb * 0.45, wat * 0.5, 0.5);
			o = vec4(rcol, ra);
			float ring = (1.0 - smoothstep(0.0, 3.5, du)) * smoothstep(0.4, 0.62, vno(vec2(wp.x * 1.1 + t * 0.8, 9.0)));
			o.rgb = mix(o.rgb, vec3(0.93, 0.97, 0.97), ring);
			o.a = max(o.a, ring * 0.75);
		}
	}
	if (o.a < 0.003) discard;
	COLOR = vec4(night_col(o.rgb), o.a);
}
