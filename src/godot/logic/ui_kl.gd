extends "res://logic/ui_kbang.gd"
# KỶ LỤC (klOpen / klRender bản web, Sổ làng › Kỷ lục). (bản 478) làm lại trên khung Kho + chip chung (ui_kbang.gd), 3 tab:
# Tủ kỷ lục (chip tổng + thanh, hàng lọc nhóm, lưới ô màu theo nhóm, ô có hạng: chip "Kỷ lục"; chạm ô mở chi tiết + trái khủng gần đây, Bán),
# Xếp hạng (chip loại có hình cuộn ngang, bảng có huy chương), Hội thi (đếm ngược, lưới 2×2 loại thi, chip thưởng, kết quả tuần trước gọn).
# Chưa có bạn bè: bảng chỉ có làng mình. Luật ở w_ca.gd (kl_*).

var WC2        # w_ca.gd
var tab := "tu"             # KLS.tab
var sel := ""               # KLS.sel
var rk := ""                # KLS.rk
var flt := ""               # (bản 478) lọc tủ: "" | lua | rau | trai | co
var nox := false            # (bản 479) lưới loại chưa có đang mở
const TABC := {"tu": "rgb(200, 150, 40)", "rk": "rgb(76, 150, 48)", "thi": "rgb(200, 70, 60)"}
const FLT := [["", "Tất cả", ""], ["lua", "Lúa", "lua"], ["rau", "Rau", "cai"], ["trai", "Trái cây", "qua_xoai"], ["co", "Đã có", ""]]
const KLC := {   # nền ô theo nhóm cây: [gradient trên, giữa, dưới, viền]
	"g_lua": ["rgb(247, 236, 210)", "rgb(249, 242, 224)", "rgb(252, 247, 237)", "rgb(232, 203, 131)"],
	"g_rau": ["rgb(219, 234, 214)", "rgb(230, 240, 226)", "rgb(241, 247, 238)", "rgb(157, 197, 141)"],
	"g_trai": ["rgb(248, 230, 212)", "rgb(250, 238, 225)", "rgb(252, 245, 238)", "rgb(237, 186, 137)"],
	"g_quy": ["rgb(234, 226, 244)", "rgb(240, 235, 247)", "rgb(247, 243, 251)", "rgb(192, 168, 222)"],
	"k_tot": ["rgb(255, 240, 200)", "rgb(255, 245, 216)", "rgb(255, 250, 234)", "rgb(222, 170, 60)"],   # (bản 480) chip tổng: vàng nhạt
	"m1": ["rgb(255, 236, 170)", "rgb(255, 243, 196)", "rgb(255, 249, 222)", "rgb(222, 170, 40)"],   # nền huy chương vàng, bạc, đồng
	"m2": ["rgb(232, 236, 242)", "rgb(240, 243, 247)", "rgb(247, 249, 251)", "rgb(160, 168, 182)"],
	"m3": ["rgb(246, 224, 204)", "rgb(249, 234, 220)", "rgb(252, 243, 234)", "rgb(200, 136, 80)"],
	"g_no": ["rgb(246, 242, 234)", "rgb(248, 245, 238)", "rgb(250, 248, 243)", "rgba(150, 112, 48, 0.3)"],
}
const MEDAL := ["rgb(240, 190, 40)", "rgb(180, 186, 196)", "rgb(205, 135, 75)"]   # vàng, bạc, đồng

func _ck(kind: String) -> Array:
	return KLC[kind] if KLC.has(kind) else super(kind)

func _init(ui, wca) -> void:
	super(ui)
	WC2 = wca

func open(t := "") -> void:   # klOpen
	if t != "":
		tab = t if TABC.has(t) else "tu"
	on = true
	scroll = 0.0
	sig = ""
	_build()

func step(dt: float) -> void:
	if not on:
		return
	_sig_t -= dt
	if _sig_t > 0.0:
		return
	_sig_t = 1.0
	if _sig() != sig:
		_build()

