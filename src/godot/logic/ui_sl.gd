extends "res://logic/ui_bang.gd"
# SỔ LÀNG (i4 bản web, mô-đun bk2: nút "Sổ làng" trong Menu): khung chung với Kho (ui_bang.gd).
# Đầu bảng .bk2top (thanh danh hiệu, nút 🏆), 3 tab .bk2tabs: Làng (lưới thẻ lối vào), Danh hiệu (Bs, nhận thưởng cV),
# Bộ sưu tập (hàng chip .khchips + lưới món đã gặp Tc().seen / công trình Tc().obj).
# Mẫu: ui/snap/sl.json (khung), sl_tab.json (khối mẫu). Luật danh hiệu ở w_ca.gd, dòng phụ thẻ ở w_lang.gd.

var WCA        # w_ca.gd (Tc, Bs, cV, aB)
var W          # w_lang.gd (dòng phụ, chấm đỏ)
var WH         # w_htx.gd (Lf: sạp quê)
var tab := "lang"        # t
var bs := "ns"           # a: chip bộ sưu tập
var chx := 0.0           # khchips.scrollLeft
var hd = null            # kéo ngang hàng chip
var SB := {}             # #pov Sổ làng
var ST := {}             # khối mẫu
const SOON := "Phần này đang chuyển qua bản Godot."

func _init(ui, wca, wl, wh) -> void:
	super(ui)
	WCA = wca
	W = wl
	WH = wh
	SB = Snap.load_snap("sl")["#pov"][0]
	ST = Snap.load_snap("sl_tab")

func open() -> void:   # Al("book"): luôn về tab Làng
	tab = "lang"
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
	_sig_t = 0.5
	if _sig() != sig:
		_build()

func _sig() -> String:
	var cur := []
	for t in WCA.bs_list():
		cur.append(WCA.bs_cur(t.id))
	var s := [tab, bs, WCA.tc(), cur]
	if tab == "lang":
		s.append(_links().map(func(g): return g[2].map(func(r): return [r[3], r[4]])))
	return JSON.stringify(s)

# ------------------------------------------------------------------ dữ liệu thẻ lối vào (o())
func _links() -> Array:   # [[tên nhóm, lớp, [[khóa, tên, hình, dòng phụ, chấm đỏ]]]]
	var cp: int = WH.lf().list.size() if WH != null else 0
	return [["Bà con lối xóm", "ng", [["gp", "Gia phả", "giapha", W.gp_bk_sub(), 0],
			["kh", "Khách thăm", "khach", "Thăm làng bạn bè", 0],
			["hr", "Làm thuê", "lam", "Thuê người phụ việc", 0],
			["hui", "Hụi làng", "hui", W.hui_bk_sub(), 0],
			["ut", "Uy tín làng", "uytin", W.ut_bk_sub(), W.ut_red()],
			["tn", "Thiên tai, hoạn nạn", "thientai", W.tn_bk_sub(), W.tn_red()],
			["hdn", "Hội đình", "hoidinh", W.hdn_bk_sub(), 0]]],
		["Tin tức trong làng", "tt", [["st", "Chuyện làng", "chuyen", W.clg_bk_sub(), W.clg_red()],
			["gd", "Sổ tay", "sotay", "Cách chơi, mẹo hay", 0],
			["rk", "Xếp hạng", "hang", "Bảng tuần này", 0]]],
		["Vui chơi, sự kiện", "vc", [["kl", "Kỷ lục", "kyluc", W.kl_bk_sub(), 0],
			["cp", "Sạp quê", "cho", "Đang bày " + str(cp) + " món" if cp else "Mua bán với bạn bè", 0],
			["dl", "Du lịch", "dulich", "Chưa mở", 0]]]]

