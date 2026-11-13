shader_type canvas_item;
// One CSS box like the web game draws it: rounded corners, background colour + gradients
// (linear, radial, repeating stripes), box-shadow list (outer + inset), borders, backdrop blur.
// Pictures (url backgrounds) are drawn by Box itself on top of this.
// The rect this draws on is the box grown by `margin` on every side (room for outer shadows).

uniform vec2 size = vec2(10.0);
uniform float margin = 0.0;
uniform vec4 radius = vec4(0.0);      // tl tr br bl
uniform vec4 bg_color = vec4(0.0);
// gradient A: kind 0 none, 1 linear, 2 radial (circle)
uniform int ga_kind = 0;
uniform int ga_n = 0;
uniform vec4 ga_c[10];
uniform float ga_p[10];               // px when ga_px, else 0..1
uniform int ga_px = 0;
uniform float ga_ang = 180.0;         // css deg (180 = top to bottom)
uniform vec2 ga_ctr = vec2(0.5);      // radial centre, px when ga_cpx else fraction
uniform int ga_cpx = 0;
uniform vec4 ga_rect = vec4(0.0);	 // css background-size/position of this layer (px); zw 0 = whole box
uniform int ga_clip = 0;			  // no-repeat: nothing outside ga_rect
// gradient B: repeating-linear stripes on top of A (bamboo nodes)
uniform int gb_n = 0;
uniform vec4 gb_c[10];
uniform float gb_p[10];
uniform float gb_ang = 90.0;
uniform float gb_period = 54.0;
// box-shadow list in css order (first = on top)
uniform int sh_n = 0;
uniform vec4 sh_g[8];                 // ox oy blur spread
uniform vec4 sh_c[8];
uniform float sh_in[8];
// borders: widths top right bottom left, one colour per side
uniform vec4 bw = vec4(0.0);
uniform vec4 bc_t = vec4(0.0);
uniform vec4 bc_r = vec4(0.0);
uniform vec4 bc_b = vec4(0.0);
uniform vec4 bc_l = vec4(0.0);
uniform float px = 1.0;               // screen pixels per css px (anti-aliasing width)
//BD_UNIFORMS

float sd_box(vec2 p, vec2 b, vec4 r) {
	// p from centre, b half size, r = tl tr br bl
	float rr = p.x > 0.0 ? (p.y > 0.0 ? r.z : r.y) : (p.y > 0.0 ? r.w : r.x);
	rr = min(rr, min(b.x, b.y));
	vec2 q = abs(p) - b + rr;
	return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - rr;
}

float erf_(float x) {
	float s = sign(x);
	x = abs(x);
	float t = 1.0 / (1.0 + 0.3275911 * x);
	float y = 1.0 - (((((1.061405429 * t - 1.453152027) * t) + 1.421413741) * t - 0.284496736) * t + 0.254829592) * t * exp(-x * x);
	return s * y;
}

// coverage of a shape with signed distance d, blurred like css box-shadow (sigma = blur / 2)
float cover(float d, float blur) {
	if (blur < 0.01) {
		return clamp(0.5 - d * px, 0.0, 1.0);
	}
	float sg = blur * 0.5;
	return 0.5 - 0.5 * erf_(d / (sg * 1.41421356));
}

vec4 over(vec4 top, vec4 bot) {
	float a = top.a + bot.a * (1.0 - top.a);
	if (a < 1e-5) return vec4(0.0);
	return vec4((top.rgb * top.a + bot.rgb * bot.a * (1.0 - top.a)) / a, a);
}

// gradient colour at t. Reads the uniform arrays directly: some phone GPUs (Adreno) break when a
// uniform array is passed into a function, which left gradients stuck on their last colour.
vec4 stops_a(float t) {
	if (ga_n <= 0) return vec4(0.0);
	if (t <= ga_p[0]) return ga_c[0];
	vec4 last = ga_c[0];
	for (int i = 1; i < 10; i++) {
		if (i >= ga_n) break;
		last = ga_c[i];
		if (t <= ga_p[i]) {
			float k = (t - ga_p[i - 1]) / max(1e-5, ga_p[i] - ga_p[i - 1]);
			return mix(ga_c[i - 1], ga_c[i], clamp(k, 0.0, 1.0));
		}
	}
	return last;
}

