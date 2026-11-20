extends RefCounted
# ĐUA GÀ: luật đua, viết lại 1:1 từ bản web (dua-ga/src/v10b.html: newRace, step, aiDrive, respawn, updateRanks).
# Đơn vị là đơn vị thế giới của web (map 5200 x 4200), góc radian, thời gian giây.
# Bước 2: thêm thúng ? + 7 vật phẩm, kỹ năng 17 con, mưa quê (đường trơn), AI dùng đồ / kỹ năng như web.

const TAU_ := TAU
const NEAR := 8.0
const RAMP_L := 28.0
const RAMP_H := 24.0

var M   # dg_map (dữ liệu đường)
var racers: Array = []
var player = null
var state := "menu"     # menu, count, race, done, result
var clock := 0.0
var race_t := 0.0
var count_t := 0.0
var done_t := 0.0
var finish_count := 0
var laps := 3
var diff := 1
var sel_char := 0
var auto := false
var wrong_t := 0.0
var shake := 0.0
var rank_pop := 0.0
var prev_rank := 5
var msg := {"t": "", "life": 0.0}
var cam := {"x": 0.0, "y": 0.0, "th": 0.0, "base": 0.0}
var CH := 70.0
var CH0 := 70.0
var CDIST := 220.0
var traps: Array = []
var ducks: Array = []
var duck_spots: Array = []
var parts: Array = []
var HZ: Array = []
var keys := {"up": false, "down": false, "left": false, "right": false, "drift": false, "brake": false, "item": false, "ability": false, "trick": false}
var boxes: Array = []
var eggs: Array = []
var nuts: Array = []
var rings: Array = []
var bolts: Array = []
var splats: Array = []
var flash := 0.0
var rain_mode := "random"
var weather := {"k": 0.0, "on": false, "warned": false, "next": 1e9, "end": 0.0}
const IKEYS := ["ot", "trung", "chuoi", "dua", "bun", "rom", "may"]
const INAME := {"ot": "Ớt Hiểm", "trung": "Trứng Ném", "chuoi": "Vỏ Chuối", "dua": "Dừa Lăn", "bun": "Vũng Bùn", "rom": "Khiên Rơm", "may": "Mây Giông"}
var touch := true
var tt := false
var ghost_rec: Array = []   # đua tính giờ: x, y, hướng mỗi 0.1 giây
const FEED_STEP := 0.025
var ev: Array = []   # sự kiện cho âm thanh / chữ: [tên, ...]

const PERS := {
	"hung": {"skill": 1.0, "margin": 0.08, "bridge": 340.0, "useMin": 0.2, "useRnd": 1.0, "trick": 0.5, "drift": false, "aim": false, "col": "#c62828"},
	"hien": {"skill": 0.985, "margin": 0.3, "bridge": 270.0, "useMin": 1.5, "useRnd": 3.0, "trick": 0.15, "drift": false, "aim": false, "col": "#3f7d2a"},
	"lanh": {"skill": 1.01, "margin": 0.15, "bridge": 360.0, "useMin": 0.6, "useRnd": 2.0, "trick": 1.0, "drift": true, "aim": true, "col": "#1e5aa8"},
}

func _init(m) -> void:
	M = m

static func wrapA(a: float) -> float:
	while a > PI:
		a -= TAU
	while a < -PI:
		a += TAU
	return a

static func sstep(u: float) -> float:
	return u * u * (3.0 - 2.0 * u)

func say(t: String, d := 1.6, k := "") -> void:
	msg = {"t": t, "life": d, "k": k if k != "" else ("big" if t == t.to_upper() else "")}

func near(r) -> bool:
	return r.isPlayer or Vector2(r.x - player.x, r.y - player.y).length() < 600.0

func puff(x: float, y: float, c: Color, n: int, sp: float, size: float, h := 10.0) -> void:
	for i in n:
		var a := randf() * TAU
		var v := sp * (0.3 + randf())
		parts.append({"x": x, "y": y, "h": h + randf() * 10.0, "vh": 40.0 + randf() * 80.0, "vx": cos(a) * v, "vy": sin(a) * v, "life": 0.5 + randf() * 0.5, "max": 1.0, "c": c, "s": size * (0.6 + randf() * 0.8)})

func feathers(r) -> void:
	for i in 12:
		var a := randf() * TAU
		var v := 60.0 + randf() * 120.0
		parts.append({"x": r.x, "y": r.y, "h": 20.0, "vh": 80.0 + randf() * 120.0, "vx": cos(a) * v, "vy": sin(a) * v, "life": 1.0 + randf() * 0.6, "max": 1.6, "c": r.ch.color if randf() < 0.5 else r.ch.dark, "s": 5.0, "feather": true, "rot": randf() * 6.0})

func hit(r, dur: float, src = null) -> bool:
	if r.hopT > 0 or r.fallT > 0:
		return false
	if r.shieldT > 0:
		puff(r.x, r.y, Color("#f2c14e"), 12, 120, 4, 18)
		if r.isPlayer:
			ev.append(["shield"])
		return false
	r.spinT = maxf(r.spinT, dur)
	r.spd *= 0.3
	r.boostT = 0.0
	r.drift = 0
	r.driftT = 0.0
	r.tier = 0
	feathers(r)
	if r.isPlayer:
		shake = 0.4
	if src != null and src is Racer and src.isPlayer and r != src:
		say("Trúng " + String(r.ch.name) + "!", 1.0)
		ev.append(["mis", "hit"])
	if near(r):
		ev.append(["hit"])
	return true

# ------------------------------------------------------------------ vật phẩm, kỹ năng
func roll_item(rank: int) -> String:
	var t := rank / 5.0
	var w := [["ot", 2 + 2.5 * t], ["trung", 3.0], ["chuoi", 3 - 1.4 * t], ["dua", 1.4 + 1.6 * t], ["bun", 2 - 0.8 * t], ["rom", 2.0], ["may", 2.4 * t if t > 0.5 else 0.15]]
	var sm := 0.0
	for q in w:
		sm += q[1]
	var x := randf() * sm
	for q in w:
		x -= q[1]
		if x <= 0:
			return q[0]
	return "ot"

func fire_egg(r, da: float) -> void:
	var a: float = r.a + da
	eggs.append({"x": r.x + cos(a) * 24, "y": r.y + sin(a) * 24, "a": a, "v": maxf(720.0, r.spd + 400), "owner": r, "life": 2.4, "age": 0.0, "idx": r.idx, "spin": 0.0})

func _behind(r, d: float) -> Vector2:
	return Vector2(r.x - cos(r.a) * d, r.y - sin(r.a) * d)

