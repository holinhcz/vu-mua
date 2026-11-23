// Chỉnh màu cả cảnh + quân (dưới thẻ, chữ): nắng trưa ấm, tươi hơn, bớt đù (Link 11-21 "nhìn cứ đù đù")
shader_type canvas_item;
uniform sampler2D S : hint_screen_texture, filter_nearest;
uniform float sat = 1.25;
uniform float con = 1.10;
uniform vec3 gain = vec3(1.10, 1.05, 0.96);
uniform float lift = 0.02;
void fragment() {
	vec3 c = texture(S, SCREEN_UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, sat);
	c = (c - 0.5) * con + 0.5;
	c = c * gain + lift;
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
