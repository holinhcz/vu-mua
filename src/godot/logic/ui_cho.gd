extends "res://logic/ui_kbang.gd"
# CHỢ NỔI SÔNG VÀM (jx bản web, 5–9 giờ sáng, chạm ghe chợ hoặc viên "Chợ nổi đang họp"). (bản 517) khung Kho + chip chung:
#  - hàng tab 4 ghe (W.s4); dải đầu: hình ghe, người bán, ghe bán gì, chip giờ tan chợ (gấp thì đỏ);
#  - "Được giá": chip cam mỗi món (hình + ×2), chạm xem giải thích;
#  - lưới 2 cột kèo hôm nay, màu ô theo loại: Mua (ghe bán, kem), Bán (ghe mua hàng mình, xanh, có/cần), Đổi (tím nhạt, hình món đưa);
#    kèo xong dồn cuối, mờ, dấu ✓. Chạm ô xem đủ chi tiết.
# Luật ở w_cho.gd (jd, Wx, Dd, s4).

var W          # w_cho.gd
const CLOCK := "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24'><circle cx='12' cy='13' r='9' fill='#fff3e0' stroke='#c8502a' stroke-width='2.4'/><path d='M12 8v5l3.2 2' fill='none' stroke='#c8502a' stroke-width='2.4' stroke-linecap='round'/><path d='M9 2.5h6' stroke='#c8502a' stroke-width='2.4' stroke-linecap='round'/></svg>"
const CHC := {   # nền ô theo loại kèo
	"k_mua": ["rgb(250, 242, 222)", "rgb(252, 247, 234)", "rgb(255, 252, 245)", "rgba(150, 112, 48, 0.55)"],
	"k_ban": ["rgb(226, 244, 214)", "rgb(234, 248, 224)", "rgb(243, 251, 236)", "rgb(110, 170, 80)"],
	"k_doi": ["rgb(236, 228, 248)", "rgb(241, 235, 250)", "rgb(247, 243, 252)", "rgb(150, 120, 196)"],
}

func _ck(kind: String) -> Array:
	return CHC[kind] if CHC.has(kind) else super(kind)

func _init(ui) -> void:
	super(ui)
	W = G.w_all.WC

func open(k := 0) -> void:
	on = true
	scroll = 0.0
	sig = ""
	W.Ui.sel = k
	_build()

func _left() -> float:   # giờ còn tới lúc tan chợ
	return maxf(0.0, W.wm() - G.nv.hour())

func _sig() -> String:
	var a: int = int(W.Ui.sel)
	var cnt := []
	for c in W.jd()[a]:
		cnt.append(int(G.g.barn.get(c.id, 0)))
		if c.t == "doi":
			cnt.append(int(G.g.barn.get(c.g, 0)))
	return JSON.stringify([a, G.g.get("cho"), cnt, int(floor(float(G.g.coins) / 10.0)), int(floor(_left() * 6.0))])

func step(dt: float) -> void:
	if on and not W.b2() and float(W.Ui.al) <= 0:   # chợ tan
		close()
		return
	super(dt)

func _tab(k: String) -> void:
	W.Ui.sel = int(k)
	scroll = 0.0
	_build()

