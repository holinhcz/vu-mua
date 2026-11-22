extends "res://logic/ui_kbang.gd"
# BẢNG THƯ NHÀ (kU bản web). (bản 491) khung Kho + chip chung (ui_kbang.gd), không tab; (bản 492) khung co vừa nội dung (fit):
#  - lá thư: giấy vở (vạch kẻ, lề đỏ), đầu thư mặt người gửi (ảnh tròn vlface/m*.webp) + "Thư của …" + nơi gửi, ký tên cuối thư;
#  - thư gửi tiền / gửi gạch: chip quà kèm (xanh), nút Nhận;
#  - thư nhờ gửi đồ quê: chip món (có / cần) sát chip tiền cước (xanh), đủ hàng: Gửi đi + Để dành, thiếu: dòng chỗ kiếm (G.where) + Để dành;
#    thư hẹn (để dành): một dòng đầu thư, không giấy;
#  - dưới: Thư cũ (g.thu.lg, w_thu.gd ghi lúc nhận / gửi): tên, ngày, kết quả có hình + màu theo loại.
# Luật ở w_thu.gd (wU).

var TH            # w_thu.gd

const THC := {   # màu riêng: giấy thư
	"paper": ["rgb(255, 254, 248)", "rgb(255, 253, 244)", "rgb(253, 250, 238)", "rgb(196, 178, 136)"],
}
const LGC := {"tien": "rgb(200, 120, 20)", "tin": "rgb(170, 80, 50)", "nho": "rgb(46, 130, 60)"}   # màu kết quả Thư cũ

func _ck(kind: String) -> Array:
	return THC[kind] if THC.has(kind) else super(kind)

func _init(ui, wth) -> void:
	super(ui)
	TH = wth
	fit = true

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

func _face(who: String) -> String:   # mặt người gửi (ảnh tròn đầu + vai) theo tên
	return "pic:res://ui/img/vlface/m" + str(maxi(0, TH.XN.find(who)) % 8) + ".webp"

static func _body(who: String, txt: String) -> String:   # lời thư: bỏ "Út Mến viết: " (đầu thư đã ghi tên) và ngoặc kép
	var k := txt.find(": \"")
	if txt.begins_with(who) and k > 0:
		txt = txt.substr(k + 3)
		if txt.ends_with("\""):
			txt = txt.substr(0, txt.length() - 1)
	return txt

func _head(x: float, y: float, w: float, who: String, t: String, s: String) -> Array:   # đầu thư: mặt tròn, tên đậm, dòng phụ
	return [_icx(x + 18.0, y + 18.0, 34.0, _face(who)), _dt(x + 42.0, y + 2.0, w - 46.0, 16.0, t, 12.0, 800, BROWN, "left"),
		_dt(x + 42.0, y + 19.0, w - 46.0, 14.0, s, 10.0, 600, SUB, "left")]

func _letter(y: float, who: String, txt: String, noi: String) -> Array:   # lá thư giấy vở: đầu thư, vạch kẻ, lề đỏ, ký tên
	var out := []
	txt = _body(who, txt)
	var lh := 18.0
	var tx := X0 + 34.0
	var P := _para(tx, 0.0, XW - 46.0, txt, 11.0, 600, BROWN, lh)
	var nl := int(round(float(P[1]) / lh)) + 1   # thêm 1 dòng ký tên
	var ty := y + 50.0
	var h := 50.0 + nl * lh + 10.0
	out.append(_chip(X0, y, XW, h, "paper"))
	out.append_array(_head(X0 + 8.0, y + 7.0, XW - 16.0, who, "Thư của " + who, noi + " · hôm nay"))
	for i in nl:   # vạch kẻ dưới mỗi dòng
		out.append(_dbx(X0 + 8.0, ty + (i + 1) * lh - 2.0, XW - 16.0, 1.0, "rgba(110, 140, 190, 0.45)", 0.0))
	out.append(_dbx(tx - 7.0, y + 46.0, 1.0, h - 52.0, "rgba(214, 90, 90, 0.55)", 0.0))   # lề đỏ
	for n in P[0]:
		n.r[1] = float(n.r[1]) + ty
		out.append(n)
	out.append(_dt(X0, ty + (nl - 1) * lh, XW - 16.0, lh, "— " + who, 11.0, 700, SUB, "right"))
	return [out, h]

func _gift(y: float, ic: String, t: String, s: String) -> Array:   # chip quà kèm thư: hình, số, dòng phụ
	var c := _chip(X0, y, XW, 44.0, "got")
	c.kids = [_icx(X0 + 26.0, y + 22.0, 30.0, ic), _dt(X0 + 48.0, y + 6.0, XW - 60.0, 18.0, t, 13.0, 800, "rgb(40, 110, 50)", "left"),
		_dt(X0 + 48.0, y + 24.0, XW - 60.0, 14.0, s, 10.0, 600, SUB, "left")]
	return [[c], 44.0]

