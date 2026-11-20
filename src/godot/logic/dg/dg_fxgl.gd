extends RefCounted
# ĐUA GÀ: hiệu ứng skill / món đồ vẽ bằng shader (bản web: sec_fxgl.js, lớp WebGL2 v40), chép 1:1.
# Hạt (sao, lông, lá lúa, bông điên điển, giọt nước / bùn / sữa, mây bụi, lửa, chớp nổ, vòng sóng, vòng âm, gió,
# bắn nước, nhúm lông thú, cục đất...) sống trong thế giới (đơn vị web), mỗi khung chiếu ra màn hình rồi gói thành
# lưới tam giác: CUSTOM0 = (1 + hình + 50 mực + 100 sáng, tuổi, ngẫu nhiên, w), shader logic/dg/dg_fx.gdshader vẽ hình.
# Bản web vẽ lớp này trên một canvas WebGL nằm trên trang; ở đây lưới chen vào danh sách độ sâu của dg_view
# (giữa các con đua), vết trên mặt đất vẽ ở lớp riêng ngay trên mặt đất.

const GS := {"glow": 0, "flame": 1, "cloud": 2, "streak": 3, "ring": 4, "star": 5, "spark": 6, "rect": 7, "drop": 8, "ribbon": 9, "slash": 10, "shock": 11, "feather": 12, "arc": 13, "leaf": 14, "flower": 15, "bubble": 16, "burst": 17, "tuft": 18, "splash": 19, "gust": 20}
const GQUAD := ["cho", "meo", "cuu", "de", "heo", "bo", "trau"]
const CAP := 2600
const FX_HEAD := {"delua": 27.0, "dongtao": 50.4, "vang": 38.9, "trong": 46.8, "mai": 38.9, "tay": 42.8, "vit": 34.2, "ac": 35.0, "tre": 40.5, "ngong": 51.5, "cho": 38.1, "meo": 39.7, "cuu": 38.9, "de": 42.8, "heo": 35.7, "bo": 43.6, "trau": 42.8}

static var GC := {}
static func _gc() -> void:
	if GC.size():
		return
	var h := {"gold": "#f7c531", "mint": "#86dcb8", "leaf": "#5fae3a", "leaf2": "#9ccc48", "yel": "#ffd23a",
		"red": "#d8331e", "org": "#ff8a26", "amb": "#ffb23a", "cream": "#fff1cf", "yolk": "#ffb21e", "shell": "#f6ead2",
		"bronze": "#a8743e", "chest": "#6e4126", "teal": "#2f9a92", "water": "#72c6ea", "foam": "#e6f6ff",
		"indigo": "#5a46b0", "violet": "#a06ee6", "sky": "#93cdff", "silk": "#34313c", "pale": "#ffe79a",
		"ginger": "#e8902a", "claw": "#fff4e0", "wool": "#f7f0e2", "pink": "#f27fa2",
		"steel": "#5f95d6", "ice": "#a8dcff", "ivory": "#f3e5c2", "mud": "#6e4826", "mud2": "#86592e", "bub": "#b08454",
		"milk": "#fbf8f0", "milkc": "#fff3d6", "milkb": "#bcd3ea", "earth": "#7a5634", "clod": "#5a3c22", "dust": "#e2c792", "dust2": "#d2b27c", "steam": "#f2f0ea",
		"gustc": "#a6ecd0", "smoke": "#6b5c52", "hit": "#ffd23f", "hit2": "#ff9a2a"}
	for k in h:
		GC[k] = Color(h[k])

static func HX(s: String) -> Color:
	return Color(s)

static func A0(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, a)

static func RG(a: float, b: float) -> float:
	return a + randf() * (b - a)

static func PK(a: Array):
	return a[randi() % a.size()]

class Pt extends RefCounted:
	var sh := 0
	var x := 0.0
	var y := 0.0
	var z := 0.0
	var vx := 0.0
	var vy := 0.0
	var vz := 0.0
	var t := 0.0
	var life := 0.5
	var s0 := 6.0
	var s1 := 6.0
	var ez := 0
	var c0 := Color.WHITE
	var c1 = null
	var fo := 1.0
	var fi := 0.0
	var add := false
	var dual := false
	var ink := false
	var gr := false
	var drag := 0.0
	var g := 0.0
	var rot := 0.0
	var vr := 0.0
	var str := 0.0
	var wf := 0.35
	var w := 0.5
	var sd := 0.0
	var asp := 1.0
	var tw := 0
	var face := 0
	var aim = null
	var fol = null
	var loc := false
	var orb := 0.0
	var orr := 0.0
	var a0 := 0.0
	var still := false
	var cap := 0.0
	var wl = null
	var front := false
	var gz := 0.0
	# mỗi khung
	var _p := -1
	var _k := 0.0
	var _a := 1.0
	var _z := 0.0
	var _x := 0.0
	var _y := 0.0
	var _r := 0.0
	var _l := 0.0
	var _lx := 0.0
	var _ly := 0.0
	var _rot := 0.0

class Rib extends RefCounted:
	var pts: Array = []
	var hw := 2.0
	var life := 0.25
	var c0 := Color.WHITE
	var c1 = null
	var ink := false
	var w := 6.0
	var loop := false
	var last := 0.0
	var key := ""
	var _s: Array = []
	var _g: Array = []

var R          # dg_race
var V          # dg_view (chiếu)
var P: Array = []
var RB: Array = []
var RBK := {}
var RX := {}   # trạng thái riêng mỗi con (web để thẳng trên r: _cw, _cs, _rp, _kk, _ks, _fw, _st, _shK)
var clock := 0.0

func _init(race) -> void:
	R = race
	_gc()

func clear() -> void:
	P.clear()
	RB.clear()
	RBK.clear()
	RX.clear()

func _x(r) -> Dictionary:
	var k: int = r.get_instance_id()
	if not RX.has(k):
		RX[k] = {}
	return RX[k]

# một hạt (cỡ theo đơn vị thế giới, con đua cao chừng 40); c0/c1 màu; add: lớp sáng; gr: nằm trên mặt đất;
# fol: chạy theo một con (x,y,z là độ lệch từ chân, xoay theo nó khi loc); orb: bay vòng quanh; wl: sống khi còn đúng
func gp(o: Dictionary):
	if P.size() >= CAP:
		return null
	var f := Pt.new()
	f.sd = randf()
	for k: String in o:
		f.set(k, o[k])
	P.append(f)
	return f

# chân con đua cao bao nhiêu (nhảy, dốc rơm)
func rH(r) -> float:
	if r.hopT > 0 and not r.hop.is_empty():
		return sin(PI * (1.0 - r.hopT / float(r.hop.dur))) * 70.0
	return r.z if r.z != 0 else r.rampH

func rVel(r) -> Vector2:
	if r.hopT > 0 and not r.hop.is_empty():
		return Vector2((r.hop.tx - r.hop.fx) / r.hop.dur, (r.hop.ty - r.hop.fy) / r.hop.dur)
	return Vector2(cos(r.md) * r.spd, sin(r.md) * r.spd)

# một điểm theo con đua: f phía trước, s bên phải
func rAt(r, f: float, s: float) -> Vector2:
	var ca := cos(r.a)
	var sa := sin(r.a)
	return Vector2(r.x + ca * f - sa * s, r.y + sa * f + ca * s)

func rSz(r) -> float:
	return float(r.ch.get("size", 1))

func fxHead(r) -> float:
	return float(FX_HEAD.get(r.id, 40.0))

func near(r) -> bool:
	return R.player != null and R.near(r)

func gpos(f: Pt) -> Vector3:
	var A = f.fol
	if A == null:
		return Vector3(f.x, f.y, f.z)
	var ax: float = A.x
	var ay: float = A.y
	var az := rH(A)
	if f.orb:
		return Vector3(ax + cos(f.a0) * f.orr, ay + sin(f.a0) * f.orr, az + f.z + sin(f.a0 * 2 + f.sd * 6) * 2)
	if f.loc:
		var ca := cos(A.a)
		var sa := sin(A.a)
		return Vector3(ax + ca * f.x - sa * f.y, ay + sa * f.x + ca * f.y, az + f.z)
	return Vector3(ax + f.x, ay + f.y, az + f.z)

# một vệt dải lụa, giữ theo chủ của nó và tên
func rib(key: String, opt: Dictionary) -> Rib:
	var r: Rib = RBK.get(key)
	if r == null:
		r = Rib.new()
		r.key = key
		r.last = clock
		for k: String in opt:
			r.set(k, opt[k])
		RBK[key] = r
		RB.append(r)
	r.last = clock
	return r

# ---------------------------------------------------------------- bộ hạt dùng chung (FXG của web)
func ring(o, x: float, y: float, col: Color, R0: float, R1: float, life: float, w: float, del := 0.0, ink := false, a := 1.0):
	return gp({"sh": GS.ring, "gr": true, "fol": o, "x": x, "y": y, "s0": R0, "s1": R1, "ez": 1, "life": life, "t": -del, "c0": A0(col, a), "c1": A0(col, 0), "w": w, "ink": ink})

func clouds(x: float, y: float, z: float, n: int, col: Color, sp: float, s0: float, s1: float, life: float, ink: float, vx := 0.0, vy := 0.0, up := 40.0) -> void:
	for i in n:
		var a := RG(0, TAU)
		var v := RG(0.5, 1) * sp
		gp({"sh": GS.cloud, "ink": ink > 0, "w": ink, "x": x + cos(a) * 4, "y": y + sin(a) * 4, "z": z + RG(0, 6), "vx": vx + cos(a) * v, "vy": vy + sin(a) * v, "vz": RG(0.2, 1) * up, "drag": 2.6, "life": RG(0.8, 1.2) * life, "s0": s0 * RG(1, 1.4), "s1": s1 * RG(1.15, 1.5), "c0": A0(col, 0.88), "c1": A0(col, 0), "fo": 0.5, "cap": 70.0})

