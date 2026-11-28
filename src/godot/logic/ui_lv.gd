extends "res://logic/ui_kbang.gd"
# (11-28) Bảng LÊN CẤP (QH / TJ / KH / iL bản web) trên khung chung (ui_kbang: khung sen, co vừa nội dung, đáy chung),
#   thay bảng chụp web cũ (lv5.json: đầu xanh riêng, ô ảnh trơn, lưới quà bị cắt đáy).
#   Đầu: tiêu đề mục "Lên cấp N" + chữ phụ "mở khóa K thứ mới"; thân cuộn: lưới quà 3 cột (ô chip: hình, số, tên, nhãn MỚI);
#   đáy: nút Mở quà (+ "Mở hết N cấp" khi chờ nhiều cấp).
# Quà mở khóa từng cấp: res://ui/snap/lv_qua.json (MJ bản web), hình res://ui/img/lv/; cây, món tính từ data lúc chạy (_gen).

const CH := 84.0
const CG := 6.0
var Q := {}
var _wait := 0.0
var lvT := 0.0             # aa.lvT: chữ LÊN CẤP! trên đầu nhân vật (2,5 giây)

func _init(ui) -> void:
	super(ui)
	Q = Snap.load_snap("lv_qua")
	fit = true

func open() -> void:   # QH
	var q := _queue()
	if on or q.is_empty():
		return
	for p in U._pans():
		if p != null and p.on:
			p.close()
	on = true
	scroll = 0.0
	sig = ""
	_build()
	G.vib(120)

func _sig() -> String:
	return str(_queue())

func _build() -> void:
	sig = _sig()
	var q := _queue()
	if q.is_empty():
		return
	var t := int(q[0])
	var L := gift_list(t)
	var news := 0
	for it in L:
		if it.get("em", false):
			news += 1
	var sh := _kshell([], "", func(_k): pass)
	var nd: Dictionary = sh[0]
	var vt: Dictionary = sh[1]
	_kfix(nd, vt, _hd(5.0, "Lên cấp " + str(t), "img:sen", 0.0, ("mở khóa " + str(news) + " thứ mới") if news > 0 else "chúc mừng!", GREEN), 26.0, false)
	var bt := [_btn(X0, 0.0, XW, 34.0, "Mở quà", take)]
	bt[0].kids[0].css["font-size"] = _cpx(14.0)
	var bh := 34.0
	if q.size() > 1:
		bt.append(_btn(X0, 40.0, XW, 28.0, "Mở hết " + str(q.size()) + " cấp một lần", take_all, "plain"))
		bh = 68.0
	_kfix(nd, vt, bt, bh, true)
	var out := []
	var cw := (XW - 2.0 * CG) / 3.0
	for i in L.size():
		out.append(_gift(X0 + (i % 3) * (cw + CG), (i / 3) * (CH + CG), cw, L[i], t))
	_kmount(nd, vt, float(vt.r[1]), out, ceili(L.size() / 3.0) * (CH + CG) - CG)

func _gift(x: float, y: float, w: float, it: Dictionary, t: int) -> Dictionary:   # ô quà: hình, số (xu / sen), tên, nhãn MỚI
	var k := String(it.k)
	var c := _chip(x, y, w, CH, "fut")
	var ic: Dictionary
	if k == "xu":
		ic = _dick(x + w * 0.5, y + 22.0, 30.0, "coin")
	elif k == "sen":
		ic = _dick(x + w * 0.5, y + 22.0, 30.0, "pearl")
	elif k == "svg":
		ic = _icn(x + w * 0.5, y + 24.0, 34.0, String(it.id))
	else:
		ic = _pic(x + (w - 38.0) * 0.5, y + 6.0, 38.0, 38.0, "res://ui/img/lv/" + String(it.ic) + ".png")
	c.kids = [ic]
	var ty := y + 46.0
	var b := String(it.get("b", ""))
	if k == "xu":
		b = "+" + G.fmt_n(30 * t)
	if b != "":
		c.kids.append(_dt(x, ty, w, 16.0, b, 14.0, 800, "rgb(214, 128, 20)" if k == "xu" else "rgb(196, 44, 60)"))
		ty += 16.0
	var nm := String(it.n)
	var L2 := [nm] if Box.text_w(nm, 10.5, 600) <= w - 8.0 else _wrap(nm, 10.5, 600, w - 8.0)
	for j in mini(2, L2.size()):
		c.kids.append(_dt(x + 4.0, ty + j * 13.0, w - 8.0, 14.0, _fitw(String(L2[j]), 10.5, 600, w - 8.0), 10.5, 600, SUB))
	if it.get("em", false):
		var bw: float = Box.text_w("MỚI", 10.5, 800) + 8.0
		var bd := _dbx(x + w - bw - 3.0, y + 3.0, bw, 14.0, "rgb(214, 69, 65)", 7.0)
		bd.kids = [_dt(x + w - bw - 3.0, y + 3.0, bw, 14.0, "MỚI", 10.5, 800, "rgb(255, 255, 255)")]
		c.kids.append(bd)
	return c

