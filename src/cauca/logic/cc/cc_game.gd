extends Control
# CÂU CÁ BỜ KÊNH: viết lại bằng Godot từ bản web (cau-ca/src/js). Gốc này phóng to K lần, mọi con số bên trong là
# css px của web. Đây là phần luật + thế giới: khổ màn và phép chiếu (00_core), đồng hồ / mưa / gió / lục bình /
# ghe hàng / chim / đom đóm / chỗ sủi tăm (04_world), hạt nước + cá quẫy (05_fx), quăng / chờ / nhấp / giật /
# kéo / đứt dây / lên cá (08_game), vòng chính + chạm (10_main). Vẽ ở cc_draw, giao diện ở cc_ui, tiếng ở cc_snd.

signal closed

const D := preload("res://logic/cc/cc_data.gd")
const A := preload("res://logic/cc/cc_art.gd")
const SCN := preload("res://logic/cc/cc_scene.gd")
const DRW := preload("res://logic/cc/cc_draw.gd")
const UIS := preload("res://logic/cc/cc_ui.gd")
const SNDS := preload("res://logic/cc/cc_snd.gd")
const SAVE_PATH := "user://cauca.json"
const ZF := 40.0

var K := 1.0
var embed := true
var L := {}
var S := {}
var W := {}
var G := {}
var FX := {"p": [], "leaps": [], "rain": []}
var tod := {}
var rips := PackedFloat32Array()
var shs := PackedFloat32Array()
var started := false
var scn
var drw
var ui
var snd
var inp: Control
var sched: Array = []
var clock := 0.0
var _save_t := 0.0
var _vs := Vector2.ZERO
var _drop_rip := 0.0
var hinted := {}

func setup(k: float) -> void:
	K = maxf(1.0, k)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	A.K = K
	rips.resize(64)
	shs.resize(32)
	_load()
	_reset_state()
	tod = D.tod_at(S.hour)
	var vs0 := get_viewport_rect().size
	layout(vs0.x / K, vs0.y / K)
	snd = SNDS.new(self)
	add_child(snd)
	scn = SCN.new(self)
	add_child(scn)
	drw = DRW.new(self)
	add_child(drw)
	inp = Control.new()
	inp.mouse_filter = Control.MOUSE_FILTER_STOP
	inp.gui_input.connect(_water_input)
	add_child(inp)
	ui = UIS.new(self)
	add_child(ui)
	await get_tree().process_frame
	resize()
	world_init()
	ui.show_title()

func _reset_state() -> void:
	W = {"t": 0.0, "rain": 0.0, "rainT": 0.0, "rainTarget": 0, "nextRain": rnd(70, 140), "wind": .35, "windT": .35, "cloud": .6, "cloudBase": .6,
		"floatGlow": [0.0, 0.0, 0.0], "rips": [], "spots": [], "props": [], "boat": null, "nextBoat": 50.0, "birds": [], "nextBird": 8.0, "flies": [], "nextJump": 6.0}
	G = {"state": "idle", "t": 0.0, "fl": {"x": 0.0, "z": 10.0, "sink": 0.0, "tilt": 0.0, "dx": 0.0}, "fish": null, "ev": [], "hold": false,
		"ten": 0.0, "over": 0.0, "slack": 0.0, "dist": 0.0, "rodA": 0.0, "rodV": 0.0, "shake": 0.0, "lastTarget": null, "shadow": null, "df": null,
		"anim": null, "biteOpen": 0.0, "biteT": 0.0, "hook": null, "landing": null, "paused": false, "dt": .016, "reelA": 0.0, "tn": 0.0, "tick": 0.0, "idleWait": 0.0}

# ============================================================ tiện ích
static func rnd(a := 1.0, b = null) -> float:
	if b == null:
		return randf() * a
	return a + randf() * (float(b) - a)

static func pick(arr: Array):
	return arr[randi() % arr.size()]

func later(sec: float, fn: Callable) -> void:
	sched.append({"t": clock + sec, "fn": fn})

func _run_sched() -> void:
	var i := 0
	while i < sched.size():
		var s: Dictionary = sched[i]
		if s.t <= clock:
			sched.remove_at(i)
			s.fn.call()
		else:
			i += 1

# ============================================================ lưu (localStorage 'cauca-save-v1' của web)
func _load() -> void:
	S = D.def_save()
	if FileAccess.file_exists(SAVE_PATH):
		var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
		if d is Dictionary:
			S.merge(d, true)
	for k in ["xu", "xp", "lv", "rod", "line", "flo", "cage", "sound", "music", "tut", "orders"]:
		S[k] = int(S[k])
	S.luck = float(S.luck)
	S.hour = float(S.hour)
	if not (S.baits is Dictionary):
		S.baits = {"trun": 999}
	for k in S.baits.keys():
		S.baits[k] = int(S.baits[k])
	if not (S.basket is Array):
		S.basket = []
	if not (S.dex is Dictionary):
		S.dex = {}
	if not (S.stats is Dictionary):
		S.stats = {"casts": 0, "catches": 0, "snaps": 0}
	for k in ["casts", "catches", "snaps"]:
		S.stats[k] = int(S.stats.get(k, 0))
	for k in ["rod", "line", "flo", "cage"]:
		S[k] = clampi(S[k], 0, D.gear(k).size() - 1)
	if not D.BAIT.has(str(S.bait)):
		S.bait = "trun"

func save(now := false) -> void:
	if not now and clock - _save_t < 1.5:
		return
	_save_t = clock
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(S))
		f.close()

func reset_save() -> void:
	S = D.def_save()
	save(true)

