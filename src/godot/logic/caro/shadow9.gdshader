shader_type canvas_item;
// bóng đổ mềm của đồ vật: lấy alpha ở mipmap thấp (mờ), tô màu bóng
uniform sampler2D tex : filter_linear_mipmap;
uniform float lod = 4.0;
uniform float alpha = 0.42;
uniform vec3 col = vec3(0.09, 0.11, 0.18);
void fragment() {
	COLOR = vec4(col, textureLod(tex, UV, lod).a * alpha);
}
