extends RefCounted
# AUTO (Ur / W$ bản web): nhân vật tự chơi như người chơi, mỗi 1,5 giây xét một lượt. Bật tắt bằng nút AUTO (lưu ở máy).
# Một lượt (thứ tự như web):
#  1. Nhận quà lên cấp (KH), quà mục tiêu (#goalGo).
#  2. Giao hàng: đơn hàng (ks) luôn trước, rồi nhà dân đang cần (Gb). Hàng cho đơn hàng luôn được giữ: việc khác, bán bớt,
#     cho ăn không đụng tới; gieo cây và xếp món xưởng cho đơn hàng trước (khác bản web: web xếp chung theo lời).
#  3. Sức dưới 12%: ăn món hồi sức trong kho, không có thì về nhà ngủ (TV). Sức dưới 3 thì nghỉ, không nhận việc.
#  4. Xếp tối đa 4 việc đi làm: phun rầy, thú y con bệnh, gặt ô chín, thu / cho ăn vật nuôi, thu xưởng, bắt sâu, hái trái,
#     gieo hạt (z$: giống cần cho đơn trước, không thì giống lời nhất), tưới ô khô, tưới cây.
#  4b. Đơn hàng có món không làm ra được thì tự đổi đơn khác (~30 giây); đơn kẹt 45 phút cũng đổi (G$).
#  5. Mua thêm con khi chuồng còn chỗ và dư xu gấp 4; xếp món xưởng còn thiếu cho đơn (giữ lại 4 hạt mỗi giống);
#     kho gần đầy thì bán bớt món rẻ; nâng sao kho, ô ruộng, chuồng khi dư xu gấp 2–3.
# Bản Godot chưa có: câu cá tự động, thương lái / ghe / tạp hóa / xe chè, nhận quà ngày và sổ nhiệm vụ, mua giống chợ phiên.

const LP := 4              # Lp: giữ lại hạt mỗi giống để gieo tiếp
var G
var U              # ui.gd (bộ ráp gán)
var on := false
var n := 0                 # số việc đã làm (hiện trên nút)
var rest := false
var t := 0.0
var _jc := []              # U9 lưu tạm
var _jk := -1

func _init(game) -> void:
	G = game
	on = _ls_get() == "1"

static func _ls_get() -> String:   # localStorage nt_auto
	if OS.has_feature("web"):
		var v = JavaScriptBridge.eval("(function(){try{return localStorage.getItem('nt_auto')||''}catch(e){return ''}})()")
		return String(v) if v != null else ""
	return ""

func toggle() -> void:
	on = not on
	if OS.has_feature("web"):
		JavaScriptBridge.eval("try{localStorage.setItem('nt_auto','" + ("1" if on else "0") + "')}catch(e){}")
	G.toast.emit("Auto bật: nhân vật tự đi làm như người chơi, tốn thể lực, giữ lại hạt để gieo tiếp." if on else "Đã tắt Auto.")

func label() -> String:   # chữ nhỏ sau BẬT
	if not on:
		return ""
	if rest:
		return "đang nghỉ mệt"
	return str(n) + " việc" if n else ""

# ------------------------------------------------------------------ đồ cần (U9, _8, jF)
func _bn(k: String) -> int:
	return int(G.g.barn.get(k, 0))

func _crop(k: String) -> bool:
	return G.D.crops.has(k)

func _jf(items: Array, keep := {}) -> bool:   # jF: đủ hàng (giữ lại LP hạt, và hàng giữ cho đơn hàng nếu có keep)
	for a in items:
		if _bn(String(a[0])) - (LP if _crop(String(a[0])) else 0) - int(keep.get(String(a[0]), 0)) < int(a[1]):
			return false
	return true

func _can(items: Array) -> bool:   # đơn làm ra được: cây phải còn hạt để gieo (Auto chưa mua giống), món khác còn nguồn (F8)
	for r in items:
		var k := String(r[0])
		if _crop(k):
			if _bn(k) <= 0 and not _growing(k):
				return false
		elif not G._f8(k):
			return false
	return true

func _growing(k: String) -> bool:   # có ô đang trồng cây k
	for a in G.B0:
		if G.p(a).get("c") == k:
			return true
	return false

func _ord() -> Dictionary:   # món cần cho các đơn hàng làm được (luôn giữ, làm trước)
	var a := {}
	for x in u9():
		if x.src == "o" and x.can:
			for r in x.items:
				a[String(r[0])] = int(a.get(String(r[0]), 0)) + int(r[1])
	return a

