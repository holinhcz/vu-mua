extends RefCounted
# CỜ GÁNH: luật + máy tính nước, dịch 1:1 từ bản web (/mnt/project-files/co-ganh/src/engine.js, makeEngine).
# Bàn 5x5 điểm, i = r*5 + c, hàng 0 ở trên (nhà người 1), hàng 4 ở dưới (nhà người 0).
# Mỗi điểm nối 4 điểm ngang dọc; điểm có (r+c) chẵn nối thêm 4 điểm chéo.
# b[i]: 0 trống, 1 quân người 0, 2 quân người 1. Nước đi = from*25 + to.
# Ván (s) là Dictionary: b (PackedByteArray), turn, ply, quiet, last ({from,to,p} hoặc null), over, winner, end, reps, ganh, vay, took.
# Khóa thế cờ: số nguyên (b đọc như số hệ 3) * 2 + turn, thay cho chuỗi b.join('')+turn của JS (cùng nghĩa).

const N := 25
static var ADJ: Array = []     # ADJ[i] = PackedInt32Array các điểm kề
static var PAIRS: Array = []   # PAIRS[i] = mảng [f, b]: hai đầu một đường đi qua i
static var DIAG: Array = []
static var PW: PackedInt32Array = PackedInt32Array()
static var _ok := false

static func init() -> void:
	if _ok:
		return
	_ok = true
	for i in N:
		var r := i / 5
		var c := i % 5
		var dg := (r + c) % 2 == 0
		DIAG.append(dg)
		var dirs := [[0, 1], [1, 0]]
		if dg:
			dirs += [[1, 1], [1, -1]]
		var a := PackedInt32Array()
		var p := []
		for d in dirs:
			var dr: int = d[0]
			var dc: int = d[1]
			var f := (r + dr) * 5 + c + dc if (r + dr >= 0 and r + dr < 5 and c + dc >= 0 and c + dc < 5) else -1
			var b := (r - dr) * 5 + c - dc if (r - dr >= 0 and r - dr < 5 and c - dc >= 0 and c - dc < 5) else -1
			if f >= 0:
				a.append(f)
			if b >= 0:
				a.append(b)
			if f >= 0 and b >= 0:
				p.append([f, b])
		ADJ.append(a)
		PAIRS.append(p)
	# PW: điểm mạnh (có đường chéo), giữa bàn, ô trung tâm
	for i in N:
		var r := i / 5
		var c := i % 5
		PW.append((3 if DIAG[i] else 0) + (2 if (r > 0 and r < 4 and c > 0 and c < 4) else 0) + (2 if i == 12 else 0))

# thế ban đầu: hàng nhà, hai đầu hàng kế, một đầu hàng giữa
static func new_state(first: int = 0) -> Dictionary:
	init()
	var b := PackedByteArray()
	b.resize(N)
	for c in 5:
		b[c] = 2
		b[20 + c] = 1
	b[5] = 2; b[9] = 2; b[15] = 1; b[19] = 1
	b[10] = 2; b[14] = 1
	var s := {"b": b, "turn": first, "ply": 0, "quiet": 0, "last": null, "over": false, "winner": -1, "end": "", "reps": {},
		"ganh": [0, 0], "vay": [0, 0], "took": [0, 0]}
	s.reps[key(s)] = 1
	return s

static func clone(s: Dictionary) -> Dictionary:
	var l = s.last
	return {"b": (s.b as PackedByteArray).duplicate(), "turn": s.turn, "ply": s.ply, "quiet": s.quiet,
		"last": ({"from": l.from, "to": l.to, "p": l.p} if l != null else null), "over": s.over, "winner": s.winner, "end": s.end,
		"reps": (s.reps as Dictionary).duplicate(), "ganh": (s.ganh as Array).duplicate(), "vay": (s.vay as Array).duplicate(), "took": (s.took as Array).duplicate()}

static func bkey(b: PackedByteArray) -> int:
	var k := 0
	for i in N:
		k = k * 3 + b[i]
	return k

static func key(s: Dictionary) -> int:
	return bkey(s.b) * 2 + int(s.turn)

static func count(b: PackedByteArray, p: int) -> int:
	var n := 0
	for i in N:
		if b[i] == p + 1:
			n += 1
	return n

# quân `to` gánh được: hai đầu một đường qua `to` đều là quân bên kia
static func ganh_at(b: PackedByteArray, to: int, me: int) -> PackedInt32Array:
	var o := 3 - me
	var out := PackedInt32Array()
	for pr in PAIRS[to]:
		if b[pr[0]] == o and b[pr[1]] == o:
			out.append(pr[0])
			out.append(pr[1])
	return out

# chùm quân bên kia (nối theo đường kẻ) không còn điểm trống nào kề
static func trapped(b: PackedByteArray, o: int) -> Array:
	var seen := PackedByteArray()
	seen.resize(N)
	var out := []
	for i in N:
		if b[i] != o or seen[i]:
			continue
		var grp := [i]
		var st := [i]
		seen[i] = 1
		var free := false
		while st.size():
			var k: int = st.pop_back()
			for j in ADJ[k]:
				if b[j] == 0:
					free = true
				elif b[j] == o and not seen[j]:
					seen[j] = 1
					grp.append(j)
					st.append(j)
		if not free:
			out.append(grp)
	return out