# ============================================================ khổ màn + phép chiếu (thế giới: X ngang, z xa, mắt cao 1)
func layout(w: float, h: float) -> void:
	L.W = w
	L.H = h
	L.portrait = h > w * 1.1
	L.yw = h * (0.34 if L.portrait else 0.42)
	L.hor = L.yw - h * 0.07
	L.F = (L.yw - L.hor) * ZF
	L.bankH = maxf(h * (0.30 if L.portrait else 0.34), w / 6 * 1.02)
	L.bankW = L.bankH * 6
	L.bankX = (w - L.bankW) / 2
	L.fgH = h * (0.13 if L.portrait else 0.17)
	L.zNear = L.F / (h - L.hor)
	L.zEdge = L.F / (h - L.fgH * 0.45 - L.hor)
	L.rodButt = Vector2(w * 1.04, h * 1.03) if L.portrait else Vector2(w * 0.9, h * 1.08)
	L.rodTip = Vector2(w * 0.6, h * 0.56) if L.portrait else Vector2(w * 0.68, h * 0.5)

func proj(X: float, z: float) -> Vector2:
	return Vector2(L.W / 2 + L.F * X / z, L.hor + L.F / z)

func unproj(x: float, y: float) -> Vector2:
	var z: float = L.F / maxf(1.0, y - L.hor)
	return Vector2((x - L.W / 2) * z / L.F, z)

func half_x(z: float) -> float:
	return (L.W / 2) * z / L.F

func resize() -> void:
	var vs := get_viewport_rect().size
	_vs = vs
	scale = Vector2(K, K)
	size = vs / K
	layout(vs.x / K, vs.y / K)
	inp.position = Vector2.ZERO
	inp.size = Vector2(L.W, L.H)
	scn.resize()
	drw.resize()
	ui.relayout()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_inside_tree() and _vs != Vector2.ZERO and get_viewport_rect().size != _vs:
		call_deferred("resize")

# ============================================================ thế giới
func ripple(x: float, z: float, a := 1.0) -> void:
	W.rips.append({"x": x, "z": z, "t0": W.t, "a": a})
	if W.rips.size() > 40:
		W.rips = W.rips.slice(W.rips.size() - 40)

func world_init() -> void:
	W.props = []
	for i in 7:
		W.props.append(new_prop(true))
	# bụi sen (ảnh thủy sinh của nông trại): mọc tại chỗ ven 2 bên kênh, không trôi (Link 11-22)
	var sz := [15.0, 21.0, 27.0, 33.0]
	for i in 4:
		var z: float = sz[i] + rnd(-1.5, 1.5)
		var sd := -1.0 if i % 2 == 0 else 1.0
		W.props.append({"z": z, "x": sd * half_x(z) * rnd(.62, .86), "v": 0.0, "k": i, "s": rnd(.9, 1.15), "ph": rnd(TAU), "sen": true})
	W.spots = []
	for i in 2:
		W.spots.append(new_spot())

func new_prop(anywhere: bool) -> Dictionary:
	var z := rnd(10, 34)
	var hx := half_x(z) + 2.5
	return {"z": z, "x": rnd(-hx, hx) if anywhere else -hx - rnd(0, 3), "v": rnd(.05, .12), "k": randi() % 4, "s": rnd(.8, 1.25), "ph": rnd(TAU)}

func new_spot() -> Dictionary:
	var z := rnd(7, minf(30, D.ROD[S.rod].range + 4))
	return {"x": rnd(-half_x(z) * .8, half_x(z) * .8), "z": z, "life": rnd(40, 80), "next": rnd(.5, 2)}

func near_cover(x: float, z: float) -> bool:
	for p in W.props:
		if absf(p.z - z) < 2.2 and absf(p.x - x) < 1.8 * p.s:
			return true
	return false

func near_spot(x: float, z: float):
	for s in W.spots:
		if Vector2(s.x - x, (s.z - z) * .6).length() < 2.4:
			return s
	return null

func world_update(dt: float) -> void:
	W.t += dt
	S.hour = fmod(S.hour + dt * D.HOUR_PER_SEC, 24.0)
	W.nextRain -= dt
	if W.nextRain < 0 and not W.rainTarget:
		W.rainTarget = 1
		W.rainT = rnd(35, 70)
		W.nextRain = rnd(150, 260)
		if started:
			ui.toast("Trời đổ mưa, cá ăn mạnh!", "info")
	if W.rainTarget:
		W.rainT -= dt
		if W.rainT < 0:
			W.rainTarget = 0
	W.rain = lerpf(W.rain, W.rainTarget, dt * .25)
	if randf() < dt * .05:
		W.windT = rnd(.15, .7) + W.rain * .3
	W.wind = lerpf(W.wind, W.windT, dt * .2)
	W.cloud = lerpf(W.cloud, W.cloudBase + W.rain * (1 - W.cloudBase), dt * .1)
	if randf() < dt * .01:
		W.cloudBase = rnd(.35, .85)
	# vòng gợn cho shader
	var keep := []
	for r in W.rips:
		if W.t - r.t0 < 4.2:
			keep.append(r)
	W.rips = keep
	rips.fill(0)
	var rs: Array = keep.slice(maxi(0, keep.size() - 16))
	for i in rs.size():
		var r: Dictionary = rs[i]
		rips[i * 4] = r.x
		rips[i * 4 + 1] = r.z
		rips[i * 4 + 2] = W.t - r.t0
		rips[i * 4 + 3] = r.a
	# lục bình trôi
	for p in W.props:
		if p.has("sen"):
			continue
		p.x += p.v * dt * (1 + W.wind * .5)
		if p.x > half_x(p.z) + 3:
			p.merge(new_prop(false), true)
	W.props.sort_custom(func(a, b): return a.z > b.z)
	# chỗ sủi tăm
	for s in W.spots:
		s.life -= dt
		s.next -= dt
		if s.next < 0:
			s.next = rnd(.6, 2.2)
			var n := 1 + randi() % 3
			for i in n:
				var bx: float = s.x + rnd(-.35, .35)
				var bz: float = s.z + rnd(-.3, .3)
				ripple(bx, bz, .22)
				fx_bubble(bx, bz)
	W.spots = W.spots.filter(func(s): return s.life > 0)
	while W.spots.size() < 2:
		W.spots.append(new_spot())
	# cá quẫy
	W.nextJump -= dt
	if W.nextJump < 0:
		W.nextJump = rnd(5, 13) * (1 - W.rain * .4)
		var z := rnd(8, 34)
		var x := rnd(-half_x(z), half_x(z))
		fx_splash(x, z, .5)
		ripple(x, z, .8)
		if randf() < .6:
			fx_leap(pick(["linh", "mevinh", "he", "sac"]), x, z, .7)
		snd.plop(.8, clampf(z / 34, 0, 1))
	boat_update(dt)
	life_update(dt)