func _cols() -> Array:   # c(): [khóa, tên, danh sách, là công trình, data-f]
	return [["ns", "Nông sản", WCA.book_ns(), false], ["tc", "Trái cây", WCA.book_tc(), false],
		["mon", "Món", WCA.book_mon(), false], ["ca", "Cá", WCA.Wf, false], ["ct", "Công trình", WCA.book_ct(), true]]

# ------------------------------------------------------------------ dựng
func _build() -> void:
	sig = _sig()
	var n := _cl(SB)
	var bb := _find(n, "khcard")
	var vt := _find(n, "bk2v")
	_top(n)
	var M: Dictionary = WCA.tc()
	var rt := 0
	for t in WCA.bs_list():
		if WCA.tb(t):
			rt += 1
	var bd := {}
	if rt:
		bd = _cl(ST.ttdot)
		bd.text = str(rt)
	var L := [["lang", "Làng", false], ["dh", "Danh hiệu", rt > 0], ["bst", "Bộ sưu tập", false]]
	_seg_tabs(_find(n, "bk2tabs"), L, tab, _tab_go, bd)
	var blocks: Array
	var top := 3.0
	match tab:
		"dh":
			blocks = _dh(M)
		"bst":
			blocks = _bst(M, bb, vt)
		_:
			blocks = _lang()
	_show(n, vt, blocks, top)
	var cr = ids.get(".khchips")
	if cr != null:
		cr._kids.clip_contents = true
	_wire_extra(box)
	U._layout()

func _tab_go(k: String) -> void:   # data-bkt
	if tab != k:
		tab = k
		scroll = 0.0

func _top(n: Dictionary) -> void:   # .bk2top: thanh N/8, "Danh hiệu: <b>", nút 🏆
	var tp := _find(n, "bk2top")
	var M: Dictionary = WCA.tc()
	var Bs: Array = WCA.bs_list()
	var N := 0
	for t in Bs:
		if W._tr(M.tt.get(t.id)):
			N += 1
	var bar := _find(tp, "kcbar")
	var bi: Dictionary = bar.kids[0]
	_fill(bi, float(bar.r[2]) * N / maxf(1.0, Bs.size()))
	var wr := _find(tp, "khworth2")
	var b: Dictionary = wr.kids[0]
	var R = WCA.ab()
	b.text = String(R.n) if R != null else "chưa có"
	var bw := _tw(b, String(b.text))
	b.r[2] = bw
	b.tr = [b.r[0], b.tr[1], bw, b.tr[3]]
	var st := _find(tp, "khst")
	var cp := _find(st, "khcap")
	cp.text = "🏆 " + str(N) + "/" + str(Bs.size())
	st.act = _tab_go.bind("dh")

static func _fill(i: Dictionary, w: float) -> void:   # .kcbar > i (width %): vệt sáng ::after cách hai đầu 5px
	i.r[2] = w
	var af: Dictionary = i.get("::after", {})
	var aw := w / _z(i) - 10.0
	if aw <= 0.0:
		i.erase("::after")
	elif af.has("w"):
		af.w = str(aw) + "px"

# ------------------------------------------------------------------ tab Làng: lưới thẻ 3 cột
func _lang() -> Array:
	var out := []
	for G0 in _links():
		var gh := _cl(ST.gh)
		gh.text = G0[0]
		_gh_line(gh)
		if out.size():
			gh.gap = 9.0
		out.append(gh)
		var row := []
		for r in G0[2]:
			row.append(_link(G0[1], r))
			if row.size() == 3:
				out.append(_row(row, 98.67))
				row = []
		if row.size():
			out.append(_row(row, 98.67))
	return out

func _gh_line(gh: Dictionary) -> void:   # li.khgh::after: vạch mờ dần từ sau chữ tới mép phải
	gh.erase("::after")
	var x0 := float(gh.r[0]) + _tw(gh, String(gh.text)) + 6.75
	var x1 := float(gh.r[0]) + float(gh.r[2])
	gh.kids = [{"z": _z(gh), "tag": "i", "id": "", "cls": "", "r": [x0, float(gh.r[1]) + float(gh.r[3]) * 0.5 - 0.56, x1 - x0, 1.125],
		"css": {"display": "block", "position": "absolute", "background-image": "linear-gradient(90deg, rgba(150, 112, 48, 0.45), rgba(150, 112, 48, 0))"}}]

