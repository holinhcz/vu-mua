extends RefCounted
# Layer 4 rules, ported from the game's AOW (ponds, canal, ditches): from the pond fields (shore F, depth D) work out
# the outline, then what grows on it, exactly by the game's rules: reed stands along the rim (CLP pictures) and mats of
# water hyacinth (lục bình) with duckweed (bèo) in the sheltered spots. Output: lists of pictures to draw.
# Every item: [picture name, x, y, scale x (negative = mirrored), scale y].

var F := PackedFloat32Array()
var D := PackedFloat32Array()
var NH := PackedByteArray()      # 1 = near a hill (per field sample)
var WILD := PackedByteArray()    # per box tile
var BUSY := PackedByteArray()
var X0 := 0.0
var Y0 := 0.0
var NX := 0
var NY := 0
var S := 4.0
var ki := 0.0
var hi := 0.0
var meta := {}                   # picture name -> [dx, dy, dw, dh]
var dbg := {}
var mats_n := 0

static func hh(x: float, y: float) -> float:
	var n := sin(x * 127.1 + y * 311.7) * 43758.5453
	return n - floorf(n)

static func hv(a: float) -> float:
	var n := sin(a * 91.7 + 3.1) * 43758.5453
	return n - floorf(n)

static func vn(x: float, y: float) -> float:
	var ix := floorf(x)
	var iy := floorf(y)
	var fx := x - ix
	var fy := y - iy
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	var a := hh(ix, iy)
	var b := hh(ix + 1.0, iy)
	var c := hh(ix, iy + 1.0)
	var d := hh(ix + 1.0, iy + 1.0)
	return a + (b - a) * fx + (c - a) * fy + (a - b - c + d) * fx * fy

