extends RefCounted
# SGEO bản web (/*SG0*/): hình học sông Vàm theo gx. Chép 1:1 phần NEW = MK(EXT, HW, 8.5, RND = 1, FIX = 1):
# c (tâm sông), sl (độ dốc), k1, hw, hs, c2 (nhánh vàm), bump, w (ô nước), isl (cù lao), col (top / bot / cr mỗi cột),
# rw. Chợ nổi (YB, vQ), ghe thương hồ, xuồng qua lại dùng.

const XA := 66.0
const XB := 134.0
const LEAN := 0.6
const EXT := [[-125, 35, 1], [-99, 38, 1], [-73, 42.5, 0.95], [-64, 46, 1], [-47, 37, 1.1], [-21, 41.5, 0.95], [5, 30.5, 1.25],
	[31, 40, 0.9], [38, 44, 1], [57, 33, 1.06], [83, 32.5, 1], [109, 31.5, 1], [135, 42.5, 0.92], [161, 34.5, 1], [174, 29.5, 1],
	[187, 40.5, 1], [213, 31.5, 1]]
const R1 := 8.5
const RHO := 1.7
const RO := 8.0
const CX0 := -220.0
const DX := 0.05

var TK := []
var CT := PackedFloat32Array()
var N := 0
var COL := {}

static func sst(a: float, b: float, x: float) -> float:
	var t := clampf((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

static func hh(n: float) -> float:
	var s := sin(n * 127.1 + 311.7) * 43758.5453
	return s - floorf(s)

static func vn(x: float) -> float:
	var i := floorf(x)
	var f := x - i
	f = f * f * (3.0 - 2.0 * f)
	return hh(i) * (1.0 - f) + hh(i + 1.0) * f

static func bump(x: float) -> float:
	if x <= XA or x >= XB:
		return 0.0
	return pow(sin(PI * (x - XA) / (XB - XA)), 1.3)

static func roadd(x: float) -> float:
	var m := fposmod(x - 0.5 - 5.0, 26.0)
	return minf(m, 26.0 - m)

static func rdx(x: float) -> float:
	return roundf((x - 0.5 - 5.0) / 26.0) * 26.0 + 5.5

func _init() -> void:
	for e in EXT:
		TK.append([float(e[0]) + 0.5 - LEAN * 4.0, float(e[1]), float(e[2])])
	N = int(ceilf((300.0 - CX0) / DX)) + 1
	CT.resize(N)
	var t: float = TK[0][0] - 40.0
	var px := -1e9
	var py := _A(t)
	var j := 0
	var tend: float = TK[TK.size() - 1][0] + 40.0
	while t < tend:
		var y := _A(t)
		var x := t + LEAN * (y - 32.0)
		while j < N and CX0 + j * DX <= x:
			var xx := CX0 + j * DX
			CT[j] = y if px < -1e8 else py + (y - py) * (xx - px) / (x - px if x != px else 1.0)
			j += 1
		px = x
		py = y
		t += 0.02
	while j < N:
		CT[j] = py
		j += 1

func _A(t: float) -> float:
	if t <= TK[0][0]:
		return TK[0][1]
	for i in TK.size() - 1:
		var t0: float = TK[i][0]
		var a0: float = TK[i][1]
		var p: float = TK[i][2]
		var t1: float = TK[i + 1][0]
		var a1: float = TK[i + 1][1]
		if t <= t1:
			var u := pow((t - t0) / (t1 - t0), p)
			return a0 + (a1 - a0) * (1.0 - cos(PI * u)) / 2.0
	return TK[TK.size() - 1][1]

func c(x: float) -> float:   # tâm sông
	var u := (x - CX0) / DX
	var i := int(floorf(u))
	if i < 0:
		return CT[0]
	if i >= N - 1:
		return CT[N - 1]
	var f := u - i
	return CT[i] + (CT[i + 1] - CT[i]) * f

func sl(x: float) -> float:
	return (c(x + 0.04) - c(x - 0.04)) / 0.08

func k1(x: float) -> float:
	var s := sl(x)
	return sqrt(1.0 + s * s)

func _hwr(x: float, b: float) -> float:   # HW của NEW
	return 3.15 + 0.42 * (vn(x * 0.083 + 3.1) - 0.5) * 2.0 + 0.18 * (vn(x * 0.29 + 8.3) - 0.5) * 2.0 + 3.0 * b

func hw(x: float) -> float:
	var b := bump(x)
	var h := _hwr(x, b)
	if b < 0.01 or b < 0.08:   # FIX = 1
		var r := 2.5 / k1(rdx(x))
		var q := sst(2.2, R1, roadd(x))
		h = r + (h - r) * maxf(q, sst(0.01, 0.08, b))
	return h

func c2(x: float) -> float:
	return c(x) + bump(x) * (29.0 + 2.0 * (vn(x * 0.13 + 7.0) - 0.5))

func hw2(x: float) -> float:
	return 0.4 + 2.6 * pow(bump(x), 0.45)

func k2(x: float) -> float:
	var s := (c2(x + 0.04) - c2(x - 0.04)) / 0.08
	return sqrt(1.0 + s * s)

func ins(x: float) -> float:
	if bump(x) <= 0.02:
		return 0.0
	var W := c2(x) - hw2(x) * k2(x) - c(x) - hw(x) * k1(x)
	if W <= 0.0:
		return 0.0
	return (W - sqrt(W * W - RHO * RHO)) / 2.0 if W >= RHO else W / 2.0

func hs(x: float) -> float:
	return hw(x) + ins(x) / k1(x)

func hn2(x: float) -> float:
	return hw2(x) + ins(x) / k2(x)

func hs2(x: float) -> float:
	var a := c(x) + hw(x) * k1(x)
	var b := c2(x) + hw2(x) * k2(x)
	var r := RO * sst(0.02, 0.15, bump(x)) * (1.0 - sst(0.3, 0.55, bump(x)))
	var d := a - b
	return ((a + b + sqrt(d * d + r * r)) / 2.0 - c2(x)) / k2(x)

func w(x: float, y: float) -> bool:   # ô (x, y) là nước sông
	var d := y - c(x)
	if (-d <= hw(x) * k1(x)) if d <= 0.0 else (d <= hs(x) * k1(x)):
		return true
	if bump(x) <= 0.02:
		return false
	d = y - c2(x)
	return (-d <= hn2(x) * k2(x)) if d <= 0.0 else (d <= hs2(x) * k2(x))

func isl(x: float, y: float) -> bool:
	if bump(x) <= 0.02 or w(x, y):
		return false
	return y > c(x) + hw(x) * k1(x) and y < c2(x)

func col(t: int) -> Dictionary:   # cột t: {top, bot, cr, w}
	if COL.has(t):
		return COL[t]
	var o := {"top": 1e9, "bot": -1e9, "cr": int(floorf(c(t + 0.5))), "w": {}}
	for a in range(10, 80):
		if w(t + 0.5, a + 0.5):
			o.w[a] = 1
			if a < o.top:
				o.top = a
			if a > o.bot:
				o.bot = a
	COL[t] = o
	return o

func rw(t: int, a: int) -> bool:
	return col(t).w.has(a)

func top(t: int) -> float:
	return float(col(t).top)

func bot(t: int) -> float:
	return float(col(t).bot)

func cr(t: int) -> int:
	return int(col(t).cr)
