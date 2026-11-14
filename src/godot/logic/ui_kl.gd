extends "res://logic/ui_ls.gd"
# KỶ LỤC (klOpen / klRender bản web, Sổ làng › Kỷ lục): bảng sổ có tab chung (ui_ls.gd), 3 tab:
# Tủ kỷ lục (lưới loại, chọn loại xem trái nặng nhất, trái khủng gần đây + Bán), Xếp hạng (chip từng loại, bảng làng),
# Hội thi (4 loại thi tuần này, kết quả tuần trước). Chưa có bạn bè: bảng chỉ có làng mình như web lúc chưa kết nối.
# Mẫu: kl_tab.json. Luật ở w_ca.gd (kl_*).

var WC2        # w_ca.gd
var tab := "tu"             # KLS.tab
var sel := ""               # KLS.sel
var rk := ""                # KLS.rk
var KT := {}

func _init(ui, wca) -> void:
	super(ui)
	WC2 = wca
	KT = Snap.load_snap("kl_tab")

func open(t := "") -> void:   # klOpen
	if t != "":
		tab = t
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
	return JSON.stringify([tab, sel, rk, WC2.kl_st(), int(WC2._now() / 60000.0)])

func _build() -> void:
	sig = _sig()
	var blocks: Array
	match tab:
		"rk":
			blocks = _rk()
		"thi":
			blocks = _thi()
		_:
			blocks = _tu()
	var n := _cl(UB)
	_seg_tabs(_find(n, "lstabs"), [["tu", "Tủ kỷ lục", false], ["rk", "Xếp hạng", false], ["thi", "Hội thi", false]], tab, _tab_go, {})
	var vt := _find(n, "lsbody")
	if tab == "rk":   # .lstools: hàng chip trên thân
		var tl := _cl(KT.tools)
		_rk_chips(tl.kids[0])
		var card := _find(n, "khcard")
		card.kids.insert(card.kids.find(vt), tl)
		var y1 := float(tl.r[1]) + float(tl.r[3]) + 6.0
		vt.r[3] = float(vt.r[1]) + float(vt.r[3]) - y1
		vt.r[1] = y1
	_show(n, vt, blocks, 3.0)
	var cr = ids.get(".khchips")
	if cr != null:
		cr._kids.clip_contents = true
	U._layout()

func _tab_go(k: String) -> void:   # data-kt
	if tab != k:
		tab = k
		scroll = 0.0
		chx = 0.0

func input(e: InputEvent) -> bool:
	if on and tab == "rk" and _chips_drag(e):
		return true
	return super(e)

# ------------------------------------------------------------------ khối
func _sum_k(runs: Array) -> Dictionary:   # p.lssum với <b>
	var p := _cl(KT.sum)
	var sb: Dictionary = p.kids[0]
	var sp := _cl(p)
	sp.erase("kids")
	var h := _put(p, runs.map(func(z): return _r(String(z[0]), sb if z[1] else sp)))
	p.r[3] = h
	return p

func _secs(t: String, small := "") -> Dictionary:   # .vl-sec (+ small)
	var c := _cl(KT.secs if small != "" else KT.sec)
	c.cls = "vl-sec"
	var b: Dictionary = c.kids[0]
	var x := float(c.r[0])
	var y := float(c.r[1])
	var hb := _put(b, [_r(t, _cl(b))], "left", 305.0)
	b.r = [x, y, 305.0, hb]
	var h := hb
	if small != "":
		var sm: Dictionary = c.kids[1]
		var sy := y + hb + 3.0
		sm.r = [x, sy, 305.0, 0.0]
		var hs := _put(sm, [_r(small, _cl(sm))], "left", 305.0)
		sm.r[3] = hs
		h = sy + hs - y
	c.r[3] = h
	return c

func _note_k(s: String) -> Dictionary:   # p.note
	var p := _cl(KT.note)
	var h := _put(p, [_r(s, _cl(p))])
	p.r[3] = h
	return p

func _tile(id: String, f, x: float, y: float) -> Dictionary:   # button.kltile (.no chưa có, .on đang chọn, ★ hạng kỷ lục)
	var c := _cl(KT.tile_on if sel == id else (KT.tile if f != null else KT.tile_no))
	var star := {}
	for k in KT.tile.kids:
		if String(k.get("cls", "")) == "klst":
			star = k
	_mv(c, x, y)
	var K: Array = c.kids
	var ic: Dictionary = K[0]
	var b: Dictionary = K[1]
	var sm: Dictionary = K[2]
	_ic(ic, id)
	if f == null:
		ic.css.opacity = "0.35"
	var nm: String = WC2.kl_name(id)
	var bw := _tw(b, nm)
	b.text = nm
	b.r = [x + (98.7 - bw) * 0.5, b.r[1], bw, b.r[3]]
	b.tr = b.r.duplicate()
	var v: String = WC2.kl_kg(float(f.g), id) if f != null else "Chưa có"
	var sw := _tw(sm, v)
	sm.text = v
	sm.r = [x + (98.7 - sw) * 0.5, sm.r[1], sw, sm.r[3]]
	sm.tr = sm.r.duplicate()
	var kids := [ic, b, sm]
	if f != null and int(f.h) == 3 and not star.is_empty():
		var st := _cl(star)
		_mv(st, x + 84.0, y + 3.0 - 0.0)
		kids.append(st)
	c.kids = kids
	c.act = _sel.bind(id)
	return c