func _build() -> void:
	sig = _sig()
	var a: int = int(W.Ui.sel)
	var L := []
	for f in W.s4.size():
		L.append([str(f), _cap(String(W.s4[f].n).replace("Ghe ", ""))])
	var out := []
	var y := 6.0
	# dải đầu: ghe + người bán + giờ tan
	var n: Dictionary = W.s4[a]
	var o := _left()
	var tt := "còn " + ((str(int(floor(o))) + " tiếng") if o >= 1.0 else (str(int(round(fmod(o, 1.0) * 60.0))) + " phút"))
	var tw: float = Box.text_w(tt, 10.0, 800) + 32.0
	out.append(_pic(X0, y + 2.0, 58.0, 42.0, "res://ui/img/xt/g_ghe1.webp"))
	out.append(_dt(X0 + 64.0, y + 2.0, XW - 70.0 - tw, 18.0, _fitw(String(n.who), 12.5, 800, XW - 70.0 - tw), 12.5, 800, BROWN, "left"))
	var tc := _chip(X0 + XW - tw, y + 1.0, tw, 22.0, "sen" if o < 0.4 else "fire_l")
	tc.kids = [_dic(X0 + XW - tw + 7.0, y + 4.0, 16.0, CLOCK),
		_dt(X0 + XW - tw + 26.0, y + 1.0, tw - 30.0, 22.0, tt, 10.0, 800, "rgb(180, 60, 40)", "left")]
	tc.act = _dsay.bind("Chợ nổi họp 5–" + str(W.wm()) + " giờ sáng, " + tt + " nữa là tan.")
	out.append(tc)
	var P: Array = _para(X0 + 64.0, y + 22.0, XW - 66.0, String(n.d), 10.0, 600, SUB, 13.0)
	out.append_array(P[0])
	y += maxf(46.0, 22.0 + float(P[1])) + GG
	# hôm nay được giá: mỗi món một chip (hình + tên + ×)
	var hl: Array = G.hot()
	if hl.size():
		out.append_array(_hd(y, "Hôm nay được giá"))
		y += 16.0 + 6.0
		var hg := 6.0
		var hw := (XW - hg * (hl.size() - 1)) / hl.size()
		for i in hl.size():
			var id := String(hl[i][0])
			var s: String = W.h5(float(hl[i][1]))
			var x := X0 + i * (hw + hg)
			var sw: float = Box.text_w(s, 10.5, 800) + 4.0
			var c := _chip(x, y, hw, 26.0, "fire_l")
			c.kids = [_icx(x + 14.0, y + 13.0, 18.0, id),
				_dt(x + 26.0, y, hw - 30.0 - sw, 26.0, _fitw(G.item_name(id), 9.5, 700, hw - 30.0 - sw), 9.5, 700, BROWN, "left"),
				_dt(x + hw - 4.0 - sw, y, sw, 26.0, s, 10.5, 800, "rgb(190, 80, 20)", "left")]
			c.act = _dsay.bind(G.item_name(id) + " hôm nay được giá " + s + ". Bán trong Kho hoặc giao đơn có món này được thêm 30%.")
			out.append(c)
		y += 26.0 + GG
	# lưới kèo: chưa xong lên đầu
	var T: Array = W.jd()[a]
	var idx := range(T.size())
	idx.sort_custom(func(p, q):
		var dp := 1 if W.Wx(a, p) else 0
		var dq := 1 if W.Wx(a, q) else 0
		return dp < dq or (dp == dq and p < q))
	var g := 6.0
	var cw := (XW - g) * 0.5
	var ch := 96.0
	for k in idx.size():
		var x := X0 + (k % 2) * (cw + g)
		if k > 0 and k % 2 == 0:
			y += ch + g
		out.append_array(_box(x, y, cw, ch, a, idx[k], T[idx[k]]))
	if T.size():
		y += ch
	y += GG
	var sh := _kshell(L, str(a), _tab)
	_kmount(sh[0], sh[1], float(sh[2]), out, y)

static func _cap(s: String) -> String:
	return s.substr(0, 1).to_upper() + s.substr(1)

