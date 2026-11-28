extends "res://logic/ui_kbang.gd"
# (11-28) BẢNG CỬA HÀNG XÂY DỰNG (k() bản web) trên khung chung (ui_kbang: khung sen, tab chung, chip lọc chung, đáy chung),
#   thay bảng chụp web cũ (bc_<mục>.json / bdx.json) của ui_bd.gd. Luật, thẻ, hình thẻ, đặt món: vẫn ở ui_bd.gd (BD).
#   Đầu (cố định, trên tab): "Độ đẹp N/mốc" + thanh + chip đỏ "Giá bán +x%" (bấm: Hạng làng).
#   Tab: Cây cối · Công trình · Trang trí · Mặt đất; dưới tab: chip mục con (chip lọc chung) + nút "?" (Cách xây).
#   Thân: lưới thẻ 3 cột: hình (BD._icon vẽ vào ô hình), tên, giá / khoá (Cấp N) / đã đủ; thiếu xu: giá đỏ.

var BD         # ui_bd.gd
const CW := 95.0
const CH := 96.0
const CG := 6.0
const IH := 48.0    # ô hình
const HTOP := 6.0
const HEAD := 28.0
const DOWN := "rgb(214, 69, 65)"
const TABS := [["caycoi", "Cây cối"], ["congtrinh", "Công trình"], ["trangtri", "Trang trí"], ["matdat", "Mặt đất"]]

func _init(ui, bd) -> void:
	super(ui)
	BD = bd

func open() -> void:
	on = true
	scroll = 0.0
	sig = ""
	_build()

func close() -> void:   # bấm × / nền: thoát cửa hàng
	if not on:
		return
	hide_()
	if BD.mode == "shop":
		BD.close()

func hide_() -> void:   # cất bảng (B đổi chế độ: đặt món, lát đường...)
	if on:
		super.close()

func _sig() -> String:
	return BD._shop_sig()

func _tab_go(k: String) -> void:
	for gp in BD.GROUPS:
		if gp.k == k:
			BD.grp_cat[BD._grp(BD.cat).k] = BD.cat
			BD.cat = BD.grp_cat[k]
	scroll = 0.0
	_build()

func _sub_go(c: String) -> void:
	if c == "?":
		BD._help()
		return
	BD.grp_cat[BD._grp(BD.cat).k] = c
	BD.cat = c
	scroll = 0.0
	_build()

func _build() -> void:
	sig = _sig()
	var gp: Dictionary = BD._grp(BD.cat)
	var sh := _kshell(TABS.map(func(x): return [x[0], x[1], false]), gp.k, _tab_go, HTOP + HEAD + GG)
	var n: Dictionary = sh[0]
	var vt: Dictionary = sh[1]
	var card := _find(n, "khcard")
	for b in _head():
		Snap._move(b, Vector2(0, float(sh[3]) + HTOP))
		card.kids.append(b)
	var F := []
	for it in gp.c:
		F.append([it[0], it[1], ""])
	F.append(["?", "?", ""])
	_kfix(n, vt, _fchips(0.0, F, BD.cat, _sub_go)[0], 24.0, false)
	var C: Array = BD._cards()
	var out := []
	var y := 0.0
	var any_open := false
	var full := false
	for c in C:
		any_open = any_open or c.r == 0
		full = full or c.r == 2
	if not any_open and C.size() > 0:
		for c in C:
			if c.r == 1 and c.lv < 10000:
				var p := _para(X0, y, XW, "Cấp " + str(c.lv) + " mở " + ("món tiếp theo" if full else "món đầu tiên"), 12.0, 700, SUB)
				out.append_array(p[0])
				y += float(p[1]) + 6.0
				break
	var cw := (XW - 2.0 * CG) / 3.0
	for i in C.size():
		out.append_array(_bcard(X0 + (i % 3) * (cw + CG), y + (i / 3) * (CH + CG), cw, C[i]))
	y += ceili(C.size() / 3.0) * (CH + CG) - CG
	_kmount(n, vt, float(vt.r[1]), out, y)
	_icons()

