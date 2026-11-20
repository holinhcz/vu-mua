extends RefCounted
# XẾP TRÁI: hiệu ứng trên bàn (05_fx.js): miếng trái văng, trái bị hút vô ô đặc biệt, chữ điểm bay,
# và mấy con thú làm việc (trâu cày, heo ụp, vịt bay, gà gáy, hạt thóc, cuốc, trứng bay, tia sáng).

const A := preload("res://logic/xt/xt_art.gd")

var g
var P: Array = []    # miếng trái, trái bị hút
var T: Array = []    # chữ điểm
var Ac: Array = []   # thú / diễn viên
var shake_v := 0.0

func _init(game) -> void:
	g = game

func sx(x: float) -> float:
	return g.sx(x)
func sy(y: float) -> float:
	return g.sy(y)

func shake(a: float) -> void:
	shake_v = maxf(shake_v, a)

func busy() -> bool:
	return Ac.size() > 0

func reset() -> void:
	P.clear()
	T.clear()
	Ac.clear()
	shake_v = 0.0

static func rnd(a: float, b: float) -> float:
	return a + randf() * (b - a)

func juice(x: int, y: int, k: int, big: bool) -> void:
	var X := sx(x)
	var Y := sy(y)
	var S: float = g.LAY.S
	g.later(0.07, func():
		g.gfx.juice(X, Y, k, S, big)
		var n := (5 if big else 4) + (1 if g.B.cascade > 2 else 0)
		var a0 := randf() * TAU
		for i in n:
			var a := a0 + float(i) / n * TAU + rnd(-0.3, 0.3)
			var v := S * rnd(1.8, 3.2)
			var vv := (i % 2) if (k == 2 or k == 5) else (1 if i % 3 == 2 else 0)
			P.append({"type": "piece", "k": k, "v": vv, "x": X + cos(a) * S * 0.12, "y": Y + sin(a) * S * 0.12, "vx": cos(a) * v, "vy": sin(a) * v * 0.6 - S * rnd(2.4, 3.8),
				"g": S * 13, "drag": 0.6, "life": rnd(0.55, 0.75), "t": 0.0, "s": rnd(1.05, 1.4), "rot": randf() * TAU, "vr": rnd(-14, 14)}))

func gather(cells: Array, at: Vector2i, k: int) -> void:
	for c in cells:
		if c == at:
			continue
		P.append({"type": "suck", "k": k, "x": sx(c.x), "y": sy(c.y), "tx": sx(at.x), "ty": sy(at.y), "life": 0.16, "t": 0.0, "vx": 0.0, "vy": 0.0, "g": 0.0, "drag": 0.0, "rot": 0.0, "vr": 0.0})

func make(x: int, y: int, sp: String) -> void:
	g.gfx.make(sx(x), sy(y), g.LAY.S, sp)
func ring(x: float, y: float, r: float, col: Color) -> void:
	g.gfx.shock(sx(x), sy(y), r * g.LAY.S, col)
func hay(x: int, y: int, _hp: int) -> void:
	g.gfx.straw(sx(x), sy(y), g.LAY.S)
func mud(x: int, y: int, _hp: int) -> void:
	g.gfx.mud(sx(x), sy(y), g.LAY.S)
	g.snd.play("mud")
func vine(x: int, y: int) -> void:
	g.gfx.leaves(sx(x), sy(y), g.LAY.S)

func sum_text(key: String, v: int, x: float, y: float, col: Color) -> void:
	for p in T:
		if p.get("key", "") == key and p.t < 0.55:
			p.sum += v
			p.txt = "+" + str(p.sum)
			p.t = minf(p.t, 0.12)
			return
	text("+" + str(v), x, y, col)
	var q: Dictionary = T[T.size() - 1]
	q.key = key
	q.sum = v

