extends RefCounted
# Layer 5 rules: the river banks, ported from the game's SONG module. The river's own curve numbers come as tables
# (n/song.json, sampled every ST tiles along x for both arms and both banks, at the 7 tide levels); everything drawn on
# the land side is rebuilt here from the game's rules: the grass lip, the mud flats at low water (runnels, puddles, crab
# holes, tracks, shells, tufts), the far bank's slope and cut earth face, the near bank's wet edge and leaning grass, the
# fishing stakes with their net, and the dull wash on water that lies on land nobody has bought.
# Output = draw ops for BankPics (main.gd): polygons and strokes with a texture mode, and plant pictures.

var T := {}
var X0 := -110.0
var ST := 0.2
var NJ := 0
var ki := 0.0
var hi := 0.0
var L := 1.0           # tide 0..1 in sixths
var Li := 6
var C := {}            # colours (Color)
var meta := {}         # plant pictures
var ops := []          # [kind, Color, PackedVector2Array, mode, amount]  kind 0 polygon, 1 stroke (width in amount2)
var plants := []

# texture modes of BankPics.gdshader
const M_PLAIN := 0
const M_CO := 1
const M_VACH := 2
const M_BUN := 3
const M_DAT := 4
const M_NUT := 5
const M_RIA := 6
const M_RACH := 7
const M_STK := 8
const M_RIAF := 16

static func hh(x: float, y: float) -> float:
	var n := sin(x * 127.1 + y * 311.7) * 43758.5453
	return n - floorf(n)

static func vn(x: float, s: float) -> float:
	var i := floorf(x)
	var f := x - i
	f = f * f * (3.0 - 2.0 * f)
	return hh(i, s) * (1.0 - f) + hh(i + 1.0, s) * f