func _grid(L: Array, k: Dictionary) -> Dictionary:   # .klgrid 3 cột
	var y := 0.0
	var out := []
	for i in L.size():
		out.append(_tile(String(L[i]), k.b.get(L[i]), 16.5 + (i % 3) * 103.2, (i / 3) * 61.1))
	var rows := int(ceil(L.size() / 3.0))
	return {"z": 0.75, "tag": "div", "id": "", "cls": "klgrid", "r": [16.5, 0.0, 305.0, maxf(0.0, rows * 61.1 - 4.4)], "css": {"display": "block", "position": "static"}, "kids": out}

func _sel(id: String) -> void:   # data-ks
	sel = "" if sel == id else id

func _info(f: Dictionary) -> Dictionary:   # .vlcard > ul.klinfo
	var c := _cl(KT.info)
	var ul: Dictionary = c.kids[0]
	var li0: Dictionary = ul.kids[0]
	var y := float(ul.r[1])
	var out := []
	for r in WC2.kl_info(f):
		var li := _cl(li0)
		_mv(li, float(li0.r[0]), y)
		var sp: Dictionary = li.kids[0]
		var b: Dictionary = li.kids[1]
		var sw := _tw(sp, String(r[0]))
		sp.text = r[0]
		sp.r[2] = sw
		sp.tr = sp.r.duplicate()
		var bw := _tw(b, String(r[1]))
		b.text = r[1]
		b.r = [float(li.r[0]) + float(li.r[2]) - bw, b.r[1], bw, b.r[3]]
		b.tr = b.r.duplicate()
		out.append(li)
		y += 15.65
	ul.kids = out
	ul.r[3] = y - 15.65 + 12.7 - float(ul.r[1])
	c.r[3] = float(ul.r[3]) + 15.0
	return c

func _rows_k(rows: Array) -> Dictionary:   # .lslist > .lsrow (hình + chữ + nút Bán)
	var ls := _cl(KT.list)
	var y := float(ls.r[1])
	var out := []
	for R in rows:
		var c := _cl(KT.row)
		_mv(c, float(ls.r[0]), y)
		var K: Array = c.kids
		_ic(K[0], String(R.id))
		var nm: Dictionary = K[1]
		nm.kids[0].text = R.b
		nm.kids[1].text = R.s
		var bt: Dictionary = K[2]
		var tw := _tw(bt, String(R.btn))
		var bw := tw + _px(bt, "padding-left") + _px(bt, "padding-right") + 2.0
		var bx := float(c.r[0]) + 305.0 - 6.0 - bw
		bt.r = [bx, bt.r[1], bw, bt.r[3]]
		bt.text = R.btn
		bt.tr = [bx + (bw - tw) * 0.5, bt.tr[1], tw, bt.tr[3]]
		bt.act = R.act
		nm.r[2] = bx - 6.0 - float(nm.r[0])
		out.append(c)
		y += 33.0 + 3.75
	ls.kids = out
	ls.r[3] = maxf(0.0, y - 3.75 - float(ls.r[1]))
	return ls

func _board(id: String, L: Array, empty: String) -> Dictionary:   # klBoard
	if L.is_empty():
		return _note_k(empty)
	var ls := _cl(KT.list)
	var y := float(ls.r[1])
	var out := []
	for i in L.size():
		var x: Dictionary = L[i]
		var c := _cl(KT.rk)
		_mv(c, float(ls.r[0]), y)
		var K: Array = c.kids
		K[0].text = str(i + 1)
		K[1].kids[0].text = String(x.n) + (" (bạn)" if x.get("me", false) else "")
		var g: Dictionary = K[2]
		var v: String = WC2.kl_kg(float(x.g), id)
		var gw := _tw(g, v)
		g.text = v
		g.r = [float(c.r[0]) + 305.0 - 6.0 - gw, g.r[1], gw, g.r[3]]
		g.tr = g.r.duplicate()
		out.append(c)
		y += 33.0 + 3.75
	ls.kids = out
	ls.r[3] = y - 3.75 - float(ls.r[1])
	return ls

