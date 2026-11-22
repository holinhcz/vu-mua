extends RefCounted
# Ô ĂN QUAN: luật + máy tính nước, dịch 1:1 từ bản web (/mnt/project-files/o-an-quan/src/engine.js, makeEngine).
# Ô: 0 = quan trái, 1..5 = hàng dưới (người 0) trái qua phải, 6 = quan phải, 7..11 = hàng trên (người 1) phải qua trái.
# Nước đi = ô*2 + (1 nếu hướng +1 (ngược chiều kim đồng hồ trên màn) còn không 0).
# Ván (s) là Dictionary: c (12 số dân), q [quan trái còn, quan phải còn], qw [ai ăn quan trái, phải] (-1 chưa ai),
# dan, debt (mỗi bên), turn, over, end ("hetquan" / "hetdan" / "dai"), moves.

static func is_q(i: int) -> bool:
	return i == 0 or i == 6

static func qk(i: int) -> int:
	return 0 if i == 0 else 1

static func nx(i: int, d: int) -> int:
	return (i + d + 12) % 12

static func row_start(p: int) -> int:
	return 7 if p else 1

static func new_state(first: int = 0) -> Dictionary:
	return {"c": [0, 5, 5, 5, 5, 5, 0, 5, 5, 5, 5, 5], "q": [1, 1], "qw": [-1, -1], "dan": [0, 0], "debt": [0, 0], "turn": first, "over": false, "end": "", "moves": 0}

static func clone(s: Dictionary) -> Dictionary:
	return {"c": (s.c as Array).duplicate(), "q": (s.q as Array).duplicate(), "qw": (s.qw as Array).duplicate(), "dan": (s.dan as Array).duplicate(),
		"debt": (s.debt as Array).duplicate(), "turn": int(s.turn), "over": bool(s.over), "end": String(s.end), "moves": int(s.moves)}

static func stones(s: Dictionary, i: int) -> int:
	return int(s.c[i]) + (1 if is_q(i) and int(s.q[qk(i)]) else 0)

static func is_non(s: Dictionary, i: int, R: Dictionary) -> bool:
	return bool(R.non) and is_q(i) and int(s.q[qk(i)]) != 0 and int(s.c[i]) < 5

static func quan_of(s: Dictionary, p: int) -> int:
	return (1 if int(s.qw[0]) == p else 0) + (1 if int(s.qw[1]) == p else 0)

static func row_sum(s: Dictionary, p: int) -> int:
	var t := 0
	var b := row_start(p)
	for i in range(b, b + 5):
		t += int(s.c[i])
	return t

static func score(s: Dictionary, p: int, R: Dictionary) -> int:
	return int(s.dan[p]) + int(R.qv) * quan_of(s, p) - int(s.debt[p]) + int(s.debt[1 - p])

static func legal(s: Dictionary, p: int) -> Array:
	var r := []
	var b := row_start(p)
	for i in range(b, b + 5):
		if int(s.c[i]) > 0:
			r.append(i * 2 + 1)
			r.append(i * 2)
	return r

# Một nước cho s.turn. ev (nếu có) gom các sự kiện để diễn hình.
static func move(s: Dictionary, mv: int, R: Dictionary, ev) -> int:
	var p: int = s.turn
	var d := 1 if (mv & 1) else -1
	var i := mv >> 1
	var hand: int = s.c[i]
	var pos := i
	var guard := 0
	var ate := 0
	s.c[i] = 0
	if ev != null:
		ev.append({"t": "pick", "i": i, "n": hand})
	var done := false
	while not done:
		while hand > 0:
			pos = nx(pos, d)
			s.c[pos] = int(s.c[pos]) + 1
			hand -= 1
			if ev != null:
				ev.append({"t": "drop", "i": pos})
		guard += 1
		if guard > 240:
			if ev != null:
				ev.append({"t": "stop", "why": "loop"})
			break
		var n := nx(pos, d)
		if stones(s, n) > 0:
			if is_q(n):
				if ev != null:
					ev.append({"t": "stop", "why": "quan", "i": n})
				break
			hand = s.c[n]
			s.c[n] = 0
			pos = n
			if ev != null:
				ev.append({"t": "pick", "i": n, "n": hand})
			continue
		while true:
			var t := nx(n, d)
			if ev != null:
				ev.append({"t": "tap", "i": n})
			if stones(s, t) == 0:
				if ev != null:
					ev.append({"t": "stop", "why": "done" if ate else "empty2", "i": t})
				done = true
				break
			if is_non(s, t, R):
				if ev != null:
					ev.append({"t": "stop", "why": "non", "i": t})
				done = true
				break
			var dn: int = s.c[t]
			var qq := 0
			s.c[t] = 0
			if is_q(t) and int(s.q[qk(t)]):
				s.q[qk(t)] = 0
				s.qw[qk(t)] = p
				qq = 1
			s.dan[p] = int(s.dan[p]) + dn
			ate += 1
			if ev != null:
				ev.append({"t": "cap", "i": t, "n": dn, "q": qq, "k": qk(t), "p": p, "chain": ate})
			n = nx(t, d)
			if stones(s, n) > 0:
				if ev != null:
					ev.append({"t": "stop", "why": "done", "i": n})
				done = true
				break
	s.turn = 1 - p
	s.moves = int(s.moves) + 1
	return ate