vec4 stops_b(float t) {
	if (gb_n <= 0) return vec4(0.0);
	if (t <= gb_p[0]) return gb_c[0];
	vec4 last = gb_c[0];
	for (int i = 1; i < 10; i++) {
		if (i >= gb_n) break;
		last = gb_c[i];
		if (t <= gb_p[i]) {
			float k = (t - gb_p[i - 1]) / max(1e-5, gb_p[i] - gb_p[i - 1]);
			return mix(gb_c[i - 1], gb_c[i], clamp(k, 0.0, 1.0));
		}
	}
	return last;
}

void fragment() {
	vec2 full = size + 2.0 * margin;
	vec2 p = UV * full - margin;          // css px from box top-left
	vec2 hc = size * 0.5;
	float d = sd_box(p - hc, hc, radius);
	float inside = cover(d, 0.0);
	vec4 col = vec4(0.0);
	// outer shadows (drawn outside the box only), last listed at the bottom
	for (int i = 7; i >= 0; i--) {
		if (i >= sh_n || sh_in[i] > 0.5) continue;
		vec4 g = sh_g[i];
		float ds = sd_box(p - hc - g.xy, hc + g.w, radius + g.w);
		float a = cover(ds, g.z) * sh_c[i].a * (1.0 - inside);
		col = over(vec4(sh_c[i].rgb, a), col);
	}
	// background
	vec4 bg = bg_color;
	vec2 gs = ga_rect.z > 0.0 ? ga_rect.zw : size;
	vec2 gq = ga_rect.z > 0.0 ? p - ga_rect.xy : p;
	bool gin = ga_clip == 0 || (gq.x >= 0.0 && gq.y >= 0.0 && gq.x <= gs.x && gq.y <= gs.y);
	if (ga_kind == 1 && gin) {
		float an = radians(ga_ang);
		vec2 dir = vec2(sin(an), -cos(an));
		float L = abs(gs.x * sin(an)) + abs(gs.y * cos(an));
		float t = dot(gq - gs * 0.5, dir) + L * 0.5;
		bg = over(stops_a(ga_px == 1 ? t : t / L), bg);
	} else if (ga_kind == 2 && gin) {
		vec2 c = ga_cpx == 1 ? ga_ctr : ga_ctr * gs;
		float L = max(max(length(c), length(c - vec2(gs.x, 0.0))), max(length(c - vec2(0.0, gs.y)), length(c - gs)));
		float t = length(gq - c);
		bg = over(stops_a(ga_px == 1 ? t : t / L), bg);
	}
	if (gb_n > 0) {
		float an = radians(gb_ang);
		vec2 dir = vec2(sin(an), -cos(an));
		float L = abs(size.x * sin(an)) + abs(size.y * cos(an));
		float t = mod(dot(p - hc, dir) + L * 0.5, gb_period);
		bg = over(stops_b(t), bg);
	}
	vec4 box = bg;
	//BD_FRAGMENT
	if (bw.x + bw.y + bw.z + bw.w > 0.0) {
		vec2 ihc = (size - vec2(bw.y + bw.w, bw.x + bw.z)) * 0.5;
		vec2 ic = vec2(bw.w, bw.x) + ihc;
		float bm = (bw.x + bw.y + bw.z + bw.w) * 0.25;
		float di = sd_box(p - ic, ihc, max(radius - bm, vec4(0.0)));
		float ba = clamp(0.5 + di * px, 0.0, 1.0);
		// which side: the edge this point is furthest past, relative to that edge's width
		float st = (bw.x - p.y) / max(bw.x, 1e-3);
		float sr = (p.x - (size.x - bw.y)) / max(bw.y, 1e-3);
		float sb = (p.y - (size.y - bw.z)) / max(bw.z, 1e-3);
		float sl = (bw.w - p.x) / max(bw.w, 1e-3);
		vec4 bcol = bc_t;
		float m = st;
		if (sr > m) { m = sr; bcol = bc_r; }
		if (sb > m) { m = sb; bcol = bc_b; }
		if (sl > m) { m = sl; bcol = bc_l; }
		box = over(vec4(bcol.rgb, bcol.a * ba), box);
	}
	// inset shadows, last listed at the bottom
	for (int i = 7; i >= 0; i--) {
		if (i >= sh_n || sh_in[i] < 0.5) continue;
		vec4 g = sh_g[i];
		float ds = sd_box(p - hc - g.xy, hc - g.w, max(radius - g.w, vec4(0.0)));
		float a = (1.0 - cover(ds, g.z)) * sh_c[i].a;
		box = over(vec4(sh_c[i].rgb, a), box);
	}
	box.a *= inside;
	col = over(box, col);
	COLOR = col * COLOR;
}
