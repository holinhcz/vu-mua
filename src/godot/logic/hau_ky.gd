extends CanvasLayer
# LỚP CHỈNH MÀU THEO GIỜ (đợt 1 hiệu ứng trời): một lượt xử lý toàn màn trên hình làng (dưới giao diện), thay tấm phủ
# hồng / cam và màu đêm cũ. Chỉ bật ở Chất lượng hình Cân bằng / Nét (G.fx_new); Tiết kiệm giữ kiểu cũ (ảnh đêm, phủ màu).
# Mốc theo giờ, nội suy liền mạch từng phút: [giờ, phơi sáng, độ rực, tương phản, màu chỗ tối, màu chỗ sáng, tối góc, sương].

const K := [
	[0.0, 0.52, 0.48, 1.06, Vector3(0.56, 0.70, 1.28), Vector3(0.78, 0.88, 1.20), 0.38, 0.0],
	[4.5, 0.52, 0.48, 1.06, Vector3(0.56, 0.70, 1.28), Vector3(0.78, 0.88, 1.20), 0.38, 0.0],
	[5.5, 0.72, 0.72, 1.00, Vector3(0.74, 0.76, 1.12), Vector3(1.08, 0.90, 0.94), 0.30, 0.28],
	[6.5, 0.90, 0.90, 1.00, Vector3(0.88, 0.88, 1.05), Vector3(1.10, 0.98, 0.93), 0.22, 0.18],
	[8.0, 1.00, 1.00, 1.00, Vector3(1.00, 1.00, 1.00), Vector3(1.00, 1.00, 1.00), 0.10, 0.0],
	[12.0, 1.04, 1.08, 1.06, Vector3(0.97, 0.98, 1.03), Vector3(1.04, 1.02, 0.97), 0.08, 0.0],
	[15.5, 1.00, 1.04, 1.03, Vector3(0.98, 0.98, 1.00), Vector3(1.05, 1.00, 0.93), 0.12, 0.0],
	[17.3, 0.97, 1.12, 1.05, Vector3(0.86, 0.78, 0.95), Vector3(1.17, 0.98, 0.76), 0.24, 0.0],
	[18.4, 0.82, 1.02, 1.04, Vector3(0.70, 0.64, 0.95), Vector3(1.16, 0.82, 0.66), 0.32, 0.0],
	[19.5, 0.62, 0.76, 1.04, Vector3(0.62, 0.68, 1.08), Vector3(0.95, 0.86, 0.96), 0.36, 0.0],
	[20.5, 0.52, 0.48, 1.06, Vector3(0.56, 0.70, 1.28), Vector3(0.78, 0.88, 1.20), 0.38, 0.0],
	[24.0, 0.52, 0.48, 1.06, Vector3(0.56, 0.70, 1.28), Vector3(0.78, 0.88, 1.20), 0.38, 0.0]]

var G
var main
var rect: ColorRect
var mat: ShaderMaterial
var t := 0.0

func _init(g, m) -> void:
	G = g
	main = m
	layer = 6   # trên làng và mưa / lá bay (lớp 5), dưới giao diện (lớp 10)
	rect = ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	mat = ShaderMaterial.new()
	mat.shader = load("res://logic/hau_ky.gdshader")
	rect.material = mat
	add_child(rect)

func _process(dt: float) -> void:
	t += dt
	var on: bool = G.fx_new() and G.troi != null
	visible = on
	if not on:
		return
	var h: float = float(G.troi.dh().h)
	var i := 0
	while i < K.size() - 2 and h >= float(K[i + 1][0]):
		i += 1
	var a: Array = K[i]
	var b: Array = K[i + 1]
	var u := clampf((h - float(a[0])) / maxf(0.001, float(b[0]) - float(a[0])), 0.0, 1.0)
	u = u * u * (3.0 - 2.0 * u)
	mat.set_shader_parameter("uExp", lerpf(a[1], b[1], u))
	mat.set_shader_parameter("uSat", lerpf(a[2], b[2], u))
	mat.set_shader_parameter("uCon", lerpf(a[3], b[3], u))
	mat.set_shader_parameter("uSh", (a[4] as Vector3).lerp(b[4], u))
	var hi: Vector3 = (a[5] as Vector3).lerp(b[5], u)
	mat.set_shader_parameter("uHi", hi)
	mat.set_shader_parameter("uVig", lerpf(a[6], b[6], u))
	mat.set_shader_parameter("uFog", lerpf(a[7], b[7], u))
	mat.set_shader_parameter("uFogC", Vector3(0.93, 0.9, 0.95).lerp(hi * 0.85, 0.3))
	mat.set_shader_parameter("uCam", main.cam)
	mat.set_shader_parameter("uZoom", main.zoom)
	mat.set_shader_parameter("uT", 0.0 if G.motion_off() else t)