func _deep(t2: Dictionary) -> Dictionary:   # thêm nguyên liệu xưởng và thức ăn cho món cần
	for o in G.xw.R:
		if t2.has(o):
			for l in G.xw.R[o].in:
				t2[String(l[0])] = maxi(int(t2.get(String(l[0]), 0)), int(l[1]) * int(t2[o]))
	for o in G.vn.Q:
		var mk = G.vn.Q[o].get("make")
		if mk != null and t2.has(String(mk)) and G.vn.ok(o):
			var f: String = G.vn.Q[o].feed
			t2[f] = maxi(int(t2.get(f, 0)), int(t2[String(mk)]))
	return t2

func _wf(items: Array) -> float:   # WF: thời gian ước để làm cho đủ
	var a := 0.0
	for x in items:
		var e: int = maxi(0, int(x[1]) - (_bn(String(x[0])) - (LP if _crop(String(x[0])) else 0)))
		if e > 0:
			a += e * _gf(String(x[0]))
	return a

var _fa := {}
func _gf(k: String, d := 0) -> float:   # GF: giây làm ra một món
	if _fa.has(k):
		return _fa[k]
	var v := 600.0
	if _crop(k):
		v = float(G.D.crops[k].get("time", 300))
	elif G.xw.R.has(k) and d < 4:
		var e: Dictionary = G.xw.R[k]
		v = float(e.get("time", 120))
		for o in e.in:
			v += _gf(String(o[0]), d + 1) * float(o[1]) * 0.5
	else:
		for o in G.vn.Q:
			if G.vn.Q[o].get("make") == k:
				v = float(G.vn.Q[o].time) / 2.0
	_fa[k] = v
	return v

func u9() -> Array:   # U9: việc giao hàng xếp theo lời / thời gian
	var tk := int(Time.get_ticks_msec() / 250)
	if tk == _jk:
		return _jc
	var a := []
	var now: float = G._now_ms()
	var O: Array = G.g.get("orders", [])
	for i in O.size():
		var o = O[i]
		if o is Dictionary and not (float(o.get("w", 0)) > now):
			a.append({"items": o.items, "xu": float(o.get("reward", 0)), "go": G.deliver.bind(i), "src": "o", "i": i})
	if G.w_all != null:
		var WL = G.w_all.WL
		var F: Dictionary = WL._r0().fam
		for u in F:
			var r = F[u].get("req")
			if r is Dictionary and r.get("id") and float(r.get("q", 0)) > 0:
				var it: Array = r.it if r.get("it") is Array and r.it.size() else [[r.id, r.q]]
				a.append({"items": it, "xu": float(r.get("xu", 0)) * 1.2, "go": WL.gb.bind(u), "src": "d"})
	var od := {}   # hàng đơn hàng: việc khác không được đụng
	for x in a:
		x.can = _can(x.items)
		if x.src == "o" and x.can:
			for r in x.items:
				od[String(r[0])] = int(od.get(String(r[0]), 0)) + int(r[1])
	for x in a:
		x.miss = _wf(x.items)
		x.sc = x.xu / (1.0 + x.miss / 60.0) + (1e9 if x.src == "o" and x.can else 0.0)   # đơn hàng làm được ưu tiên cao nhất
		x.ok = _jf(x.items) if x.src == "o" else _jf(x.items, od)
	a.sort_custom(func(p, q): return p.sc > q.sc)
	_jc = a
	_jk = tk
	return a

func _need(all := false) -> Dictionary:   # _8: món cần: mọi đơn hàng + 2 việc khác đầu bảng (all: tất cả)
	var a := _ord()
	var k := 0
	for e in u9():
		if e.src == "o" or (not all and k >= 2):
			continue
		k += 1
		for r in e.items:
			a[String(r[0])] = int(a.get(String(r[0]), 0)) + int(r[1])
	return a