static func sst(a: float, b: float, x: float) -> float:
	var t := clampf((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

const WASH_WATER := false
var F := false        # nước nổi: the flood (the game's mu, autumn days 2-6): build() draws the flood's edge instead of the banks
var kindf: Callable   # (tile x, tile y) -> ground kind of that tile (0 grass, 1 paddy, 3 tram, -1 road / other), for the rice tips
var no_ow := false     # strip(): keep quads in the other arm's water (the flood's bands are clipped their own way)
var sorig := []   # strip(): per returned polygon, the strip quad it was cut from (null when whole)

# the dull wash of land nobody has bought, as a table for bank.gdshader: per grid spot j and arm a (row), the arm's
# centre, k, and the wash's reach on both sides (bank + 0.35), -9 where the land is bought or the arm is not there. The
# game cuts the water out of its washed ground canvas, so the wash lies on the bank and the mud, never on the water.
func wash_image() -> Image:
	var im := Image.create(NJ, 2, false, Image.FORMAT_RGBAF)
	var lk: Array = T["lk"]
	var lk0: int = int(T["lk0"])
	for a in 2:
		var c: Array = arm(a)["c"]
		var k: Array = arm(a)["k"]
		var x0 := xa(a)
		var x1 := xb(a)
		for j in NJ:
			var x := X0 + j * ST
			var i0 := int(floorf(x + 1e-4)) - lk0
			var lok: bool = x >= x0 - 1e-4 and x <= x1 + 1e-4 and i0 >= 0 and i0 < lk.size() and int(lk[i0]) == 1
			im.set_pixel(j, a, Color(float(c[j]), float(k[j]), EB(a, x, true) + 0.35 if lok else -9.0, EB(a, x, false) + 0.35 if lok else -9.0))
	return im

func g2s(gx: float, gy: float) -> Vector2:
	return Vector2(ki + (gx - gy) * 32.0, hi + (gx + gy) * 16.0)

func col(name: String, a: float = -1.0) -> Color:
	var c: Color = C[name]
	if a >= 0.0:
		c.a = a
	return c

static func parse_col(s: String) -> Color:
	if s.begins_with("#"):
		return Color.html(s)
	var m := s.trim_prefix("rgba(").trim_prefix("rgb(").trim_suffix(")").split(",")
	return Color(float(m[0]) / 255.0, float(m[1]) / 255.0, float(m[2]) / 255.0, float(m[3]) if m.size() > 3 else 1.0)

func setup(tab: Dictionary, picmeta: Dictionary, tide: float) -> void:
	T = tab
	X0 = tab["X0"]; ST = tab["ST"]; NJ = int(tab["NJ"])
	L = tide; Li = clampi(int(roundf(tide * 6.0)), 0, 6)
	for k in tab["cols"].keys():
		if k != "n":
			C[k] = parse_col(str(tab["cols"][k]))
	meta = picmeta

# ---- the tables, at a grid spot j (the game only ever evaluates on the grid, except the stakes)
func jx(x: float) -> int: return int(roundf((x - X0) / ST))
func arm(a: int) -> Dictionary: return T["arm"][a]
func Ac(a: int, x: float) -> float:
	var u := (x - X0) / ST
	var j := clampi(int(floorf(u)), 0, NJ - 2)
	var f := u - j
	var c: Array = arm(a)["c"]
	return float(c[j]) * (1.0 - f) + float(c[j + 1]) * f
func Ak(a: int, x: float) -> float:
	var u := (x - X0) / ST
	var j := clampi(int(floorf(u)), 0, NJ - 2)
	var f := u - j
	var c: Array = arm(a)["k"]
	return float(c[j]) * (1.0 - f) + float(c[j + 1]) * f
func Ahw(a: int, x: float) -> float:
	var u := (x - X0) / ST
	var j := clampi(int(floorf(u)), 0, NJ - 2)
	var f := u - j
	var c: Array = arm(a)["hw"]
	return float(c[j]) * (1.0 - f) + float(c[j + 1]) * f
func EB(a: int, x: float, nb: bool) -> float: return float(arm(a)["E"][1 if nb else 0][jx(x)])
func KK(a: int, x: float) -> float: return float(arm(a)["k"][jx(x)])
func CV(a: int, x: float) -> float: return float(arm(a)["cv"][jx(x)])
func BPf(a: int, x: float, nb: bool) -> float: return float(arm(a)["BP"][1 if nb else 0][jx(x)])
func on(a: int, x: float, nb: bool) -> bool: return BPf(a, x, nb) > 0.02
func bump(x: float) -> float: return float(arm(0)["bump"][jx(x)])
func inner(a: int, x: float, nb: bool) -> float: return clampf((-1.0 if nb else 1.0) * CV(a, x) * 8.0, 0.0, 1.0)
func drop(a: int, x: float, nb: bool) -> float: return float(arm(a)["D"][Li][1 if nb else 0][jx(x)])
func ex(a: int, x: float, nb: bool) -> float: return float(arm(a)["EX"][Li][1 if nb else 0][jx(x)])
func fext(a: int, x: float, nb: bool) -> float: return float(arm(a)["FX"][1 if nb else 0][jx(x)])
func wo(a: int, x: float, nb: bool) -> float: return EB(a, x, nb) - drop(a, x, nb)
func xa(a: int) -> float: return maxf(float(arm(a)["xa"]), X0)
func xb(a: int) -> float: return minf(float(arm(a)["xb"]), X0 + (NJ - 1) * ST)
func J0(v: float) -> int: return int(ceilf((v - X0) / ST - 1e-6))
func J1(v: float) -> int: return int(floorf((v - X0) / ST + 1e-6))

# is screen point p inside the OTHER arm's water? Where the two arms split round the cù lao and join again they overlap:
# the game paints each arm's water over the other's mud there; Godot's water lies under the banks, so such pieces are
# left out instead (they showed as flat triangles and slabs of mud out in the water)
func ow(a: int, p: Vector2) -> bool:
	var u := (p.x - ki) / 32.0
	var v := (p.y - hi) / 16.0
	var gx := (u + v) * 0.5
	var gy := (v - u) * 0.5
	var o := 1 - a
	if gx < xa(o) or gx > xb(o): return false
	if o == 1 and bump(gx) <= 0.03: return false
	var c := Ac(o, gx)
	var k := KK(o, gx)
	if F:   # in the flood the other arm's water reaches its flood's edge
		return gy > c - (EB(o, gx, true) + fext(o, gx, true)) * k and gy < c + (EB(o, gx, false) + fext(o, gx, false)) * k
	var lo := c - (EB(o, gx, true) - drop(o, gx, true)) * k
	var hi2 := c + (EB(o, gx, false) - drop(o, gx, false)) * k
	return gy > lo and gy < hi2

# is the point at offset off from arm a's bank line (side nb) inside the OTHER arm's bank-to-bank zone? Before the cù lao's
# points the two arms overlap: a shallow band or lapping line at one arm's waterline lies there on the other arm's
# (left out) mud, so out in open water: it showed as two thin lines running on from the tip of the mud tongue
func ovx(a: int, nb: bool, x: float, off: float) -> bool:
	var sg := -1.0 if nb else 1.0
	var p := g2s(x, Ac(a, x) + sg * off * KK(a, x))
	var u := (p.x - ki) / 32.0
	var v := (p.y - hi) / 16.0
	var gx := (u + v) * 0.5
	var gy := (v - u) * 0.5
	var o := 1 - a
	if gx < xa(o) or gx > xb(o): return false
	if o == 1 and bump(gx) <= 0.03: return false
	var c := Ac(o, gx)
	var k := KK(o, gx)
	return gy > c - EB(o, gx, true) * k and gy < c + EB(o, gx, false) * k

# the mud strip at grid x was left out (one end in the other arm's water): no details there either
func clipx(a: int, nb: bool, x: float) -> bool:
	var sg := -1.0 if nb else 1.0
	var c := Ac(a, x)
	var k := KK(a, x)
	var E := EB(a, x, nb)
	return ow(a, g2s(x, c + sg * (E - drop(a, x, nb) - 0.03) * k)) or ow(a, g2s(x, c + sg * (E + 0.02) * k))

# ---- geometry helpers (SONG strip / line / body)
# a band between two offsets from the bank line, as a list of polygons (one per unbroken run)
func strip(a: int, nb: bool, fA: Callable, fB: Callable, act: Callable = Callable()) -> Array:
	var out := []
	sorig = []
	var run := []
	var sg := -1.0 if nb else 1.0
	var x0 := xa(a)
	var x1 := xb(a)
	if x1 <= x0: return out
	# a quad partly in the other arm's water is cut exactly along that water's edge (dropping it whole left a saw edge
	# of column ends, sharp mud spikes where the river splits round the cù lao); a quad wholly in it is left out
	var flush := func():
		for j in run.size() - 1:
			var Q := PackedVector2Array([run[j][0], run[j + 1][0], run[j + 1][1], run[j][1]])
			var n_in := 0
			for p in Q:
				if not no_ow and ow(a, p): n_in += 1
			if n_in == 0:
				out.append(Q); sorig.append(null)
				continue
			if n_in == 4: continue
			var W := owpoly(a, Q)
			if W.size() < 3:
				out.append(Q); sorig.append(null)
				continue
			for R in Geometry2D.clip_polygons(Q, W):
				var R2: PackedVector2Array = R
				# a hair-thin sliver left between the two arms' waterlines (they nearly meet before the cù lao's point)
				# read as a stick out in the water: left out
				var ar := 0.0
				var ed := 0.0
				for m in R2.size():
					var p0: Vector2 = R2[m]
					var p1: Vector2 = R2[(m + 1) % R2.size()]
					ar += p0.cross(p1)
					ed = maxf(ed, p0.distance_to(p1))
				if absf(ar) * 0.5 / maxf(ed, 1e-3) < 2.5: continue
				if R2.size() == 4: R2.insert(2, (R2[1] + R2[2]) * 0.5)   # not an edge-softened strip quad
				out.append(R2); sorig.append(Q)
		run.clear()
	for j9 in range(J0(x0), J1(x1) + 1):
		var x := X0 + j9 * ST
		if act.is_valid() and not act.call(x):
			flush.call()
			continue
		var c := Ac(a, x)
		var k := KK(a, x)
		var pa := g2s(x, c + sg * float(fA.call(x)) * k)
		var pb := g2s(x, c + sg * float(fB.call(x)) * k)
		run.append([pb, pa] if nb else [pa, pb])
	flush.call()
	return out

# the other arm's water (at this tide) round quad Q, as one polygon: its two waterlines over Q's grid x range
func owpoly(a: int, Q: PackedVector2Array) -> PackedVector2Array:
	var o := 1 - a
	var g0 := 1e9
	var g1 := -1e9
	for p in Q:
		var gx := ((p.x - ki) / 32.0 + (p.y - hi) / 16.0) * 0.5
		g0 = minf(g0, gx); g1 = maxf(g1, gx)
	g0 = maxf(g0 - 2.0 * ST, xa(o)); g1 = minf(g1 + 2.0 * ST, xb(o))
	var W := PackedVector2Array()
	if g1 <= g0: return W
	if o == 1 and bump((g0 + g1) * 0.5) <= 0.03: return W
	var j0 := J0(g0)
	var j1 := J1(g1)
	if j1 <= j0: return W
	for j in range(j0, j1 + 1):
		var x := X0 + j * ST
		W.append(g2s(x, Ac(o, x) - ((EB(o, x, true) + fext(o, x, true)) if F else (EB(o, x, true) - drop(o, x, true))) * KK(o, x)))
	for j in range(j1, j0 - 1, -1):
		var x := X0 + j * ST
		W.append(g2s(x, Ac(o, x) + ((EB(o, x, false) + fext(o, x, false)) if F else (EB(o, x, false) - drop(o, x, false))) * KK(o, x)))
	return W

# points along one offset line: runs of [X, Y, x]
func line(a: int, nb: bool, f: Callable, act: Callable = Callable()) -> Array:
	var out := []
	var run := []
	var sg := -1.0 if nb else 1.0
	var x0 := xa(a)
	var x1 := xb(a)
	for j9 in range(J0(x0), J1(x1) + 1):
		var x := X0 + j9 * ST
		if act.is_valid() and not act.call(x):
			if run.size() > 1: out.append(run)
			run = []
			continue
		var p := g2s(x, Ac(a, x) + sg * float(f.call(x)) * KK(a, x))
		if ow(a, p):
			if run.size() > 1: out.append(run)
			run = []
			continue
		run.append([p.x, p.y, x])
	if run.size() > 1: out.append(run)
	return out

func body(a: int, x0: float, x1: float, fn: Callable, fs: Callable) -> Array:
	var P := PackedVector2Array()
	x0 = maxf(x0, xa(a)); x1 = minf(x1, xb(a))
	if x1 <= x0: return []
	var a9 := J0(x0)
	var b9 := J1(x1)
	if b9 <= a9: return []
	for j in range(a9, b9 + 1):
		var x := X0 + j * ST
		P.append(g2s(x, Ac(a, x) - float(fn.call(x)) * KK(a, x)))
	var Q := PackedVector2Array()
	for j in range(a9, b9 + 1):
		var x := X0 + j * ST
		Q.append(g2s(x, Ac(a, x) + float(fs.call(x)) * KK(a, x)))
	return band(P, Q)

# the area between two lines of the same length, as one quad per step (a long band would self-intersect and fail to triangulate)
static func band(top: PackedVector2Array, bot: PackedVector2Array) -> Array:
	var out := []
	for j in mini(top.size(), bot.size()) - 1:
		out.append(PackedVector2Array([top[j], top[j + 1], bot[j + 1], bot[j]]))
	return out

func sides(f: Callable) -> void:
	for a in 2:
		for s in 2:
			f.call(a, s == 1, a * 2 + s)

func pts_of(run: Array, dy: float = 0.0) -> PackedVector2Array:
	var P := PackedVector2Array()
	for r in run: P.append(Vector2(r[0], r[1] + dy))
	return P

# ---- draw ops
func poly(P: PackedVector2Array, c: Color, mode: int = M_PLAIN, amt: float = 1.0) -> void:
	if P.size() >= 3: ops.append([0, c, P, mode, amt, 0.0])
func polys(PS: Array, c: Color, mode: int = M_PLAIN, amt: float = 1.0) -> void:
	for P in PS: poly(P, c, mode, amt)
# strip quads with one colour on the fA edge and another on the fB edge (strip() vertex order differs per side)
func grads(PS: Array, nb: bool, cA: Color, cB: Color, mode: int = M_PLAIN, amt: float = 1.0) -> void:
	var CC := PackedColorArray([cB, cB, cA, cA]) if nb else PackedColorArray([cA, cA, cB, cB])
	var org: Array = sorig if sorig.size() == PS.size() else []
	for i in PS.size():
		var P: PackedVector2Array = PS[i]
		var Q = org[i] if org.size() > 0 else null
		if Q == null:
			if P.size() == 4: ops.append([0, CC, P, mode, amt, 0.0])
			continue
		# a piece cut from a strip quad: each corner takes the colour of where it lies across the quad
		var q: PackedVector2Array = Q
		var CP := PackedColorArray()
		for p in P:
			var d0 := Geometry2D.get_closest_point_to_segment_uncapped(p, q[0], q[1]).distance_to(p)
			var d1 := Geometry2D.get_closest_point_to_segment_uncapped(p, q[3], q[2]).distance_to(p)
			CP.append(CC[0].lerp(CC[2], d0 / maxf(d0 + d1, 1e-4)))
		ops.append([0, CP, P, mode, amt, 0.0])
func stroke(P: PackedVector2Array, c: Color, w: float, mode: int = M_PLAIN, amt: float = 1.0, closed: bool = false) -> void:
	if P.size() >= 2: ops.append([1, c, P, mode, amt, w, closed])
func strokes(PS: Array, c: Color, w: float, mode: int = M_PLAIN, amt: float = 1.0, closed: bool = false) -> void:
	for P in PS: stroke(P, c, w, mode, amt, closed)
# BTX.fringe: a stroke in the ria grass-edge texture tinted with the colour
func fringe(P: PackedVector2Array, c: Color, w: float, al: float, fl: bool = false, closed: bool = false) -> void:
	stroke(P, c, w, M_RIAF if fl else M_RIA, al, closed)
# BTX.wet: a strip of wet earth at the water's edge, ragged outside, with the mud texture
func wet(P: PackedVector2Array, c: Color, w: float, closed: bool = false) -> void:
	stroke(P, Color(c, 0.45), w * 0.45, M_PLAIN, 1.0, closed)
	stroke(P, Color(c, 0.6), w, M_RACH, 1.0, closed)
	stroke(P, c, w * 0.8, M_BUN, 0.9, closed)
func glint(P: PackedVector2Array, c: Color, w: float, al: float) -> void:
	stroke(P, c, w * 1.6, M_STK, al)

# CLP: which picture a bank plant is (same rule as the ponds), kind 0 tuft, 1 reed, 2 small
const FL := ["h_sao_nhai", "h_dua_can", "h_tim", "h_cuc_trang"]
func clp(x: float, y: float, s: float, kind: int, v: int) -> void:
	v = v & 7
	var m := (v & 4) != 0
	var h := hh(roundf(x * 3.0) / 3.0, roundf(y * 3.0) / 3.0)
	var c := hh(roundf(x / 7.0) + 0.3, roundf(y / 7.0) + 0.7)
	var k := s * (0.85 + h * 0.3)
	x += (h - 0.5) * 3.0
	if (kind != 1 and c > 0.5 and c < 0.72) or (kind == 1 and c < 0.5):
		var kk := k * (0.4 if kind == 1 else 0.34)
		plants.append(["lau" + str(v & 3), x, y, -kk if m else kk, kk])
		return
	if c >= 0.72:
		var id: String = FL[int(floorf(c * 53.0)) & 3]
		var q := minf(0.9, maxf(0.6, k * 0.62))
		plants.append([id + str((v + 1) & 3), x - 5.0 * q, y - 1.2 * q, q * 0.85 if m else -q * 0.85, q * 0.85])
		plants.append([id + str(v & 3), x + 1.0 * q, y, -q if m else q, q])
		return
	var t := (3 if v & 1 else 1) if kind == 1 else (2 if v & 1 else 0)
	var k2 := k * (0.55 if kind == 1 else (0.4 if kind == 2 else 0.48))
	plants.append(["co" + str(t), x, y, -k2 if m else k2, k2])

# ================================================================ the layer
func build() -> void:
	ops.clear(); plants.clear()
	if F:
		_flood()
		for o in ops: o[3] = int(o[3]) + 32   # bank.gdshader: flood edge pictures, off the roads
		_stakes()
		return
	# the grass lip along both banks, see-through, with the grass texture
	var LP := []
	sides(func(a: int, nb: bool, i: int):
		LP.append_array(strip(a, nb, func(x): return EB(a, x, nb) + 0.02,
			func(x): return EB(a, x, nb) + 0.02 + (0.08 + 0.26 * vn(x * 0.7, i + 1)) * BPf(a, x, nb),
			func(x): return on(a, x, nb))))
	polys(LP, col("lip", 0.2))
	polys(LP, col("lip", 0.6), M_CO, 1.0)
	_mud()
	_tips()
	_faces()
	_near()
	_stakes()
	# water on land nobody has bought takes the dull wash (the water shader draws the water itself)
	# the live game (GL water) never washes the river itself, only the land: the player sees clean water, so is it here
	var lk: Array = T["lk"] if WASH_WATER else []
	var lk0: int = int(T["lk0"])
	var xx := int(floorf(xa(0)))
	var xe := xb(0)
	while xx < xe:
		var i0 := xx - lk0
		if i0 < 0 or i0 >= lk.size() or int(lk[i0]) == 0:
			xx += 1
			continue
		var x3 := xx
		var x4 := xx + 1
		while x4 < xe and x4 - lk0 < lk.size() and int(lk[x4 - lk0]) == 1: x4 += 1
		xx = x4
		for a in 2:
			for Q in body(a, x3, x4, func(x): return EB(a, x, true) + 0.35, func(x): return EB(a, x, false) + 0.35):
				if a == 0:
					poly(Q, col("dull"))
					continue
				# the cù lao arm's wash leaves out what arm 0's wash already covers (arm 0 already washed it: twice looked like a pale wedge)
				var q0: Vector2 = Q[0]
				var u: float = (q0.x - ki) / 32.0
				var v: float = (q0.y - hi) / 16.0
				var gx: float = (u + v) * 0.5
				var W := PackedVector2Array()
				for xw in [gx - 0.01, gx + ST + 0.01]:
					W.append(g2s(xw, Ac(0, xw) - (EB(0, xw, true) + 0.35) * KK(0, xw)))
				for xw in [gx + ST + 0.01, gx - 0.01]:
					W.append(g2s(xw, Ac(0, xw) + (EB(0, xw, false) + 0.35) * KK(0, xw)))
				for R in Geometry2D.clip_polygons(Q, W):
					var R2: PackedVector2Array = R
					if R2.size() == 4: R2.insert(2, (R2[1] + R2[2]) * 0.5)   # not an edge-softened strip quad
					poly(R2, col("dull"))

# ---- nước nổi (the game's floodSheet): the water spreads over the land beside the river up to fext beyond each bank
# (the sheet itself is the river water shader, reading w/flood.png); here its edge: two paler shallow bands out towards
# the edge, the sky in it, a wet dark band of soaked earth just outside, the pale lapping line, rice tips standing out
# of flooded paddies and grass, bits of drift. Roads stay dry (bank.gdshader cuts them out of these with flood.png B).
func _fband(f0: Callable, f1: Callable, c: Color, al: float, act: Callable = Callable()) -> void:
	var cc := c
	cc.a *= al
	no_ow = true
	sides(func(a: int, nb: bool, i: int):
		var PS := strip(a, nb, func(x): return EB(a, x, nb) + float(f0.call(a, x, nb, i)), func(x): return EB(a, x, nb) + float(f1.call(a, x, nb, i)),
				func(x): return on(a, x, nb) and (not act.is_valid() or act.call(a, x, nb, i)))
		if a == 0:
			polys(PS, cc)
			return
		# the game fills both arms' bands as one shape: the cù lao arm's band leaves out what arm 0's same band covers
		for Q in PS:
			var R := [Q]
			for s0 in 2:
				var nb0 := s0 == 1
				var W := _band0(Q, nb0, f0, f1)
				if W.size() < 3: continue
				var R2 := []
				for q in R:
					for r in Geometry2D.clip_polygons(q, W): R2.append(r)
				R = R2
			for q in R:
				var P: PackedVector2Array = q
				if P.size() == 4: P.insert(2, (P[1] + P[2]) * 0.5)   # not an edge-softened strip quad
				if P.size() >= 3: poly(P, cc)
		)
	no_ow = false

# arm 0's band (side nb, offsets f0..f1 beyond the bank) over the grid x range of quad Q, as one polygon
func _band0(Q: PackedVector2Array, nb: bool, f0: Callable, f1: Callable) -> PackedVector2Array:
	var g0 := 1e9
	var g1 := -1e9
	for p in Q:
		var gx := ((p.x - ki) / 32.0 + (p.y - hi) / 16.0) * 0.5
		g0 = minf(g0, gx); g1 = maxf(g1, gx)
	var W := PackedVector2Array()
	var j0 := J0(g0 - 2.0 * ST)
	var j1 := J1(g1 + 2.0 * ST)
	var sg := -1.0 if nb else 1.0
	var ii := 1 if nb else 0   # sides() numbers arm 0's sides 0 (+) and 1 (-)
	for j in range(j0, j1 + 1):
		var x := X0 + j * ST
		if not on(0, x, nb): return PackedVector2Array()
		W.append(g2s(x, Ac(0, x) + sg * (EB(0, x, nb) + float(f0.call(0, x, nb, ii))) * KK(0, x)))
	for j in range(j1, j0 - 1, -1):
		var x := X0 + j * ST
		W.append(g2s(x, Ac(0, x) + sg * (EB(0, x, nb) + float(f1.call(0, x, nb, ii))) * KK(0, x)))
	return W

func farm(x: float, nb: bool) -> int: return 1 if (not nb and x > xa(1) and x < xb(1)) else 0

func _flood() -> void:
	_fband(func(a, x, nb, i): return fext(a, x, nb) * 0.3, func(a, x, nb, i): return fext(a, x, nb), col("flO"), 0.45)
	_fband(func(a, x, nb, i): return fext(a, x, nb) * 0.55, func(a, x, nb, i): return fext(a, x, nb), col("flO"), 0.45)
	_fband(func(a, x, nb, i): return fext(a, x, nb) * (0.18 + 0.22 * vn(x * 0.3 + i, i + 3)),
			func(a, x, nb, i): return fext(a, x, nb) * (0.62 + 0.26 * vn(x * 0.27 + i, i + 5)), col("sky"), 0.3,
			func(a, x, nb, i): return vn(x * 0.16 + i * 2, i + 7) > 0.42)
	_fband(func(a, x, nb, i): return fext(a, x, nb), func(a, x, nb, i): return fext(a, x, nb) + 0.09 + 0.08 * vn(x * 1.7 + i, i + 9), col("flW"), 1.0)
	sides(func(a: int, nb: bool, i: int):
		for r in line(a, nb, func(x): return EB(a, x, nb) + fext(a, x, nb) - 0.025, func(x): return on(a, x, nb) and vn(x * 1.1 + i, i + 11) > 0.22):
			stroke(pts_of(r), col("flE"), 0.9))
	# rice tips out of the flooded paddies (denser and taller out towards the edge, where the water is shallow) and grass
	if kindf.is_valid():
		var P1 := []; var P2 := []; var P3 := []
		var xs0 := int(floorf(maxf(X0, -95.0)))
		var xs1 := int(ceilf(minf(X0 + (NJ - 1) * ST, 180.0)))
		for t in range(xs0, xs1 + 1):
			var c0 := Ac(0, t + 0.5)
			var k0 := KK(0, t + 0.5)
			var r_lo := int(floorf(c0 - (EB(0, t + 0.5, true) + fext(0, t + 0.5, true) + 0.5) * k0))
			var a1 := farm(t + 0.5, false)
			var c1 := Ac(a1, t + 0.5)
			var r_hi := int(ceilf(c1 + (EB(a1, t + 0.5, false) + fext(a1, t + 0.5, false) + 0.5) * KK(a1, t + 0.5)))
			for r0 in range(r_lo, r_hi + 1):
				var ty: int = kindf.call(t, r0)
				if ty != 1: continue   # only flooded paddies show their rice (Link: no "V" marks on grass)
				# a drowned paddy: the rice still stands in its rows, so its leaf tips break the water in rows across the
				# field, thick where the water is shallow (out towards the flood's edge), thinning in patches and gone
				# where it is deep; never single sprigs dotted about
				var tc := t + 0.5; var rc := r0 + 0.5
				var nbt := rc < Ac(0, tc)
				var At := 0 if nbt else farm(tc, false)
				var fet := fext(At, tc, nbt)
				var ot := absf(rc - Ac(At, tc)) / KK(At, tc) - EB(At, tc, nbt)
				if ot < -0.5 or ot > fet + 0.5: continue
				var patch := 0.5 * (vn(t * 0.23 + r0 * 0.11, 21.0) + vn(r0 * 0.29 - t * 0.07, 23.0))
				for rw in 5:
					var px := t + (rw + 0.5) / 5.0 + (hh(t * 5 + rw, r0) - 0.5) * 0.02
					for m in 9:
						var py := r0 + (m + 0.5 + 0.25 * (hh(r0 * 9 + m, t * 5 + rw) - 0.5) + 0.5 * (rw % 2)) / 9.0
						var nb := py < Ac(0, px)
						var A := 0 if nb else farm(px, false)
						var cA := Ac(A, px)
						if nb != (py < cA): continue
						var fe := fext(A, px, nb)
						var o := absf(py - cA) / KK(A, px) - EB(A, px, nb)
						if o < 0.0 or o > fe - 0.04 or not on(A, px, nb): continue
						var u := o / fe
						var dens := sst(0.22, 0.75, u) * (0.42 + 0.85 * patch) - 0.09
						var rr := hh(px * 7.1, py * 3.3)
						if rr > dens: continue
						var p := g2s(px, py)
						if ow(A, p): continue
						# only the top of each hill shows: 3-4 blades fanning out of the water, the outer ones bending over
						var hgt := (2.0 + 2.8 * u) * (0.8 + 0.4 * hh(px, py))
						var nl := 4 + int(hh(px * 3.1, py * 1.7) * 2.0)
						var lean := (hh(py * 2.3, px) - 0.5) * 0.25
						for b in nl:
							var f := (b / float(nl - 1)) - 0.5
							var an := -PI * 0.5 + f * 0.85 + lean + (hh(px + b, py * 2.0) - 0.5) * 0.3
							var ln := hgt * (0.7 + 0.4 * hh(px * 5.0 + b, py)) * (1.0 - 0.3 * absf(f))
							var dv := Vector2(cos(an), sin(an))
							var q0 := p + Vector2(f * 0.8, 0.0)
							var q1 := q0 + dv * ln * 0.6
							var q2 := q0 + dv * ln + Vector2(f * ln * 0.3, absf(f) * ln * 0.35)
							var dst: Array = P1 if (b + int(rr * 10.0)) % 2 == 0 else P2
							dst.append(PackedVector2Array([q0, q1, q2]))
						# the ring of still water round the stems
						P3.append(PackedVector2Array([p + Vector2(-1.1, 0.2), p + Vector2(1.1, 0.2)]))
		strokes(P3, Color(col("lua2").darkened(0.5), 0.4), 0.7)
		strokes(P2, col("lua2"), 0.55)
		strokes(P1, col("lua1"), 0.55)

# the cù lao's two ends: where the river splits and joins again the current drops its silt in a tongue of mud that runs
# on from the island's point along the middle of the river, rounded at its end, longer the lower the water; a skirt of
# clear shallow water round it, wet and dark at its rim, a paler drier crest, a gleam, a few tracks and stranded lục bình
func _tips() -> void:
	if L < 0.05: return
	var land := func(x: float) -> float:
		return (Ac(1, x) - EB(1, x, true) * KK(1, x)) - (Ac(0, x) + EB(0, x, false) * KK(0, x))
	var mid := func(x: float) -> float:
		return ((Ac(1, x) - EB(1, x, true) * KK(1, x)) + (Ac(0, x) + EB(0, x, false) * KK(0, x))) * 0.5
	for e in 2:
		# find the island's point: the first grid x (from that end) where the two banks have parted
		var dir := -1.0 if e == 0 else 1.0   # the tongue runs upstream from the head, downstream from the tail
		var xt := -1.0
		if e == 0:
			var x := xa(1) + ST
			while x < xb(1) and land.call(x) <= 0.0: x += ST
			xt = x
		else:
			var x := xb(1) - ST
			while x > xa(1) and land.call(x) <= 0.0: x -= ST
			xt = x
		var Zt := (drop(0, xt, false) + drop(1, xt, true)) * 0.5
		if Zt < 0.08: continue
		var sd := 7.0 + e * 13.0
		var Lb := 0.6 + 3.0 * Zt
		var W0 := 0.5 * (drop(0, xt, false) * KK(0, xt) + drop(1, xt, true) * KK(1, xt)) + 0.1
		var lim := xa(1) + 0.05 if e == 0 else xb(1) - 0.05
		var n := 22
		var CL := PackedVector2Array(); var LF := PackedVector2Array(); var RT := PackedVector2Array()
		var LF2 := PackedVector2Array(); var RT2 := PackedVector2Array()
		var LH := PackedVector2Array(); var RH := PackedVector2Array()
		var CR := PackedVector2Array(); var CRL := PackedVector2Array(); var CRR := PackedVector2Array()
		var gm0: float = mid.call(xt)
		var slope := (float(mid.call(xt + dir * 0.4)) - gm0) / 0.4   # carried on past the arms' start
		for m in n + 1:
			var t := m / float(n)
			var x := xt + dir * Lb * t
			var gm: float = mid.call(x) if ((x >= lim) if e == 0 else (x <= lim)) else gm0 + slope * (x - xt)
			gm += 0.18 * (vn(t * 2.3 + sd, sd) - 0.5) * t   # not a ruler line
			var hw := W0 * pow(maxf(0.0, 1.0 - pow(t, 1.7)), 0.55) * (0.9 + 0.2 * vn(t * 5.0 + sd, sd + 1))
			var hs := hw + 0.16 + 0.06 * vn(t * 3.0, sd + 2)   # the shallow skirt
			CL.append(g2s(x, gm))
			LF.append(g2s(x, gm - hw)); RT.append(g2s(x, gm + hw))
			LF2.append(g2s(x, gm - hw * 0.62)); RT2.append(g2s(x, gm + hw * 0.62))
			LH.append(g2s(x, gm - hs)); RH.append(g2s(x, gm + hs))
			var tc := minf(1.0, t / 0.85)
			var hc := hw * 0.42 * pow(maxf(0.0, 1.0 - tc), 0.6)
			var oc := hw * 0.12 * sin(t * 4.0 + sd)
			CR.append(g2s(x, gm + oc)); CRL.append(g2s(x, gm + oc - hc)); CRR.append(g2s(x, gm + oc + hc))
		var shalc := col("mudW").lerp(col("shal"), 0.45)
		var bandc := func(A: PackedVector2Array, B: PackedVector2Array, cA: Color, cB: Color, mode: int, amt: float):
			for P in band(A, B):
				ops.append([0, PackedColorArray([cA, cA, cB, cB]), P, mode, amt, 0.0])
		# skirt of shallow water: mud seen through it, fading out
		bandc.call(LH, LF, Color(shalc, 0.0), Color(shalc, 0.7), M_BUN, 0.8)
		bandc.call(RH, RT, Color(shalc, 0.0), Color(shalc, 0.7), M_BUN, 0.8)
		# the tongue
		polys(band(LF, RT), col("mudM"), M_BUN, 1.0)
		# wet dark rim fading inwards, both sides
		bandc.call(LF, LF2, Color(col("mudG"), 0.8), Color(col("mudG"), 0.0), M_BUN, 0.9)
		bandc.call(RT, RT2, Color(col("mudG"), 0.8), Color(col("mudG"), 0.0), M_BUN, 0.9)
		# the paler drier crest along its back, cracked
		bandc.call(CRL, CR, Color(col("mudD"), 0.0), Color(col("mudD"), 0.85), M_NUT, 0.7)
		bandc.call(CR, CRR, Color(col("mudD"), 0.85), Color(col("mudD"), 0.0), M_NUT, 0.7)
		# sky in the wet mud on the near (lower on screen) flank
		bandc.call(RT, RT2, Color(col("sky").lightened(0.15), 0.45), Color(col("sky"), 0.0), 9, 1.0)
		var RG := PackedVector2Array()
		for m in range(2, n - 1):
			RG.append(RT[m] + Vector2(0, -0.6))
		glint(RG, col("shine"), 1.1, 0.9)
		# the lapping line just out in the water round its end
		var LP := PackedVector2Array()
		for m in range(n / 3, n + 1): LP.append(LH[m].lerp(LF[m], 0.45))
		for m in range(n, n / 3 - 1, -1): LP.append(RH[m].lerp(RT[m], 0.45))
		stroke(LP, col("flO", 0.3), 0.8)
		# bird tracks walking along it, a clump or two of lục bình left by the ebb, a tuft where it joins the island
		var TRK := []
		var tx0 := 0.15 + 0.1 * hh(sd, 3)
		for m in 8:
			var t := tx0 + m * 0.07
			var q := CL[int(t * n)].lerp(CL[mini(n, int(t * n) + 1)], fmod(t * n, 1.0)) + Vector2((m % 2) * 1.4 - 0.7, 1.5 + m * 0.3)
			TRK.append(PackedVector2Array([q, q + Vector2(-1.3, -0.9)])); TRK.append(PackedVector2Array([q, q + Vector2(1.3, -0.9)]))
			TRK.append(PackedVector2Array([q, q + Vector2(0.1, -1.5)])); TRK.append(PackedVector2Array([q, q + Vector2(-0.2, 0.8)]))
		strokes(TRK, col("trk", 0.55), 0.6)
		if Zt > 0.35:
			for m in 1:   # one clump: more read as cabbages lined up
				var t := 0.45 + 0.17 * m + 0.05 * hh(sd, m)
				var j := mini(n, int(t * n))
				var p := RT[j].lerp(CL[j], 0.3 + 0.2 * hh(m, sd))
				var k2 := 1.0 + 0.3 * hh(sd, m + 9)
				var SHD := PackedVector2Array()
				for q in 12:
					var an := q / 12.0 * TAU
					SHD.append(p + Vector2(cos(an) * 6.5 * k2, 0.6 + sin(an) * 2.2 * k2))
				poly(SHD, col("mudG", 0.45))
				plants.append(["lb" + str((m * 2 + e) % 6), p.x, p.y, -k2 if m % 2 else k2, k2])
		var pr := CL[1].lerp(LF[1], 0.4)
		clp(pr.x, pr.y, 1.0, 0, int(sd) & 7)

# the mud flats bared at low water
func _mud() -> void:
	var PM := []; var PD := []; var PW := []
	var shal := col("shal")
	sides(func(a: int, nb: bool, i: int):
		var act := func(x): return a == 0 or bump(x) > 0.03
		var wl := func(x): return EB(a, x, nb) - drop(a, x, nb)
		# the top of the bared mud is not a ruler line: it bites into the bank grass by a little, unevenly
		var top := func(x): return EB(a, x, nb) + 0.02 - 0.07 * vn(x * 4.7 + i, i + 80) - 0.03 * hh(roundf(x * 5.0), i + 81)
		# the bed keeps going under the water: mud seen through a hand of clear shallow water, fading into the deep
		var sub := func(x): return wl.call(x) - 0.03 - (0.08 + 0.12 * vn(x * 2.2 + i, i + 82) + 0.12 * minf(1.0, drop(a, x, nb)))
		var actw := func(x): return act.call(x) and drop(a, x, nb) > 0.02 and not ovx(a, nb, x, sub.call(x)) and not ovx(a, nb, x, wl.call(x))
		grads(strip(a, nb, sub, func(x): return wl.call(x) - 0.03, actw), nb, Color(shal, 0.0), Color(col("mudW").lerp(shal, 0.45), 0.75), M_BUN, 0.8)
		PM.append_array(strip(a, nb, func(x): return wl.call(x) - 0.03, top, act))
		PD.append_array(strip(a, nb, func(x):
			var Z := drop(a, x, nb)
			return EB(a, x, nb) - Z * (0.16 + 0.34 * vn(x * 0.9 + i * 3, i + 20) + 0.1 * (vn(x * 3.1 + i, i + 24) - 0.5)),
			top, act))
		PW.append_array(strip(a, nb, func(x): return wl.call(x) - 0.03, func(x):
			var Z := drop(a, x, nb)
			return wl.call(x) + Z * (0.3 + 0.25 * vn(x * 1.3 + i, i + 26) + 0.08 * (vn(x * 4.3 + i, i + 27) - 0.5)), act)))
	polys(PM, col("mudM"), M_BUN, 1.0)
	polys(PD, col("mudD"), M_NUT, 0.85)
	polys(PW, col("mudW"), M_BUN, 1.0)
	sides(func(a: int, nb: bool, i: int):
		var act := func(x): return a == 0 or bump(x) > 0.03
		var wl := func(x): return EB(a, x, nb) - drop(a, x, nb)
		# the darkest, wettest mud right at the water, fading up the flat (was one flat band: read as a cut-out outline)
		grads(strip(a, nb, func(x): return wl.call(x) - 0.03, func(x):
			var Z := drop(a, x, nb)
			return wl.call(x) + minf(0.22, Z * (0.16 + 0.16 * vn(x * 1.7 + i, i + 30))), act), nb,
			Color(col("mudG"), 0.85), Color(col("mudG"), 0.0), M_BUN, 0.9)
		# wet mud mirrors the sky in soft patches, strongest near the water
		grads(strip(a, nb, func(x): return wl.call(x) - 0.01, func(x):
			var Z := drop(a, x, nb)
			return wl.call(x) + Z * (0.3 + 0.25 * vn(x * 1.1 + i, i + 84)), act), nb,
			Color(col("sky").lightened(0.15), 0.5), Color(col("sky"), 0.0), 9, 1.0))
	var SH := []; var S2 := []
	sides(func(a: int, nb: bool, i: int):
		for r in line(a, nb, func(x): return EB(a, x, nb) - drop(a, x, nb) + 0.03,
				func(x): return (a == 0 or bump(x) > 0.03) and vn(x * 0.8 + i, i + 40) > 0.3):
			SH.append(pts_of(r))
		if L > 0.1:
			for r in line(a, nb, func(x):
					var Z := drop(a, x, nb)
					return EB(a, x, nb) - Z * (0.8 + 0.08 * vn(x * 2.1 + i, i + 42)),
					func(x): return (a == 0 or bump(x) > 0.03) and drop(a, x, nb) > 0.3 and vn(x * 1.9 + i, i + 41) > 0.5):
				S2.append(pts_of(r)))
	for P in SH: glint(P, col("shine"), 1.2, 1.0)
	sides(func(a: int, nb: bool, i: int):
		for r in line(a, nb, func(x): return EB(a, x, nb) - drop(a, x, nb) - 0.07 - 0.03 * vn(x * 3.0 + i, i + 86),
				func(x): return (a == 0 or bump(x) > 0.03) and drop(a, x, nb) > 0.04 and vn(x * 1.3 + i, i + 87) > 0.35 and not ovx(a, nb, x, EB(a, x, nb) - drop(a, x, nb) - 0.07)):
			stroke(pts_of(r), col("flO", 0.32), 0.8))
	for P in S2: glint(P, col("shine", col("shine").a * 0.6), 1.8, 0.8)   # a soft streaked gleam, not a crisp line (read as sticks)
	if L < 0.1: return
	var HO := []; var TR := []; var SL := []
	sides(func(a: int, nb: bool, i: int):
		var sg := -1.0 if nb else 1.0
		for j9 in range(J0(xa(a)), J1(xb(a)) + 1):
			var x := X0 + j9 * ST
			if a == 1 and bump(x) <= 0.03: continue
			if clipx(a, nb, x): continue
			var Z := drop(a, x, nb)
			var E := EB(a, x, nb)
			var k := KK(a, x)
			var r := hh(j9, i + 50)
			var c := Ac(a, x)
			if Z > 0.42 and r < 0.11:
				# a runnel: from the upper mud down to the water, wandering
				# (placed with the bank line at the runnel's own x: the game kept the grid x's line and the ends fell in the water)
				# a draining channel meanders, narrow up the flat and widening to the water, wet-dark with a soft gleam low down
				var R := PackedVector2Array()
				var nR := 13
				for m in nR:
					var t := m / float(nR - 1)
					var xx := x + (0.3 * sin(t * 2.7 + r * 90.0) + 0.07 * sin(t * 9.0 + r * 31.0)) * minf(1.0, Z)
					var o := E - Z * (0.2 + 0.86 * t)
					R.append(g2s(xx, Ac(a, xx) + sg * o * KK(a, xx)))
				var wetc := false
				for q in R:
					if ow(a, q): wetc = true
				if wetc: continue
				for m in nR - 1:
					var t := (m + 0.5) / float(nR - 1)
					var seg := PackedVector2Array([R[m], R[m + 1]])
					stroke(seg, col("run", 0.3), 1.2 + 3.2 * t)
					stroke(seg, col("run", 0.55), 0.5 + 1.4 * t)
					if t > 0.45:
						stroke(PackedVector2Array([R[m] + Vector2(0, -0.4), R[m + 1] + Vector2(0, -0.4)]), col("sky", 0.28 * (t - 0.45) / 0.55), 0.4 + 0.8 * t)
			elif Z > 0.6 and r > 0.93:
				# a puddle
				var p := g2s(x, c + sg * (E - Z * (0.35 + 0.35 * hh(x, i + 60))) * k)
				if ow(a, p): continue
				var rx := 2.6 + 3.6 * hh(x * 3, i + 61)
				var ry := rx * (0.3 + 0.15 * hh(x, i + 62))
				var rot := (hh(x, i + 63) - 0.5) * 0.5
				var E1 := PackedVector2Array()
				for m in 20:
					var an := m / 20.0 * TAU
					var e := Vector2(cos(an) * rx, sin(an) * ry)
					E1.append(p + Vector2(e.x * cos(rot) - e.y * sin(rot), e.x * sin(rot) + e.y * cos(rot)))
				poly(E1, col("pud", 0.5))
				var E2 := PackedVector2Array()
				for m in 9:
					var an := 3.3 + (6.1 - 3.3) * m / 8.0
					E2.append(p + Vector2(cos(an) * rx, 0.3 + sin(an) * ry))
				stroke(E2, col("mudG", 0.5), 0.8)
			for m in 2:
				if Z > 0.22 and hh(x * 9.1 + m, i + 70) < 0.55:
					var p := g2s(x + 0.1 * m, c + sg * (E - Z * (0.28 + 0.62 * hh(x * 4.7 + m, i + 71))) * k)
					if ow(a, p): continue
					var E3 := PackedVector2Array()
					for q in 10:
						var an := q / 10.0 * TAU
						E3.append(p + Vector2(cos(an) * 1.1, sin(an) * 0.55))
					HO.append(E3)
			if Z > 0.4 and r > 0.8 and r < 0.85:
				var u0 := 0.12 + 0.15 * hh(x, i + 75)
				var dr := 1.0 if hh(x, i + 76) < 0.5 else -1.0
				for m in 7:
					var tt := u0 + m * 0.11
					if tt > 0.92: break
					var xt := x + dr * m * 0.06 + (0.035 if m % 2 else -0.035)
					var pp := g2s(xt, Ac(a, xt) + sg * (E - Z * tt) * KK(a, xt))   # on the mud at its own x
					if ow(a, pp): continue
					TR.append(PackedVector2Array([pp, pp + Vector2(-1.3, -0.9)]))
					TR.append(PackedVector2Array([pp, pp + Vector2(1.3, -0.9)]))
					TR.append(PackedVector2Array([pp, pp + Vector2(0.1, -1.5)]))
					TR.append(PackedVector2Array([pp, pp + Vector2(-0.2, 0.8)]))
			if Z > 0.3 and hh(x * 5.3, i + 77) < 0.28:
				var p := g2s(x, c + sg * (E - Z * (0.06 + 0.22 * hh(x * 6.1, i + 78))) * k)
				if ow(a, p): continue
				SL.append(PackedVector2Array([p + Vector2(-0.7, -0.4), p + Vector2(0.7, -0.4), p + Vector2(0.7, 0.4), p + Vector2(-0.7, 0.4)]))
			if Z > 0.2 and r > 0.45 and r < 0.72:
				var p := g2s(x, c + sg * (E - Z * (0.04 + 0.22 * hh(x * 2.3, i + 72))) * k)
				if ow(a, p): continue
				clp(p.x, p.y + 0.5, 0.8 + r * 0.45, 0, int(floorf(r * 40.0)) & 7))
	polys(HO, col("hole"))
	strokes(TR, col("trk", 0.6), 0.6)
	polys(SL, col("shell", 0.75))
	_mudlip()
	_stranded()

# lục bình the ebb left behind: little clumps lying on the low mud near the water, a wet shadow under each
func _stranded() -> void:
	sides(func(a: int, nb: bool, i: int):
		var sg := -1.0 if nb else 1.0
		for j9 in range(J0(xa(a)), J1(xb(a)) + 1):
			var x := X0 + j9 * ST
			if a == 1 and bump(x) <= 0.03: continue
			if clipx(a, nb, x): continue
			var Z := drop(a, x, nb)
			if Z < 0.35 or hh(j9 * 1.3, i + 120) > 0.07: continue
			if nb and on(a, x, nb): continue   # the far bank's slope covers its mud on screen: a clump would sit on the grass
			if (x > xa(1) - 4.0 and x < xb(1) + 4.0) and bump(x) < 0.6: continue   # not near the cù lao's ends: the tongues there carry their own
			var E := EB(a, x, nb)
			var n := 2 + int(floorf(hh(x, i + 121) * 4.0))
			var cl := []
			for m in n:
				var xm := x + (hh(x + m, i + 122) - 0.5) * 0.3
				var tt := 0.72 + 0.24 * hh(x * 2.0 + m, i + 123)
				var p := g2s(xm, Ac(a, xm) + sg * (E - Z * tt) * KK(a, xm))
				if ow(a, p): continue
				cl.append([p, hh(x * 3.0 + m, i + 124)])
			cl.sort_custom(func(u, v): return u[0].y < v[0].y)
			for e in cl:
				var p: Vector2 = e[0]
				var sd: float = e[1]
				var k2 := 1.0 + 0.35 * sd
				var SH := PackedVector2Array()
				for q in 12:
					var an := q / 12.0 * TAU
					SH.append(p + Vector2(cos(an) * 6.5 * k2, 0.6 + sin(an) * 2.2 * k2))
				poly(SH, col("mudG", 0.45))
				var nm := "lb" + str(int(floorf(sd * 6.0)) % 6)   # left on the mud: leaves only, no flower spikes
				plants.append([nm, p.x, p.y, -k2 if hh(sd, 7) < 0.5 else k2, k2]))

# where the grass ends above bared mud (and no slope or near-bank edge is drawn there): the grass fringe hangs over the
# ragged top, little slumps of earth have slid off it, roots hang out
func _mudlip() -> void:
	sides(func(a: int, nb: bool, i: int):
		var sg := -1.0 if nb else 1.0
		var act := func(x): return (a == 0 or bump(x) > 0.03) and drop(a, x, nb) > 0.06 and not on(a, x, nb)
		for r in line(a, nb, func(x): return EB(a, x, nb) + 0.01 - 0.035 * vn(x * 4.7 + i, i + 80), act):
			var P := pts_of(r)
			fringe(P, col("slope"), 3.4, 0.95, not nb)
			fringe(P, col("lip"), 2.0, 0.7, not nb)
		for j9 in range(J0(xa(a)), J1(xb(a)) + 1):
			var x := X0 + j9 * ST
			if not act.call(x) or clipx(a, nb, x): continue
			var Z := drop(a, x, nb)
			var E := EB(a, x, nb)
			var c := Ac(a, x)
			var k := KK(a, x)
			var r := hh(j9, i + 90)
			if r < 0.16:
				# a slump: a lump of bank earth lying on the mud just under the lip, lit on top
				var p := g2s(x, c + sg * (E - 0.06 - minf(Z, 1.0) * 0.12 * hh(x, i + 91)) * k)
				if ow(a, p): continue
				var w := 2.2 + 3.5 * hh(x * 3.3, i + 92)
				var hgt := w * (0.35 + 0.2 * hh(x, i + 93))
				var Q := PackedVector2Array()
				for m in 9:
					var an := PI + m / 8.0 * PI
					var jag := 0.8 + 0.35 * hh(x * 7.0 + m, i + 94)
					Q.append(p + Vector2(cos(an) * w * jag, sin(an) * hgt * jag))
				Q.append(p + Vector2(w * 0.8, 0.4)); Q.append(p + Vector2(-w * 0.8, 0.4))
				poly(Q, col("faceW"), M_BUN, 0.9)
				var Tq := PackedVector2Array()
				for m in 6:
					var an := PI * 1.15 + m / 5.0 * PI * 0.7
					Tq.append(p + Vector2(cos(an) * w * 0.85, sin(an) * hgt * 0.95))
				stroke(Tq, col("faceL", 0.55), 0.8)
			elif r < 0.34:
				# roots hanging from the lip down onto the mud
				var p0 := g2s(x, c + sg * (E + 0.01) * k)
				if ow(a, p0): continue
				var ln := 2.5 + 4.0 * hh(x * 5.1, i + 95)
				var bend := (hh(x * 2.9, i + 96) - 0.5) * 3.0
				stroke(_qcurve(p0, p0 + Vector2(bend, ln * 0.55), p0 + Vector2(bend * 0.4, ln)), col("root", 0.75), 0.6)
				if r > 0.27:
					stroke(_qcurve(p0 + Vector2(1.2, 0), p0 + Vector2(1.6 - bend, ln * 0.4), p0 + Vector2(1.0, ln * 0.7)), col("root", 0.6), 0.5))

# the far bank: a grassy slope down from the lip, a cut earth face where the current bites, a wet foot at the water
func _faces() -> void:
	for a in 2:
		var R := line(a, true, func(x): return EB(a, x, true) + 0.015, func(x): return on(a, x, true))
		for run in R:
			var n: int = run.size()
			var h := PackedFloat32Array(); var e := PackedFloat32Array(); var tb := PackedFloat32Array()
			for j in n:
				var x: float = run[j][2]
				var o := inner(a, x, false)
				var q := inner(a, x, true)
				var sd := a * 4
				var bp := BPf(a, x, true)
				h.append((((1.8 + 2.2 * vn(x * 0.8 + sd, 3)) * (0.7 if a == 1 else 1.0) + 5.5 * pow(o, 0.9)) * (1.0 - 0.65 * q) + L * 2.5 * o) * bp)
				e.append(sst(0.22, 0.5, o) * sst(0.3, 0.62, vn(x * 0.37 + sd, 8) + 0.3 * o) * (1.0 - q))
				tb.append(L * (1.4 + 2.6 * o + 0.9 * vn(x * 1.3 + sd, 12)) * (1.0 - 0.6 * q) * bp)
			var FB := PackedVector2Array(); var FT := PackedVector2Array()
			for j in n:
				FB.append(Vector2(run[j][0], run[j][1] + h[j]))
				FT.append(Vector2(run[j][0], run[j][1] - 0.3))
			polys(band(FT, FB), col("slope"))
			polys(band(FT, FB), col("slope"), M_CO, 0.85)
			for j in n: FT[j].y += 0.3
			fringe(FT, col("slope"), 2.6, 0.8)
			var CT := PackedVector2Array(); var CW := PackedVector2Array()
			for j in n:
				CT.append(Vector2(run[j][0], run[j][1] + h[j] - 1.8))
				CW.append(Vector2(run[j][0], run[j][1] + h[j] + 2.0 + 4.0 * vn(run[j][2] * 1.3 + a * 7, 15)))
			polys(band(CT, CW), col("face"))
			polys(band(CT, CW), col("face"), M_VACH, 1.0)
			wet(CW, col("faceW"), 3.6)
			glint(CW, col("shine"), 1.0, 0.8)
			fringe(FB, col("slope"), 4.0, 0.95)
			if L > 0.05:
				var TB := PackedVector2Array(); var TT := PackedVector2Array(); var T0 := PackedVector2Array()
				for j in n:
					TB.append(Vector2(run[j][0], run[j][1] + h[j] + tb[j] * (0.85 + 0.3 * hh(run[j][2] * 3.3, a + 5))))
					TT.append(Vector2(run[j][0], run[j][1] + h[j] + tb[j] * (0.3 + 0.2 * vn(run[j][2] * 1.7, a + 6))))
					T0.append(Vector2(run[j][0], run[j][1] + h[j] - 0.3))
				polys(band(T0, TB), col("faceW"))
				polys(band(T0, TB), col("faceW"), M_BUN, 1.0)
				polys(band(T0, TT), col("mudM", 0.55))
			# the cut face: where the bank is steep, bare earth with a wet band, pale dry patches, cracks, roots
			var seg := []
			var E := []
			var SQ := []   # [top line, bottom line] of every piece of cut face, for the silt layers and root hairs
			var fl := func():
				if seg.size() > 1:
					var Qt := PackedVector2Array(); var Qb := PackedVector2Array()
					for k in seg.size():
						var tq := minf(1.0, minf(k, seg.size() - 1 - k) / 2.5)
						Qt.append(Vector2(seg[k][0], seg[k][2] + (seg[k][1] - seg[k][2]) * tq))
						Qb.append(Vector2(seg[k][0], seg[k][2]))
					E.append_array(band(Qt, Qb))
					SQ.append([Qt, Qb, seg[0][3]])
				seg.clear()
			for j in n:
				var hE := (h[j] - 1.4) * e[j]
				if hE < 0.7:
					fl.call()
					continue
				seg.append([run[j][0], run[j][1] + h[j] - hE + (vn(run[j][2] * 2.3, a + 7) - 0.5) * 1.2, run[j][1] + h[j] + 0.2, run[j][2]])
			fl.call()
			if E.size() > 0:
				polys(E, col("face"))
				polys(E, col("face"), M_VACH, 1.0)
				# (clipped to the face in the game: here the bands are drawn only where the face is)
				for Q in _split_runs(run, h, e, 0.32, 0.12, 9, a): poly(Q, col("faceW", 0.45))
				for j in n:
					var r := hh(run[j][2] * 6.1, a + 3)
					if r > 0.42 or (h[j] - 1.4) * e[j] < 0.7: continue
					var hj := (h[j] - 1.4) * e[j]
					var yy: float = run[j][1] + h[j] - hj * (0.62 + 0.3 * r)
					var ww := 2.0 + r * 9.0
					var EL := PackedVector2Array()
					for q in 12:
						var an := q / 12.0 * TAU
						EL.append(Vector2(run[j][0] + cos(an) * ww, yy + sin(an) * (0.6 + r * 1.6)))
					poly(EL, col("faceL", 0.55))
				for j in n:
					var r4 := hh(run[j][2] * 8.3, a + 4)
					if r4 > 0.15 or (h[j] - 1.4) * e[j] < 0.7: continue
					var top: float = run[j][1] + h[j] - (h[j] - 1.4) * e[j]
					var rx: float = run[j][0] + (r4 - 0.2) * 4.0
					stroke(PackedVector2Array([Vector2(rx, top + 0.8 + r4 * 2.0), Vector2(rx + 0.4, run[j][1] + h[j] + 0.3)]), col("faceW", 0.3), 0.6)
				for j in range(0, n, 2):
					var r3 := hh(run[j][2] * 5.1, 1)
					if h[j] < 3.5 or r3 > 0.4 or (h[j] - 1.4) * e[j] < 0.7: continue
					var qx: float = run[j][0]
					var qy: float = run[j][1]
					stroke(_qcurve(Vector2(qx, qy), Vector2(qx + 1.5, qy + h[j] * 0.5), Vector2(qx + (r3 - 0.2) * 10.0, qy + h[j] - 0.5)), col("root"), 0.7)
				# silt laid down flood after flood: thin uneven layers of paler and darker earth along the face, and root
				# hairs hanging from the sod at its top
				for sq in SQ:
					var Qt: PackedVector2Array = sq[0]
					var Qb: PackedVector2Array = sq[1]
					var x00: float = sq[2]
					var LAY := [[0.22, "faceL", 0.42, 0.9], [0.36, "faceD", 0.22, 0.7], [0.5, "faceL", 0.3, 1.3], [0.63, "faceD", 0.2, 0.6], [0.78, "faceL", 0.22, 0.8]]
					for li in LAY.size():
						var ly: Array = LAY[li]
						var LN := PackedVector2Array()
						for k in Qt.size():
							var xg := x00 + k * ST
							var gap := vn(xg * 1.6 + li * 5.3, a + 30 + li) < 0.3
							var hk: float = Qb[k].y - Qt[k].y
							if gap or hk < 1.6:
								if LN.size() > 1: stroke(LN, col(ly[1], ly[2]), ly[3])
								LN = PackedVector2Array()
								continue
							var f: float = ly[0] + 0.07 * (vn(xg * 2.7 + li, a + 40 + li) - 0.5)
							LN.append(Vector2(Qt[k].x, Qt[k].y + hk * f))
						if LN.size() > 1: stroke(LN, col(ly[1], ly[2]), ly[3])
					for k in Qt.size():
						var xg := x00 + k * ST
						for m in 2:
							var r5 := hh(xg * 7.7 + m * 0.37, a + 50)
							if r5 > 0.45: continue
							var hk: float = Qb[k].y - Qt[k].y
							if hk < 1.2: continue
							var p0 := Vector2(Qt[k].x + (m - 0.5) * 2.4 + (r5 - 0.2) * 2.0, Qt[k].y + 0.3)
							var ln := minf(hk * 0.8, 1.2 + 3.5 * hh(xg * 3.1 + m, a + 51))
							var bd := (hh(xg + m, a + 52) - 0.5) * 2.2
							stroke(_qcurve(p0, p0 + Vector2(bd, ln * 0.5), p0 + Vector2(bd * 0.3, ln)), col("root", 0.7), 0.45 + 0.25 * r5)
				var on2 := false
				var TL := PackedVector2Array()
				for j in n:
					if vn(run[j][2] * 1.4, a + 10) < 0.35 or (h[j] - 1.4) * e[j] < 0.7:
						if TL.size() > 1: stroke(TL, col("faceD", 0.3), 1.1)
						TL = PackedVector2Array()
						continue
					TL.append(Vector2(run[j][0], run[j][1] + h[j] - (h[j] - 1.4) * e[j] + (vn(run[j][2] * 2.3, a + 7) - 0.5) * 1.2 + 0.5))
				if TL.size() > 1: stroke(TL, col("faceD", 0.3), 1.1)
			# grass hanging over the slope's foot
			for j in n - 1:
				for k2 in 3:
					var t := (k2 + 0.5) / 3.0
					var r2 := hh(run[j][2] * 3.7 + k2 * 0.31, 2 + a)
					if r2 > 0.72: continue
					var gx: float = run[j][0] + (run[j + 1][0] - run[j][0]) * t
					var gy: float = run[j][1] + (run[j + 1][1] - run[j][1]) * t - 0.4
					var hb := h[j] * (1.0 - t) + h[j + 1] * t
					var L2 := 1.8 + r2 * minf(hb, 4.5) * (1.6 if r2 < 0.12 else 1.0)
					if hb < 0.6 or k2 != 1: continue
					clp(gx, gy - 1.4, 0.85 + minf(0.5, L2 * 0.07), 2, int(floorf(r2 * 50.0)) & 7)

# the wet band inside a cut face, as separate polygons per unbroken piece of face
func _split_runs(run: Array, h: PackedFloat32Array, e: PackedFloat32Array, f0: float, f1: float, sd: int, a: int) -> Array:
	var out := []
	var top := []
	var bot := []
	var n: int = run.size()
	for j in n + 1:
		var okj := j < n and (h[j] - 1.4) * e[j] >= 0.7
		if not okj:
			if top.size() > 1:
				out.append_array(band(PackedVector2Array(top), PackedVector2Array(bot)))
			top.clear(); bot.clear()
			continue
		top.append(Vector2(run[j][0], run[j][1] + h[j] - (h[j] - 1.4) * e[j] * (f0 + f1 * vn(run[j][2] * 1.9, a + sd))))
		bot.append(Vector2(run[j][0], run[j][1] + h[j] + 0.5))
	return out

static func _qcurve(p0: Vector2, c: Vector2, p1: Vector2) -> PackedVector2Array:
	var P := PackedVector2Array()
	for m in 7:
		var t := m / 6.0
		P.append(p0 * (1 - t) * (1 - t) + c * 2 * t * (1 - t) + p1 * t * t)
	return P

# the near bank: wet earth at the edge, the grass fringe hanging in, grass leaning out over the water
func _near() -> void:
	for a in 2:
		var R := line(a, false, func(x): return EB(a, x, false) + 0.01, func(x): return on(a, x, false))
		for run in R:
			var n: int = run.size()
			var NB := pts_of(run)
			wet(NB, col("faceW"), 2.8)
			fringe(NB, col("slope"), 3.6, 0.9, true)
			var BL := PackedVector2Array()
			for j in n:
				if drop(a, run[j][2], false) > 0.1 or BPf(a, run[j][2], false) < 0.5:
					if BL.size() > 1: stroke(BL, col("band", 0.13), 2.4)
					BL = PackedVector2Array()
					continue
				BL.append(Vector2(run[j][0], run[j][1] - 1.0))
			if BL.size() > 1: stroke(BL, col("band", 0.13), 2.4)
			for j in n - 1:
				if vn(run[j][2] * 0.6, a + 90) < 0.28 or BPf(a, run[j][2], false) < 0.4: continue
				for k2 in 3:
					var t := (k2 + 0.5) / 3.0
					var r := hh(run[j][2] * 4.3 + k2 * 0.37, 5 + a)
					if r > 0.8: continue
					var gx: float = run[j][0] + (run[j + 1][0] - run[j][0]) * t + (r - 0.5) * 3.0
					var gy: float = run[j][1] + (run[j + 1][1] - run[j][1]) * t + 0.6
					var lean := (r - 0.3) * 5.0
					if k2 == 1: clp(gx, gy + 1.2, 1.05 + r * 0.5, 0, int(floorf(r * 50.0)) & 7)

# rows of fishing stakes (đáy) across the river with a net between the last two
const DAY := [[-64, 1], [-38, 0], [14, 1], [44, 0], [146, 1], [170, 0]]
func _stakes() -> void:
	for d in DAY:
		var x: float = d[0] + 0.5
		var nb: bool = d[1] == 1
		var E := Ahw(0, x)
		var row := []
		var cnt := 5 + int(floorf(hh(x, 3) * 3.0))
		for m in cnt:
			var o := E - 0.35 - m * 0.42
			var y := Ac(0, x) + (-1.0 if nb else 1.0) * o * Ak(0, x) + (hh(m, x) - 0.5) * 0.06
			var p := g2s(x + (hh(x, m) - 0.5) * 0.08, y)
			row.append([p.x, p.y, 15.0 + hh(m * 3, x) * 7.0 + (4.0 if m > cnt - 3 else 0.0), o])
		for m in range(row.size() - 1, -1, -1):
			var s: Array = row[m]
			var px: float = s[0]; var py: float = s[1]; var h: float = s[2]
			stroke(PackedVector2Array([Vector2(px, py + 1), Vector2(px + 0.6, py + h * 0.7)]), col("rt", 0.3), 1.6)
			var RG := PackedVector2Array()
			for q in 14:
				var an := q / 14.0 * TAU
				RG.append(Vector2(px + cos(an) * 3.2, py + sin(an) * 1.3))
			stroke(RG, col("ring"), 0.7, M_PLAIN, 1.0, true)
			stroke(PackedVector2Array([Vector2(px, py), Vector2(px - 0.4, py - h)]), col("stkD"), 2.0)
			stroke(PackedVector2Array([Vector2(px - 0.5, py - 1), Vector2(px - 0.9, py - h + 0.6)]), col("stk"), 1.0)
			poly(PackedVector2Array([Vector2(px - 1, py - 2.5 - L * 3), Vector2(px + 1, py - 2.5 - L * 3), Vector2(px + 1, py), Vector2(px - 1, py)]), col("wetD"))
		if row.size() > 2:
			var a: Array = row[row.size() - 1]
			var b: Array = row[row.size() - 2]
			for m in 5:
				var t := m / 4.0
				var px: float = a[0] + (b[0] - a[0]) * t
				var py: float = a[1] + (b[1] - a[1]) * t
				stroke(_qcurve(Vector2(px, py - a[2] * 0.55), Vector2(px + 6, py - a[2] * 0.2), Vector2(px + 9, py + 1)), col("net"), 0.6)
			stroke(PackedVector2Array([Vector2(a[0], a[1] - a[2] * 0.55), Vector2(b[0], b[1] - b[2] * 0.55)]), col("net"), 0.6)
