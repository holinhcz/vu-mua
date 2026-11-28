extends "res://logic/ui_kbang.gd"
# BẢNG CÂU CÁ TRÊN KHUNG KHO CHUNG CỦA VƯỜN (bản 535). Câu cá (logic/cc) chạy trong vườn thì Giỏ cá / Chợ / Sổ cá / Cài đặt
# không vẽ khung riêng nữa (cc_ui._open -> host "pan" -> ui_cc.pan) mà mở bảng này: khung Kho, tab chung, chip chung, bong bóng
# chạm xem chung. Bản chơi riêng (src/cauca, không có vườn) vẫn dùng bảng tự vẽ của cc_ui.
#  - (bản 537) không còn tab Giỏ cá: cá câu được vô thẳng Kho vườn (nút "Giỏ cá" của màn câu mở Kho lọc mục Thủy sản).
#  - tab Mồi câu: lưới mồi (khóa theo CẤP VƯỜN, ổ khóa); chọn -> thẻ: mô tả, Dùng / Đang dùng, Mua gói.
#  - tab Đồ nghề: cần, dây, phao, giỏ: món đang có; chọn -> thẻ: món kế, giá xu + cá cần trong Kho (chip có/cần), nút Đổi.
#    (bản 537) "giỏ đựng" trong vườn = cá to dễ dính hơn (không còn sức chứa giỏ).
#  - tab Sổ cá: lưới mọi loài (chưa gặp = bóng tối "???"); chạm -> bong bóng: mô tả, gợi ý chỗ câu, con lớn nhất.
#  - Cài đặt (không tab): Âm thanh, Nhạc đàn tranh (Bật / Tắt), Thống kê, Về vườn.
# Luật + dữ liệu ở cc_game / cc_data / cc_ui (sell, has_fish, take_fish); bảng này chỉ dựng giao diện.

const CD := preload("res://logic/cc/cc_data.gd")
const IMG := "res://ui/img/cc/"
var cg = null          # cc_game.gd đang chạy
var tab := "moi"
var sel := ""          # ô đang chọn (giỏ: chỉ số; mồi / đồ nghề: mã; "" không chọn)
var on_close := Callable()
const TOP := 44.0
const TABS := [["moi", "Mồi câu"], ["do", "Đồ nghề"], ["so", "Sổ cá"]]   # (bản 537) bỏ Giỏ cá: cá vô thẳng Kho vườn

func _init(ui) -> void:
	super(ui)
	fit = true

func open2(game, k: String) -> void:
	cg = game
	tab = k
	fit = k == "set"   # bảng có tab: cao cố định như Kho (đổi tab khỏi nhảy khung); Cài đặt co vừa
	sel = ""
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
	var kc := []
	for fid in CD.KHO:
		kc.append(cg.ui.basket_count(fid))
	return JSON.stringify([tab, sel, kc, S.xu, S.bait, S.baits, S.rod, S.line, S.flo, S.luoi, S.cage, S.dex.size(), S.sound, S.music, cg.lv()])

func step(dt: float) -> void:
	if on and (cg == null or not is_instance_valid(cg)):
		close()
		return
	super(dt)

func _go(k: String) -> void:
	if tab != k:
		tab = k
		sel = ""
		scroll = 0.0

func _redo() -> void:
	sig = ""
	_build()

func _build() -> void:
	sig = _sig()
	var out: Array
	match tab:
		"do": out = _do()
		"so": out = _so()
		"set": out = _caidat()
		_: out = _moi()
	var sh := _kshell([] if tab == "set" else TABS, tab, _go, 0.0 if tab == "set" else TOP)
	if tab != "set":
		_find(sh[0], "khcard").kids.append_array(_top(float(sh[3])))
	_kmount(sh[0], sh[1], float(sh[2]), out[0], float(out[1]))

# ------------------------------------------------------------------ dải đầu (như Kho: thanh + dòng chữ + chip cam)
func _top(y: float) -> Array:
	var S := _S()
	var out := []
	var f := 0.0
	var parts := []
	var ch := ""
	var cact := Callable()
	match tab:
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
	var cw: float = (Box.text_w(ch, 10.5, 800) + 22.0) if ch != "" else 0.0
	out.append_array(_bar(X0 + 2.0, y + 6.0, XW - cw - 14.0, f, 7.0))
	out.append_array(_rowi(X0 + 2.0, y + 18.0, 18.0, parts, 10.5, 700, SUB)[0])
	if ch != "":
		var c := _chip(X0 + XW - cw, y + 2.0, cw, 26.0, "now")
		c.kids = [_dt(X0 + XW - cw, y + 2.0, cw, 26.0, ch, 10.5, 800, "rgb(150, 80, 10)")]
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
	var L := _wrap(nm, 10.5, 800, cw - 6.0)
	for k in mini(2, L.size()):
		out.append(_dt(x + 3.0, y + 42.0 + k * 13.0, cw - 6.0, 13.0, _fitw(String(L[k]), 10.5, 800, cw - 6.0), 10.5, 800, BROWN))
	out.append(_dt(x + 3.0, y + CH - 17.0, cw - 6.0, 14.0, _fitw(low, 10.5, 700, cw - 6.0), 10.5, 700, lowc))
	return out

func _rows(n: int) -> float:
	return ceil(n / 4.0) * (CH + CG)

const LOCK := "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\"><path d=\"M7 10V7a5 5 0 0 1 10 0v3\" fill=\"none\" stroke=\"rgb(120,112,98)\" stroke-width=\"2.4\"/><rect x=\"4\" y=\"10\" width=\"16\" height=\"11\" rx=\"2.5\" fill=\"rgb(150,140,120)\"/><circle cx=\"12\" cy=\"15.5\" r=\"1.8\" fill=\"#fff\"/></svg>"
const GRN := "rgb(40, 110, 50)"
const RED := "rgb(190, 50, 60)"
const GOLDC := "rgb(150, 90, 10)"

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
		var C := _scard(y, IMG + "ic-" + k + str(cur) + ".webp", String(list[cur].name), String(CD.GEAR_NAME[k]) + " xịn nhất rồi", _gdesc(k, cur, String(list[cur].desc)), [])
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
		var C := _scard(y, IMG + "ic-" + k + str(cur + 1) + ".webp", String(list[cur].name) + " → " + String(nx.name), "", _gdesc(k, cur + 1, String(nx.desc)),
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

func _gdesc(k: String, lv: int, d: String) -> String:   # giỏ đựng trong vườn: không đựng cá nữa (cá vô Kho), mà giúp dính cá hiếm
	if k == "cage":
		var r := int(round((float(CD.CAGE[lv].rare) - 1.0) * 100.0))
		return ("Cá hiếm dễ dính hơn " + str(r) + "%." if r > 0 else "Chưa tăng cá hiếm.") + " Cá câu được vô thẳng Kho vườn."
	return d

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
	var P: Array = _para(X0 + 2.0, y, XW - 4.0, "Quăng " + str(int(S.stats.casts)) + " lần · câu được " + str(int(S.stats.catches)) + " · đứt dây " + str(int(S.stats.snaps)), 10.5, 600, SUB, 15.0)
	out.append_array(P[0])
	y += float(P[1]) + GG + 4.0
	out.append(_btn(X0, y, XW, 30.0, "Thôi câu, về lại vườn", func(): close(); cg.close_game(), "go"))
	return [out, y + 30.0 + 6.0]   # (bản 540) bỏ "Chơi lại từ đầu": trong vườn cá, xu, cấp, sổ cá là của vườn