func _queue() -> Array:
	if not (G.g.get("lvq") is Array):
		G.g.lvq = []
	return G.g.lvq

# ------------------------------------------------------------------ quà từng cấp (bản 343)
var GEN := {}    # cấp -> {"cay": [...], "mon": [...]}

func gift_list(t: int) -> Array:   # xu, sen, cây, xưởng / chuồng, món, chức năng / đất / địa danh
	if GEN.is_empty():
		_gen()
	var head := []
	var cv := []
	var emo := []
	for it in Q.get(str(t), []):
		var k := String(it.k)
		if k == "xu" or k == "sen":
			head.append(it)
		elif k == "cv":
			cv.append(it)
		elif k == "emo":
			emo.append(it)
	var g: Dictionary = GEN.get(t, {})
	return head + g.get("cay", []) + cv + g.get("mon", []) + emo

func _gen() -> void:
	var D = G.D
	var lai: Dictionary = G._j("nong_trai/giong_lai")
	var at := {}   # vật phẩm -> cấp có được
	for k in D.crops:
		at[k] = int(D.crops[k].lv)
		if not lai.has(k):
			_add(int(D.crops[k].lv), "cay", {"n": String(D.crops[k].name), "id": k, "k": "svg", "em": true})
	var ei: Dictionary = G._j("nong_trai/cay_an_trai")
	var ct: Dictionary = G._j("xay_dung/cong_trinh")
	for f in ei:
		var q := String(ei[f].p)
		at[q] = mini(int(at.get(q, 999)), int(ei[f].lv))
		_add(int(ei[f].lv), "cay", {"n": "Cây " + String(ct.get(f, {}).get("n", G.item_name(q))).to_lower(), "id": q, "k": "svg", "em": true})
	var an: Dictionary = G._j("vat_nuoi/vat_nuoi")
	var cm: Dictionary = G._j("vat_nuoi/chuong_mo_cap")
	for a in an:
		for m in [an[a].get("make", ""), an[a].get("make2", "")]:
			if m != "":
				at[m] = mini(int(at.get(m, 999)), int(cm.get(a, 1)))
	var ws: Array = G.xw.T.keys()
	ws.sort_custom(func(a, b): return int(G.xw.T[a].lv) < int(G.xw.T[b].lv))
	var memo := {}
	for w in ws:
		for r in G.xw.T[w].rec:
			var l := _rl(String(r), at, memo, {})
			if l <= 100:
				_add(maxi(l, 2), "mon", {"n": G.item_name(String(r)), "id": r, "k": "svg", "em": true})

func _rl(r: String, at: Dictionary, memo: Dictionary, seen: Dictionary) -> int:   # cấp sớm nhất có món r
	if memo.has(r):
		return memo[r]
	if at.has(r):
		return at[r]
	var R: Dictionary = G.xw.R
	if not R.has(r) or seen.has(r) or not G.xw.T.has(String(R[r].w)) or not G.xw.T[R[r].w].rec.has(r):
		return 1 if not R.has(r) else 999   # đồ câu / bắt / mua: có sẵn
	seen[r] = true
	var l := int(G.xw.T[R[r].w].lv)
	for p in R[r]["in"]:
		l = maxi(l, _rl(String(p[0]), at, memo, seen))
	memo[r] = l
	return l

func _add(t: int, kind: String, it: Dictionary) -> void:
	if not GEN.has(t):
		GEN[t] = {"cay": [], "mon": []}
	GEN[t][kind].append(it)

# ------------------------------------------------------------------ nhận (TJ / KH)
func take() -> void:   # TJ: nhận quà 1 cấp
	var q := _queue()
	if q.is_empty():
		close()
		return
	var t := int(q.pop_front())
	var a := 30 * t
	G.g.coins = int(G.g.coins) + a
	if t % 5 == 0:
		G.g.ngoc = int(G.g.get("ngoc", 0)) + 3
	G.toast.emit("Nhận " + G.fmt_n(a) + " xu quà lên cấp " + str(t) + ".")
	G.mark()
	close()
	if not q.is_empty():
		_wait = 0.45

func take_all() -> void:   # KH: nhận hết các cấp đang chờ
	var q := _queue()
	var t := 0
	var a := 0
	var n := 0
	while not q.is_empty():
		var r := int(q.pop_front())
		t += 30 * r
		if r % 5 == 0:
			a += 3
		n += 1
	G.g.coins = int(G.g.coins) + t
	if a:
		G.g.ngoc = int(G.g.get("ngoc", 0)) + a
	G.toast.emit("Nhận quà " + str(n) + " cấp: " + G.fmt_n(t) + " xu" + ((", " + str(a) + " sen đỏ") if a else "") + ".")
	G.mark()
	close()

func step(dt: float) -> void:
	lvT = maxf(0.0, lvT - dt)
	if _wait > 0.0:
		_wait -= dt
		if _wait <= 0.0:
			open()
		return
	if not on and not _queue().is_empty():
		open()
	super(dt)
