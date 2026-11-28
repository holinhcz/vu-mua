extends "res://logic/ui_kbang.gd"
# BẢNG NHÂN VẬT (bấm hình đại diện #pcAv) trên khung chung (ui_kbang: khung sen, hàng tab, tiêu đề mục, chip), 3 tab:
#   Nhân vật: tên + cấp + thanh kinh nghiệm + thanh sức (nút Ngủ); nhân vật đứng giữa 2 cột ô:
#     trái Nón / Áo / Quần / Dép (đồ mặc), phải Bình tưới / Liềm / Cuốc / Gùi (đồ nghề cấp 0-3); hàng dưới Xe đạp / Xuồng / Bùa / Bùa EXP.
#     Chạm ô: thẻ chi tiết đáy tab (tác dụng, nút Sắm / Nâng / Mở túi).
#   Chỉ số: cấp, thể lực, di chuyển, đồ nghề, bùa.
#   Túi đồ: đồ mặc được (lọc Nón / Áo / Quần / Dép). (11-27) chưa có nguồn đồ: ô trống.
#   (bản 546) bảng Diều (thân w_ca_ui) mở riêng qua open_solo("dieu").

const TABS := [["nv", "Nhân vật"], ["cs", "Chỉ số"], ["tui", "Túi đồ"]]
const WTABS := ["dieu"]
const LEFT := ["non", "ao", "quan", "dep"]
const RIGHT := ["binh", "liem", "cuoc", "gui"]
const BOT := ["xe", "xuong", "bua", "xp"]
const MAC := {"non": "Nón", "ao": "Áo", "quan": "Quần", "dep": "Dép"}

var K := {}
var tab := "nv"
var sel := "binh"
var tui := ""   # lọc túi đồ: "" tất cả, hoặc khoá MAC
var wc: Control = null      # thân tab w_ca_ui
var pic: Control = null     # hình nhân vật
var _svgs := {}

func _init(ui) -> void:
	super(ui)
	K = Snap.load_snap("kdd")

var solo := ""   # (bản 546) mở riêng 1 bảng (Diều từ nút viên "Có gió chướng"): chỉ 1 tab
func open_solo(t: String) -> void:
	solo = t
	tab = t
	_open0()

func open(t := "") -> void:
	if t == "cau":   # câu cũ đã bỏ: mở minigame câu cá
		U.ccp.open()
		return
	solo = ""
	if t != "":
		tab = t
	if WTABS.has(tab):
		tab = "nv"
	_open0()

func _open0() -> void:
	U.close_all()
	U.kho_close()
	on = true
	scroll = 0.0
	sig = ""
	_build()

func close() -> void:
	if wc != null and is_instance_valid(wc) and wc.get_parent() != null:
		wc.get_parent().remove_child(wc)   # bảng diều dùng lại lần sau, không để khung cũ xoá mất
	wc = null
	super()

func _sig() -> String:
	if WTABS.has(tab):
		return tab
	var p: Dictionary = G.g.pc
	return JSON.stringify([tab, sel, tui, p.lv, p.xp, int(floor(float(p.en))), p.get("tools"), p.get("xe"), p.get("xuong"), G.bh(), int(G.bh_left() / 60000.0),
		int(G.nv.Fu() / 60000.0), G.g.coins, G.mat_n("gach"), p.get("n")])

func _tab_go(k: String) -> void:
	if tab != k:
		tab = k
		scroll = 0.0

# ------------------------------------------------------------------ dựng
func _build() -> void:
	sig = _sig()
	var L := [[solo, {"dieu": "Diều"}.get(solo, solo), false]] if solo != "" else TABS.map(func(x): return [x[0], x[1], false])
	var sh := _kshell(L, tab, _tab_go)
	var r: Array
	wc = null
	if WTABS.has(tab) and G.w_all != null and G.w_all.WCAU != null:
		wc = G.w_all.WCAU.tab_body(tab)
		var h: float = maxf(200.0, wc.get_combined_minimum_size().y / Css.K)
		r = [[_hold("pcw", X0, 0.0, XW, h)], h]
	elif tab == "cs":
		r = _cs()
	elif tab == "tui":
		r = _tui()
	else:
		r = _nv()
	_kmount(sh[0], sh[1], sh[2], r[0], float(r[1]))
	if wc != null:   # thân tab w_ca_ui đặt vào khối giữ chỗ
		var hold = ids.get(".pcw")
		if hold != null:
			wc.custom_minimum_size.x = hold.size.x
			hold.add_child(wc)
	elif tab == "nv":
		var fig = ids.get(".pcfig")
		if fig != null and (pic == null or not is_instance_valid(pic) or pic.get_parent() != fig):
			pic = PcPic.new()
			pic.farm = U.F
			pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
			fig.add_child(pic)
		if pic != null and fig != null:
			pic.position = Vector2.ZERO
			pic.size = fig.size