func _pick_seed() -> String:   # z$: giống để gieo (cây cho đơn hàng trước, rồi việc khác, rồi giống lời nhất)
	var WC = G.w_all.WC
	var od := _deep(_ord())
	var r: Array = G.xo.filter(func(o): return not G.D.crops[o].get("hyb") and not WC.tf(o) and od.has(o) and _bn(o) < int(od[o]) + LP)
	if r.size():
		r.sort_custom(func(x, y): return int(od[x]) - _bn(x) > int(od[y]) - _bn(y))
		return r[0]
	var t2 := _deep(_need())
	for o in G.vn.Q:
		if G.vn.ok(o):
			var f: String = G.vn.Q[o].feed
			t2[f] = maxi(int(t2.get(f, 0)), 8)
	r = G.xo.filter(func(o): return not G.D.crops[o].get("hyb") and not WC.tf(o) and t2.has(o) and _bn(o) < int(t2[o]) + 2)
	if r.size():
		return r[randi() % r.size()]
	var best := ""
	var e := -1.0
	for o in G.xo:
		var l: Dictionary = G.D.crops[o]
		if l.get("hyb") or WC.tf(o):
			continue
		var c := (float(l.get("sell", 0)) * 2.0 + float(l.get("xp", 0)) * 6.0) / (float(l.get("time", 60)) / 60.0 + 3.0)
		if c > e:
			e = c
			best = o
	return best

# ------------------------------------------------------------------ một lượt (W$)
func step(dt: float) -> void:
	t -= dt
	if t > 0.0:
		return
	t = 1.5
	if not on or G.w_all == null or not (G.g.get("pc") is Dictionary):   # bản Godot chưa có màn tạo nhân vật (pc.made) nên không xét
		return
	_turn()

func _ga() -> int:   # GA: việc đang xếp
	var F = U.F
	return (1 if F.cur != null else 0) + F.q.size()