func use_item(r) -> void:
	if r.item == "" or r.rollT > 0 or r.spinT > 0 or r.hopT > 0 or r.fallT > 0:
		return
	var k: String = r.item
	if r.isPlayer:
		ev.append(["mis", "item"])
	var l: int = r.lvl
	r.item = ""
	r.lvl = 0
	if r.uses > 1:
		r.uses -= 1
		r.item = k
		r.lvl = l
	else:
		r.uses = 0
	match k:
		"ot":
			r.boostT = maxf(r.boostT, [0.0, 0.8, 1.2, 1.7][l])
			r.boostPow = 1.55
			if r.isPlayer:
				ev.append(["boost"])
		"trung":
			for sp in ([0.0] if l == 1 else ([-0.1, 0.1] if l == 2 else [-0.24, 0.0, 0.24])):
				fire_egg(r, sp)
			if r.isPlayer:
				ev.append(["throw"])
		"chuoi":
			for i in l:
				var b := _behind(r, 32 + i * 36)
				traps.append({"kind": "chuoi", "x": b.x, "y": b.y, "r": 18.0, "life": 40.0, "owner": r, "arm": 0.8})
		"dua":
			var offs := [0.0] if l == 1 else ([-0.35, 0.35] if l == 2 else [-0.5, 0.0, 0.5])
			for o in offs:
				nuts.append({"s": r.prog + 3, "o": clampf(r.off / M.WD[r.idx] * 0.5 + o, -0.8, 0.8), "v": maxf(640.0, r.spd + 260), "owner": r, "life": 5.0, "age": 0.0, "rot": 0.0, "x": r.x, "y": r.y, "bounce": 0.0})
			if r.isPlayer:
				ev.append(["throw"])
		"bun":
			var b := _behind(r, 40)
			traps.append({"kind": "bun", "x": b.x, "y": b.y, "r": [0.0, 30.0, 36.0, 44.0][l], "life": 14.0, "owner": r, "arm": 0.8})
		"rom":
			r.shieldT = maxf(r.shieldT, [0.0, 3.0, 5.0, 7.0][l])
			if r.isPlayer:
				ev.append(["shield"])
		"may":
			flash = 0.35
			ev.append(["zap"])
			for o in racers:
				if o != r and not o.finished and (l == 3 or o.prog > r.prog):
					if hit(o, [0.0, 0.8, 1.2, 1.6][l], r):
						bolts.append({"r": o, "life": 1.0})

func _ring(r, c := "255,236,180") -> void:
	rings.append({"x": r.x, "y": r.y, "t": 0.0, "c": c})

func _hop(r, ahead: int, dur: float, pounce: bool) -> void:
	var N: int = M.N
	var j = (r.idx + ahead) % N
	var o := clampf(r.off, -M.WD[j] * 0.6, M.WD[j] * 0.6)
	r.hop = {"fx": r.x, "fy": r.y, "tx": M.PX[j] + M.NX[j] * o, "ty": M.PY[j] + M.NY[j] * o, "j": j, "dur": dur, "pounce": pounce}
	r.hopT = dur

func _cone(r, rad: float, ang: float, dur: float) -> void:
	for o in racers:
		if o == r or o.finished:
			continue
		var dx: float = o.x - r.x
		var dy: float = o.y - r.y
		if sqrt(dx * dx + dy * dy) < rad and absf(wrapA(atan2(dy, dx) - r.a)) < ang:
			hit(o, dur, r)

func use_ability(r) -> void:
	if r.gauge < 1 or r.spinT > 0 or r.hopT > 0 or r.fallT > 0:
		return
	r.gauge = 0.0
	var id: String = r.id
	if r.isPlayer:
		say(String(r.ch.ab) + "!", 1.2)
	var nr := near(r)
	match id:
		"vang":
			r.boostT = maxf(r.boostT, 2.2)
			r.boostPow = 1.62
			if r.isPlayer:
				ev.append(["boost"])
		"trong":
			_ring(r)
			ev.append(["crow"])
			for o in racers:
				if o != r and not o.finished and Vector2(o.x - r.x, o.y - r.y).length() < 300:
					hit(o, 1.1, r)
		"mai":
			for sp in [-0.22, 0.0, 0.22]:
				fire_egg(r, sp)
			ev.append(["throw"])
		"tay":
			r.shieldT = maxf(r.shieldT, 5.0)
			if r.isPlayer:
				ev.append(["shield"])
		"vit":
			r.mudT = 6.0
			r.boostT = maxf(r.boostT, 1.0)
			r.boostPow = 1.3
		"tre":
			r.boostT = maxf(r.boostT, 1.5)
			r.boostPow = 1.5
			r.kickT = 1.5
			if nr:
				ev.append(["boost"])
		"ngong":
			_ring(r, "255,255,255")
			ev.append(["honk"])
			_cone(r, 400, 0.7, 1.0)
		"dongtao":
			r.stompN = 3
			r.stompT = 0.0
			r.stp = []
		"delua":
			r.chirpN = 3
			r.chirpT = 0.0
			r.chp = []
			r.boostT = maxf(r.boostT, 1.6)
			r.boostPow = 1.38
		"cho":
			r.boostT = maxf(r.boostT, 2.5)
			r.boostPow = 1.42
			r.kickT = 2.5
			if nr:
				ev.append(["bark"])
		"meo":
			_hop(r, 30, 0.65, true)
			if nr:
				ev.append(["meow"])
		"cuu":
			r.shieldT = maxf(r.shieldT, 4.5)
			r.kickT = 4.5
			if nr:
				ev.append(["baa"])
		"de":
			r.boostT = maxf(r.boostT, 1.0)
			r.boostPow = 1.7
			if nr:
				ev.append(["bleat"])
			_cone(r, 270, 0.6, 1.0)
		"heo":
			r.mudT = 6.0
			r.boostT = maxf(r.boostT, 1.0)
			r.boostPow = 1.3
			traps.append({"kind": "bun", "x": r.x - cos(r.a) * 40, "y": r.y - sin(r.a) * 40, "r": 44.0, "life": 14.0, "owner": r, "arm": 0.8})
			if nr:
				ev.append(["oink"])
		"bo":
			r.boostT = maxf(r.boostT, 6.0)
			r.boostPow = 1.24
			if nr:
				ev.append(["moo"])
		"trau":
			r.shieldT = maxf(r.shieldT, 3.0)
			r.boostT = maxf(r.boostT, 3.0)
			r.boostPow = 1.32
			r.kickT = 3.0
			if nr:
				ev.append(["low"])
		"ac":
			_hop(r, 44, 0.8, false)
			if r.isPlayer:
				ev.append(["whoosh"])

# Dậm Đất / Gáy Thách Đấu: mỗi nhịp một vòng, con nào gần mà nhịp này chưa trúng thì trúng
func stomp(r) -> void:
	if near(r):
		ev.append(["stomp"])
		shake = maxf(shake, 0.28 if r.isPlayer else 0.14)
	_ring(r, "200,160,110")
	puff(r.x, r.y, Color("#d8c09a"), 12, 140, 5, 10)
	for o in racers:
		if o == r or o.finished or r.stp.has(o):
			continue
		if Vector2(o.x - r.x, o.y - r.y).length() < 220 and hit(o, 0.85, r):
			r.stp.append(o)

func chirp(r) -> void:
	if near(r):
		ev.append(["chirp"])
	_ring(r, "255,214,120")
	for o in racers:
		if o == r or o.finished or r.chp.has(o):
			continue
		if Vector2(o.x - r.x, o.y - r.y).length() < 230 and hit(o, 0.8, r):
			r.chp.append(o)