func _box(x: float, y: float, w: float, h: float, a: int, f: int, c: Dictionary) -> Array:   # một kèo
	var out := []
	var done: bool = W.Wx(a, f)
	var t := String(c.t)   # doi: đổi | mua: ghe mua (mình bán) | ban: ghe bán (mình mua)
	var kind := "k_doi" if t == "doi" else "k_ban" if t == "mua" else "k_mua"
	var bx := _chip(x, y, w, h, kind)
	out.append(bx)
	var ic: String = String(c.id) if t == "doi" else W.bB(c)
	var nm: String
	var ok: bool
	var bt: String
	var info := ""
	if t == "doi":
		nm = "Đổi lấy " + str(int(c.q)) + " hạt giống " + G.item_name(c.id).to_lower()
		ok = int(G.g.barn.get(c.g, 0)) >= int(c.gq)
		bt = "Đổi"
		info = nm + ": đưa ghe " + W.ho(c.g, int(c.gq)) + " (kho có " + G.fmt_n(int(G.g.barn.get(c.g, 0))) + ")."
	elif t == "mua":
		nm = "Bán " + W.ho(c.id, int(c.q))
		ok = int(G.g.barn.get(c.id, 0)) >= int(c.q)
		bt = "Bán"
		info = "Ghe mua " + W.ho(c.id, int(c.q)) + ", trả " + G.fmt_n(int(c.xu)) + " xu (chợ làng chỉ " + G.fmt_n(int(c.q) * G.price(c.id)) + " xu). Kho có " + G.fmt_n(int(G.g.barn.get(c.id, 0))) + "."
	else:
		nm = W.pQ(c)
		ok = int(G.g.coins) >= int(c.xu)
		bt = "Mua"
		var k: String = c.k
		var sub := "Thả ao sen, đẻ trứng vịt." if k == "vitcon" else "Rẻ hơn tiệm 20%." if k == "cg" else "Rẻ hơn chợ phiên." if k == "giong" else "Thả vô chuồng." if k == "con" else ""
		info = nm + ": " + G.fmt_n(int(c.xu)) + " xu. " + sub + ("" if ok else " Chưa đủ xu.")
	out.append(_icx(x + 24.0, y + 26.0, 36.0, ic))
	var nl: Array = _wrap(nm, 10.5, 800, w - 52.0)
	for i in mini(2, nl.size()):
		var s := String(nl[i])
		if i == 1 and nl.size() > 2:
			s = _fitw(s + " …", 10.5, 800, w - 52.0)
		out.append(_dt(x + 46.0, y + 6.0 + i * 15.0, w - 52.0, 15.0, s, 10.5, 800, BROWN, "left"))
	# dòng giữa: giá / có-cần / món đưa
	var R: Array
	var red := "rgb(190, 50, 60)"
	var grn := "rgb(40, 110, 50)"
	if t == "doi":
		var hv := int(G.g.barn.get(c.g, 0))
		R = _rowi(x + 8.0, y + 46.0, 18.0, ["Đưa", "i:" + String(c.g), G.fmt_n(mini(hv, 9999)) + "/" + G.fmt_n(int(c.gq))], 10.0, 800, grn if ok or done else red)
	elif t == "mua":
		var hv := int(G.g.barn.get(c.id, 0))
		R = _rowi(x + 8.0, y + 46.0, 18.0, [(G.fmt_n(int(c.q)) if done else G.fmt_n(mini(hv, 9999))) + "/" + G.fmt_n(int(c.q)) + "  ", "c", " " + G.fmt_n(int(c.xu))], 10.0, 800, grn if ok or done else red)
	else:
		R = _rowi(x + 8.0, y + 46.0, 18.0, ["c", " " + G.fmt_n(int(c.xu))], 10.5, 800, "rgb(150, 90, 10)" if ok or done else red)
	out.append_array(R[0])
	var tag := "−20%" if String(c.get("k", "")) == "cg" and t == "ban" else ""
	if tag != "":
		out.append(_tchip(x + 12.0 + float(R[1]), y + 46.0, tag, "got", "rgb(40, 110, 50)")[0])
	if done:
		bx.css = bx.css.duplicate()
		bx.css["opacity"] = "0.7"
		out.append(_dtick(x + w - 22.0, y + 6.0, 16.0))
		out.append(_dt(x + 8.0, y + h - 26.0, w - 16.0, 20.0, "Đã " + bt.to_lower() + " hôm nay", 9.5, 700, grn, "left"))
	else:
		out.append(_btn(x + 8.0, y + h - 28.0, w - 16.0, 22.0, bt, _deal.bind(a, f), "go" if ok else "off"))
	bx.act = _dsay.bind(info)
	return out

func _deal(a: int, f: int) -> void:
	W.Dd(a, f)
	sig = ""
	_build()
