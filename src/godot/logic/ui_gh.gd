extends "res://logic/ui_kbang.gd"
# GHE THƯƠNG HỒ (OD / D bản BUON, chạm ghe đậu bến hoặc viên "Ghe thương hồ ghé bến"). (bản 515) khung Kho + chip chung, không tab:
#  - chip đầu: hình ghe, "Ghe thương hồ <nơi>", chip giờ nhổ neo (cam, gấp thì đỏ);
#  - thanh "Đã chất N/M thùng" + chip thưởng chất đủ (xu, kinh nghiệm, 2 vật liệu hiếm: cân đòn / dây mây / gạch nung);
#  - lưới 2 cột: thùng đủ hàng lên đầu (nền xanh, nút Chất), thiếu (số đỏ + chỗ kiếm G.where, nút xám), đã chất (xanh nhạt ✓).
# Luật ở w_ghe.gd (Ae, Hd, bonus, cm).

var WG         # w_ghe.gd

func _init(ui) -> void:
	super(ui)
	WG = G.w_all.WGH

func open() -> void:
	on = true
	scroll = 0.0
	sig = ""
	_build()

func _sig() -> String:
	var A = WG.Ae
	var cnt := []
	for o in A.get("offers", []):
		cnt.append(int(G.g.barn.get(o.id, 0)))
	return JSON.stringify([A.get("offers"), cnt, A.st, int(floor(maxf(0.0, float(A.left)) / 30.0))])

func step(dt: float) -> void:
	if on and int(WG.Ae.st) != 2 and int(WG.Ae.st) != 1:   # ghe đi rồi
		close()
		return
	super(dt)

func _build() -> void:
	sig = _sig()
	var A = WG.Ae
	var L: Array = A.get("offers", [])
	var out := []
	var y := 6.0
	# chip đầu
	var At := maxf(0.0, float(A.left))
	var c := _chip(X0, y, XW, 50.0, "now")
	var tt := String(WG.cm(At))
	var tw: float = Box.text_w(tt, 10.5, 800) + 30.0
	c.kids = [_pic(X0 + 6.0, y + 5.0, 54.0, 40.0, "res://ui/img/xt/g_ghe1.webp"),
		_dt(X0 + 66.0, y + 7.0, XW - 74.0 - tw, 18.0, "Ghe thương hồ", 12.5, 800, BROWN, "left"),
		_dt(X0 + 66.0, y + 26.0, XW - 74.0 - tw, 16.0, "từ " + String(A.get("from", "")) if int(A.st) == 2 else "Đang vào bến", 10.5, 600, SUB, "left")]
	var tc := _chip(X0 + XW - 8.0 - tw, y + 14.0, tw, 22.0, "sen" if At < 1800.0 else "fire_l")
	tc.kids = [_dt(X0 + XW - 8.0 - tw, y + 14.0, tw, 22.0, "⏱ " + tt, 10.5, 800, "rgb(180, 60, 40)")]
	c.kids.append(tc)
	out.append(c)
	y += 50.0 + GG
	# thanh tiến độ + thưởng chất đủ
	var n := 0
	for o in L:
		if int(o.done):
			n += 1
	var Y: Dictionary = WG.bonus(L)
	out.append(_dt(X0 + 2.0, y, 150.0, 16.0, "Đã chất " + str(n) + "/" + str(L.size()) + " thùng", 11.0, 800, BROWN, "left"))
	out.append_array(_bar(X0 + 2.0, y + 20.0, 140.0, float(n) / maxf(1.0, L.size()), 6.0))
	var bx := X0 + 150.0
	var bw := XW - 150.0
	var bc := _chip(bx, y - 2.0, bw, 34.0, "got")
	var parts := ["c", " " + G.fmt_n(int(Y.xu)) + "  ", "i:svg:res://ui/svg/mat/huychuong.svg", " " + str(int(Y.xp)) + "  "]
	for m in WG.K:
		parts += ["i:svg:res://ui/svg/mat/" + String(m) + ".svg"]   # vật liệu hiếm
	var R: Array = _rowi(bx + 8.0, y + 1.0, 14.0, ["Chất đủ:"], 9.0, 700, "rgb(40, 110, 50)")
	var R2: Array = _rowi(bx + 8.0, y + 15.0, 16.0, parts, 10.0, 800, "rgb(40, 110, 50)")
	bc.kids = R[0] + R2[0]
	bc.act = _dsay.bind("Chất đủ hết thùng: +" + G.fmt_n(int(Y.xu)) + " xu, +" + str(int(Y.xp)) + " kinh nghiệm và 2 vật liệu hiếm (cân đòn, dây mây hoặc gạch nung).")
	out.append(bc)
	y += 34.0 + GG
	# lưới thùng: đủ hàng lên đầu, đã chất xuống cuối
	var idx := range(L.size())
	idx.sort_custom(func(a, b):
		var ra := _rank(L[a])
		var rb := _rank(L[b])
		return ra < rb or (ra == rb and a < b))
	var g := 6.0
	var cw := (XW - g) * 0.5
	var ch := 92.0
	for k in idx.size():
		var i: int = idx[k]
		var o: Dictionary = L[i]
		var x := X0 + (k % 2) * (cw + g)
		if k > 0 and k % 2 == 0:
			y += ch + g
		out.append_array(_box(x, y, cw, ch, i, o, int(A.st) == 2))
	y += ch + GG
	var sh := _kshell([], "", func(_k): pass)
	_kmount(sh[0], sh[1], float(sh[2]), out, y)