class Racer extends RefCounted:
	var ch: Dictionary
	var id := ""
	var st := {}
	var x := 0.0
	var y := 0.0
	var a := 0.0
	var md := 0.0
	var spd := 0.0
	var steer := 0.0
	var idx := 0
	var prog := 0.0
	var off := 0.0
	var z := 0.0
	var vz := 0.0
	var rampH := 0.0
	var trick := 0
	var trickRot := 0.0
	var ctlSteer := 0.0
	var ctlThr := 0.0
	var ctlBrake := false
	var ctlDrift := false
	var lapTimes: Array = []
	var hat := ""
	var lapStart := 0.0
	var gauge := 0.0
	var boostT := 0.0
	var boostPow := 1.4
	var spinT := 0.0
	var spinVis := 0.0
	var shieldT := 0.0
	var mudT := 0.0
	var hopT := 0.0
	var run := 0.0
	var finished := false
	var finT := 0.0
	var place := 0
	var lapShown := 0
	var rank := 0
	var drift := 0
	var driftT := 0.0
	var tier := 0
	var slipT := 0.0
	var fallT := 0.0
	var fallX := 0.0
	var fallY := 0.0
	var inMud := false
	var kickT := 0.0
	var isPlayer := false
	var ai := {}
	var item := ""
	var lvl := 0
	var uses := 0
	var rollT := 0.0
	var hop := {}
	var stompN := 0
	var stompT := 0.0
	var stp: Array = []
	var chirpN := 0
	var chirpT := 0.0
	var chp: Array = []
	# dáng (birdPose của web): va = hướng nhìn đã làm mượt
	var pose := {}
	var occA := 1.0

# opts: tt (đua tính giờ: chạy một mình, không thúng, cầm sẵn 3 ớt cấp 2), up (đồ ăn đã cho: id -> {spd,acc,turn}), hat (đồ con mình đội)
func new_race(order: Array, chars: Array, sel: int, nlaps: int, dif: int, opts := {}) -> void:
	tt = bool(opts.get("tt", false))
	ghost_rec = []
	laps = nlaps
	diff = dif
	sel_char = sel
	traps = []
	for m in M.STATIC_MUD:
		var q: Dictionary = m.duplicate()
		q["kind"] = "bun"
		traps.append(q)
	parts = []
	ducks = []
	eggs = []
	nuts = []
	rings = []
	bolts = []
	splats = []
	flash = 0.0
	boxes = []
	for b in ([] if tt else M.D.boxes):
		boxes.append({"x": float(b[0]), "y": float(b[1]), "on": true, "t": 0.0, "ph": randf() * 6.0, "pop": 0.0})
	weather = {"k": 0.0, "on": false, "warned": false, "end": 0.0, "next": 3.0 if rain_mode == "heavy" else (1e9 if rain_mode == "none" else 22.0 + randf() * 12.0)}
	finish_count = 0
	race_t = 0.0
	count_t = 3.6
	done_t = 0.0
	wrong_t = 0.0
	duck_spots = []
	for i in M.DUCK_SPOTS:
		duck_spots.append({"i": int(i), "t": 3.0 + randf() * 4.0})
	var pers := ["hung", "hung", "hien", "lanh", "lanh"]
	pers.shuffle()
	var base: float = [0.84, 0.92, 1.0][dif]
	racers = []
	var N: int = M.N
	for k in order.size():
		var ci: int = order[k]
		var row := k / 2
		var idx := (N - 4 - row * 7 + N) % N
		var lane: float = 0.0 if tt else (0.45 if k % 2 else -0.45) * M.WD[idx]
		var ch: Dictionary = chars[ci]
		var r := Racer.new()
		r.ch = ch
		r.id = String(ch.id)
		r.isPlayer = ci == sel
		r.st = {"spd": float(ch.spd), "acc": float(ch.acc), "turn": float(ch.turn)}
		if r.isPlayer:
			var up: Dictionary = opts.get("up", {}).get(r.id, {})
			for sk in ["spd", "acc", "turn"]:
				r.st[sk] = float(ch[sk]) * (1 + FEED_STEP * int(up.get(sk, 0)))
			r.hat = String(opts.get("hat", ""))
		r.x = M.PX[idx] + M.NX[idx] * lane
		r.y = M.PY[idx] + M.NY[idx] * lane
		r.a = M.TA[idx]
		r.md = r.a
		r.idx = idx
		r.prog = -(4 + row * 7)
		r.off = lane
		r.rank = k
		var pk: String = "lanh" if r.isPlayer else String(pers[k % pers.size()])
		r.ai = {"pers": pk, "lane": randf() * 1.2 - 0.6, "laneCur": lane / M.WD[idx], "skill": base * (0.97 + randf() * 0.05) * float(PERS[pk].skill), "laneT": 0.0, "useT": 0.0, "abT": 1.0 + randf() * 3.0}
		racers.append(r)
	for r in racers:
		if r.isPlayer:
			player = r
	player.ai.lane = 0.0
	if tt:
		player.item = "ot"
		player.lvl = 2
		player.uses = 3
	prev_rank = player.rank
	rank_pop = 0.0
	cam.base = player.a
	cam.th = player.a
	cam.x = player.x - cos(cam.th) * CDIST
	cam.y = player.y - sin(cam.th) * CDIST
	state = "count"

func update_ranks() -> void:
	var s := racers.duplicate()
	s.sort_custom(func(a, b):
		if a.finished and b.finished:
			return a.finT < b.finT
		if a.finished:
			return true
		if b.finished:
			return false
		return a.prog > b.prog)
	for i in s.size():
		s[i].rank = i

func hazards() -> Array:
	var h := []
	for t in traps:
		h.append(t)
	for b in M.BASKETS:
		h.append(b)
	for d in ducks:
		if not d.fly:
			h.append({"x": d.x, "y": d.y, "r": 16.0})
	return h

