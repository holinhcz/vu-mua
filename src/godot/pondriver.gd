extends "res://songgen.gd"
# (n17, Link "làm như bờ ở sông") The banks of the ponds, the canal and the brook, drawn the way songgen.gd draws the
# river's banks: the same draw ops, the same colours (song.json), the same detail textures (bank.gdshader: grass,
# cut face, mud, grass edge, ragged edge, glints) and the same plant rule (clp). main.gd draws them with BankPics.
# The shore loops come from pondgen.banks(SP): smooth, one point every SP px, which is the river's grid step along its
# banks (ST 0.2 of a grid unit of ~36 px), so every per-point rule of the river keeps its spacing. xg is the distance
# along the shore in grid units: the river's noise and hashes take it where they take the grid x.
#   far bank (water below on screen): grass lip, the slope (grass texture) with its fringe, the earth face hanging into
#   the water with its wet foot and glints, the cut face where the bank is steep (wet band, pale patches, cracks,
#   roots, silt layers, root hairs, a dark top line), grass hanging over the slope's foot;
#   near bank and the side banks: grass lip, the wet edge, the grass fringe hanging in, a faint band on the water,
#   grass leaning out.
const SP := 7.2
const GU := 36.0

var P := PackedVector2Array()     # the loop being drawn
var N := PackedVector2Array()     # into the water
var D := PackedVector2Array()     # the way the far bank's face hangs (straight down; leaning out on a side bank)
var TG := PackedVector2Array()    # along the face (D turned)
var XG := PackedFloat32Array()

func at(j: int, d: float, t: float = 0.0) -> Vector2: return P[j] + D[j] * d + TG[j] * t

# runs of loop indices where ok[j] holds (a loop that holds everywhere comes back closed: first index again at the end)
static func _runs(ok: Array) -> Array:
	var n := ok.size()
	var s0 := -1
	for j in n:
		if not ok[j]:
			s0 = j
			break
	if s0 < 0:
		var all := []
		for j in n + 1: all.append(j % n)
		return [all]
	var out := []
	var cur := []
	for m in range(1, n + 1):
		var j := (s0 + m) % n
		if ok[j]:
			cur.append(j)
		else:
			if cur.size() > 1: out.append(cur)
			cur = []
	if cur.size() > 1: out.append(cur)
	return out

func build_ponds(loops: Array) -> void:
	ops.clear(); plants.clear()
	var jobs := []
	for li in loops.size():
		var L: Dictionary = loops[li]
		var p: PackedVector2Array = L["p"]
		var nv: PackedVector2Array = L["n"]
		var kk: PackedFloat32Array = L["k"]
		var wd: PackedFloat32Array = L["wd"]
		var n := p.size()
		var x0 := li * 97.3
		var xg := PackedFloat32Array(); xg.resize(n)
		var fr := PackedFloat32Array(); fr.resize(n)
		var dd := PackedVector2Array(); dd.resize(n)
		var tg := PackedVector2Array(); tg.resize(n)
		for j in n:
			xg[j] = x0 + j * SP / GU
			fr[j] = sst(0.25, 0.75, nv[j].y)
		var fr2 := PackedFloat32Array(); fr2.resize(n)
		for j in n:
			fr2[j] = (fr[(j - 2 + n) % n] + 2.0 * fr[(j - 1 + n) % n] + 3.0 * fr[j] + 2.0 * fr[(j + 1) % n] + fr[(j + 2) % n]) / 9.0
		for j in n:
			var d0 := nv[j].lerp(Vector2(0, 1), sst(0.2, 0.75, nv[j].y)).normalized()
			dd[j] = d0
			tg[j] = Vector2(d0.y, -d0.x)
		jobs.append({"p": p, "n": nv, "k": kk, "wd": wd, "xg": xg, "fr": fr2, "d": dd, "t": tg, "i": li})
	# the grass lip all round, see-through, with the grass texture (river: build())
	var LP := []
	for J in jobs:
		_use(J)
		var kk: PackedFloat32Array = J["k"]
		var ok := []
		for j in P.size(): ok.append(kk[j] > 0.5)
		for run in _runs(ok):
			var A := PackedVector2Array(); var B := PackedVector2Array()
			for j in run:
				var w := (0.08 + 0.26 * vn(XG[j] * 0.7, J["i"] + 1)) * GU
				A.append(P[j] - N[j] * 0.7)
				B.append(P[j] - N[j] * (0.7 + w))
			LP.append_array(band(A, B))
	polys(LP, col("lip", 0.2))
	polys(LP, col("lip", 0.6), M_CO, 1.0)
	for J in jobs:
		_use(J)
		var kk: PackedFloat32Array = J["k"]
		var fr: PackedFloat32Array = J["fr"]
		var ok := []
		for j in P.size(): ok.append(kk[j] > 0.5 and fr[j] > 0.12)
		for run in _runs(ok): _face(run, J)
	for J in jobs:
		_use(J)
		var kk: PackedFloat32Array = J["k"]
		var fr: PackedFloat32Array = J["fr"]
		var ok := []
		for j in P.size(): ok.append(kk[j] > 0.5 and fr[j] < 0.55)
		for run in _runs(ok): _nearrun(run, J)