# ------------------------------------------------------------------ tab Tủ kỷ lục
func _tu() -> Array:
	var k: Dictionary = WC2.kl_st()
	var ids: Array = WC2.kld().keys()
	var got := ids.filter(func(id): return k.b.has(id)).size()
	var runs := [["Đã có ", false], [str(got) + "/" + str(ids.size()), true], [" loại · ", false], [str(int(k.get("n", 0))), true], [" trái khủng", false]]
	if k.tt.size():
		runs += [[" · Danh hiệu: ", false], [String(k.tt[0]), true]]
	var out := [_sum_k(runs)]
	var L0 := ids.filter(func(id): return not WC2.lai_la(id))
	var L1 := ids.filter(func(id): return WC2.lai_la(id))
	out.append(_grid(L0, k))
	if L1.size():
		out.append(_secs("Giống quý", "Giống lai: trái khủng ra gấp 3, nặng hơn cây gốc. Hạt chỉ có khi lai."))
		out.append(_grid(L1, k))
	var f = k.b.get(sel)
	if f != null:
		out.append(_secs(WC2.kl_name(String(f.id)) + " nặng nhất"))
		out.append(_info(f))
	var rows := []
	for i in k.r.size():
		var x: Dictionary = k.r[i]
		if sel != "" and x.id != sel:
			continue
		rows.append({"id": x.id, "b": WC2.kl_name(String(x.id)) + " · " + WC2.kl_kg(float(x.g), String(x.id)), "s": WC2.KLHANG[int(x.h)] + (" · " + String(x.who) + " gặt" if String(x.get("who", "")) != "" else ""),
			"btn": "Bán " + WC2._sa(WC2.kl_price(x)), "act": WC2.kl_sell.bind(i)})
	if rows.size():
		out.append(_secs("Trái khủng gần đây", "Bán được giá cao gấp nhiều lần trái thường."))
		out.append(_rows_k(rows))
	return out

# ------------------------------------------------------------------ tab Xếp hạng
func _rk_chips(row: Dictionary) -> void:
	var k: Dictionary = WC2.kl_st()
	if rk == "" or not WC2.kld().has(rk):
		rk = String(k.b.keys()[0]) if k.b.size() else "lua"
	var on_t: Dictionary = row.kids[0]
	var off_t: Dictionary = row.kids[1]
	var x := float(row.r[0])
	var out := []
	var onr := [0.0, 0.0]
	for id in WC2.kld():
		var a: bool = id == rk
		var c := _cl(on_t if a else off_t)
		var sp: Dictionary = c.kids[0]
		var t: String = WC2.kl_name(id)
		var tw := _dw(sp, t)
		var w := tw + 18.0
		_mv(c, x, float(on_t.r[1]))
		c.r[2] = w
		sp.text = t
		sp.r = [x + 9.0, float(on_t.r[1]) + 8.8, tw, sp.r[3]]
		sp.tr = sp.r.duplicate()
		c.act = _rk_go.bind(id)
		if a:
			onr = [x, x + w]
		out.append(c)
		x += w + 4.5
	_chips_keep(out, onr, x - 4.5)
	row.kids = out

func _rk_go(id: String) -> void:   # data-kr
	rk = id

func _rk() -> Array:
	var k: Dictionary = WC2.kl_st()
	var mine = k.b.get(rk)
	var L := [{"n": WC2.os_name(), "me": true, "g": float(mine.g)}] if mine != null else []
	return [_board(rk, L, "Chưa làng nào có " + WC2.kl_name(rk).to_lower() + " khủng.")]

# ------------------------------------------------------------------ tab Hội thi
func _thi() -> Array:
	var k: Dictionary = WC2.kl_st()
	var w: int = WC2.m_r()
	var cur: Array = WC2.kl_thi(w)
	var prev: Array = WC2.kl_thi(w - 1)
	var left := maxf(0.0, ceil(((w + 1) * 7 - 3) * 86400000.0 - WC2._now()) / 3600000.0)
	var out := [_sum_k([["Tuần này thi 4 loại (loại cuối là giống quý), mỗi loại lấy trái nặng nhất gặt trong tuần. Còn ", false],
		[(str(int(floor(left / 24.0))) + " ngày " if left >= 24.0 else "") + str(int(round(fmod(left, 24.0)))) + " giờ", true], [".", false]])]
	for id in cur:
		if id == "":
			continue
		var my = k.wk.b.get(id)
		out.append(_secs(WC2.kl_name(id), "Của bạn tuần này: " + (WC2.kl_kg(float(my), id) if my != null else "chưa có")))
		out.append(_board(id, WC2.kl_thi_rank(w, id).slice(0, 5), "Chưa ai dự thi."))
	out.append(_secs("Kết quả tuần trước", "Hạng 1–3 mỗi loại nhận xu, sen đỏ; hạng 1 có danh hiệu Vua."))
	for id in prev:
		if id == "":
			continue
		var L: Array = WC2.kl_thi_rank(w - 1, id)
		var c := _cl(KT.res)
		var cl: Dictionary = c.kids[0]
		var sm: Dictionary = cl.kids[0]
		var sb: Dictionary = sm.kids[0]
		var st := _cl(sm)
		st.erase("kids")
		var txt := ""
		if L.size():
			var p := []
			for i in mini(3, L.size()):
				p.append(str(i + 1) + ". " + String(L[i].n) + " " + WC2.kl_kg(float(L[i].g), id))
			txt = ": " + " · ".join(PackedStringArray(p))
		else:
			txt = ": không ai dự thi"
		var h := _put(sm, [_r(WC2.kl_name(id), sb), _r(txt, st)], "left", 287.0)
		sm.r[3] = h
		cl.r[3] = h + 2.0
		c.r[3] = h + 2.0 + 15.0
		out.append(c)
	out.append(_note_k("Chưa kết nối mạng nên chưa thấy làng khác."))
	return out