func _row(cards: Array, w: float) -> Dictionary:   # một hàng lưới: thẻ cao bằng thẻ cao nhất
	var h := 0.0
	for c in cards:
		h = maxf(h, float(c.r[3]))
	var x := 16.5
	for c in cards:
		_mv(c, x, 0.0)
		_grow(c, h)
		x += w + 4.5
	return {"z": 0.75, "tag": "div", "id": "", "cls": "bk2row", "r": [16.5, 0.0, 305.0, h], "css": {"display": "block", "position": "static"}, "kids": cards, "gap": 4.5}

static func _grow(c: Dictionary, h: float) -> void:   # li + nút/khối con đầu cao theo hàng
	c.r[3] = h
	if c.get("kids", []).size():
		c.kids[0].r[3] = h

func _link(g: String, r: Array) -> Dictionary:   # li.khit.g-* > button.bk2l
	var li := _cl(ST[g])
	var bt: Dictionary = li.kids[0]
	var x := float(li.r[0])
	var y := float(li.r[1])
	var sp: Dictionary = _tag_kids(bt, "span")[0]
	var b: Dictionary = _tag_kids(bt, "b")[0]
	var sm: Dictionary = _tag_kids(bt, "small")[0]
	var ic: Dictionary = sp.kids[0]
	ic.svg = ST.icons[r[2]]
	var W0 := float(bt.r[2]) - 6.0
	var by := y + 47.25
	b.r = [x + 3.0, by, W0, 0.0]
	var hb := _put(b, [_r(String(r[1]), _cl(b))], "center")
	b.r[3] = hb
	var sy := by + hb + 3.75
	sm.r = [x + 3.0, sy, W0, 0.0]
	var hs := _put(sm, [_r(String(r[3]), _cl(sm))], "center")
	sm.r[3] = hs
	var h := sy + hs + 7.5 - y
	bt.kids = []
	if r[4]:
		var rd := _cl(ST.red)
		_mv(rd, x + 85.9, y + 6.0)
		bt.kids.append(rd)
	bt.kids += [sp, b, sm]
	bt.act = _go.bind(String(r[0]))
	li.r[3] = h
	bt.r[3] = h
	return li

func _go(k: String) -> void:   # data-gp / data-kh / data-hr / data-ut / ...: bảng con chưa chuyển
	U.say(SOON)