func _hold(cls: String, x: float, y: float, w: float, h: float) -> Dictionary:   # khối trống giữ chỗ (gắn Control vào sau)
	return {"z": 0.75, "tag": "div", "id": "", "cls": cls, "r": [x, y, w, h], "css": {"display": "block", "position": "static"}, "kids": [], "nw": str(Time.get_ticks_msec())}

func _svg(k: String) -> String:   # hình ô (ui/svg/kh/pc_*, bùa từ mẫu Đồ dùng)
	if k == "*bua":
		return String(K.ic_bua)
	if not _svgs.has(k):
		_svgs[k] = FileAccess.get_file_as_string("res://ui/svg/kh/" + k + ".svg")
	return _svgs[k]

# ô trang bị: [hình, tên, số góc thẻ ("" = không), có chưa]
func _slot(k: String) -> Array:
	var p: Dictionary = G.g.pc
	if MAC.has(k):
		return ["pc_" + k, MAC[k], "", false]
	if RIGHT.has(k):
		var t: int = G.fd(k)
		var nm := ""
		for o in G.TOOLS:
			if o.id == k:
				nm = String(o.n)
		return ["pc_" + k, nm, ("c" + str(t)) if t > 0 else "", t > 0]
	match k:
		"xe":
			return ["pc_xe", "Xe đạp", "", bool(p.get("xe", 0))]
		"xuong":
			return ["pc_xuong", "Xuồng ba lá", "", bool(p.get("xuong", 0))]
		"bua":
			var b: String = G.bh()
			return ["*bua", String(G.BUFFS[b].n) if b != "" else "Bùa", "", b != ""]
		"xp":
			var n := 0
			for v in G.nv.A3().values():
				n += int(v)
			return ["*bua", "Bùa EXP", str(n) if n > 0 else "", G.nv.Fu() > 0.0 or n > 0]
	return ["", k, "", false]

func _cell(k: String, x: float, y: float, w: float, h: float) -> Array:   # ô chip: hình + tên, số góc; đang chọn vàng
	var s := _slot(k)
	var c := _chip(x, y, w, h, "now" if k == sel else ("fut" if s[3] else "miss"))
	var is_ := minf(30.0, h - 26.0)
	var op := 1.0 if s[3] or k == sel else 0.55
	c.kids = [_dic(x + (w - is_) * 0.5, y + (h - is_ - 16.0) * 0.5, is_, _svg(String(s[0])), op),
		_dt(x + 2.0, y + h - 18.0, w - 4.0, 14.0, _fitw(String(s[1]), 10.5, 700, w - 6.0), 10.5, 700, BROWN if s[3] else SUB)]
	if String(s[2]) != "":
		var bw: float = Box.text_w(String(s[2]), 10.5, 800) + 8.0
		c.kids.append(_dbx(x + w - bw - 3.0, y + 3.0, bw, 14.0, "rgb(214, 160, 30)", 7.0))
		c.kids.append(_dt(x + w - bw - 3.0, y + 3.0, bw, 14.0, String(s[2]), 10.5, 800, "rgb(255, 255, 255)"))
	var kk := k
	c.act = func(): sel = kk
	return [c]

func _bars(y: float, nm: String, f: float, t: String) -> Array:   # dòng thanh: tên trái, thanh giữa, số phải
	var tw: float = Box.text_w(t, 10.5, 800) + 4.0
	var out := [_dt(X0, y, 72.0, 14.0, nm, 10.5, 700, SUB, "left")]
	out.append_array(_bar(X0 + 74.0, y + 4.0, XW - 74.0 - tw - 8.0, f, 6.0))
	out.append(_dt(X0 + XW - tw, y, tw, 14.0, t, 10.5, 800, GREEN, "right"))
	return out