func _sig() -> String:
	return JSON.stringify([tab, sel, rk, flt, WC2.kl_st(), int(WC2._now() / 60000.0)])

func _build() -> void:
	sig = _sig()
	var L := [["tu", "Tủ kỷ lục", false], ["rk", "Xếp hạng", false], ["thi", "Hội thi", false]]
	var sh := _kshell(L, tab, _tab_go)
	var r: Array
	match tab:
		"rk":
			r = _rk()
		"thi":
			r = _thi()
		_:
			r = _tu()
	_kmount(sh[0], sh[1], float(sh[2]), r[0], float(r[1]))

func _tab_go(k: String) -> void:   # data-kt
	if tab != k:
		tab = k
		scroll = 0.0

# ------------------------------------------------------------------ khối chung
func _sq(y: float, t: String, help: String) -> Array:   # tiêu đề phần + nút ? (đoạn luật) ở mép phải
	var out := _sect(y, t, String(TABC[tab]))
	if help != "":
		var rl: Dictionary = out[2]
		rl.r[2] = maxf(0.0, float(rl.r[2]) - 26.0)
		var q := _chip(X0 + XW - 20.0, y - 1.0, 20.0, 18.0, "info")
		q.kids = [_dt(X0 + XW - 20.0, y - 1.0, 20.0, 18.0, "?", 11.0, 800, "rgb(60, 110, 170)")]
		q.act = func(): U.tre_help(t, help)
		out.append(q)
	return out

func _grp(id: String) -> String:   # nhóm cây: lua | rau | trai | quy (giống lai)
	if WC2.lai_la(id):
		return "quy"
	if id.begins_with("qua_"):
		return "trai"
	if id in ["lua", "lua_thom", "lua_man", "nep"]:
		return "lua"
	return "rau"

func _medal(x: float, y: float, i: int) -> Dictionary:   # huy chương hạng i (0..2) hoặc số tròn kem
	var c := _dbx(x, y, 22.0, 22.0, String(MEDAL[i]) if i < 3 else "rgb(236, 226, 204)", 11.0)
	c.kids = [_dt(x, y, 22.0, 22.0, str(i + 1), 11.0, 800, "rgb(255, 255, 255)" if i < 3 else BROWN)]
	return c

func _board(y: float, id: String, L: Array, empty: String) -> Array:   # bảng hạng: huy chương, tên (Bạn nền xanh), số ký; trả [khối, cao]
	var out := []
	if L.is_empty():
		out.append(_dt(X0, y, XW, 15.0, empty, 10.5, 600, SUB, "left"))
		return [out, 15.0]
	var yy := y
	for i in L.size():
		var x: Dictionary = L[i]
		var me: bool = x.get("me", false)
		var c := _chip(X0, yy, XW, 30.0, "got" if me else "fut")
		var v: String = WC2.kl_kg(float(x.g), id)
		var vw: float = Box.text_w(v, 11.5, 800) + 2.0
		c.kids = [_medal(X0 + 8.0, yy + 4.0, i), _dt(X0 + 38.0, yy, XW - 56.0 - vw, 30.0, "Bạn" if me else String(x.n), 11.5, 800, BROWN, "left"),
			_dt(X0 + XW - 10.0 - vw, yy, vw, 30.0, v, 11.5, 800, "rgb(46, 120, 50)", "right")]
		out.append(c)
		yy += 30.0 + 5.0
	return [out, yy - 5.0 - y]

