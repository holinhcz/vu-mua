extends "res://logic/ui_kbang.gd"
# BẢNG CÂU CÁ TRÊN KHUNG KHO CHUNG CỦA VƯỜN (bản 535). Câu cá (logic/cc) chạy trong vườn thì Giỏ cá / Chợ / Sổ cá / Cài đặt
# không vẽ khung riêng nữa (cc_ui._open -> host "pan" -> ui_cc.pan) mà mở bảng này: khung Kho, tab chung, chip chung, bong bóng
# chạm xem chung. Bản chơi riêng (src/cauca, không có vườn) vẫn dùng bảng tự vẽ của cc_ui.
#  - tab Giỏ cá: thanh sức chứa + "Đáng giá N ⊙" + chip n/sức chứa; lưới 4 cột cá trong giỏ; chọn 1 con -> thẻ trên lưới:
#    tên · cân, giá, độ hiếm, nút Bán / Vô Kho; không chọn -> nút Bán hết (chạm 2 lần).
#  - tab Mồi câu: lưới mồi (khóa theo CẤP VƯỜN, ổ khóa); chọn -> thẻ: mô tả, Dùng / Đang dùng, Mua gói.
#  - tab Đồ nghề: cần, dây, phao, giỏ: món đang có; chọn -> thẻ: món kế, giá xu + cá cần (chip có/cần), nút Đổi.
#  - tab Sổ cá: lưới mọi loài (chưa gặp = bóng tối "???"); chạm -> bong bóng: mô tả, gợi ý chỗ câu, con lớn nhất.
#  - Cài đặt (không tab): Âm thanh, Nhạc đàn tranh (Bật / Tắt), Thống kê, Về vườn, Chơi lại từ đầu (chạm 2 lần).
# Luật + dữ liệu ở cc_game / cc_data / cc_ui (sell, has_fish, take_fish); bảng này chỉ dựng giao diện.

const CD := preload("res://logic/cc/cc_data.gd")
const IMG := "res://ui/img/cc/"
var cg = null          # cc_game.gd đang chạy
var tab := "gio"
var sel := ""          # ô đang chọn (giỏ: chỉ số; mồi / đồ nghề: mã; "" không chọn)
var _sure := false     # Bán hết / Chơi lại: đã chạm 1 lần
var on_close := Callable()
const TOP := 44.0
const TABS := [["gio", "Giỏ cá"], ["moi", "Mồi câu"], ["do", "Đồ nghề"], ["so", "Sổ cá"]]

func _init(ui) -> void:
	super(ui)
	fit = true

func open2(game, k: String) -> void:
	cg = game
	tab = k
	sel = ""
	_sure = false
	on = true
	scroll = 0.0
	sig = ""
	_build()

func close() -> void:
	var was := on
	super()
	if was and on_close.is_valid():
		on_close.call()

func _S() -> Dictionary:
	return cg.S

func _sig() -> String:
	var S := _S()
	return JSON.stringify([tab, sel, _sure, S.basket.size(), S.xu, S.bait, S.baits, S.rod, S.line, S.flo, S.cage, S.dex.size(), S.sound, S.music, cg.lv()])

func step(dt: float) -> void:
	if on and (cg == null or not is_instance_valid(cg)):
		close()
		return
	super(dt)

func _go(k: String) -> void:
	if tab != k:
		tab = k
		sel = ""
		_sure = false
		scroll = 0.0

func _redo() -> void:
	sig = ""
	_build()

func _build() -> void:
	sig = _sig()
	var out: Array
	match tab:
		"moi": out = _moi()
		"do": out = _do()
		"so": out = _so()
		"set": out = _caidat()
		_: out = _gio()
	var sh := _kshell([] if tab == "set" else TABS, tab, _go, 0.0 if tab == "set" else TOP)
	if tab != "set":
		_find(sh[0], "khcard").kids.append_array(_top(float(sh[3])))
	_kmount(sh[0], sh[1], float(sh[2]), out[0], float(out[1]))