# ------------------------------------------------------------------ tab Nhân vật
func _nv() -> Array:
	var out := []
	var p: Dictionary = G.g.pc
	var lv: int = int(p.lv)
	var need: int = G.xp_need(lv)
	var em: float = G.en_max()
	# đầu: tên + cấp, nút ngủ; thanh kinh nghiệm, sức
	var nm := String(p.get("name", ""))
	if nm == "":
		nm = "Anh Năm Gạo"
	var nw: float = minf(Box.text_w(nm, 14.0, 800) + 4.0, XW - 150.0)
	out.append(_dt(X0, 6.0, nw, 22.0, _fitw(nm, 14.0, 800, nw), 14.0, 800, BROWN, "left"))
	var lt := "Cấp " + str(lv)
	var lw: float = Box.text_w(lt, 10.5, 800) + 16.0
	var lp := _onbtn(X0 + nw + 6.0, 8.0, lw, 18.0, lt, null)
	lp.kids[0].css["font-size"] = _cpx(10.5)
	out.append(lp)
	out.append(_btn(X0 + XW - 64.0, 5.0, 64.0, 24.0, "Về ngủ", _sleep, "plain"))
	out.append_array(_bars(34.0, "Kinh nghiệm", float(p.xp) / maxf(1.0, need), G.fmt_n(int(p.xp)) + "/" + G.fmt_n(need)))
	out.append_array(_bars(52.0, "Sức", float(p.en) / maxf(1.0, em), str(int(floor(float(p.en)))) + "/" + str(int(em))))
	# ô trang bị: cao theo thân, vừa một màn
	var y0 := 76.0
	var dh := 62.0   # thẻ chi tiết
	var g := 6.0
	var sh := clampf(floorf((_hb - 2.0 - y0 - dh - 10.0 - 8.0 - 4.0 * g) / 5.0), 50.0, 70.0)
	var sw := 66.0
	for i in 4:
		out.append_array(_cell(LEFT[i], X0, y0 + i * (sh + g), sw, sh))
		out.append_array(_cell(RIGHT[i], X0 + XW - sw, y0 + i * (sh + g), sw, sh))
	var fh := 4.0 * sh + 3.0 * g
	out.append(_hold("pcfig", X0 + sw + 6.0, y0, XW - 2.0 * sw - 12.0, fh))
	var yb := y0 + fh + 8.0
	var bw := (XW - 3.0 * 8.0) / 4.0
	for i in 4:
		out.append_array(_cell(BOT[i], X0 + i * (bw + 8.0), yb, bw, sh))
	var yd := yb + sh + 10.0
	out.append_array(_det(yd, dh))
	return [out, yd + dh + 2.0]

func _sleep() -> void:
	close()
	U.F.sleep_go()

func _det(y: float, h: float) -> Array:   # thẻ chi tiết món đang chọn: hình, tên · cấp, tác dụng, cấp sau, nút
	var s := _slot(sel)
	var nm := String(s[1])
	var sm := ""
	var tx := ""
	var bl := ""
	var act = null
	var ok := true
	if MAC.has(sel):
		sm = "Chưa mặc"
		tx = "Đồ mặc chọn ở tab Túi đồ."
	elif RIGHT.has(sel):
		var t: int = G.fd(sel)
		nm += " · cấp " + str(t)
		sm = G.tool_desc(sel, t)
		if t >= 3:
			tx = "Đã nâng tối đa."
		else:
			var c: Array = G.TOOL_COST[t]
			tx = "Cấp " + str(t + 1) + ": " + G.tool_desc(sel, t + 1) + "."
			bl = ("Sắm" if t == 0 else "Nâng") + " · " + G.fmt_n(int(c[0])) + " xu" + ((" + " + str(c[1]) + " gạch") if int(c[1]) > 0 else "")
			ok = int(G.g.coins) >= int(c[0]) and G.mat_n("gach") >= int(c[1])
			var kk := sel
			act = func(): G.tool_up(kk)
	elif sel == "xe" or sel == "xuong":
		var a := {}
		for o in G.RIDES:
			if o.id == sel:
				a = o
		var has := bool(G.g.pc.get(sel, 0))
		sm = "Đã có" if has else ("Cần cấp " + str(a.lv) if G.lv() < int(a.lv) else "Chưa có")
		tx = String(a.d) + "."
		if not has:
			bl = "Sắm · " + G.fmt_n(int(a.xu)) + " xu"
			ok = G.lv() >= int(a.lv) and int(G.g.coins) >= int(a.xu)
			var kk2 := sel
			act = func(): G.ride_buy(kk2)
	elif sel == "bua":
		var b: String = G.bh()
		if b != "":
			sm = "Còn " + U.kdp.MA(G.bh_left())
			tx = String(G.BUFFS[b].d) + "."
		else:
			sm = "Chưa có bùa"
			tx = "Bùa có từ chùa, lễ hội, sự kiện."
	elif sel == "xp":
		var f: float = G.nv.Fu()
		sm = ("Đang chạy · còn " + U.kdp.MA(f)) if f > 0.0 else "Chưa dùng"
		tx = "+50% kinh nghiệm, dùng thêm thì cộng dồn."
		bl = "Mở túi"
		act = func():
			close()
			U.kho_open()
			U._kho_tab(2)
	var out := [_chip(X0, y, XW, h, "fut")]
	out.append(_dic(X0 + 10.0, y + (h - 34.0) * 0.5, 34.0, _svg(String(s[0]))))
	var x := X0 + 52.0
	var bw := 0.0
	if bl != "" and act != null:
		bw = Box.text_w(bl, 10.5, 800) + 22.0
		out.append(_btn(X0 + XW - 8.0 - bw, y + (h - 26.0) * 0.5, bw, 26.0, bl, act if ok else null, "go" if ok else "off"))
	var tw := XW - 52.0 - 8.0 - (bw + 8.0 if bw > 0.0 else 0.0)
	out.append(_dt(x, y + 7.0, tw, 16.0, _fitw(nm, 12.0, 800, tw), 12.0, 800, BROWN, "left"))
	out.append(_dt(x, y + 24.0, tw, 14.0, _fitw(sm, 10.5, 700, tw), 10.5, 700, GREEN if s[3] else SUB, "left"))
	out.append(_dt(x, y + 40.0, tw, 14.0, _fitw(tx, 10.5, 600, tw), 10.5, 600, SUB, "left"))
	return out

