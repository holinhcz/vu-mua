extends RefCounted
# THƯ NHÀ, ÔNG ĐƯA THƯ bản web (ui({id:"thu"}): mi, Eg, w6, vU, mU, JN, xU, YN, wU, Mx).
# Mỗi ngày một lá thư: 8g30–12g ông đưa thư đạp xe từ đầu đường làng tới cổng (w6), reng chuông, đứng vẫy 40 giây
# (chạm ông để nhận), hết giờ bỏ thư vô hộp thư trước nhà rồi đạp đi. Thư: gửi tiền (tien), nhờ gửi đồ quê (nho), thăm
# kèm gạch (tin). Đồ chưa đủ thì để dành (rq), mở lại trong Trời đất › Radio, thư nhà. Bảng đọc thư: ui_thu.gd.

var G
var WC    # w_cho.gd (Eg, giờ, yu, v1, s2, ho)
var WL    # w_lang.gd (_vr, _r0)
var U = null

var mi := {"st": 0, "x": 0.0, "y": 0.0, "path": [], "i": 0, "face": 1, "ph": 0.0, "al": 0.0, "wait": 0.0, "ring": 0}
const XN := ["Út Mến", "Hai Lúa", "Thằng Tí", "Bé Na", "Cậu Ba", "Dì Sáu"]

func _init(g) -> void:
	G = g

func Eg() -> Dictionary:
	return WC.Eg()

static func w6() -> Vector2:   # hộp thư trước nhà
	return Vector2(6.5, 5.5)

func _toast(s: String) -> void:
	G.toast.emit(s)

func Mx():   # đường làng: hai đầu hàng y = 5 và cột x = 5 (đường mở)
	var L = G.lang
	if L == null:
		return null
	var t := []
	var a := []
	for n in range(-6, 17):
		if L.fg(n, 5) != "" and L.ci(L.fo(n, 5)):
			t.append(n)
	for n in range(-5, 14):
		if L.fg(5, n) != "" and L.ci(L.fo(5, n)):
			a.append(n)
	if t.size() < 4:
		return null
	var e := [[t[0] + 0.5, 5.5], [t[-1] + 0.5, 5.5], [5.5, 5.5]]
	if a.size() > 3:
		e.append([5.5, a[0] + 0.5])
		e.append([5.5, a[-1] + 0.5])
	else:
		e.append([t[0] + 0.5, 5.5])
	return e

func vU() -> Dictionary:   # lá thư hôm nay
	var t: int = WL._vr()
	var a = WC.yu(t * 131 + 7)
	var n: String = XN[int(floor(a.next() * XN.size()))]
	var e: float = a.next()
	var r: int = WC.v1()
	if e < 0.4:
		return {"k": "tien", "who": n, "xu": G.nv.v0((300.0 + a.next() * 500.0) * (1.0 + 0.6 * r)),
			"txt": n + " ở Sài Gòn viết thư về: \"Con đi làm ở xưởng may cũng đỡ, gửi về chút tiền ông bà tiêu Tết. Nhớ quê lắm, nhớ cá kho tộ với canh chua.\""}
	if e < 0.8:
		var o: Array = WC.s2().filter(func(s): return float(G.item(s).get("sell", 0)) < 200)
		var l: String = String(o[int(floor(a.next() * o.size()))]) if o.size() else "qua_xoai"
		if not o.size():
			a.next()
		var c := float(G.item(l).get("sell", 10))
		if c <= 0:
			c = 10.0
		var f := maxi(2, mini(12, int(round((200.0 + a.next() * 200.0) * (1.0 + 0.4 * r) / c))))
		return {"k": "nho", "who": n, "id": l, "q": f, "xu": int(round(f * G.price0(l) * 1.7)),
			"txt": n + " viết: \"Trên này mua đồ quê đắt mà không ngon. Nhà mình gửi giùm con " + WC.ho(l, f) + " theo đường bưu điện nha, con gửi tiền cước về.\""}
	return {"k": "tin", "who": n, "gach": 3 + int(floor(a.next() * 4)),
		"txt": n + " gửi thư thăm: \"Nghe nói làng mình mới làm cầu bắc qua sông, con mừng lắm. Con gửi kèm mấy viên gạch nung cũ ở nhà chủ cho, để dành sửa nhà.\""}

func step(t: float) -> void:   # mU
	if WC._cr():
		return
	var a := Eg()
	var n: int = WL._vr()
	var e: float = WC._hour()
	if int(mi.st) == 0:
		if int(a.get("d", -1)) == n or e < 8.5 or e >= 12 or WC._mode() != "off":
			return
		var r = Mx()
		if r == null:
			return
		var o := w6()
		mi.path = [[float(r[0][0]), float(r[0][1])], [o.x, o.y]]
		mi.i = 1
		mi.x = float(r[0][0])
		mi.y = float(r[0][1])
		mi.st = 1
		mi.al = 0.0
		mi.ring = 0
		a.d = n
		a.un = vU()
		G.mark()
		return
	mi.ph = float(mi.ph) + t * 6.0
	if int(mi.st) == 1 or int(mi.st) == 3:
		var l: Array = mi.path[int(mi.i)]
		var c := float(l[0]) - float(mi.x)
		var f := float(l[1]) - float(mi.y)
		var s := sqrt(c * c + f * f)
		var h := 1.4 * t
		if absf(c - f) > 0.01:
			mi.face = 1 if c - f > 0 else -1
		mi.al = minf(1.0, float(mi.al) + t) if int(mi.st) == 1 else maxf(0.0, float(mi.al) - t * 0.6)
		if s <= h:
			mi.x = float(l[0])
			mi.y = float(l[1])
			if int(mi.st) == 1:
				mi.st = 2
				mi.wait = 40.0
				mi.ring = 1
				_toast("Reng reng! Ông đưa thư tới cổng, có thư cho bạn. Chạm ông để nhận.")
			else:
				mi.st = 0
		else:
			mi.x = float(mi.x) + c / s * h
			mi.y = float(mi.y) + f / s * h
		if int(mi.st) == 3 and float(mi.al) <= 0.0:
			mi.st = 0
		return
	if int(mi.st) == 2:
		mi.wait = float(mi.wait) - t
		if float(mi.wait) <= 0.0:
			JN(true)