func text(txt: String, x, y, col = null) -> void:
	var X := sx(x)
	var Y := sy(y)
	var S: float = g.LAY.S
	for n in 6:
		var hitp = null
		for p in T:
			if p.t < 0.5 and absf(p.x - X) < S * 1.4 and absf(p.y - Y) < S * 0.45:
				hitp = p
				break
		if hitp == null:
			break
		Y = hitp.y - S * 0.5
	T.append({"txt": txt, "x": X, "y": Y, "t": 0.0, "life": 0.9, "col": col if col is Color else Color("#fff8e6")})

# ---- diễn viên: bàn còn bận tới khi xong
func buffalo(x: int, y: int, dir: String, sgn: int) -> void:
	var N: int = g.B.W if dir == "h" else g.B.H
	Ac.append({"type": "trau", "dir": dir, "sgn": sgn, "x": x, "y": y, "t": 0.0, "dur": 0.12 + N * 0.055 + 0.25, "N": N})
func pig(x: int, y: int, R: int, sq: bool) -> void:
	Ac.append({"type": "heo", "x": x, "y": y, "t": 0.0, "dur": 0.75, "R": R, "sq": sq})
func duck(x: int, y: int, tx: int, ty: int, dur: float, carry) -> void:
	Ac.append({"type": "vit", "x": x, "y": y, "tx": tx, "ty": ty, "t": 0.0, "dur": dur, "carry": carry})
func crow(x: int, y: int) -> void:
	Ac.append({"type": "ga", "x": x, "y": y, "t": 0.0, "dur": 1.0})
func beam(x: int, y: int, tx: int, ty: int, delay: float) -> void:
	Ac.append({"type": "beam", "x": x, "y": y, "tx": tx, "ty": ty, "t": -delay + 0.3, "dur": 0.35})
func hoe(x: int, y: int) -> void:
	Ac.append({"type": "hoe", "x": x, "y": y, "t": 0.0, "dur": 0.5})
func egg_out(_t: Dictionary, x: int, y: int) -> void:
	var tg: Vector2 = g.ui.goal_pos("egg")
	Ac.append({"type": "egg", "x": sx(x), "y": sy(y), "tx": tg.x, "ty": tg.y, "t": 0.0, "dur": 0.7})
func to_tile(t: Dictionary) -> void:
	var s: Vector2 = g.ui.moves_pos()
	Ac.append({"type": "spark", "x": s.x, "y": s.y, "tx": sx(t.x), "ty": sy(t.y), "t": 0.0, "dur": 0.25})