# ------------------------------------------------------------------ tab Chỉ số
func _info(y: float, t: String, ic: String, rows: Array) -> Array:   # tiêu đề mục + thẻ kem các dòng [trái, phải, màu phải] / ["bar", tên, f, số]
	var out := _hd(y, t, ic)
	var cy := y + HDG
	var h := 8.0
	for r in rows:
		h += 22.0 if String(r[0]) == "bar" else 18.0
	h += 6.0
	out.append(_chip(X0, cy, XW, h, "fut"))
	var ry := cy + 8.0
	for r in rows:
		if String(r[0]) == "bar":
			var tw: float = Box.text_w(String(r[3]), 10.5, 800) + 4.0
			out.append(_dt(X0 + 10.0, ry, 90.0, 14.0, String(r[1]), 10.5, 700, SUB, "left"))
			out.append_array(_bar(X0 + 100.0, ry + 4.0, XW - 110.0 - tw - 6.0, float(r[2]), 6.0))
			out.append(_dt(X0 + XW - 10.0 - tw, ry, tw, 14.0, String(r[3]), 10.5, 800, GREEN, "right"))
			ry += 22.0
		else:
			var rw: float = minf(Box.text_w(String(r[1]), 10.5, 800) + 4.0, XW * 0.6)
			out.append(_dt(X0 + 10.0, ry, XW - 24.0 - rw, 14.0, _fitw(String(r[0]), 10.5, 600, XW - 24.0 - rw), 10.5, 600, SUB, "left"))
			out.append(_dt(X0 + XW - 10.0 - rw, ry, rw, 14.0, _fitw(String(r[1]), 10.5, 800, rw), 10.5, 800, String(r[2]) if r.size() > 2 else BROWN, "right"))
			ry += 18.0
	return [out, HDG + h]

