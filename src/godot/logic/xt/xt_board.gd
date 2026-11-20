extends RefCounted
# XẾP TRÁI: luật bàn, dịch từng dòng từ 03_board.js của bản web (ráp, trái đặc biệt, combo, rơi, trứng, mục tiêu,
# lượt dư "Được mùa", xáo bàn, đồ phụ). Trái là Dictionary như object của web. g = xt_game (đồng hồ, hiệu ứng, âm, giao diện).

const D := preload("res://logic/xt/xt_data.gd")
const EGG := 9
const ROO := -1

var g   # xt_game
var W := 9
var H := 9
var cell: Array = []
var T: Array = []
var lv: Dictionary = {}
var lv_idx := 0
var moves := 0
var score := 0
var goals: Array = []
var busy := false
var over := false
var dying: Array = []
var cascade := 0
var idle := 0.0
var hint = null
var next_id := 1
var spawn_stack: Array = []
var eggs_out := 0
var stats := {}
var haul := {}
var extra_used := false
var stars: Array = [0, 0, 0]
var gen := 0   # tăng mỗi lần vô màn: việc cũ còn chờ thì dừng

func _init(game) -> void:
	g = game

func in_b(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < W and y < H
func C(x: int, y: int):
	return cell[y][x] if in_b(x, y) else null
func TL(x: int, y: int):
	return T[y][x] if in_b(x, y) else null
static func matchable(t) -> bool:
	return t != null and t.k >= 0 and t.k < 6 and not t.dying

func new_tile(k: int, sp := "") -> Dictionary:
	var t := {"id": next_id, "k": k, "sp": sp, "x": 0, "y": 0, "px": 0.0, "py": 0.0, "vy": 0.0, "sq": 0.0, "sc": 1.0, "al": 1.0, "lock": 0,
		"dying": false, "fired": false, "wob": 0.0, "born": 0.0, "glow": 0.0, "tw": 0, "dieT": 0.0}
	next_id += 1
	return t

func place(t: Dictionary, x: int, y: int, snap: bool) -> void:
	T[y][x] = t
	t.x = x
	t.y = y
	if snap:
		t.px = float(x)
		t.py = float(y)

# ---------- vô màn
func load_level(i: int) -> void:
	gen += 1
	var L: Dictionary = D.LEVELS[i]
	lv = L
	lv_idx = i
	var rows: Array = L.map
	H = rows.size()
	W = 0
	for r in rows:
		W = maxi(W, r.length())
	cell = []
	T = []
	g.sched.clear()
	dying = []
	next_id = 1
	eggs_out = 0
	over = false
	busy = false
	hint = null
	extra_used = false
	for y in H:
		cell.append([])
		T.append([])
		for x in W:
			var row: String = rows[y]
			var ch := row[x] if x < row.length() else " "
			var c := {"play": ch != " " and ch != "_", "mud": 0, "block": null, "exit": false, "v": (x * 7 + y * 3) % 4}
			if ch == "m" or ch == "L":
				c.mud = 1
			if ch == "M":
				c.mud = 2
			if ch == "h":
				c.block = {"type": "hay", "hp": 1}
			if ch == "H":
				c.block = {"type": "hay", "hp": 2}
			cell[y].append(c)
			T[y].append(null)
	var has_egg := false
	for gg in L.goals:
		if gg.has("egg"):
			has_egg = true
	if has_egg:
		for x in W:
			for y in range(H - 1, -1, -1):
				if cell[y][x].play:
					cell[y][x].exit = true
					break
	moves = int(L.moves)
	score = 0
	cascade = 0
	goals = []
	for gg in L.goals:
		if gg.has("fruit"):
			goals.append({"type": "fruit", "k": int(gg.fruit), "need": int(gg.n), "got": 0})
		elif gg.has("mud"):
			var n := 0
			for r in cell:
				for c in r:
					n += c.mud
			goals.append({"type": "mud", "need": n, "got": 0})
		elif gg.has("hay"):
			var n2 := 0
			for r in cell:
				for c in r:
					n2 += c.block.hp if c.block != null else 0
			goals.append({"type": "hay", "need": n2, "got": 0})
		elif gg.has("egg"):
			goals.append({"type": "egg", "need": int(gg.egg), "got": 0})
		elif gg.has("score"):
			goals.append({"type": "score", "need": int(gg.score), "got": 0})
	stars = D.stars_of(i)
	stats = {"specials": 0, "best": 0}
	haul = {}
	fill_board(rows)

func fill_board(rows: Array) -> void:
	for tries in 60:
		for y in H:
			for x in W:
				T[y][x] = null
				var c: Dictionary = cell[y][x]
				if not c.play or c.block != null:
					continue
				var row: String = rows[y]
				var ch := row[x] if x < row.length() else " "
				if ch == "e":
					var te := new_tile(EGG)
					place(te, x, y, true)
					eggs_out += 1
					continue
				var k := 0
				var n := 0
				while true:
					k = randi() % int(lv.kinds)
					n += 1
					if not (n < 30 and would_match(x, y, k)):
						break
				var t := new_tile(k)
				if ch == "l" or ch == "L":
					t.lock = 1
				place(t, x, y, true)
		if find_move() != null:
			return
		eggs_out = 0

func would_match(x: int, y: int, k: int) -> bool:
	var Kf := func(xx, yy):
		var t = TL(xx, yy)
		return t != null and t.k == k
	if Kf.call(x - 1, y) and Kf.call(x - 2, y):
		return true
	if Kf.call(x, y - 1) and Kf.call(x, y - 2):
		return true
	if Kf.call(x - 1, y) and Kf.call(x, y - 1) and Kf.call(x - 1, y - 1):
		return true
	return false

# ---------- tìm chỗ ráp
func find_groups() -> Array:
	var runs := []
	for dir in ["h", "v"]:
		var A := H if dir == "h" else W
		var B := W if dir == "h" else H
		for a in A:
			var b := 0
			while b < B:
				var t = TL(b, a) if dir == "h" else TL(a, b)
				if not matchable(t):
					b += 1
					continue
				var e := b + 1
				while e < B:
					var u = TL(e, a) if dir == "h" else TL(a, e)
					if matchable(u) and u.k == t.k:
						e += 1
					else:
						break
				if e - b >= 3:
					var cells := []
					for i in range(b, e):
						cells.append(Vector2i(i, a) if dir == "h" else Vector2i(a, i))
					runs.append({"dir": dir, "cells": cells, "k": t.k, "len": e - b, "type": "run"})
				b = e
	var squares := []
	for y in H - 1:
		for x in W - 1:
			var t = TL(x, y)
			if not matchable(t):
				continue
			var k: int = t.k
			var ok := true
			for u in [TL(x + 1, y), TL(x, y + 1), TL(x + 1, y + 1)]:
				if not (matchable(u) and u.k == k):
					ok = false
			if ok:
				squares.append({"cells": [Vector2i(x, y), Vector2i(x + 1, y), Vector2i(x, y + 1), Vector2i(x + 1, y + 1)], "k": k, "type": "sq"})
	if runs.is_empty() and squares.is_empty():
		return []
	var pats: Array = runs + squares
	var par := []
	for i in pats.size():
		par.append(i)
	var f := func(i: int) -> int:
		var r := i
		while par[r] != r:
			r = par[r]
		var j := i
		while par[j] != r:
			var nx: int = par[j]
			par[j] = r
			j = nx
		return r
	var owner := {}
	for i in pats.size():
		for c in pats[i].cells:
			var key: int = c.y * W + c.x
			if owner.has(key):
				par[f.call(i)] = f.call(owner[key])
			else:
				owner[key] = i
	var gm := {}
	var order := []
	for i in pats.size():
		var r: int = f.call(i)
		if not gm.has(r):
			gm[r] = {"k": pats[i].k, "cells": {}, "runs": [], "squares": []}
			order.append(r)
		var gr: Dictionary = gm[r]
		for c in pats[i].cells:
			gr.cells[c.y * W + c.x] = c
		if pats[i].type == "run":
			gr.runs.append(pats[i])
		else:
			gr.squares.append(pats[i])
	var out := []
	for r in order:
		out.append(gm[r])
	return out

static func group_special(gr: Dictionary) -> String:
	var max_run := 0
	for r in gr.runs:
		max_run = maxi(max_run, r.len)
	if max_run >= 5:
		return "rooster"
	var hs := 0
	var vs := 0
	for r in gr.runs:
		if r.dir == "h":
			hs += 1
		else:
			vs += 1
	if hs > 0 and vs > 0:
		return "bomb"
	if max_run == 4:
		for r in gr.runs:
			if r.len == 4:
				return "v" if r.dir == "h" else "h"
	if gr.squares.size():
		return "duck"
	return ""

func later(sec: float, fn: Callable) -> void:
	g.later(sec, fn)

func add_score(n: float, x = null, y = null, col = null) -> void:
	var v := int(round(n))
	score += v
	if x != null:
		g.fx.text("+" + str(v), x, y, col)
	for gg in goals:
		if gg.type == "score":
			gg.got = score
	g.ui.dirty = true

func goal(type: String, k := -9, n := 1) -> void:
	for gg in goals:
		if gg.type == type and (type != "fruit" or gg.k == k):
			if gg.got < gg.need:
				gg.got = mini(gg.need, gg.got + n)
				g.ui.bump(gg)
	g.ui.dirty = true

# trúng một ô: gỡ dây / phá rơm, hay ăn trái (nổ đặc biệt của nó) và một lớp bùn
func hit(x: int, y: int, src := {}) -> void:
	var c = C(x, y)
	if c == null or not c.play:
		return
	if c.block != null:
		c.block.hp -= 1
		goal("hay")
		add_haul("rom")
		g.fx.hay(x, y, c.block.hp)
		g.snd.play("hay")
		add_score(100)
		if c.block.hp <= 0:
			c.block = null
		return
	var t = T[y][x]
	if t == null:
		if src.get("big", false) and c.mud > 0:
			c.mud -= 1
			goal("mud")
			g.fx.mud(x, y, c.mud)
			add_score(80)
		return
	if t.dying:
		return
	if t.k == EGG:
		return
	if t.lock:
		t.lock = 0
		g.fx.vine(x, y)
		g.snd.play("hay")
		add_score(60)
		return
	if t.sp != "" and not t.fired:
		t.fired = true
		trigger(t, x, y, src)
	kill(t, x, y, src)
	if c.mud > 0:
		c.mud -= 1
		goal("mud")
		g.fx.mud(x, y, c.mud)
		add_score(80)

func kill(t: Dictionary, x: int, y: int, src := {}) -> void:
	if T[y][x] == t:
		T[y][x] = null
	t.dying = true
	t.dieT = 0.0
	dying.append(t)
	if t.k >= 0 and t.k < 6:
		goal("fruit", t.k)
		add_haul(str(t.k))
		g.fx.juice(x, y, t.k, src.get("big", false))
	elif t.k == ROO:
		g.fx.juice(x, y, 0, true)

func hit_adj_blocks(cells: Array) -> void:
	var seen := {}
	for p in cells:
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var xx: int = p.x + d.x
			var yy: int = p.y + d.y
			var c = C(xx, yy)
			var key := yy * W + xx
			if c != null and c.block != null and not seen.has(key):
				seen[key] = 1
				hit(xx, yy)

# ---------- trái đặc biệt
func pet_lv(k: String) -> int:
	var p = g.save.pets.get(k, null)
	return int(p.lv) if p is Dictionary else 1

func trigger(t: Dictionary, x: int, y: int, _src: Dictionary) -> void:
	stats.specials += 1
	var sp: String = t.sp
	g.scn.cheer(D.HELPER[sp])
	var tk: int = t.k
	if sp == "h" or sp == "v":
		line_blast(x, y, sp, tk)
		var lvl := pet_lv("trau")
		for j in range(1, lvl):
			var o = extra_line(x, y, sp, j)
			if o != null:
				var oo: int = o
				later(j * 0.08, func():
					if sp == "h":
						line_blast(x, oo, sp, tk, true)
					else:
						line_blast(oo, y, sp, tk, true))
	elif sp == "bomb":
		var lvl2 := pet_lv("heo")
		bomb_blast(x, y, 3 if lvl2 >= 3 else 2, tk, lvl2 == 2)
	elif sp == "duck":
		duck_fly(x, y, "", tk, pet_lv("vit"))
	elif sp == "rooster":
		var ks := present_kinds()
		var lvl3 := pet_lv("trong")
		if lvl3 >= 2 and ks.size():
			ks.sort_custom(func(a, b): return kind_count(a) > kind_count(b))
		rooster(x, y, (ks[0] if lvl3 >= 2 else ks.pick_random()) if ks.size() else 0, "")
		if lvl3 >= 3 and ks.size() > 1:
			var k1: int = ks[1]
			later(0.5, func(): rooster(x, y, k1, ""))

func add_haul(k: String) -> void:
	haul[k] = int(haul.get(k, 0)) + 1

func kind_count(k: int) -> int:
	var n := 0
	for r in T:
		for t in r:
			if matchable(t) and t.k == k:
				n += 1
	return n

func extra_line(x: int, y: int, dir: String, j: int):
	var N := H if dir == "h" else W
	var c := y if dir == "h" else x
	for o in [c + j, c - j, c + j + 1, c - j - 1]:
		if o < 0 or o >= N:
			continue
		for i in (W if dir == "h" else H):
			var cc = C(i, o) if dir == "h" else C(o, i)
			if cc != null and cc.play:
				return o
	return null

func line_blast(x: int, y: int, dir: String, _k: int, quiet := false) -> void:
	if not quiet:
		g.snd.play("trau")
	g.fx.shake(0.25)
	var dir_sign := 1 if randf() < 0.5 else -1
	g.fx.buffalo(x, y, dir, dir_sign)
	var N := W if dir == "h" else H
	later(0.4, func(): g.fx.sum_text("blast", (N - 1) * 60, x, y, Color("#fff2b0")))
	for i in N:
		var xx := i if dir == "h" else x
		var yy := y if dir == "h" else i
		if xx == x and yy == y:
			continue
		var pos := i if dir_sign > 0 else N - 1 - i
		later(0.12 + pos * 0.055, func():
			hit(xx, yy, {"big": true})
			add_score(60))

func bomb_blast(x: int, y: int, R: int, _k: int, sq := false) -> void:
	g.snd.play("heo")
	g.fx.pig(x, y, R, sq)
	later(0.42, func():
		g.fx.shake(0.4)
		g.snd.play("boom")
		g.fx.ring(x, y, R + 0.5, Color("#ffd27a"))
		g.gfx.dust(g.sx(x), g.sy(y) + g.LAY.S * 0.3, g.LAY.S, 6, "#f3e6c6")
		for yy in range(y - R, y + R + 1):
			for xx in range(x - R, x + R + 1):
				if not sq and absi(xx - x) + absi(yy - y) > R + (1 if R > 2 else 0):
					continue
				if xx == x and yy == y:
					continue
				var d := absi(xx - x) + absi(yy - y)
				var cx := xx
				var cy := yy
				later(d * 0.03, func():
					hit(cx, cy, {"big": true})
					add_score(60))
		g.fx.sum_text("blast", 2400 if R > 2 else (1440 if sq else 720), x, y - 1.3, Color("#fff3c4")))

func duck_target(fx: int, fy: int):
	var cand := []
	for y in H:
		for x in W:
			var c: Dictionary = cell[y][x]
			if not c.play or (x == fx and y == fy):
				continue
			var t = T[y][x]
			var s := randf() * 0.5
			if c.block != null:
				s += 5.0 if _goal_open("hay") else 1.0
			if c.mud:
				s += (4.0 + c.mud) if _goal_open("mud") else 0.0
			if t != null and t.lock:
				s += 2
			if t != null and t.k >= 0 and t.k < 6:
				for gg in goals:
					if gg.type == "fruit" and gg.k == t.k and gg.got < gg.need:
						s += 2
						break
			var up = TL(x, y - 1)
			if up != null and up.k == EGG:
				s += 3
			if t != null and t.k == EGG:
				s -= 9
			if t != null and t.dying:
				s -= 9
			cand.append([s, x, y])
	cand.sort_custom(func(a, b): return a[0] > b[0])
	return Vector2i(cand[0][1], cand[0][2]) if cand.size() else null

func _goal_open(type: String) -> bool:
	for gg in goals:
		if gg.type == type and gg.got < gg.need:
			return true
	return false

func duck_fly(x: int, y: int, carry: String, k: int, n := 1) -> void:
	g.snd.play("vit")
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var dx: int = d.x
		var dy: int = d.y
		later(0.05, func(): hit(x + dx, y + dy))
	for i in n:
		var tg = duck_target(x, y)
		if tg == null:
			return
		var tx: int = tg.x
		var ty: int = tg.y
		var dur := 0.5 + i * 0.12
		g.fx.duck(x, y, tx, ty, dur, {"k": k, "sp": carry} if carry != "" else null)
		later(dur, func():
			if carry == "h" or carry == "v":
				line_blast(tx, ty, carry, k)
			elif carry == "bomb":
				bomb_blast(tx, ty, 2, k)
			hit(tx, ty, {"big": true})
			add_score(150, tx, ty))

func present_kinds() -> Array:
	var s := {}
	for r in T:
		for t in r:
			if matchable(t):
				s[t.k] = 1
	return s.keys()

# gà gáy: mọi trái một loại bị mổ (hay hóa trái đặc biệt trước)
func rooster(x: int, y: int, k: int, turn_into: String) -> void:
	g.snd.play("ga")
	g.fx.crow(x, y)
	var targets := []
	for yy in H:
		for xx in W:
			var t = T[yy][xx]
			if matchable(t) and t.k == k:
				targets.append([xx, yy, t])
	targets.sort_custom(func(a, b): return Vector2(a[0] - x, a[1] - y).length() < Vector2(b[0] - x, b[1] - y).length())
	for i in targets.size():
		var xx: int = targets[i][0]
		var yy: int = targets[i][1]
		var t: Dictionary = targets[i][2]
		var d := 0.35 + i * 0.05
		g.fx.beam(x, y, xx, yy, d)
		if turn_into != "":
			later(d, func():
				if t.dying:
					return
				t.sp = ("h" if randf() < 0.5 else "v") if turn_into == "line" else turn_into
				t.glow = 1.0
				g.snd.play("make"))
			later(d + 0.5 + i * 0.09, func():
				if T[yy][xx] == t:
					hit(xx, yy, {"big": true}))
		else:
			later(d + 0.12, func():
				hit(xx, yy, {"big": true})
				add_score(80))
	if targets.size() and turn_into == "":
		var n := targets.size()
		later(0.6, func(): g.fx.text("+" + str(n * 80), x, y - 1.5, Color("#ffe58a")))

func clear_all(x: int, y: int) -> void:
	g.snd.play("ga")
	g.fx.crow(x, y)
	g.fx.shake(0.6)
	for yy in H:
		for xx in W:
			var d := Vector2(xx - x, yy - y).length()
			var cx := xx
			var cy := yy
			later(0.35 + d * 0.07, func():
				hit(cx, cy, {"big": true})
				add_score(80))
			later(0.9 + d * 0.07, func():
				var c = C(cx, cy)
				if c != null and c.mud:
					hit(cx, cy, {"big": true}))

static func is_line(s: String) -> bool:
	return s == "h" or s == "v"

func combo(a: Dictionary, b: Dictionary) -> void:
	var A: String = a.sp
	var B: String = b.sp
	var x: int = b.x
	var y: int = b.y
	for t in [a, b]:
		t.fired = true
		kill(t, t.x, t.y, {"big": true})
	stats.specials += 2
	if A == "rooster" and B == "rooster":
		g.scn.cheer("trong")
		g.ui.banner("Gà gáy sáng!", "Sạch nguyên vườn")
		clear_all(x, y)
		return
	if A == "rooster" or B == "rooster":
		var o: Dictionary = b if A == "rooster" else a
		g.scn.cheer("trong")
		if o.sp == "":
			rooster(x, y, o.k, "")
			return
		g.ui.banner("Gà gáy dậy đồng!")
		rooster(x, y, o.k, "line" if is_line(o.sp) else o.sp)
		return
	if is_line(A) and is_line(B):
		g.scn.cheer("trau")
		g.ui.banner("Trâu cày chữ thập!")
		line_blast(x, y, "h", b.k)
		line_blast(x, y, "v", b.k)
		return
	if (is_line(A) and B == "bomb") or (A == "bomb" and is_line(B)):
		g.scn.cheer("trau")
		g.scn.cheer("heo")
		g.ui.banner("Ba trâu ra đồng!")
		for d in [-1, 0, 1]:
			if y + d >= 0 and y + d < H:
				line_blast(x, y + d, "h", b.k)
			if x + d >= 0 and x + d < W:
				line_blast(x + d, y, "v", b.k)
		return
	if A == "bomb" and B == "bomb":
		g.scn.cheer("heo")
		g.ui.banner("Heo ụp hai lần!")
		bomb_blast(x, y, 3, b.k)
		var bk: int = b.k
		later(0.9, func(): bomb_blast(x, y, 3, bk))
		return
	if A == "duck" and B == "duck":
		g.scn.cheer("vit")
		g.ui.banner("Bầy vịt xuất chuồng!")
		duck_fly(x, y, "", b.k, 3)
		return
	if A == "duck" or B == "duck":
		var o2: Dictionary = b if A == "duck" else a
		g.scn.cheer("vit")
		duck_fly(x, y, o2.sp, o2.k)
		return

# ---------- rơi + bù trái
func spawn_kind() -> int:
	var eg = null
	for gg in goals:
		if gg.type == "egg":
			eg = gg
			break
	if eg != null and eggs_out + eg.got < eg.need and eggs_out < int(lv.get("eggsOn", 2)) and randf() < 0.18:
		eggs_out += 1
		return EGG
	return randi() % int(lv.kinds)

func gravity() -> bool:
	spawn_stack = []
	spawn_stack.resize(W)
	spawn_stack.fill(0)
	var any := false
	for _pass in 200:
		var moved := false
		for y in range(H - 1, -1, -1):
			for x in W:
				var c: Dictionary = cell[y][x]
				if not c.play or c.block != null or T[y][x] != null:
					continue
				var yy := y - 1
				while yy >= 0 and not cell[yy][x].play:
					yy -= 1
				if yy < 0:
					var t := new_tile(spawn_kind())
					spawn_stack[x] += 1
					t.px = float(x)
					t.py = y - spawn_stack[x] - 0.15
					place(t, x, y, false)
					moved = true
					continue
				var cu: Dictionary = cell[yy][x]
				var tu = T[yy][x]
				if cu.block == null and tu != null:
					T[yy][x] = null
					place(tu, x, y, false)
					moved = true
					continue
				if cu.block == null and tu == null:
					continue
				var dirs := [-1, 1] if randf() < 0.5 else [1, -1]
				for dx in dirs:
					var xx: int = x + dx
					if not in_b(xx, y - 1):
						continue
					var cs: Dictionary = cell[y - 1][xx]
					var ts = T[y - 1][xx]
					if not cs.play or cs.block != null or ts == null:
						continue
					var below: Dictionary = cell[y][xx]
					if below.play and below.block == null and T[y][xx] == null:
						continue
					T[y - 1][xx] = null
					place(ts, x, y, false)
					moved = true
					break
		if not moved and not side_feed():
			break
		any = true
	return any

func _ok(x: int, y: int) -> bool:
	var c = C(x, y)
	return c != null and c.play and c.block == null

func side_feed() -> bool:
	var fed := []
	for y in H:
		var r := []
		r.resize(W)
		r.fill(false)
		fed.append(r)
	for y in H:
		for x in W:
			if not _ok(x, y):
				continue
			var yy := y - 1
			while yy >= 0 and not cell[yy][x].play:
				yy -= 1
			var f = yy < 0 or (_ok(x, yy) and fed[yy][x])
			if not f:
				for dx in [-1, 1]:
					if _ok(x + dx, y - 1) and fed[y - 1][x + dx]:
						f = true
			fed[y][x] = f
	for y in range(H - 1, -1, -1):
		for x in W:
			if not _ok(x, y) or T[y][x] != null or fed[y][x]:
				continue
			var best = null
			for dx in [-1, 1]:
				var i := 1
				while true:
					var xx: int = x + dx * i
					if not _ok(xx, y) or T[y][xx] == null or T[y][xx].lock:
						break
					if fed[y][xx]:
						if best == null or i < best[1]:
							best = [dx, i]
						break
					i += 1
			if best == null:
				var t := new_tile(spawn_kind())
				place(t, x, y, true)
				t.born = 1.0
				return true
			var dx2: int = best[0]
			var n: int = best[1]
			for i in n:
				var t2: Dictionary = T[y][x + dx2 * (i + 1)]
				T[y][x + dx2 * (i + 1)] = null
				place(t2, x + dx2 * i, y, false)
			return true
	return false

func settled() -> bool:
	if g.sched.size() or dying.size() or g.fx.busy():
		return false
	for r in T:
		for t in r:
			if t != null and (t.py != float(t.y) or t.px != float(t.x)):
				return false
	return true

func wait_settled() -> void:
	while not settled():
		await g.wait(0.016).done

func collect_eggs() -> int:
	var n := 0
	for x in W:
		for y in H:
			var c: Dictionary = cell[y][x]
			var t = T[y][x]
			if c.exit and t != null and t.k == EGG and t.py == float(t.y):
				T[y][x] = null
				eggs_out -= 1
				n += 1
				g.fx.egg_out(t, x, y)
				goal("egg")
				add_haul("trung")
				add_score(1000, x, y, Color("#3f7d3a"))
				g.snd.play("egg")
	return n

# ---------- đổi + giải
func swap_tiles(a: Dictionary, b: Dictionary) -> void:
	var ax: int = a.x
	var ay: int = a.y
	place(a, b.x, b.y, false)
	place(b, ax, ay, false)

func anim_hop(a: Dictionary, b: Dictionary, dur := 0.42) -> void:
	a.tw = 1
	b.tw = 1
	var ax: int = b.x
	var ay: int = b.y
	var bx: int = a.x
	var by: int = a.y
	var t0: float = g.clock
	var S: float = g.LAY.S
	var mx: float = g.sx((ax + bx) / 2.0)
	var my: float = g.sy((ay + by) / 2.0)
	g.gfx.leaves(mx, my - S * 0.4, S, 10, ["#7cc04a", "#4f8f36", "#f4c430"])
	g.gfx.warp(mx, my, {"kind": "ripple", "r0": 0, "r1": S * 1.6, "w": S * 0.4, "amp": S * 0.05, "freq": 3, "life": 0.5, "lit": 0.3})
	while true:
		var e := minf(1.0, (g.clock - t0) / dur)
		var q: float = g.ease_in_out(e)
		var arc := sin(e * PI)
		a.px = lerpf(ax, a.x, q)
		a.py = lerpf(ay, a.y, q) - arc * 0.75
		a.sc = 1 + arc * 0.22
		b.px = lerpf(bx, b.x, q)
		b.py = lerpf(by, b.y, q) + arc * 0.12
		b.sc = 1 - arc * 0.12
		if e >= 1:
			break
		await g.wait(0.016).done
	a.sc = 1.0
	b.sc = 1.0
	a.sq = 0.8
	b.sq = 0.8
	a.tw = 0
	b.tw = 0
	g.fx.ring(a.x, a.y, 0.7, Color("#ffe58a"))
	g.fx.ring(b.x, b.y, 0.7, Color("#ffe58a"))

func anim_swap(a: Dictionary, b: Dictionary, dur := 0.16) -> void:
	a.tw = 1
	b.tw = 1
	var w1 = g.tween(a, {"px": float(a.x), "py": float(a.y)}, dur, "inout")
	var w2 = g.tween(b, {"px": float(b.x), "py": float(b.y)}, dur, "inout")
	await g.all([w1, w2])
	a.tw = 0
	b.tw = 0

func _comboable(a: Dictionary, b: Dictionary) -> bool:
	return (a.sp != "" and b.sp != "") or (a.sp == "rooster" and b.k != EGG) or (b.sp == "rooster" and a.k != EGG)

func try_swap(x1: int, y1: int, x2: int, y2: int) -> void:
	if busy or over:
		return
	var a = TL(x1, y1)
	var b = TL(x2, y2)
	if a == null or b == null or a.lock or b.lock:
		if a != null:
			a.wob = 1.0
			g.snd.play("bad")
		return
	busy = true
	hint = null
	idle = 0.0
	g.snd.play("swap")
	var my_gen := gen
	swap_tiles(a, b)
	await anim_swap(a, b)
	if my_gen != gen:
		return
	if _comboable(a, b):
		moves -= 1
		g.ui.dirty = true
		combo(a, b)
		await resolve(null)
		return
	var groups := find_groups()
	if groups.is_empty():
		g.snd.play("bad")
		swap_tiles(a, b)
		await anim_swap(a, b, 0.18)
		if my_gen == gen:
			busy = false
		return
	moves -= 1
	g.ui.dirty = true
	await resolve([Vector2i(a.x, a.y), Vector2i(b.x, b.y)])

static func _in(p: Vector2i, arr) -> bool:
	if arr == null:
		return false
	for q in arr:
		if q == p:
			return true
	return false

func resolve(pref) -> void:
	var my_gen := gen
	cascade = 0
	for _loop in 80:
		await wait_settled()
		if my_gen != gen:
			return
		var groups := find_groups()
		if groups.size():
			cascade += 1
			for gr in groups:
				var cells: Array = gr.cells.values()
				var sp := group_special(gr)
				var at = null
				if sp != "":
					if pref != null:
						for c in cells:
							if _in(c, pref):
								at = c
								break
					if at == null:
						var rs: Array = gr.runs.duplicate()
						rs.sort_custom(func(p, q): return p.len > q.len)
						var src: Array = rs[0].cells if rs.size() else cells
						var pool := []
						for c in src:
							if TL(c.x, c.y).sp == "":
								pool.append(c)
						at = pool[pool.size() / 2] if pool.size() else cells[0]
					if sp == "bomb":
						var inter = null
						for c in cells:
							var nr := 0
							for r in gr.runs:
								if r.cells.has(c):
									nr += 1
							if nr > 1:
								inter = c
								break
						var pref_in := false
						if pref != null:
							for c in cells:
								if _in(c, pref):
									pref_in = true
						if inter != null and not pref_in:
							at = inter
				var base := 60.0 * cascade * (1 + (cells.size() - 3) * 0.5)
				var cx := 0.0
				var cy := 0.0
				for c in cells:
					cx += float(c.x) / cells.size()
					cy += float(c.y) / cells.size()
				add_score(base * cells.size() / 3.0, cx, cy, Color(D.FRUITS[gr.k].col))
				hit_adj_blocks(cells)
				if sp != "" and at != null:
					var pulled := []
					for c in cells:
						var t = TL(c.x, c.y)
						if t != null and t.sp == "" and not t.lock and not cell[c.y][c.x].mud:
							pulled.append(c)
					g.fx.gather(pulled, at, gr.k)
					for c in cells:
						if c == at:
							continue
						var t = TL(c.x, c.y)
						if t != null and t.sp == "" and not t.lock and not cell[c.y][c.x].mud:
							T[c.y][c.x] = null
							goal("fruit", t.k)
							continue
						hit(c.x, c.y)
				else:
					for c in cells:
						if at != null and c == at:
							continue
						hit(c.x, c.y)
				if sp != "" and at != null:
					var x: int = at.x
					var y: int = at.y
					var old = T[y][x]
					if old != null:
						if old.sp != "" and not old.fired:
							old.fired = true
							trigger(old, x, y, {})
						kill(old, x, y, {})
						var c2: Dictionary = C(x, y)
						if c2.mud:
							c2.mud -= 1
							goal("mud")
							g.fx.mud(x, y, c2.mud)
					var t := new_tile(ROO if sp == "rooster" else gr.k, sp)
					place(t, x, y, true)
					t.born = 1.0
					t.glow = 1.0
					g.fx.make(x, y, sp)
					g.snd.play("make")
					add_score(300 if sp == "rooster" else 120)
			g.snd.play("pop", cascade)
			if cascade >= 3:
				g.ui.praise(cascade)
			pref = null
			await wait_settled()
			if my_gen != gen:
				return
		var fell := gravity()
		await wait_settled()
		if my_gen != gen:
			return
		var eggs := collect_eggs()
		if eggs:
			await wait_settled()
			gravity()
			await wait_settled()
			if my_gen != gen:
				return
		if groups.is_empty() and not fell and eggs == 0 and g.sched.is_empty():
			break
	stats.best = maxi(stats.best, cascade)
	busy = false
	await after_turn()

func goals_done() -> bool:
	for gg in goals:
		if gg.got < gg.need:
			return false
	return true

func after_turn() -> void:
	if over:
		return
	var my_gen := gen
	if goals_done():
		over = true
		busy = true
		await bonus_round()
		if my_gen == gen:
			g.ui.win()
		return
	if moves <= 0:
		busy = true
		await g.wait(0.5).done
		if my_gen == gen:
			g.ui.lose()
		return
	if find_move() == null:
		busy = true
		await shuffle_board()
		if my_gen == gen:
			busy = false

# "Được mùa": lượt dư hóa trâu cày, rồi nổ hết
func bonus_round() -> void:
	var my_gen := gen
	await g.wait(0.4).done
	g.ui.banner("Được mùa!", "Lượt dư thành trâu cày")
	await g.wait(1.1).done
	while moves > 0 and my_gen == gen:
		var pool := []
		for r in T:
			for t in r:
				if matchable(t) and t.sp == "" and not t.lock:
					pool.append(t)
		if pool.is_empty():
			break
		var t: Dictionary = pool.pick_random()
		moves -= 1
		g.ui.dirty = true
		g.fx.to_tile(t)
		await g.wait(0.12).done
		t.sp = "h" if randf() < 0.5 else "v"
		t.glow = 1.0
		add_score(300, t.x, t.y, Color("#3f7d3a"))
		g.snd.play("coin")
		await g.wait(0.1).done
	for _round in 12:
		if my_gen != gen:
			return
		var sp := []
		for r in T:
			for t in r:
				if t != null and t.sp != "" and not t.fired and not t.dying:
					sp.append(t)
		if sp.is_empty():
			break
		for t in sp:
			if T[t.y][t.x] == t and not t.fired:
				hit(t.x, t.y, {"big": true})
				await g.wait(0.16).done
		await resolve_quiet()

func resolve_quiet() -> void:
	for _loop in 40:
		await wait_settled()
		var groups := find_groups()
		for gr in groups:
			var cells: Array = gr.cells.values()
			add_score(60 * cells.size())
			for c in cells:
				hit(c.x, c.y)
		var fell := gravity()
		await wait_settled()
		collect_eggs()
		if groups.is_empty() and not fell:
			break

# ---------- nước đi, gợi ý, xáo
func line_at(x: int, y: int, k: int) -> bool:
	var Kf := func(xx, yy):
		var t = TL(xx, yy)
		return matchable(t) and t.k == k
	var h := 1
	var i := x - 1
	while Kf.call(i, y):
		h += 1
		i -= 1
	i = x + 1
	while Kf.call(i, y):
		h += 1
		i += 1
	var v := 1
	i = y - 1
	while Kf.call(x, i):
		v += 1
		i -= 1
	i = y + 1
	while Kf.call(x, i):
		v += 1
		i += 1
	if h >= 3 or v >= 3:
		return true
	for d in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
		if Kf.call(x + d.x, y) and Kf.call(x, y + d.y) and Kf.call(x + d.x, y + d.y):
			return true
	return false

func find_move():
	for y in H:
		for x in W:
			for d in [Vector2i(1, 0), Vector2i(0, 1)]:
				var a = TL(x, y)
				var b = TL(x + d.x, y + d.y)
				if a == null or b == null or a.lock or b.lock or a.dying or b.dying:
					continue
				if _comboable(a, b):
					return [a, b]
				T[y][x] = b
				T[y + d.y][x + d.x] = a
				var ok := (matchable(b) and line_at(x, y, b.k)) or (matchable(a) and line_at(x + d.x, y + d.y, a.k))
				T[y][x] = a
				T[y + d.y][x + d.x] = b
				if ok:
					return [a, b]
	return null

func shuffle_board() -> void:
	g.ui.banner("Xáo lại!", "Hết nước đi rồi")
	await g.wait(0.8).done
	var tiles := []
	for r in T:
		for t in r:
			if t != null and not t.lock and t.k != EGG:
				tiles.append(t)
	var spots := []
	for t in tiles:
		spots.append(Vector2i(t.x, t.y))
	for tries in 80:
		spots.shuffle()
		for i in tiles.size():
			T[spots[i].y][spots[i].x] = tiles[i]
		if find_groups().is_empty() and find_move() != null:
			break
		if tries > 40:
			for t in tiles:
				if t.sp == "":
					t.k = randi() % int(lv.kinds)
	var ws := []
	for i in tiles.size():
		var t: Dictionary = tiles[i]
		t.x = spots[i].x
		t.y = spots[i].y
		t.tw = 1
		ws.append(g.tween(t, {"px": float(t.x), "py": float(t.y)}, 0.5, "inout", randf() * 0.15))
	await g.all(ws)
	for t in tiles:
		t.tw = 0

# đồ phụ
func use_booster(kind: String, x: int, y: int, x2 := 0, y2 := 0) -> bool:
	if busy or over:
		return false
	var t = TL(x, y)
	if kind == "doi":
		var b = TL(x2, y2)
		if t == null or b == null or t.lock or b.lock:
			return false
		busy = true
		swap_tiles(t, b)
		g.snd.play("swap")
		await anim_hop(t, b)
		if _comboable(t, b):
			combo(t, b)
		await resolve([Vector2i(t.x, t.y), Vector2i(b.x, b.y)])
		return true
	if C(x, y) == null or not C(x, y).play:
		return false
	busy = true
	if kind == "cuoc":
		g.fx.hoe(x, y)
		await g.wait(0.3).done
		g.fx.shake(0.3)
		g.gfx.chop(g.sx(x), g.sy(y), g.LAY.S)
		hit(x, y, {"big": true})
		add_score(60, x, y)
	if kind == "trau":
		g.scn.cheer("trau")
		line_blast(x, y, "h", 0)
		hit(x, y, {"big": true})
	await resolve(null)
	return true

func run_len(x: int, y: int, k: int) -> int:
	var Kf := func(xx, yy):
		var t = TL(xx, yy)
		return matchable(t) and t.k == k
	var h := 1
	var i := x - 1
	while Kf.call(i, y):
		h += 1
		i -= 1
	i = x + 1
	while Kf.call(i, y):
		h += 1
		i += 1
	var v := 1
	i = y - 1
	while Kf.call(x, i):
		v += 1
		i -= 1
	i = y + 1
	while Kf.call(x, i):
		v += 1
		i += 1
	var sq := 0
	for d in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
		if Kf.call(x + d.x, y) and Kf.call(x, y + d.y) and Kf.call(x + d.x, y + d.y):
			sq = 1
	var hh := h if h >= 3 else 0
	var vv := v if v >= 3 else 0
	if hh and vv:
		return 10
	if maxi(hh, vv) >= 5:
		return 12
	if maxi(hh, vv) == 4:
		return 7
	if sq:
		return 5
	return maxi(hh, vv)

func best_move():
	var best = null
	var bs := -1.0
	for y in H:
		for x in W:
			for d in [Vector2i(1, 0), Vector2i(0, 1)]:
				var a = TL(x, y)
				var b = TL(x + d.x, y + d.y)
				if a == null or b == null or a.lock or b.lock or a.dying or b.dying:
					continue
				var s := 0.0
				if a.sp != "" and b.sp != "":
					s = 20
				elif (a.sp == "rooster" and b.k != EGG) or (b.sp == "rooster" and a.k != EGG):
					s = 15
				else:
					T[y][x] = b
					T[y + d.y][x + d.x] = a
					var s1 := run_len(x, y, b.k) if matchable(b) else 0
					var s2 := run_len(x + d.x, y + d.y, a.k) if matchable(a) else 0
					T[y][x] = a
					T[y + d.y][x + d.x] = b
					if s1 < 3 and s2 < 3:
						continue
					s = maxi(s1, s2) + mini(s1, s2) * 0.3 + (4.0 if (a.sp != "" and s2 >= 3) or (b.sp != "" and s1 >= 3) else 0.0)
				s += (float(y) / H) * 0.6 + randf() * 0.3
				if s > bs:
					bs = s
					best = [a, b]
	return best
