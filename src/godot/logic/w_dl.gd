extends RefCounted
# DU LỊCH MIỆT VƯỜN (dulich bản web: R6, zR, pC, Q_, qR, K_, n7, U_, gC, __, BR, Z_, X_): luật chép 1:1.
#  - Bảng mở ở cấp 15 (Jg "dulich"). Cần ít nhất một nhà dân và một quán cơm hoặc sạp bán hàng.
#  - Ban ngày 7–16 giờ, cứ 20 giây cộng dồn chờ; đủ ngưỡng (theo danh tiếng) thì một đoàn khách Sài Gòn / Tây ba lô 2–3 người
#    tới ở homestay một nhà dân chưa có khách (tối đa 2 đoàn, không quá số nhà).
#  - Đoàn đi lần lượt các chỗ gần nhà chủ (≤ 34 ô): quán (boa), sạp (mua đặc sản giá 1,5), đình, bến ghe (đi xuồng), cảnh đẹp,
#    ruộng, cù lao; mỗi chỗ vui lên hoặc buồn đi (mưa, giông thì buồn). Tối về nhà chủ ngủ, sáng 6g30 đi tiếp; hết chỗ thì ra về,
#    trả tiền phòng theo giá đã chọn, chấm 1–5 sao, ghi đánh giá; nhà chủ có thể lên thân.
#  - Đi thẳng tới chỗ (Wb của người làm thuê; bản web có tìm đường Lc). Chỗ "quán" chờ khi bản Godot có quán cơm.
# Lưu: g.dl (WH.r6: rv đánh giá, lv giá phòng, xu, n khách, wait). Đoàn đang ở (Jc) chỉ trong máy như web.
# Vẽ khách: farm.gd (_dan_list) bằng ảnh ui/img/khach/<sg|tay><0-2>[n].webp (Lo + ba lô, nón Tây; n = đội nón lá sau khi mua đặc sản).
# Bảng: ui_dl.gd.

var G
var WL         # w_lang.gd: bl, r1, _home, wb, _jg, _r0
var WH         # w_htx.gd: r6, _z6
var WR         # w_ruong.gd: gg, _pi, _hrl, m0
var WC         # w_cho.gd: Rl
var WCA        # w_ca.gd: _a0, _ci

var PR := []               # giá phòng [{n, xu, r}]
var A7 := {}               # loại khách {sg|tay: {n, looks}}
var V_ := {}               # câu đánh giá theo số sao
var Jc := []               # đoàn đang ở
var dC := 60.0
var _nid := 0

func _init(game) -> void:
	G = game
	PR = G._j("du_lich/gia_phong")
	A7 = G._j("du_lich/khach")
	V_ = G._j("du_lich/danh_gia")

func r6() -> Dictionary:
	return WH.r6()

func z_r() -> float:   # zR: danh tiếng (sao trung bình 12 đánh giá gần nhất, chưa có thì 3)
	var t: Array = r6().rv
	if t.is_empty():
		return 3.0
	var a := 0.0
	var L := t.slice(0, 12)
	for n in L:
		a += float(n.s)
	return a / L.size()

func _saps() -> Array:   # Hr có sạp (sap, sap2)
	return WR._hrl().filter(func(p): return p.id == "sap" or p.id == "sap2")

func _quan() -> bool:   # Gs: có quán cơm (bản Godot chưa có)
	var f = WL.ext.get("Gs")
	return f is Callable and f.is_valid() and bool(f.call())

func p_c() -> bool:   # pC: đủ điều kiện đón khách
	return WL.bl().size() > 0 and (_quan() or _saps().size() > 0)

func q_free() -> Array:   # Q_: nhà chưa có khách
	var t := {}
	for a in Jc:
		t[int(a.host)] = 1
	return WL.bl().filter(func(a): return not t.has(int(a.u)))

func q_r() -> Array:   # qR: chỗ khách vào làng
	var t := [[5.5, 23.5], [5.5, 20.5], [5.5, 16.5], [4.5, 13.5]]
	for a in t:
		if WCA._zd(a[0], a[1], false):
			return a
	return [5.5, 13.5]