# ------------------------------------------------------------------ dải đầu (như Kho: thanh + dòng chữ + chip cam)
func _top(y: float) -> Array:
	var S := _S()
	var out := []
	var cap: int = CD.CAGE[S.cage].cap
	var f := 0.0
	var parts := []
	var ch := ""
	var cact := Callable()
	match tab:
		"gio":
			var tot := 0
			for c in S.basket:
				tot += CD.fish_value(CD.fish(c.id), c.w)
			f = float(S.basket.size()) / cap
			parts = ["Đáng giá ", "c", " " + G.fmt_n(tot)]
			ch = str(S.basket.size()) + "/" + str(cap)
			cact = _go_r.bind("do")
		"so":
			var seen := 0
			for fi in CD.FISH:
				if S.dex.has(fi.id):
					seen += 1
			f = float(seen) / CD.FISH.size()
			parts = ["Đã gặp " + str(seen) + " / " + str(CD.FISH.size()) + " loài"]
		_:
			var xi: Array = cg.host.xpi.call() if cg.host != null and cg.host.has("xpi") else [0, 1]
			f = float(xi[0]) / maxf(1.0, float(xi[1]))
			parts = ["Cấp vườn " + str(cg.lv()) + " · còn " + G.fmt_n(maxi(0, int(xi[1]) - int(xi[0]))) + " kinh nghiệm"]
			ch = "Giỏ " + str(S.basket.size()) + "/" + str(cap)
			cact = _go_r.bind("gio")
	var cw: float = (Box.text_w(ch, 11.0, 800) + 22.0) if ch != "" else 0.0
	out.append_array(_bar(X0 + 2.0, y + 6.0, XW - cw - 14.0, f, 7.0))
	out.append_array(_rowi(X0 + 2.0, y + 18.0, 18.0, parts, 11.0, 700, SUB)[0])
	if ch != "":
		var c := _chip(X0 + XW - cw, y + 2.0, cw, 26.0, "now")
		c.kids = [_dt(X0 + XW - cw, y + 2.0, cw, 26.0, ch, 11.0, 800, "rgb(150, 80, 10)")]
		if cact.is_valid():
			c.act = cact
		out.append(c)
	return out

func _go_r(k: String) -> void:
	_go(k)
	_redo()

# ------------------------------------------------------------------ ô lưới 4 cột (như ô Kho)
const CG := 6.0
const CH := 84.0
func _cw() -> float:
	return (XW - CG * 3.0) / 4.0

func _cell(i: int, y0: float, pic: String, nm: String, low: String, lowc: String, kind: String, act: Callable, dark := false, lock := false, tick := false) -> Array:
	var cw := _cw()
	var x := X0 + (i % 4) * (cw + CG)
	var y := y0 + int(i / 4) * (CH + CG)
	var out := []
	var c := _chip(x, y, cw, CH, kind)
	c.act = act
	out.append(c)
	if pic != "":
		var p := _icx(x + cw * 0.5, y + 22.0, 34.0, "pic:" + pic)
		if dark:
			p.css = p.css.duplicate()
			p.css["opacity"] = "0.35"
		out.append(p)
	if lock:
		out.append(_dic(x + cw * 0.5 - 9.0, y + 13.0, 18.0, LOCK))
	if tick:
		out.append(_dtick(x + cw - 17.0, y + 5.0, 13.0))
	var L := _wrap(nm, 10.0, 800, cw - 6.0)
	for k in mini(2, L.size()):
		out.append(_dt(x + 3.0, y + 42.0 + k * 13.0, cw - 6.0, 13.0, _fitw(String(L[k]), 10.0, 800, cw - 6.0), 10.0, 800, BROWN))
	out.append(_dt(x + 3.0, y + CH - 17.0, cw - 6.0, 14.0, _fitw(low, 9.5, 700, cw - 6.0), 9.5, 700, lowc))
	return out

func _rows(n: int) -> float:
	return ceil(n / 4.0) * (CH + CG)

const LOCK := "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\"><path d=\"M7 10V7a5 5 0 0 1 10 0v3\" fill=\"none\" stroke=\"rgb(120,112,98)\" stroke-width=\"2.4\"/><rect x=\"4\" y=\"10\" width=\"16\" height=\"11\" rx=\"2.5\" fill=\"rgb(150,140,120)\"/><circle cx=\"12\" cy=\"15.5\" r=\"1.8\" fill=\"#fff\"/></svg>"
const GRN := "rgb(40, 110, 50)"
const RED := "rgb(190, 50, 60)"
const GOLDC := "rgb(150, 90, 10)"