func _send(y: float, id: String, q: int, xu: int, cb: Callable, de) -> Array:   # chip món (có / cần) sát chip tiền cước, hàng nút
	var out := []
	var hv := _barn(id)
	var ok := hv >= q
	var g := 6.0
	var lw := floorf((XW - g) * 0.5)
	var c := _chip(X0, y, lw, 38.0, "fut")
	c.kids = [_icx(X0 + 20.0, y + 19.0, 28.0, id), _dt(X0 + 40.0, y + 4.0, lw - 44.0, 15.0, _fitw(G.item_name(id), 10.5, 700, lw - 44.0), 10.5, 700, BROWN, "left"),
		_dt(X0 + 40.0, y + 19.0, lw - 44.0, 15.0, G.fmt_n(mini(hv, 99999)) + "/" + G.fmt_n(q), 11.0, 800, "rgb(46, 120, 50)" if ok else "rgb(190, 60, 50)", "left")]
	c.act = _dsay.bind(G.item_name(id) + ": kho có " + G.fmt_n(hv) + ", cần " + G.fmt_n(q) + ".")
	out.append(c)
	var rx := X0 + lw + g
	var rw := XW - lw - g
	var r := _chip(rx, y, rw, 38.0, "got")
	r.kids = [_icx(rx + 20.0, y + 19.0, 26.0, "xu"), _dt(rx + 40.0, y + 4.0, rw - 44.0, 15.0, "Tiền cước", 10.5, 700, SUB, "left"),
		_dt(rx + 40.0, y + 19.0, rw - 44.0, 15.0, "+" + G.fmt_n(xu) + " xu", 11.0, 800, "rgb(40, 110, 50)", "left")]
	out.append(r)
	y += 38.0 + GG
	if not ok:   # (bản 492) thiếu hàng: chỉ chỗ kiếm
		out.append_array(_rowi(X0 + 2.0, y, 16.0, ["i:" + id, " Còn thiếu " + G.fmt_n(q - hv) + " · " + G.where(id)], 10.5, 700, SUB)[0])
		y += 16.0 + 8.0
	if ok and de != null:
		var bw := floorf((XW - g) * 0.6)
		out.append(_btn(X0, y, bw, 32.0, "Gửi đi", cb, "go"))
		var d := _chip(X0 + bw + g, y, XW - bw - g, 32.0, "fut")
		d.kids = [_dt(X0 + bw + g, y, XW - bw - g, 32.0, "Để dành", 11.0, 700, BROWN)]
		d.act = de
		out.append(d)
	elif ok:
		out.append(_btn(X0, y, XW, 32.0, "Gửi đi", cb, "go"))
	elif de != null:   # thiếu hàng: chỉ còn Để dành
		var d2 := _chip(X0, y, XW, 32.0, "fut")
		d2.kids = [_dt(X0, y, XW, 32.0, "Để dành, đủ hàng gửi sau", 11.0, 700, BROWN)]
		d2.act = de
		out.append(d2)
	else:
		return [out, y - GG]
	return [out, y + 32.0]

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
		var rs := String(r.s)
		var sw: float = minf(Box.text_w(rs, 10.5, 800) + 2.0, XW - 170.0)
		var ks := [_icx(X0 + 16.0, y + 15.0, 22.0, _face(String(r.w))), _dt(X0 + 32.0, y, nw, 30.0, String(r.w), 10.5, 800, BROWN, "left"),
			_dt(X0 + 32.0 + nw + 2.0, y, 90.0, 30.0, "· " + dn, 10.0, 600, SUB, "left"),
			_dt(X0 + XW - 8.0 - sw, y, sw, 30.0, _fitw(rs, 10.5, 800, sw), 10.5, 800, String(LGC.get(String(r.get("k", "")), SUB)), "left")]
		if r.has("ic"):
			ks.append(_icx(X0 + XW - 8.0 - sw - 12.0, y + 15.0, 18.0, String(r.ic)))
		c.kids = ks
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
		var L := _letter(y, String(a.who), String(a.txt), String(a.get("noi", TH.noi(String(a.who)))))   # thư cũ trong bản lưu chưa ghi nơi: theo tên
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
			y = float(S[1])
	elif t.get("rq") is Dictionary:   # thư hẹn: một dòng đầu thư
		var o: Dictionary = t.rq
		out.append_array(_head(X0, y, XW, String(o.who), "Thư hẹn của " + String(o.who), "Còn hẹn gửi " + G.w_all.WC.ho(String(o.id), int(o.q))))
		y += 36.0 + GG
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