func _head() -> Array:   # Độ đẹp N/mốc + thanh, chip Giá bán +x%
	var L = BD.lg()
	var j: int = L.beauty()
	var st: int = L.tier(j)
	var nx = L.C.Q5[st + 1] if st + 1 < L.C.Q5.size() else null
	var D: Dictionary = L.C.Q5[st]
	var f := 1.0 if nx == null else clampf(float(j - int(D.b)) / maxf(1.0, float(int(nx.b) - int(D.b))), 0.0, 1.0)
	var ct := "Giá bán +" + str(int(round(L.sell_bonus() * 100))) + "%"
	var cw: float = Box.text_w(ct, 12.0, 800) + 22.0
	var out := []
	var bw := XW - cw - 10.0
	out.append(_dbx(X0, 2.0, bw, 8.0, TRACK, 4.0))
	if f > 0.0:
		out.append(_dbx(X0, 2.0, maxf(8.0, bw * f), 8.0, "rgb(214, 69, 65)", 4.0))
	var wt := "Độ đẹp "
	var ww: float = Box.text_w(wt, 10.5, 600)
	out.append(_dt(X0, 13.0, ww, 15.0, wt, 10.5, 600, SUB, "left"))
	var vs := str(j)
	var vw: float = Box.text_w(vs, 13.0, 800) + 1.0
	out.append(_dt(X0 + ww, 12.0, vw, 16.0, vs, 13.0, 800, "rgb(214, 128, 20)", "left"))
	if nx != null:
		var tl := "/" + str(int(nx.b))
		out.append(_dt(X0 + ww + vw, 13.0, Box.text_w(tl, 10.5, 600) + 2.0, 15.0, tl, 10.5, 600, SUB, "left"))
	var c := _onbtn(X0 + XW - cw, 0.0, cw, 26.0, ct, BD._tier_pop, true)
	c.kids[0].css["font-size"] = _cpx(12.0)
	out.append(c)
	return out

func _bcard(x: float, y: float, w: float, c: Dictionary) -> Array:   # thẻ món: ô hình, tên, giá
	var lk: bool = c.r == 1
	var poor: bool = c.pr[0] == "c" and int(G.g.coins) < int(c.pr[1]) and c.r == 0
	var k := _chip(x, y, w, CH, "miss" if lk else "fut")
	var ic := _dbx(x + (w - IH * 1.23) * 0.5, y + 6.0, IH * 1.23, IH, "rgba(0, 0, 0, 0)", 0.0)
	ic.bdic = c.ic
	ic.bdlk = lk
	k.kids = [ic, _dt(x + 4.0, y + 56.0, w - 8.0, 16.0, _fitw(String(c.name), 12.0, 700, w - 8.0), 12.0, 700, SUB if lk else BROWN)]
	var py := y + 74.0
	if c.pr[0] == "c":
		var parts := [G.fmt_n(int(c.pr[1])), "c"]
		if String(c.pr[2]) != "":
			parts.append("/" + String(c.pr[2]))
		var rw: Array = _rowi(0.0, 0.0, 16.0, parts, 12.0, 800, DOWN if poor else "rgb(214, 128, 20)")
		for q in rw[0]:
			Snap._move(q, Vector2(x + (w - float(rw[1])) * 0.5, py))
			k.kids.append(q)
	else:
		var col := GREEN if c.pr[2] == "ok" else (SUB if c.pr[2] == "lk" else BROWN)
		var tx := String(c.pr[1]).replace("✓ ", "")
		k.kids.append(_dt(x + 4.0, py, w - 8.0, 16.0, _fitw(tx, 10.5, 700, w - 8.0), 10.5, 700, col))
		if c.pr[2] == "ok":
			k.kids.append(_dtick(x + w - 17.0, y + 5.0, 12.0))
	if c.has("cnt"):
		var ct := String(c.cnt)
		var bw: float = Box.text_w(ct, 10.5, 700) + 8.0
		var bd := _dbx(x + 5.0, y + 5.0, bw, 15.0, "rgb(236, 224, 196)", 4.0)
		bd.kids = [_dt(x + 5.0, y + 5.0, bw, 15.0, ct, 10.5, 700, SUB)]
		k.kids.append(bd)
	if c.get("full", false):
		k.css["opacity"] = "0.55"
	else:
		k.act = func(): BD._card(c)
	return [k]

func _icons() -> void:   # vẽ hình thẻ (BD._icon) vào ô hình chưa có hình (thẻ dùng lại giữ hình cũ)
	if box == null or not is_instance_valid(box):
		return
	var st := [box]
	while st.size():
		var nd: Node = st.pop_back()
		if nd is Control and nd.has_meta("snap"):
			var sn = nd.get_meta("snap")
			if sn is Dictionary and sn.has("bdic"):
				if not nd.has_meta("bdok") and nd.size.x > 0.0:
					nd.set_meta("bdok", true)
					BD._icon(nd, sn.bdic, bool(sn.bdlk))
				continue
		for ch in nd.get_children():
			st.append(ch)
