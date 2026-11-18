extends RefCounted
# SỐ "CÓ/CẦN" + Ô GIÁ DÙNG CHUNG (bản 291). Mọi chỗ hiện số món có/cần (bảng nâng sao ruộng / chuồng / xưởng / kho,
# đơn hàng, Nghề, Sổ làng, chợ nổi, câu cá) đều lấy chữ, cỡ, độ đậm, màu và kích thước ô ở đây:
#   một chữ "43/2" liền một khối, cùng cỡ cùng đậm; kho đủ hoặc dư -> xanh, thiếu -> đỏ.
#   ô giá: [hình ICON][GAP][chữ], đệm PAD hai bên, rộng theo chữ (tối thiểu MINW); hàng ô canh giữa, chật thì xuống hàng.

const Snap = preload("res://ui/snap.gd")

const FS := 14.0            # cỡ chữ (css px)
const FW := 700             # độ đậm
const OK := "rgb(35, 160, 74)"
const NO := "rgb(224, 72, 62)"
const OK_D := "rgb(155, 229, 143)"   # nền tối (thẻ món xưởng): xanh / đỏ sáng cho đọc được
const NO_D := "rgb(255, 143, 128)"
const ICON := 22.0          # hình món / xu trong ô giá
const GAP := 4.0            # hình -> chữ
const PAD := 6.0            # đệm trái / phải ô
const MINW := 54.0          # ô giá hẹp nhất
const H := 34.0             # cao ô giá
const SEP := 5.0            # khoảng giữa các ô
const DY := 1.2             # (bản 301) chữ số không có dấu / đuôi: hộp chữ canh theo cỡ chữ làm số nằm cao hơn tên món và dấu
                            # tích ~1,2 css px -> hạ xuống cho thẳng hàng giữa

static func down(n: Dictionary) -> void:   # hạ hộp chữ số có/cần DY cho thẳng hàng giữa với tên món, hình, dấu tích
	if n.has("tr"):
		n.tr = [n.tr[0], float(n.tr[1]) + DY, n.tr[2], n.tr[3]]
	else:
		n.r = [n.r[0], float(n.r[1]) + DY, n.r[2], n.r[3]]

static func text(have: int, need: int) -> String:
	return str(have) + "/" + str(need)

static func css(c: Dictionary, ok: bool, dark := false) -> Dictionary:   # css chữ số (bản chụp): cỡ / đậm / màu chung
	var o := c.duplicate()
	o["font-size"] = str(FS) + "px"
	o["font-weight"] = str(FW)
	o["color"] = (OK_D if ok else NO_D) if dark else (OK if ok else NO)
	o["white-space"] = "nowrap"
	return o

static func color(ok: bool) -> Color:   # cho bảng dựng bằng khối Godot (Label)
	return Color8(35, 160, 74) if ok else Color8(224, 72, 62)

static func chip_w(text_w: float) -> float:
	return maxf(MINW, PAD * 2.0 + ICON + GAP + text_w)

static func row(box: Dictionary, chips: Array) -> void:   # xếp ô giá trong box: canh giữa, chật thì xuống hàng; box cao theo
	var lines := [[]]
	var w := 0.0
	var bw: float = float(box.r[2])
	for c in chips:
		var cw: float = float(c.r[2])
		if not lines[-1].is_empty() and w + SEP + cw > bw:
			lines.append([])
			w = 0.0
		w += (SEP if not lines[-1].is_empty() else 0.0) + cw
		lines[-1].append(c)
	var y: float = float(box.r[1])
	for L in lines:
		var tot := 0.0
		for c in L:
			tot += float(c.r[2])
		tot += SEP * (L.size() - 1)
		var x: float = float(box.r[0]) + (bw - tot) * 0.5
		for c in L:
			Snap._move(c, Vector2(x - float(c.r[0]), y - float(c.r[1])))
			x += float(c.r[2]) + SEP
		y += H + SEP
	box.kids = chips
	box.r = [box.r[0], box.r[1], box.r[2], lines.size() * H + (lines.size() - 1) * SEP]