func drops(x: float, y: float, z: float, n: int, cols: Array, sp: float, up: float, s: float, vx := 0.0, vy := 0.0, gloss := 0.8, q := 8.0) -> void:
	for i in n:
		var a := RG(0, TAU)
		var v := RG(0.5, 1) * sp
		var c: Color = PK(cols)
		gp({"sh": GS.drop, "ink": true, "x": x + cos(a) * q, "y": y + sin(a) * q, "z": z, "vx": vx + cos(a) * v, "vy": vy + sin(a) * v, "vz": RG(0.55, 1) * up, "g": 900.0, "drag": 0.5, "life": RG(0.4, 0.62), "s0": s * RG(0.5, 0.75), "s1": s * 0.4, "str": 0.01, "wf": 1.0, "c0": c, "c1": c, "fo": 0.75, "w": gloss, "cap": 16.0})

func feathers(x: float, y: float, z: float, n: int, cols: Array, sp: float, s: float, vx := 0.0, vy := 0.0, pat := 0.0) -> void:
	for i in n:
		var a := RG(0, TAU)
		var v := RG(0.4, 1) * sp
		var c: Color = PK(cols)
		gp({"sh": GS.feather, "ink": true, "x": x, "y": y, "z": z + RG(-4, 6), "vx": vx * 0.6 + cos(a) * v, "vy": vy * 0.6 + sin(a) * v, "vz": RG(60, 170), "g": 150.0, "drag": 2.4, "life": RG(1, 1.5), "s0": s * RG(0.8, 1.15), "s1": s, "rot": RG(0, TAU), "vr": RG(-3, 3), "c0": c, "c1": c, "fo": 0.6, "w": pat, "cap": 24.0})

func tufts(x: float, y: float, z: float, n: int, cols: Array, sp: float, s: float, vx := 0.0, vy := 0.0) -> void:
	for i in n:
		var a := RG(0, TAU)
		var v := RG(0.4, 1) * sp
		var c: Color = PK(cols)
		gp({"sh": GS.tuft, "ink": true, "x": x, "y": y, "z": z + RG(-4, 6), "vx": vx * 0.6 + cos(a) * v, "vy": vy * 0.6 + sin(a) * v, "vz": RG(60, 160), "g": 260.0, "drag": 2.2, "life": RG(0.7, 1), "s0": s * RG(0.8, 1.15), "s1": s * 0.8, "rot": RG(0, TAU), "vr": RG(-8, 8), "c0": c, "c1": c, "fo": 0.6, "cap": 20.0})

# cục đất: mẩu nhỏ có viền lăn lộn, không phải giọt bóng
func clods(x: float, y: float, z: float, n: int, cols: Array, sp: float, up: float, s: float, vx := 0.0, vy := 0.0) -> void:
	for i in n:
		var a := RG(0, TAU)
		var v := RG(0.5, 1) * sp
		var c: Color = PK(cols)
		gp({"sh": GS.rect, "ink": true, "x": x + cos(a) * 8, "y": y + sin(a) * 8, "z": z, "vx": vx + cos(a) * v, "vy": vy + sin(a) * v, "vz": RG(0.55, 1) * up, "g": 900.0, "drag": 0.5, "life": RG(0.4, 0.62), "s0": s * RG(0.5, 0.8), "s1": s * 0.45, "asp": RG(0.7, 0.95), "rot": RG(0, TAU), "vr": RG(-14, 14), "c0": c, "c1": c, "fo": 0.75, "w": 1.0, "cap": 12.0})

# một vũng bắn lên (nước, bùn, sữa) đứng trên mặt đất ở x,y
func crown(x: float, y: float, s: float, col: Color, life: float, gloss := 0.8, del := 0.0, o := {}):
	var d := {"sh": GS.splash, "ink": true, "x": x, "y": y, "z": s * 0.74, "t": -del, "life": life, "s0": s, "s1": s, "c0": col, "c1": col, "fo": 0.85, "w": gloss, "cap": 120.0}
	d.merge(o, true)
	return gp(d)

func sparks(x: float, y: float, z: float, n: int, cols: Array, sp: float, s: float, life: float, vx := 0.0, vy := 0.0, o := {}) -> void:
	for i in n:
		var a := RG(0, TAU)
		var v := RG(0.3, 1) * sp
		var c: Color = PK(cols)
		var d := {"sh": GS.spark, "add": true, "x": x, "y": y, "z": z, "vx": vx + cos(a) * v, "vy": vy + sin(a) * v, "vz": RG(-0.3, 1) * sp * 0.6, "drag": 2.2, "life": RG(0.7, 1.2) * life, "s0": s * RG(0.8, 1.2), "s1": s * 0.15, "tw": 1, "c0": A0(c, 1), "c1": A0(c, 0)}
		d.merge(o, true)
		gp(d)

func stars(x: float, y: float, z: float, n: int, col: Color, sp: float, s: float, vx := 0.0, vy := 0.0) -> void:
	for i in n:
		var a := RG(0, TAU)
		var v := RG(0.5, 1) * sp
		gp({"sh": GS.star, "ink": true, "x": x, "y": y, "z": z, "vx": vx + cos(a) * v, "vy": vy + sin(a) * v, "vz": RG(90, 200), "g": 380.0, "drag": 1.4, "life": RG(0.55, 0.8), "s0": s * 0.4, "s1": s, "ez": 1, "rot": RG(-0.4, 0.4), "vr": RG(-5, 5), "c0": col, "c1": col, "fo": 0.6})

func burst(o, x: float, y: float, z: float, col: Color, s0: float, s1: float, life: float, loc := false):
	return gp({"sh": GS.burst, "ink": true, "fol": o, "loc": loc, "x": x, "y": y, "z": z, "life": life, "s0": s0, "s1": s1, "ez": 1, "rot": RG(0, TAU), "c0": col, "c1": col, "fo": 0.45})

func _front(f) -> void:
	if f != null:
		f.front = true

# tia chớp gãy khúc, vẽ bằng các đoạn đứng yên
func zap(x: float, y: float, z: float, col: Color, len: float, n: int) -> void:
	var px := x
	var py := y
	var pz := z
	var a0 := RG(0, TAU)
	var e0 := RG(-0.6, 0.9)
	for i in n:
		var a := a0 + RG(-0.9, 0.9)
		var e := e0 + RG(-0.7, 0.7)
		var l := len / n * RG(0.7, 1.3)
		var dx := cos(a) * cos(e)
		var dy := sin(a) * cos(e)
		var dz := sin(e)
		gp({"sh": GS.streak, "dual": true, "still": true, "x": px + dx * l * 0.5, "y": py + dy * l * 0.5, "z": pz + dz * l * 0.5, "vx": dx * l / 0.1, "vy": dy * l / 0.1, "vz": dz * l / 0.1, "str": 0.05, "wf": 0.3, "life": 0.14, "s0": 2.6, "s1": 1.6, "c0": A0(col, 1), "c1": A0(col, 0)})
		px += dx * l
		py += dy * l
		pz += dz * l

# ---------------------------------------------------------------- skill nổ ra
# Dậm Đất: mỗi lần dậm vòng bụi lan trên đất, cục đất văng, đám bụi thấp
func stomp(r) -> void:
	if not near(r):
		return
	ring(null, r.x, r.y, HX("#ead3a6"), 10, 210, 0.5, 0.13, 0, true)
	ring(null, r.x, r.y, HX("#a07c50"), 8, 140, 0.42, 0.09, 0.06, true)
	clouds(r.x, r.y, 2, 9, HX("#d9c39c"), 230, 9, 20, 0.75, 0.6, 0, 0, 30)
	clods(r.x, r.y, 4, 8, [HX("#8a6a44"), HX("#6e5236"), HX("#a8875a")], 170, 280, 5.5)

# Gáy Thách Đấu: mỗi tiếng gáy một loạt vòng âm ngang đầu
func chirp(r) -> void:
	if not near(r):
		return
	ring(null, r.x, r.y, HX("#fff1b8"), 12, 230, 0.48, 0.17, 0, true)
	ring(null, r.x, r.y, HX("#f2a23a"), 10, 185, 0.42, 0.14, 0.06, true)
	ring(null, r.x, r.y, HX("#ffd25a"), 8, 130, 0.36, 0.12, 0.12, true)