# ------------------------------------------------------------ ghe hàng
func make_order() -> Dictionary:
	var pool := []
	for f in D.FISH:
		if not f.has("junk") and f.rar <= (3 if S.lv >= 4 else 2) and (f.bait.get(S.bait, 0) or S.lv > 1):
			pool.append(f)
	if pool.is_empty():
		pool = [D.fish("ro")]
	var n := 1 + randi() % (3 if S.lv >= 3 else 2)
	var need := {}
	for i in n:
		var cand: Array = pool.filter(func(f): return f.rar <= 2 or i == 0)
		var f: Dictionary = pick(cand)
		need[f.id] = need.get(f.id, 0) + ((1 + randi() % 2) if f.rar == 1 else 1)
	var val := 0
	for id in need:
		var f := D.fish(id)
		val += D.fish_value(f, (f.w[0] + f.w[1]) / 2.0) * need[id]
	var bonus = null
	if randf() < .45:
		var bl := []
		for b in D.BAIT_ORDER.slice(1):
			if D.BAIT[b].lv <= S.lv + 1:
				bl.append(b)
		if bl.size():
			bonus = pick(bl)
	return {"need": need, "xu": int(round(val * 1.7 + 20)), "xp": 12 + need.size() * 6, "bonus": bonus, "who": pick(D.WHO)}

func boat_update(dt: float) -> void:
	W.nextBoat -= dt
	if W.boat == null and W.nextBoat < 0 and G.state != "fight":
		var z := 21.0
		var hx := half_x(z)
		W.boat = {"z": z, "x": -hx - 4, "tx": hx * .25 - .5, "stay": 70.0, "ph": 0.0, "mode": "in", "wake": 0.0, "order": make_order()}
		if started:
			ui.on_boat_arrive()
	var b = W.boat
	if b == null:
		return
	b.ph += dt
	if b.mode == "in":
		b.x += (b.tx - b.x) * dt * .35 + .35 * dt
		if b.x >= b.tx:
			b.x = b.tx
			b.mode = "stay"
	elif b.mode == "stay":
		b.stay -= dt
		if b.stay < 0:
			b.mode = "out"
	else:
		b.x += 1.1 * dt
		if b.x > half_x(b.z) + 5:
			W.boat = null
			W.nextBoat = rnd(110, 170)
			ui.on_boat_leave()
			return
	b.wake -= dt
	if b.mode != "stay" and b.wake < 0:
		b.wake = .35
		ripple(b.x - 1.2, b.z + .1, .5)
	if b.mode == "stay" and b.wake < 0:
		b.wake = 1.6
		ripple(b.x + rnd(-1, 1), b.z, .25)

# ------------------------------------------------------------ chim, đom đóm
func life_update(dt: float) -> void:
	W.nextBird -= dt
	if W.nextBird < 0 and tod.night < .4 and W.rain < .5:
		W.nextBird = rnd(14, 30)
		var dir := 1.0 if randf() < .5 else -1.0
		var y := rnd(L.H * .06, L.yw - L.bankH * .45)
		var n := 1 + randi() % 3
		for i in n:
			W.birds.append({"x": -60 - i * 50 if dir > 0 else L.W + 60 + i * 50, "y": y + rnd(-20, 20) + i * 12, "v": dir * rnd(40, 60), "ph": rnd(TAU), "s": rnd(.8, 1.1) * (.8 if L.portrait else 1.0)})
	for b in W.birds:
		b.x += b.v * dt
		b.ph += dt * 6.5
		b.y += sin(b.ph * .5) * dt * 4
	W.birds = W.birds.filter(func(b): return b.x > -200 and b.x < L.W + 200)
	var want := (26 if L.portrait else 44) if tod.night > .5 else 0
	while W.flies.size() < want:
		W.flies.append({"x": rnd(L.W), "y": rnd(L.yw - L.bankH * .3, L.yw) if randf() < .55 else rnd(L.H * .78, L.H), "ph": rnd(TAU), "vx": rnd(-8, 8), "vy": rnd(-5, 5)})
	if W.flies.size() > want:
		W.flies.resize(want)
	for f in W.flies:
		f.ph += dt
		f.x += (f.vx + sin(f.ph * .7) * 10) * dt
		f.y += (f.vy + cos(f.ph * .9) * 6) * dt
		if f.x < -10:
			f.x = L.W + 10
		if f.x > L.W + 10:
			f.x = -10

# ============================================================ hạt nước (thế giới: X, cao, z)
func fx_drop(x: float, z: float, vx: float, vy: float, vz: float, s := 1.0, life := 1.4) -> void:
	FX.p.append({"k": "drop", "x": x, "y": .02, "z": z, "vx": vx, "vy": vy, "vz": vz, "s": s, "life": life, "age": 0.0})

func fx_splash(x: float, z: float, sz := 1.0) -> void:
	drw.pfx.splash(x, z, sz)   # giọt + hơi nước = CPUParticles2D (cc_fx.gd)
	FX.p.append({"k": "crown", "x": x, "z": z, "y": 0.0, "s": sz, "age": 0.0, "life": .45})

func fx_bubble(x: float, z: float) -> void:
	FX.p.append({"k": "bub", "x": x, "z": z, "y": 0.0, "s": rnd(.6, 1.2), "age": 0.0, "life": rnd(.8, 1.6)})

func fx_wake(x: float, z: float, s := 1.0) -> void:
	FX.p.append({"k": "foam", "x": x, "z": z, "y": 0.0, "s": s, "age": 0.0, "life": 1.2})

func fx_leap(id: String, x: float, z: float, sc := 1.0, dir := 0.0, big := false) -> void:
	if dir == 0.0:
		dir = 1.0 if randf() < .5 else -1.0
	var f := D.fish(id)
	var ln: float = (f.vis if f.size() else .35) * sc
	FX.leaps.append({"id": id, "x": x, "z": z, "dir": dir, "len": ln, "age": 0.0, "dur": 1.0 if big else rnd(.55, .75), "h": .55 if big else rnd(.18, .32), "vx": dir * rnd(.3, .7)})

