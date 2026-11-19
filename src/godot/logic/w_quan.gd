extends RefCounted
# (bản 350) KHÁCH QUÁN: Quán cơm (g.quan.k), Tạp hóa đầu ngõ (g.tap.o), Quán cà phê võng (g.cafe.c). Một luật chung, cấu hình
# ở data/cho/quan_khach.json: giờ mở, nhóm món theo khung giờ (xưởng + tab, hoặc danh sách món), nhịp khách giờ cao điểm /
# giờ thường (giờ làng), số lượng; "nuoc" (quán cơm): mỗi bàn thêm 1 món nước.
#   - Chỉ ra khách / đơn lúc đang mở game; khách chỉ gọi món làm được (G._f8: đủ xưởng, cấp, nguyên liệu, hoặc có trong kho).
#   - Có khách thì bong bóng hình món trên mái (farm._tree_bub_want), chạm để giao từ kho (giao()).
#   - Trễ hẹn lúc đang mở game: Quán cơm mất 0,1 sao; Tạp hóa để trễ 3 đơn liền thì nghỉ tới hôm sau; Cà phê bớt 5% khách
#     trong ngày. Hết hạn lúc tắt game thì bỏ, không phạt.
# (bản 355) Sao nâng cấp căn nhà (st(k).ns 1..6 = 0★..5★, nâng ở bảng nâng sao chung, giá như xưởng): quan_khach.json "sao"
# theo bậc: toi_da (chỗ chờ), cho (phút chờ), boa (+ phần boa), nhanh (khách tới nhanh hơn), gia (tạp hóa: nhân giá).
# (bản 360) Mỗi căn một hàng khách riêng: q = id căn ("quancom" / "quancom2"...), trạng thái g.quan / g.quan2, g.tap / g.tap2, g.cafe / g.cafe2.
# Sao danh tiếng quán cơm (g.quan.sao 1..5) và mức giá (g.quan.gia: 0 Bình dân, 1 Vừa, 2 Sang) dùng cho/muc_gia_quan_com.json (m: nhân giá, s x5: sao lên mỗi khách).

var G
var CF := {}          # quan_khach.json
var GIA := []         # muc_gia_quan_com.json
var _t := 0.0
var _last := 0.0      # ms lần xét trước (khoảng cách lớn = vừa mở lại game / tab ngủ)

func _init(game) -> void:
	G = game
	CF = G._j("cho/quan_khach")
	GIA = G._j("cho/muc_gia_quan_com")

# ------------------------------------------------------------------ trạng thái
func kd(q: String) -> String:   # loại của căn q
	return kind_of(q)

func st(q: String) -> Dictionary:
	var k := kd(q)
	var ix: int = CF[k].obj.find(q)
	var key: String = {"quancom": "quan", "taphoa": "tap", "cafe": "cafe"}[k] + ("" if ix <= 0 else str(ix + 1))
	var s = G.g.get(key)
	if not (s is Dictionary):
		s = {}
		G.g[key] = s
	var lk: String = {"quancom": "k", "taphoa": "o", "cafe": "c"}[k]
	if not (s.get(lk) is Array):
		s[lk] = []
	if k == "quancom":
		if not (s.get("sao") is float or s.get("sao") is int):
			s.sao = 3.0
		if not s.has("gia"):
			s.gia = 1
	return s

func list(q: String) -> Array:
	return st(q)[{"quancom": "k", "taphoa": "o", "cafe": "c"}[kd(q)]]

func ten(q: String) -> String:   # tên căn: căn thứ 2 cùng loại thêm " 2"
	var k := kd(q)
	var ix: int = CF[k].obj.find(q)
	return String(CF[k].ten) + ("" if ix <= 0 or not built(String(CF[k].obj[0])) else " " + str(ix + 1))

func kind_of(obj_id: String) -> String:
	for k in CF:
		if CF[k].obj.has(obj_id):
			return k
	return ""

func built(q: String) -> bool:
	for o in G.lang.objs():
		if o is Dictionary and String(o.get("id", "")) == q:
			return true
	return false

func ks(q: String) -> int:   # sao nâng cấp 1..6
	return clampi(int(st(q).get("ns", 1)), 1, 6)

func sv(q: String, f: String) -> float:   # hiệu lực theo sao nâng cấp
	var a: Array = CF[kd(q)].sao.get(f, [])
	return float(a[ks(q) - 1]) if a.size() else 0.0

