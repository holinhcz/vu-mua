extends CanvasLayer
# LỚP CHỈNH MÀU THEO GIỜ (đợt 1 hiệu ứng trời): một lượt xử lý toàn màn trên hình làng (dưới giao diện), thay tấm phủ
# hồng / cam và màu đêm cũ. Chỉ bật ở Chất lượng hình Cân bằng / Nét (G.fx_new); Tiết kiệm giữ kiểu cũ (ảnh đêm, phủ màu).
# Mốc theo giờ, nội suy liền mạch từng phút: [giờ, phơi sáng, độ rực, tương phản, màu chỗ tối, màu chỗ sáng, tối góc, sương].

const K := [
	[0.0, 0.70, 0.58, 1.03, Vector3(0.68, 0.79, 1.18), Vector3(0.88, 0.96, 1.12), 0.30, 0.0],
	[4.5, 0.70, 0.58, 1.03, Vector3(0.68, 0.79, 1.18), Vector3(0.88, 0.96, 1.12), 0.30, 0.0],
	[5.5, 0.89, 0.89, 1.00, Vector3(0.90, 0.90, 1.05), Vector3(1.03, 0.96, 0.98), 0.15, 0.14],
	[6.5, 0.96, 0.96, 1.00, Vector3(0.95, 0.95, 1.02), Vector3(1.04, 0.99, 0.97), 0.11, 0.09],
	[8.0, 1.00, 1.00, 1.00, Vector3(1.00, 1.00, 1.00), Vector3(1.00, 1.00, 1.00), 0.06, 0.0],
	[12.0, 1.02, 1.03, 1.02, Vector3(0.99, 0.99, 1.01), Vector3(1.02, 1.01, 0.99), 0.06, 0.0],
	[15.5, 1.00, 1.02, 1.01, Vector3(0.99, 0.99, 1.00), Vector3(1.02, 1.00, 0.97), 0.08, 0.0],
	[17.3, 0.99, 1.05, 1.02, Vector3(0.94, 0.91, 0.98), Vector3(1.07, 0.99, 0.90), 0.14, 0.0],
	[18.4, 0.93, 1.01, 1.02, Vector3(0.88, 0.86, 0.98), Vector3(1.06, 0.93, 0.86), 0.18, 0.0],
	[19.5, 0.74, 0.74, 1.03, Vector3(0.70, 0.75, 1.10), Vector3(0.96, 0.89, 0.98), 0.30, 0.0],
	[20.5, 0.70, 0.58, 1.03, Vector3(0.68, 0.79, 1.18), Vector3(0.88, 0.96, 1.12), 0.30, 0.0],
	[24.0, 0.70, 0.58, 1.03, Vector3(0.68, 0.79, 1.18), Vector3(0.88, 0.96, 1.12), 0.30, 0.0]]

var G
var main
var rect: ColorRect
var mat: ShaderMaterial
var t := 0.0
var dem   # dem.gd: bản đồ ánh sáng đèn, đom đóm, sao trên nước

func _init(g, m, f) -> void:
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
	dem = load("res://logic/dem.gd").new(g, f)
	add_child(dem)
	mat.set_shader_parameter("uLight", dem.texture())

func _process(dt: float) -> void:
	t += dt
	var on: bool = G.fx_new() and G.troi != null
	visible = on
	var h: float = float(G.troi.dh().h) if G.troi != null else 12.0
	dem.step(dt, on and int(G.cfg.get("q", 2)) >= 1, h, on and int(G.cfg.get("q", 2)) >= 2)
	if not on:
		return
	var i := 0
	while i < K.size() - 2 and h >= float(K[i + 1][0]):
		i += 1
	var a: Array = K[i]
	var b: Array = K[i + 1]
	var u := clampf((h - float(a[0])) / maxf(0.001, float(b[0]) - float(a[0])), 0.0, 1.0)
	u = u * u * (3.0 - 2.0 * u)
	# trăng: đêm rằm sáng hơn, cuối tháng tối hơn
	mat.set_shader_parameter("uExp", lerpf(a[1], b[1], u) * lerpf(1.0, 0.9 + 0.18 * dem.moon_k(), dem.night_k(h)))
	mat.set_shader_parameter("uNk", dem.nk)
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