func fx_update(dt: float) -> void:
	var g := 3.2
	_drop_rip -= dt
	for p in FX.p:
		p.age += dt
		if p.k == "drop":
			p.vy -= g * dt
			p.x += p.vx * dt
			p.y += p.vy * dt
			p.z += p.vz * dt
			if p.y < 0:
				p.age = p.life
				if _drop_rip < 0 and p.s > .8:
					ripple(p.x, p.z, .18)
					_drop_rip = .05
	FX.p = FX.p.filter(func(p): return p.age < p.life)
	for l in FX.leaps:
		var t0: float = l.age
		l.age += dt
		l.x += l.vx * dt
		if t0 == 0:
			fx_splash(l.x, l.z, .6 + l.len)
			ripple(l.x, l.z, 1)
		if t0 < l.dur and l.age >= l.dur:
			fx_splash(l.x, l.z, .8 + l.len * 1.2)
			ripple(l.x, l.z, 1.2)
			snd.plop(1.4, clampf(l.z / 30, 0, .8))
	FX.leaps = FX.leaps.filter(func(l): return l.age < l.dur + .05)
	var want := 0   # mưa rơi = CPUParticles2D (cc_fx.gd)
	while FX.rain.size() < want:
		FX.rain.append({"x": rnd(-50, L.W + 50), "y": rnd(-L.H, L.H), "v": rnd(900, 1300), "l": rnd(14, 26)})
	if FX.rain.size() > want:
		FX.rain.resize(want)
	for d in FX.rain:
		d.y += d.v * dt
		d.x -= d.v * .12 * dt
		if d.y > L.H:
			d.y = rnd(-100, 0)
			d.x = rnd(-50, L.W + 80)

# ============================================================ câu: quăng, chờ, nhấp, giật, kéo, lên cá
func rod_tip_pos() -> Vector2:
	var b: Vector2 = L.rodButt
	var t: Vector2 = L.rodTip
	var a: float = G.rodA
	var d := t - b
	var c := cos(a)
	var s := sin(a)
	return Vector2(b.x + d.x * c - d.y * s, b.y + d.x * s + d.y * c + d.length() * .06)

func set_state(s: String) -> void:
	G.state = s
	G.t = 0.0
	ui.ui_state(s)

func cast_at(sx: float, sy: float) -> void:
	if G.state != "idle":
		return
	if S.bait != "trun" and not (int(S.baits.get(S.bait, 0)) > 0):
		S.bait = "trun"
		ui.toast("Hết mồi, xài trùn đất nha", "info")
		ui.hud_dirty()
	var u := unproj(sx, maxf(sy, L.yw + 2))
	var x := u.x
	var z := u.y
	var rod: Dictionary = D.ROD[S.rod]
	if z > rod.range:
		z = rod.range
		ui.toast("%s chỉ quăng tới đây thôi" % rod.name, "info")
	z = maxf(z, L.zEdge + 1.6)
	var acc: float = rod.acc * (.4 + z / 25)
	x += rnd(-acc, acc) * .5
	z += rnd(-acc, acc) * .5
	x = clampf(x, -half_x(z) * .92, half_x(z) * .92)
	G.lastTarget = Vector2(sx, sy)
	G.fl.x = x
	G.fl.z = z
	G.fl.sink = 0.0
	G.fl.tilt = 0.0
	G.fl.dx = 0.0
	G.flight = {"dur": .55 + z * .02}
	G.rodV = 0.0
	snd.whoosh()
	S.stats.casts += 1
	set_state("cast")

func cast_default() -> void:
	if G.lastTarget != null:
		cast_at(G.lastTarget.x, G.lastTarget.y)
		return
	var p := proj(0, minf(D.ROD[S.rod].range * .7, 13))
	cast_at(p.x, p.y)

func bite_table(x: float, z: float, hour: float, bait: String) -> Array:
	var cover := near_cover(x, z)
	var spot = near_spot(x, z)
	var out := []
	for f in D.FISH:
		var w: float = D.RAR_W[f.rar]
		if f.has("junk"):
			out.append([f, w * (.5 if spot != null else 1.0)])
			continue
		var b: float = f.bait.get(bait, 0)
		if not b:
			continue
		w *= b
		var tm: float = f.time.n if D.is_night(hour) else (f.time.dd if D.is_dusk_dawn(hour) else f.time.d)
		w *= tm
		var z0: float = f.zone[0]
		var z1: float = f.zone[1]
		w *= exp(-(z0 - z) * .6) if z < z0 else (exp(-(z - z1) * .6) if z > z1 else 1.0)
		if f.has("cover"):
			w *= 2.4 if cover else .6
		if spot != null and f.rar >= 2:
			w *= 2.2
		if W.rain > .4:
			w *= 1.25
		if f.rar >= 3:
			w *= 1 + S.luck * .04
		if w > 0.0005:
			out.append([f, w])
	return out

static func roll_fish(tab: Array) -> Dictionary:
	var tot := 0.0
	for e in tab:
		tot += e[1]
	var r := randf() * tot
	for e in tab:
		r -= e[1]
		if r <= 0:
			return e[0]
	return tab[tab.size() - 1][0]