func ai_drive(r, dt: float) -> void:
	var P: Dictionary = PERS.get(r.ai.pers, PERS.hien)
	var ag: bool = r.ai.pers == "hung"
	var N: int = M.N
	var look := int(round(6 + r.spd / 45.0))
	var j = ((r.idx + look) % N + N) % N
	var wj: float = M.WD[j]
	var wide: bool = M.wide
	var lane: float = r.ai.lane
	var lim := 0.35 if (M.BR[j] or M.BR[r.idx]) and not wide else 0.75
	if P.aim:
		var bd := 60
		var o = null
		for t in M.AIM:
			var d: int = int(t.i) - r.idx
			if d < 0:
				d += N
			if d > 3 and d < bd:
				bd = d
				o = float(t.o)
		if o != null:
			lane = o
	if ag and not r.isPlayer:
		var tg = null
		var bd := 220.0
		for o in racers:
			if o == r or o.finished or o.fallT > 0:
				continue
			var dx: float = o.x - r.x
			var dy: float = o.y - r.y
			var d := sqrt(dx * dx + dy * dy)
			if d < bd and dx * cos(r.a) + dy * sin(r.a) > 20:
				bd = d
				tg = o
		if tg != null:
			lane = clampf(tg.off / M.WD[tg.idx], -0.7, 0.7)
	for t in HZ:
		var dx: float = t.x - r.x
		var dy: float = t.y - r.y
		var d := sqrt(dx * dx + dy * dy)
		if d < 260 and dx * cos(r.a) + dy * sin(r.a) > 0:
			var toff: float = ((t.x - M.PX[j]) * M.NX[j] + (t.y - M.PY[j]) * M.NY[j]) / wj
			var rr: float = (float(t.r) + 14.0) / wj
			if absf(toff - lane) < rr + P.margin:
				lane = toff - rr - P.margin - 0.05 if toff > 0 else toff + rr + P.margin + 0.05
	lane = clampf(lane, -lim, lim)
	r.ai.laneCur = lerpf(r.ai.laneCur, lane, minf(1.0, dt * 3.0))
	var tx: float = M.PX[j] + M.NX[j] * r.ai.laneCur * wj
	var ty: float = M.PY[j] + M.NY[j] * r.ai.laneCur * wj
	var diffA := wrapA(atan2(ty - r.y, tx - r.x) - r.a)
	r.ctlSteer = clampf(diffA * 3.0, -1, 1)
	r.ctlThr = 0.4 if absf(diffA) > 0.7 else 1.0
	r.ctlBrake = false
	r.ctlDrift = false
	if not wide and (M.BR[(r.idx + 8) % N] or M.BR[r.idx]) and r.spd > P.bridge:
		r.ctlThr = 0.0
	if r.ai.pers == "hien" and weather.k > 0.5 and absf(diffA) > 0.25 and r.spd > 300:
		r.ctlThr = 0.0
	if P.drift and not M.BR[r.idx] and not M.BR[(r.idx + 14) % N]:
		var ahead := wrapA(M.TA[(r.idx + 16) % N] - M.TA[r.idx])
		if r.drift:
			r.ctlDrift = not (r.tier == 2 or absf(wrapA(M.TA[(r.idx + 6) % N] - M.TA[r.idx])) < 0.1)
		elif absf(ahead) > 0.5 and r.spd > 260 and signf(r.ctlSteer) == signf(ahead) and absf(r.ctlSteer) > 0.3:
			r.ctlDrift = true
	if not r.isPlayer:
		r.ai.laneT -= dt
		if r.ai.laneT < 0:
			r.ai.laneT = 2.0 + randf() * 3.0
			r.ai.lane = randf() * 1.2 - 0.6
	if r.finished:
		return
	if r.item != "":
		r.ai.useT -= dt
		if r.ai.useT <= 0:
			var k: String = r.item
			var go := false
			match k:
				"ot":
					go = absf(wrapA(M.TA[(r.idx + 25) % N] - M.TA[r.idx])) < 0.35 and not M.BR[(r.idx + 20) % N]
				"trung":
					for o in racers:
						if o != r and Vector2(o.x - r.x, o.y - r.y).length() < (600.0 if ag else 450.0) and absf(wrapA(atan2(o.y - r.y, o.x - r.x) - r.a)) < (0.6 if ag else 0.45):
							go = true
				"dua":
					for o in racers:
						if o != r and not o.finished and o.prog > r.prog and o.prog - r.prog < (110 if ag else 70):
							go = true
					go = go or r.ai.useT < -6
				"bun", "chuoi":
					for o in racers:
						if o != r and o.prog < r.prog and r.prog - o.prog < (40 if ag else 25):
							go = true
					go = go or r.ai.useT < -6
				"rom":
					go = ag or r.ai.useT < -8
					for e in eggs:
						if e.owner != r and Vector2(e.x - r.x, e.y - r.y).length() < 200:
							go = true
				_:
					go = true
			if go:
				use_item(r)
	if r.gauge >= 1:
		r.ai.abT -= dt
		if r.ai.abT <= 0:
			var id: String = r.id
			var go := true
			var any := func(rad: float, ang: float, ahead: float) -> bool:
				for o in racers:
					if o == r or o.finished:
						continue
					var dx: float = o.x - r.x
					var dy: float = o.y - r.y
					if ahead > 0:
						if o.prog > r.prog and o.prog - r.prog < ahead:
							return true
						continue
					if sqrt(dx * dx + dy * dy) < rad and (ang >= 4 or absf(wrapA(atan2(dy, dx) - r.a)) < ang):
						return true
				return false
			match id:
				"trong":
					go = any.call(260.0, 9.0, 0.0) or r.ai.abT < -8
				"vang", "ac":
					go = absf(wrapA(M.TA[(r.idx + 30) % N] - M.TA[r.idx])) < 0.5 and not M.BR[(r.idx + 25) % N]
				"vit":
					go = ["ruong", "muong", "song", "suoi"].has(M.ZN[r.idx]) or r.ai.abT < -10
				"tre":
					go = any.call(0.0, 9.0, 20.0) or r.ai.abT < -8
				"delua":
					go = any.call(200.0, 9.0, 0.0) or r.ai.abT < -8
				"dongtao":
					go = any.call(190.0, 9.0, 0.0) or r.ai.abT < -8
				"ngong":
					go = any.call(380.0, 0.6, 0.0) or r.ai.abT < -10
			if go:
				use_ability(r)
				r.ai.abT = 1.0 + randf() * 3.0

func start_fall(r) -> void:
	r.fallT = 1.3
	r.fallX = r.x
	r.fallY = r.y
	r.spd = 0.0
	r.drift = 0
	r.boostT = 0.0
	puff(r.x, r.y, Color("#9fd3ea"), 16, 140, 6, 4)
	puff(r.x, r.y, Color("#ffffff"), 8, 90, 4, 4)
	if near(r):
		ev.append(["splash"])
	if r.isPlayer:
		say(String(M.map.get("fall", "Rớt nước!")), 1.4)

func respawn(r) -> void:
	var N: int = M.N
	var i = (r.idx - 6 + N) % N
	while M.BR[i]:
		i = (i - 1 + N) % N
	var d: int = r.idx - i
	if d < 0:
		d += N
	r.prog -= d
	r.idx = i
	r.x = M.PX[i]
	r.y = M.PY[i]
	r.a = M.TA[i]
	r.md = r.a
	r.spd = 0.0
	r.off = 0.0
	r.spinT = 0.0
	r.shieldT = maxf(r.shieldT, 1.0)