func _cs() -> Array:
	var p: Dictionary = G.g.pc
	var lv: int = int(p.lv)
	var need: int = G.xp_need(lv)
	var em: float = G.en_max()
	var out := []
	var y := 13.0
	var S := []
	S.append(["Cấp, kinh nghiệm", "d:gift", [["Cấp", str(lv)], ["bar", "Kinh nghiệm", float(p.xp) / maxf(1.0, need), G.fmt_n(int(p.xp)) + "/" + G.fmt_n(need)],
		["Đã làm", G.fmt_n(int(p.get("n", 0))) + " việc"]]])
	S.append(["Thể lực", "lua", [["bar", "Sức", float(p.en) / maxf(1.0, em), str(int(floor(float(p.en)))) + "/" + str(int(em))],
		["Tự hồi", "4 sức mỗi phút"], ["Hết sức", "đi chậm lại"]]])
	var sp: float = G.speed(3.0)
	S.append(["Di chuyển", "kh:pc_gui", [["Tốc độ đi", str(snappedf(sp, 0.1)).replace(".", ",") + " ô/giây"],
		["Xe đạp", "+70% khi đi xa" if p.get("xe", 0) else "chưa có", GREEN if p.get("xe", 0) else SUB],
		["Xuồng ba lá", "đã có" if p.get("xuong", 0) else "chưa có", GREEN if p.get("xuong", 0) else SUB]]])
	var tr := []
	for o in G.TOOLS:
		var t: int = G.fd(String(o.id))
		tr.append([String(o.n) + " · cấp " + str(t), G.tool_desc(String(o.id), t), GREEN if t > 0 else SUB])
	S.append(["Đồ nghề", "kh:pc_cuoc", tr])
	var b: String = G.bh()
	var f: float = G.nv.Fu()
	S.append(["Bùa", "d:bua", [["Bùa đang có", (String(G.BUFFS[b].n) + " · còn " + U.kdp.MA(G.bh_left())) if b != "" else "không", GREEN if b != "" else SUB],
		["Bùa EXP +50%", ("còn " + U.kdp.MA(f)) if f > 0.0 else "chưa dùng", GREEN if f > 0.0 else SUB]]])
	for s in S:
		var r := _info(y, String(s[0]), String(s[1]), s[2])
		out.append_array(r[0])
		y += float(r[1]) + GG
	return [out, y - GG + 2.0]

# ------------------------------------------------------------------ tab Túi đồ
func _tui() -> Array:
	var out := []
	var y := 8.0
	var F := [["", "Tất cả"], ["non", "Nón"], ["ao", "Áo"], ["quan", "Quần"], ["dep", "Dép"]]
	var g := 5.0
	var fw := (XW - g * (F.size() - 1)) / F.size()
	for i in F.size():
		var k := String(F[i][0])
		var x := X0 + i * (fw + g)
		var c := _chip(x, y, fw, 26.0, "now" if tui == k else "fut")
		c.kids = [_dt(x, y, fw, 26.0, String(F[i][1]), 10.5, 800, BROWN)]
		c.act = func(): tui = k
		out.append(c)
	y += 26.0 + GG
	out.append(_dt(X0, y, XW, 14.0, "Chưa có đồ mặc. Có đồ thì chạm ô để mặc lên.", 10.5, 600, SUB, "left"))
	y += 14.0 + GG
	var cols := 4
	var cw := (XW - 6.0 * (cols - 1)) / cols
	var av := _hb - 2.0 - y
	var rows := maxi(1, int(floor((av + 6.0) / (cw + 6.0))))   # ô vuông, số hàng vừa kín thân
	var ch := floorf((av - 6.0 * (rows - 1)) / rows)
	for i in rows * cols:
		var x := X0 + (i % cols) * (cw + 6.0)
		var cy := y + (i / cols) * (ch + 6.0)
		var c := _chip(x, cy, cw, ch, "miss")
		c.css["opacity"] = "0.6"
		var k: String = tui if tui != "" else LEFT[i % 4]
		c.kids = [_dic(x + (cw - 28.0) * 0.5, cy + (ch - 28.0) * 0.5, 28.0, _svg("pc_" + k), 0.35)]
		out.append(c)
	return [out, y + rows * (ch + 6.0) - 4.0]

# ------------------------------------------------------------------ hình nhân vật (khung đứng nhìn ra của nhân vật trên làng)
class PcPic extends Control:
	var farm
	func _process(_dt: float) -> void:
		queue_redraw()
	func _draw() -> void:
		var P = farm.P
		var m: Dictionary = P.meta("nv_walk")
		var tx: Texture2D = P.tex("nv_walk", "sheet")
		if m.is_empty() or tx == null:
			return
		var dir := 0
		var n := int(m["n"])
		var fr := int(m["stand"][dir])
		var fw := float(m["fw"])
		var fh := float(m["fh"])
		var per := maxi(1, int(tx.get_width() / fw))
		var j := dir * n + fr
		var src := Rect2((j % per) * fw, (j / per) * fh, fw, fh)
		var h := minf(size.y, size.x * fh / fw)
		var w := h * fw / fh
		draw_texture_rect_region(tx, Rect2((size.x - w) * 0.5, (size.y - h) * 0.5, w, h), src)