# ------------------------------------------------------------------ tab Tủ kỷ lục
func _tu() -> Array:
	var k: Dictionary = WC2.kl_st()
	var ids: Array = WC2.kld().keys()
	var got := ids.filter(func(id): return k.b.has(id)).size()
	var out := []
	var y := 6.0
	# chip tổng + thanh
	var hc := _chip(X0, y, XW, 50.0, "k_tot")   # (bản 480) vàng nhạt, khác ô đang chọn (vàng đậm)
	out.append(hc)
	out.append_array(_rowi(X0 + 10.0, y + 7.0, 17.0, ["Đã có " + str(got) + "/" + str(ids.size()) + " loại"], 12.5, 800, BROWN)[0])
	var nt := str(int(k.get("n", 0))) + " trái khủng" + ((" · " + String(k.tt[0])) if k.tt.size() else "")
	var nw: float = Box.text_w(nt, 10.5, 700) + 2.0
	out.append(_dt(X0 + XW - 10.0 - nw, y + 8.0, nw, 16.0, nt, 10.5, 700, "rgb(150, 100, 20)", "right"))
	out.append_array(_bar(X0 + 10.0, y + 31.0, XW - 20.0, float(got) / maxf(1.0, ids.size()), 6.0))
	y += 50.0 + GG
	# hàng lọc
	var cx := X0
	var cw := (XW - 4.0 * (FLT.size() - 1)) / FLT.size()
	for f in FLT:
		var on: bool = flt == String(f[0])
		var fc := _chip(cx, y, cw, 24.0, "thue" if on else "fut")
		var kk := []
		var hi := String(f[2]) != ""
		if hi:
			kk.append(_icn(cx + 11.0, y + 12.0, 15.0, String(f[2])))
		kk.append(_dt(cx + (19.0 if hi else 0.0), y, cw - (21.0 if hi else 0.0), 24.0, _fitw(String(f[1]), 10.0, 700, cw - 21.0), 10.0, 700, BROWN, "center"))
		fc.kids = kk
		fc.act = _flt.bind(String(f[0]))
		out.append(fc)
		cx += cw + 4.0
	y += 24.0 + GG
	# lưới: ô đã có trước (màu theo nhóm), ô chưa có sau (mờ)
	var L := ids.filter(func(id): return flt == "" or (flt == "co" and k.b.has(id)) or (flt != "co" and (_grp(id) == flt or (flt == "rau" and _grp(id) == "quy" and not String(id).begins_with("qua_")) or (flt == "trai" and _grp(id) == "quy" and String(id).begins_with("qua_")))))
	var L1 := L.filter(func(id): return k.b.has(id))
	var L2 := L.filter(func(id): return not k.b.has(id))
	if L1.size():
		var g := _tiles(y, L1, k)
		out.append_array(g[0])
		y += float(g[1]) + GG
	if L2.size() and flt != "co":   # (bản 479) loại chưa có: thu 1 chip, chạm mở lưới mờ
		var nc := _chip(X0, y, XW, 30.0, "info")   # (bản 480) xanh dương nhạt
		nc.kids = [_dt(X0 + 10.0, y, XW - 40.0, 30.0, ("Còn " + str(L2.size()) + " loại chưa có") if L1.size() else ("Chưa có trái khủng nào · " + str(L2.size()) + " loại"), 11.0, 700, "rgb(50, 96, 150)", "left"),
			_dic(X0 + XW - 20.0, y + 10.0, 10.0, CHU if nox else CHD)]
		nc.act = func(): nox = not nox
		out.append(nc)
		y += 30.0 + GG
		if nox:
			var g2 := _tiles(y, L2, k)
			out.append_array(g2[0])
			y += float(g2[1]) + GG
	# chi tiết ô đang chọn
	var f = k.b.get(sel)
	if f != null:
		out.append_array(_sq(y, WC2.kl_name(String(f.id)) + " nặng nhất", ""))
		y += 16.0 + GG
		var I: Array = WC2.kl_info(f)
		var ic := _chip(X0, y, XW, 14.0 + I.size() * 17.0, "g_" + _grp(String(f.id)))
		out.append(ic)
		out.append(_icn(X0 + 26.0, y + float(ic.r[3]) * 0.5, 36.0, String(f.id)))
		var yy := y + 7.0
		for rr in I:
			var vw: float = Box.text_w(String(rr[1]), 11.0, 800) + 2.0
			out.append(_dt(X0 + 54.0, yy, XW - 70.0 - vw, 17.0, String(rr[0]), 10.5, 600, SUB, "left"))
			out.append(_dt(X0 + XW - 10.0 - vw, yy, vw, 17.0, String(rr[1]), 11.0, 800, BROWN, "right"))
			yy += 17.0
		y += float(ic.r[3]) + GG
	# trái khủng gần đây + Bán
	var rows := []
	for i in k.r.size():
		var x: Dictionary = k.r[i]
		if sel != "" and x.id != sel:
			continue
		rows.append([i, x])
	if rows.size():
		out.append_array(_sq(y, "Trái khủng gần đây", "Trái khủng bán được giá cao gấp nhiều lần trái thường."))
		y += 16.0 + GG
		for e in rows:
			var x: Dictionary = e[1]
			var id := String(x.id)
			var c := _chip(X0, y, XW, 40.0, "g_" + _grp(id))
			out.append(c)
			out.append(_icn(X0 + 20.0, y + 20.0, 28.0, id))
			var P := ["Bán " + WC2._sa(WC2.kl_price(x)), "c"]
			var bw := float(_rowi(0.0, 0.0, 26.0, P, 10.5, 700, "")[1]) + 18.0
			var bt := _onbtn(X0 + XW - 8.0 - bw, y + 7.0, bw, 26.0, "", WC2.kl_sell.bind(int(e[0])))
			bt.kids = _rowi(X0 + XW - 8.0 - bw + 9.0, y + 7.0, 26.0, P, 10.5, 700, "rgb(255, 255, 255)")[0]
			out.append(bt)
			var tw := XW - 50.0 - bw - 6.0
			out.append(_dt(X0 + 40.0, y + 5.0, tw, 16.0, _fitw(WC2.kl_name(id) + " · " + WC2.kl_kg(float(x.g), id), 11.5, 800, tw), 11.5, 800, BROWN, "left"))
			out.append(_dt(X0 + 40.0, y + 21.0, tw, 14.0, _fitw(WC2.KLHANG[int(x.h)] + (" · " + String(x.who) + " gặt" if String(x.get("who", "")) != "" else ""), 10.0, 700, tw), 10.0, 700, "rgb(150, 100, 20)" if int(x.h) == 3 else SUB, "left"))
			y += 40.0 + 5.0
		y += GG - 5.0
	return [out, y]