func step(dt: float) -> void:
	clock += dt
	var N: int = M.N
	if state == "count":
		var before := ceili(count_t)
		count_t -= dt
		var after := ceili(count_t)
		if after != before and after > 0 and after <= 3:
			ev.append(["beep"])
		if count_t <= 0:
			state = "race"
			ev.append(["go"])
			say("XUẤT PHÁT!", 1.0)
	var racing := state == "race" or state == "done" or state == "result"
	if state == "race" or state == "done":
		race_t += dt
	# mưa quê: thỉnh thoảng kéo tới, đường trơn
	if state == "race" or state == "done":
		if not weather.on and not weather.warned and race_t > weather.next - 2.5:
			weather.warned = true
			say("Trời sắp mưa!", 1.6)
		if not weather.on and race_t > weather.next:
			weather.on = true
			weather.end = race_t + (22.0 + randf() * 8.0 if rain_mode == "heavy" else 11.0 + randf() * 4.0)
			say("Mưa quê! Đường trơn", 1.6)
		if weather.on and rain_mode == "heavy" and randf() < dt * 0.07:
			flash = maxf(flash, 0.22)
			ev.append(["thunder"])
		if weather.on and race_t > weather.end:
			weather.on = false
			weather.warned = false
			weather.next = race_t + (10.0 + randf() * 6.0 if rain_mode == "heavy" else 38.0 + randf() * 25.0)
	weather.k = lerpf(weather.k, 1.0 if weather.on else 0.0, minf(1.0, dt * 0.8))
	update_ranks()
	HZ = hazards()
	# vịt qua đường
	if racing:
		for sp in duck_spots:
			sp.t -= dt
			if sp.t <= 0:
				sp.t = 6.0 + randf() * 6.0
				var dir := -1 if randf() < 0.5 else 1
				var i: int = sp.i
				for k in 3:
					var j := (i + k * 2) % N
					ducks.append({"i": j, "o": -dir * (M.WD[j] + 60 + k * 26), "dir": dir, "x": 0.0, "y": 0.0, "run": 0.0, "fly": 0.0, "h": 0.0, "life": 9.0})
	for d in ducks:
		d.life -= dt
		d.run += dt * 14
		if d.fly > 0:
			d.fly += dt
			d.h += dt * 120
			d.o += d.dir * dt * 160
		else:
			d.o += d.dir * dt * 60
		d.x = M.PX[d.i] + M.NX[d.i] * d.o
		d.y = M.PY[d.i] + M.NY[d.i] * d.o
		if absf(d.o) > M.WD[d.i] + 90 and signf(d.o) == d.dir:
			d.life = 0.0
	ducks = ducks.filter(func(d): return d.life > 0 and d.fly < 1.5)
	for r in racers:
		if r.isPlayer and not r.finished and not auto:
			r.ctlSteer = (1.0 if keys.right else 0.0) - (1.0 if keys.left else 0.0)
			r.ctlThr = 1.0 if (keys.up or touch) else 0.0
			r.ctlBrake = keys.down or keys.brake
			r.ctlDrift = keys.drift
		else:
			ai_drive(r, dt)
			if r.isPlayer and not r.finished:
				var ms := (1.0 if keys.right else 0.0) - (1.0 if keys.left else 0.0)
				if ms != 0:
					r.ctlSteer = ms
					var ln := clampf(r.off / M.WD[r.idx], -0.8, 0.8)
					r.ai.lane = ln
					r.ai.laneCur = ln
				if keys.down or keys.brake:
					r.ctlBrake = true
				if keys.drift:
					r.ctlDrift = true
					r.ctlThr = 1.0
		if r.isPlayer and not r.finished:
			if keys.item:
				keys.item = false
				if racing:
					use_item(r)
			if keys.ability:
				keys.ability = false
				if racing:
					use_ability(r)
		if not racing:
			r.ctlThr = 0.0
			r.ctlSteer = 0.0
			r.ctlDrift = false
		r.boostT = maxf(0, r.boostT - dt)
		r.kickT = maxf(0, r.kickT - dt)
		r.shieldT = maxf(0, r.shieldT - dt)
		r.mudT = maxf(0, r.mudT - dt)
		r.slipT = maxf(0, r.slipT - dt)
		if r.chirpN > 0 and not r.finished:
			r.chirpT -= dt
			if r.chirpT <= 0:
				r.chirpT = 0.3
				r.chirpN -= 1
				chirp(r)
		if r.stompN > 0 and not r.finished:
			r.stompT -= dt
			if r.stompT <= 0:
				r.stompT = 0.42
				r.stompN -= 1
				stomp(r)
		if r.rollT > 0:
			var b4 := floori(r.rollT * 14)
			r.rollT -= dt
			if r.isPlayer and floori(r.rollT * 14) != b4 and r.rollT > 0:
				ev.append(["tick"])
			if r.rollT <= 0 and r.isPlayer:
				ev.append(["pick"])
		if racing and not r.finished:
			r.gauge = minf(1.0, r.gauge + dt * (1 + r.rank * 0.09) / 15.0)
		if r.fallT > 0:
			r.fallT -= dt
			if r.fallT <= 0:
				respawn(r)
			continue
		if r.isPlayer and keys.trick:
			keys.trick = false
			if r.z > 8 and not r.trick:
				r.trick = 1
				ev.append(["tier", 2])
		if r.z > 0:
			r.z += r.vz * dt
			r.vz -= 620 * dt
			if r.trick:
				r.trickRot += dt * 13
			if r.z <= 0:
				r.z = 0.0
				r.vz = 0.0
				puff(r.x, r.y, Color("#e8dcc0"), 8, 80, 5, 2)
				if near(r):
					ev.append(["thud"])
				if r.trick:
					r.boostT = maxf(r.boostT, 1.0)
					r.boostPow = 1.42
					if r.isPlayer:
						say("Nhào lộn!", 1.0)
						ev.append(["boost"])
						ev.append(["mis", "trick"])
				r.trick = 0
				r.trickRot = 0.0
		if r.hopT > 0:
			r.hopT -= dt
			var ht := 1.0 - maxf(0.0, r.hopT) / float(r.hop.dur)
			r.x = lerpf(r.hop.fx, r.hop.tx, ht)
			r.y = lerpf(r.hop.fy, r.hop.ty, ht)
			r.a += wrapA(M.TA[r.hop.j] - r.a) * minf(1.0, dt * 4)
			r.md = r.a
			if r.hopT <= 0:
				var hd: int = int(r.hop.j) - r.idx
				if hd < 0:
					hd += N
				r.prog += hd
				r.idx = int(r.hop.j)
				r.a = M.TA[r.idx]
				r.md = r.a
				puff(r.x, r.y, Color("#e8dcc0"), 10, 80, 6, 4)
				if r.hop.pounce:
					_ring(r, "255,214,120")
					for o in racers:
						if o != r and not o.finished and Vector2(o.x - r.x, o.y - r.y).length() < 170:
							hit(o, 1.0, r)
			continue
		var air: bool = r.z > 6
		r.inMud = false
		if r.mudT <= 0 and not air:
			for t in traps:
				if t.kind == "bun" and Vector2(t.x - r.x, t.y - r.y).length() < float(t.r):
					r.inMud = true
					break
		var wet: float = weather.k
		var grip := lerpf(11.0, 2.6, wet)
		if r.spinT > 0:
			r.spinT -= dt
			r.spinVis += dt * 14
			r.spd *= pow(0.15, dt)
			grip = 1.0
		else:
			r.spinVis = 0.0
			r.steer = lerpf(r.steer, r.ctlSteer, minf(1.0, dt * 10))
			var offroad: bool = absf(r.off) > M.WD[r.idx] + 6 and r.mudT <= 0
			var maxS: float = 430.0 * r.st.spd * (1.0 if r.isPlayer and not r.finished else float(r.ai.skill))
			if not r.isPlayer:
				var gap: float = (r.prog - player.prog) / N
				if gap > 0.12:
					maxS *= 0.93
				elif gap < -0.08:
					maxS *= 1.05
			if r.finished:
				maxS *= 0.6
			if offroad:
				maxS *= float(M.OFFROAD.get(M.ZN[r.idx], 0.58))
			if r.inMud:
				maxS *= 0.45
			if wet > 0.3:
				maxS *= 1.0 - 0.05 * wet
			if r.boostT > 0:
				maxS *= r.boostPow
			if r.mudT > 0:
				maxS *= 1.05
			if r.ctlBrake:
				r.spd -= (700.0 if r.spd > 0 else 220.0) * dt
				if r.spd < -120:
					r.spd = -120.0
			elif r.ctlThr > 0:
				r.spd += (900.0 if r.boostT > 0 else 320.0 * r.st.acc) * r.ctlThr * dt
			else:
				r.spd *= pow(0.45, dt)
			if r.spd > maxS:
				r.spd = lerpf(r.spd, maxS, minf(1.0, dt * (4.0 if offroad or r.inMud else 2.5)))
			var f := clampf(r.spd / 120.0, -1, 1)
			var turn: float = 2.5 * r.st.turn * (1.0 - 0.25 * minf(1.0, absf(r.spd) / 500.0))
			if not r.drift and r.ctlDrift and absf(r.ctlSteer) > 0.3 and r.spd > 200 and not offroad:
				r.drift = int(signf(r.ctlSteer))
				r.driftT = 0.0
				r.tier = 0
			if r.drift:
				if not r.ctlDrift or r.spd < 150 or offroad:
					if r.tier > 0:
						r.boostT = maxf(r.boostT, 1.05 if r.tier == 2 else 0.55)
						r.boostPow = 1.42 if r.tier == 2 else 1.32
						if r.isPlayer:
							ev.append(["boost"])
							ev.append(["mis", "turbo"])
					r.drift = 0
					r.tier = 0
				else:
					r.driftT += dt
					var nt := 2 if r.driftT > 1.6 else (1 if r.driftT > 0.75 else 0)
					if nt > r.tier:
						r.tier = nt
						if r.isPlayer:
							ev.append(["tier", nt])
					r.a += r.drift * (0.62 + 0.55 * r.steer * r.drift) * turn * 1.1 * dt
					grip = minf(grip, 3.2)
					r.spd *= pow(0.96, dt)
					if randf() < 0.7:
						var c := Color("#ff9d2e") if r.tier == 2 else (Color("#6ec6ff") if r.tier == 1 else Color("#fff6e0"))
						for s in [-1, 1]:
							parts.append({"x": r.x - cos(r.a) * 10 + M.NX[r.idx] * s * 8, "y": r.y - sin(r.a) * 10 + M.NY[r.idx] * s * 8, "h": 3.0, "vh": 60.0, "vx": (randf() - 0.5) * 60, "vy": (randf() - 0.5) * 60, "life": 0.25, "max": 0.25, "c": c, "s": 4.0 if r.tier else 3.0})
			else:
				r.a += r.steer * turn * f * dt
			if r.slipT > 0:
				grip = minf(grip, 1.2)
			var zn: String = M.ZN[r.idx]
			if offroad and absf(r.spd) > 90 and randf() < 0.6:
				parts.append({"grow": 1, "x": r.x - cos(r.a) * 14, "y": r.y - sin(r.a) * 14, "h": 2.0, "vh": 50.0, "vx": (randf() - 0.5) * 40, "vy": (randf() - 0.5) * 40, "life": 0.5, "max": 0.5, "c": Color("#8fc4d8") if zn == "ruong" or zn == "song" else (Color("#3f8030") if zn == "che" else Color("#5f8f32")), "s": 4.0})
			if r.inMud and randf() < 0.5:
				parts.append({"x": r.x, "y": r.y, "h": 2.0, "vh": 70.0, "vx": (randf() - 0.5) * 60, "vy": (randf() - 0.5) * 60, "life": 0.5, "max": 0.5, "c": Color("#5b3a1d"), "s": 4.0})
			if not offroad and absf(r.spd) > 200 and randf() < 0.35:
				parts.append({"x": r.x - cos(r.a) * 14, "y": r.y - sin(r.a) * 14, "h": 2.0, "vh": 30.0, "vx": (randf() - 0.5) * 30, "vy": (randf() - 0.5) * 30, "life": 0.5, "max": 0.5, "c": Color(170 / 255.0, 200 / 255.0, 220 / 255.0, 0.8) if wet > 0.5 else Color(214 / 255.0, 186 / 255.0, 136 / 255.0, 0.85), "s": 6.0, "grow": 1, "dust": 0 if wet > 0.5 else 2, "v": randi() % 3})
			if r.boostT > 0:
				var ca := cos(r.a)
				var sa := sin(r.a)
				for k in 2:
					var sd := (-1.0 if randf() < 0.5 else 1.0) * (10 + randf() * 16)
					parts.append({"x": r.x - ca * 6 - sa * sd, "y": r.y - sa * 6 + ca * sd, "h": 4 + randf() * 34, "vh": 0.0, "vx": -ca * 240, "vy": -sa * 240, "life": 0.26, "max": 0.26, "c": Color(1, 250 / 255.0, 235 / 255.0), "s": 2.4, "streak": 1})
				if randf() < 0.45:
					parts.append({"x": r.x - ca * 14, "y": r.y - sa * 14, "h": 3.0, "vh": 30.0, "vx": -ca * 50 + (randf() - 0.5) * 50, "vy": -sa * 50 + (randf() - 0.5) * 50, "life": 0.6, "max": 0.6, "c": Color("#ecd9b0"), "s": 5.0, "grow": 1})
		# hướng chạy theo sau hướng mặt: bám đường kém thì trượt
		r.md += wrapA(r.a - r.md) * minf(1.0, dt * grip)
		r.x += cos(r.md) * r.spd * dt
		r.y += sin(r.md) * r.spd * dt
		r.run += absf(r.spd) * dt * 0.07
		r.x = clampf(r.x, 20, M.WORLD_W - 20)
		r.y = clampf(r.y, 20, M.WORLD_H - 20)
		var ni: int = M.nearest(r.x, r.y, r.idx, 14, 22)
		var dd: int = ni - r.idx
		if dd > N / 2:
			dd -= N
		if dd < -N / 2:
			dd += N
		r.prog += dd
		r.idx = ni
		r.off = (r.x - M.PX[ni]) * M.NX[ni] + (r.y - M.PY[ni]) * M.NY[ni]
		var cl: float = M.clamp_w(ni)
		if (r.off > cl and M.FR[ni]) or (r.off < -cl and M.FL[ni]):
			var lim2 := cl * signf(r.off)
			var ex: float = r.off - lim2
			r.x -= M.NX[ni] * ex
			r.y -= M.NY[ni] * ex
			r.off = lim2
			r.spd *= pow(0.25, dt)
			r.a += wrapA(M.TA[ni] - r.a) * minf(1.0, dt * 3)
			r.md = r.a
		# nước: mương, ao, rớt khỏi cầu khỉ
		if not air and not (r.mudT > 0 and r.id == "vit") and M.in_water(r.x, r.y) and not (M.BR[ni] and absf(r.off) <= M.WD[ni] + 2):
			start_fall(r)
			continue
		# dốc rơm
		r.rampH = 0.0
		for rp in M.RAMPS:
			if r.z > 0 or r.spd < 150:
				break
			var ri: int = rp.i
			var dx: float = r.x - M.PX[ri]
			var dy: float = r.y - M.PY[ri]
			var al: float = dx * cos(M.TA[ri]) + dy * sin(M.TA[ri])
			var lat: float = (dx * M.NX[ri] + dy * M.NY[ri]) / M.WD[ri]
			if al > -RAMP_L and al <= RAMP_L - 10 and lat > rp.o0 and lat < rp.o1:
				r.rampH = (al + RAMP_L) / (2 * RAMP_L) * RAMP_H
			if al > RAMP_L - 10 and al < RAMP_L + 6 and lat > rp.o0 - 0.05 and lat < rp.o1 + 0.05:
				r.z = RAMP_H
				r.vz = 130 + r.spd * 0.1
				r.drift = 0
				if r.isPlayer:
					ev.append(["mis", "jump"])
				elif randf() < float(PERS.get(r.ai.pers, PERS.hien).trick):
					r.trick = 1
		# ngô tăng tốc
		if not air:
			for p in M.PADS:
				var pi: int = p.i
				var dx: float = r.x - p.x
				var dy: float = r.y - p.y
				var al: float = dx * cos(M.TA[pi]) + dy * sin(M.TA[pi])
				var lat: float = dx * M.NX[pi] + dy * M.NY[pi]
				if absf(al) < 28 and absf(lat) < 30 and r.boostT < 0.6:
					r.boostT = 0.9
					r.boostPow = 1.45
					if r.isPlayer:
						ev.append(["pad"])
						ev.append(["mis", "pad"])
		# bó rơm chắn đường
		if not air:
			for b in M.BASKETS:
				var dx: float = r.x - b.x
				var dy: float = r.y - b.y
				var d2 := sqrt(dx * dx + dy * dy)
				if d2 < b.r + 12 and d2 > 0:
					var pp: float = b.r + 12 - d2
					r.x += dx / d2 * pp
					r.y += dy / d2 * pp
					if r.spd > 150:
						r.spd *= 0.35
						r.drift = 0
						puff(b.x, b.y, Color("#e6c35c"), 8, 90, 4, 20)
						if near(r):
							ev.append(["thud"])
						if r.isPlayer:
							shake = 0.25
		# vịt
		if not air:
			for dk in ducks:
				if dk.fly:
					continue
				if Vector2(dk.x - r.x, dk.y - r.y).length() < 20:
					dk.fly = 0.01
					if near(r):
						ev.append(["quack"])
					if r.shieldT <= 0:
						hit(r, 0.5)
					puff(dk.x, dk.y, Color("#ffffff"), 6, 80, 4, 14)
		var lap := floori(r.prog / N) + 1
		if lap > r.lapShown and lap >= 2 and lap <= laps + 1:
			r.lapTimes.append(race_t - r.lapStart)
			r.lapStart = race_t
		if r.isPlayer and lap > r.lapShown and lap >= 2 and lap <= laps:
			say("VÒNG CUỐI!" if lap == laps else "VÒNG " + str(lap), 1.5)
			ev.append(["lap"])
		r.lapShown = maxi(r.lapShown, lap)
		if not r.finished and r.prog >= laps * N:
			r.finished = true
			r.finT = race_t
			r.item = ""
			finish_count += 1
			r.place = finish_count
			if r.isPlayer:
				state = "done"
				done_t = 0.0
				say("VỀ NHẤT!" if r.place == 1 else "VỀ ĐÍCH!", 2.5)
				ev.append(["finish", r.place])
		if r.isPlayer and racing and not r.finished:
			var dot := cos(r.a - M.TA[r.idx])
			wrong_t = wrong_t + dt if dot < -0.3 and absf(r.spd) > 40 else 0.0
		# thúng ?: lấy đồ (trùng món thì lên cấp)
		if racing and not r.finished:
			for b in boxes:
				if b.on and Vector2(b.x - r.x, b.y - r.y).length() < 28:
					b.on = false
					b.t = 3.0
					r.gauge = minf(1.0, r.gauge + 0.04)
					var ik := roll_item(r.rank)
					if r.item == ik:
						r.lvl = mini(3, r.lvl + 1)
					else:
						r.item = ik
						r.lvl = 1
					var PP: Dictionary = PERS.get(r.ai.pers, PERS.hien)
					r.ai.useT = float(PP.useMin) + randf() * float(PP.useRnd)
					puff(b.x, b.y, Color("#f2c14e"), 8, 90, 4, 22)
					if near(r):
						_box_burst(b)
					if r.isPlayer:
						r.rollT = 0.85
		# vỏ chuối
		if not air:
			for t in traps:
				if t.get("dead", false) or t.kind != "chuoi":
					continue
				if t.owner == r and t.arm > 0:
					continue
				if Vector2(t.x - r.x, t.y - r.y).length() < float(t.r) + 8:
					t.dead = true
					if hit(r, 0.75, t.owner):
						r.slipT = 0.7
						r.md = r.a + (-0.6 if randf() < 0.5 else 0.6)
						if near(r):
							ev.append(["slip"])
	# chen nhau
	for i in racers.size():
		for j in range(i + 1, racers.size()):
			var a = racers[i]
			var b = racers[j]
			if a.hopT > 0 or b.hopT > 0 or a.fallT > 0 or b.fallT > 0:
				continue
			var dx: float = b.x - a.x
			var dy: float = b.y - a.y
			var d := sqrt(dx * dx + dy * dy)
			if d < 28 and d > 0:
				var p := (28 - d) / 2
				var nx := dx / d
				var ny := dy / d
				a.x -= nx * p
				a.y -= ny * p
				b.x += nx * p
				b.y += ny * p
				if a.kickT > 0 and b.kickT <= 0 and b.spinT <= 0:
					hit(b, 0.8, a)
				elif b.kickT > 0 and a.kickT <= 0 and a.spinT <= 0:
					hit(a, 0.8, b)
				elif a.shieldT > 0 and b.shieldT <= 0:
					hit(b, 0.6, a)
				elif b.shieldT > 0 and a.shieldT <= 0:
					hit(a, 0.6, b)
				else:
					a.spd *= 0.985
					b.spd *= 0.985
	for b in boxes:
		if not b.on:
			b.t -= dt
			if b.t <= 0:
				b.on = true
				b.pop = clock
	_step_eggs(dt)
	_step_nuts(dt)
	for t in traps:
		t.arm = float(t.get("arm", 0)) - dt
	for t in traps:
		t.life = float(t.get("life", 1e9)) - dt
	traps = traps.filter(func(t): return not t.get("dead", false) and float(t.life) > 0)
	for p in parts:
		p.life -= dt
		p.x += p.vx * dt
		p.y += p.vy * dt
		p.vx *= 0.95
		p.vy *= 0.95
		p.h = maxf(0, p.h + p.vh * dt)
		p.vh -= (60.0 if p.has("feather") else 160.0) * dt
		if p.has("rot"):
			p.rot += dt * 4
	parts = parts.filter(func(p): return p.life > 0)
	if parts.size() > 600:
		parts = parts.slice(parts.size() - 600)
	for g in rings:
		g.t += dt
	rings = rings.filter(func(g): return g.t < 0.6)
	for b in bolts:
		b.life -= dt
	bolts = bolts.filter(func(b): return b.life > 0)
	for sp in splats:
		sp.t += dt
	splats = splats.filter(func(sp): return sp.t < sp.life)
	_fx_step(dt)
	flash = maxf(0, flash - dt)
	msg.life -= dt
	shake = maxf(0, shake - dt)
	if tt and state == "race" and not player.finished:
		while ghost_rec.size() / 3.0 * 0.1 <= race_t:
			ghost_rec.append_array([roundi(player.x), roundi(player.y), snappedf(player.a, 0.01)])
	if state == "done":
		done_t += dt
		if done_t > 3.2:
			state = "result"
			ev.append(["result"])
	if player.rank != prev_rank:
		if player.rank < prev_rank and state == "race":
			rank_pop = 0.45
		prev_rank = player.rank
	rank_pop = maxf(0, rank_pop - dt)
	# camera bám sau; lúc đếm ngược nó quay vòng từ phía trước con gà ra sau
	if player.fallT <= 0:
		cam.base += wrapA(player.a - cam.base) * minf(1.0, dt * 4.5)
	var orbit := 0.0
	var dm := 1.0
	if state == "count":
		var u := clampf((count_t - 0.5) / 3.0, 0, 1)
		var e := sstep(u)
		orbit = e * PI * 0.95
		dm = 1 + e * 0.5
	cam.th = cam.base + orbit
	CH = CH0 + player.z * 0.6
	var dist := CDIST * (1.0 + (0.12 if player.boostT > 0 else 0.0)) * dm
	var fx0: float = player.fallX if player.fallT > 0 else player.x
	var fy0: float = player.fallY if player.fallT > 0 else player.y
	cam.x = fx0 - cos(cam.th) * dist
	cam.y = fy0 - sin(cam.th) * dist

