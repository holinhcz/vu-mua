shader_type canvas_item;
render_mode unshaded;
// LỚP CHỈNH MÀU theo giờ (hau_ky.gd): đọc hình làng đã vẽ, phơi sáng, màu riêng chỗ tối / chỗ sáng, độ rực, tương phản,
// sương sớm trôi theo làng (toạ độ làng, đi theo khi kéo), tối 4 góc.
uniform sampler2D SCR : hint_screen_texture, filter_linear;
uniform float uExp = 1.0;
uniform float uSat = 1.0;
uniform float uCon = 1.0;
uniform float uVig = 0.0;
uniform float uFog = 0.0;
uniform vec3 uSh = vec3(1.0);
uniform vec3 uHi = vec3(1.0);
uniform vec3 uFogC = vec3(1.0);
uniform vec2 uCam = vec2(0.0);
uniform float uZoom = 1.0;
uniform float uT = 0.0;

float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) {
	float a = 0.5, s = 0.0;
	for (int k = 0; k < 4; k++) { s += a * vn(p); p = p * 2.03 + vec2(17.1, 9.3); a *= 0.5; }
	return s;
}
void fragment() {
	vec3 c = texture(SCR, SCREEN_UV).rgb;
	float L = dot(c, vec3(0.299, 0.587, 0.114));
	c *= mix(uSh, uHi, smoothstep(0.08, 0.85, L)) * uExp;
	float L2 = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(L2), c, uSat);
	c = (c - 0.5) * uCon + 0.5;
	if (uFog > 0.001) {
		vec2 w = uCam + FRAGCOORD.xy / uZoom;
		float n = fbm(w * vec2(0.0035, 0.007) + vec2(uT * 0.012, uT * 0.004));
		c = mix(c, uFogC, uFog * smoothstep(0.38, 0.8, n));
	}
	vec2 q = SCREEN_UV - 0.5;
	c *= 1.0 - uVig * smoothstep(0.15, 0.75, dot(q, q) * 2.2);
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