func update(dt: float) -> void:
	shake_v = maxf(0.0, shake_v - dt * 1.6)
	var S: float = g.LAY.S
	for i in range(P.size() - 1, -1, -1):
		var p: Dictionary = P[i]
		p.t += dt
		if p.t >= p.life:
			P.remove_at(i)
			continue
		p.vx *= 1 - p.drag * dt
		p.vy *= 1 - p.drag * dt
		p.vy += p.g * dt
		p.x += p.vx * dt
		p.y += p.vy * dt
		p.rot += p.vr * dt
	for i in range(T.size() - 1, -1, -1):
		var p: Dictionary = T[i]
		p.t += dt
		p.y -= S * 0.9 * dt
		if p.t > p.life:
			T.remove_at(i)
	var G = g.gfx
	for i in range(Ac.size() - 1, -1, -1):
		var a: Dictionary = Ac[i]
		a.t += dt
		if a.type == "trau" and a.t > 0:
			var pos := trau_pos(a)
			var dx: float = a.sgn if a.dir == "h" else 0
			var dy: float = 0 if a.dir == "h" else a.sgn
			if not a.has("sn"):
				a.sn = 1
				G.warp(pos.x, pos.y - S * 0.2, {"r0": S * 0.2, "r1": S * 2.2, "w": S * 0.4, "amp": S * 0.22, "life": 0.45})
				G.snort(pos.x + dx * S * 0.55, pos.y - S * 0.55, S, dx if dx != 0 else (1.0 if randf() < 0.5 else -1.0))
			if randf() < dt * 30:
				G.clods(pos.x - dx * S * 0.3, pos.y - dy * S * 0.3, S, dx, dy)
			if randf() < dt * 10:
				G.plough(pos.x, pos.y, S, dx)
			if randf() < dt * 40:
				G.rush(pos.x, pos.y - S * 0.45, S, dx, dy)
			a.tw = a.get("tw", 0.0) - dt
			if a.tw <= 0:
				a.tw = 0.075
				G.warp(pos.x, pos.y, {"r0": S * 0.1, "r1": S * 1.1, "w": S * 0.22, "amp": S * 0.12, "life": 0.32, "lit": 0.05})
		if a.type == "vit":
			var p2 := duck_pos(a)
			if not a.has("st"):
				a.st = 1
				G.feathers(sx(a.x), sy(a.y), S, 5)
				G.dust(sx(a.x), sy(a.y) + S * 0.3, S, 3, "#f3e6c6")
			if randf() < dt * 18:
				G.drip(p2.x, p2.y, S)
			if randf() < dt * 7:
				G.feathers(p2.x, p2.y, S, 1)
			if randf() < dt * 30:
				G.trail(p2.x, p2.y + S * 0.1, S * 0.7, "#cfeefa")
		if a.type == "beam" and a.t > 0 and randf() < dt * 90:
			var k: float = g.ease_out(clampf(a.t / a.dur, 0, 1))
			var b := _beam_pt(a, k)
			G.trail(b.x, b.y, S)
		if a.type == "ga" and not a.has("rung"):
			a.rung = 1
			var X := sx(a.x)
			var Y := sy(a.y) - S * 0.3
			var R: float = Vector2(g.LAY.bw, g.LAY.bh).length()
			for q in 3:
				G.warp(X, Y, {"t": -q * 0.18, "r0": S * 0.4, "r1": R, "w": S * 0.38, "amp": S * 0.16, "life": 0.9, "lit": 0.06})
			G.crow(sx(a.x), sy(a.y) - S * 0.4, S)
			G.plumes(sx(a.x), sy(a.y) - S * 0.2, S)
		if a.type == "heo" and not a.has("jumped") and a.t / a.dur > 0.1:
			a.jumped = 1
			G.dust(sx(a.x), sy(a.y) + S * 0.35, S, 5, "#f3e6c6")
		if a.type == "heo" and not a.has("landed") and a.t / a.dur > 0.56:
			a.landed = 1
			G.slam(sx(a.x), sy(a.y) + S * 0.2, S, a.R)
		if a.t >= a.dur:
			Ac.remove_at(i)
			if a.type == "vit":
				G.splash(sx(a.tx), sy(a.ty) + S * 0.2, S)
				G.warp(sx(a.tx), sy(a.ty), {"kind": "ripple", "r0": 0, "r1": S * 2.6, "w": S * 0.5, "amp": S * 0.07, "freq": 3.2, "life": 0.9, "lit": 0.35})
			if a.type == "beam":
				G.peck(sx(a.tx), sy(a.ty), S)
			if a.type == "spark":
				G.make(a.tx, a.ty, S, "h")
			if a.type == "egg":
				g.ui.bump_type("egg")

func trau_pos(a: Dictionary) -> Vector2:
	var k := clampf(a.t / (a.dur - 0.12), 0, 1)
	var S: float = g.LAY.S
	var span: float = a.N + 2.4
	var p := -1.2 + k * span
	if a.dir == "h":
		var xx: float = p if a.sgn > 0 else a.N - 1 - p
		return Vector2(g.LAY.bx + (xx + 0.5) * S, sy(a.y) + S * 0.38)
	var yy: float = p if a.sgn > 0 else a.N - 1 - p
	return Vector2(sx(a.x), g.LAY.by + (yy + 0.5) * S + S * 0.38)

func duck_pos(a: Dictionary) -> Vector2:
	var k: float = g.ease_in_out(clampf(a.t / a.dur, 0, 1))
	return Vector2(lerpf(sx(a.x), sx(a.tx), k), lerpf(sy(a.y), sy(a.ty), k) - sin(k * PI) * g.LAY.S * 2.2)

