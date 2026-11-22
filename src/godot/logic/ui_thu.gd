extends "res://logic/ui_kbang.gd"
# BẢNG THƯ NHÀ (kU bản web). (bản 491) làm lại trên khung Kho + chip chung (ui_kbang.gd), không tab:
#  - lá thư: nền giấy thư (vạch kẻ mờ), đầu thư có mặt người gửi + "Thư của …", lời thư;
#  - thư gửi tiền / gửi gạch: chip quà kèm (hình + số), nút Nhận;
#  - thư nhờ gửi đồ quê: chip món (có / cần) + chip tiền cước, nút Gửi đi (thiếu: chip đỏ "Thiếu N") + Để dành; thư hẹn (để dành) chỉ còn Gửi;
#  - dưới: Thư cũ (g.thu.lg, w_thu.gd ghi lúc nhận / gửi).
# Luật ở w_thu.gd (wU).

var TH            # w_thu.gd

const THC := {   # màu riêng: giấy thư
	"paper": ["rgb(255, 253, 244)", "rgb(255, 251, 238)", "rgb(252, 247, 230)", "rgb(206, 186, 140)"],
}
func _ck(kind: String) -> Array:
	return THC[kind] if THC.has(kind) else super(kind)

func _init(ui, wth) -> void:
	super(ui)
	TH = wth

func open() -> void:
	on = true
	scroll = 0.0
	sig = ""
	_build()

func _sig() -> String:
	var t: Dictionary = TH.Eg()
	var a = t.get("un")
	var o = t.get("rq")
	return JSON.stringify([t, _barn(a.id) if a is Dictionary and a.has("id") else 0, _barn(o.id) if o is Dictionary else 0])

func _face(who: String) -> String:   # mặt người gửi theo tên
	return "pic:res://ui/img/vlface/" + str(maxi(0, TH.XN.find(who)) % 8) + ".webp"

static func _body(who: String, txt: String) -> String:   # lời thư: bỏ "Út Mến viết: " (đầu thư đã ghi tên) và ngoặc kép
	var k := txt.find(": \"")
	if txt.begins_with(who) and k > 0:
		txt = txt.substr(k + 3)
		if txt.ends_with("\""):
			txt = txt.substr(0, txt.length() - 1)
	return txt

func _letter(y: float, who: String, head: String, txt: String) -> Array:   # lá thư: đầu thư (mặt, tên) + lời thư trên giấy kẻ
	var out := []
	txt = _body(who, txt)
	var P := _para(X0 + 14.0, 0.0, XW - 28.0, txt, 11.0, 600, BROWN, 17.0)
	var h := 52.0 + float(P[1]) + 12.0
	out.append(_chip(X0, y, XW, h, "paper"))
	out.append(_icx(X0 + 26.0, y + 24.0, 30.0, _face(who)))
	out.append(_dt(X0 + 48.0, y + 9.0, XW - 60.0, 16.0, "Thư của " + who, 12.0, 800, BROWN, "left"))
	out.append(_dt(X0 + 48.0, y + 25.0, XW - 60.0, 14.0, head, 10.0, 600, SUB, "left"))
	out.append(_dbx(X0 + 12.0, y + 46.0, XW - 24.0, 1.0, "rgb(222, 204, 164)", 0.0))
	var ty := y + 52.0
	for i in int(round(float(P[1]) / 17.0)):   # vạch kẻ giấy dưới mỗi dòng
		out.append(_dbx(X0 + 12.0, ty + (i + 1) * 17.0 - 1.0, XW - 24.0, 1.0, "rgba(150, 170, 200, 0.28)", 0.0))
	for n in P[0]:
		n.r[1] = float(n.r[1]) + ty
		out.append(n)
	return [out, h]

func _gift(y: float, ic: String, t: String, s: String) -> Array:   # chip quà kèm thư: hình, số, dòng phụ
	var c := _chip(X0, y, XW, 44.0, "now")
	c.kids = [_icx(X0 + 26.0, y + 22.0, 30.0, ic), _dt(X0 + 48.0, y + 6.0, XW - 60.0, 18.0, t, 13.0, 800, BROWN, "left"),
		_dt(X0 + 48.0, y + 24.0, XW - 60.0, 14.0, s, 10.0, 600, SUB, "left")]
	return [[c], 44.0]

