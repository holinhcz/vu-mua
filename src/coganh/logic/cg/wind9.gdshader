shader_type canvas_item;
// gió cho tán cây/bụi chuối/bóng: lắc theo khoảng cách tới gốc + lá rung từng chỗ + ánh nắng lấp lánh
uniform sampler2D noise : filter_linear, repeat_enable;
uniform sampler2D tex : filter_linear_mipmap;
uniform vec2 tex_size = vec2(512.0);
uniform vec2 pivot = vec2(0.0);      // gốc cây theo pixel của ảnh
uniform float reach = 600.0;
uniform float amp = 6.0;            // biên độ lắc cả cành (px)
uniform float flutter = 2.0;        // lá rung (px)
uniform float bend = 0.0;           // xoay quanh gốc (radian) cho chuối
uniform float phase = 0.0;
uniform float glint = 0.1;
uniform float fleck = 0.0;          // đốm nắng chạy trong bóng
uniform float shadow = 0.0;         // >0: vẽ bóng (đậm), mờ bằng mipmap
uniform float lod = 0.0;
uniform float px_scale = 1.0;
uniform vec3 shadow_col = vec3(0.09, 0.11, 0.18);
void fragment() {
	vec2 p = UV * tex_size;
	float d = clamp(length(p - pivot) / reach, 0.0, 1.0);
	float t = TIME;
	float gust = texture(noise, vec2(t * 0.025 + phase, 0.37)).r;
	float g = 0.55 + 0.9 * gust;
	vec2 sway = vec2(sin(t * 0.85 + phase) + 0.35 * sin(t * 2.3 + phase * 1.9),
	                 0.6 * cos(t * 0.65 + phase * 1.3) + 0.25 * sin(t * 1.7 + phase)) * amp * d * d * g;
	vec2 n = texture(noise, p / (160.0 * px_scale) + vec2(t * 0.045, t * 0.03)).rg - 0.5;
	vec2 off = sway + n * flutter * d * g;
	vec2 q = p - off;
	if (bend != 0.0) {
		float a = bend * d * (sin(t * 0.8 + phase) + 0.3 * sin(t * 1.9 + phase)) * g;
		vec2 r = q - pivot;
		q = pivot + vec2(r.x * cos(a) + r.y * sin(a), -r.x * sin(a) + r.y * cos(a));
	}
	vec4 c = shadow > 0.0 ? vec4(shadow_col, textureLod(tex, q / tex_size, lod).a * shadow) : texture(tex, q / tex_size);
	float gl = texture(noise, p / (70.0 * px_scale) + vec2(-t * 0.07, t * 0.05)).b;
	c.rgb *= 1.0 + glint * smoothstep(0.62, 0.78, gl) * d;
	if (fleck > 0.0) {
		float f = texture(noise, p / (55.0 * px_scale) + vec2(t * 0.05, -t * 0.035)).g;
		c.a *= 1.0 - fleck * smoothstep(0.5, 0.8, f);
	}
	COLOR = c;
}