func _beam_pt(a: Dictionary, e: float) -> Vector2:
	var S: float = g.LAY.S
	var p0 := Vector2(sx(a.x), sy(a.y) - S * 0.3)
	var p1 := Vector2(sx(a.tx), sy(a.ty))
	var m := Vector2((p0.x + p1.x) / 2, minf(p0.y, p1.y) - S * 1.2)
	return p0 * (1 - e) * (1 - e) + m * 2 * (1 - e) * e + p1 * e * e

# ---------- vẽ
# dưới trái: luống đất trâu cày
func draw_under(ci: CanvasItem) -> void:
	var S: float = g.LAY.S
	var L: Dictionary = g.LAY
	for a in Ac:
		if a.type != "trau" or a.t <= 0:
			continue
		var pos := trau_pos(a)
		var k := clampf(a.t / a.dur, 0, 1)
		var al := 1 - (k - 0.75) / 0.25 if k > 0.75 else 1.0
		var h: bool = a.dir == "h"
		var y0: float = sy(a.y) if h else 0.0
		var x0: float = 0.0 if h else sx(a.x)
		var st: float
		if h:
			st = L.bx if a.sgn > 0 else L.bx + L.bw
		else:
			st = L.by if a.sgn > 0 else L.by + L.bh
		var en: float = pos.x if h else pos.y - S * 0.38
		var lo := minf(st, en)
		var ln := absf(en - st)
		var w := S * 0.46
		var stops := [[0.0, Color("#9a6a3e")], [0.25, Color("#5e3d22")], [0.75, Color("#6b4a2c")], [1.0, Color("#a87a4a")]]
		for s in stops:
			s[1].a = 0.62 * al
		var r := Rect2(lo, y0 - w / 2, ln, w) if h else Rect2(x0 - w / 2, lo, w, ln)
		var pts := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
		if h:
			A.grad_poly(ci, pts, Vector2(0, y0 - w / 2), Vector2(0, y0 + w / 2), stops)
		else:
			A.grad_poly(ci, pts, Vector2(x0 - w / 2, 0), Vector2(x0 + w / 2, 0), stops)
		var lc := Color(1, 0.925, 0.784, 0.35 * 0.62 * al)
		var q := lo + S * 0.2
		while q < lo + ln:
			if h:
				ci.draw_rect(Rect2(q, y0 - w * 0.08, S * 0.18, w * 0.12), lc)
			else:
				ci.draw_rect(Rect2(x0 - w * 0.08, q, w * 0.12, S * 0.18), lc)
			q += S * 0.42

# miếng trái + trái bị hút
func draw_parts(ci: CanvasItem) -> void:
	var S: float = g.LAY.S
	for p in P:
		var k: float = p.t / p.life
		if p.type == "suck":
			var e := k * k
			var x := lerpf(p.x, p.tx, e)
			var y := lerpf(p.y, p.ty, e)
			var w := S * 1.5 * (1 - e * 0.45)
			ci.draw_texture_rect(A.img("f" + str(p.k)), Rect2(x - w / 2, y - w / 2, w, w), false, Color(1, 1, 1, 1 - e * 0.3))
		elif p.type == "piece":
			var im: Texture2D = A.img("p" + str(p.k) + str(p.v))
			var w2 = S * 0.5458 * p.s * (0.6 + k / 0.12 * 0.4 if k < 0.12 else 1.0) * (1 - maxf(0.0, k - 0.7) / 0.3 * 0.4)
			var al := 1 - (k - 0.7) / 0.3 if k > 0.7 else 1.0
			ci.draw_set_transform(Vector2(p.x, p.y), p.rot, Vector2.ONE)
			ci.draw_texture_rect(im, Rect2(-w2 / 2, -w2 / 2, w2, w2), false, Color(1, 1, 1, al))
			ci.draw_set_transform_matrix(Transform2D.IDENTITY)