func _cast(r, H: float, sz: float, vx: float, vy: float) -> void:
	match String(r.id):
		"delua":
			_front(burst(r, 12 * sz, 0, H * 0.8, GC.gold, 5, 12, 0.2, true))
		"dongtao":
			_front(burst(r, 14 * sz, 0, H * 0.8, GC.org, 5, 13, 0.22, true))
		"vang":
			ring(r, 0, 0, GC.mint, 6, 74 * sz, 0.42, 0.12, 0, true)
			ring(r, 0, 0, GC.gold, 4, 48 * sz, 0.36, 0.1, 0.06, true)
			for i in 6:
				var a := i / 6.0 * TAU + RG(-0.3, 0.3)
				var Rr := RG(18, 24) * sz
				var sd := -1.0 if sin(a) < 0 else 1.0
				gp({"sh": GS.gust, "ink": true, "fol": r, "loc": true, "x": cos(a) * Rr, "y": sin(a) * Rr, "z": H * RG(0.25, 0.85), "vx": -sin(a) * 260 - 90, "vy": cos(a) * 260, "t": -i * 0.03, "face": 1, "asp": sd, "life": 0.6, "s0": 17 * sz, "s1": 19 * sz, "c0": GC.gustc, "c1": GC.gustc, "fo": 0.8, "cap": 130.0})
			for i in 12:
				var a := RG(0, TAU)
				var v := RG(150, 280)
				var fl := i % 3 == 0
				gp({"sh": GS.flower if fl else GS.leaf, "ink": true, "x": r.x + cos(a) * 10, "y": r.y + sin(a) * 10, "z": rH(r) + RG(4, H * 0.8), "vx": vx * 0.9 + cos(a) * v, "vy": vy * 0.9 + sin(a) * v, "vz": RG(40, 170), "g": 130.0, "drag": 2.2,
					"life": RG(0.8, 1.2), "s0": RG(4, 4.8) if fl else RG(6.2, 7.6), "s1": 3.8 if fl else 6.4, "rot": RG(0, TAU), "vr": RG(-6, 6), "c0": GC.yel if fl else PK([GC.leaf, GC.leaf2]), "fo": 0.65})
			gp({"sh": GS.glow, "fol": r, "z": H * 0.5, "life": 0.35, "s0": 22 * sz, "s1": 36 * sz, "c0": A0(GC.mint, 0.28), "c1": A0(GC.mint, 0), "w": 0.4})
		"trong":
			for i in 3:
				ring(r, 0, 0, GC.red if i == 1 else GC.amb, 12, 300, 0.58, 0.055 - i * 0.01, i * 0.09, true)
			for i in 20:
				var a := i / 20.0 * TAU + RG(-0.08, 0.08)
				var v := RG(540, 650)
				gp({"sh": GS.cloud, "ink": true, "w": 0.4, "fol": r, "x": cos(a) * 16, "y": sin(a) * 16, "z": 6.0, "vx": cos(a) * v, "vy": sin(a) * v, "vz": RG(20, 60), "drag": 2.1,
					"life": RG(0.5, 0.65), "s0": RG(7, 9), "s1": RG(16, 20), "c0": A0(GC.dust, 0.8), "c1": A0(GC.dust, 0), "fo": 0.3, "cap": 75.0})
			for k in 3:
				for sd in [-1.0, 1.0]:
					var col: Color = GC.red if k == 1 else GC.org
					gp({"sh": GS.arc, "ink": true, "fol": r, "loc": true, "x": 4.0, "y": sd * 8, "z": H * 0.82, "vx": 30.0, "vy": sd * 260, "vz": 30.0, "t": -k * 0.1, "face": 1, "life": 0.45, "s0": 7.0, "s1": 22.0, "ez": 1, "c0": A0(col, 1), "c1": A0(col, 0), "w": 0.28, "fo": 0.5, "cap": 80.0})
					gp({"sh": GS.arc, "ink": true, "fol": r, "loc": true, "x": 12.0, "y": sd * 4, "z": H * 0.86, "vx": 300.0, "vy": sd * 90, "vz": 20.0, "t": -k * 0.1 - 0.05, "face": 1, "life": 0.42, "s0": 6.0, "s1": 18.0, "ez": 1, "c0": A0(col, 1), "c1": A0(col, 0), "w": 0.28, "fo": 0.5, "cap": 80.0})
			_front(burst(r, 8, 0, H * 0.85, GC.amb, 4, 11, 0.2, true))
			sparks(r.x, r.y, rH(r) + H * 0.85, 10, [GC.amb, GC.gold, GC.org], 160, 4, 0.5)
		"mai":
			var n := 0
			for i in range(R.eggs.size() - 1, -1, -1):
				if n >= 3:
					break
				n += 1
				if R.eggs[i].owner == r:
					R.eggs[i].sk = 1
			feathers(r.x, r.y, rH(r) + H * 0.55, 6, [GC.cream, HX("#e8cf9a")], 120, 6, vx, vy)
			var p := rAt(r, 14, 0)
			sparks(p.x, p.y, rH(r) + H * 0.5, 8, [GC.gold, GC.yolk, GC.cream], 180, 4, 0.4, vx * 0.8, vy * 0.8)
			ring(r, 0, 0, GC.yolk, 6, 40 * sz, 0.3, 0.12, 0, true)
		"tay":
			var C := [GC.bronze, GC.chest, HX("#b9844a")]
			for i in 11:
				var th := (i / 10.0 - 0.5) * 2.7
				gp({"sh": GS.feather, "ink": true, "fol": r, "loc": true, "x": -8 * sz, "y": sin(th) * 19 * sz, "z": H * 0.52 + cos(th) * 19 * sz, "still": true, "face": 2, "aim": [-8 * sz, 0.0, H * 0.52], "life": 0.5, "s0": 4.0, "s1": 12 * sz, "ez": 1, "c0": C[i % 3], "c1": C[i % 3], "fo": 0.72, "w": 1.0})
			ring(r, 0, 0, GC.teal, 8, 52 * sz, 0.35, 0.12, 0, true)
			sparks(r.x, r.y, rH(r) + H * 0.5, 8, [GC.teal, GC.gold], 150, 4, 0.5)
		"vit":
			for sd in [-1.0, 1.0]:
				var p := rAt(r, -2 * sz, sd * 15 * sz)
				crown(p.x, p.y, 13 * sz, HX("#7cccf0"), 0.55, 0.9, 0.05 if sd > 0 else 0.0, {"vx": vx * 0.7, "vy": vy * 0.7})
				p = rAt(r, -14 * sz, sd * 9 * sz)
				crown(p.x, p.y, 8 * sz, HX("#8fd6f4"), 0.45, 0.9, 0.12, {"vx": vx * 0.7, "vy": vy * 0.7})
			drops(r.x, r.y, rH(r) + 8, 8, [GC.water, GC.foam], 150, 300, 2.8, vx * 0.7, vy * 0.7)
			gp({"sh": GS.ring, "gr": true, "x": r.x, "y": r.y, "s0": 6.0, "s1": 62.0, "ez": 1, "life": 0.6, "c0": A0(GC.foam, 0.9), "c1": A0(GC.foam, 0), "w": 0.06})
			gp({"sh": GS.ring, "gr": true, "x": r.x, "y": r.y, "t": -0.12, "s0": 6.0, "s1": 42.0, "ez": 1, "life": 0.6, "c0": A0(GC.water, 0.9), "c1": A0(GC.water, 0), "w": 0.08})
		"ac":
			ring(null, r.x, r.y, GC.violet, 8, 64, 0.45, 0.1, 0, true)
			feathers(r.x, r.y, H * 0.5, 5, [HX("#4a4656"), HX("#5e5874")], 150, 4.6, vx, vy, 2)
			sparks(r.x, r.y, H * 0.5, 10, [GC.violet, GC.sky, GC.indigo], 200, 5, 0.6, vx * 0.5, vy * 0.5)
			stars(r.x, r.y, H * 0.6, 2, GC.pale, 120, 5, vx * 0.5, vy * 0.5)
			clouds(r.x, r.y, 2, 8, HX("#bcb4cc"), 120, 5, 11, 0.5, 0.5)
		"tre":
			for sd in [-1.0, 1.0]:
				gp({"sh": GS.slash, "ink": true, "front": true, "fol": r, "loc": true, "x": 6 * sz, "y": sd * 15 * sz, "z": H * 0.42, "still": true, "rot": sd * 0.35, "t": -0.13 if sd > 0 else 0.0, "life": 0.24, "s0": 15.0, "s1": 22.0, "ez": 1, "c0": GC.amb if sd > 0 else GC.org, "c1": GC.org, "fo": 0.45, "cap": 110.0})
				gp({"sh": GS.burst, "ink": true, "front": true, "fol": r, "loc": true, "x": 8 * sz, "y": sd * 30 * sz, "z": H * 0.46, "t": (-0.13 if sd > 0 else 0.0) - 0.06, "life": 0.16, "s0": 3.0, "s1": 8.0, "ez": 1, "rot": RG(0, TAU), "c0": GC.yel, "c1": GC.yel, "fo": 0.4})
			ring(r, 0, 0, GC.org, 8, 44 * sz, 0.32, 0.12, 0, true)
			for i in 12:
				var a: float = r.a + RG(-1, 1)
				var v := RG(200, 380)
				gp({"sh": GS.streak, "dual": true, "x": r.x, "y": r.y, "z": rH(r) + H * 0.45, "vx": vx + cos(a) * v, "vy": vy + sin(a) * v, "vz": RG(-40, 160), "g": 300.0, "drag": 2.0, "life": RG(0.2, 0.35), "s0": 3.4, "s1": 1.4, "str": 0.05, "c0": A0(GC.gold, 1), "c1": A0(GC.org, 0)})
		"ngong":
			for i in 6:
				var col: Color = HX("#5fb2ef") if (i >> 1) % 2 else GC.sky
				var sd := 1.0 if i % 2 else -1.0
				gp({"sh": GS.arc, "ink": true, "fol": r, "loc": true, "x": 18 * sz, "y": sd * 7 * sz, "z": H * 0.84, "vx": 170.0, "vy": sd * 250, "vz": 10.0, "t": -(i >> 1) * 0.1, "drag": 0.8, "face": 1, "life": 0.5, "s0": 8.0, "s1": 26.0, "ez": 1, "c0": A0(col, 1), "c1": A0(col, 0), "w": 0.32, "fo": 0.55, "cap": 90.0})
			for i in 3:
				var col: Color = HX("#9fd6ff") if i == 1 else HX("#5fb2ef")
				gp({"sh": GS.arc, "gr": true, "fol": r, "loc": true, "t": -i * 0.09, "life": 0.52, "s0": 30.0, "s1": 400.0, "ez": 1, "c0": A0(col, 1), "c1": A0(col, 0), "w": 0.09, "ink": true})
			_front(burst(r, 15 * sz, 0, H * 0.8, GC.cream, 4, 10, 0.18, true))
			feathers(r.x, r.y, rH(r) + H * 0.6, 5, [GC.wool, GC.shell], 110, 4.6)
		"cho":
			_front(burst(r, 16 * sz, 0, H * 0.78, GC.amb, 5, 13, 0.22, true))
			for sd in [-1.0, 1.0]:
				gp({"sh": GS.arc, "ink": true, "fol": r, "loc": true, "x": 18 * sz, "y": sd * 6, "z": H * 0.8, "vx": 220.0, "vy": sd * 160, "face": 1, "life": 0.36, "s0": 5.0, "s1": 14.0, "ez": 1, "c0": A0(GC.amb, 1), "c1": A0(GC.amb, 0), "w": 0.2, "fo": 0.5, "cap": 60.0})
			ring(r, 0, 0, GC.amb, 8, 50 * sz, 0.34, 0.12, 0, true)
			clouds(r.x, r.y, 3, 10, GC.dust, 240, 5, 12, 0.55, 0.6, vx * 0.5, vy * 0.5)
		"meo":
			clouds(r.x, r.y, 2, 8, GC.dust, 160, 5, 11, 0.5, 0.6)
			sparks(r.x, r.y, H * 0.5, 10, [GC.ginger, GC.gold], 160, 4, 0.5, vx * 0.4, vy * 0.4)
		"cuu":
			clouds(r.x, r.y, rH(r) + H * 0.4, 8, GC.wool, 200, 5, 10, 0.55, 0.7, vx * 0.5, vy * 0.5, 70)
			ring(r, 0, 0, GC.pink, 8, 50 * sz, 0.36, 0.11, 0, true)
		"de":
			gp({"sh": GS.arc, "gr": true, "fol": r, "loc": true, "life": 0.42, "s0": 30.0, "s1": 270.0, "ez": 1, "c0": A0(HX("#4f86d0"), 1), "c1": A0(HX("#4f86d0"), 0), "w": 0.1, "ink": true})
			_front(burst(r, 18 * sz, 0, H * 0.7, GC.ivory, 5, 12, 0.2, true))
			for i in 14:
				var a: float = r.a + RG(-0.9, 0.9)
				var v := RG(240, 420)
				gp({"sh": GS.streak, "dual": true, "x": r.x + cos(r.a) * 16 * sz, "y": r.y + sin(r.a) * 16 * sz, "z": rH(r) + H * 0.8, "vx": vx + cos(a) * v, "vy": vy + sin(a) * v, "vz": RG(40, 220), "g": 500.0, "drag": 1.6, "life": RG(0.25, 0.45), "s0": 3.2, "s1": 1.2, "str": 0.05, "c0": A0(GC.ivory, 1), "c1": A0(GC.amb, 0)})
			clouds(r.x, r.y, 2, 8, GC.dust, 200, 5, 11, 0.5, 0.6, vx * 0.5, vy * 0.5)
		"heo":
			for sd in [-1.0, 1.0]:
				var p := rAt(r, -2 * sz, sd * 16 * sz)
				crown(p.x, p.y, 14 * sz, GC.mud2, 0.55, 0.6, 0.05 if sd > 0 else 0.0, {"vx": vx * 0.7, "vy": vy * 0.7})
			drops(r.x, r.y, rH(r) + 8, 6, [GC.mud, GC.mud2], 160, 300, 3, vx * 0.6, vy * 0.6, 0.3)
			var b := rAt(r, -40, 0)
			gp({"sh": GS.ring, "gr": true, "x": b.x, "y": b.y, "s0": 10.0, "s1": 52.0, "ez": 1, "life": 0.5, "c0": A0(GC.mud, 0.85), "c1": A0(GC.mud, 0), "w": 0.12, "ink": true})
			crown(b.x, b.y, 10, GC.mud2, 0.45, 0.6, 0.1)
		"bo":
			for sd in [-1.0, 1.0]:
				var p := rAt(r, -2 * sz, sd * 16 * sz)
				crown(p.x, p.y, 11 * sz, GC.milkc, 0.55, 0.7, 0.05 if sd > 0 else 0.0, {"vx": vx * 0.7, "vy": vy * 0.7})
			drops(r.x, r.y, rH(r) + H * 0.3, 8, [GC.milk, HX("#fff4dc")], 160, 320, 3, vx * 0.7, vy * 0.7, 0.6)
			ring(r, 0, 0, GC.milkb, 8, 56 * sz, 0.4, 0.11, 0, true)
			clouds(r.x, r.y, 4, 6, GC.milk, 160, 6, 12, 0.6, 0.35, vx * 0.5, vy * 0.5)
		"trau":
			clods(r.x, r.y, 4, 18, [GC.clod, GC.earth, GC.mud], 220, 320, 3.4, vx * 0.5, vy * 0.5)
			for i in 18:
				var a := i / 18.0 * TAU + RG(-0.1, 0.1)
				var v := RG(290, 390)
				gp({"sh": GS.cloud, "ink": true, "w": 0.45, "fol": r, "x": cos(a) * 18, "y": sin(a) * 18, "z": 7.0, "vx": cos(a) * v, "vy": sin(a) * v, "vz": RG(20, 60), "drag": 2.6, "life": RG(0.55, 0.8), "s0": RG(8, 10), "s1": RG(18, 22), "c0": A0(GC.dust2, 0.85), "c1": A0(GC.dust2, 0), "fo": 0.35, "cap": 75.0})
			ring(null, r.x, r.y, GC.clod, 10, 84 * sz, 0.6, 0.07, 0, false, 0.6)
			steam(r, H, sz, 7)