func _box_burst(b) -> void:
	var cs := ["#ff4b3e", "#ffd52e", "#ff86b0", "#8fd24a", "#74c23c", "#fff3c4", "#e0262e", "#ffa514"]
	for i in 16:
		var a := randf() * TAU
		var v := 70.0 + randf() * 130.0
		parts.append({"x": b.x, "y": b.y, "h": 22.0, "vh": 90.0 + randf() * 120.0, "vx": cos(a) * v, "vy": sin(a) * v, "life": 0.8 + randf() * 0.6, "max": 1.4, "c": Color(cs[i % 8]), "s": 3.0 if i % 4 == 3 else 5.0, "feather": true, "rot": randf() * 6.0})

func _step_eggs(dt: float) -> void:
	var N: int = M.N
	for e in eggs:
		e.age += dt
		e.life -= dt
		e.spin += dt * 15
		var tgt = null
		var best := 480.0
		for o in racers:
			if o == e.owner or o.hopT > 0 or o.fallT > 0:
				continue
			var dx: float = o.x - e.x
			var dy: float = o.y - e.y
			var d := sqrt(dx * dx + dy * dy)
			if d < best and absf(wrapA(atan2(dy, dx) - e.a)) < 0.7:
				best = d
				tgt = o
		if tgt != null:
			e.a += clampf(wrapA(atan2(tgt.y - e.y, tgt.x - e.x) - e.a), -2.8 * dt, 2.8 * dt)
		else:
			e.a += clampf(wrapA(M.TA[(int(e.idx) + 6) % N] - e.a), -1.5 * dt, 1.5 * dt)
		e.x += cos(e.a) * e.v * dt
		e.y += sin(e.a) * e.v * dt
		e.idx = M.nearest(e.x, e.y, int(e.idx), 10, 24)
		var off: float = (e.x - M.PX[e.idx]) * M.NX[e.idx] + (e.y - M.PY[e.idx]) * M.NY[e.idx]
		if absf(off) > M.WD[e.idx] + 40:
			e.life = 0.0
			puff(e.x, e.y, Color("#fff6e0"), 8, 90, 4, 12)
			puff(e.x, e.y, Color("#f2b705"), 5, 60, 4, 12)
		for b in M.BASKETS:
			if e.life > 0 and Vector2(b.x - e.x, b.y - e.y).length() < float(b.r) + 6:
				e.life = 0.0
				puff(e.x, e.y, Color("#f2b705"), 8, 90, 5, 16)
		for o in racers:
			if e.life <= 0:
				break
			if o == e.owner and e.age < 0.5:
				continue
			if o.hopT > 0 or o.fallT > 0 or o.z > 30:
				continue
			if Vector2(o.x - e.x, o.y - e.y).length() < 24:
				e.life = 0.0
				puff(e.x, e.y, Color("#f2b705"), 10, 100, 5, 16)
				puff(e.x, e.y, Color("#fff6e0"), 8, 100, 4, 16)
				if hit(o, 1.15, e.owner) and o.isPlayer:
					splats.append({"x": randf_range(0.28, 0.72), "y": randf_range(0.2, 0.48), "r": randf_range(0.1, 0.14), "t": 0.0, "life": 2.2, "seed": randi()})
	eggs = eggs.filter(func(e): return e.life > 0)