static func steps(b: PackedByteArray, me: int) -> PackedInt32Array:
	var mv := PackedInt32Array()
	for i in N:
		if b[i] == me:
			for j in ADJ[i]:
				if b[j] == 0:
					mv.append(i * N + j)
	return mv

# R.mo: luật "mở". Bên kia vừa rời một điểm mà mình bước vô đó gánh được thì bắt buộc phải gánh.
static func forced(s: Dictionary, R: Dictionary):
	if R.is_empty() or not R.get("mo", false) or s.last == null or int(s.last.p) == int(s.turn):
		return null
	var v: int = s.last.from
	var me: int = int(s.turn) + 1
	var b: PackedByteArray = s.b
	if b[v] != 0:
		return null
	var out := PackedInt32Array()
	for j in ADJ[v]:
		if b[j] == me and ganh_at(b, v, me).size():
			out.append(j * N + v)
	return out if out.size() else null

static func legal(s: Dictionary, R: Dictionary) -> PackedInt32Array:
	if s.over:
		return PackedInt32Array()
	var f = forced(s, R)
	return f if f != null else steps(s.b, int(s.turn) + 1)

# đi nước mv trên s (sửa tại chỗ). ev (Array hoặc null) nhận các sự kiện step / ganh / vay / end để diễn hoạt.
static func move(s: Dictionary, mv: int, R: Dictionary, ev = null) -> int:
	var from := mv / N
	var to := mv % N
	var p: int = s.turn
	var me := p + 1
	var o := 3 - me
	var b: PackedByteArray = s.b
	var is_forced := forced(s, R) != null
	b[to] = me
	b[from] = 0
	if ev != null:
		ev.append({"t": "step", "from": from, "to": to, "p": p, "forced": is_forced})
	var took := 0
	var g := ganh_at(b, to, me)
	if g.size():
		for x in g:
			b[x] = me
		took += g.size()
		s.ganh[p] += 1
		if ev != null:
			var pairs := []
			for k in range(0, g.size(), 2):
				pairs.append([g[k], g[k + 1]])
			ev.append({"t": "ganh", "at": to, "pts": Array(g), "pairs": pairs, "p": p})
	var tr := trapped(b, o)
	if tr.size():
		var pts := []
		for grp in tr:
			pts += grp
		for x in pts:
			b[x] = me
		took += pts.size()
		s.vay[p] += 1
		if ev != null:
			ev.append({"t": "vay", "pts": pts, "groups": tr, "p": p})
	s.took[p] += took
	s.last = {"from": from, "to": to, "p": p}
	s.turn = 1 - p
	s.ply += 1
	s.quiet = 0 if took else int(s.quiet) + 1
	var k := key(s)
	s.reps[k] = int(s.reps.get(k, 0)) + 1
	if took:   # ăn quân rồi thì không bao giờ quay lại thế cũ được
		s.reps = {k: 1}
	# hết ván
	if count(b, s.turn) == 0:
		s.over = true; s.winner = p; s.end = "het"
	elif steps(b, int(s.turn) + 1).size() == 0:
		s.over = true; s.winner = p; s.end = "ket"
	elif not R.is_empty() and int(R.get("quiet", 0)) and int(s.quiet) >= int(R.quiet) * 2:
		s.over = true; s.winner = -1; s.end = "quiet"
	elif int(s.reps[k]) >= 3:
		s.over = true; s.winner = -1; s.end = "lap"
	if ev != null and s.over:
		ev.append({"t": "end", "winner": s.winner, "why": s.end})
	return took

# ------------------------------------------------------------ AI
# giá trị thế cờ nhìn từ người p: quân, đường đi, điểm chéo mạnh, giữa bàn an toàn
static func eval_for(b: PackedByteArray, p: int) -> int:
	var me := p + 1
	var o := 3 - me
	var v := 0
	var mm := 0
	var om := 0
	for i in N:
		var x := b[i]
		if not x:
			continue
		var fr := 0
		for j in ADJ[i]:
			if b[j] == 0:
				fr += 1
		if x == me:
			v += 100 + PW[i]; mm += fr
		else:
			v -= 100 + PW[i]; om += fr
	# đe dọa: điểm trống mà một bên gánh được ngay
	var tm := 0
	var to := 0
	for i in N:
		if b[i]:
			continue
		var nm := false
		var no := false
		for j in ADJ[i]:
			if b[j] == me:
				nm = true
			elif b[j] == o:
				no = true
		if nm:
			var g := ganh_at(b, i, me).size()
			if g:
				tm = maxi(tm, g)
		if no:
			var g2 := ganh_at(b, i, o).size()
			if g2:
				to = maxi(to, g2)
	return v + (mm - om) * 4 + tm * 22 - to * 30

const WIN := 100000