func _rank(o: Dictionary) -> int:   # 0 đủ hàng, 1 thiếu, 2 đã chất
	if int(o.done):
		return 2
	return 0 if int(G.g.barn.get(o.id, 0)) >= int(o.q) else 1

func _box(x: float, y: float, w: float, h: float, i: int, o: Dictionary, dock: bool) -> Array:   # một thùng
	var out := []
	var id := String(o.id)
	var hv := int(G.g.barn.get(id, 0))
	var q := int(o.q)
	var done := int(o.done) == 1
	var ok := hv >= q
	var c := _chip(x, y, w, h, "got" if done or ok else "fut")
	out.append(c)
	out.append(_icx(x + 24.0, y + 26.0, 36.0, id))
	if done:
		out[0].css = out[0].css.duplicate()
		out[0].css["opacity"] = "0.75"
	var nm: String = G.item_name(id)
	out.append(_dt(x + 46.0, y + 6.0, w - 50.0, 16.0, _fitw(nm, 10.5, 800, w - 50.0), 10.5, 800, BROWN, "left"))
	out.append(_dt(x + 46.0, y + 22.0, w - 50.0, 16.0, G.fmt_n(mini(hv, 99999)) + "/" + G.fmt_n(q), 11.0, 800, "rgb(40, 110, 50)" if ok or done else "rgb(190, 50, 60)", "left"))
	out.append_array(_rowi(x + 8.0, y + 48.0, 14.0, ["c", " " + G.fmt_n(int(o.xu))], 10.0, 800, "rgb(150, 90, 10)")[0])
	if done:
		out.append(_dtick(x + w - 24.0, y + 8.0, 16.0))
		out.append(_dt(x + 8.0, y + h - 26.0, w - 16.0, 20.0, "Đã chất lên ghe", 9.5, 700, "rgb(40, 110, 50)", "left"))
	elif ok:
		out.append(_btn(x + 8.0, y + h - 28.0, w - 16.0, 22.0, "Chất", _chat.bind(i), "go" if dock else "off"))
	else:
		out.append(_dt(x + 8.0, y + h - 28.0, w - 16.0, 22.0, _fitw(G.where(id), 9.0, 600, w - 16.0), 9.0, 600, SUB, "left"))
		c.act = _dsay.bind(nm + ": kho có " + G.fmt_n(hv) + ", cần " + G.fmt_n(q) + ". " + G.where(id) + ".")
	return out

func _chat(i: int) -> void:
	WG.Hd(i)