func _use(J: Dictionary) -> void:
	P = J["p"]; N = J["n"]; D = J["d"]; TG = J["t"]; XG = J["xg"]

func _line(run: Array, f: Callable) -> PackedVector2Array:
	var Q := PackedVector2Array()
	for j in run: Q.append(f.call(j))
	return Q

# the far bank (river: _faces), along a run of loop indices
func _face(run: Array, J: Dictionary) -> void:
	var a: int = int(J["i"]) & 1
	var fr: PackedFloat32Array = J["fr"]
	var wd: PackedFloat32Array = J["wd"]
	var n: int = run.size()
	var h := PackedFloat32Array(); var e := PackedFloat32Array(); var tpr := PackedFloat32Array()
	for m in n:
		var j: int = run[m]
		var x: float = XG[j]
		# how much the bank is cut (river: the outer side of a bend, about nothing on a straight stretch): a pond's
		# shore is low all round, cut only here and there
		var o := 0.55 * sst(0.5, 0.9, vn(x * 0.33 + 4.0, 21))
		var sd := a * 4
		# a brook keeps most of its water clear: the face is never more than about a third of the way across
		var cap := clampf(wd[j] * 0.3, 2.0, 99.0)
		# (n17b) the face grows from nothing where the far bank turns into a side bank (was cut off square there)
		var tp := sst(0.12, 0.5, fr[j])
		tpr.append(tp)
		h.append(minf(((1.8 + 2.2 * vn(x * 0.8 + sd, 3)) + 5.5 * pow(o, 0.9)) * fr[j] * tp, cap))
		e.append(sst(0.22, 0.5, o) * sst(0.3, 0.62, vn(x * 0.37 + sd, 8) + 0.3 * o))
	var FB := PackedVector2Array(); var FT := PackedVector2Array()
	for m in n:
		var j: int = run[m]
		FB.append(at(j, h[m]))
		FT.append(at(j, -0.3))
	polys(band(FT, FB), col("slope"))
	polys(band(FT, FB), col("slope"), M_CO, 0.85)
	for m in n: FT[m] = at(run[m], 0.0)
	fringe(FT, col("slope"), 2.6, 0.8)
	var CT := PackedVector2Array(); var CW := PackedVector2Array()
	for m in n:
		var j: int = run[m]
		CT.append(at(j, (h[m] - 1.8) * tpr[m]))
		CW.append(at(j, h[m] + (2.0 + 4.0 * vn(XG[j] * 1.3 + a * 7, 15)) * clampf(wd[j] / 24.0, 0.4, 1.0) * tpr[m]))
	polys(band(CT, CW), col("face"))
	polys(band(CT, CW), col("face"), M_VACH, 1.0)
	wet(CW, col("faceW"), 3.6)
	glint(CW, col("shine"), 1.0, 0.8)
	fringe(FB, col("slope"), 4.0, 0.95)
	# the cut face: where the bank is steep, bare earth with a wet band, pale dry patches, cracks, roots
	var seg := []
	var E := []
	var SQ := []
	var fl := func():
		if seg.size() > 1:
			var Qt := PackedVector2Array(); var Qb := PackedVector2Array()
			for k in seg.size():
				var tq := minf(1.0, minf(k, seg.size() - 1 - k) / 2.5)
				Qt.append(seg[k][1] + (seg[k][0] - seg[k][1]) * tq)
				Qb.append(seg[k][1])
			E.append_array(band(Qt, Qb))
			SQ.append([Qt, Qb, seg[0][2]])
		seg.clear()
	for m in n:
		var j: int = run[m]
		var hE := (h[m] - 1.4) * e[m]
		if hE < 0.7:
			fl.call()
			continue
		seg.append([at(j, h[m] - hE + (vn(XG[j] * 2.3, a + 7) - 0.5) * 1.2), at(j, h[m] + 0.2), XG[j]])
	fl.call()
	if E.size() > 0:
		polys(E, col("face"))
		polys(E, col("face"), M_VACH, 1.0)
		# the wet band inside the cut face, per unbroken piece
		var top := PackedVector2Array(); var bot := PackedVector2Array()
		for m in n + 1:
			var okm := m < n and (h[m] - 1.4) * e[m] >= 0.7
			if not okm:
				if top.size() > 1:
					for Q in band(top, bot): poly(Q, col("faceW", 0.45))
				top = PackedVector2Array(); bot = PackedVector2Array()
				continue
			var j: int = run[m]
			top.append(at(j, h[m] - (h[m] - 1.4) * e[m] * (0.32 + 0.12 * vn(XG[j] * 1.9, a + 9))))
			bot.append(at(j, h[m] + 0.5))
		for m in n:
			var j: int = run[m]
			var r := hh(XG[j] * 6.1, a + 3)
			if r > 0.42 or (h[m] - 1.4) * e[m] < 0.7: continue
			var hj := (h[m] - 1.4) * e[m]
			var yy := h[m] - hj * (0.62 + 0.3 * r)
			var ww := 2.0 + r * 9.0
			var EL := PackedVector2Array()
			for q in 12:
				var an := q / 12.0 * TAU
				EL.append(at(j, yy + sin(an) * (0.6 + r * 1.6), cos(an) * ww))
			poly(EL, col("faceL", 0.55))
		for m in n:
			var j: int = run[m]
			var r4 := hh(XG[j] * 8.3, a + 4)
			if r4 > 0.15 or (h[m] - 1.4) * e[m] < 0.7: continue
			var tp := h[m] - (h[m] - 1.4) * e[m]
			var rx := (r4 - 0.2) * 4.0
			stroke(PackedVector2Array([at(j, tp + 0.8 + r4 * 2.0, rx), at(j, h[m] + 0.3, rx + 0.4)]), col("faceW", 0.3), 0.6)
		for m in range(0, n, 2):
			var j: int = run[m]
			var r3 := hh(XG[j] * 5.1, 1)
			if h[m] < 3.5 or r3 > 0.4 or (h[m] - 1.4) * e[m] < 0.7: continue
			stroke(_qcurve(at(j, 0.0), at(j, h[m] * 0.5, 1.5), at(j, h[m] - 0.5, (r3 - 0.2) * 10.0)), col("root"), 0.7)
		# silt laid down layer after layer, and root hairs hanging from the sod at the top
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
					var hk: float = Qb[k].distance_to(Qt[k])
					if gap or hk < 1.6:
						if LN.size() > 1: stroke(LN, col(ly[1], ly[2]), ly[3])
						LN = PackedVector2Array()
						continue
					var f: float = ly[0] + 0.07 * (vn(xg * 2.7 + li, a + 40 + li) - 0.5)
					LN.append(Qt[k].lerp(Qb[k], f))
				if LN.size() > 1: stroke(LN, col(ly[1], ly[2]), ly[3])
			for k in Qt.size():
				var xg := x00 + k * ST
				var dv := (Qb[k] - Qt[k]).normalized()
				var tv := Vector2(dv.y, -dv.x)
				for m2 in 2:
					var r5 := hh(xg * 7.7 + m2 * 0.37, a + 50)
					if r5 > 0.45: continue
					var hk: float = Qb[k].distance_to(Qt[k])
					if hk < 1.2: continue
					var p0 := Qt[k] + tv * ((m2 - 0.5) * 2.4 + (r5 - 0.2) * 2.0) + dv * 0.3
					var ln := minf(hk * 0.8, 1.2 + 3.5 * hh(xg * 3.1 + m2, a + 51))
					var bd := (hh(xg + m2, a + 52) - 0.5) * 2.2
					stroke(_qcurve(p0, p0 + tv * bd + dv * ln * 0.5, p0 + tv * bd * 0.3 + dv * ln), col("root", 0.7), 0.45 + 0.25 * r5)
		var TL := PackedVector2Array()
		for m in n:
			var j: int = run[m]
			if vn(XG[j] * 1.4, a + 10) < 0.35 or (h[m] - 1.4) * e[m] < 0.7:
				if TL.size() > 1: stroke(TL, col("faceD", 0.3), 1.1)
				TL = PackedVector2Array()
				continue
			TL.append(at(j, h[m] - (h[m] - 1.4) * e[m] + (vn(XG[j] * 2.3, a + 7) - 0.5) * 1.2 + 0.5))
		if TL.size() > 1: stroke(TL, col("faceD", 0.3), 1.1)
	# grass hanging over the slope's foot (the river's rule: one a step)
	for m in n - 1:
		var j: int = run[m]
		var j1: int = run[m + 1]
		var r2 := hh(XG[j] * 3.7 + 0.31, 2 + a)
		if r2 > 0.72: continue
		var g := P[j].lerp(P[j1], 0.5) - D[j] * 0.4
		var hb := (h[m] + h[m + 1]) * 0.5
		var L2 := 1.8 + r2 * minf(hb, 4.5) * (1.6 if r2 < 0.12 else 1.0)
		if hb < 0.6: continue
		clp(g.x, g.y - 1.4, 0.85 + minf(0.5, L2 * 0.07), 2, int(floorf(r2 * 50.0)) & 7)