static func _ch(t: Dictionary) -> Array:   # Ch: chỗ đứng trước sạp
	return [t.gx + t.fw + 0.45, t.gy + t.fd / 2.0] if String(t.id).ends_with("2") else [t.gx + t.fw / 2.0, t.gy + t.fd + 0.45]

func _ben_ok(p: Dictionary) -> bool:   # $M: bến có mé sông mở
	var f = WL.ext.get("ben_ok")
	if f is Callable and f.is_valid():
		return bool(f.call(p))
	return true

func k_() -> Array:   # K_: các chỗ đoàn có thể ghé (tối đa 6, xáo, quán chen vị trí thứ 2)
	WR.m0()
	var t := []
	if _quan():
		var fq = WL.ext.get("T4")
		if fq is Callable and fq.is_valid():
			t.append({"k": "quan", "o": fq.call()[0]})
	var n := _saps()
	if n.size():
		t.append({"k": "sap", "o": n[0]})
	var e = WH._z6()
	if e != null:
		t.append({"k": "dinh", "p": [float(e.gx) + float(e.fw) / 2.0, float(e.gy) + float(e.fd) + 0.7]})
	var r: Array = WR._hrl().filter(func(p): return RegEx.create_from_string("^ben[34]$").search(String(p.id)) != null and _ben_ok(p))
	if r.size():
		t.append({"k": "ben", "o": r[0]})
	var Pi: Dictionary = G.lang.Pi
	var o: Array = WR._hrl().filter(func(p):
		var d = Pi.get(p.id)
		return d != null and int(d.get("b", 0)) >= 3 and RegEx.create_from_string("^(quancom|sap|kho|tramyt)").search(String(p.id)) == null)
	for l in 2:
		if o.is_empty():
			break
		var a: Dictionary = o.pop_at(randi() % o.size())
		t.append({"k": "canh", "p": [a.gx + a.fw / 2.0, a.gy + a.fd + 0.6], "n": String(Pi[a.id].n)})
	var c: Array = WR.gg()
	if c.size():
		var f: Dictionary = WR._pi(int(c[randi() % c.size()]))
		t.append({"k": "ruong", "p": [float(f.gx) + 0.5, float(f.gy) + 1.2]})
	t.shuffle()
	var h := t.filter(func(p): return p.k == "quan")
	t = t.filter(func(p): return p.k != "quan")
	if h.size():
		t.insert(mini(1, t.size()), h[0])
	return t.slice(0, 6)

func n7(t: Dictionary) -> Array:   # n7: chỗ đứng ở điểm ghé
	if t.k == "quan":
		var f = WL.ext.get("Pg")
		return f.call(t.o) if f is Callable and f.is_valid() else []
	if t.k == "sap":
		return _ch(t.o)
	if t.k == "ben":
		var a: Dictionary = t.o
		return [a.gx + a.fw / 2.0, a.gy + a.fd / 2.0]
	return t.p

func u_() -> void:   # U_: một đoàn tới
	var t := q_free()
	if t.is_empty():
		return
	var a: Dictionary = t[randi() % t.size()]
	var n := "tay" if randf() < 0.35 else "sg"
	var e := 2 + (1 if randf() < 0.4 else 0)
	var r := q_r()
	var o: Array = A7[n].looks
	var l := []
	for c in e:
		l.append({"x": r[0] + c * 0.3, "y": r[1] + c * 0.25, "j": c % 3, "non": false, "face": -1, "ph": randf() * 6.0, "mv": false})
	var hp: Vector2 = WL._home(a.u)
	var f := [hp.x, hp.y]
	var s: Array = k_().filter(func(T):
		var w := n7(T)
		return w.size() and Vector2(w[0] - f[0], w[1] - f[1]).length() < 34.0)
	var h := []
	var p := f
	while s.size():
		var d := 0
		var v := 1e9
		for w in s.size():
			var E := n7(s[w])
			var C := Vector2(E[0] - p[0], E[1] - p[1]).length()
			if C < v:
				v = C
				d = w
		var x: Dictionary = s.pop_at(d)
		h.append(x)
		p = n7(x)
	_nid += 1
	Jc.append({"id": _nid, "k": n, "host": int(a.u), "m": l, "stops": h, "i": -1, "st": "go", "dest": f, "t": 0.0, "happy": 0.0, "spent": 0,
		"night": 0, "at": Time.get_unix_time_from_system() * 1000.0, "act": "", "leaving": false, "home": false, "cur": null})
	var M = WL._r0().fam.get(str(a.u))
	WL._ta("Có đoàn " + String(A7[n].n).to_lower() + " " + str(e) + " người tới ở homestay nhà " + (String(M.n) if M != null else "dân") + "!")