func _send(y: float, id: String, q: int, xu: int, cb: Callable, de) -> Array:   # món cần gửi + tiền cước, hàng nút
	var out := []
	var hv := _barn(id)
	var lw := floorf((XW - 6.0) * 0.55)
	var nd := _nchips(X0, y, lw, [[id, G.item_name(id), hv, q]])
	nd[0][0].r[2] = lw   # chip món giãn đủ nửa trái, sát chip tiền cước
	out.append_array(nd[0])
	var rx := X0 + lw + 6.0
	var rw := XW - lw - 6.0
	var c := _chip(rx, y, rw, 34.0, "now")
	c.kids = [_icx(rx + 18.0, y + 17.0, 24.0, "xu"), _dt(rx + 34.0, y + 3.0, rw - 38.0, 14.0, "Tiền cước", 10.0, 700, SUB, "left"),
		_dt(rx + 34.0, y + 17.0, rw - 38.0, 14.0, "+" + G.fmt_n(xu) + " xu", 10.5, 800, "rgb(150, 90, 10)", "left")]
	out.append(c)
	y += 34.0 + GG
	var bw := XW if de == null else floorf((XW - 6.0) * 0.6)
	if hv >= q:
		out.append(_btn(X0, y, bw, 32.0, "Gửi đi", cb, "go"))
	else:   # thiếu: chip đỏ, không bấm
		var m := _chip(X0, y, bw, 32.0, "sen")
		m.kids = [_dt(X0, y, bw, 32.0, "Thiếu " + G.fmt_n(q - hv) + " " + G.item_name(id).to_lower(), 11.0, 800, "rgb(190, 50, 60)")]
		m.act = _dsay.bind("Kho có " + G.fmt_n(hv) + ", cần " + G.fmt_n(q) + ". Để dành rồi gửi sau khi đủ.")
		out.append(m)
	if de != null:
		var dx := X0 + bw + 6.0
		var dw := XW - bw - 6.0
		var d := _chip(dx, y, dw, 32.0, "fut")
		d.kids = [_dt(dx, y, dw, 32.0, "Để dành", 11.0, 700, BROWN)]
		d.act = de
		out.append(d)
	y += 32.0
	return [out, y]

func _old(y: float, t: Dictionary) -> Array:   # Thư cũ: mỗi lá một dòng
	var out := []
	var L: Array = t.get("lg", []) if t.get("lg") is Array else []
	out.append_array(_sect(y, "Thư cũ", "rgb(96, 146, 196)"))
	y += 16.0 + GG
	if L.is_empty():
		out.append(_dt(X0 + 2.0, y, XW, 14.0, "Chưa có lá thư nào. Ông đưa thư ghé khoảng 9–12 giờ.", 10.5, 600, SUB, "left"))
		return [out, y + 14.0]
	var day: int = G.w_all.WL._vr()
	for r in L.slice(0, 6):
		var c := _chip(X0, y, XW, 30.0, "fut")
		var ago: int = day - int(r.get("d", day))
		var dn := "hôm nay" if ago <= 0 else ("hôm qua" if ago == 1 else str(ago) + " ngày trước")
		var nw: float = Box.text_w(String(r.w), 10.5, 800) + 4.0
		c.kids = [_icx(X0 + 16.0, y + 15.0, 20.0, _face(String(r.w))), _dt(X0 + 32.0, y, nw, 30.0, String(r.w), 10.5, 800, BROWN, "left"),
			_dt(X0 + 32.0 + nw + 2.0, y, 90.0, 30.0, "· " + dn, 10.0, 600, SUB, "left"),
			_dt(X0 + 150.0, y, XW - 158.0, 30.0, _fitw(String(r.s), 10.0, 700, XW - 158.0), 10.0, 700, SUB, "right")]
		out.append(c)
		y += 30.0 + 4.0
	return [out, y - 4.0]

func _build() -> void:   # kU
	sig = _sig()
	var t: Dictionary = TH.Eg()
	var a = t.get("un")
	var out := []
	var y := 6.0
	if a is Dictionary:
		var hd := "Từ Sài Gòn gửi về · hôm nay" if a.k == "tien" else ("Nhờ gửi đồ quê" if a.k == "nho" else "Thư thăm nhà")
		var L := _letter(y, String(a.who), hd, String(a.txt))
		out.append_array(L[0])
		y += float(L[1]) + GG
		if a.k == "tien" or a.k == "tin":
			var G0 := _gift(y, "xu", "+" + G.fmt_n(int(a.xu)) + " xu", "Tiền gửi kèm thư") if a.k == "tien" else _gift(y, "svg:res://ui/svg/mat/gach.svg", "+" + str(int(a.gach)) + " viên gạch", "Gạch nung gửi kèm, để sửa nhà")
			out.append_array(G0[0])
			y += float(G0[1]) + GG
			out.append(_btn(X0, y, XW, 32.0, "Nhận", TH.wU.bind("nhan"), "go"))
			y += 32.0
		else:
			var S := _send(y, String(a.id), int(a.q), int(a.xu), TH.wU.bind("gui"), TH.wU.bind("de"))
			out.append_array(S[0])
			y = float(S[1]) + 6.0
			out.append(_dt(X0 + 2.0, y, XW, 14.0, "Để dành thì chạm hộp thư trước nhà để mở lại.", 10.0, 600, SUB, "left"))
			y += 14.0
	elif t.get("rq") is Dictionary:
		var o: Dictionary = t.rq
		var L2 := _letter(y, String(o.who), "Thư hẹn gửi đồ quê", "Còn hẹn gửi " + G.w_all.WC.ho(String(o.id), int(o.q)) + " cho " + String(o.who) + ". Đủ hàng là gửi được.")
		out.append_array(L2[0])
		y += float(L2[1]) + GG
		var S2 := _send(y, String(o.id), int(o.q), int(o.xu), TH.wU.bind("gui2"), null)
		out.append_array(S2[0])
		y = float(S2[1])
	else:
		close()
		return
	y += GG + 6.0
	var R := _old(y, t)
	out.append_array(R[0])
	y = float(R[1]) + GG
	var sh := _kshell([], "", func(_k): pass)
	_kmount(sh[0], sh[1], float(sh[2]), out, y)