func plan_bite() -> void:
	var x: float = G.fl.x
	var z: float = G.fl.z
	var tab := bite_table(x, z, S.hour, S.bait)
	G.ev = []
	G.fish = null
	G.shadow = null
	if tab.is_empty():
		G.idleWait = 99.0
		return
	var sum := 0.0
	for e in tab:
		sum += e[1]
	var spot = near_spot(x, z)
	var wait := rnd(3, 9) / minf(2.2, .55 + sum * .6) * (.6 if spot != null else 1.0) * (.7 if W.rain > .4 else 1.0)
	if S.tut < 2:
		wait = rnd(2, 3.5)
	var f := roll_fish(tab)
	G.fish = {"f": f, "wait": wait, "dir": 0.0}
	var t := wait
	var appr := 0.0 if f.has("junk") else rnd(1.6, 2.8)
	G.ev.append({"at": t, "k": "appr", "dur": appr})
	t += appr
	var fl: Dictionary = D.FLO[S.flo]
	var win: float = f.win * fl.win * (1.5 if S.tut < 2 else 1.0) * (.85 if D.is_night(S.hour) and not fl.glow else 1.0)
	match f.bite:
		"nhap":
			var n := 1 + randi() % 3
			for i in n:
				G.ev.append({"at": t, "k": "nib", "dur": .32})
				t += rnd(.6, 1.3)
			G.ev.append({"at": t, "k": "bite", "mode": "sink", "win": win})
		"keo":
			G.ev.append({"at": t, "k": "nib", "dur": .3})
			t += rnd(.7, 1.2)
			G.ev.append({"at": t, "k": "bite", "mode": "drag", "win": win * 1.1})
		"nam":
			for i in 2:
				G.ev.append({"at": t, "k": "nib", "dur": .26, "small": 1})
				t += rnd(.5, 1)
			G.ev.append({"at": t, "k": "bite", "mode": "lift", "win": win})
		"giat":
			G.ev.append({"at": t, "k": "nib", "dur": .2, "small": 1})
			t += rnd(1.5, 3)
			G.ev.append({"at": t, "k": "bite", "mode": "plunge", "win": win})
		_:
			G.ev.append({"at": t, "k": "bite", "mode": "slow", "win": win})
	G.anim = null
	G.biteOpen = 0.0

func wait_update(dt: float) -> void:
	var fl: Dictionary = G.fl
	fl.sink = lerpf(fl.sink, 0, dt * 3)
	fl.tilt = lerpf(fl.tilt, 0, dt * 2.5)
	if G.fish == null:
		G.idleWait += dt
		if G.idleWait > 20:
			G.idleWait = 0.0
			plan_bite()
		return
	for e in G.ev:
		if e.get("done", false) or G.t < e.at:
			continue
		e.done = true
		if e.k == "appr":
			start_shadow(e.dur)
		elif e.k == "nib":
			G.anim = {"k": "nib", "t": 0.0, "dur": e.dur, "small": e.get("small", 0)}
			ripple(fl.x, fl.z, .35 if e.get("small", 0) else .55)
			snd.plop(.5, .5)
			if G.df != null:
				df_fly()
			hint_once("nib", "Phao nhấp nhấp… chưa giật, chờ phao chìm hẳn!")
		elif e.k == "bite":
			G.anim = {"k": e.mode, "t": 0.0, "dur": e.win}
			G.biteOpen = e.win
			G.biteT = 0.0
			ripple(fl.x, fl.z, 1)
			if e.mode == "plunge":
				fx_splash(fl.x, fl.z, .8)
				snd.splash(.6)
			snd.plop(1.2, .3)
			if G.df != null:
				df_fly()
			big_cue(e.mode)
	var a = G.anim
	if a != null:
		a.t += dt
		var u: float = a.t / a.dur
		match a.k:
			"nib":
				fl.sink = sin(clampf(u, 0, 1) * PI) * (.35 if a.small else .6)
				if u > 1:
					G.anim = null
			"sink":
				fl.sink = clampf(u * 3, 0, 1.4)
			"plunge":
				fl.sink = clampf(u * 6, 0, 1.6)
				if randf() < dt * 8:
					ripple(fl.x + rnd(-.2, .2), fl.z, .6)
			"drag":
				if G.fish.dir == 0.0:
					G.fish.dir = pick([-1.0, 1.0])
				fl.dx += dt * .9 * G.fish.dir
				fl.x += dt * .9 * G.fish.dir
				fl.sink = .25 + u * .9
				if randf() < dt * 10:
					ripple(fl.x, fl.z, .4)
					fx_wake(fl.x, fl.z, .8)
			"lift":
				fl.tilt = clampf(u * 3, 0, 1)
				fl.sink = -.25 * clampf(u * 3, 0, 1)
			"slow":
				fl.sink = clampf(u * 1.2, 0, 1.2)
	if G.biteOpen:
		G.biteT += dt
		if G.biteT > G.biteOpen:
			G.biteOpen = 0.0
			lose_bait(1)
			ui.toast("Hụt rồi!" if G.fish.f.has("junk") else "Cá ăn mất mồi rồi!", "bad")
			snd.bad()
			reel_back()
	if G.shadow != null:
		var s: Dictionary = G.shadow
		s.t += dt
		var u := clampf(s.t / s.dur, 0, 1)
		var e := 1 - pow(1 - u, 2)
		s.x = lerpf(s.x0, fl.x - s.dx * .3, e)
		s.z = lerpf(s.z0, fl.z - s.dz * .3, e)
		s.a = minf(1, s.t * 1.5) * (.8 if G.fish.f.rar >= 3 else .55)
		if randf() < dt * 2.5:
			ripple(s.x, s.z, .18)
			fx_bubble(s.x, s.z)

func start_shadow(dur: float) -> void:
	var f: Dictionary = G.fish.f
	var an := rnd(TAU)
	var d := rnd(2.5, 4)
	var dx := cos(an)
	var dz := sin(an) * .6
	G.shadow = {"x0": G.fl.x + dx * d, "z0": G.fl.z + dz * d, "x": 0.0, "z": 0.0, "dx": dx, "dz": dz, "t": 0.0, "dur": maxf(.5, dur), "a": 0.0, "len": f.vis * 1.2, "flee": false}

func big_cue(mode: String) -> void:
	var msg: String = {"sink": "PHAO CHÌM!", "drag": "CÁ KÉO PHAO!", "lift": "PHAO NẰM!", "plunge": "CẮN MẠNH!", "slow": "PHAO CHÌM!"}[mode]
	ui.cue(msg)
	ui.ui_bite(true)
	hint_once("bite", "Giật liền! Chạm màn hình hoặc nút GIẬT")
	_vibrate(40)

func _vibrate(ms: int) -> void:
	Input.vibrate_handheld(ms)