# Hàng nào về chủ hàng đó. Ván dừng vì bên kia không còn dân để rải thì phần còn trong ô quan (dân và quan) về `taker`.
static func finish(s: Dictionary, ev, why: String, taker: int = -1) -> void:
	var got := [row_sum(s, 0), row_sum(s, 1)]
	for p in 2:
		var b := row_start(p)
		for i in range(b, b + 5):
			s.c[i] = 0
	s.dan[0] = int(s.dan[0]) + got[0]
	s.dan[1] = int(s.dan[1]) + got[1]
	var qcells := []
	if taker >= 0:
		for i in [0, 6]:
			var k := qk(i)
			var dn: int = s.c[i]
			var qq: int = s.q[k]
			if not dn and not qq:
				continue
			s.dan[taker] = int(s.dan[taker]) + dn
			s.c[i] = 0
			if qq:
				s.q[k] = 0
				s.qw[k] = taker
			qcells.append({"i": i, "n": dn, "q": qq, "k": k})
	s.over = true
	s.end = why
	if ev != null:
		ev.append({"t": "end", "why": why, "got": got, "taker": taker, "qcells": qcells})

# Đầu lượt: hết ván chưa, hàng trống thì rải lại (lấy dân mình hoặc vay).
static func prep(s: Dictionary, R: Dictionary, ev) -> bool:
	if s.over:
		return false
	if stones(s, 0) == 0 and stones(s, 6) == 0:
		finish(s, ev, "hetquan")
		return false
	if int(s.moves) > 600:
		finish(s, ev, "dai")
		return false
	var p: int = s.turn
	var b := row_start(p)
	if row_sum(s, p) > 0:
		return true
	if int(s.dan[p]) >= 5:
		s.dan[p] = int(s.dan[p]) - 5
		for i in range(b, b + 5):
			s.c[i] = 1
		if ev != null:
			ev.append({"t": "vay", "p": p, "from": p})
		return true
	if bool(R.borrow) and int(s.dan[1 - p]) >= 5:
		s.dan[1 - p] = int(s.dan[1 - p]) - 5
		s.debt[p] = int(s.debt[p]) + 5
		for i in range(b, b + 5):
			s.c[i] = 1
		if ev != null:
			ev.append({"t": "vay", "p": p, "from": 1 - p})
		return true
	finish(s, ev, "hetdan", 1 - p)
	return false

# ------------------------------------------------------------ máy
static func eval_s(s: Dictionary, R: Dictionary) -> float:
	var p: int = s.turn
	return score(s, p, R) - score(s, 1 - p, R) + 0.22 * (row_sum(s, p) - row_sum(s, 1 - p))

static func _nega(X: Dictionary, s: Dictionary, depth: int, a: float, b: float) -> float:
	var R: Dictionary = X.R
	if not prep(s, R, null):
		var p: int = s.turn
		return (score(s, p, R) - score(s, 1 - p, R)) * 1000.0 / 999.0
	if depth == 0:
		return eval_s(s, R)
	X.nodes = int(X.nodes) + 1
	if (int(X.nodes) & 1023) == 0 and Time.get_ticks_msec() > int(X.deadline):
		X.stop = true
	if X.stop:
		return eval_s(s, R)
	var best := -1e9
	for mv in legal(s, s.turn):
		var c := clone(s)
		move(c, mv, R, null)
		var v := -_nega(X, c, depth - 1, -b, -a)
		if v > best:
			best = v
		if v > a:
			a = v
		if a >= b:
			break
	return best

const CFG := [{"d": 1, "t": 200, "noise": 5.0, "rand": 0.4}, {"d": 2, "t": 300, "noise": 1.6, "rand": 0.12}, {"d": 5, "t": 900, "noise": 0.15, "rand": 0.0}, {"d": 14, "t": 1400, "noise": 0.0, "rand": 0.0}]

# level: 0 Dễ, 1 Vừa, 2 Khó, 3 Cao thủ. Chạy được trong Thread (mọi biến đếm nằm trong X).
static func think(s0: Dictionary, R: Dictionary, level: int, _tag: int = 0) -> int:
	var s := clone(s0)
	var ms := legal(s, s.turn)
	if ms.size() <= 1:
		return ms[0] if ms.size() else -1
	var cfg: Dictionary = CFG[clampi(level, 0, 3)]
	if randf() < float(cfg.rand):
		return ms[randi() % ms.size()]
	var X := {"R": R, "nodes": 0, "stop": false, "deadline": Time.get_ticks_msec() + int(cfg.t)}
	var order := ms.duplicate()
	var scores = null
	for d in range(1, int(cfg.d) + 1):
		var cur := []
		for mv in order:
			var c := clone(s)
			move(c, mv, R, null)
			cur.append([-_nega(X, c, d - 1, -1e9, 1e9), mv])
			if X.stop:
				break
		if X.stop and scores != null:
			break
		scores = cur
		scores.sort_custom(func(x, y): return x[0] > y[0])
		var seen := {}
		order = []
		for o in scores:
			order.append(o[1])
			seen[o[1]] = true
		for m in ms:
			if not seen.has(m):
				order.append(m)
		if X.stop:
			break
	var best := -1
	var bv := -1e9
	var noise: float = cfg.noise
	for o in scores:
		var v: float = o[0] + (randf() - 0.5) * 2 * noise + randf() * 0.01
		if v > bv:
			bv = v
			best = o[1]
	return best