# lớp trên cùng: vùng heo ụp, thú, chữ điểm
func draw_top_add(ci: CanvasItem) -> void:
	var S: float = g.LAY.S
	var star: Texture2D = A.img("glint")
	for a in Ac:
		if a.t < 0:
			continue
		var k := clampf(a.t / a.dur, 0, 1)
		if a.type == "beam":
			var b := _beam_pt(a, g.ease_out(k))
			ci.draw_texture_rect(star, Rect2(b.x - S * 0.42, b.y - S * 0.42, S * 0.84, S * 0.84), false, Color(1, 1, 1, 0.55))
		elif a.type == "spark":
			var e3 := k * k
			ci.draw_texture_rect(star, Rect2(lerpf(a.x, a.tx, e3) - S * 0.5, lerpf(a.y, a.ty, e3) - S * 0.5, S, S), false)

func draw_top(ci: CanvasItem) -> void:
	var S: float = g.LAY.S
	var L: Dictionary = g.LAY
	var B = g.B
	for a in Ac:
		if a.type != "heo":
			continue
		var k: float = a.t / a.dur
		if k > 0.56:
			continue
		var R: int = a.R
		var ex := 1 if R > 2 else 0
		var q := sin(k / 0.56 * PI * 0.5)
		var pul := 0.75 + 0.25 * sin(a.t * 22)
		var fill := Color(1, 196 / 255.0, 90 / 255.0, 0.22 * q * pul)
		var lc := Color(226 / 255.0, 108 / 255.0, 28 / 255.0, 0.9 * q)
		var lw := maxf(2.0, S * 0.06)
		var dz := func(u: int, v: int) -> int:
			return (maxi(absi(u - a.x), absi(v - a.y)) - ex) if a.sq else (absi(u - a.x) + absi(v - a.y))
		var inZ := func(u: int, v: int) -> bool:
			var c = B.C(u, v)
			return dz.call(u, v) <= R + ex and c != null and c.play
		for yy in range(a.y - R, a.y + R + 1):
			for xx in range(a.x - R, a.x + R + 1):
				if not inZ.call(xx, yy):
					continue
				var X0: float = L.bx + xx * S
				var Y0: float = L.by + yy * S
				ci.draw_rect(Rect2(X0, Y0, S, S), fill)
				if not inZ.call(xx, yy - 1):
					ci.draw_line(Vector2(X0, Y0), Vector2(X0 + S, Y0), lc, lw)
				if not inZ.call(xx, yy + 1):
					ci.draw_line(Vector2(X0, Y0 + S), Vector2(X0 + S, Y0 + S), lc, lw)
				if not inZ.call(xx - 1, yy):
					ci.draw_line(Vector2(X0, Y0), Vector2(X0, Y0 + S), lc, lw)
				if not inZ.call(xx + 1, yy):
					ci.draw_line(Vector2(X0 + S, Y0), Vector2(X0 + S, Y0 + S), lc, lw)
	for a in Ac:
		if a.t < 0:
			continue
		var k := clampf(a.t / a.dur, 0, 1)
		match a.type:
			"trau":
				var pos := trau_pos(a)
				var fr := int(floor(a.t * 16))
				var view := "4" if a.dir == "h" else ("8" if a.sgn > 0 else "0")
				var flip: bool = a.dir == "h" and a.sgn < 0
				A.ell(ci, pos, S * 0.75, S * 0.18, Color(40 / 255.0, 30 / 255.0, 10 / 255.0, 0.25))
				var bob := absf(sin(a.t * 26)) * S * 0.07
				var rot = sin(a.t * 26) * 0.05 * a.sgn if a.dir == "h" else 0.0
				A.anim_t(ci, "trau", "run", view, fr, Transform2D(rot, Vector2(pos.x, pos.y - bob)), S * 1.75, flip)
			"heo":
				var X := sx(a.x)
				var Y := sy(a.y)
				var h := 0.0
				var sq := 1.0
				var startH := S * 3.1
				var tilt := 0.0
				if k < 0.1:
					sq = 1 - sin(k / 0.1 * PI * 0.5) * 0.22
				elif k < 0.56:
					var q2 := (k - 0.1) / 0.46
					h = sin(q2 * PI) * startH
					sq = 1 + sin(q2 * PI) * 0.1
					tilt = sin(q2 * TAU) * 0.25
				else:
					sq = 1 - sin((k - 0.56) / 0.44 * PI) * 0.22
				A.ell(ci, Vector2(X, Y + S * 0.35), S * 0.55 * (1 - h / startH * 0.5), S * 0.14, Color(40 / 255.0, 30 / 255.0, 10 / 255.0, 0.3))
				var xf := Transform2D(tilt, Vector2(1 / sq, sq), 0, Vector2(X, Y + S * 0.35 - h))
				A.anim_t(ci, "heo", "idle", "8", 0, xf, S * 1.7, false)
				if k > 0.6:
					var q3 := (k - 0.6) / 0.4
					var al := q3 / 0.2 if q3 < 0.2 else (1 - (q3 - 0.75) / 0.25 if q3 > 0.75 else 1.0)
					for j in 3:
						var an: float = a.t * 9 + j * TAU / 3
						var c := Vector2(X + cos(an) * S * 0.42, Y - S * 0.62 + sin(an) * S * 0.12)
						var pts := A.star_pts(c, S * 0.12, S * 0.05, 5)
						ci.draw_colored_polygon(pts, Color(1, 0.847, 0.29, al))
						var cl := pts.duplicate()
						cl.append(pts[0])
						ci.draw_polyline(cl, Color(0.66, 0.35, 0.05, al), S * 0.03, true)
			"vit":
				var p := duck_pos(a)
				var flip2 := sx(a.tx) < sx(a.x)
				if a.carry != null:
					var im := A.img("rooster") if a.carry.sp == "rooster" else A.img("s" + str(a.carry.k) + a.carry.sp)
					ci.draw_texture_rect(im, Rect2(p.x - S * 0.45, p.y - S * 0.2, S * 0.9, S * 0.9), false)
				var xf2 := Transform2D(sin(a.t * 30) * 0.08, p) * Transform2D(0, Vector2(0, S * 0.25))
				A.anim_t(ci, "vit", "run", "4", int(floor(a.t * 20)), xf2, S * 1.4, flip2)
			"ga":
				var X2 := sx(a.x)
				var Y2 := sy(a.y)
				var pop: float = g.ease_back(clampf(k * 3, 0, 1)) * (1 - (k - 0.8) * 5 if k > 0.8 else 1.0)
				var c2 := Vector2(X2, Y2 - S * 0.3)
				var RR := maxf(1.0, S * 2.4 * pop)
				var ap := clampf(pop, 0, 1)
				# tia nắng điên điển
				for r in 10:
					var qa: float = float(r) / 10 * TAU + a.t * 0.8
					var fan := PackedVector2Array([c2])
					var cols := PackedColorArray([Color(1, 0.85, 0.29, 0.55 * ap)])
					for s in 5:
						var aa := qa - 0.09 + 0.18 * s / 4.0
						fan.append(c2 + Vector2(cos(aa), sin(aa)) * RR)
						cols.append(Color(0.97, 0.72, 0.125, 0.0))
					ci.draw_polygon(fan, cols)
				A.radial(ci, c2, S * 1.2, [[0.0, Color(1, 0.94, 0.745, 0.45 * ap)], [1.0, Color(1, 0.86, 0.47, 0)]], 20)
				A.anim(ci, "trong", "idle", "8", int(floor(a.t * 8)), X2, Y2 + S * 0.5, S * 2.4 * pop, false)
			"beam":
				var e: float = g.ease_out(k)
				var b := _beam_pt(a, e)
				var p0 := Vector2(sx(a.x), sy(a.y) - S * 0.3)
				var p1 := Vector2(sx(a.tx), sy(a.ty))
				var m := Vector2((p0.x + p1.x) / 2, minf(p0.y, p1.y) - S * 1.2)
				var dv := (m - p0) * 2 * (1 - e) + (p1 - m) * 2 * e
				var ang := atan2(dv.y, dv.x)
				var pts2 := A.ell_pts(b, S * 0.15, S * 0.07, 16, ang)
				ci.draw_colored_polygon(pts2, Color("#ffd84a"))
				var cl2 := pts2.duplicate()
				cl2.append(pts2[0])
				ci.draw_polyline(cl2, Color("#a85a0c"), maxf(1.0, S * 0.03), true)
				A.ell(ci, b + Vector2(-S * 0.03, -S * 0.025).rotated(ang), S * 0.06, S * 0.02, Color(1, 1, 1, 0.8), ang)
			"hoe":
				_draw_hoe(ci, a, k, S)
			"egg":
				var e2: float = g.ease_in_out(k)
				var x := lerpf(a.x, a.tx, e2)
				var y := lerpf(a.y, a.ty, e2) - sin(e2 * PI) * S * 1.5
				var s2 := S * (1 - e2 * 0.4)
				ci.draw_texture_rect(A.img("egg"), Rect2(x - s2 * 0.75, y - s2 * 0.75, s2 * 1.5, s2 * 1.5), false)
	# chữ điểm bay
	for p in T:
		var k2: float = p.t / p.life
		var s3: float = round(S * 0.42 * (0.6 + k2 / 0.15 * 0.4 if k2 < 0.15 else 1.0))
		var al2 := 1 - (k2 - 0.6) / 0.4 if k2 > 0.6 else 1.0
		var col: Color = p.col
		col.a = al2
		A.text(ci, p.txt, p.x, p.y, s3, col, 1, 800, maxf(3.0, s3 * 0.18) * 2, Color(0.169, 0.129, 0.094, al2))