# ------------------------------------------------------------------ tab Danh hiệu
func _dh(M: Dictionary) -> Array:
	var dt := []
	for t in WCA.bs_list():
		var c := mini(int(t.max), WCA.bs_cur(t.id))
		var got: bool = W._tr(M.tt.get(t.id))
		dt.append({"t": t, "c": c, "got": got, "rd": not got and c >= int(t.max)})
	dt.sort_custom(func(D, E):
		if D.rd != E.rd:
			return D.rd
		if D.got != E.got:
			return E.got
		return float(D.c) / float(D.t.max) > float(E.c) / float(E.t.max))
	var out := []
	for D in dt:
		var li := _cl(ST.dh_got if D.got else (ST.dh_rd if D.rd else ST.dh))
		var tt: Dictionary = li.kids[0]
		var tx: Dictionary = tt.kids[0]
		var ra: Dictionary = D.t
		var x := float(tx.r[0])
		var y := float(tx.r[1])
		var W0 := float(tx.r[2])
		var b: Dictionary = tx.kids[0]
		var sm: Dictionary = tx.kids[1]
		var bar: Dictionary = tx.kids[2]
		var em: Dictionary = tx.kids[3]
		b.r = [x, y, W0, 0.0]
		var hb := _put(b, [_r(String(ra.n), _cl(b))])
		b.r[3] = hb
		var sy := y + hb + 1.5
		sm.r = [x, sy, W0, 0.0]
		var hs := _put(sm, [_r(String(ra.d), _cl(sm))])
		sm.r[3] = hs
		_mv(bar, x, sy + hs)
		_fill(bar.kids[0], W0 * float(D.c) / float(ra.max))
		var et: String = str(D.c) + "/" + str(ra.max) + " · thưởng " + W._sa(ra.xu)
		var ey := sy + hs + 13.5
		var xi: Dictionary = em.kids[0]
		_mv(em, x, ey)
		var ew := _dw(em, et + " ")
		em.text = et
		em.tr = [x, ey, _dw(em, et), em.tr[3]]
		em.r[2] = ew + float(xi.r[2])
		_mv(xi, x + ew, ey)
		var h := ey + 9.0 + 9.0 - float(li.r[1])
		var dh := h - float(li.r[3])
		li.r[3] = h
		tt.r[3] = h
		tx.r[3] = ey + 9.0 - y
		if tt.kids.size() > 1:   # nút Nhận / dấu ✓ giữa thẻ
			var k: Dictionary = tt.kids[1]
			Snap._move(k, Vector2(0, dh * 0.5))
			if D.rd:
				k.act = WCA.cv.bind(String(ra.id))
		if out.size():
			li.gap = 4.5
		out.append(li)
	return out

# ------------------------------------------------------------------ tab Bộ sưu tập
func _bst(M: Dictionary, bb: Dictionary, vt: Dictionary) -> Array:
	var W5 := _cols()
	var K: Array = W5[0]
	for D in W5:
		if D[0] == bs:
			K = D
	# hàng chip (.khtools > .khchips) nằm trên lưới; lưới thấp xuống
	var tl := _cl(ST.tools)
	var row: Dictionary = tl.kids[0]
	var off: Array = []
	for i in 5:
		off.append(ST.tools2.kids[0].kids[0] if i == 0 else ST.tools.kids[0].kids[i])
	var on_t: Dictionary = ST.tools.kids[0].kids[0]
	var x := 16.5
	var chips := []
	var onr := [0.0, 0.0]
	for i in 5:
		var D: Array = W5[i]
		var ra := 0
		for e in D[2]:
			if W._tr(M.obj.get(e) if D[3] else M.seen.get(e)):
				ra += 1
		var a: bool = D == K
		var c := _cl(on_t if a else off[i])
		if a:
			c["::before"].mask = off[i]["::before"].mask
		var sp: Dictionary = c.kids[0]
		var em: Dictionary = c.kids[1]
		var et := str(ra) + "/" + str(D[2].size())
		var sw := _dw(sp, String(D[1]))
		var ew := _dw(em, et)
		var w := 7.5 + 12.0 + 3.75 + sw + 6.0 + ew + 9.0
		_mv(c, x, float(c.r[1]))
		c.r[2] = w
		sp.text = D[1]
		sp.r = [x + 23.25, sp.r[1], sw, sp.r[3]]
		sp.tr = sp.r.duplicate()
		em.text = et
		em.r = [x + 23.25 + sw + 6.0, em.r[1], ew, em.r[3]]
		em.tr = em.r.duplicate()
		c.act = _bs_go.bind(String(D[0]))
		if a:
			onr = [x, x + w]
		chips.append(c)
		x += w + 4.5
	# giữ chip đang chọn trong khung (như web: scrollLeft += lố + 8)
	var vw := [16.5 + chx, 321.5 + chx]
	if onr[1] > vw[1]:
		chx += onr[1] - vw[1] + 6.0
	elif onr[0] < vw[0]:
		chx -= vw[0] - onr[0] + 6.0
	chx = clampf(chx, 0.0, maxf(0.0, x - 4.5 - 321.5))
	for c in chips:
		Snap._move(c, Vector2(-chx, 0))
	row.kids = chips
	row.cls = "khchips"
	var ks: Array = bb.kids
	ks.insert(ks.find(vt), tl)
	vt.r[1] = 239.16
	vt.r[3] = 354.34
	vt.cls = "khgrid bk2v bk2grid"
	# lưới 4 cột
	var out := []
	var cur := []
	for D in K[2]:
		cur.append(_kb(D, K[3], M))
		if cur.size() == 4:
			out.append(_row(cur, 72.88))
			cur = []
	if cur.size():
		out.append(_row(cur, 72.88))
	if out.size():
		out[0].erase("gap")
	return out