# nước ăn trước (theo số quân gánh), rồi tới nước vô điểm mạnh
static func _order(s: Dictionary, mv: PackedInt32Array) -> Array:
	var me: int = int(s.turn) + 1
	var a := []
	for m in mv:
		var to := m % N
		a.append([ganh_at(s.b, to, me).size() * 100 + PW[to], m])
	a.sort_custom(func(x, y): return x[0] > y[0])
	var out := []
	for x in a:
		out.append(x[1])
	return out

# X: {R, t0, lim, nodes, stop, TT} (biến chung của một lần tính, như closure của think() bản JS)
static func _search(X: Dictionary, s: Dictionary, d: int, a: float, bb: float, ply: int) -> float:
	X.nodes += 1
	if (int(X.nodes) & 1023) == 0 and Time.get_ticks_msec() - int(X.t0) > int(X.lim):
		X.stop = true
	if X.stop:
		return 0.0
	if s.over:
		return 0.0 if int(s.winner) < 0 else (float(WIN - ply) if int(s.winner) == int(s.turn) else float(-WIN + ply))
	if d <= 0:
		return float(eval_for(s.b, s.turn))
	var k: int = (bkey(s.b) * 2 + int(s.turn)) * 26 + (int(s.last.from) + 1 if s.last != null else 0)
	var TT: Dictionary = X.TT
	var te = TT.get(k)
	var best := -INF
	var bm := -1
	var mv := _order(s, legal(s, X.R))
	if te != null and te.m >= 0:
		var ix := mv.find(te.m)
		if ix > 0:
			mv.remove_at(ix)
			mv.push_front(te.m)
	if te != null and te.d >= d:
		if te.f == 0:
			return te.v
		if te.f == 1 and te.v >= bb:
			return te.v
		if te.f == -1 and te.v <= a:
			return te.v
	var a0 := a
	for m in mv:
		var c := clone(s)
		move(c, m, X.R, null)
		var v := -_search(X, c, d - 1, -bb, -a, ply + 1)
		if X.stop:
			return 0.0
		if v > best:
			best = v; bm = m
		if v > a:
			a = v
		if a >= bb:
			break
	TT[k] = {"d": d, "v": best, "m": bm, "f": (-1 if best <= a0 else (1 if best >= bb else 0))}
	return best

# chọn nước cho máy. level 0..3 = Bé Út, Thằng Tí, Chị Hai, Ông Sáu. budget ms (0 = theo cấp).
static func think(s0: Dictionary, R: Dictionary, level: int, budget: int = 0) -> int:
	init()
	var lv := level
	var root := clone(s0)
	var moves := legal(root, R)
	if moves.size() <= 1:
		return moves[0] if moves.size() else -1
	var depth_max: int = [1, 2, 4, 30][lv] if lv >= 0 and lv < 4 else 2
	var X := {"R": R, "t0": Time.get_ticks_msec(), "nodes": 0, "stop": false, "TT": {},
		"lim": budget if budget > 0 else ([60, 200, 700, 1500][lv] if lv >= 0 and lv < 4 else 600)}
	var best_move: int = moves[0]
	var scored := []
	for m in moves:
		scored.append([0.0, m])
	for d in range(1, depth_max + 1):
		var res := []
		var a := -INF
		var ord: Array = _order(root, moves) if d == 1 else scored.map(func(x): return x[1])
		# cấp yếu chấm điểm đủ mọi nước (để chọn trong mấy nước gần tốt nhất); Ông Sáu chỉ cần nước tốt nhất
		var full := lv < 3
		for m in ord:
			var c := clone(root)
			move(c, m, R, null)
			var v := -_search(X, c, d - 1, -INF, INF if full else -a, 1)
			if X.stop:
				break
			# đừng đi qua đi lại: thế đã gặp bị trừ chút điểm (trừ khi đằng nào cũng thua)
			var seen: int = int(c.reps.get(key(c), 0)) - 1
			if seen > 0 and v > -WIN / 2.0:
				v -= 18 * seen + (40 if c.over else 0)
			res.append([v, m])
			if v > a:
				a = v
		if X.stop and res.size() < ord.size():
			if res.size():
				res.sort_custom(func(x, y): return x[0] > y[0])
				if res[0][0] > scored[0][0]:
					best_move = res[0][1]
			break
		res.sort_custom(func(x, y): return x[0] > y[0])
		scored = res
		best_move = res[0][1]
		if absf(res[0][0]) > WIN / 2.0:
			break
		if Time.get_ticks_msec() - int(X.t0) > int(X.lim) * 0.5:
			break
	# cấp mềm thỉnh thoảng chọn trong mấy nước gần tốt nhất, cho giống con nít chơi
	if lv == 0:
		if randf() < 0.45:
			return moves[randi() % moves.size()]
		var ok := scored.filter(func(x): return x[0] >= scored[0][0] - 60)
		return ok[randi() % ok.size()][1]
	if lv == 1:
		var ok1 := scored.filter(func(x): return x[0] >= scored[0][0] - 25)
		if randf() < 0.3:
			return ok1[randi() % ok1.size()][1]
	if lv == 2:
		var ok2 := scored.filter(func(x): return x[0] >= scored[0][0] - 4)
		return ok2[randi() % ok2.size()][1]
	return best_move