func us(q: String, a: int) -> String:   # dòng hiệu lực ở bảng nâng sao (bậc a 1..6)
	var k := kd(q)
	var S: Dictionary = CF[k].sao
	var i := clampi(a, 1, 6) - 1
	var cho: String = G.ao(float(S.cho[i]) * 60.0)
	var t := []
	match k:
		"quancom":
			t = ["Chỗ " + str(int(S.toi_da[i])) + " bàn", "Chờ " + cho]
		"taphoa":
			t = ["Chỗ " + str(int(S.toi_da[i])) + " đơn", "Giữ đơn " + cho, "Giá +" + str(int(round((float(S.gia[i]) - 1.0) * 100.0))) + "%"]
		"cafe":
			t = ["Chỗ " + str(int(S.toi_da[i])) + " võng", "Chờ " + cho]
	if S.has("boa") and float(S.boa[i]) > 0.0:
		t.append("Boa +" + str(int(round(float(S.boa[i]) * 100.0))) + "%")
	if float(S.nhanh[i]) > 0.0:
		t.append(("Đơn" if k == "taphoa" else "Khách") + " tới nhanh +" + str(int(round(float(S.nhanh[i]) * 100.0))) + "%")
	return " · ".join(t)

func up(q: String) -> bool:   # nâng sao căn nhà: xu + ván, đinh, gạch (giá như xưởng)
	var n := ks(q)
	if n >= 6:
		return false
	if not G._pay(G.up_need(n + 1, 1, "work")):
		return false
	st(q).ns = n + 1
	G.toast.emit(ten(q) + " lên " + str(n) + "★: " + us(q, n + 1) + ".")
	G.vib(15)
	G.mark()
	return true

func _hms() -> float:   # ms thật cho 1 giờ làng (Cài đặt "Nhanh": 1 phút = 1 giờ)
	return (60.0 if G.cfg.d == "fast" else 3600.0) * 1000.0

# ------------------------------------------------------------------ món theo giờ
func _slot(k: String, h: float):
	var c: Dictionary = CF[k]
	if h < float(c.mo[0]) or h >= float(c.mo[1]):
		return null
	for s in c.gio:
		if h >= float(s.tu) and h < float(s.den):
			return s
	return null

func pool(s: Dictionary) -> Array:   # món khung giờ s mà người chơi làm được
	var out := []
	for w in s.get("xuong", {}):
		if not G.xw.T.has(w):
			continue
		var tabs: Array = s.xuong[w]
		for r in G.xw.T[w].rec:
			if tabs.is_empty() or tabs.has(G.xw.group_of(w, String(r))):
				out.append(String(r))
	for m in s.get("mon", []):
		if not out.has(m):
			out.append(String(m))
	return out.filter(func(m): return G.xw.R.has(m) and G._f8(m))

# ------------------------------------------------------------------ bước (mỗi khung, chỉ lúc mở game)
func step(dt: float) -> void:
	_t -= dt
	if _t > 0.0:
		return
	_t = 1.0
	var now: float = G._now_ms()
	var gap := now - _last if _last > 0.0 else 1e12
	_last = now
	var online := gap < 90000.0   # xét liền nhau: trễ hẹn lúc đang chơi mới phạt
	var h: float = G.nv.hour()
	for k in CF:
		for q in CF[k].obj:
			if built(String(q)):
				_expire(String(q), now, online)
				_spawn(String(q), now, h)

func _expire(q: String, now: float, online: bool) -> void:
	var L := list(q)
	var keep := []
	for e in L:
		if float(e.dl) > now:
			keep.append(e)
		elif online:
			_late(q)
	if keep.size() != L.size():
		L.assign(keep)
		G.mark()

func _late(q: String) -> void:
	var s := st(q)
	match kd(q):
		"quancom":
			s.sao = maxf(1.0, float(s.sao) - 0.1)
			G.toast.emit("Khách " + ten(q) + " chờ lâu bỏ về, danh tiếng giảm còn " + ("%.1f" % float(s.sao)).replace(".", ",") + ".")
		"taphoa":
			s.tre = int(s.get("tre", 0)) + 1
			if int(s.tre) >= int(CF.taphoa.nghi_sau):
				s.tre = 0
				s.nghi = G.day() + 1
				G.toast.emit(ten(q) + " trễ 3 đơn liền, nghỉ tới mai mới đặt hàng lại.")
			else:
				G.toast.emit("Đơn sỉ " + ten(q) + " hết hạn.")
		"cafe":
			if int(s.get("pd", -1)) != G.day():
				s.pd = G.day()
				s.pen = 0
			s.pen = int(s.get("pen", 0)) + 1
			G.toast.emit("Khách " + ten(q) + " chờ lâu bỏ đi.")