# the near bank and the side banks (river: _near)
func _nearrun(run: Array, J: Dictionary) -> void:
	var a: int = int(J["i"]) & 1
	var fr: PackedFloat32Array = J["fr"]
	var n: int = run.size()
	var NB := _line(run, func(j): return P[j])
	wet(NB, col("faceW"), 2.8)
	fringe(NB, col("slope"), 3.6, 0.9, true)
	var BL := PackedVector2Array()
	for m in n:
		var j: int = run[m]
		if fr[j] > 0.3:
			if BL.size() > 1: stroke(BL, col("band", 0.13), 2.4)
			BL = PackedVector2Array()
			continue
		BL.append(P[j] + N[j] * 1.0)
	if BL.size() > 1: stroke(BL, col("band", 0.13), 2.4)
	# grass leaning out (the river's rule)
	for m in n - 1:
		var j: int = run[m]
		var j1: int = run[m + 1]
		if vn(XG[j] * 0.6, a + 90) < 0.28: continue
		var r := hh(XG[j] * 4.3 + 0.37, 5 + a)
		if r > 0.8: continue
		var g := P[j].lerp(P[j1], 0.5) + (P[j1] - P[j]).normalized() * (r - 0.5) * 3.0 - N[j] * 1.8
		clp(g.x, g.y, 1.05 + r * 0.5, 0, int(floorf(r * 50.0)) & 7)