# hai luồng hơi từ mũi trâu, thổi tới trước và xuống
func steam(r, H: float, sz: float, n: int) -> void:
	for sd in [-1.0, 1.0]:
		for i in n:
			gp({"sh": GS.cloud, "fol": r, "loc": true, "x": 22 * sz, "y": sd * 5 * sz, "z": H * 0.55, "vx": RG(140, 220), "vy": sd * RG(20, 60), "vz": RG(-50, -10), "t": -i * 0.035, "drag": 2.4, "life": RG(0.45, 0.65), "s0": 2.5, "s1": 9.0, "c0": A0(GC.steam, 0.85), "c1": A0(GC.steam, 0), "w": 0.0})

# skill nổ ra (gọi sau use_ability của luật đua)
func cast(r) -> void:
	var id: String = r.id
	r.bsrc = id
	r.bpw = r.boostPow
	if id == "tay" or id == "cuu" or id == "trau":
		r.shSrc = id
	if not near(r):
		return
	var v := rVel(r)
	_cast(r, fxHead(r), rSz(r), v.x, v.y)

# lông bay quanh gà tây có khiên, hoặc len quanh cừu: tạo một lần mỗi lần dùng, khi con đó đủ gần để thấy
func orbit(r, H: float, sz: float) -> void:
	var X := _x(r)
	X.shK = r.gskT
	var id: String = r.id
	var ok := func(): return r.shieldT > 0 and r.shSrc == id
	var L: float = r.shieldT + 0.3
	if id == "tay":
		var C := [GC.bronze, GC.chest, HX("#b9844a")]
		for i in 6:
			gp({"sh": GS.feather, "ink": true, "fol": r, "orb": 3.1, "orr": 25 * sz, "a0": i * TAU / 6, "z": H * 0.4, "face": 2, "aim": [0.0, 0.0, H * 0.4 - 34], "life": L, "wl": ok, "fi": 0.25, "s0": 9.5 * sz, "s1": 9.5 * sz, "c0": C[i % 3], "c1": C[i % 3], "w": 1.0})
		gp({"sh": GS.ring, "gr": true, "fol": r, "life": L, "wl": ok, "fi": 0.25, "s0": 27 * sz, "s1": 27 * sz, "w": 0.09, "c0": A0(GC.teal, 0.6), "c1": A0(GC.teal, 0.6), "ink": true})
	else:
		for i in 5:
			gp({"sh": GS.cloud, "ink": true, "w": 0.7, "fol": r, "orb": 2.5, "orr": 27 * sz, "a0": i * TAU / 5, "z": H * 0.36 + (i % 2) * 8, "life": L, "wl": ok, "fi": 0.3, "s0": 7.5 * sz, "s1": 7.5 * sz, "c0": GC.wool, "c1": GC.wool})

# một món đồ được dùng
func item(r, k: String, l: int) -> void:
	if k == "rom":
		r.shSrc = "rom"
	if k == "ot":
		r.bsrc = "ot"
		r.bpw = r.boostPow
	if not near(r):
		return
	var H := fxHead(r)
	var sz := rSz(r)
	var v := rVel(r)
	if k == "ot":
		ring(r, 0, 0, GC.org, 6, 44 * sz, 0.32, 0.12, 0, true)
		for i in 8:
			gp({"sh": GS.flame, "ink": true, "fol": r, "loc": true, "x": RG(-14, 4) * sz, "y": RG(-10, 10) * sz, "z": RG(2, H * 0.4), "vx": RG(-120, -40), "vz": RG(40, 110), "drag": 1.5, "life": RG(0.3, 0.45), "s0": 5.0, "s1": 9.0, "c0": Color.WHITE, "c1": Color.WHITE})
		sparks(r.x, r.y, rH(r) + H * 0.4, 10, [GC.org, GC.amb, GC.red], 180, 4, 0.5, v.x * 0.6, v.y * 0.6)
	elif k == "rom":
		ring(r, 0, 0, GC.gold, 8, 46 * sz, 0.35, 0.12, 0, true)
		for i in 10:
			var a := RG(0, TAU)
			var s := RG(100, 200)
			gp({"sh": GS.rect, "ink": true, "x": r.x, "y": r.y, "z": rH(r) + H * 0.5, "vx": v.x * 0.7 + cos(a) * s, "vy": v.y * 0.7 + sin(a) * s, "vz": RG(80, 180), "g": 400.0, "drag": 1.5, "life": RG(0.6, 0.9), "s0": 3.6, "s1": 3.0, "asp": 0.22, "rot": RG(0, TAU), "vr": RG(-10, 10), "c0": GC.yel, "c1": GC.yel, "fo": 0.6})
	elif k == "may":
		for b in R.bolts:
			if b.life < 0.98 or b.get("r") == null:
				continue
			var o = b.r
			var h := rH(o) + fxHead(o)
			for i in 3:
				zap(o.x, o.y, h + 18, GC.yel, 34, 4)
			gp({"sh": GS.glow, "fol": o, "z": fxHead(o) * 0.6, "life": 0.4, "s0": 20.0, "s1": 34.0, "c0": A0(GC.yel, 0.35), "c1": A0(GC.yel, 0), "w": 0.3})
			ring(null, o.x, o.y, HX("#3a3020"), 6, 40, 0.7, 0.14, 0, false, 0.45)
			sparks(o.x, o.y, h, 10, [GC.yel, GC.amb], 200, 4, 0.5)