# thẻ chọn (trên lưới): hình + tên + dòng phụ + đoạn tả + nút
func _scard(y: float, pic: String, ttl: String, sub: String, desc: String, btns: Array, extra := []) -> Array:   # btns: [[chữ, việc, kiểu]]
	var out := []
	var P: Array = _para(X0 + 10.0, y + 46.0, XW - 20.0, desc, 10.5, 600, SUB, 14.0) if desc != "" else [[], 0.0]
	var h: float = 46.0 + float(P[1]) + (6.0 if desc != "" else 0.0) + (extra[1] if extra.size() else 0.0) + 34.0
	var c := _chip(X0, y, XW, h, "fut")
	out.append(c)
	if pic != "":
		out.append(_icx(X0 + 26.0, y + 23.0, 34.0, "pic:" + pic))
	out.append(_dt(X0 + 48.0, y + 7.0, XW - 56.0, 17.0, _fitw(ttl, 12.5, 800, XW - 56.0), 12.5, 800, BROWN, "left"))
	if sub != "":
		out.append(_dt(X0 + 48.0, y + 25.0, XW - 56.0, 15.0, _fitw(sub, 10.5, 700, XW - 56.0), 10.5, 700, SUB, "left"))
	out.append_array(P[0])
	var yy: float = y + 46.0 + float(P[1]) + (6.0 if desc != "" else 0.0)
	if extra.size():
		for k in extra[0]:
			Snap._move(k, Vector2(0, yy))
		out.append_array(extra[0])
		yy += extra[1]
	var bx := X0 + XW - 8.0
	for i in range(btns.size() - 1, -1, -1):
		var b: Array = btns[i]
		var bw: float = Box.text_w(String(b[0]), 11.0, 800) + 26.0
		bx -= bw
		if String(b[2]) == "gold":
			out.append(_dbtn(bx, yy, bw, 26.0, String(b[0]), b[1]))
		else:
			out.append(_btn(bx, yy, bw, 26.0, String(b[0]), b[1], String(b[2])))
		bx -= 6.0
	return [out, h]

# ------------------------------------------------------------------ Giỏ cá
func _gio() -> Array:
	var S := _S()
	var out := []
	var y := 6.0
	if S.basket.is_empty():
		out.append(_pic(X0 + XW * 0.5 - 40.0, y + 6.0, 80.0, 80.0, IMG + "ic-cage" + str(S.cage) + ".webp"))
		out.append(_dt(X0, y + 92.0, XW, 18.0, "Giỏ trống trơn", 13.0, 800, BROWN))
		var P: Array = _para(X0 + 20.0, y + 114.0, XW - 40.0, "Cá câu được bỏ vô đây: bán lấy xu, cất vô Kho, hoặc để dành đổi đồ nghề.", 10.5, 600, SUB, 14.0)
		for k in P[0]:
			k.css = k.css.duplicate()
			k.css["text-align"] = "center"
		out.append_array(P[0])
		return [out, y + 114.0 + float(P[1]) + 8.0]
	var si := int(sel) if sel != "" else -1
	if si >= 0 and si < S.basket.size():
		var c: Dictionary = S.basket[si]
		var f: Dictionary = CD.fish(c.id)
		var val: int = CD.fish_value(f, c.w)
		var kid: String = String(CD.KHO.get(c.id, ""))
		var nb := _need_by(String(c.id))
		var btns := [["Bán · +" + G.fmt_n(val), _sell1.bind(si), "go"]]
		if kid != "":
			btns.push_front(["Vô Kho", _kho1.bind(si, kid), "gold"])
		var sub: String = cg.ui.fmt_w(float(c.w)) + " · " + "★".repeat(int(f.rar)) + " " + String(CD.RAR[int(f.rar)])
		var desc := ("Cần để đổi " + nb + ", nên giữ lại.") if nb != "" else ("Cá hiếm, để dành đổi đồ." if int(f.rar) >= 3 else "")
		var C := _scard(y, IMG + String(c.id) + ".webp", String(f.name), sub, desc, btns)
		out.append_array(C[0])
		y += float(C[1]) + GG
	else:
		var tot := 0
		for c in S.basket:
			tot += CD.fish_value(CD.fish(c.id), c.w)
		var lab: String = "Chạm lần nữa để bán hết" if _sure else "Bán hết · +" + G.fmt_n(tot)
		var bw: float = Box.text_w(lab, 11.0, 800) + 30.0
		out.append(_btn(X0 + (XW - bw) * 0.5, y, bw, 28.0, lab, _sell_all, "go"))
		y += 28.0 + GG
	for i in S.basket.size():
		var c: Dictionary = S.basket[i]
		var f: Dictionary = CD.fish(c.id)
		var ii: int = i
		out.append_array(_cell(i, y, IMG + String(c.id) + ".webp", String(f.name), G.fmt_n(CD.fish_value(f, c.w)) + " xu", GOLDC,
			"got" if i == si else "fut", func(): sel = "" if sel == str(ii) else str(ii); _sure = false; _redo()))
	return [out, y + _rows(S.basket.size())]