func _spawn(q: String, now: float, h: float) -> void:
	var k := kd(q)
	var c: Dictionary = CF[k]
	var s := st(q)
	var L := list(q)
	if L.size() >= int(sv(q, "toi_da")):
		return
	if k == "taphoa" and int(s.get("nghi", -1)) > G.day():
		return
	var sl = _slot(k, h)
	if sl == null:
		return
	if float(s.get("nx", 0)) <= 0.0 or float(s.nx) > now + _hms() * 24.0:
		s.nx = now + _gap(q, sl)
		return
	if now < float(s.nx):
		return
	s.nx = now + _gap(q, sl)
	var P := pool(sl)
	if P.is_empty():
		return
	var it := []
	var n := 1
	if k == "quancom" and randf() < float(c.nhom):
		n = 2
	elif k == "taphoa":
		n = randi_range(int(c.mon_moi_don[0]), int(c.mon_moi_don[1]))
	P.shuffle()
	var tv := (20.0 + 10.0 * mini(60, G.lv())) * randf_range(float(c.gia_tri[0]), float(c.gia_tri[1])) if c.has("gia_tri") else 0.0
	for m in P.slice(0, n):
		var qn := randi_range(int(c.sl[0]), int(c.sl[1]))
		if tv > 0.0:   # (bản 354) tạp hóa: số lượng theo giá trị, cả đơn khoảng 2-3 lần một đơn hàng thường
			qn = clampi(int(round(tv / n / float(G.item(m).get("sell", 10)))), int(c.sl[0]), int(c.sl[1]))
		it.append([m, qn])
	if c.has("nuoc"):   # (bản 356) quán cơm: mỗi bàn gọi thêm 1 món nước (Xe nước mía, nước uống Quán chè), có thì mới gọi
		var NU := pool(c.nuoc)
		if NU.size():
			it.append([String(NU[randi() % NU.size()]), 1])
	L.append({"items": it, "dl": now + sv(q, "cho") / 60.0 * _hms(), "t0": now})
	G.mark()

func _gap(q: String, sl: Dictionary) -> float:   # ms tới khách sau
	var k := kd(q)
	var c: Dictionary = CF[k]
	var g := float(c.cao if sl.get("cao", false) else c.thuong) * _hms() * (1.0 - sv(q, "nhanh"))
	if k == "quancom":
		g /= 0.6 + 0.2 * float(st(q).sao)   # 3★ = nhịp gốc; sao cao đông khách
	elif k == "cafe":
		var s := st(q)
		var pen := int(s.get("pen", 0)) if int(s.get("pd", -1)) == G.day() else 0
		g /= maxf(0.5, 1.0 - float(c.bot_khach) * pen)
	return g * randf_range(0.7, 1.3)

# ------------------------------------------------------------------ bong bóng + giao
func bub(q: String):   # món hiện trên bong bóng (khách chờ lâu nhất), không có thì null
	var L := list(q)
	return String(L[0].items[0][0]) if L.size() else null

func giao(q: String, i := 0) -> bool:   # giao khách / đơn thứ i (bong bóng: khách chờ lâu nhất)
	var k := kd(q)
	var L := list(q)
	if i < 0 or i >= L.size():
		return false
	var e: Dictionary = L[i]
	var miss := []
	for p in e.items:
		if int(G.g.barn.get(p[0], 0)) < int(p[1]):
			miss.append(G.item_name(String(p[0])) + " " + str(int(p[1]) - int(G.g.barn.get(p[0], 0))))
	if miss.size():
		G.toast.emit(ten(q) + " cần: " + ", ".join(miss) + ".")
		return false
	var pay := _pay(q, e.items)
	for p in e.items:
		G.g.barn[p[0]] = int(G.g.barn[p[0]]) - int(p[1])
	var s := st(q)
	match k:
		"quancom":
			var m: Dictionary = GIA[clampi(int(s.gia), 0, GIA.size() - 1)]
			s.sao = clampf(float(s.sao) + float(m.s) * 5.0, 1.0, 5.0)
			s.tot = int(s.get("tot", 0)) + 1
			s.xu = int(s.get("xu", 0)) + pay[0] + pay[1]
		"taphoa":
			s.tre = 0
	L.remove_at(i)
	G.g.coins = float(G.g.coins) + pay[0] + pay[1]
	G.add_xp(maxi(1, int(round(_val(e.items) / 12.0))), "quan")
	G.toast.emit(ten(q) + ": +" + G.fmt_n(pay[0]) + " xu" + (" (boa " + G.fmt_n(pay[1]) + ")" if pay[1] > 0 else "") + ".")
	G.mark()
	return true