# dừa lăn theo đường, húc ai trên lối
func _step_nuts(dt: float) -> void:
	var N: int = M.N
	for n in nuts:
		n.age += dt
		n.life -= dt
		n.s += n.v * dt / 12.0
		var i := (floori(n.s) % N + N) % N
		var j := (i + 1) % N
		var u: float = n.s - floor(n.s)
		var w := lerpf(M.WD[i], M.WD[j], u)
		var o := clampf(n.o, -0.85, 0.85) * w
		n.x = lerpf(M.PX[i], M.PX[j], u) + lerpf(M.NX[i], M.NX[j], u) * o
		n.y = lerpf(M.PY[i], M.PY[j], u) + lerpf(M.NY[i], M.NY[j], u) * o
		n.rot += n.v * dt / 16
		n.bounce = absf(sin(n.age * 9)) * 6
		for b in M.BASKETS:
			if Vector2(b.x - n.x, b.y - n.y).length() < float(b.r) + 14:
				n.life = 0.0
				puff(n.x, n.y, Color("#6b4423"), 10, 100, 5, 10)
		for r in racers:
			if n.life <= 0:
				break
			if r == n.owner and n.age < 0.6:
				continue
			if r.hopT > 0 or r.fallT > 0 or r.z > 20:
				continue
			if Vector2(r.x - n.x, r.y - n.y).length() < 28:
				hit(r, 1.0, n.owner)
	nuts = nuts.filter(func(n): return n.life > 0)