func _need_by(fid: String) -> String:   # cá này đang cần để đổi đồ nghề nào
	var S := _S()
	for k in CD.GEAR_KEYS:
		var list: Array = CD.gear(k)
		var cur: int = S[k]
		if cur + 1 < list.size() and list[cur + 1].has("need") and list[cur + 1].need.has(fid):
			return String(list[cur + 1].name)
	return ""

func _sell1(i: int) -> void:
	var S := _S()
	if i < 0 or i >= S.basket.size():
		return
	cg.ui.sell([S.basket[i]], Vector2.ZERO)
	cg._xu_sync()
	sel = ""
	_redo()

func _kho1(i: int, kid: String) -> void:
	var S := _S()
	if i < 0 or i >= S.basket.size():
		return
	if not cg.host.kho.call(kid, 1):
		_dsay("Kho vườn đầy (" + str(cg.host.room.call()) + "), bán bớt đã.")
		return
	var nm: String = String(CD.fish(S.basket[i].id).name)
	S.basket.remove_at(i)
	sel = ""
	cg.save(true)
	_dsay("Đã cất " + nm + " vô Kho.")
	_redo()

func _sell_all() -> void:
	if not _sure:
		_sure = true
		_redo()
		return
	_sure = false
	cg.ui.sell(_S().basket.duplicate(), Vector2.ZERO)
	cg._xu_sync()
	_redo()

# ------------------------------------------------------------------ Mồi câu
func _moi() -> Array:
	var S := _S()
	var out := []
	var y := 6.0
	var k := sel if sel != "" else String(S.bait)
	var b: Dictionary = CD.BAIT[k]
	var lock: bool = int(b.lv) > cg.lv()
	var btns := []
	var sub := ""
	if lock:
		sub = "Vườn lên cấp " + str(int(b.lv)) + " mới mở"
	else:
		sub = "Vô hạn" if k == "trun" else "Đang có " + str(int(S.baits.get(k, 0)))
		if S.bait == k:
			btns.append(["Đang dùng", func(): pass, "go"])
		elif k == "trun" or int(S.baits.get(k, 0)) > 0:
			btns.append(["Dùng mồi này", _use.bind(k), "go"])
		if int(b.pack) > 0:
			btns.append(["Mua " + str(int(b.pack)) + " · " + G.fmt_n(int(b.price)) + " xu", _buy.bind(k), "gold" if S.xu >= int(b.price) else "off"])
	var C := _scard(y, IMG + "ic-" + k + ".webp", String(b.name), sub, String(b.desc), btns)
	out.append_array(C[0])
	y += float(C[1]) + GG
	for i in CD.BAIT_ORDER.size():
		var kk: String = CD.BAIT_ORDER[i]
		var bb: Dictionary = CD.BAIT[kk]
		var lk: bool = int(bb.lv) > cg.lv()
		var low: String = ("Cấp " + str(int(bb.lv))) if lk else ("Vô hạn" if kk == "trun" else "Có " + str(int(S.baits.get(kk, 0))))
		out.append_array(_cell(i, y, IMG + "ic-" + kk + ".webp", String(bb.name), low, SUB if lk else BROWN, "got" if kk == k else "fut",
			func(): sel = kk; _redo(), lk, lk, S.bait == kk))
	return [out, y + _rows(CD.BAIT_ORDER.size())]