func _val(items: Array) -> float:
	var v := 0.0
	for p in items:
		v += float(G.item(String(p[0])).get("sell", 10)) * int(p[1])
	return v

func _pay(q: String, items: Array, est := false) -> Array:   # [xu, boa]; est: boa cà phê lấy giữa khoảng
	var v := _val(items)
	var s := st(q)
	match kd(q):
		"quancom":
			var m: Dictionary = GIA[clampi(int(s.gia), 0, GIA.size() - 1)]
			return [int(round(v * float(m.m))), int(round(v * 0.05 * float(s.sao) * (1.0 + sv(q, "boa"))))]
		"taphoa":
			return [int(round(v * sv(q, "gia"))), 0]
		"cafe":
			var b: float = (float(CF.cafe.boa[0]) + float(CF.cafe.boa[1])) * 0.5 if est else randf_range(float(CF.cafe.boa[0]), float(CF.cafe.boa[1]))
			return [int(round(v * float(CF.cafe.gia))), int(round(v * b * (1.0 + sv(q, "boa"))))]
	return [int(v), 0]

# ------------------------------------------------------------------ bảng quán (ui.gd dùng chung bảng Đơn hàng: od_src = id căn)
const CHO := {"quancom": "Bàn", "taphoa": "Đơn sỉ", "cafe": "Võng"}
func cards(q: String) -> Array:   # khách đang chờ dạng thẻ đơn: {who, shop, items, reward}; chỗ trống: khách kế {w}
	var now: float = G._now_ms()
	var out := []
	var k := kd(q)
	var L := list(q)
	for i in L.size():
		var e: Dictionary = L[i]
		var pay := _pay(q, e.items, true)
		out.append({"who": CHO[k] + " " + str(i + 1), "shop": "Còn " + _left(float(e.dl) - now), "items": e.items, "reward": pay[0] + pay[1]})
	var s := st(q)
	var nx := float(s.get("nx", 0))
	if L.size() < int(sv(q, "toi_da")) and nx > now and _slot(k, G.nv.hour()) != null and not (k == "taphoa" and int(s.get("nghi", -1)) > G.day()):
		out.append({"who": "", "shop": "", "items": [], "reward": 0, "w": nx})
	return out

func _left(ms: float) -> String:
	var m := int(ceil(maxf(0.0, ms) / 60000.0))
	return (str(m / 60) + "g " + str(m % 60) + "p") if m >= 60 else (str(m) + " phút")

func chips(q: String) -> Array:   # hàng chip đầu bảng quán: [mã, chữ, hình?]
	var s := st(q)
	var out := [["sao", str(ks(q) - 1) + "/5", "res://ui/img/bong/sao.png"]]
	match kd(q):
		"quancom":
			out.append(["dt", "🏅 Danh tiếng " + ("%.1f" % float(s.sao)).replace(".", ",")])
			out.append(["gia", "🪙 Giá: " + String(GIA[clampi(int(s.gia), 0, GIA.size() - 1)].n)])
		"taphoa":
			out.append(["tre", "⏱ Nghỉ tới mai" if int(s.get("nghi", -1)) > G.day() else "⏱ Trễ " + str(int(s.get("tre", 0))) + "/" + str(int(CF.taphoa.nghi_sau))])
		"cafe":
			var pen := int(s.get("pen", 0)) if int(s.get("pd", -1)) == G.day() else 0
			out.append(["khach", "🤝 Khách hôm nay " + str(int(round(maxf(0.5, 1.0 - float(CF.cafe.bot_khach) * pen) * 100.0))) + "%"])
	return out

func menu_now(q: String) -> Array:   # món khách có thể gọi giờ này (đã lọc món làm được)
	var sl = _slot(kd(q), G.nv.hour())
	return [] if sl == null else pool(sl)

func menu_title(q: String) -> String:
	var k := kd(q)
	if _slot(k, G.nv.hour()) == null:
		return "Đang đóng cửa, mở lúc " + str(int(CF[k].mo[0])) + " giờ"
	return "Giờ này khách hay gọi:" if k != "taphoa" else "Tạp hóa hay lấy sỉ:"

func gia_next(q: String) -> void:   # quán cơm: đổi mức giá Bình dân -> Vừa -> Sang
	var s := st(q)
	s.gia = (int(s.gia) + 1) % GIA.size()
	G.toast.emit(ten(q) + " đổi giá: " + String(GIA[int(s.gia)].n) + ".")
	G.mark()