func _turn() -> void:
	var c := 0
	var F = U.F
	var WS = G.w_all.WS
	if WS.pp().size() and U.lvp != null:   # KH
		U.lvp.take_all()
		c += 1
	if not WS.goal_view().is_empty() and WS.goal_claim():   # #goalGo
		c += 1
	var L := u9().filter(func(x): return x.ok)
	if L.size():
		var r = L[0].go.call()
		if r is bool and r or r == null:
			c += 1
			_jk = -1
	var res := _ord()   # hàng giữ: mọi đơn hàng (luôn giữ) + việc khác đã đủ
	for x in u9():
		if x.ok and x.src != "o":
			for k in x.items:
				res[String(k[0])] = int(res.get(String(k[0]), 0)) + int(k[1])
	var o := func(x: String) -> int: return _bn(x) - int(res.get(x, 0))
	var en := float(G.g.pc.en)
	if en < G.en_max() * 0.12:
		var ate := false
		for f in G.FB:
			if _bn(f[0]) > int(res.get(f[0], 0)):
				ate = G.eat(f[0])
				break
		if ate:
			c += 1
		elif F.cur == null and F.q.is_empty() and not G.night:
			F.sleep_go()
	rest = en < 3.0
	var s := 0 if rest else maxi(0, 4 - _ga())
	var room: int = G.kho_room()
	# phun rầy
	var R = G.g.get("ray")
	if R is Dictionary and R.get("p") is Dictionary:
		for k in R.p:
			if s <= 0:
				break
			var i := int(k)
			if G.owned(i) and not F.has_job("p" + str(i) + "spray") and (int(R.get("th", 0)) >= 1 or int(G.g.coins) >= 200):
				if F.queue_job(i, "spray"):
					s -= 1
					c += 1
	# thú y
	for x in G.vn.Q:
		for j in G.vn.list(x).size():
			var e: Dictionary = G.vn.list(x)[j]
			if e.get("s", 0) and int(G.g.coins) >= 250 and G.vn.vet(x, j):
				c += 1
	# gặt
	for a in G.B0:
		if s <= 0:
			break
		var p: Dictionary = G.p(a)
		if p.get("u") and p.get("c") and G.ripe(p) and room > 3 and not F.has_job("p" + str(a) + "harvest") and F.queue_job(a, "harvest"):
			s -= 1
			c += 1
	# vật nuôi: thu / cho ăn
	for x in G.vn.Q:
		if not G.vn.ok(x):
			continue
		var k: Dictionary = G.vn.Q[x]
		var lst: Array = G.vn.list(x)
		for j in lst.size():
			if s <= 0:
				break
			var e: Dictionary = lst[j]
			var act := ""
			if G.vn.ready(x, e) and room > 3:
				act = "collect"
			elif G.vn.hungry(e) and _bn(String(k.feed)) - _feed_q(x, String(k.feed)) > (LP if _crop(String(k.feed)) else 0):
				act = "feed"
			if act != "" and F.vn_job(x, j, act):
				s -= 1
				c += 1
	# thu xưởng
	for x in G.xw.list_built():
		if s <= 0:
			break
		if G.xw.df(x) > 0 and room > 4 and not F.has_job("wkc" + x):
			F.xw_job(x, "workc")
			s -= 1
			c += 1
	# bắt sâu
	for a in G.B0:
		if s <= 0:
			break
		var p: Dictionary = G.p(a)
		if p.get("u") and p.get("b") and not F.has_job("p" + str(a) + "bug") and F.queue_job(a, "bug"):
			s -= 1
			c += 1
	# hái trái, tưới cây (Px)
	var WR = G.w_all.WR
	var Ei: Dictionary = WR._ei()
	var O: Array = WR._objs()
	for a in O.size():
		if s <= 0:
			break
		var q = O[a]
		if q is Dictionary and Ei.has(q.get("id", "")) and (q.get("fp") is float or q.get("fp") is int) and WR.wc(q) and room > 5:
			G.w_all.WRU.px(a, "tharvest")
			s -= 1
			c += 1
	# gieo
	for a in G.B0:
		if s <= 0:
			break
		var p: Dictionary = G.p(a)
		if not p.get("u") or p.get("c") or F.has_job("p" + str(a) + "plant") or not G.owned(a):
			continue
		var d := _pick_seed()
		var odd := _ord()   # cây cho đơn hàng: gieo luôn bằng hạt đang giữ (gieo 1 gặt 2, mau đủ đơn)
		if d == "" or (odd.has(d) and _bn(d) - F.seeds_queued(d) < 1) or (not odd.has(d) and o.call(d) - F.seeds_queued(d) < 1):
			var cand: Array = G.xo.filter(func(x): return not G.D.crops[x].get("hyb") and not G.w_all.WC.tf(x) and o.call(x) - F.seeds_queued(x) >= 1)
			cand.sort_custom(func(x, y): return o.call(x) > o.call(y))
			d = cand[0] if cand.size() else ""
		if d != "" and G.can_plant(a, d) == "" and F.queue_job(a, "plant", d):
			s -= 1
			c += 1
	# tưới ô
	for a in G.B0:
		if s <= 0:
			break
		var p: Dictionary = G.p(a)
		if p.get("u") and p.get("c") and not G.ripe(p) and float(p.get("w", 0)) <= 0.0 and not F.has_job("p" + str(a) + "water") and F.queue_job(a, "water"):
			s -= 1
			c += 1
	for a in O.size():
		if s <= 0:
			break
		var q = O[a]
		if q is Dictionary and Ei.has(q.get("id", "")) and (q.get("fw") is float or q.get("fw") is int) and not WR.wc(q) and float(q.fw) <= 0.0:
			G.w_all.WRU.px(a, "twater")
			s -= 1
			c += 1
	# mua thêm con
	for x in G.vn.Q:
		if G.vn.ok(x) and G.vn.list(x).size() < G.vn.gl() and int(G.g.coins) > G.vn.price(x) * 4 and G.vn.buy(x):
			c += 1
	# xếp món xưởng
	var M := _need()
	var MO := _deep(_ord())   # món cho đơn hàng: làm trước
	for x in G.xw.list_built():
		var w: Dictionary = G.xw.w(x)
		var tries := 0
		while w.q.size() < G.xw.nc(x) and tries < 3:
			tries += 1
			var rec: Array = G.xw.sr[x].rec.filter(func(C):
				if not G.xw.R.has(C) or G.bf(C) > G.lv():
					return false
				if not M.has(C) and _bn(C) + _queued(C) >= 6:
					return false
				for Rr in G.xw.R[C].in:
					var nn: int = (LP if _crop(String(Rr[0])) else 0) + int(M.get(String(Rr[0]), 0))
					if not (_bn(String(Rr[0])) - int(Rr[1]) >= nn or (not _crop(String(Rr[0])) and not M.has(String(Rr[0])) and _bn(String(Rr[0])) >= int(Rr[1]))):
						return false
				return true)
			if rec.is_empty():
				break
			var pr := func(C) -> float: return (2000.0 if MO.has(C) and _bn(C) + _queued(C) < int(MO[C]) else 0.0) + (1000.0 if M.has(C) else 0.0) + float(G.item(C).get("sell", 0))
			rec.sort_custom(func(C, Rr): return pr.call(C) > pr.call(Rr))
			var E: int = w.q.size()
			G.xw.make(x, rec[0])
			if w.q.size() == E:
				break
			c += 1
	# đơn kẹt (G$): đơn có món không làm ra được thì đổi sau ~30 giây; đơn làm được mà 45 phút chưa đủ hàng cũng đổi
	if _stuck():
		c += 1
	# kho gần đầy: bán bớt
	var cap: int = G.kho_cap()
	if G.kho_room() < cap * 0.12 and _sell_some(cap, res):
		c += 1
	# nâng sao kho, ô ruộng, chuồng
	var lv: int = G.lv()
	var k1: int = G.kho_star()
	if k1 < 10:
		var Mk: Dictionary = G.kho_need(k1 + 1)
		if lv >= int(Mk.lv) and G.can_pay(Mk) and int(G.g.coins) > int(Mk.xu) * 2 and G.kho_up():
			c += 1
	for a in G.B0:
		var p: Dictionary = G.p(a)
		if p.get("u") and G.owned(a):
			var st: int = G.star(p)
			if st < 6:
				var T: Dictionary = G.up_need(st + 1, 1, "plot")
				if lv >= int(T.lv) and G.can_pay(T) and int(G.g.coins) > int(T.xu) * 3 and G.plot_up(a):
					c += 1
	for x in G.vn.Q:
		if G.vn.ok(x):
			var C: int = G.vn.ps(x)
			if C < 6:
				var T: Dictionary = G.up_need(C + 1, 1, "pen")
				if lv >= int(T.lv) and G.can_pay(T) and int(G.g.coins) > int(T.xu) * 3 and G.pen_up(x):
					c += 1
	if c:
		n += c
		G.mark()