func strike() -> void:
	G.rodV = 7.0
	snd.whoosh()
	if G.state == "wait" and G.biteOpen:
		var q: float = G.biteT / G.biteOpen
		var perfect := q < .45
		ui.cue("CHUẨN!" if perfect else "DÍNH RỒI!", "good")
		ui.hint_off()
		start_fight(perfect)
		return
	if G.state == "wait" and G.fish != null and G.shadow != null:
		var nib_done := false
		for e in G.ev:
			if e.k == "nib" and e.get("done", false):
				nib_done = true
		if G.anim != null or nib_done:
			ui.toast("Giật hụt! Cá sợ chạy mất", "bad")
			snd.bad()
			lose_bait(.5)
			G.shadow.flee = true
	reel_back()

func lose_bait(p: float) -> void:
	if S.bait != "trun" and randf() < p:
		S.baits[S.bait] = maxi(0, int(S.baits.get(S.bait, 0)) - 1)
		ui.hud_dirty()

func reel_back() -> void:
	G.biteOpen = 0.0
	G.anim = null
	G.ev = []
	if G.shadow != null:
		G.shadow.flee = true
	G.reel = {"x0": G.fl.x, "z0": G.fl.z}
	set_state("reel")

func start_fight(perfect: bool) -> void:
	var f: Dictionary = G.fish.f
	var w: float = f.w[0] + (f.w[1] - f.w[0]) * pow(randf(), 1.6 if f.rar >= 3 else 2.2)
	var k: float = (w - f.w[0]) / (f.w[1] - f.w[0] if f.w[1] != f.w[0] else 1.0)
	G.hook = {"f": f, "w": w, "size": .8 + .45 * k, "P": f.P * (.85 + .35 * k), "st0": f.st * (.8 + .5 * k), "x": G.fl.x, "vx": 0.0, "beh": "calm", "bt": .6, "surf": 0.0, "wk": 0.0}
	G.hook.st = G.hook.st0 * (.75 if perfect else 1.0)
	G.dist = maxf(.5, G.fl.z - L.zEdge)
	G.ten = .3
	G.over = 0.0
	G.slack = 0.0
	G.shadow = null
	ripple(G.fl.x, G.fl.z, 1.2)
	fx_splash(G.fl.x, G.fl.z, .7)
	snd.splash(.7)
	set_state("fight")
	later(.9, func():
		if G.state == "fight":
			hint_once("fight", "GIỮ để kéo · THẢ khi dây đỏ hoặc cá phóng lên"))

func fight_update(dt: float) -> void:
	var h: Dictionary = G.hook
	var f: Dictionary = h.f
	var rod: Dictionary = D.ROD[S.rod]
	var line: Dictionary = D.LINE[S.line]
	h.bt -= dt
	if h.bt < 0:
		if h.beh == "jumpwarn":
			h.beh = "jump"
			h.bt = .9
			fx_leap(f.id, h.x, L.zEdge + G.dist, h.size, 1.0 if h.vx >= 0 else -1.0, true)
			snd.splash(1.1)
		else:
			var r := randf()
			var fr0: float = h.st / h.st0
			if f.jump and r < f.jump * (.4 + fr0) and G.dist > 2:
				h.beh = "jumpwarn"
				h.bt = .45
				ui.cue("CÁ PHÓNG! THẢ TAY!", "warn")
			elif r < .55 * (.3 + fr0):
				h.beh = "run"
				h.bt = rnd(.8, 2.2)
				h.vx = pick([-1.0, 1.0]) * rnd(.6, 1.6) * f.P
			else:
				h.beh = "calm"
				h.bt = rnd(.7, 1.8)
				h.vx *= .3
	var fr := clampf(h.st / h.st0, 0, 1)
	var pull: float = h.P * (.3 + .7 * fr) / sqrt(rod.pow)
	pull *= {"run": 1.55, "calm": .5, "jumpwarn": .9, "jump": 1.25}[h.beh]
	if f.has("junk"):
		pull = h.P * .5
	var hold: bool = G.hold
	var maxD: float = rod.range + 6
	var tgt := (.16 + pull * .9 + (.95 if h.beh == "jump" else 0.0)) if hold else pull * .26
	if not hold and G.dist >= maxD - .05:
		tgt += pull * .6
	G.ten += (tgt - G.ten) * minf(1, dt * (7 if hold else 4))
	var tn: float = G.ten / line.str
	G.tn = tn
	if tn > 1:
		G.over += dt
		G.shake = minf(1, G.shake + dt * 4)
		if randf() < dt * 6:
			_vibrate(15)
	else:
		G.over = maxf(0, G.over - dt * 1.5)
		G.shake = maxf(0, G.shake - dt * 3)
	if G.over > .75:
		snap_line()
		return
	var reel: float = 2.2 * pow(rod.pow, .35)
	if hold:
		G.dist -= reel * dt * (1 - minf(.85, pull * .55))
	else:
		G.dist += pull * dt * (1.7 if h.beh == "run" else (1.0 if h.beh == "jump" else .35))
	G.dist = clampf(G.dist, 0, maxD)
	h.st -= dt * ((.55 + minf(1.3, tn) * 1.1) if hold else .22) * sqrt(rod.pow)
	h.st = maxf(h.st, 0)
	if not hold and h.beh != "run" and h.beh != "jump":
		G.slack += dt
		if G.slack > 1.2:
			ui.hint("Giữ để kéo vô!")
	else:
		G.slack = maxf(0, G.slack - dt * 2)
	if G.slack > 2.8 and not f.has("junk"):
		lost_fish("Dây chùng quá, cá sút lưỡi!")
		return
	var z: float = L.zEdge + G.dist
	h.x += h.vx * dt * (1.0 if h.beh == "run" else .4)
	var hx := half_x(z) * .85
	if absf(h.x) > hx:
		h.x = signf(h.x) * hx
		h.vx *= -.6
	h.x = lerpf(h.x, 0, dt * .15 * (1 if hold else 0))
	G.fl.x = h.x
	G.fl.z = z
	h.wk -= dt
	if h.wk < 0 and h.beh != "jump":
		# Link 11-22 "bọt loang lúc kéo ít lại": thưa hơn ~3 lần, gợn nhẹ hơn, ít bắn nước
		h.wk = .38 if h.beh == "run" else .75
		ripple(h.x, z, .35 if h.beh == "run" else .2)
		fx_wake(h.x, z, h.size * .7)
		if h.beh == "run" and randf() < .12:
			fx_splash(h.x, z, .35 * h.size)
			snd.plop(.7, .4)
	if hold:
		G.tick -= dt * (2 + reel * 3)
		if G.tick < 0:
			G.tick = 1.0
			snd.tick(.08 + tn * .06)
	snd.creak(tn)
	ui.ui_fight(tn, fr, G.dist / maxD, h.beh)
	if G.dist < .45:
		land_fish()