func _use(k: String) -> void:
	_S().bait = k
	cg.ui.hud_dirty()
	_dsay("Đã móc " + String(CD.BAIT[k].name) + ".")
	_redo()

func _buy(k: String) -> void:
	var S := _S()
	var b: Dictionary = CD.BAIT[k]
	if S.xu < int(b.price):
		_dsay("Còn thiếu " + G.fmt_n(int(b.price) - int(S.xu)) + " xu.")
		return
	S.xu -= int(b.price)
	S.baits[k] = int(S.baits.get(k, 0)) + int(b.pack)
	if S.bait == "trun":
		S.bait = k
	cg.snd.coin(0)
	cg._xu_sync()
	cg.ui.hud_dirty()
	_redo()

# ------------------------------------------------------------------ Đồ nghề
func _do() -> Array:
	var S := _S()
	var out := []
	var y := 6.0
	var k := sel if sel != "" else String(CD.GEAR_KEYS[0])
	var list: Array = CD.gear(k)
	var cur: int = S[k]
	if cur + 1 >= list.size():
		var C := _scard(y, IMG + "ic-" + k + str(cur) + ".webp", String(list[cur].name), String(CD.GEAR_NAME[k]) + " xịn nhất rồi", String(list[cur].desc), [])
		out.append_array(C[0])
		y += float(C[1]) + GG
	else:
		var nx: Dictionary = list[cur + 1]
		var ok_xu: bool = S.xu >= int(nx.price)
		var ok_f: bool = not nx.has("need") or cg.ui.has_fish(nx.need)
		var nl := [["xu", "Xu", int(S.xu), int(nx.price)]]
		if nx.has("need"):
			for fid in nx.need:
				nl.append(["pic:" + IMG + String(fid) + ".webp", String(CD.fish(fid).name), cg.ui.basket_count(fid), int(nx.need[fid])])
		var N: Array = _nchips(0.0, 0.0, XW - 20.0, nl)
		for n in N[0]:
			Snap._move(n, Vector2(X0 + 10.0, 0))
		var C := _scard(y, IMG + "ic-" + k + str(cur + 1) + ".webp", String(list[cur].name) + " → " + String(nx.name), "", String(nx.desc),
			[["Đổi", _up.bind(k), "go" if ok_xu and ok_f else "off"]], [N[0], float(N[1]) + 6.0])
		out.append_array(C[0])
		y += float(C[1]) + GG
	for i in CD.GEAR_KEYS.size():
		var kk: String = CD.GEAR_KEYS[i]
		var L: Array = CD.gear(kk)
		var cc: int = S[kk]
		var st := "Xịn nhất"
		var col := GRN
		if cc + 1 < L.size():
			var n2: Dictionary = L[cc + 1]
			var ok: bool = S.xu >= int(n2.price) and (not n2.has("need") or cg.ui.has_fish(n2.need))
			st = "Đổi được" if ok else "Chưa đủ"
			col = GRN if ok else SUB
		out.append_array(_cell(i, y, IMG + "ic-" + kk + str(cc) + ".webp", String(L[cc].name), st, col, "got" if kk == k else "fut", func(): sel = kk; _redo()))
	return [out, y + _rows(CD.GEAR_KEYS.size())]

func _up(k: String) -> void:
	var S := _S()
	var nn: Dictionary = CD.gear(k)[S[k] + 1]
	if S.xu < int(nn.price) or (nn.has("need") and not cg.ui.has_fish(nn.need)):
		_dsay("Chưa đủ xu hoặc cá để đổi.")
		return
	S.xu -= int(nn.price)
	if nn.has("need"):
		cg.ui.take_fish(nn.need)
	S[k] += 1
	cg.snd.fanfare(3)
	cg._xu_sync()
	cg.ui.hud_dirty()
	cg.save(true)
	_dsay("Đổi được " + String(nn.name) + "!")
	_redo()