# hạt bụi / lửa / bùn theo việc con đua đang làm (fxStep của web, chỉ con gần người chơi)
func _fx_step(dt: float) -> void:
	for r in racers:
		if r.finished or r.fallT > 0 or not near(r):
			continue
		var ca := cos(r.a)
		var sa := sin(r.a)
		var sp := absf(r.spd)
		var air: bool = r.hopT > 0 or r.z > 2
		if r.kickT > 0 and not air and sp > 60 and randf() < dt * 24:
			var sd := -1.0 if randf() < 0.5 else 1.0
			parts.append({"x": r.x - sa * sd * 10, "y": r.y + ca * sd * 10, "h": 3.0, "vh": 110 + randf() * 80, "vx": -sa * sd * (80 + randf() * 80) - ca * 40, "vy": ca * sd * (80 + randf() * 80) - sa * 40, "life": 0.5, "max": 0.5, "c": Color("#7a5634"), "s": 2.2, "drop": 1})
		if r.boostT > 0 and r.boostPow >= 1.55 and not air and randf() < dt * 36:
			var sd := -1.0 if randf() < 0.5 else 1.0
			parts.append({"flame": 1, "x": r.x - ca * 6 - sa * sd * 6, "y": r.y - sa * 6 + ca * sd * 6, "h": 1.0, "vh": 70.0, "vx": -ca * 24, "vy": -sa * 24, "life": 0.36, "max": 0.36, "s": 6.5, "c": Color.WHITE})
		if r.mudT > 0 and not air and sp > 60 and randf() < dt * 22:
			var w: bool = r.id == "vit"
			var sd := -1.0 if randf() < 0.5 else 1.0
			parts.append({"x": r.x - ca * 8 - sa * sd * 8, "y": r.y - sa * 8 + ca * sd * 8, "h": 3.0, "vh": 120 + randf() * 90, "vx": -ca * 90 - sa * sd * 60, "vy": -sa * 90 + ca * sd * 60, "life": 0.55, "max": 0.55, "c": Color("#8fc7de") if w else (Color("#5a3a1c") if randf() < 0.5 else Color("#6e4826")), "s": 2.4 if w else 3.0, "drop": 2 if w else 1})
	for n in nuts:
		if randf() < dt * 12:
			parts.append({"grow": 1, "dust": 2, "v": randi() % 3, "x": n.x, "y": n.y, "h": 1.0, "vh": 20.0, "vx": (randf() - 0.5) * 30, "vy": (randf() - 0.5) * 30, "life": 0.5, "max": 0.5, "c": Color(214 / 255.0, 186 / 255.0, 136 / 255.0, 0.8), "s": 5.0})

# birdPose của web: hướng nhìn, tốc độ quay, gia tốc (để chọn góc vẽ cho mượt)
func bird_pose(r) -> Dictionary:
	var s: Dictionary = r.pose
	if s.is_empty():
		s = {"t": clock, "pa": r.a, "va": r.a, "ps": r.spd, "av": 0.0}
		r.pose = s
	var dt := minf(0.05, maxf(0.0, clock - float(s.t)))
	s.t = clock
	if dt > 0:
		s.av += (clampf(wrapA(r.a - s.pa) / dt, -4, 4) - s.av) * minf(1.0, dt * 3.5)
		s.pa = r.a
		s.ps = r.spd
		s.va += wrapA(r.a - s.va) * minf(1.0, dt * 14)
	return s