# trúng đòn: chớp nổ trên mình, sao bật ra, lông (hay nhúm lông thú) bay
func hit(o) -> void:
	if not near(o):
		return
	var H := fxHead(o)
	var sz := rSz(o)
	var v := rVel(o)
	burst(o, 0, 0, H * 0.55, GC.hit, 5 * sz, 14 * sz, 0.24)
	stars(o.x, o.y, rH(o) + H * 0.75, 2, GC.gold, 110, 4.6)
	var c1 := HX(String(o.ch.color))
	var c2 := HX(String(o.ch.dark))
	if GQUAD.has(o.id):
		tufts(o.x, o.y, rH(o) + H * 0.5, 4, [c1, c1, c2], 140, 4.4, v.x, v.y)
	else:
		feathers(o.x, o.y, rH(o) + H * 0.5, 4, [c1, c2], 140, 4.6, v.x, v.y)

# đòn dội ra khỏi khiên
func block(r) -> void:
	if not near(r):
		return
	var H := fxHead(r)
	var sz := rSz(r)
	var s: String = r.shSrc
	var col: Color = GC.teal if s == "tay" else (GC.pink if s == "cuu" else (GC.earth if s == "trau" else GC.gold))
	ring(r, 0, 0, col, 20 * sz, 46 * sz, 0.3, 0.12, 0, true)
	sparks(r.x, r.y, rH(r) + H * 0.5, 10, [col, GC.cream], 200, 4.5, 0.45)
	if s == "tay":
		feathers(r.x, r.y, rH(r) + H * 0.5, 3, [GC.bronze, GC.chest], 120, 7, 0, 0, 1)
	if s == "cuu":
		clouds(r.x, r.y, rH(r) + H * 0.4, 4, GC.wool, 160, 5, 9, 0.5, 0.7)

# nhảy xong chạm đất
func land(r) -> void:
	if not near(r) or r.gsk != r.id:
		return
	var H := fxHead(r)
	var sz := rSz(r)
	if r.id == "ac":
		ring(null, r.x, r.y, GC.violet, 10, 70, 0.45, 0.1, 0, true)
		clouds(r.x, r.y, 2, 10, HX("#bcb4cc"), 180, 5, 12, 0.55, 0.5)
		sparks(r.x, r.y, H * 0.4, 6, [GC.violet, GC.sky], 180, 4.5, 0.55)
		stars(r.x, r.y, H * 0.4, 2, GC.pale, 110, 4.5)
	elif r.id == "meo" and not r.hop.is_empty() and r.hop.pounce:
		var c := rAt(r, 22 * sz, 0)
		for i in range(-1, 2):
			gp({"sh": GS.slash, "ink": true, "x": c.x, "y": c.y, "z": (14 + (i + 1) * 11) * sz, "t": -(i + 1) * 0.04, "still": true, "rot": -0.5, "life": 0.5, "s0": 16 * sz, "s1": 20 * sz, "ez": 1, "c0": GC.claw, "c1": GC.claw, "fo": 0.5, "cap": 90.0})
		ring(null, r.x, r.y, GC.gold, 14, 170, 0.5, 0.06, 0, true)
		ring(null, r.x, r.y, GC.ginger, 10, 120, 0.42, 0.08, 0.06, true)
		for i in 14:
			var a := i / 14.0 * TAU + RG(-0.1, 0.1)
			var v := RG(370, 470)
			gp({"sh": GS.cloud, "ink": true, "w": 0.4, "x": r.x + cos(a) * 14, "y": r.y + sin(a) * 14, "z": 6.0, "vx": cos(a) * v, "vy": sin(a) * v, "vz": RG(20, 50), "drag": 2.4, "life": RG(0.45, 0.62), "s0": RG(7, 9), "s1": RG(15, 18), "c0": A0(GC.dust, 0.82), "c1": A0(GC.dust, 0), "fo": 0.32, "cap": 75.0})
		burst(null, c.x, c.y, H * 0.4, GC.amb, 6, 15, 0.24)

# trứng vỡ: vũng lòng trắng + lòng đỏ trên đất, mảnh vỏ, tiếng bốp nhỏ
func egg_pop(x: float, y: float, sk) -> void:
	if R.player != null and Vector2(x - R.player.x, y - R.player.y).length() > 700:
		return
	var s := bool(sk)
	gp({"sh": GS.drop, "gr": true, "ink": true, "x": x, "y": y, "rot": RG(0, TAU), "asp": RG(0.75, 0.9), "s0": 5.0, "s1": 15.0 if s else 12.0, "ez": 1, "life": 1.3, "c0": GC.wool, "c1": GC.wool, "fo": 0.6, "w": 0.35, "gz": 1.0})
	gp({"sh": GS.drop, "gr": true, "ink": true, "x": x + RG(-2, 2), "y": y + RG(-2, 2), "s0": 2.0, "s1": 5.5 if s else 4.5, "ez": 1, "life": 1.3, "c0": GC.yolk, "c1": GC.yolk, "fo": 0.6, "w": 0.9})
	for i in 3:
		var a := i / 3.0 * TAU + RG(-0.5, 0.5)
		var v := RG(90, 170)
		gp({"sh": GS.rect, "ink": true, "x": x, "y": y, "z": 14.0, "vx": cos(a) * v, "vy": sin(a) * v, "vz": RG(120, 220), "g": 700.0, "drag": 1.0, "life": RG(0.45, 0.6), "s0": RG(2.6, 3.1), "s1": 2.4, "asp": RG(0.7, 0.9), "rot": RG(0, TAU), "vr": RG(-12, 12), "c0": GC.shell, "c1": GC.shell, "fo": 0.7, "w": 2.0})
	burst(null, x, y, 14, GC.yolk if s else GC.cream, 3, 9, 0.16)

# ---------------------------------------------------------------- trong lúc skill còn chạy
func owns_boost(r) -> bool:
	return r.boostT > 0 and r.bsrc != "" and r.boostPow == r.bpw

static func P_(dt: float, rate: float) -> bool:
	return randf() < dt * rate

