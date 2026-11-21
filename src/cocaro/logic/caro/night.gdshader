// Cảnh đêm: trăng xanh lạnh ngoài sân, đèn dầu treo trên bàn rọi vàng ấm (Link 11-21 "làm ban đêm")
shader_type canvas_item;
uniform sampler2D S : hint_screen_texture, filter_nearest;
uniform vec2 lamp = vec2(0.5, 0.5);     // tâm đèn (UV màn hình)
uniform float rad = 0.55;               // bán kính quầng đèn theo cạnh ngắn
uniform float aspect = 1.0;             // rộng / cao
uniform float flick = 1.0;              // đèn dầu lập lòe
uniform vec2 lamp2 = vec2(-5.0);         // cây đèn dầu thật (quầng nhỏ quanh đèn)
uniform float rad2 = 0.1;
void fragment() {
	vec3 c = texture(S, SCREEN_UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	vec3 moon = mix(vec3(l), c, 0.45) * vec3(0.40, 0.48, 0.72) + vec3(0.012, 0.020, 0.050);
	vec2 d = (SCREEN_UV - lamp) * vec2(aspect, 1.0) / min(aspect, 1.0);
	float r = length(d) / rad;
	float w = (1.0 - smoothstep(0.62, 1.35, r)) * flick;
	vec3 warm = mix(vec3(l), c, 1.2) * vec3(1.10, 0.98, 0.80);
	warm += vec3(0.05, 0.025, 0.0) * (1.0 - r);
	vec2 d2 = (SCREEN_UV - lamp2) * vec2(aspect, 1.0) / min(aspect, 1.0);
	float r2 = length(d2) / rad2;
	w = max(w, exp(-r2 * r2 * 1.2) * flick);
	vec3 o = mix(moon, warm, clamp(w, 0.0, 1.0));
	COLOR = vec4(clamp(o, 0.0, 1.0), 1.0);
}
