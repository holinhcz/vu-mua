extends RefCounted
# ĐUA GÀ: luật đua, viết lại 1:1 từ bản web (dua-ga/src/v10b.html: newRace, step, aiDrive, respawn, updateRanks).
# Đơn vị là đơn vị thế giới của web (map 5200 x 4200), góc radian, thời gian giây.
# Bước 1: chưa có vật phẩm, kỹ năng, thời tiết (để bước 2); đường, dốc rơm, ngô tăng tốc, bó rơm, bùn, vịt, nước, trượt đều chạy như web.

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
var keys := {"up": false, "down": false, "left": false, "right": false, "drift": false, "brake": false}
var touch := true
var ev: Array = []   # sự kiện cho âm thanh / chữ: [tên, ...]

const PERS := {
	"hung": {"skill": 1.0, "margin": 0.08, "bridge": 340.0, "trick": 0.5, "drift": false, "aim": false, "col": "#c62828"},
	"hien": {"skill": 0.985, "margin": 0.3, "bridge": 270.0, "trick": 0.15, "drift": false, "aim": false, "col": "#3f7d2a"},
	"lanh": {"skill": 1.01, "margin": 0.15, "bridge": 360.0, "trick": 1.0, "drift": true, "aim": true, "col": "#1e5aa8"},
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

func say(t: String, d := 1.6) -> void:
	msg = {"t": t, "life": d}

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

func hit(r, dur: float) -> bool:
	if r.hopT > 0 or r.fallT > 0:
		return false
	if r.shieldT > 0:
		puff(r.x, r.y, Color("#f2c14e"), 12, 120, 4, 18)
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
	if near(r):
		ev.append(["hit"])
	return true

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
	# dáng (birdPose của web): va = hướng nhìn đã làm mượt
	var pose := {}
	var occA := 1.0

func new_race(order: Array, chars: Array, sel: int, nlaps: int, dif: int) -> void:
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
		var lane: float = (0.45 if k % 2 else -0.45) * M.WD[idx]
		var ch: Dictionary = chars[ci]
		var r := Racer.new()
		r.ch = ch
		r.id = String(ch.id)
		r.isPlayer = ci == sel
		r.st = {"spd": float(ch.spd), "acc": float(ch.acc), "turn": float(ch.turn)}
		r.x = M.PX[idx] + M.NX[idx] * lane
		r.y = M.PY[idx] + M.NY[idx] * lane
		r.a = M.TA[idx]
		r.md = r.a
		r.idx = idx
		r.prog = -(4 + row * 7)
		r.off = lane
		r.rank = k
		var pk: String = "lanh" if r.isPlayer else String(pers[k % pers.size()])
		r.ai = {"pers": pk, "lane": randf() * 1.2 - 0.6, "laneCur": lane / M.WD[idx], "skill": base * (0.97 + randf() * 0.05) * float(PERS[pk].skill), "laneT": 0.0}
		racers.append(r)
	for r in racers:
		if r.isPlayer:
			player = r
	player.ai.lane = 0.0
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
		if not racing:
			r.ctlThr = 0.0
			r.ctlSteer = 0.0
			r.ctlDrift = false
		r.boostT = maxf(0, r.boostT - dt)
		r.kickT = maxf(0, r.kickT - dt)
		r.shieldT = maxf(0, r.shieldT - dt)
		r.mudT = maxf(0, r.mudT - dt)
		r.slipT = maxf(0, r.slipT - dt)
		if racing and not r.finished:
			r.gauge = minf(1.0, r.gauge + dt * (1 + r.rank * 0.09) / 15.0)
		if r.fallT > 0:
			r.fallT -= dt
			if r.fallT <= 0:
				respawn(r)
			continue
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
				r.trick = 0
				r.trickRot = 0.0
		var air: bool = r.z > 6
		r.inMud = false
		if r.mudT <= 0 and not air:
			for t in traps:
				if t.kind == "bun" and Vector2(t.x - r.x, t.y - r.y).length() < float(t.r):
					r.inMud = true
					break
		var wet := 0.0
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
				parts.append({"x": r.x - cos(r.a) * 14, "y": r.y - sin(r.a) * 14, "h": 2.0, "vh": 50.0, "vx": (randf() - 0.5) * 40, "vy": (randf() - 0.5) * 40, "life": 0.5, "max": 0.5, "c": Color("#8fc4d8") if zn == "ruong" or zn == "song" else (Color("#3f8030") if zn == "che" else Color("#5f8f32")), "s": 4.0})
			if r.inMud and randf() < 0.5:
				parts.append({"x": r.x, "y": r.y, "h": 2.0, "vh": 70.0, "vx": (randf() - 0.5) * 60, "vy": (randf() - 0.5) * 60, "life": 0.5, "max": 0.5, "c": Color("#5b3a1d"), "s": 4.0})
			if not offroad and absf(r.spd) > 200 and randf() < 0.35:
				parts.append({"x": r.x - cos(r.a) * 14, "y": r.y - sin(r.a) * 14, "h": 2.0, "vh": 30.0, "vx": (randf() - 0.5) * 30, "vy": (randf() - 0.5) * 30, "life": 0.5, "max": 0.5, "c": Color(214 / 255.0, 186 / 255.0, 136 / 255.0, 0.85), "s": 6.0})
			if r.boostT > 0 and randf() < 0.8:
				parts.append({"x": r.x - cos(r.a) * 18, "y": r.y - sin(r.a) * 18, "h": 16.0, "vh": 20.0, "vx": -cos(r.a) * 80 + (randf() - 0.5) * 50, "vy": -sin(r.a) * 80 + (randf() - 0.5) * 50, "life": 0.35, "max": 0.35, "c": Color("#ff7a1a") if randf() < 0.5 else Color("#ffd23f"), "s": 6.0})
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
				if not r.isPlayer and randf() < float(PERS.get(r.ai.pers, PERS.hien).trick):
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
				a.spd *= 0.985
				b.spd *= 0.985
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
	msg.life -= dt
	shake = maxf(0, shake - dt)
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