func g_c(t: Dictionary) -> void:   # gC: tới chỗ kế (hết thì ra về)
	t.i = int(t.i) + 1
	if t.i >= t.stops.size():
		t.st = "go"
		t.dest = q_r()
		t.leaving = true
		return
	var a: Dictionary = t.stops[t.i]
	t.st = "go"
	t.dest = n7(a)
	t.cur = a

func z5() -> Array:   # z5: món bày sạp (có trong kho, nhiều trước, tối đa 6)
	var t: Array = WC.Rl.filter(func(a): return int(G.g.barn.get(a, 0)) > 0)
	t.sort_custom(func(a, b): return int(G.g.barn[a]) > int(G.g.barn[b]))
	return t.slice(0, 6)

func __(t: Dictionary) -> void:   # __: tới một chỗ ghé
	var a: Dictionary = t.cur
	var n: int = t.m.size()
	var e: bool = G.troi != null and (G.troi.cur == "mua" or G.troi.cur == "giong")
	var r: Dictionary = t.m[0]
	t.act = a.k
	t.t = 14.0 if a.k == "ben" else 9.0 + randf() * 4.0
	if e:
		t.happy -= 0.6
	if a.k == "quan":
		var f = WL.ext.get("JS")
		var o := 0
		for l in n:
			if f is Callable and f.is_valid() and f.call(a.o, r):
				o += 1
		if o:
			var c := 12 * o
			G.g.coins = float(G.g.coins) + c
			t.spent += c
			t.happy += 1.6
			WCA._a0(r.x, r.y - 0.6, "Khách boa +" + str(c) + " xu")
		else:
			t.happy -= 1.2
	elif a.k == "sap":
		var f := z5().filter(func(k): return int(G.g.barn.get(k, 0)) >= 2)
		var s := 0
		for h in n:
			if f.is_empty():
				break
			var p: String = f[randi() % f.size()]
			var d := 1 + (1 if randf() < 0.4 else 0)
			d = mini(d, int(G.g.barn[p]) - 1)
			if d < 1:
				continue
			G.g.barn[p] = int(G.g.barn[p]) - d
			var v := int(round(d * G.price(p) * 1.5))
			G.g.coins = float(G.g.coins) + v
			t.spent += v
			s += v
		if s:
			WCA._a0(r.x, r.y - 0.6, "Khách mua đặc sản +" + G.fmt_n(s) + " xu")
			t.happy += 1.0
			for k in t.m:
				if randf() < 0.6:
					k.non = true
		else:
			t.happy -= 0.5
	elif a.k == "ben":
		var x := 12 * n
		G.g.coins = float(G.g.coins) + x
		t.spent += x
		t.happy += 2.0
		WCA._a0(r.x, r.y - 0.6, "Đi xuồng +" + str(x) + " xu")
	else:
		t.happy += 1.0 + (0.6 if G.lang.beauty() > 250 else 0.0)
	G.mark()

func b_r(t: Dictionary) -> void:   # BR: trả phòng, chấm sao
	var a := r6()
	var n: Dictionary = PR[int(a.lv)]
	var e: int = t.m.size()
	var r := maxi(1, int(t.night))
	var o := int(n.xu) * e * r
	var l := maxi(1, mini(5, int(round(2.4 + float(t.happy) * 0.35 + float(n.r)))))
	G.g.coins = float(G.g.coins) + o
	a.xu = float(a.xu) + o + int(t.spent)
	a.n = float(a.n) + e
	var L: Array = V_[str(l)]
	var c: String = L[randi() % L.size()]
	a.rv.push_front({"s": l, "t": c, "k": t.k, "n": e, "xu": o + int(t.spent), "at": Time.get_unix_time_from_system() * 1000.0})
	a.rv = a.rv.slice(0, 20)
	var f = WL._r0().fam.get(str(t.host))
	if f != null and l >= 4 and int(f.get("tim", 0)) < 5 and randf() < 0.4:
		f.tim = int(f.get("tim", 0)) + 1
	WL._ta(String(A7[t.k].n) + " trả phòng: +" + G.fmt_n(o) + " xu tiền phòng, đánh giá " + str(l) + "★ “" + c + "”")
	G.mark()