func snap_line() -> void:
	snd.creak(0)
	snd.snap()
	ui.toast("Đứt dây! Cá lớn quá…", "bad")
	ui.cue("ĐỨT DÂY!", "bad")
	S.stats.snaps += 1
	lose_bait(1)
	G.shake = 1.0
	set_state("snap")
	if S.line < D.LINE.size() - 1:
		later(1.6, func(): ui.toast("Mua %s ở Chợ để kéo cá to" % D.LINE[S.line + 1].name, "info"))

func lost_fish(msg: String) -> void:
	snd.creak(0)
	ui.toast(msg, "bad")
	snd.bad()
	lose_bait(.6)
	reel_back()

func land_fish() -> void:
	snd.creak(0)
	var h: Dictionary = G.hook
	G.landing = {"t": 0.0, "h": h, "done": false}
	fx_splash(h.x, L.zEdge + .4, 1 + h.size * .5)
	snd.splash(1.2)
	set_state("land")

func land_update(dt: float) -> void:
	G.landing.t += dt
	if G.landing.t > .75 and not G.landing.done:
		G.landing.done = true
		var h: Dictionary = G.landing.h
		caught(h.f, h.w)

func caught(f: Dictionary, w: float) -> void:
	if S.bait != "trun":
		S.baits[S.bait] = maxi(0, int(S.baits.get(S.bait, 0)) - 1)
	S.stats.catches += 1
	if not S.dex.has(f.id):
		S.dex[f.id] = {"n": 0, "best": 0.0}
	var d: Dictionary = S.dex[f.id]
	var is_new: bool = int(d.n) == 0
	d.n = int(d.n) + 1
	var rec: bool = w > float(d.best)
	if rec:
		d.best = w
	var cm := int(round(f.cm[0] + (f.cm[1] - f.cm[0]) * clampf((w - f.w[0]) / (f.w[1] - f.w[0] if f.w[1] != f.w[0] else 1.0), 0, 1)))
	var xp := 2 if f.has("junk") else int(round(4 + f.rar * 7 + minf(20, w * 3)))
	add_xp(xp)
	if f.has("junk"):
		S.luck = minf(10, S.luck + 1)
	if S.tut < 3:
		S.tut = 3
	save(true)
	snd.fanfare(f.rar)
	ui.show_catch({"f": f, "w": w, "cm": cm, "isNew": is_new, "rec": rec, "xp": xp, "val": D.fish_value(f, w)})
	set_state("card")

func add_xp(n: int) -> void:
	S.xp += n
	while S.xp >= D.xp_need(S.lv):
		S.xp -= D.xp_need(S.lv)
		S.lv += 1
		ui.level_up(S.lv)
	ui.hud_dirty()

# ------------------------------------------------------------ chuồn chuồn đậu phao
func float_h(z: float) -> float:
	return (L.F * .07 / z + 13) * (1.1 if L.portrait else 1.0)

func float_base() -> Vector2:
	var fl: Dictionary = G.fl
	var p := proj(fl.x, fl.z)
	var bob: float = sin(W.t * 1.9 + fl.x) * .7 + sin(W.t * 3.3) * .35 * (.5 + W.wind)
	return Vector2(p.x, p.y + bob)

func float_tip() -> Vector2:
	if G.state == "idle":
		var t := rod_tip_pos()
		return Vector2(t.x, t.y + 46)
	var b := float_base()
	var h := float_h(G.fl.z)
	var t: float = G.fl.tilt * 1.35 * (1.0 if G.fl.x >= 0 else -1.0)
	return Vector2(b.x + sin(t) * h, b.y + G.fl.sink * h - cos(t) * h)

func df_update(dt: float) -> void:
	if G.state == "wait" and G.df == null and G.anim == null and randf() < dt * .05 and S.hour > 7 and S.hour < 17.5 and W.rain < .3:
		G.df = {"x": -30.0 if randf() < .5 else L.W + 30, "y": rnd(L.H * .3, L.H * .7), "mode": "in", "t": 0.0, "ph": 0.0, "vx": 0.0, "vy": 0.0}
	var d = G.df
	if d == null:
		return
	d.t += dt
	d.ph += dt * 60
	var f := float_tip()
	if d.mode == "in":
		var k := 1 - minf(1, d.t / 3)
		var tx: float = f.x + sin(d.t * 3) * 30 * k
		var ty: float = f.y - 4 + cos(d.t * 2.3) * 20 * k
		d.x += (tx - d.x) * dt * 2.2
		d.y += (ty - d.y) * dt * 2.2
		if d.t > 3 and Vector2(d.x - f.x, d.y - f.y + 4).length() < 4:
			d.mode = "sit"
		if G.state != "wait":
			df_fly()
	elif d.mode == "sit":
		d.x = f.x
		d.y = f.y - 4
		if G.state != "wait":
			df_fly()
	else:
		d.x += d.vx * dt
		d.y += d.vy * dt
		d.vy -= 40 * dt
		if d.y < -50 or d.x < -60 or d.x > L.W + 60:
			G.df = null

func df_fly() -> void:
	if G.df != null and G.df.mode != "out":
		G.df.mode = "out"
		G.df.vx = pick([-1.0, 1.0]) * rnd(160, 260)
		G.df.vy = -rnd(60, 120)