var os := {}   # Ur.os: số lượt thấy đơn chưa giao được, theo chữ ký đơn
func _stuck() -> bool:
	var seen := {}
	var done := false
	for x in u9():
		if x.src != "o":
			continue
		var sg := str(x.items) + "|" + str(x.xu)
		seen[sg] = 1
		if x.ok:
			os.erase(sg)
			continue
		os[sg] = int(os.get(sg, 0)) + 1
		if not done and (os[sg] > 1800 or (not x.can and os[sg] > 20)):
			G.swap(int(x.i))
			os.erase(sg)
			_jk = -1
			done = true
	for k in os.keys():
		if not seen.has(k):
			os.erase(k)
	return done

func _feed_q(t2: String, f: String) -> int:   # I$: việc cho ăn món f đang xếp
	var a := 0
	var F = U.F
	for j in ([F.cur] if F.cur != null else []) + F.q:
		if j.kind == "animal" and j.seed == "feed" and j.va[0] == t2:
			a += 1
	return a

func _queued(k: String) -> int:   # F$: món k đang chờ trong hàng xưởng
	var a := 0
	for x in G.xw.N0:
		if G.xw.built(x):
			for r in G.xw.w(x).q:
				if r == k:
					a += 1
	return a

func _sell_some(cap: int, res: Dictionary) -> bool:   # H$: bán món rẻ cho kho còn 25%
	var want := int(ceil(cap * 0.25))
	var e := {}
	var r := {}
	var L := u9()
	for f in L:
		if f.ok or f.src == "o":   # hàng đơn hàng luôn giữ
			for s in f.items:
				e[String(s[0])] = int(e.get(String(s[0]), 0)) + int(s[1])
	for f in L.filter(func(x): return not x.ok).slice(0, 2):
		for s in f.items:
			r[String(s[0])] = mini(10, int(r.get(String(s[0]), 0)) + int(s[1]))
	var cnt := 0
	var xu := 0
	for pass_n in 2:
		var ks: Array = G.g.barn.keys().filter(func(k): return _bn(k) > 0 and not G.item(k).is_empty() and float(G.item(k).get("sell", 0)) > 0)
		ks.sort_custom(func(a, b): return G.price(a) < G.price(b))
		for p in ks:
			if G.kho_room() >= want:
				break
			var d := _bn(p)
			var v: int = int(e.get(p, 0)) + (int(r.get(p, 0)) if pass_n == 0 else 0) + (LP if _crop(p) else 0)
			var x: int = mini(d - v, want - G.kho_room())
			if x > 0:
				xu += G.sell(p, x)
				cnt += x
		if G.kho_room() >= want:
			break
	if cnt:
		G.toast.emit("Auto bán bớt " + str(cnt) + " món cho đỡ chật kho, được " + G.fmt_n(xu) + " xu.")
	return cnt > 0