static func sst(a: float, b: float, x: float) -> float:
	var t := clampf((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

func g2s(gx: float, gy: float) -> Vector2:
	return Vector2(ki + (gx - gy) * 32.0, hi + (gx + gy) * 16.0)

func s2g(X: float, Y: float) -> Vector2:
	var a := (X - ki) / 32.0
	var b := (Y - hi) / 16.0
	return Vector2((a + b) / 2.0, (b - a) / 2.0)

func scr(su: float, sv: float) -> Vector2:
	return g2s(X0 + (su + 0.5) / S, Y0 + (sv + 0.5) / S)

# a field's value at a spot in tiles (bilinear), 0 outside the box
func fa(f: PackedFloat32Array, gx: float, gy: float) -> float:
	var u := (gx - X0) * S - 0.5
	var v := (gy - Y0) * S - 0.5
	var iu := int(floorf(u))
	var iv := int(floorf(v))
	if iu < 0 or iv < 0 or iu >= NX - 1 or iv >= NY - 1:
		return 0.0
	var a := u - iu
	var b := v - iv
	var q := iv * NX + iu
	return f[q] * (1 - a) * (1 - b) + f[q + 1] * a * (1 - b) + f[q + NX] * (1 - a) * b + f[q + NX + 1] * a * b

func fs(f: PackedFloat32Array, X: float, Y: float) -> float:
	var g := s2g(X, Y)
	return fa(f, g.x, g.y)

func near_hill(X: float, Y: float) -> bool:
	var g := s2g(X, Y)
	var u := int(roundf((g.x - X0) * S - 0.5))
	var v := int(roundf((g.y - Y0) * S - 0.5))
	if u < 0 or v < 0 or u >= NX or v >= NY or NH.size() == 0:
		return false
	return NH[v * NX + u] == 1

func tile_flag(a: PackedByteArray, tx: int, ty: int) -> bool:
	var W := int(NX / S)
	var x := tx - int(X0)
	var y := ty - int(Y0)
	if x < 0 or y < 0 or x >= W or y >= int(NY / S) or a.size() == 0:
		return false
	return a[y * W + x] == 1

# the outline at threshold th: marching squares, joined into loops, one round of corner cutting (AOW march)
func march(f: PackedFloat32Array, th: float) -> Array:
	var pts := {}
	var adj := {}
	var segs := []
	var ep := func(id: int, su: float, sv: float) -> int:
		if not pts.has(id):
			pts[id] = scr(su, sv)
		return id
	var add := func(a: int, b: int) -> void:
		segs.append([a, b])
		var k := segs.size() - 1
		if not adj.has(a): adj[a] = []
		if not adj.has(b): adj[b] = []
		adj[a].append(k)
		adj[b].append(k)
	for v in NY - 1:
		for u in NX - 1:
			var c0 := f[v * NX + u]
			var c1 := f[v * NX + u + 1]
			var c2 := f[(v + 1) * NX + u + 1]
			var c3 := f[(v + 1) * NX + u]
			var cs := (1 if c0 > th else 0) | (2 if c1 > th else 0) | (4 if c2 > th else 0) | (8 if c3 > th else 0)
			if cs == 0 or cs == 15:
				continue
			var hT := (v * NX + u) * 2
			var hB := ((v + 1) * NX + u) * 2
			var vL := (v * NX + u) * 2 + 1
			var vR := (v * NX + u + 1) * 2 + 1
			var T := func() -> int: return ep.call(hT, u + (th - c0) / (c1 - c0), v)
			var R := func() -> int: return ep.call(vR, u + 1, v + (th - c1) / (c2 - c1))
			var B := func() -> int: return ep.call(hB, u + (th - c3) / (c2 - c3), v + 1)
			var L := func() -> int: return ep.call(vL, u, v + (th - c0) / (c3 - c0))
			var mid := (c0 + c1 + c2 + c3) / 4.0 > th
			match cs:
				1: add.call(L.call(), T.call())
				2: add.call(T.call(), R.call())
				3: add.call(L.call(), R.call())
				4: add.call(R.call(), B.call())
				5:
					if mid:
						add.call(T.call(), R.call()); add.call(B.call(), L.call())
					else:
						add.call(L.call(), T.call()); add.call(R.call(), B.call())
				6: add.call(T.call(), B.call())
				7: add.call(L.call(), B.call())
				8: add.call(B.call(), L.call())
				9: add.call(T.call(), B.call())
				10:
					if mid:
						add.call(L.call(), T.call()); add.call(R.call(), B.call())
					else:
						add.call(T.call(), R.call()); add.call(B.call(), L.call())
				11: add.call(R.call(), B.call())
				12: add.call(L.call(), R.call())
				13: add.call(T.call(), R.call())
				14: add.call(L.call(), T.call())
	var used := PackedByteArray()
	used.resize(segs.size())
	var out := []
	for s0 in segs.size():
		if used[s0]:
			continue
		var lp := PackedVector2Array()
		var cur := s0
		var at0: int = segs[s0][0]
		var st := at0
		for gg in 200000:
			used[cur] = 1
			lp.append(pts[at0])
			at0 = segs[cur][1] if segs[cur][0] == at0 else segs[cur][0]
			if at0 == st:
				break
			var nn := -1
			for q in adj[at0]:
				if not used[q]:
					nn = q
					break
			if nn < 0:
				break
			cur = nn
		if lp.size() > 4:
			out.append(lp)
	var res := []
	for p in out:
		var r := PackedVector2Array()
		var n: int = p.size()
		for j in n:
			var a: Vector2 = p[j]
			var b: Vector2 = p[(j + 1) % n]
			r.append(a * 0.75 + b * 0.25)
			r.append(a * 0.25 + b * 0.75)
		res.append(r)
	return res

# returns {"items": [...]}: the mats. (n17) Every bank plant (grass over the far face, grass leaning out from the near
# bank, the odd lau or flower pair) comes with the river's bank drawing (pondriver.gd, the river's clp rule), so the
# ponds' banks grow what the river's banks grow
func build() -> Dictionary:
	var out := []
	_mats(out)
	return {"items": out}

# water hyacinth drifts into mats in the sheltered places: corners, narrow arms, the canal's bends (AOW mats)
func _mats(out: Array) -> void:
	var cand := []
	var gy := Y0 + 0.25
	var nC := 0
	for ty in int(NY / S):
		for tx in int(NX / S):
			if fa(F, X0 + tx + 0.5, Y0 + ty + 0.5) > 0.5: nC += 1
	while gy < Y0 + NY / S:
		var gx := X0 + 0.25
		while gx < X0 + NX / S:
			var jx := gx + (hh(gx, gy) - 0.5) * 0.3
			var jy := gy + (hh(gy + 3.3, gx) - 0.5) * 0.3
			var f := fa(F, jx, jy)
			# (n15) on the far bank the mats float a little way out, so the earth face shows above them
			var farb := fa(F, jx + 0.12, jy + 0.12) - fa(F, jx - 0.12, jy - 0.12) > 0.004
			if f >= (0.76 if farb else 0.6) and f <= 0.9:
				cand.append([(1.0 - fa(D, jx, jy)) * 0.8 + vn(jx * 0.37 + 3.3, jy * 0.37 + 7.1) * 0.6, jx, jy, cand.size()])
			gx += 0.5
		gy += 0.5
	cand.sort_custom(func(a, b): return a[0] > b[0] or (a[0] == b[0] and a[3] < b[3]))
	var maxM := int(roundf(nC / 14.0)) + 1   # a few big mats drifted into the sheltered corners, not a string of small ones
	var mt := []
	for c in cand:
		if mt.size() >= maxM: break
		var okm := true
		for o in mt:
			if (o.x - c[1]) * (o.x - c[1]) + (o.y - c[2]) * (o.y - c[2]) < 5.0 * 5.0:
				okm = false
				break
		if okm: mt.append(Vector2(c[1], c[2]))
	var mt2 := []
	for o in mt:
		if (o.x + 7.9) * (o.x + 7.9) + (o.y + 19.1) * (o.y + 19.1) > 6.8: mt2.append(o)
	mats_n = mt2.size()
	dbg["mats"] = mt2
	for idx in mt2.size():
		var o: Vector2 = mt2[idx]
		var ex := fa(F, o.x + 0.12, o.y) - fa(F, o.x - 0.12, o.y)
		var ey := fa(F, o.x, o.y + 0.12) - fa(F, o.x, o.y - 0.12)
		var el := sqrt(ex * ex + ey * ey)
		if el == 0.0: el = 1.0
		var tx := -ey / el
		var ty := ex / el
		var nx := ex / el
		var ny := ey / el
		var La := 1.0 + hh(o.x * 3.1, o.y * 1.7) * 0.8
		var Lb := 0.5 + hh(o.y * 2.3, o.x * 1.1) * 0.3
		var ros := []
		var v := -1.0
		while v <= 1.001:
			var u := -1.0
			while u <= 1.001:
				var rr := sqrt(u * u + v * v)
				var wob := 1.0 + 0.32 * (vn(o.x * 4.0 + u * 2.0, o.y * 4.0 + v * 2.0) - 0.5) * 2.0
				if rr <= wob:
					var px := o.x + u * La * tx + v * Lb * nx + (hh(u * 7.0 + o.x, v * 5.0) - 0.5) * 0.09
					var py := o.y + u * La * ty + v * Lb * ny + (hh(v * 7.0, u * 5.0 + o.y) - 0.5) * 0.09
					if fa(F, px, py) >= 0.57:
						var sp := g2s(px, py)
						ros.append([sp.x, sp.y, (1.0 - 0.28 * rr) * (0.85 + hh(px * 3.3, py * 2.1) * 0.35), hh(px * 1.9, py * 4.1) < 0.2, Vector2i(int(floorf(px)), int(floorf(py))), rr / wob, hh(py * 5.7, px * 2.3)])
				u += 0.15 / La
			v += 0.15 / Lb
		for u4 in 4:
			var an := hh(o.x + u4, o.y - u4) * 6.283
			var dd := 1.3 + hh(u4, o.x) * 0.6
			var px2 := o.x + cos(an) * La * dd * tx + sin(an) * Lb * dd * nx
			var py2 := o.y + cos(an) * La * dd * ty + sin(an) * Lb * dd * ny
			if fa(F, px2, py2) < 0.6: continue
			var sp2 := g2s(px2, py2)
			ros.append([sp2.x, sp2.y, 0.75 + hh(px2, py2) * 0.3, false, Vector2i(int(floorf(px2)), int(floorf(py2))), 1.0, hh(py2, px2)])
		for q in ros.size(): ros[q].append(q)
		ros.sort_custom(func(a, b): return a[1] < b[1] or (a[1] == b[1] and a[7] < b[7]))
		# a film of duckweed beside the mat, drawn first
		var sg := 1.0 if idx % 2 else -1.0
		var bx := o.x + tx * La * 1.25 * sg
		var by := o.y + ty * La * 1.25 * sg
		if false:   # (n15) the duckweed film read as a flat sticker on the water: off
			for k in 9:
				var a := hh(bx + k, by) * 6.283
				var r2 := hh(by, bx + k) * 0.5
				var qx := bx + cos(a) * r2
				var qy := by + sin(a) * r2 * 0.7
				if fa(F, qx, qy) < 0.6: continue
				var s3 := g2s(qx, qy)
				var nm := "beo" + str(int(floorf(hv(s3.x * 0.37 + s3.y) * 4.0)) % 4)
				var w: float = meta[nm][2]
				var sc := (7.0 + hh(qx, k) * 7.0) * 2.3 / w
				out.append([nm, s3.x, s3.y, -sc if hv(s3.y) < 0.5 else sc, sc])
		var wd := tile_flag(WILD, int(floorf(o.x)), int(floorf(o.y)))
		var lim := 1.01 if wd else 0.85
		for r in ros:
			if r[5] > lim or tile_flag(BUSY, r[4].x, r[4].y): continue
			var sd: float = r[6]
			var nm2 := ("lbf" + str(int(floorf(sd * 3.0)) % 3)) if r[3] else ("lb" + str(int(floorf(sd * 6.0)) % 6))
			var k2: float = r[2] * 1.05 * 1.35
			out.append([nm2, r[0], r[1], -k2 if hv(sd) < 0.5 else k2, k2])

# (n17) the shore as smooth lines for the river's bank drawing (pondriver.gd): the outline smoothed hard (corner
# cutting, relaxed at 2 px), then one point every SP px (the river's grid step along its banks). Every point: where
# it is, the way into the water (n), whether a bank is drawn there (k: none right under the cliff, where the fall's
# pool meets the rock), and how wide the water is straight out from it (wd, so a brook's face never fills it).
static func _chaikin(p: PackedVector2Array) -> PackedVector2Array:
	var r := PackedVector2Array()
	var n := p.size()
	for j in n:
		var a := p[j]; var b := p[(j + 1) % n]
		r.append(a * 0.75 + b * 0.25); r.append(a * 0.25 + b * 0.75)
	return r
static func _even(p: PackedVector2Array, st: float) -> PackedVector2Array:
	var r := PackedVector2Array()
	var n := p.size()
	var acc := 0.0
	r.append(p[0])
	for j in n:
		var a := p[j]; var b := p[(j + 1) % n]
		var L := a.distance_to(b)
		var t := st - acc
		while t <= L:
			r.append(a.lerp(b, t / L))
			t += st
		acc = L - (t - st)
	if r.size() > 1 and r[r.size() - 1].distance_to(r[0]) < st * 0.5:
		r.remove_at(r.size() - 1)
	return r
static func _avg(v: PackedFloat32Array, k: int) -> PackedFloat32Array:
	var n := v.size()
	var r := PackedFloat32Array(); r.resize(n)
	for j in n:
		var s := 0.0
		for m in range(-k, k + 1):
			s += v[(j + m + n) % n]
		r[j] = s / (2 * k + 1)
	return r
func banks(SP: float) -> Array:
	var out := []
	for p0 in march(F, 0.5):
		if p0.size() < 6: continue
		var p: PackedVector2Array = _even(_chaikin(_chaikin(p0)), 2.0)
		if p.size() < 8: continue
		for it in 10:
			var q := p.duplicate()
			var m := p.size()
			for j in m:
				q[j] = p[j] * 0.5 + (p[(j - 1 + m) % m] + p[(j + 1) % m]) * 0.25
			p = q
		p = _even(p, SP)
		var n := p.size()
		if n < 5: continue
		var nx := PackedVector2Array(); nx.resize(n)
		var kk := PackedFloat32Array(); kk.resize(n)
		var wd := PackedFloat32Array(); wd.resize(n)
		var sgn := 0.0
		for j in n:
			var t := (p[(j + 1) % n] - p[(j - 1 + n) % n]).normalized()
			var nv := Vector2(-t.y, t.x)
			sgn += 1.0 if fs(F, p[j].x + nv.x * 3, p[j].y + nv.y * 3) > fs(F, p[j].x - nv.x * 3, p[j].y - nv.y * 3) else -1.0
			nx[j] = nv
		if sgn < 0.0:
			for j in n: nx[j] = -nx[j]
		for j in n:
			# (n17b) under the fall only the edge against the cliff (water below it) and the spring up on the top have no bank;
			# the pool's sides and its lower shore get the bank like everywhere else
			var fallz := absf(p[j].x - 4624.0) < 105.0 and p[j].y < 549.0
			kk[j] = 0.0 if (fallz and (p[j].y < 400.0 or nx[j].y > 0.3)) else 1.0
			var d := 2.0
			while d < 80.0 and fs(F, p[j].x + nx[j].x * d, p[j].y + nx[j].y * d) > 0.5: d += 2.0
			wd[j] = d
		out.append({"p": p, "n": nx, "k": kk, "wd": wd})
	return out