# ------------------------------------------------------------------ Sổ cá
func _so() -> Array:
	var S := _S()
	var out := []
	var y := 6.0
	for i in CD.FISH.size():
		var f: Dictionary = CD.FISH[i]
		var d = S.dex.get(f.id)
		var fid: String = f.id
		out.append_array(_cell(i, y, IMG + fid + ".webp", String(f.name) if d != null else "???",
			cg.ui.fmt_w(float(d.best)) if d != null else "Chưa gặp", SUB, "fut", _dex_tip.bind(fid), d == null))
	return [out, y + _rows(CD.FISH.size())]

func _dex_tip(fid: String) -> void:
	var S := _S()
	var f: Dictionary = CD.fish(fid)
	var d = S.dex.get(fid)
	var t: String = (String(f.desc) if d != null else "Chưa câu được con nào.")
	if not f.has("junk"):
		var bt := "d"
		var bv := -1.0
		for kk in f.time:
			if float(f.time[kk]) > bv:
				bv = float(f.time[kk])
				bt = kk
		var bb := ""
		var bw := -1.0
		for kk in f.bait:
			if float(f.bait[kk]) > bw:
				bw = float(f.bait[kk])
				bb = kk
		var tm: String = {"d": "ban ngày", "dd": "rạng sáng, chạng vạng", "n": "ban đêm"}[bt]
		var zn := "giữa kênh xa" if float(f.zone[0]) > 15 else ("sát mé" if float(f.zone[1]) < 12 else "tầm giữa")
		t += " Gợi ý: " + tm + ", " + zn + (", gần lục bình" if f.has("cover") else "") + ((", mồi " + String(CD.BAIT[bb].name).to_lower()) if bb != "" else "") + "."
	if d != null:
		t += " Đã câu " + str(int(d.n)) + " lần, con lớn nhất " + cg.ui.fmt_w(float(d.best)) + "."
	_dtip(t, "", (String(f.name) if d != null else "???") + " · " + "★".repeat(int(f.rar)))

# ------------------------------------------------------------------ Cài đặt
func _caidat() -> Array:
	var S := _S()
	var out := []
	var y := 6.0
	for g in [["Âm thanh", int(S.sound) == 1, func(v): cg.snd.set_sound(v)], ["Nhạc đàn tranh", int(S.music) == 1, func(v): cg.snd.set_music(v)]]:
		out.append_array(_sect(y, String(g[0]), "rgb(76, 160, 70)"))
		y += 22.0
		var hw := (XW - 6.0) * 0.5
		var cb: Callable = g[2]
		out.append(_btn(X0, y, hw, 28.0, "Bật", func(): cb.call(true); _redo(), "go" if g[1] else "off"))
		out.append(_btn(X0 + hw + 6.0, y, hw, 28.0, "Tắt", func(): cb.call(false); _redo(), "off" if g[1] else "go"))
		y += 28.0 + GG + 4.0
	out.append_array(_sect(y, "Thống kê", "rgb(214, 150, 20)"))
	y += 22.0
	var P: Array = _para(X0 + 2.0, y, XW - 4.0, "Quăng " + str(int(S.stats.casts)) + " lần · câu được " + str(int(S.stats.catches)) + " · đứt dây " + str(int(S.stats.snaps)), 11.0, 600, SUB, 15.0)
	out.append_array(P[0])
	y += float(P[1]) + GG + 4.0
	out.append(_btn(X0, y, XW, 30.0, "Thôi câu, về lại vườn", func(): close(); cg.close_game(), "go"))
	y += 30.0 + GG
	var lab: String = "Chạm lần nữa để xóa hết tiến trình câu cá" if _sure else "Chơi lại từ đầu"
	out.append(_btn(X0 + 40.0, y, XW - 80.0, 28.0, lab, _reset, "red"))
	return [out, y + 28.0 + 6.0]

func _reset() -> void:
	if not _sure:
		_sure = true
		_redo()
		return
	_sure = false
	cg.reset_save()
	cg.ui.hud_dirty()
	close()