func z_(t: Dictionary, a: float, n: float) -> void:   # Z_: người sau đi theo người đầu
	var e: Dictionary = t.m[0]
	for r in range(1, t.m.size()):
		var o: Dictionary = t.m[r]
		var l: float = e.x - 0.35 * r * float(e.face if e.face else 1) * 0.7
		var c: float = e.y + 0.3 * r
		var f: float = l - o.x
		var s: float = c - o.y
		var h := sqrt(f * f + s * s)
		if h > 0.05:
			var p := minf(h, n * a * 1.15 * (1.6 if h > 1.5 else 1.0))
			o.x += f / h * p
			o.y += s / h * p
			o.ph += a * 8.0
			var d := f - s
			if absf(d) > 0.01:
				o.face = 1 if d > 0 else -1
			o.mv = true
		else:
			o.mv = false

func step(t: float) -> void:   # X_: mỗi khung
	if G.w_all == null or bool(WH._cr()):
		return
	var night: bool = G.night
	dC -= t
	if dC <= 0.0:
		dC = 20.0
		var a: float = WH._d0()
		if p_c() and not night and a >= 7.0 and a < 16.0 and Jc.size() < mini(2, WL.bl().size()):
			var n := r6()
			n.wait = float(n.get("wait", 0)) + 20.0
			var e := maxf(120.0, 420.0 / (0.6 + z_r() * 0.25))
			if float(n.wait) >= e:
				n.wait = 0
				u_()
	for r in range(Jc.size() - 1, -1, -1):
		var o: Dictionary = Jc[r]
		var l: Dictionary = o.m[0]
		var c := 1.25
		if WL.r1(o.host) == null:
			Jc.remove_at(r)
			continue
		var hv: Vector2 = WL._home(o.host)
		if o.st == "rest":
			if not night and WH._d0() >= 6.5:
				o.night = int(o.night) + 1
				o.st = "go"
				o.dest = null
				o.t = 0.0
				g_c(o)
				for d in o.m:
					d.x = hv.x
					d.y = hv.y
			continue
		if night and not o.leaving and o.st != "rest":
			o.st = "go"
			o.dest = [hv.x, hv.y]
			o.home = true
		if o.st == "do":
			o.t = float(o.t) - t
			for d in o.m:
				d.mv = false
			if o.t <= 0.0:
				o.act = ""
				g_c(o)
			continue
		if o.st == "go":
			var s: Array = o.dest if o.dest != null else [hv.x, hv.y]
			l.tx = float(s[0])
			l.ty = float(s[1])
			if WL.wb(l, t, c):
				l.mv = false
				if o.leaving:
					b_r(o)
					Jc.remove_at(r)
					continue
				if o.home:
					o.home = false
					o.st = "rest"
					for d in o.m:
						d.mv = false
					continue
				if int(o.i) < 0:
					o.st = "do"
					o.act = "nha"
					o.t = 4.0
					continue
				o.st = "do"
				__(o)
				continue
			l.mv = true
			z_(o, t, c)

func at(w: Vector2, le: float, en: Callable, nn: Callable) -> bool:   # $_: chạm trúng khách
	for e in Jc:
		if e.st == "rest":
			continue
		for o in e.m:
			var l: float = en.call(o.x, o.y)
			var c: float = nn.call(o.x, o.y)
			if absf(w.x - l) < 10.0 * le and w.y > c - 32.0 * le and w.y < c + 4.0:
				return true
	return false

func n_khach() -> int:
	var n := 0
	for e in Jc:
		n += e.m.size()
	return n

func bk_sub() -> String:   # dòng phụ thẻ Du lịch trong Sổ làng
	return str(Jc.size()) + " đoàn khách" if Jc.size() else ("Sẵn sàng đón khách" if p_c() else "Chưa mở")