func JN(t: bool) -> void:   # ông bỏ thư vô hộp rồi đạp đi
	var a = Mx()
	mi.path = [[float(mi.x), float(mi.y)], [float(a[-1][0]), float(a[-1][1])] if a != null else [float(mi.x) + 8.0, float(mi.y)]]
	mi.i = 1
	mi.st = 3
	if t:
		_toast("Ông đưa thư bỏ thư vô hộp thư trước nhà rồi đạp đi. Chạm biểu tượng thư để đọc.")

func hit(F, w: Vector2):   # xU: chạm ông đưa thư (đang đứng chờ) hoặc hộp thư có thư
	var n := Eg()
	var le: float = F.sign_le()
	if int(mi.st) == 2:
		var e: float = F.en(float(mi.x), float(mi.y))
		var r: float = F.nn(float(mi.x), float(mi.y))
		if absf(w.x - e) < 16.0 * le and w.y > r - 56.0 * le and w.y < r + 6.0:
			return {"type": "thu"}
	if _tr(n.get("un")) and int(mi.st) != 2:
		var o := w6()
		var l: float = F.en(o.x + 0.35, o.y - 0.3)
		var c: float = F.nn(o.x + 0.35, o.y - 0.3)
		if absf(w.x - l) < 16.0 and w.y > c - 52.0 and w.y < c + 4.0:
			return {"type": "thu"}
	return null

func YN() -> void:   # mở thư
	var t := Eg()
	if not _tr(t.get("un")) and not _tr(t.get("rq")):
		_toast("Chưa có thư mới.")
		return
	if int(mi.st) == 2:
		JN(false)
	if U != null:
		U.thu_open()

func wU(t: String) -> void:   # nút trong bảng thư
	var a := Eg()
	var n = a.get("un")
	if t == "nhan" and _tr(n):
		if n.k == "tien":
			G.g.coins = int(G.g.coins) + int(n.xu)
		else:
			var e: Dictionary = WL._r0()
			e.gach = int(e.get("gach", 0)) + int(n.gach)
		_lg(a, String(n.who), ("+" + G.fmt_n(int(n.xu)) + " xu") if n.k == "tien" else ("+" + str(int(n.gach)) + " gạch"), "xu" if n.k == "tien" else "svg:res://ui/svg/mat/gach.svg", String(n.k))
		a.un = null
		_toast("Đọc thư xong xếp vô hộp, ấm lòng ghê.")
	elif t == "gui" and _tr(n):
		if int(G.g.barn.get(n.id, 0)) < int(n.q):
			return
		G.g.barn[n.id] = int(G.g.barn[n.id]) - int(n.q)
		G.g.coins = int(G.g.coins) + int(n.xu)
		_lg(a, String(n.who), "Gửi " + WC.ho(String(n.id), int(n.q)), String(n.id), "nho")
		a.un = null
		_toast("Gói đồ quê gửi bưu điện lên cho " + String(n.who) + ". Nhận " + G.fmt_n(int(n.xu)) + " xu tiền cước gửi về.")
		G.w_all.qi("thu")
	elif t == "de" and _tr(n):
		a.rq = {"id": n.id, "q": n.q, "xu": n.xu, "who": n.who}
		a.un = null
		_close()
		_toast("Để dành gửi sau. Chạm hộp thư trước nhà để mở lại.")
	elif t == "gui2" and _tr(a.get("rq")):
		var r: Dictionary = a.rq
		if int(G.g.barn.get(r.id, 0)) < int(r.q):
			return
		G.g.barn[r.id] = int(G.g.barn[r.id]) - int(r.q)
		G.g.coins = int(G.g.coins) + int(r.xu)
		_lg(a, String(r.who), "Gửi " + WC.ho(String(r.id), int(r.q)), String(r.id), "nho")
		a.rq = null
		_toast("Đã gửi đồ quê lên cho " + String(r.who) + ", nhận " + G.fmt_n(int(r.xu)) + " xu.")
	G.mark()
	if not _tr(a.get("un")) and not _tr(a.get("rq")):
		_close()

func _lg(a: Dictionary, who: String, s: String, ic: String, k: String) -> void:   # (bản 491) Thư cũ: lá mới lên đầu, giữ 10 lá; ic hình kết quả, k loại thư
	var L: Array = a.get("lg", []) if a.get("lg") is Array else []
	L.push_front({"w": who, "s": s, "ic": ic, "k": k, "d": WL._vr()})
	a.lg = L.slice(0, 10)

func _close() -> void:
	if U != null and U.thup != null:
		U.thup.close()

static func _tr(v) -> bool:
	return not (v == null or v is bool and not v or (v is float or v is int) and v == 0 or v is String and v == "")