func _bs_go(k: String) -> void:   # data-bks
	if bs != k:
		bs = k
		scroll = 0.0

func _kb(id: String, ct: bool, M: Dictionary) -> Dictionary:   # li.khit > .khb(.no) > span.khic + span.khnm
	var seen: bool = W._tr(M.obj.get(id) if ct else M.seen.get(id))
	var li := _cl(ST.kb_cv if ct else (ST.kb if seen else ST.kb_no))
	var kb: Dictionary = li.kids[0]
	var ic: Dictionary = kb.kids[0]
	var nm: Dictionary = kb.kids[1]
	if ct:
		ic.kids[0].th = id
		ic.kids[0].sil = not seen
		kb.cls = "khb" if seen else "khb no"
	else:
		_ic(ic, id)
		ic.sil = not seen
	var s := "???"
	if seen:
		s = String(G.lang.Pi[id].n) if ct and G.lang != null and G.lang.Pi.has(id) else String(G.item(id).get("name", id))
	var x := float(li.r[0])
	nm.r = [x + 1.5, nm.r[1], 69.88, 0.0]
	var h := _put(nm, [_r(s, _cl(nm))], "center")
	nm.r[3] = h
	var hh := float(li.r[3]) + maxf(0.0, h - 12.06)
	li.r[3] = hh
	kb.r[3] = hh
	return li

# hình công trình (canvas lg) và bóng đen mờ của món chưa gặp (.khb.no: brightness(0), opacity .13)
func _wire_extra(b: Control) -> void:
	var n: Dictionary = b.get_meta("snap", {})
	if n.has("th") and U.bdp != null:
		U.bdp._icon(b, ["id", String(n.th)], false)
	if n.get("sil", false):
		b.modulate = Color(0, 0, 0, 0.13)
	for k in b.kids():
		_wire_extra(k)

# ------------------------------------------------------------------ kéo ngang hàng chip
func input(e: InputEvent) -> bool:
	if on and tab == "bst" and box != null:
		var row = ids.get(".khchips")
		if (e is InputEventScreenTouch or e is InputEventMouseButton) and row != null:
			if e is InputEventMouseButton and e.button_index != MOUSE_BUTTON_LEFT:
				return super(e)
			var p: Vector2 = e.position / Css.K
			if e.pressed:
				var gr := Rect2(row.get_global_rect().position / Css.K, row.r.size)
				hd = {"x0": p.x, "s0": chx, "moved": false} if gr.has_point(p) else null
			elif hd != null:
				if hd.moved:
					sig = ""
				hd = null
		elif (e is InputEventScreenDrag or e is InputEventMouseMotion) and hd != null:
			var p: Vector2 = e.position / Css.K
			var d: float = p.x - hd.x0
			if absf(d) > 6.0:
				hd.moved = true
				moved_t = true
			if hd.moved and row != null:
				var mx := 0.0
				for c in row.kids():
					mx = maxf(mx, c.r.end.x + chx)
				var nx := clampf(hd.s0 - d, 0.0, maxf(0.0, mx - row.r.size.x))
				for c in row.kids():
					U._move(c, c.r.position - Vector2(nx - chx, 0))
				chx = nx
			return true
	return super(e)