func emit(r, dt: float) -> void:
	var id: String = r.id
	var H := fxHead(r)
	var sz := rSz(r)
	var z0 := rH(r)
	var v := rVel(r)
	var vx := v.x
	var vy := v.y
	var air: bool = r.hopT > 0 or r.z > 2
	var sp := v.length()
	var own := owns_boost(r)
	var sk: bool = r.gsk == id
	var ca := cos(r.a)
	var sa := sin(r.a)
	var X := _x(r)
	# ớt: lửa hoạt hình phụt sau lưng, tàn lửa, khói, đốm lửa nhỏ chỗ chân chạm (không viền, cho lửa chồng nhau hòa một)
	if own and r.bsrc == "ot":
		var n := (1 if P_(dt, 22) else 0) + (1 if P_(dt, 22) else 0)
		for i in n:
			gp({"sh": GS.flame, "fol": r, "loc": true, "x": RG(-12, -8) * sz, "y": RG(-4, 4) * sz, "z": H * RG(0.14, 0.3), "vx": RG(-90, -40), "vy": RG(-12, 12), "vz": RG(50, 100), "drag": 1.2, "life": RG(0.28, 0.38), "s0": RG(5.6, 6.6) * sz, "s1": RG(9, 10.5) * sz, "c0": Color.WHITE, "c1": Color.WHITE, "cap": 80.0})
		if P_(dt, 8):
			gp({"sh": GS.glow, "fol": r, "loc": true, "x": -10 * sz, "z": H * 0.35, "life": 0.3, "s0": 16 * sz, "s1": 20 * sz, "c0": A0(GC.org, 0.2), "c1": A0(GC.org, 0), "w": 0.2})
		if P_(dt, 22):
			var p := rAt(r, -12 * sz, RG(-6, 6))
			sparks(p.x, p.y, z0 + H * 0.3, 1, [GC.org, GC.amb], 120, 3, 0.5, vx * 0.4, vy * 0.4, {"vz": RG(60, 160)})
		if P_(dt, 8):
			gp({"sh": GS.cloud, "x": r.x - ca * 16, "y": r.y - sa * 16, "z": z0 + H * 0.5, "vx": vx * 0.3, "vy": vy * 0.3, "vz": RG(40, 80), "drag": 1.4, "life": RG(0.6, 0.9), "s0": 4.0, "s1": 12.0, "c0": A0(GC.smoke, 0.42), "c1": A0(GC.smoke, 0), "w": 0.0})
		if not air and P_(dt, 22):
			var s := RG(-1, 1) * 7
			gp({"sh": GS.flame, "ink": true, "x": r.x - ca * 6 - sa * s, "y": r.y - sa * 6 + ca * s, "z": 0.0, "life": RG(0.28, 0.38), "s0": 3.4, "s1": 2.2, "c0": Color.WHITE, "c1": Color.WHITE})
	if not sk:
		return
	if (id == "tay" or id == "cuu") and r.shieldT > 0 and r.shSrc == id and X.get("shK") != r.gskT:
		orbit(r, H, sz)
	# Lướt Gió: lọn gió hai bên, vệt gió, lá lúa / bông điên điển bay qua
	if id == "vang" and own:
		if P_(dt, 10):
			var sd := -1.0 if randf() < 0.5 else 1.0
			gp({"sh": GS.gust, "ink": true, "fol": r, "loc": true, "x": RG(-2, 12) * sz, "y": sd * RG(17, 25) * sz, "z": H * RG(0.25, 0.85), "vx": -RG(70, 130), "vy": sd * RG(20, 60), "face": 1, "asp": sd, "life": 0.55, "s0": 15 * sz, "s1": 17 * sz, "c0": GC.gustc, "c1": GC.gustc, "fo": 0.8, "cap": 120.0})
		if P_(dt, 36):
			var p := rAt(r, RG(-10, 10), RG(-22, 22) * sz)
			gp({"sh": GS.streak, "add": true, "x": p.x, "y": p.y, "z": z0 + RG(4, H), "vx": vx * 0.2, "vy": vy * 0.2, "life": RG(0.18, 0.28), "s0": 4.0, "s1": 1.5, "str": 0.14, "c0": A0(GC.mint, 0.9), "c1": A0(GC.mint, 0)})
		if P_(dt, 7):
			var fl := randf() < 0.35
			var s := RG(-1, 1) * 24 * sz
			var p := rAt(r, RG(0, 14), s)
			gp({"sh": GS.flower if fl else GS.leaf, "ink": true, "x": p.x, "y": p.y, "z": z0 + RG(6, H * 0.9), "vx": vx * 0.75 - sa * s * 3, "vy": vy * 0.75 + ca * s * 3, "vz": RG(20, 80), "g": 80.0, "drag": 1.6, "life": RG(0.6, 0.9), "s0": 4.0 if fl else 6.4, "s1": 3.6 if fl else 5.6, "rot": RG(0, TAU), "vr": RG(-6, 6), "c0": GC.yel if fl else PK([GC.leaf, GC.leaf2]), "fo": 0.6})
	# Cuộn Len: vòng len hồng quay quanh cừu
	if id == "cuu" and r.shieldT > 0 and r.shSrc == "cuu":
		var rb := rib("y" + str(r.get_instance_id()), {"hw": 1.3, "life": 1.0, "c0": A0(GC.pink, 0.95), "c1": A0(GC.pink, 0.95), "ink": true, "w": 5.0, "loop": true})
		var Rr := 24 * sz
		var n := 40
		rb.pts.clear()
		for i in n + 1:
			var a := i / float(n) * TAU + clock * 1.6
			rb.pts.append([r.x + cos(a) * Rr, r.y + sin(a) * Rr, z0 + H * 0.44 + sin(a * 3 + clock * 5) * 5 * sz, clock])
		if P_(dt, 6):
			clouds(r.x, r.y, z0 + H * 0.4, 1, GC.wool, 120, 3, 6, 0.6, 0.6, vx * 0.6, vy * 0.6, 40)
	# Lội Ruộng: nước từ chân, gợn sóng trên đất, bơi thì nhiều hơn
	if id == "vit" and r.mudT > 0 and not air and sp > 40:
		var wet: bool = R.M.in_water(r.x, r.y)
		if P_(dt, 16 if wet else 10):
			var s := RG(-1, 1) * 8
			drops(r.x - ca * 6 - sa * s, r.y - sa * 6 + ca * s, 3, 1, [GC.water, GC.foam], 60, RG(150, 260), 2.4, vx * 0.4 - sa * s * 12, vy * 0.4 + ca * s * 12)
		X.cw = float(X.get("cw", 0.0)) + dt
		if X.cw > (0.13 if wet else 0.18):
			X.cw = 0.0
			X.cs = -float(X.get("cs", 1.0))
			var p := rAt(r, -4 * sz, X.cs * 7 * sz)
			crown(p.x, p.y, RG(6, 8) * sz * (1.25 if wet else 1.0), HX("#86d2f2"), 0.36, 0.9, 0, {"vx": vx * 0.25, "vy": vy * 0.25})
		X.rp = float(X.get("rp", 0.0)) + dt
		if X.rp > (0.06 if wet else 0.1):
			X.rp = 0.0
			gp({"sh": GS.ring, "gr": true, "x": r.x - ca * 8, "y": r.y - sa * 8, "s0": 5.0, "s1": 30.0 if wet else 22.0, "ez": 1, "life": 0.6, "c0": A0(GC.foam, 0.8), "c1": A0(GC.foam, 0), "w": 0.1})
	# Nhảy Vọt: lấp lánh, sao nhạt, lông rơi khi bay
	if id == "ac" and r.hopT > 0:
		if P_(dt, 30):
			sparks(r.x + RG(-10, 10), r.y + RG(-10, 10), z0 + H * RG(0.2, 0.9), 1, [GC.violet, GC.sky, GC.indigo], 60, 4.5, 0.6)
		if P_(dt, 4):
			stars(r.x, r.y, z0 + H * 0.5, 1, GC.pale, 60, 4)
		if P_(dt, 6):
			feathers(r.x, r.y, z0 + H * 0.5, 1, [HX("#4a4656")], 60, 4.4, vx * 0.4, vy * 0.4, 2)
	# Đá Song Phi: cú đá nối cú đá trước mặt, vệt nóng, bụi chân
	if id == "tre" and r.kickT > 0:
		X.kk = float(X.get("kk", 0.0)) + dt
		if X.kk > 0.11:
			X.kk = 0.0
			X.ks = -float(X.get("ks", 1.0))
			gp({"sh": GS.slash, "ink": true, "front": true, "fol": r, "loc": true, "x": 8 * sz, "y": X.ks * 15 * sz, "z": H * RG(0.3, 0.55), "still": true, "rot": X.ks * 0.35, "life": 0.16, "s0": 13.0, "s1": 18.0, "ez": 1, "c0": PK([GC.org, GC.amb]), "c1": GC.org, "fo": 0.45, "cap": 100.0})
		if P_(dt, 28):
			var p := rAt(r, RG(-6, 6), RG(-16, 16))
			gp({"sh": GS.streak, "add": true, "x": p.x, "y": p.y, "z": z0 + RG(4, H * 0.9), "vx": vx * 0.2, "vy": vy * 0.2, "life": RG(0.16, 0.26), "s0": 3.6, "s1": 1.4, "str": 0.12, "c0": A0(GC.org, 0.95), "c1": A0(GC.org, 0)})
		if not air and sp > 60 and P_(dt, 14):
			dust(r, GC.dust, 0.75)
	# Rượt Đuổi: bụi hai bên chân, vệt hổ phách
	if id == "cho" and r.kickT > 0:
		if not air and sp > 60 and P_(dt, 24):
			dust(r, GC.dust, 1)
		if P_(dt, 24):
			var p := rAt(r, RG(-6, 6), RG(-18, 18) * sz)
			gp({"sh": GS.streak, "add": true, "x": p.x, "y": p.y, "z": z0 + RG(4, H * 0.9), "vx": vx * 0.2, "vy": vy * 0.2, "life": RG(0.16, 0.26), "s0": 3.6, "s1": 1.4, "str": 0.12, "c0": A0(GC.amb, 0.95), "c1": A0(GC.amb, 0)})
	# Vồ Mồi: vài đốm lấp lánh sau cú vồ
	if id == "meo" and r.hopT > 0 and not r.hop.is_empty() and r.hop.pounce:
		if P_(dt, 70):
			sparks(r.x + RG(-8, 8), r.y + RG(-8, 8), z0 + H * RG(0.2, 0.8), 1, [GC.ginger, GC.gold], 50, 4, 0.5)
	if id == "cuu" and r.kickT > 0 and not air and sp > 60 and P_(dt, 10):
		dust(r, GC.dust, 0.7)
	# Húc Sừng: bụi chân và vệt thép trong giây xông tới
	if id == "de" and own and not air and sp > 60 and P_(dt, 16):
		dust(r, GC.dust, 0.85)
	if id == "de" and own and P_(dt, 30):
		var p := rAt(r, RG(-6, 10), RG(-18, 18) * sz)
		gp({"sh": GS.streak, "add": true, "x": p.x, "y": p.y, "z": z0 + RG(4, H * 0.9), "vx": vx * 0.2, "vy": vy * 0.2, "life": RG(0.16, 0.26), "s0": 3.8, "s1": 1.4, "str": 0.14, "c0": A0(GC.steel, 0.95), "c1": A0(GC.ice, 0)})
	# Tắm Bùn: bùn từ chân, thỉnh thoảng một bong bóng
	if id == "heo" and r.mudT > 0 and not air and sp > 40:
		X.cw = float(X.get("cw", 0.0)) + dt
		if X.cw > 0.22:
			X.cw = 0.0
			X.cs = -float(X.get("cs", 1.0))
			var p := rAt(r, -6 * sz, X.cs * 8 * sz)
			crown(p.x, p.y, RG(6, 8) * sz, GC.mud2, 0.36, 0.6, 0, {"vx": vx * 0.25, "vy": vy * 0.25})
		if P_(dt, 10):
			var s := RG(-1, 1) * 9
			drops(r.x - ca * 8 - sa * s, r.y - sa * 8 + ca * s, 3, 1, [GC.mud, GC.mud2, GC.clod], 70, RG(150, 250), 3, vx * 0.35 - sa * s * 12, vy * 0.35 + ca * s * 12, 0.3)
		if P_(dt, 5):
			gp({"sh": GS.bubble, "fol": r, "loc": true, "x": -12 * sz, "y": RG(-8, 8), "z": H * 0.3, "vz": 30.0, "life": RG(0.4, 0.6), "s0": 2.0, "s1": 4.5, "c0": A0(GC.bub, 0.95), "c1": A0(GC.bub, 0.95)})
	# Sữa Tươi: giọt sữa, mây kem để lại, vệt xanh nhạt
	if id == "bo" and own:
		if not air and sp > 60:
			X.cw = float(X.get("cw", 0.0)) + dt
			if X.cw > 0.3:
				X.cw = 0.0
				X.cs = -float(X.get("cs", 1.0))
				var p := rAt(r, -10 * sz, X.cs * 8 * sz)
				crown(p.x, p.y, RG(6, 8) * sz, GC.milkc, 0.36, 0.7, 0, {"vx": vx * 0.25, "vy": vy * 0.25})
		if P_(dt, 8):
			var p := rAt(r, RG(-6, 14) * sz, RG(-10, 10))
			drops(p.x, p.y, z0 + H * RG(0.3, 0.6), 1, [GC.milk, HX("#fff4dc")], 60, RG(80, 180), 2.6, vx * 0.6, vy * 0.6, 0.6)
		if P_(dt, 16):
			gp({"sh": GS.cloud, "ink": true, "w": 0.35, "x": r.x - ca * 16 * sz + RG(-8, 8), "y": r.y - sa * 16 * sz + RG(-8, 8), "z": z0 + RG(3, H * 0.4), "vx": vx * 0.45, "vy": vy * 0.45, "vz": RG(10, 40), "drag": 2.0, "life": RG(0.4, 0.6), "s0": 5.0, "s1": 11.0, "c0": A0(GC.milk, 0.8), "c1": A0(GC.milk, 0), "fo": 0.4})
		if P_(dt, 26):
			var p := rAt(r, RG(-6, 6), RG(-20, 20) * sz)
			gp({"sh": GS.streak, "add": true, "x": p.x, "y": p.y, "z": z0 + RG(4, H * 0.9), "vx": vx * 0.2, "vy": vy * 0.2, "life": RG(0.16, 0.26), "s0": 3.6, "s1": 1.4, "str": 0.12, "c0": A0(GC.milkb, 0.9), "c1": A0(GC.milkb, 0)})
	# Húc Ủi: tường bụi hai bên, cục đất, rãnh cày trên đất, thỉnh thoảng phun hơi
	if id == "trau" and r.kickT > 0 and not air and sp > 60:
		if P_(dt, 26):
			dust(r, GC.dust2, 1.05)
		if P_(dt, 10):
			var s := RG(-1, 1) * 12
			clods(r.x - ca * 10 - sa * s, r.y - sa * 10 + ca * s, 4, 1, [GC.clod, GC.earth], 80, RG(160, 260), 3.2, vx * 0.3 - sa * s * 10, vy * 0.3 + ca * s * 10)
		X.fw = float(X.get("fw", 0.0)) + dt
		if X.fw > 0.03:
			X.fw = 0.0
			for s in [-7.0, 7.0]:
				var p := rAt(r, -10 * sz, s * sz)
				gp({"sh": GS.rect, "gr": true, "x": p.x, "y": p.y, "rot": r.a, "s0": 7.0, "s1": 7.0, "asp": 0.22, "life": 1.1, "c0": A0(GC.clod, 0.38), "c1": A0(GC.clod, 0)})
		X.st = float(X.get("st", 0.0)) + dt
		if X.st > 0.5:
			X.st = 0.0
			steam(r, H, sz, 3)

