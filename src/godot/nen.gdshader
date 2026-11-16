shader_type canvas_item;
#include "res://night.gdshaderinc"
// Nền đất người chơi lát (bản 225): mỗi điểm ảnh tính độ đậm của từng loại nền theo khoảng cách tới các ô quanh nó (3x3 ô),
// nên chỗ hai loại giáp nhau chuyển màu mềm (ở cạnh 50/50), mép giáp cỏ nhạt dần, góc ngã ba ngã tư tròn đều, không có dải
// thẳng. Ảnh: đúng ảnh mặt đường của làng (lớp uRA của nền: 0 đất, 1 đất đỏ, 2 cát, 3 sỏi), cùng cỡ lặp như đường.
uniform sampler2DArray uRA : repeat_enable, filter_linear_mipmap;
uniform sampler2D uMap : filter_nearest;   // ô (x - uBox.x, y - uBox.y): R = lớp ảnh + 1 (0 = không lát)
uniform vec4 uBox;                          // ô đầu (x, y), cỡ (w, h)
uniform float uB = 0.45;                    // bề rộng loang (đơn vị ô)
varying vec2 wp;

void vertex() {
	wp = VERTEX;
}

int kind(ivec2 t) {
	ivec2 q = t - ivec2(uBox.xy);
	if (q.x < 0 || q.y < 0 || q.x >= int(uBox.z) || q.y >= int(uBox.w)) return 0;
	return int(texelFetch(uMap, q, 0).r * 255.0 + 0.5);
}

vec3 pic(int k) {
	int l = k - 1;
	return texture(uRA, vec3(wp / (l == 3 ? 96.0 : 112.0), float(l))).rgb;
}

void fragment() {
	// toạ độ làng -> toạ độ ô liên tục: ô (e, r) chiếm [e, e+1] x [r, r+1]
	float u = (wp.x - 4268.0) / 32.0;
	float v = (wp.y - 968.0) / 16.0;
	vec2 t = vec2((u + v) * 0.5, (v - u) * 0.5);
	ivec2 ti = ivec2(floor(t));
	float W[5];
	for (int i = 0; i < 5; i++) W[i] = 0.0;
	for (int dy = -1; dy <= 1; dy++) {
		for (int dx = -1; dx <= 1; dx++) {
			ivec2 c = ti + ivec2(dx, dy);
			int k = kind(c);
			if (k <= 0 || k > 4) continue;
			vec2 d = max(abs(t - (vec2(c) + 0.5)) - 0.5, 0.0);   // khoảng cách tới ô đó (0 = ở trong)
			float w = 1.0 - smoothstep(0.0, uB, length(d));
			W[k] = max(W[k], w);
		}
	}
	float s = W[1] + W[2] + W[3] + W[4];
	if (s <= 0.0001) discard;
	vec3 col = vec3(0.0);
	for (int k = 1; k <= 4; k++) {
		if (W[k] > 0.0) col += pic(k) * W[k];
	}
	col /= s;
	float a = max(max(W[1], W[2]), max(W[3], W[4]));
	COLOR = vec4(night_col(col), a);
}
