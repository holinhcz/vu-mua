extends "res://logic/ui_bang.gd"
# HỘP NỔI .lvov.ngov > .hxwrap.tre-ov bản web (Điểm danh, 7 ngày về làng): khung tre giữa màn, nút × góc phải, nút ? góc trái
# (mở hộp giải thích với chữ đầu hộp .hxhd bị ẩn), hàng tab tre (tùy), thân .hxbody cuộn được: cao theo nội dung, tối đa BMAX.
# Bấm ra ngoài khung thì đóng. Mẫu lấy từ bản chụp web của từng bảng (khung đặt sẵn ở vị trí chụp, nội dung xếp từ đầu thân).

var BMAX := 318.0          # .hxbody cao tối đa (màn 610)
var help := ["", ""]       # [tiêu đề, chữ] của nút ?

# ov: bản chụp .lvov (đã chép); kids: khối trong thân, tọa độ tính từ đỉnh thân của mẫu; ch: cao nội dung thân (gồm lề)
func _hx(ov: Dictionary, kids: Array, ch: float) -> void:
	var wr := _find(ov, "hxwrap")
	var bd := _find(ov, "hxbody")
	var bh := minf(ch, BMAX)
	var dh := bh - float(bd.r[3])
	var H := float(wr.r[3]) + dh
	var dy := (610.0 - H) * 0.5 - float(wr.r[1])
	bd.r[3] = bh
	var hin := _find(wr, "hxin")
	if not hin.is_empty():
		hin.r[3] = float(hin.r[3]) + dh
	wr.r[3] = H
	Snap._move(wr, Vector2(0, dy))
	for k in kids:
		Snap._move(k, Vector2(0, dy))
	_tre_box(wr)
	_mount(_ovl(ov), bd, kids, float(bd.r[1]), ch)
	_wire_ov(".hxwrap")

func _tre_box(wr: Dictionary) -> void:   # khung tre đè lên mép hộp, nút × và ? (z-index 40) nằm trên khung
	var top: Array = wr.kids.filter(func(k): return String(k.cls).begins_with("ngx") or String(k.cls).begins_with("treq"))
	wr.kids = wr.kids.filter(func(k): return not top.has(k)) + [tre_frame(float(wr.r[0]), float(wr.r[1]), float(wr.r[2]), float(wr.r[3]))] + top

var _wsel := ".hxwrap"
func _wire_ov(wsel: String) -> void:   # nút ×, nút ?, bấm ra ngoài hộp wsel thì đóng
	_wsel = wsel
	U._click(ids.get(".ngx"), close, "scale")
	U._click(ids.get(".treq"), func(): U.tre_help(help[0], help[1]), "scale")
	var o = ids.get(".lvov")
	if o != null:
		U._stop(o)
		o.gui_input.connect(_ov_tap.bind(o))
	var w = ids.get(wsel)
	if w != null:
		U._stop(w)
	U._layout()

func _ov_tap(e: InputEvent, ov: Control) -> void:   # bấm ra ngoài khung thì đóng
	var w = ids.get(_wsel)
	if U._is_tap_down(e) and w != null and not w.get_global_rect().has_point(ov.global_position + e.position):
		close()

func step(dt: float) -> void:   # dựng lại mỗi giây khi trạng thái đổi
	if not on:
		return
	_sig_t -= dt
	if _sig_t > 0.0:
		return
	_sig_t = 1.0
	if _sig() != sig:
		_build()

func _sig() -> String:
	return ""

# chữ một dòng: đặt chữ mới, giữ mép trái (al = "left") hoặc giữa (al = "center"). Ô rộng hơn chữ (nút, khối) thì giữ ô,
# chỉ dời khung chữ trong ô.
func _set_txt(n: Dictionary, s: String, al := "left") -> void:
	var w := _tw(n, s)
	n.text = s
	var box: bool = n.has("tr") and float(n.r[2]) > float(n.tr[2]) + 1.0
	var R: Array = n.tr if box else n.r
	var x := float(R[0]) if al == "left" else float(R[0]) + (float(R[2]) - w) * 0.5
	if box:
		if al == "center":
			x = float(n.r[0]) + (float(n.r[2]) - w) * 0.5
		n.tr = [x, n.tr[1], w, n.tr[3]]
		return
	n.r = [x, n.r[1], w, n.r[3]]
	if n.has("tr"):
		n.tr = [x, n.tr[1], w, n.tr[3]]
