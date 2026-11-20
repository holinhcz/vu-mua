extends RefCounted
# CỜ CARO: luật + máy. Bàn 15x15, 5 con liền (ngang, dọc, chéo) là thắng.
# Luật "chặn 2 đầu" (tuỳ chọn): 5 con mà 2 đầu đều bị quân địch chặn thì không tính.
# Bàn = PackedInt32Array 225 ô: 0 trống, 1 X (người đi trước / mày), 2 O.
# Máy: chấm điểm từng ô theo thế cờ (4 hướng) cho cả công lẫn thủ, mức cao dò trước bằng alpha-beta.

const N := 15
const NN := 225
const DIRS := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]

# điểm thế cờ
const S_FIVE := 100000000
const S_OPEN4 := 1000000
const S_FOUR := 100000
const S_OPEN3 := 8000
const S_THREE := 600
const S_OPEN2 := 300
const S_TWO := 30
const S_ONE := 3

static func new_board() -> PackedInt32Array:
	var b := PackedInt32Array()
	b.resize(NN)
	b.fill(0)
	return b

static func at(b: PackedInt32Array, x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= N or y >= N:
		return -1
	return b[y * N + x]

# ------------------------------------------------------------ thắng
# trả mảng 5+ ô thắng (chỉ số) qua nước vừa đi i, hoặc [] nếu chưa
static func win_line(b: PackedInt32Array, i: int, block2: bool) -> Array:
	var p := b[i]
	if p <= 0:
		return []
	var x := i % N
	var y := i / N
	var q := 3 - p
	for d in DIRS:
		var cells := [i]
		var k := 1
		while at(b, x + d.x * k, y + d.y * k) == p:
			cells.append((y + d.y * k) * N + x + d.x * k)
			k += 1
		var e1 := at(b, x + d.x * k, y + d.y * k)
		k = 1
		while at(b, x - d.x * k, y - d.y * k) == p:
			cells.push_front((y - d.y * k) * N + x - d.x * k)
			k += 1
		var e2 := at(b, x - d.x * k, y - d.y * k)
		if cells.size() >= 5:
			if block2 and e1 == q and e2 == q:
				continue
			return cells
	return []

static func full(b: PackedInt32Array) -> bool:
	for v in b:
		if v == 0:
			return false
	return true

# ------------------------------------------------------------ chấm điểm 1 ô cho phe p (giả sử p đặt vô ô i)
static func _dir_shape(b: PackedInt32Array, x: int, y: int, dx: int, dy: int, p: int) -> int:
	# trả mã thế: 6 five, 5 open4, 4 four, 3 open3, 2 three, 1 open2/two..., chấm trực tiếp ra điểm
	var L := 0
	while at(b, x - dx * (L + 1), y - dy * (L + 1)) == p:
		L += 1
	var R := 0
	while at(b, x + dx * (R + 1), y + dy * (R + 1)) == p:
		R += 1
	var n := 1 + L + R
	var eL := at(b, x - dx * (L + 1), y - dy * (L + 1))   # ô ngay sau chuỗi
	var eR := at(b, x + dx * (R + 1), y + dy * (R + 1))
	var oL := eL == 0
	var oR := eR == 0
	if n >= 5:
		return S_FIVE
	# chuỗi sau 1 ô trống (thế gãy: XX_X, X_XXX ...)
	var gL := 0
	if oL:
		while at(b, x - dx * (L + 2 + gL), y - dy * (L + 2 + gL)) == p:
			gL += 1
	var gR := 0
	if oR:
		while at(b, x + dx * (R + 2 + gR), y + dy * (R + 2 + gR)) == p:
			gR += 1
	if n == 4:
		if oL and oR:
			return S_OPEN4
		if oL or oR:
			return S_FOUR
		return 0
	# 4 gãy: lấp 1 ô thành 5
	if n + gL >= 4 or n + gR >= 4:
		return S_FOUR
	# khoảng trống tối đa 2 phía (để biết có đủ chỗ làm 5 không)
	var spL := 0
	while spL < 5 and at(b, x - dx * (L + 1 + spL), y - dy * (L + 1 + spL)) in [0, p]:
		spL += 1
	var spR := 0
	while spR < 5 and at(b, x + dx * (R + 1 + spR), y + dy * (R + 1 + spR)) in [0, p]:
		spR += 1
	if n + spL + spR < 5:
		return 0
	if n == 3:
		if oL and oR and (spL >= 2 or spR >= 2):
			return S_OPEN3
		return S_THREE
	# 3 gãy: X_XX, XX_X
	if n + gL == 3 or n + gR == 3:
		var g := gL if n + gL == 3 else gR
		var farL: int
		var farR: int
		if g == gL:
			farL = at(b, x - dx * (L + 2 + gL), y - dy * (L + 2 + gL))
			farR = eR
		else:
			farL = eL
			farR = at(b, x + dx * (R + 2 + gR), y + dy * (R + 2 + gR))
		if farL == 0 and farR == 0:
			return S_OPEN3 * 3 / 4
		return S_THREE
	if n == 2:
		if oL and oR:
			return S_OPEN2
		return S_TWO
	if oL and oR:
		return S_ONE * 2
	return S_ONE

static func cell_score(b: PackedInt32Array, i: int, p: int) -> int:
	var x := i % N
	var y := i / N
	var tot := 0
	var fours := 0
	var threes := 0
	for d in DIRS:
		var s := _dir_shape(b, x, y, d.x, d.y, p)
		if s >= S_FIVE:
			return S_FIVE
		if s >= S_FOUR:
			fours += 1
		elif s >= S_OPEN3 * 3 / 4:
			threes += 1
		tot += s
	# đòn đôi
	if fours >= 2 or (fours >= 1 and threes >= 1):
		tot += S_OPEN4 / 2
	elif threes >= 2:
		tot += S_FOUR * 2
	return tot

# các ô trống gần quân (cách <= 2)
static func candidates(b: PackedInt32Array) -> PackedInt32Array:
	var mark := PackedByteArray()
	mark.resize(NN)
	mark.fill(0)
	var any := false
	for i in NN:
		if b[i] != 0:
			any = true
			var x := i % N
			var y := i / N
			for dy in range(-2, 3):
				var yy := y + dy
				if yy < 0 or yy >= N:
					continue
				for dx in range(-2, 3):
					var xx := x + dx
					if xx < 0 or xx >= N:
						continue
					if absi(dx) == 2 and absi(dy) == 1 or absi(dy) == 2 and absi(dx) == 1:
						continue
					mark[yy * N + xx] = 1
	var out := PackedInt32Array()
	if not any:
		out.append(7 * N + 7)
		return out
	for i in NN:
		if mark[i] and b[i] == 0:
			out.append(i)
	return out

# danh sách [điểm, ô] xếp giảm dần cho phe p đi
static func ranked(b: PackedInt32Array, p: int, defw := 0.9) -> Array:
	var q := 3 - p
	var out := []
	for i in candidates(b):
		var a := cell_score(b, i, p)
		var d := cell_score(b, i, q)
		var s: float
		if a >= S_FIVE:
			s = 1e12
		elif d >= S_FIVE:
			s = 1e11
		else:
			s = a + d * defw
		# gần giữa bàn hơn chút
		var x := i % N
		var y := i / N
		s += 6 - (absi(x - 7) + absi(y - 7)) * 0.4
		out.append([s, i, a, d])
	out.sort_custom(func(u, v): return u[0] > v[0])
	return out

# ------------------------------------------------------------ máy chọn nước
# level 0 Bé Út, 1 Thằng Tí, 2 Chị Hai, 3 Ông Sáu
static func think(b0: PackedInt32Array, p: int, level: int, seed: int, budget_ms: int = 900) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var b := b0.duplicate()
	var r := ranked(b, p)
	if r.is_empty():
		return -1
	if r.size() == 1:
		return r[0][1]
	# thắng ngay / chặn 5 luôn làm (trừ Bé Út đôi khi sót chặn)
	if r[0][0] >= 1e12:
		return r[0][1]
	if level == 0:
		if r[0][0] >= 1e11 and rng.randf() < 0.7:
			return r[0][1]
		# chọn ngẫu nhiên trong mấy ô khá
		var k := mini(6, r.size())
		var w := 0.0
		for j in k:
			w += 1.0 / (j + 1)
		var t := rng.randf() * w
		for j in k:
			t -= 1.0 / (j + 1)
			if t <= 0:
				return r[j][1]
		return r[0][1]
	if r[0][0] >= 1e11:
		return r[0][1]
	if level == 1:
		# tham: điểm cao nhất, hơi ngẫu nhiên giữa các ô gần bằng, thủ yếu hơn chút
		var r1 := ranked(b, p, 0.7)
		var top: float = r1[0][0]
		var pool := []
		for e in r1:
			if e[0] >= top * 0.92:
				pool.append(e[1])
		return pool[rng.randi() % pool.size()]
	# Chị Hai / Ông Sáu: alpha-beta
	var depth_max := 3 if level == 2 else 7
	var width := 8 if level == 2 else 10
	var t0 := Time.get_ticks_msec()
	var best: int = r[0][1]
	var ctx := {"t0": t0, "budget": budget_ms if level == 3 else 400, "stop": false}
	var d := 1 if level == 2 else 2
	while d <= depth_max:
		var res := _root(b, p, d, width, ctx, r)
		if ctx.stop:
			break
		best = res
		d += 1
	return best

static func _root(b: PackedInt32Array, p: int, depth: int, width: int, ctx: Dictionary, r: Array) -> int:
	var alpha := -INF
	var beta := INF
	var best: int = r[0][1]
	var n := mini(width, r.size())
	for j in n:
		var i: int = r[j][1]
		b[i] = p
		var v: float
		if r[j][2] >= S_FIVE:
			v = 1e15
		else:
			v = -_neg(b, 3 - p, depth - 1, -beta, -alpha, width, ctx)
		b[i] = 0
		if ctx.stop:
			return best
		if v > alpha:
			alpha = v
			best = i
	return best

static func _neg(b: PackedInt32Array, p: int, depth: int, alpha: float, beta: float, width: int, ctx: Dictionary) -> float:
	if Time.get_ticks_msec() - int(ctx.t0) > int(ctx.budget):
		ctx.stop = true
		return 0.0
	var r := ranked(b, p)
	if r.is_empty():
		return 0.0
	# p thắng ngay được
	if r[0][2] >= S_FIVE:
		return 1e14 + depth
	if depth <= 0:
		# lượng giá: thế mạnh nhất của bên đi trừ thế mạnh nhất bên kia
		var mine := 0.0
		var theirs := 0.0
		for e in r:
			mine = maxf(mine, e[2])
			theirs = maxf(theirs, e[3])
		if theirs < S_FIVE and mine >= S_OPEN4:
			return 1e12   # bên đi tạo được 4 mở / đòn đôi, bên kia không có 5 để gỡ
		return window_eval(b, p)
	var n := mini(width, r.size())
	# bị đe doạ 5: chỉ xét ô chặn
	if r[0][3] >= S_FIVE:
		n = 1
	var best := -INF
	for j in n:
		var i: int = r[j][1]
		b[i] = p
		var v := -_neg(b, 3 - p, depth - 1, -beta, -alpha, width, ctx)
		b[i] = 0
		if ctx.stop:
			return 0.0
		if v > best:
			best = v
		if v > alpha:
			alpha = v
		if alpha >= beta:
			break
	return best

# lượng giá cả bàn: trượt cửa sổ 5 ô trên mọi hàng / cột / chéo; cửa sổ chỉ có quân 1 phe thì cộng điểm phe đó
const WV := [0.0, 1.0, 12.0, 160.0, 2400.0, 1e7]
static var _wins := PackedInt32Array()   # mỗi cửa sổ 5 chỉ số ô liền nhau
static func _build_wins() -> void:
	var w := PackedInt32Array()
	for y in N:
		for x in N:
			for d in DIRS:
				var ex: int = x + d.x * 4
				var ey: int = y + d.y * 4
				if ex < 0 or ex >= N or ey < 0 or ey >= N:
					continue
				for k in 5:
					w.append((y + d.y * k) * N + x + d.x * k)
	_wins = w

static func window_eval(b: PackedInt32Array, p: int) -> float:
	if _wins.is_empty():
		_build_wins()
	var sp := 0.0
	var sq := 0.0
	var n := _wins.size()
	var j := 0
	while j < n:
		var cp := 0
		var cq := 0
		for k in 5:
			var v := b[_wins[j + k]]
			if v == p:
				cp += 1
			elif v != 0:
				cq += 1
		if cq == 0:
			sp += WV[cp]
		elif cp == 0:
			sq += WV[cq]
		j += 5
	# bên đi có lợi 1 nhịp
	return sp * 1.5 - sq