# ------------------------------------------------------------ cập nhật mỗi khung
func game_update(dt: float) -> void:
	G.dt = dt
	G.t += dt
	var rest: float = (.14 + minf(.25, G.ten * .12)) if G.state == "fight" else 0.0
	G.rodV += ((rest - G.rodA) * 60 - G.rodV * 9) * dt
	G.rodA += G.rodV * dt
	match G.state:
		"cast":
			var u: float = G.t / G.flight.dur
			if G.t < .12:
				G.rodV += 30 * dt
			elif G.t < .22:
				G.rodV -= 80 * dt
			if u >= 1:
				fx_splash(G.fl.x, G.fl.z, .35)
				ripple(G.fl.x, G.fl.z, .9)
				snd.plop(1, clampf(G.fl.z / 30, 0, .7))
				set_state("wait")
				plan_bite()
				hint_once("wait", "Canh phao… Phao CHÌM hẳn thì GIẬT")
		"wait":
			wait_update(dt)
		"reel":
			var u := clampf(G.t / .55, 0, 1)
			var z := lerpf(G.reel.z0, L.zEdge + .6, u * u)
			G.fl.x = lerpf(G.reel.x0, 0, u * u * .5)
			G.fl.z = z
			G.fl.sink = 0.0
			G.fl.tilt = .6
			if randf() < .5:
				ripple(G.fl.x, G.fl.z, .3)
			if u >= 1:
				set_state("idle")
		"fight":
			fight_update(dt)
		"land":
			land_update(dt)
		"snap":
			if G.t > 1.1:
				set_state("idle")
	if G.shadow != null and G.shadow.flee:
		G.shadow.x += G.shadow.dx * dt * -4
		G.shadow.z += G.shadow.dz * dt * -4
		G.shadow.a -= dt * 1.2
		if G.shadow.a <= 0:
			G.shadow = null
	# bóng cá + phao đèn cho shader
	shs.fill(0)
	var list := []
	if G.shadow != null:
		list.append([G.shadow.x, G.shadow.z, G.shadow.len, G.shadow.a, G.shadow.dx, G.shadow.dz])
	if G.state == "fight":
		var h: Dictionary = G.hook
		list.append([h.x, G.fl.z, h.f.vis * h.size * 1.2, 0.0 if h.beh == "jump" else .8, 1.0 if h.vx >= 0 else -1.0, .15])
	for i in mini(4, list.size()):
		var s: Array = list[i]
		var dd := Vector2(s[4], s[5]).length()
		if dd == 0:
			dd = 1
		shs[i * 4] = s[0]
		shs[i * 4 + 1] = s[1]
		shs[i * 4 + 2] = s[2]
		shs[i * 4 + 3] = s[3]
		shs[16 + i * 4] = s[4] / dd
		shs[16 + i * 4 + 1] = s[5] / dd
		shs[16 + i * 4 + 2] = s[2] * .16
	var glow: float = tod.night if D.FLO[S.flo].glow and (G.state == "wait" or G.state == "fight") else 0.0
	W.floatGlow = [G.fl.x, G.fl.z, glow * (1 - clampf(G.fl.sink, 0, 1) * .7)]
	df_update(dt)

func hint_once(k: String, msg: String) -> void:
	if S.stats.catches > 3 or hinted.has(k):
		return
	hinted[k] = true
	ui.hint(msg)

# ============================================================ vòng chính
func _process(dt: float) -> void:
	if L.is_empty():
		return
	dt = minf(.05, dt)
	clock += dt
	_run_sched()
	if started:
		scn.perf(dt)
	tod = D.tod_at(S.hour)
	if W.rain > .01:
		var r: float = W.rain
		var grey := Color(.55, .6, .64).lerp(Color(.12, .14, .18), tod.night)
		tod.top = tod.top.lerp(grey, r * .7)
		tod.hor = tod.hor.lerp(grey.lerp(Color.WHITE, .15), r * .7)
		tod.tint = tod.tint.lerp(tod.tint.lerp(Color(.55, .6, .62), .6), r * .6)
		tod.cloud = tod.cloud.lerp(grey, r * .6)
		tod.fog = tod.fog.lerp(grey, r * .5)
		tod.water = tod.water.lerp(tod.water.lerp(grey, .3), r * .5)
	world_update(dt * .3 if G.paused else dt)
	if not G.paused and started:
		game_update(dt)
	fx_update(dt)
	if started:
		snd.ambience(dt, tod, W.rain)
	scn.render(W.t, tod, W, rips, shs)
	drw.redraw()
	drw.pfx.step(dt)
	ui.step(dt)
	save()

# ============================================================ chạm
func act(down: bool) -> void:
	if G.paused or not started:
		return
	snd.init()
	if not down:
		G.hold = false
		return
	if G.state == "idle":
		cast_default()
	elif G.state == "wait":
		strike()
	elif G.state == "fight":
		G.hold = true

func _water_input(e: InputEvent) -> void:
	var pos := Vector2.ZERO
	var down := false
	if e is InputEventScreenTouch:
		if e.index != 0:
			return
		pos = e.position
		down = e.pressed
	elif e is InputEventMouseButton:
		if e.button_index != MOUSE_BUTTON_LEFT:
			return
		pos = e.position
		down = e.pressed
	else:
		return
	inp.accept_event()
	if not down:
		G.hold = false
		return
	if G.paused or not started:
		return
	snd.init()
	if G.state == "idle":
		if pos.y > L.yw + 4:
			cast_at(pos.x, pos.y)
		else:
			cast_default()
	else:
		act(true)

# thả tay ở bất cứ đâu (cả trên nút) thì thôi kéo
func _input(e: InputEvent) -> void:
	if (e is InputEventScreenTouch and not e.pressed) or (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed):
		G.hold = false

func _notification_focus(what: int) -> void:
	pass

func start_game() -> void:
	if started:
		return
	started = true
	snd.init()
	ui.hide_title()
	set_state("idle")
	if not S.tut:
		S.tut = 1
		later(.7, func(): ui.hint("Chạm xuống mặt nước để quăng câu"))

func close_game() -> void:
	G.hold = false
	save(true)
	closed.emit()
