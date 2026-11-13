// mưa: vòng gợn trên mặt nước, chép web nuocgl (rain rings, flat on the ground = iso ellipses in tile space)
// uRain = lượng mưa (web oj: mưa .7, giông 1) x độ zoom (web zf = smoothstep(.3,.75,zoom)), main.gd đặt
uniform float uRain = 0.0;
float rh21(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float rain_rings(vec2 w) {
	if (uRain <= 0.0) return 0.0;
	vec2 d = w - vec2(4268.0, 968.0);
	float ga = d.x / 32.0, gb = d.y / 16.0;
	vec2 g = vec2((ga + gb) * 0.5, (gb - ga) * 0.5) * 3.0;
	float tt = TIME, rr = 0.0;
	for (int j = 0; j < 2; j++) {
		vec2 off = vec2(float(j) * 0.5);
		vec2 c2 = floor(g + off), ff = fract(g + off);
		vec2 c0 = 0.5 + (vec2(rh21(c2), rh21(c2 + 7.1)) - 0.5) * 0.5;
		float ph = fract(tt * 0.9 + rh21(c2 + 3.3));
		float dd = length(ff - c0);
		rr += smoothstep(0.06, 0.0, abs(dd - ph * 0.42)) * (1.0 - ph) * step(0.3, rh21(c2 + 1.7));
	}
	return min(rr * uRain, 1.0);
}