func _tiles(y: float, L: Array, k: Dictionary) -> Array:   # lưới 3 cột ô kỷ lục
	var out := []
	var g := 5.0
	var bw := (XW - 2.0 * g) / 3.0
	var bh := 58.0
	for i in L.size():
		var id := String(L[i])
		var f = k.b.get(id)
		var x := X0 + (i % 3) * (bw + g)
		var yy := y + floorf(i / 3.0) * (bh + g)
		var gr := _grp(id)
		var c := _chip(x, yy, bw, bh, "now" if sel == id else ("g_" + gr if f != null else ("g_quy" if gr == "quy" else "g_no")))   # giống quý: nền tím cả ô
		var ks := [_icn(x + bw * 0.5, yy + 15.0, 22.0, id)]
		if f == null:
			ks[0].css["opacity"] = "0.35"
		var nm: String = WC2.kl_name(id)
		ks.append(_dt(x + 3.0, yy + 27.0, bw - 6.0, 14.0, _fitw(nm, 10.5, 800, bw - 6.0), 10.5, 800, BROWN if f != null else "rgb(150, 140, 120)"))
		ks.append(_dt(x + 3.0, yy + 41.0, bw - 6.0, 13.0, WC2.kl_kg(float(f.g), id) if f != null else "Chưa có", 10.5 if f != null else 9.5, 800 if f != null else 600, "rgb(46, 120, 50)" if f != null else "rgb(170, 160, 140)"))
		if f != null and int(f.h) == 3:   # hạng kỷ lục: chip vàng nhỏ góc trên
			var kc := _chip(x + bw - 34.0, yy + 3.0, 31.0, 13.0, "now")
			kc.kids = [_dt(x + bw - 34.0, yy + 3.0, 31.0, 13.0, "Kỷ lục", 7.5, 800, "rgb(150, 100, 20)")]
			ks.append(kc)
		c.kids = ks
		c.act = _sel.bind(id)
		out.append(c)
	var rows := int(ceil(L.size() / 3.0))
	return [out, rows * bh + maxf(0, rows - 1) * g]