# đám bụi hoạt hình bên chân, trôi ra sau và ra ngoài
func dust(r, col: Color, k: float) -> void:
	var sz := rSz(r)
	var sd := -1.0 if randf() < 0.5 else 1.0
	gp({"sh": GS.cloud, "ink": true, "w": 0.4, "fol": r, "loc": true, "x": -4 * sz, "y": sd * 9 * sz, "z": 5.0, "vx": RG(-200, -120) * k, "vy": sd * RG(50, 110) * k, "vz": RG(15, 45), "drag": 1.6, "life": RG(0.34, 0.48), "s0": 5.5 * k * sz, "s1": 12 * k * sz, "c0": A0(col, 0.85), "c1": A0(col, 0), "fo": 0.35, "cap": 90.0})

# trứng đang bay: trứng của gà mái để lại dải lấp lánh, trứng ném thường để vệt mờ
func emit_eggs(dt: float) -> void:
	for e in R.eggs:
		if e.life <= 0:
			continue
		if R.player != null and Vector2(e.x - R.player.x, e.y - R.player.y).length() > 700:
			continue
		if e.get("sk", 0):
			if not e.has("id"):
				e.id = randi()
			rib("e" + str(e.id), {"hw": 2.2, "life": 0.16, "c0": A0(GC.pale, 0.85), "c1": A0(GC.gold, 0), "w": 4.0}).pts.append([e.x, e.y, 12.0, clock])
			if P_(dt, 40):
				sparks(e.x, e.y, 12 + RG(-3, 3), 1, [GC.gold, GC.yolk], 40, 3.6, 0.4)
		elif P_(dt, 30):
			gp({"sh": GS.streak, "add": true, "x": e.x, "y": e.y, "z": 12.0, "vx": cos(e.a) * e.v * 0.15, "vy": sin(e.a) * e.v * 0.15, "life": 0.14, "s0": 2.6, "s1": 1.0, "str": 0.12, "c0": A0(GC.cream, 0.7), "c1": A0(GC.cream, 0)})

# vũng bùn gần mình sủi bọt
func emit_mud(dt: float) -> void:
	var pl = R.player
	if pl == null:
		return
	for t in R.traps:
		if t.kind != "bun":
			continue
		if absf(t.x - pl.x) > 900 or absf(t.y - pl.y) > 900:
			continue
		if P_(dt, float(t.r) / 12.0):
			var a := RG(0, TAU)
			var q := sqrt(randf()) * float(t.r) * 0.75
			gp({"sh": GS.bubble, "gr": true, "x": t.x + cos(a) * q, "y": t.y + sin(a) * q, "s0": 1.0, "s1": RG(3.5, 6.5), "life": RG(0.5, 0.9), "c0": A0(GC.bub, 0.95), "c1": A0(GC.bub, 0.95)})

# hạt già đi, bay, rơi, nảy; dải lụa bỏ điểm cũ; rồi cái gì đang chạy thì phun thêm
func step(dt: float) -> void:
	clock = R.clock
	for i in range(P.size() - 1, -1, -1):
		var f: Pt = P[i]
		f.t += dt
		if f.t > 0 and f.t < f.life - 0.25 and ((f.wl != null and not f.wl.call()) or (f.fol != null and f.fol.fallT > 0)):
			f.t = f.life - 0.25
		if f.t >= f.life:
			P[i] = P[P.size() - 1]
			P.pop_back()
			continue
		if f.t < 0:
			continue
		if f.orb:
			f.a0 += f.orb * dt
		if f.still or f.orb:
			continue
		if f.drag:
			var k := exp(-f.drag * dt)
			f.vx *= k
			f.vy *= k
			f.vz *= k
		f.vz -= f.g * dt
		f.x += f.vx * dt
		f.y += f.vy * dt
		f.z += f.vz * dt
		f.rot += f.vr * dt
		if f.g and f.z < 0:
			f.z = 0
			f.vz *= -0.25
			f.vx *= 0.5
			f.vy *= 0.5
	for i in range(RB.size() - 1, -1, -1):
		var rb: Rib = RB[i]
		if not rb.loop:
			while rb.pts.size() and clock - float(rb.pts[0][3]) > rb.life:
				rb.pts.pop_front()
		elif clock - rb.last > 0.05:
			rb.pts.clear()
		if rb.pts.is_empty() and clock - rb.last > rb.life:
			RB.remove_at(i)
			RBK.erase(rb.key)
	if R.player == null:
		return
	for r in R.racers:
		if r.boostT <= 0:
			r.bsrc = ""
		if r.fallT > 0 or not near(r):
			continue
		emit(r, dt)
	emit_eggs(dt)
	emit_mud(dt)

# ---------------------------------------------------------------- vẽ
# màu hạt lúc này
func gcol(f: Pt, light: bool) -> Color:
	var k := f._k
	var c := f.c0
	var c1: Color = f.c1 if f.c1 != null else c
	var C := c.lerp(c1, k)
	if k > f.fo:
		C.a *= 1.0 - (k - f.fo) / (1.0 - f.fo)
	if f.fi and f.t < f.fi:
		C.a *= f.t / f.fi
	if f.tw:
		C.a *= 0.55 + 0.45 * sin(clock * 24 + f.sd * 40)
	C.a *= f._a
	if f.dual:
		if light:
			C.r += (1 - C.r) * 0.2
			C.g += (1 - C.g) * 0.2
			C.b += (1 - C.b) * 0.2
			C.a *= 0.3
		else:
			C.a *= 0.85
	elif light:
		C.a *= 0.35 if f.sh == GS.glow else 0.55
	return C

# chiếu mọi hạt một lần mỗi khung. Nhóm: 0 trên đất, còn lại theo độ sâu: sau con đua thứ mấy (xa -> gần)
var ZR: Array = []   # độ sâu các con đua đang vẽ, xa trước
var nB := 0
func prep(zr: Array) -> void:
	V = V
	ZR = zr
	nB = ZR.size() + 1
	var U: float = V.fxU()
	var zn: float = V.CDIST * 0.3
	var zf: float = V.CDIST * 0.25
	var zs := 1e9
	if R.player != null and R.player.fallT <= 0:
		var pp: Array = V.proj(R.player.x, R.player.y, 0)
		if not pp.is_empty():
			zs = pp[4]
	for f: Pt in P:
		f._p = -1
		if f.t < 0:
			continue
		var k := f.t / f.life
		f._k = k
		if f.gr:
			f._p = 0
			f._a = 1.0
			continue
		var g := gpos(f)
		var p: Array = V.proj(g.x, g.y, g.z)
		if p.is_empty() or p[4] < zn or p[4] > V.ZFAR:
			continue
		var kk := 1.0 - (1.0 - k) * (1.0 - k) if f.ez else k
		var s := f.s0 + (f.s1 - f.s0) * kk
		var r: float = s * p[3]
		var cap := (f.cap if f.cap > 0 else 110.0) * U
		if r > cap:
			r = cap
		if r < 0.35:
			continue
		if p[0] < -r - 80 or p[0] > V.VW + r + 80 or p[1] < -r - 80 or p[1] > V.VH + r + 80:
			continue
		f._x = p[0]
		f._y = p[1]
		f._z = p[4]
		f._r = r
		f._a = minf(1.0, (p[4] - zn) / zf)
		f._l = 0.0
		var rot := f.rot
		if f.face == 1 or f.str:
			var dx := f.vx
			var dy := f.vy
			var dz := f.vz
			var A = f.fol
			if A != null and f.orb:
				dx = -sin(f.a0) * f.orr * f.orb
				dy = cos(f.a0) * f.orr * f.orb
				dz = 0.0
			elif A != null and f.loc:
				var ca := cos(A.a)
				var sa := sin(A.a)
				dx = ca * f.vx - sa * f.vy
				dy = sa * f.vx + ca * f.vy
			var e := f.str if f.str else 0.02
			var q: Array = V.proj(g.x + dx * e, g.y + dy * e, g.z + dz * e)
			if not q.is_empty():
				var lx: float = q[0] - p[0]
				var ly: float = q[1] - p[1]
				var l := sqrt(lx * lx + ly * ly)
				if f.face == 1 and l > 0.01:
					rot = atan2(ly, lx) + f.rot
				if f.str and l > 0.5:
					f._l = minf(l, 160 * U)
					f._lx = lx / l
					f._ly = ly / l
		elif f.face == 2 and f.aim != null:
			var A = f.fol
			var m: Array = f.aim
			var ax: float = m[0]
			var ay: float = m[1]
			if A != null:
				if f.loc:
					var ca := cos(A.a)
					var sa := sin(A.a)
					ax = A.x + ca * m[0] - sa * m[1]
					ay = A.y + sa * m[0] + ca * m[1]
				else:
					ax = A.x + m[0]
					ay = A.y + m[1]
			var q: Array = V.proj(ax, ay, (rH(A) if A != null else 0.0) + m[2])
			if not q.is_empty():
				rot = atan2(p[1] - q[1], p[0] - q[0]) + f.rot
		f._rot = rot
		if f.front and f.fol == R.player:
			f._p = nB   # trên hết
		else:
			f._p = 1 + _bucket(p[4])
	# dải lụa: chiếu từng điểm một lần, mỗi đoạn vào nhóm theo độ sâu
	for rb: Rib in RB:
		var n := rb.pts.size()
		rb._s.clear()
		rb._g.clear()
		if n < 2:
			continue
		for pt in rb.pts:
			var p: Array = V.proj(pt[0], pt[1], pt[2])
			if p.is_empty() or p[4] < zn:
				rb._s.append(null)
				continue
			var a := 0.0 if rb.loop else minf(1.0, (clock - float(pt[3])) / rb.life)
			rb._s.append({"x": p[0], "y": p[1], "z": p[4], "w": minf(rb.hw * p[3] * (1 - a * 0.65), 26 * U), "a": a, "f": minf(1.0, (p[4] - zn) / zf), "nx": 0.0, "ny": 0.0})
		for i in n:
			var s = rb._s[i]
			if s == null:
				continue
			var A = rb._s[i - 1] if i > 0 and rb._s[i - 1] != null else s
			var B = rb._s[i + 1] if i + 1 < n and rb._s[i + 1] != null else s
			var tx: float = B.x - A.x
			var ty: float = B.y - A.y
			var l := sqrt(tx * tx + ty * ty)
			if l == 0:
				l = 1.0
			s.nx = -ty / l
			s.ny = tx / l
		for i in n - 1:
			var a = rb._s[i]
			var b = rb._s[i + 1]
			rb._g.append(1 + _bucket((a.z + b.z) * 0.5) if a != null and b != null else -1)

