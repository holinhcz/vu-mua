extends RefCounted
# KHUNG TRE CHUNG BẰNG ẢNH (bản 294): 4 góc cong + 4 cạnh lặp theo đốt (ui/img/tre, vẽ bằng tools/tre/lam.py).
# Góc và cạnh cùng một mặt cắt cây tre (dày T, bóng S vào lòng) nên nối liền; nền hộp bo đúng R nên không lòi viền.
# Snap.build gọi frame() cho mọi .u2tre (Kho, bảng tre, hộp nổi): một khung cho cả game.
const T := 7.0     # dày tre (css px)
const S := 3.0     # bóng đổ vào lòng bảng
const R := 16.0    # bo góc ngoài = bo góc nền hộp
const L := 48.0    # dài một đốt (một mắt tre)
const D := "res://ui/img/tre/"

static func _p(name: String, x: float, y: float, w: float, h: float, z: float) -> Dictionary:
	return {"tag": "i", "id": "", "cls": "tre-" + name, "z": z, "css": {"position": "absolute"}, "r": [x, y, w, h], "kids": [], "pic": D + name + ".png"}

static func frame(r: Array, z: float) -> Array:   # các mảnh khung quanh hộp r (khung tràn ra 1 px để phủ kín mép nền)
	var x: float = float(r[0]) - 1.0
	var y: float = float(r[1]) - 1.0
	var w: float = float(r[2]) + 2.0
	var h: float = float(r[3]) + 2.0
	var o := [_p("goc_tt", x, y, R, R, z), _p("goc_tp", x + w - R, y, R, R, z), _p("goc_dt", x, y + h - R, R, R, z), _p("goc_dp", x + w - R, y + h - R, R, R, z)]
	var e := T + S
	var sw: float = w - 2.0 * R
	var n := maxi(1, int(round(sw / L)))
	var tw: float = sw / n
	for i in n:
		o.append(_p("canh_tren", x + R + i * tw, y, tw, e, z))
		o.append(_p("canh_duoi", x + R + i * tw, y + h - e, tw, e, z))
	var sh: float = h - 2.0 * R
	n = maxi(1, int(round(sh / L)))
	var th: float = sh / n
	for i in n:
		o.append(_p("canh_trai", x, y + R + i * th, e, th, z))
		o.append(_p("canh_phai", x + w - e, y + R + i * th, e, th, z))
	return o