func _sel(id: String) -> void:   # data-ks
	sel = "" if sel == id else id

func _flt(k: String) -> void:
	flt = k
	sel = ""
	scroll = 0.0

# ------------------------------------------------------------------ tab Xếp hạng
func _rk() -> Array:
	var k: Dictionary = WC2.kl_st()
	if rk == "" or not WC2.kld().has(rk):
		rk = String(k.b.keys()[0]) if k.b.size() else "lua"
	var out := []
	var y := 6.0
	# chip loại có hình: chỉ loại đã có (cuộn trong lưới 3 cột), đang chọn xanh
	var have: Array = WC2.kld().keys().filter(func(id): return k.b.has(id))
	if have.is_empty():
		for i in 3:   # (bản 479) bảng trống: 3 ô huy chương mờ
			var ec := _chip(X0, y, XW, 30.0, "g_no")
			var md := _medal(X0 + 8.0, y + 4.0, i)
			md.css["opacity"] = "0.4"
			ec.kids = [md, _dt(X0 + 38.0, y, XW - 48.0, 30.0, "Gặt trái khủng đầu tiên để lên bảng" if i == 0 else "—", 11.0, 700 if i == 0 else 600, SUB if i == 0 else "rgb(190, 180, 160)", "left")]
			out.append(ec)
			y += 30.0 + 5.0
		return [out, y + GG - 5.0]
	var g := 5.0
	var bw := (XW - 2.0 * g) / 3.0
	for i in have.size():
		var id := String(have[i])
		var x := X0 + (i % 3) * (bw + g)
		var yy := y + floorf(i / 3.0) * (26.0 + g)
		var c := _chip(x, yy, bw, 26.0, "thue" if id == rk else "g_" + _grp(id))
		c.kids = [_icn(x + 13.0, yy + 13.0, 18.0, id), _dt(x + 25.0, yy, bw - 28.0, 26.0, _fitw(WC2.kl_name(id), 10.5, 700, bw - 28.0), 10.5, 700, BROWN, "left")]
		c.act = _rk_go.bind(id)
		out.append(c)
	var rows := int(ceil(have.size() / 3.0))
	y += rows * 26.0 + maxf(0, rows - 1) * g + GG
	out.append_array(_sq(y, "Bảng " + WC2.kl_name(rk).to_lower(), "Chưa kết nối mạng nên bảng chỉ có làng mình."))
	y += 16.0 + GG
	var mine = k.b.get(rk)
	var L := [{"n": WC2.os_name(), "me": true, "g": float(mine.g)}] if mine != null else []
	var b := _board(y, rk, L, "Chưa ai có " + WC2.kl_name(rk).to_lower() + " khủng.")
	out.append_array(b[0])
	y += float(b[1]) + GG
	return [out, y]

func _rk_go(id: String) -> void:   # data-kr
	rk = id