func _bucket(z: float) -> int:
	# số con đua xa hơn z (vẽ sau chúng)
	var n := 0
	for zz in ZR:
		if zz > z:
			n += 1
	return n

# ---- gói lưới
var _V := PackedVector2Array()
var _U := PackedVector2Array()
var _C := PackedColorArray()
var _Q := PackedFloat32Array()

func _vput(x: float, y: float, u: float, v: float, c: Color, q: float, age: float, sd: float, w: float) -> void:
	_V.append(Vector2(x, y))
	_U.append(Vector2(u, v))
	_C.append(c)
	_Q.append(q)
	_Q.append(age)
	_Q.append(sd)
	_Q.append(w)

# một ô vuông trên màn hình từ tâm và hai nửa trục a (u) và b (v)
func _squad(cx: float, cy: float, ax: float, ay: float, bx: float, by: float, c: Color, q: float, age: float, sd: float, w: float) -> void:
	var x0 := cx - ax - bx
	var y0 := cy - ay - by
	var x1 := cx + ax - bx
	var y1 := cy + ay - by
	var x2 := cx + ax + bx
	var y2 := cy + ay + by
	var x3 := cx - ax + bx
	var y3 := cy - ay + by
	_vput(x0, y0, -1, -1, c, q, age, sd, w)
	_vput(x1, y1, 1, -1, c, q, age, sd, w)
	_vput(x2, y2, 1, 1, c, q, age, sd, w)
	_vput(x0, y0, -1, -1, c, q, age, sd, w)
	_vput(x2, y2, 1, 1, c, q, age, sd, w)
	_vput(x3, y3, -1, 1, c, q, age, sd, w)

func _packB(f: Pt, light: bool) -> void:
	var C := gcol(f, light)
	if C.a < 0.008:
		return
	var q := 1.0 + f.sh + (50.0 if f.ink else 0.0) + (100.0 if light else 0.0)
	var r := f._r
	if f._l > 0.5:
		var l := f._l
		var dx := f._lx
		var dy := f._ly
		var L := r + l * 0.5
		var wd := r * f.wf
		_squad(f._x - dx * l * 0.5, f._y - dy * l * 0.5, dx * L, dy * L, -dy * wd, dx * wd, C, q, f._k, f.sd, f.w)
		return
	var cs := cos(f._rot)
	var sn := sin(f._rot)
	var rb := r * f.asp
	_squad(f._x, f._y, cs * r, sn * r, -sn * rb, cs * rb, C, q, f._k, f.sd, f.w)

func _packR(g: int) -> void:
	for rb: Rib in RB:
		if rb._g.is_empty():
			continue
		var c1: Color = rb.c1 if rb.c1 != null else rb.c0
		var q := 1.0 + GS.ribbon + (50.0 if rb.ink else 0.0)
		for i in rb._g.size():
			if rb._g[i] != g:
				continue
			var a = rb._s[i]
			var b = rb._s[i + 1]
			var ca: Color = rb.c0.lerp(c1, a.a)
			var cb: Color = rb.c0.lerp(c1, b.a)
			ca.a *= a.f * pow(1 - a.a, 0.7)
			cb.a *= b.f * pow(1 - b.a, 0.7)
			if ca.a < 0.01 and cb.a < 0.01:
				continue
			var P0 := Vector2(a.x + a.nx * a.w, a.y + a.ny * a.w)
			var P1 := Vector2(a.x - a.nx * a.w, a.y - a.ny * a.w)
			var P2 := Vector2(b.x + b.nx * b.w, b.y + b.ny * b.w)
			var P3 := Vector2(b.x - b.nx * b.w, b.y - b.ny * b.w)
			_vput(P0.x, P0.y, 0, -1, ca, q, 0, 0, rb.w)
			_vput(P1.x, P1.y, 0, 1, ca, q, 0, 0, rb.w)
			_vput(P2.x, P2.y, 1, -1, cb, q, 0, 0, rb.w)
			_vput(P1.x, P1.y, 0, 1, ca, q, 0, 0, rb.w)
			_vput(P3.x, P3.y, 1, 1, cb, q, 0, 0, rb.w)
			_vput(P2.x, P2.y, 1, -1, cb, q, 0, 0, rb.w)

# nhóm g: dải lụa và hình mềm từ xa tới gần, rồi lớp sáng. Trả về lưới (hoặc null)
func pack(g: int, mesh: ArrayMesh) -> bool:
	_V.clear()
	_U.clear()
	_C.clear()
	_Q.clear()
	var S := []
	var L := []
	for f: Pt in P:
		if f._p != g:
			continue
		if f.dual or not f.add:
			S.append(f)
		if f.dual or f.add:
			L.append(f)
	_packR(g)
	S.sort_custom(func(p, q): return p._z > q._z)
	for f in S:
		_packB(f, false)
	for f in L:
		_packB(f, true)
	return _commit(mesh)

func _commit(mesh: ArrayMesh) -> bool:
	mesh.clear_surfaces()
	if _V.is_empty():
		return false
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = _V
	arr[Mesh.ARRAY_TEX_UV] = _U
	arr[Mesh.ARRAY_COLOR] = _C
	arr[Mesh.ARRAY_CUSTOM0] = _Q
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	return true

# vết trên mặt đất: một ô nằm trên đất, chia lưới nhỏ chiếu từng đỉnh (web để GPU tự chiếu phối cảnh)
func pack_ground(mesh: ArrayMesh) -> bool:
	_V.clear()
	_U.clear()
	_C.clear()
	_Q.clear()
	for f: Pt in P:
		if f._p != 0 or (f.add and not f.dual):
			continue
		var C := gcol(f, false)
		if C.a < 0.008:
			continue
		var g := gpos(f)
		var kk := 1.0 - (1.0 - f._k) * (1.0 - f._k) if f.ez else f._k
		var s := f.s0 + (f.s1 - f.s0) * kk
		var rot: float = (f.fol.a if f.fol != null and f.loc else 0.0) + f.rot
		_gquad(g.x, g.y, 1.0, s, rot, f.asp, C, 1.0 + f.sh + (50.0 if f.ink else 0.0), f._k, f.sd, f.w)
	return _commit(mesh)

func _gquad(x: float, y: float, h: float, s: float, rot: float, asp: float, c: Color, q: float, age: float, sd: float, w: float) -> void:
	var ax := cos(rot) * s
	var ay := sin(rot) * s
	var bx := -sin(rot) * s * asp
	var by := cos(rot) * s * asp
	# chia theo cỡ trên màn hình: ô lớn gần ống kính chia nhiều hơn
	var pc: Array = V.proj(x, y, h)
	var n := 2
	if pc.is_empty() or s * float(pc[3]) > 60:
		n = 8
	elif s * float(pc[3]) > 20:
		n = 4
	var G := []
	for j in n + 1:
		var row := []
		var v := -1.0 + 2.0 * j / n
		for i in n + 1:
			var u := -1.0 + 2.0 * i / n
			var p: Array = V.proj(x + ax * u + bx * v, y + ay * u + by * v, h)
			row.append(null if p.is_empty() else Vector2(p[0], p[1]))
		G.append(row)
	for j in n:
		for i in n:
			var a = G[j][i]
			var b = G[j][i + 1]
			var cc = G[j + 1][i + 1]
			var d = G[j + 1][i]
			if a == null or b == null or cc == null or d == null:
				continue
			var u0 := -1.0 + 2.0 * i / n
			var u1 := -1.0 + 2.0 * (i + 1) / n
			var v0 := -1.0 + 2.0 * j / n
			var v1 := -1.0 + 2.0 * (j + 1) / n
			_vput(a.x, a.y, u0, v0, c, q, age, sd, w)
			_vput(b.x, b.y, u1, v0, c, q, age, sd, w)
			_vput(cc.x, cc.y, u1, v1, c, q, age, sd, w)
			_vput(a.x, a.y, u0, v0, c, q, age, sd, w)
			_vput(cc.x, cc.y, u1, v1, c, q, age, sd, w)
			_vput(d.x, d.y, u0, v1, c, q, age, sd, w)