func _draw_hoe(ci: CanvasItem, a: Dictionary, k: float, S: float) -> void:
	var X := sx(a.x)
	var Y := sy(a.y)
	var q := clampf(k / 0.7, 0, 1)
	var ang: float = (-1.1 - g.ease_out(q / 0.35) * 0.5) if q < 0.35 else (-1.6 + pow((q - 0.35) / 0.65, 2) * 1.9)
	var sc := S * 1.9
	var xf := Transform2D(ang, Vector2(X + S * 0.55, Y + S * 0.35))
	ci.draw_set_transform_matrix(xf)
	A.ell(ci, Vector2.ZERO, S * 0.12, S * 0.05, Color(40 / 255.0, 25 / 255.0, 10 / 255.0, 0.18))
	A.stroke(ci, PackedVector2Array([Vector2.ZERO, Vector2(0, -sc * 0.8)]), Color("#5a3618"), S * 0.13)
	ci.draw_set_transform_matrix(xf)
	A.stroke(ci, PackedVector2Array([Vector2(-S * 0.02, -S * 0.05), Vector2(-S * 0.02, -sc * 0.78)]), Color("#a87444"), S * 0.07)
	ci.draw_set_transform_matrix(xf)
	var blade := PackedVector2Array([Vector2(S * 0.05, -sc * 0.82), Vector2(-S * 0.72, -sc * 0.7)])
	blade.append_array(A.quad_pts(Vector2(-S * 0.72, -sc * 0.7), Vector2(-S * 0.82, -sc * 0.6), Vector2(-S * 0.7, -sc * 0.52), 6))
	blade.append(Vector2(S * 0.05, -sc * 0.66))
	ci.draw_colored_polygon(blade, Color("#b8c2c6"))
	var bl := blade.duplicate()
	bl.append(blade[0])
	ci.draw_polyline(bl, Color("#2f3538"), maxf(1.5, S * 0.04), true)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-S * 0.1, -sc * 0.79), Vector2(-S * 0.6, -sc * 0.7), Vector2(-S * 0.58, -sc * 0.67), Vector2(-S * 0.1, -sc * 0.75)]), Color(1, 1, 1, 0.6))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
