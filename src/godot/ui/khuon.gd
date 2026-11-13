# Khuôn màn hình của bản web (Wi): mỗi màn hình tính riêng độ to giao diện s và kiểu khung.
#   s = chiều cao / 810 (máy cảm ứng: cạnh dài/ngắn của screen), làm tròn 0,05, kẹp 0,7..2
#   co = "lon" khi cạnh ngắn >= 560 css px, không thì "nho"
#   k  = "doc" / "vuong" / "ngang" (điện thoại nằm ngang) / "may" (màn rộng)
# Bản web nhân mọi bảng với s (css zoom: var(--ks)), zoom đầu 0,7·s, zoom tối đa 1,7·s.
# Số đo giao diện (res://ui/snap) chụp trên điện thoại 338x610 nên đã mang sẵn s = 0,75.

const NG := {"co": 560.0, "nhoDoc": 0.8, "nhoVuong": 1.25, "lonDoc": 0.65, "lonVuong": 1.45, "cao": 810.0, "min": 0.7, "max": 2.0}
const S_SNAP := 0.75

static func _js(code: String, dflt):
	if not OS.has_feature("web"):
		return dflt
	var v = JavaScriptBridge.eval(code)
	return dflt if v == null else v

static func coarse() -> bool:
	return bool(_js("!!(window.matchMedia&&matchMedia('(pointer: coarse)').matches)", false))

# W, H: khổ cửa sổ css px (innerWidth/innerHeight)
static func tinh(W: float, H: float) -> Dictionary:
	W = maxf(1.0, W)
	H = maxf(1.0, H)
	var ft := coarse()
	var j := W / H
	var co := "lon" if minf(W, H) >= NG.co else "nho"
	var k := ""
	if co == "nho":
		k = "doc" if j < NG.nhoDoc else ("vuong" if j <= NG.nhoVuong else ("ngang" if ft else "may"))
	else:
		k = "doc" if j < NG.lonDoc else ("vuong" if j <= NG.lonVuong else "may")
	# a(): máy cảm ứng lấy screen (bàn phím ảo không làm đổi độ to), máy thường lấy chiều cao cửa sổ
	var a := H
	if ft:
		var sw := float(_js("screen.width||0", 0))
		var sh := float(_js("screen.height||0", 0))
		if sw > 0.0 and sh > 0.0:
			a = minf(sw, sh) if W > H else maxf(sw, sh)
	var s := a / NG.cao
	s = round(s * 20.0) / 20.0
	s = clampf(s, NG.min, NG.max)
	return {"k": k, "co": co, "r": j, "s": s}