# ------------------------------------------------------------------ tab Hội thi
func _thi() -> Array:
	var k: Dictionary = WC2.kl_st()
	var w: int = WC2.m_r()
	var cur: Array = WC2.kl_thi(w).filter(func(id): return id != "")
	var prev: Array = WC2.kl_thi(w - 1).filter(func(id): return id != "")
	var left := maxf(0.0, ceil(((w + 1) * 7 - 3) * 86400000.0 - WC2._now()) / 3600000.0)
	var out := []
	var y := 6.0
	out.append_array(_sq(y, "Hội thi tuần này", "Tuần này thi 4 loại (loại cuối là giống quý), mỗi loại lấy trái nặng nhất gặt trong tuần. Hạng 1–3 mỗi loại nhận xu, sen đỏ; hạng 1 có danh hiệu Vua."))
	var lt := "Còn " + (str(int(floor(left / 24.0))) + " ngày " if left >= 24.0 else "") + str(int(round(fmod(left, 24.0)))) + " giờ"
	var lc := _tchip(X0, y - 1.0, lt, "sen", "rgb(170, 50, 60)")
	Snap._move(lc[0], Vector2(XW - 26.0 - float(lc[1]), 0))
	out.append(lc[0])
	out[2].r[2] = maxf(0.0, float(out[2].r[2]) - float(lc[1]) - 6.0)
	y += 16.0 + GG
	# (bản 481) thưởng: 3 ô cao bằng nhau, huy chương có dải (trái), "Hạng N" + xu, sen (phải); hạng 1 có chip Vua
	var pw := (XW - 8.0) / 3.0
	for i in 3:
		var P: Array = WC2.KLPRIZE[i]
		var px := X0 + i * (pw + 4.0)
		var pc := _chip(px, y, pw, 56.0, "m" + str(i + 1))
		var kk := [_dic(px + 4.0, y + 12.0, 32.0, _medsvg(i))]
		kk.append(_dt(px + 38.0, y + 6.0, pw - 40.0, 16.0, "Hạng " + str(i + 1), 11.5, 800, ["rgb(170, 120, 10)", "rgb(100, 110, 126)", "rgb(160, 90, 40)"][i], "left"))
		kk.append_array(_rowi(px + 36.0, y + 22.0, 15.0, [WC2._sa(int(P[0])), "c"], 10.5, 800, BROWN)[0])   # dòng 2: xu, dòng 3: sen
		kk.append_array(_rowi(px + 36.0, y + 37.0, 15.0, [str(P[1]), "i:pearl"], 10.5, 800, BROWN)[0])
		if i == 0:
			var vc := _chip(px + pw - 30.0, y - 6.0, 30.0, 14.0, "sen")
			vc.kids = [_dt(px + pw - 30.0, y - 6.0, 30.0, 14.0, "Vua", 8.5, 800, "rgb(190, 50, 60)")]
			kk.append(vc)
		pc.kids = kk
		pc.act = _dsay.bind("Hạng " + str(i + 1) + " mỗi loại: " + WC2._sa(int(P[0])) + " xu, " + str(P[1]) + " sen đỏ" + (", danh hiệu Vua." if i == 0 else "."))
		out.append(pc)
	y += 56.0 + GG
	# lưới 2×2 loại thi
	var g := 6.0
	var bw := (XW - g) * 0.5
	var bh := 64.0
	for i in cur.size():
		var id := String(cur[i])
		var my = k.wk.b.get(id)
		var R: Array = WC2.kl_thi_rank(w, id)
		var x := X0 + (i % 2) * (bw + g)
		var yy := y + floorf(i / 2.0) * (bh + g)
		var c := _chip(x, yy, bw, bh, "g_" + _grp(id))
		var ks := [_icn(x + 20.0, yy + 22.0, 30.0, id), _dt(x + 40.0, yy + 7.0, bw - 46.0, 16.0, _fitw(WC2.kl_name(id), 11.5, 800, bw - 46.0), 11.5, 800, BROWN, "left"),
			_dt(x + 40.0, yy + 23.0, bw - 46.0, 14.0, WC2.kl_kg(float(my), id) if my != null else "Chưa dự thi", 11.0 if my != null else 10.0, 800 if my != null else 600, "rgb(46, 120, 50)" if my != null else SUB, "left")]
		var hk := 0
		for j in R.size():
			if R[j].get("me", false):
				hk = j + 1
		var hx := x + 8.0
		if hk:   # (bản 479) chip hạng chỉ khi đã dự thi
			var hc := _tchip(hx, yy + bh - 24.0, "Hạng " + str(hk), "now" if hk == 1 else "got", "rgb(150, 100, 20)" if hk == 1 else "rgb(46, 120, 50)", null, 18.0, 9.5)
			ks.append(hc[0])
			hx += float(hc[1]) + 4.0
		if _grp(id) == "quy":
			var qc := _tchip(hx, yy + bh - 24.0, "Giống quý", "g_quy", "rgb(110, 70, 170)", null, 18.0, 9.5)
			ks.append(qc[0])
		c.kids = ks
		c.act = _dsay.bind(WC2.kl_name(id) + ": " + (("của bạn " + WC2.kl_kg(float(my), id) + ", đang hạng " + str(hk) + ".") if my != null else "gặt trong tuần này để dự thi."))
		out.append(c)
	var rows := int(ceil(cur.size() / 2.0))
	y += rows * bh + maxf(0, rows - 1) * g + GG
	# kết quả tuần trước: dòng gọn, loại không ai dự thi gộp 1 dòng
	out.append_array(_sq(y, "Kết quả tuần trước", ""))
	y += 16.0 + GG
	var none := []
	for id in prev:
		var L: Array = WC2.kl_thi_rank(w - 1, id)
		if L.is_empty():
			none.append(WC2.kl_name(id))
			continue
		var c := _chip(X0, y, XW, 30.0, "g_" + _grp(id))
		var p := []
		for i in mini(3, L.size()):
			p.append(("Bạn" if L[i].get("me", false) else String(L[i].n)) + " " + WC2.kl_kg(float(L[i].g), id))
		c.kids = [_icn(X0 + 16.0, y + 15.0, 20.0, id), _medal(X0 + 32.0, y + 4.0, 0), _dt(X0 + 60.0, y, XW - 70.0, 30.0, _fitw(WC2.kl_name(id) + ": " + " · ".join(PackedStringArray(p)), 11.0, 700, XW - 70.0), 11.0, 700, BROWN, "left")]
		out.append(c)
		y += 30.0 + 5.0
	if none.size():
		out.append(_dt(X0, y, XW, 15.0, _fitw(str(none.size()) + " loại không ai dự thi: " + ", ".join(PackedStringArray(none)), 10.5, 600, XW), 10.5, 600, SUB, "left"))
		y += 15.0 + 5.0
	return [out, y + GG - 5.0]

static func _medsvg(i: int) -> String:   # (bản 481) huy chương có dải ruy băng: vàng / bạc / đồng
	var C: Array = [["rgb(250,204,60)", "rgb(200,150,20)"], ["rgb(214,220,230)", "rgb(140,150,166)"], ["rgb(222,150,90)", "rgb(160,96,44)"]][i]
	return "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\"><path d=\"M6 1 L10 10 L12 9 L8 1 Z\" fill=\"rgb(210,60,60)\"/><path d=\"M18 1 L14 10 L12 9 L16 1 Z\" fill=\"rgb(60,110,190)\"/><circle cx=\"12\" cy=\"15.5\" r=\"7\" fill=\"" + C[0] + "\" stroke=\"" + C[1] + "\" stroke-width=\"1.3\"/><circle cx=\"12\" cy=\"15.5\" r=\"4.8\" fill=\"none\" stroke=\"" + C[1] + "\" stroke-width=\"0.8\" opacity=\"0.7\"/><text x=\"12\" y=\"18.3\" font-size=\"7.5\" font-weight=\"800\" text-anchor=\"middle\" fill=\"" + C[1] + "\">" + str(i + 1) + "</text></svg>"
