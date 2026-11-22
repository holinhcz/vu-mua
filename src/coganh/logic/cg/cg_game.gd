extends Control
# CỜ GÁNH viết lại bằng Godot (bản web: /mnt/project-files/co-ganh/src/game.js). Sân đất miền Tây buổi trưa, bàn kẻ phấn,
# sỏi trắng đấu miểng gạch, quân dư nằm trong rổ của mỗi bên. Đơn vị bàn: khoảng cách hai điểm = 1, điểm 0..4.
# Vẽ theo css px của bản web, nhân K (= devicePixelRatio) ra điểm ảnh thật. Nền tĩnh vẽ một lần (cg_bg.gd).

signal ended(mode: String, level: int, winner: int)
signal closed

const E := preload("res://logic/cg/cg_engine.gd")
const A := preload("res://logic/cg/cg_art.gd")
const BG := preload("res://logic/cg/cg_bg.gd")
const SND := preload("res://logic/cg/cg_snd.gd")
const HUD := preload("res://logic/cg/cg_hud.gd")

const PR := 0.155
const TOTAL := 16
const BM := 0.5
const SUN := Vector2(0.64, 0.77)
const KIND := ["sỏi trắng", "miểng gạch"]
const PCOL := [Color8(86, 170, 232), Color8(240, 122, 146)]
const OPP := [
	{"k": "ut", "name": "Bé Út", "lvl": "Dễ", "tag": "mới tập chơi"},
	{"k": "ti", "name": "Thằng Tí", "lvl": "Vừa", "tag": "lanh chanh"},
	{"k": "hai", "name": "Chị Hai", "lvl": "Khó", "tag": "tính kỹ từng nước"},
	{"k": "sau", "name": "Ông Sáu", "lvl": "Cao thủ", "tag": "vô địch xóm"},
]
const DEF := {"mo": 1, "quiet": 40, "first": "me", "speed": 1.0, "fx": 1, "sound": 1, "hint": 1}
const BANTER := {
	"ut": {"eat": ["Hihi, em gánh được rồi!", "Ủa, em ăn hả? Vui quá!"], "big": ["Trời ơi gánh đôi luôn!"], "vay": ["Em vây được rồi nè!"], "hurt": ["Huhu anh ăn quân em!", "Hổng chịu đâu!"], "mo": ["Em bị bắt đi đó hả?"], "win": ["Em thắng rồi! Hihi"], "lose": ["Thôi ván sau em gỡ!"]},
	"ti": {"eat": ["Hehe, gánh nha!", "Dô! Hai con về tay tui!"], "big": ["Gánh đôi! Thấy chưa!"], "vay": ["Kẹt cứng rồi nghen, hehe!"], "hurt": ["Ê ê, chơi gì kỳ vậy!", "Trời đất, mất hai con!"], "mo": ["Á, mở hả? Gánh thì gánh!"], "win": ["Thua tui rồi nha, hehe!"], "lose": ["Ván này hên thôi nghen!"]},
	"hai": {"eat": ["Chị gánh nghen em.", "Vậy là gọn."], "big": ["Nước này chị tính lâu rồi."], "vay": ["Hết đường rồi em."], "hurt": ["Em đi khá đó!", "Ờ, nước hay."], "mo": ["Mở cho chị gánh hả? Coi chừng nghen."], "win": ["Ván sau em coi chừng đường chéo nghen."], "lose": ["Giỏi lắm, chị chịu!"]},
	"sau": {"eat": ["Hà hà, thấy chưa.", "Đi vậy mới gọi là đi."], "big": ["Ông gánh cờ từ hồi còn để chỏm!"], "vay": ["Vây chặt rồi, chạy đằng trời."], "hurt": ["Bây được à nghen!", "Hừm, nước này ông không thấy."], "mo": ["Thế mở này ông biết rồi."], "win": ["Về tập thêm rồi qua kiếm ông."], "lose": ["Hậu sinh khả úy! Ông phục."]},
}
const SAVE := "user://coganh.json"

var K := 1.0
var L := {"W": 0.0, "H": 0.0, "port": false, "s": 100.0, "ox": 0.0, "oy": 0.0, "bx": [], "bas": [], "obst": [], "cards": [], "tools": Rect2(), "porch": 30.0}
var S := {}
var store := {}
var stats := {"w": [0, 0, 0, 0], "l": [0, 0, 0, 0], "d": [0, 0, 0, 0]}
var Gm := {"mode": "ai", "level": 1, "names": ["Bạn", "Thằng Tí"], "av": ["me", "ti"], "s": null, "R": {}, "hist": [], "busy": false, "sel": -1, "hover": -1, "hoverT": -1,
	"ff": 1.0, "started": false, "aiWaiting": false, "press": null, "drag": null, "moving": false, "undoLeft": 3, "trailA": 0.0, "demo": null, "needRebuild": false, "pvKey": "", "pvVal": null}
var ST := []
var sid := 0
var clock := 0.0
var hand := {"x": 2.0, "y": 2.0, "z": 0.0, "vis": 0.0, "show": false, "p": 0, "track": null}
var FX := []
var petals := []
var shake := 0.0
var ME := {"fall": [], "ground": [], "next": 3.0}
var FARM := {"hen": null, "chicks": [], "home": null}
var home_spot = null
var tut_step := 0
var ai_token := 0
var snd: Node = null
var hud: Control = null
var bg_tex: Texture2D = null
var shade: TextureRect = null
var _svp: SubViewport = null
var _shade_mat: ShaderMaterial = null
var _shade_t := 0.0
var _shade_drawn := false
var _ready_ok := false
var _vs := Vector2.ZERO
var _rz := -1.0
var _thr: Thread = null
var _baking := false

# ============================================================ dựng
func setup(k: float) -> void:
	K = maxf(1.0, k)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	E.init()
	_load()
	S = DEF.duplicate()
	S.merge(store.get("cg-set-v1", {}), true)
	var st0 = store.get("cg-stats-v1", null)
	if st0 is Dictionary:
		stats = st0
	tut_step = int(store.get("cg-tut", 0))
	snd = SND.new()
	add_child(snd)
	snd.on = bool(int(S.sound))
	A.build_atlas()
	A.build_arm()
	ME.next = 3 + randf() * 4
	_build_shade()
	hud = HUD.new()
	hud.game = self
	add_child(hud)
	await get_tree().process_frame
	_layout()
	Gm.demo = E.new_state(0)
	rebuild(Gm.demo)
	hud.build_menu()
	hud.update_cards()
	hud.show_ov("menu")
	_ready_ok = true

func _exit_tree() -> void:
	ai_token += 1
	if _thr != null and _thr.is_started():
		_thr.wait_to_finish()

func rules_now() -> Dictionary:
	return {"mo": bool(int(S.mo)), "quiet": int(S.quiet)}

func map(u: float, v: float) -> Vector2:
	return Vector2(L.ox + u * L.s, L.oy + v * L.s)

func unmap(X: float, Y: float) -> Vector2:
	return Vector2((X - L.ox) / L.s, (Y - L.oy) / L.s)

func board_rect(pad: float) -> Rect2:
	var a := map(-BM, -BM)
	var b := map(4 + BM, 4 + BM)
	return Rect2(a.x - pad, a.y - pad, b.x - a.x + 2 * pad, b.y - a.y + 2 * pad)

func _layout() -> void:
	var vs := get_viewport_rect().size
	_vs = vs
	var W := vs.x / K
	var H := vs.y / K
	L.W = W
	L.H = H
	L.port = H > W * 1.05
	hud.layout(W, H, L.port)
	var c0: Rect2 = hud.card_rect(0)
	var c1: Rect2 = hud.card_rect(1)
	var tl: Rect2 = hud.tools_rect()
	L.cards = [c0, c1]
	L.tools = tl
	if not L.port:
		var side := maxf(c0.size.x, c1.size.x) + 22
		L.s = minf(minf((H - 16) / (5.0 if H < 500 else 5.7), (W - 2 * side) / (4 + 2 * BM * 0.6)), 165.0)
		L.ox = (W - 4 * L.s) / 2
		L.oy = (H - 4 * L.s) / 2 + minf(14.0, L.s * 0.1)
	else:
		var top := maxf(c1.end.y, tl.end.y)
		var bot := c0.position.y
		L.s = minf(minf((W - 16) / (4 + 0.62), (bot - top - 16) / (4 + 2 * BM + 1.6)), 175.0)
		L.ox = (W - 4 * L.s) / 2
		L.oy = (top + bot) / 2 - 2 * L.s
	# rổ quân dư của mỗi bên: to nhất vừa chỗ (tới chừng 60 cm), phía bên mình, gần thẻ
	var brd := board_rect(L.s * 0.08)
	var blocks := [brd, c0.grow(8), c1.grow(8), tl.grow(8)]
	var hit := func(x: float, y: float, r: float, lst: Array) -> bool:
		for o in lst:
			var q: Rect2 = o
			if Vector2(clampf(x, q.position.x, q.end.x) - x, clampf(y, q.position.y, q.end.y) - y).length() < r:
				return true
		return false
	L.bx = []
	for p in [0, 1]:
		var card: Rect2 = L.cards[p]
		var cc := card.get_center()
		var best = null
		for f in [0.95, 0.88, 0.8, 0.72, 0.64, 0.56, 0.5]:
			var r := maxf(26.0, minf(L.s * f, 120.0))
			var bs := -1e9
			var y := r + 6
			while y <= H - r - 6:
				var x := r + 6
				while x <= W - r - 6:
					if not hit.call(x, y, r + 4, blocks):
						var ok := true
						if L.bx.size():
							var b0: Vector3 = L.bx[0]
							if Vector2(x - b0.x, y - b0.y).length() < r + b0.z + 10:
								ok = false
						if ok:
							var half := (0.0 if y > H / 2 else -400.0) if p == 0 else (0.0 if y < H / 2 else -400.0)
							var sc := half - Vector2(x - cc.x, y - cc.y).length() * 0.6
							if sc > bs:
								bs = sc
								best = Vector3(x, y, r)
					x += 6
				y += 6
			if best != null:
				break
		if best == null:
			best = Vector3(W - 40, H - 40, 30) if p == 0 else Vector3(40, 40 + tl.size.y, 30)
		L.bx.append(best)
		blocks.append(Rect2(best.x - best.z, best.y - best.z, best.z * 2, best.z * 2))
	L.bas = []
	for b in L.bx:
		var u := unmap(b.x, b.y)
		L.bas.append({"x": u.x, "y": u.y, "r": b.z * 0.8 / L.s})
	_resize_shade()
	_bake_bg()

func _bake_bg() -> void:
	# nền tĩnh: vẽ một lần trong SubViewport, chụp ra ảnh
	_baking = true
	var vp := SubViewport.new()
	vp.size = Vector2i(maxi(2, int(_vs.x)), maxi(2, int(_vs.y)))
	vp.transparent_bg = false
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var n := BG.new()
	n.g = self
	n.K = K
	vp.add_child(n)
	add_child(vp)
	await RenderingServer.frame_post_draw
	var im := vp.get_texture().get_image()
	bg_tex = ImageTexture.create_from_image(im)
	if OS.has_environment("CG_DUMP"):
		im.save_png(OS.get_environment("CG_DUMP"))
	vp.queue_free()
	_baking = false
	place_animals()
	queue_redraw()

# ============================================================ lưu
func _load() -> void:
	store = {}
	if FileAccess.file_exists(SAVE):
		var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
		if d is Dictionary:
			store = d

func store_set(k: String, v) -> void:
	store[k] = v
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(store))
		f.close()

func store_del(k: String) -> void:
	if store.has(k):
		store.erase(k)
		store_set("_", 0)

static func ser(s: Dictionary) -> Dictionary:
	var d := {}
	for k in s:
		d[k] = s[k]
	d.b = Array(s.b)
	var rp := {}
	for k in s.reps:
		rp[str(k)] = s.reps[k]
	d.reps = rp
	return d

static func deser(d: Dictionary) -> Dictionary:
	var b := PackedByteArray()
	for x in d.b:
		b.append(int(x))
	var rp := {}
	for k in d.reps:
		rp[int(k)] = int(d.reps[k])
	var l = d.get("last")
	return {"b": b, "turn": int(d.turn), "ply": int(d.ply), "quiet": int(d.quiet),
		"last": ({"from": int(l.from), "to": int(l.to), "p": int(l.p)} if l is Dictionary else null), "over": bool(d.over), "winner": int(d.winner),
		"end": String(d.get("end", "")), "reps": rp, "ganh": [int(d.ganh[0]), int(d.ganh[1])], "vay": [int(d.vay[0]), int(d.vay[1])], "took": [int(d.took[0]), int(d.took[1])]}

func save_game() -> void:
	var s = Gm.s
	if s == null or s.over:
		return
	var h := []
	for x in Gm.hist.slice(-20):
		h.append(ser(x))
	store_set("cg-save-v1", {"mode": Gm.mode, "level": Gm.level, "names": Gm.names, "av": Gm.av, "s": ser(s), "R": Gm.R, "hist": h, "undoLeft": Gm.undoLeft})

func has_save() -> bool:
	return store.get("cg-save-v1", null) is Dictionary

# ============================================================ điểm & vùng
static func ptx(i: int) -> float:
	return float(i % 5)

static func pty(i: int) -> float:
	return float(i / 5)

func point_at(u: float, v: float, tol := 0.42) -> int:
	var c := roundi(u)
	var r := roundi(v)
	if c < 0 or c > 4 or r < 0 or r > 4:
		return -1
	return r * 5 + c if Vector2(u - c, v - r).length() <= tol else -1

func region(home: String) -> Dictionary:
	if home[0] == "b":
		var b: Dictionary = L.bas[int(home.substr(1))]
		return {"x": b.x, "y": b.y, "r": b.r}
	var i := int(home.substr(1))
	return {"x": ptx(i), "y": pty(i), "r": PR + 0.06}

static func clamp_to(reg: Dictionary, p: Dictionary, rad: float) -> bool:
	var dx: float = p.x - reg.x
	var dy: float = p.y - reg.y
	var d := Vector2(dx, dy).length()
	var m := maxf(0.001, reg.r - rad)
	if d > m:
		p.x = reg.x + dx / d * m
		p.y = reg.y + dy / d * m
		return true
	return false

func spot_in(home: String, rad: float) -> Vector2:
	if home[0] == "p":
		var i := int(home.substr(1))
		return Vector2(ptx(i) + (randf() - 0.5) * 0.05, pty(i) + (randf() - 0.5) * 0.05)
	var reg := region(home)
	var others := ST.filter(func(t): return t.home == home and t.fly == null)
	var c := Vector2(reg.x, reg.y)
	var best := c
	var bs := -1e9
	for k in 40:
		var a := randf() * TAU
		var d := sqrt(randf()) * maxf(0.0, reg.r - rad)
		var p := Vector2(reg.x + cos(a) * d, reg.y + sin(a) * d)
		var gap := 9.0
		for o in others:
			gap = minf(gap, Vector2(o.x - p.x, o.y - p.y).length() - o.r - rad)
		var sc := -maxf(0.0, 0.006 - gap) * 60 - (p - c).length() * 0.3 + randf() * 0.05
		if sc > bs:
			bs = sc
			best = p
	if others.size():
		for it in 14:
			var nb := best + (c - best) * 0.25
			var gap := 9.0
			for o in others:
				gap = minf(gap, Vector2(o.x - nb.x, o.y - nb.y).length() - o.r - rad)
			if gap < 0.004:
				break
			best = nb
	return best

# ============================================================ gà mái và bầy gà con đi mổ quanh sân
func place_animals() -> void:
	FARM.hen = null
	FARM.chicks = []
	var hm = home_spot
	if hm == null:
		return
	var size: float = hm.len * 0.72
	FARM.home = hm
	FARM.hen = {"x": hm.x, "y": hm.y, "a": (0.0 if randf() < 0.5 else PI) + (PI / 2 if hm.ax else 0.0), "sz": size, "len": hm.len, "st": "walk", "t": 1 + randf() * 2, "bob": 0.0, "peck": 0, "tx": null, "ty": null}
	for k in 3:
		FARM.chicks.append({"x": hm.x + (randf() - 0.5) * size, "y": hm.y + (randf() - 0.5) * size, "a": 0.0, "sz": size, "len": hm.len * 0.27, "off": [-0.75 - k * 0.22, (k - 1) * 0.42], "peck": 0, "ph": randf() * 6, "hop": 0.0})

static func strip_uv(hm: Dictionary, x: float, y: float) -> Vector2:
	return Vector2(y - hm.y, x - hm.x) if hm.ax else Vector2(x - hm.x, y - hm.y)

static func strip_pt(hm: Dictionary, u: float, v: float) -> Vector2:
	return Vector2(hm.x + v, hm.y + u) if hm.ax else Vector2(hm.x + u, hm.y + v)

func step_animals(dt: float) -> void:
	var h = FARM.hen
	if h == null:
		return
	var hm: Dictionary = FARM.home
	h.t -= dt
	if h.t <= 0:
		h.st = ("peck" if randf() < 0.7 else "look") if h.st == "walk" else "walk"
		h.t = 1.5 + randf() * 2.5 if h.st == "walk" else 1 + randf() * 1.8
	if h.st == "walk":
		if h.tx == null or Vector2(h.tx - h.x, h.ty - h.y).length() < h.len * 0.15:
			var q := strip_pt(hm, (randf() * 2 - 1) * hm.half, (randf() * 2 - 1) * hm.r)
			h.tx = q.x
			h.ty = q.y
		var to := atan2(h.ty - h.y, h.tx - h.x)
		var df := fposmod(to - h.a + PI * 3, PI * 2) - PI
		h.a += signf(df) * minf(absf(df), 2.4 * dt) + (randf() - 0.5) * 0.6 * dt
		var sp: float = h.len * 0.35
		h.x += cos(h.a) * sp * dt
		h.y += sin(h.a) * sp * dt
		h.bob += dt * 9
		h.peck = 0
		var uv := strip_uv(hm, h.x, h.y)
		var q2 := strip_pt(hm, clampf(uv.x, -hm.half, hm.half), clampf(uv.y, -hm.r, hm.r))
		h.x = q2.x
		h.y = q2.y
	elif h.st == "peck":
		h.bob += dt * 2
		h.peck = 1 if sin(clock * 7) > 0.1 else 0
	else:
		h.peck = 0
		h.a += sin(clock * 3) * dt * 0.8
	for c in FARM.chicks:
		var ca := cos(h.a)
		var sa := sin(h.a)
		var tx: float = h.x + (ca * c.off[0] - sa * c.off[1]) * h.sz
		var ty: float = h.y + (sa * c.off[0] + ca * c.off[1]) * h.sz
		var dx: float = tx - c.x
		var dy: float = ty - c.y
		var d := Vector2(dx, dy).length()
		if d > h.sz * 0.15:
			c.a = atan2(dy, dx)
			var sp := minf(d * 3, h.sz * 1.1)
			c.x += cos(c.a) * sp * dt
			c.y += sin(c.a) * sp * dt
			c.hop += dt * 16
			c.peck = 0
		else:
			c.peck = 1 if sin(clock * 9 + c.ph) > 0.3 else 0
			c.a += sin(clock * 2 + c.ph) * dt
		var uv := strip_uv(hm, c.x, c.y)
		var qu := clampf(uv.x, -hm.half, hm.half)
		var eu := uv.x - qu
		var ed := Vector2(eu, uv.y).length()
		var lim := maxf(hm.r, hm.cr - c.len * 0.45)
		if ed > lim:
			var q3 := strip_pt(hm, qu + eu / ed * lim, uv.y / ed * lim)
			c.x = q3.x
			c.y = q3.y

func _draw_animal(name: String, ln: float, span: float, x: float, y: float, rot: float, off: Vector2) -> void:
	# gà 9px của caro: 1 ảnh nhìn từ trên, xoay theo hướng đi; chỉ bóng sát đất (bóng đổ xoay theo sẽ phải làm lại mỗi khung)
	var D := ln / span
	A.on_ground(self, K, name, Rect2i(), Vector2(x, y) + off, D, D, rot, 0.0)

# ============================================================ quân cờ (hình + vật lý)
func mk_stone(kind: int, home: String, p: Vector2) -> Dictionary:
	sid += 1
	return {"id": sid, "kind": kind, "home": home, "x": p.x, "y": p.y, "z": 0.0, "vx": 0.0, "vy": 0.0, "vz": 0.0, "r": PR * (0.95 + randf() * 0.1),
		"v": randi() % A.QN, "fly": null, "rest": true, "land": clock + randf(), "still": 0.0}

func rebuild(s: Dictionary) -> void:
	ST = []
	hand.show = false
	hand.track = null
	Gm.drag = null
	var put := func(home: String, kind: int) -> void:
		var st := mk_stone(kind, home, Vector2.ZERO)
		var p := spot_in(home, st.r)
		st.x = p.x
		st.y = p.y
		ST.append(st)
	for i in 25:
		if s.b[i]:
			put.call("p" + str(i), s.b[i] - 1)
	for p in [0, 1]:
		for n in range(E.count(s.b, p), TOTAL):
			put.call("b" + str(p), p)
	for k in 40:
		physics(1.0 / 60, true)
	for st in ST:
		st.vx = 0.0
		st.vy = 0.0
		st.vz = 0.0
		st.rest = true

func stone_at(i: int):
	var h := "p" + str(i)
	for t in ST:
		if t.home == h and t.fly == null:
			return t
	return null

func in_home(h: String) -> Array:
	return ST.filter(func(t): return t.home == h and t.fly == null)

func fly(st: Dictionary, tx: float, ty: float, tz: float, dur: float, arc: float, on_land, to: String, delay := 0.0) -> void:
	st.fly = {"sx": st.x, "sy": st.y, "sz": st.z, "tx": tx, "ty": ty, "tz": tz, "t0": clock + delay, "dur": dur, "arc": arc, "cb": on_land, "to": to}
	st.rest = false

func finish_all_flights() -> void:
	for st in ST:
		if st.fly != null:
			var f: Dictionary = st.fly
			st.fly = null
			st.x = f.tx
			st.y = f.ty
			st.z = f.tz
			if f.cb != null:
				(f.cb as Callable).call(st, 0.0, 0.0)

func physics(dt: float, settle := false) -> void:
	for st in ST:
		if st.fly != null:
			var f: Dictionary = st.fly
			if clock < f.t0:
				continue
			var k := minf(1.0, (clock - f.t0) / f.dur)
			var e := 2 * k * k if k < 0.5 else 1 - 2 * (1 - k) * (1 - k)
			st.x = f.sx + (f.tx - f.sx) * e
			st.y = f.sy + (f.ty - f.sy) * e
			st.z = f.sz + (f.tz - f.sz) * k + f.arc * 4 * k * (1 - k)
			if k >= 1:
				st.fly = null
				if f.cb != null:
					(f.cb as Callable).call(st, (f.tx - f.sx) / f.dur, (f.ty - f.sy) / f.dur)
			continue
		if st.home == "h" or st.rest:
			continue
		st.vz -= 7.5 * dt
		st.z += st.vz * dt
		if st.z <= 0:
			st.z = 0.0
			if st.vz < -0.45:
				var imp: float = -st.vz
				st.vz = imp * 0.3
				if not settle and imp > 0.8:
					snd.clack(imp / 3.5, near_stone(st))
			else:
				st.vz = 0.0
		st.x += st.vx * dt
		st.y += st.vy * dt
		if st.z == 0:
			var fr := exp(-8 * dt)
			st.vx *= fr
			st.vy *= fr
	# va chạm trong mỗi rổ; quân trên bàn chỉ nằm yên ở điểm
	var groups := {}
	for st in ST:
		if st.fly == null and st.home != "h" and st.home != "air":
			if not groups.has(st.home):
				groups[st.home] = []
			groups[st.home].append(st)
	for h in groups:
		var a: Array = groups[h]
		var reg := region(h)
		if a.size() > 1:
			for it in 2:
				for i in a.size():
					for j in range(i + 1, a.size()):
						var p: Dictionary = a[i]
						var q: Dictionary = a[j]
						if p.rest and q.rest:
							continue
						if absf(p.z - q.z) > 0.12:
							continue
						var dx: float = q.x - p.x
						var dy: float = q.y - p.y
						var d := Vector2(dx, dy).length()
						if d == 0:
							d = 1e-4
						var m: float = (p.r + q.r) * 0.9
						if d >= m:
							continue
						var ov := (m - d) * 0.5
						var nx := dx / d
						var ny := dy / d
						p.x -= nx * ov * 0.6; p.y -= ny * ov * 0.6; q.x += nx * ov * 0.6; q.y += ny * ov * 0.6
						var rv: float = (q.vx - p.vx) * nx + (q.vy - p.vy) * ny
						if rv < 0:
							var j2 := -rv * 0.3
							p.vx -= nx * j2; p.vy -= ny * j2; q.vx += nx * j2; q.vy += ny * j2
						if p.rest and ov > 0.006:
							wake(p)
						if q.rest and ov > 0.006:
							wake(q)
		for st in a:
			if clamp_to(reg, st, st.r * 0.9):
				st.vx *= -0.3
				st.vy *= -0.3
			if not st.rest and st.z == 0 and st.vz == 0 and Vector2(st.vx, st.vy).length() < 0.03:
				st.still += dt
				if st.still > 0.12 or settle:
					st.rest = true
					st.vx = 0.0
					st.vy = 0.0
					st.still = 0.0
			else:
				st.still = 0.0
			if not st.rest and clock - st.land > 1.6 and st.z == 0:
				st.rest = true
				st.vx = 0.0
				st.vy = 0.0

func wake(st: Dictionary) -> void:
	st.rest = false
	st.still = 0.0

func near_stone(st: Dictionary) -> bool:
	for o in ST:
		if o != st and o.home == st.home and Vector2(o.x - st.x, o.y - st.y).length() < st.r + o.r + 0.02:
			return true
	return false

func land_in(home: String, soft := false) -> Callable:
	return func(st: Dictionary, vx: float, vy: float) -> void:
		st.home = home
		st.z = 0.0
		st.rest = false
		st.land = clock
		if home[0] == "p":
			st.vz = 0.25 if soft else 0.4
			st.vx = 0.0
			st.vy = 0.0
		else:
			st.vz = 0.55 + randf() * 0.25
			st.vx = vx * 0.1 + (randf() - 0.5) * 0.35
			st.vy = vy * 0.1 + (randf() - 0.5) * 0.35
		snd.clack(0.8 if home[0] == "p" else 0.9, near_stone(st))
		dust(st.x, st.y, 2 if home[0] == "b" else 5)
		for o in ST:
			if o != st and o.home == home and Vector2(o.x - st.x, o.y - st.y).length() < st.r + o.r + 0.04:
				wake(o)
				o.land = clock
				o.vx += (o.x - st.x) * 2
				o.vy += (o.y - st.y) * 2

# ============================================================ khung hình
func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _ready_ok:
		_rz = 0.12

func _process(dt: float) -> void:
	if not _ready_ok:
		return
	dt = minf(0.05, dt)
	if _rz > 0.0:
		_rz -= dt
		if _rz <= 0.0 and get_viewport_rect().size != _vs:
			_layout()
			if Gm.s != null and not Gm.busy:
				rebuild(Gm.s)
			elif Gm.s != null:
				Gm.needRebuild = true
			elif Gm.demo != null:
				rebuild(Gm.demo)
			hud.update_cards()
	clock += dt
	for k in 2:
		physics(dt / 2)
	if hand.track != null:
		var t: Dictionary = hand.track
		hand.x = t.x
		hand.y = t.y
		hand.z = t.z
	hand.vis += ((1.0 if hand.show else 0.0) - hand.vis) * minf(1.0, dt * 10)
	shake *= exp(-dt * 7)
	_step_me(dt)
	if FARM.hen != null:
		step_animals(dt)
	for f in FX:
		f.age += dt
		if f.t == "dust":
			f.x += f.vx * dt; f.y += f.vy * dt; f.vx *= 0.92; f.vy *= 0.92
		elif f.t == "spark":
			f.x += f.vx * dt; f.y += f.vy * dt; f.vx *= 0.94; f.vy *= 0.94
	for p in petals:
		p.y += p.vy * dt
		p.x += (p.vx + sin(clock * 2 + p.ph) * 26) * dt
		p.a += p.va * dt
	if Gm.s != null and Gm.s.last != null and Gm.trailA > 0 and human_live():
		Gm.trailA = maxf(0.35, Gm.trailA - dt * 0.4)
	queue_redraw()
	_shade_step(dt)

func human_live() -> bool:
	return Gm.s != null and not Gm.busy and not Gm.s.over and is_human(Gm.s.turn) and Gm.started

func is_human(p: int) -> bool:
	return Gm.mode == "pvp" or p == 0

func preview(mv: int) -> Dictionary:
	var key := str(mv) + ":" + str(Gm.s.ply)
	if Gm.pvKey == key:
		return Gm.pvVal
	var c := E.clone(Gm.s)
	var ev := []
	E.move(c, mv, Gm.R, ev)
	var r := {"ganh": [], "vay": [], "pairs": [], "win": c.over and c.winner == Gm.s.turn}
	for e in ev:
		if e.t == "ganh":
			r.ganh = e.pts
			r.pairs = e.pairs
		elif e.t == "vay":
			r.vay = e.pts
	Gm.pvKey = key
	Gm.pvVal = r
	return r

func targets_of(i: int) -> Array:
	var out := []
	if Gm.s != null:
		for m in E.legal(Gm.s, Gm.R):
			if m / 25 == i:
				out.append(m % 25)
	return out

func movable() -> Dictionary:
	var set := {}
	if Gm.s != null:
		for m in E.legal(Gm.s, Gm.R):
			set[m / 25] = true
	return set

# ------------------------------------------------------------ vẽ
func _T(xf := Transform2D.IDENTITY) -> void:
	draw_set_transform_matrix(Transform2D(0.0, Vector2(K, K), 0.0, Vector2.ZERO) * xf)

func _LG(sh := Vector2.ZERO) -> void:   # tọa độ bàn (1 = một khoảng giữa hai điểm)
	_T(Transform2D(0.0, Vector2(L.s, L.s), 0.0, Vector2(L.ox, L.oy) + sh))

func chalk_loop(c: Vector2, rx: float, ry: float, seed: float, col: Color, lw: float) -> void:
	# vòng phấn vẽ tay méo méo, cùng một kiểu méo mỗi khung cho một điểm
	for ps in 2:
		var pts := PackedVector2Array()
		for k in 49:
			var t := k / 48.0 * 6.6 + seed + ps * 0.4
			var w := 1 + 0.035 * sin(t * 3 + seed * 7 + ps) + 0.02 * sin(t * 7 + seed)
			pts.append(c + Vector2(cos(t) * rx * w, sin(t) * ry * w))
		draw_polyline(pts, Color(col, col.a * (0.55 if ps else 1.0)), lw, true)

func chalk_text(at: Vector2, txt: String, fs: float, col: Color) -> void:
	var f := A.font(700)
	var n := roundi(fs * K)
	var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, n).x / K
	var asc := f.get_ascent(n) / K
	var dsc := f.get_descent(n) / K
	var p := Vector2(at.x - w / 2, at.y + (asc - dsc) / 2)
	_T()
	draw_string(f, (p + Vector2(fs * 0.04, fs * 0.06)) * K, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, n, Color8(60, 38, 18, 77))
	draw_string(f, (p + Vector2(-fs * 0.025, fs * 0.02)) * K, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, n, Color(col, 0.45))
	draw_string(f, (p + Vector2(fs * 0.02, -fs * 0.02)) * K, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, n, Color(col, 0.45))
	draw_string(f, p * K, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, n, col)

func _star(c: Vector2, r: float, col: Color) -> void:
	if r < 0.8:
		return
	var pts := PackedVector2Array()
	for k in 8:
		var a := k * PI / 4
		var rr := r * 0.38 if k & 1 else r
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(pts, col)

static func ellipse(c: Vector2, rx: float, ry: float, rot: float, n := 16) -> PackedVector2Array:
	rx = maxf(rx, 0.4)
	ry = maxf(ry, 0.4)
	var pts := PackedVector2Array()
	var cr := cos(rot)
	var sr := sin(rot)
	for k in n:
		var a := TAU * k / n
		var x := cos(a) * rx
		var y := sin(a) * ry
		pts.append(c + Vector2(x * cr - y * sr, x * sr + y * cr))
	return pts

func _draw() -> void:
	if not _ready_ok:
		return
	var s: float = L.s
	var sh := Vector2.ZERO
	if shake > 0.3:
		sh = Vector2((randf() - 0.5) * shake, (randf() - 0.5) * shake)
	_T()
	if sh != Vector2.ZERO or bg_tex == null:
		draw_rect(Rect2(0, 0, L.W, L.H), Color("#9c7f5c"))
	if bg_tex != null:
		draw_set_transform(sh * K, 0.0, Vector2.ONE)
		draw_texture(bg_tex, Vector2.ZERO)
	_draw_me(false)
	if FARM.hen != null and not _baking:
		for c in FARM.chicks:
			var hop: float = absf(sin(c.hop)) * c.len * 0.06
			_draw_animal("gacon", c.len, 0.91, c.x + cos(c.a) * c.len * 0.08 * c.peck, c.y - hop + sin(c.a) * c.len * 0.08 * c.peck, c.a, sh)
		var h = FARM.hen
		var bob: float = sin(h.bob) * h.len * 0.01
		_draw_animal("ga", h.len, 0.6, h.x + cos(h.a) * h.len * 0.05 * h.peck, h.y + bob + sin(h.a) * h.len * 0.05 * h.peck, h.a - 2.6, sh)
	var live := human_live()
	var pulse := 0.5 + 0.5 * sin(clock * 3.2)
	_LG(sh)
	# nước vừa đi: vệt phấn mờ từ chỗ cũ tới chỗ mới
	if Gm.s != null and Gm.s.last != null and Gm.trailA > 0:
		var la: Dictionary = Gm.s.last
		var p0 := Vector2(ptx(la.from), pty(la.from))
		var p1 := Vector2(ptx(la.to), pty(la.to))
		var al := minf(1.0, Gm.trailA)
		var u := (p1 - p0).normalized()
		var e := p1 - u * 0.25
		draw_set_transform_matrix(Transform2D(0.0, Vector2(K, K), 0.0, Vector2.ZERO) * Transform2D(0.0, Vector2(s, s), 0.0, Vector2(L.ox, L.oy) + sh))
		draw_texture_rect_region(A.atlas, Rect2(p0 - Vector2(0.12, 0.12), Vector2(0.24, 0.24)), A.R_GLOW, Color(1.0, 0.925, 0.784, 0.28 * al))
		var cl := Color8(255, 232, 170, int(0.6 * al * 255))
		draw_dashed_line(p0 + u * 0.06, e, cl, 0.024, 0.05, true, true)
		var nn := Vector2(-u.y, u.x)
		draw_polyline(PackedVector2Array([e - u * 0.09 + nn * 0.06, e, e - u * 0.09 - nn * 0.06]), cl, 0.024, true)
	var hov = null
	if live:
		var mov := movable()
		var forced = E.forced(Gm.s, Gm.R)
		if forced != null and Gm.sel < 0:
			for i in mov:
				chalk_loop(Vector2(ptx(i), pty(i)), 0.25, 0.25, i * 1.7, Color8(255, 214, 90, int((0.55 + 0.4 * pulse) * 255)), 0.032)
		if Gm.hover >= 0 and Gm.sel < 0 and mov.has(Gm.hover):
			chalk_loop(Vector2(ptx(Gm.hover), pty(Gm.hover)), 0.23, 0.23, Gm.hover, Color8(255, 248, 226, 204), 0.022)
		if Gm.sel >= 0:
			var i: int = Gm.sel
			chalk_loop(Vector2(ptx(i), pty(i)), 0.25, 0.25, i, Color8(255, 226, 120, 242), 0.034)
			for t in targets_of(i):
				var c := Vector2(ptx(t), pty(t))
				var mv: int = i * 25 + t
				var pv = preview(mv) if int(S.hint) else null
				var n: int = (pv.ganh.size() + pv.vay.size()) if pv != null else 0
				var on: bool = Gm.hoverT == t
				var a := 0.4 if on else 0.16 + 0.12 * pulse
				draw_texture_rect_region(A.atlas, Rect2(c - Vector2(0.3, 0.3), Vector2(0.6, 0.6)), A.R_GLOW, Color(1.0, 0.965, 0.84, a))
				chalk_loop(c, 0.15, 0.15, t * 2.1, Color8(255, 214, 90, int((0.75 + 0.25 * pulse) * 255)) if n else Color8(255, 250, 236, int((0.55 + 0.35 * pulse) * 255)), 0.03 if n else 0.024)
				if on:
					hov = {"mv": mv, "pv": pv if pv != null else preview(mv)}
	if Gm.drag != null and Gm.drag.t >= 0 and Gm.sel >= 0:
		hov = {"mv": Gm.sel * 25 + Gm.drag.t, "pv": preview(Gm.sel * 25 + Gm.drag.t)}
	# quân: bóng trước rồi tới thân
	_T(Transform2D(0.0, Vector2.ONE, 0.0, sh))
	var lst := ST.duplicate()
	lst.sort_custom(func(a, b): return a.z < b.z if a.z != b.z else a.land < b.land)
	for st in lst:
		var P := map(st.x, st.y)
		var R: float = st.r * s * (1 + st.z * 0.28)
		var off: float = (0.05 + st.z * 0.42) * s
		var ss: float = R * (2.3 + st.z * 0.9)
		var al := maxf(0.25, 1 - st.z * 0.55) * 0.9
		if st.z < 0.03:
			# Link 11-22: bỏ vòng cát sỏi nhỏ quanh chân quân, chỉ còn bóng
			var cs := R * 2.16
			draw_texture_rect_region(A.atlas, Rect2(P.x + R * 0.07 - cs / 2, P.y + R * 0.1 - cs / 2, cs, cs * 0.96), A.R_CONT, Color(1, 1, 1, 0.5))
			var ks := R * 2.3
			draw_texture_rect_region(A.atlas, Rect2(P.x + R * 0.32 - ks / 2, P.y + R * 0.4 - ks / 2, ks, ks * 0.92), A.R_SOFT, Color(1, 1, 1, 0.22))
			continue
		var a2 := (al * 0.5 if st.z > 0.25 else al) * 0.7
		draw_texture_rect_region(A.atlas, Rect2(P.x + off * 0.55 - ss / 2, P.y + off * 0.75 - ss / 2 + R * 0.12, ss, ss * 0.92), A.R_SOFT, Color(1, 1, 1, a2))
	if hand.vis > 0.02:
		var P := map(hand.x, hand.y)
		var off: float = (0.05 + hand.z * 0.42) * s
		_arm_shadow(P.x + off * 0.55, P.y + off * 0.75, hand.p, hand.vis, sh)
	_T(Transform2D(0.0, Vector2.ONE, 0.0, sh))
	for st in lst:
		if st.z <= 0.05:
			_draw_st(st)
	# gợi ý: quân nước này ăn được, khoanh phấn vàng; đòn gánh: vạch phấn từ quân này qua quân kia
	if hov != null and hov.pv != null:
		_T()
		for i in hov.pv.ganh + hov.pv.vay:
			var X := map(ptx(i), pty(i))
			chalk_loop(X, s * 0.25, s * 0.25, i * 3.1, Color8(255, 214, 90, int((0.7 + 0.3 * pulse) * 255)), maxf(2.0, s * 0.022))
		for pr in hov.pv.pairs:
			var X0 := map(ptx(pr[0]), pty(pr[0]))
			var X1 := map(ptx(pr[1]), pty(pr[1]))
			draw_dashed_line(X0, X1, Color8(255, 214, 90, int((0.55 + 0.3 * pulse) * 255)), maxf(2.0, s * 0.022), s * 0.065, true, true)
		_T(Transform2D(0.0, Vector2.ONE, 0.0, sh))
	for st in lst:
		if st.z > 0.05:
			_draw_st(st)
	# chữ phấn trên chỗ đi: nước này ăn mấy quân
	if live and Gm.sel >= 0 and int(S.hint):
		for t in targets_of(Gm.sel):
			var pv := preview(Gm.sel * 25 + t)
			var n: int = pv.ganh.size()
			var m: int = pv.vay.size()
			if not n and not m:
				continue
			var txt := ("gánh %d + vây %d" % [n, m]) if n and m else (("gánh %d" % n) if n else ("vây %d" % m))
			var fs := maxf(13.0, minf(20.0, s * 0.15))
			var X := map(ptx(t), pty(t))
			var up := -1.0 if pty(t) > 0 else 1.0
			chalk_text(X + Vector2(0, up * s * 0.36), txt, fs, Color("#ffe680"))
	_draw_fx(s)
	_draw_me(true)
	if petals.size():
		_T()
		for p in petals:
			var c := Vector2(p.x, p.y)
			var col: Color = p.c
			for q in 5:
				var a: float = p.a + 1.2566 * (q + 1)
				var cc: Vector2 = c + Vector2(sin(a), -cos(a)) * (p.s * 0.55)
				draw_colored_polygon(ellipse(cc, p.s * 0.36, p.s * 0.55, a, 12), col)
			draw_circle(c, p.s * 0.2, Color("#d9822b"), true, -1.0, true)
		petals = petals.filter(func(p): return p.y < L.H + 30)
	_T()

func _draw_st(st: Dictionary) -> void:
	var P := map(st.x, st.y)
	var Y: float = P.y - st.z * L.s * 0.34
	var D: float = st.r * L.s * 2 / 0.82 * (1 + st.z * 0.28)
	draw_texture_rect(A.quan(st.kind, st.v), Rect2(P.x - D / 2, Y - D / 2, D, D), false)

func _arm_shadow(fx: float, fy: float, p: int, vis: float, sh: Vector2) -> void:
	var s: float = L.s
	var o := Vector2(fx + s * (0.9 if p == 0 else -0.9), L.H + s * 0.6 if p == 0 else -s * 0.6)
	var d := Vector2(fx, fy) - o
	var ln := d.length()
	var wdt := s * 0.42
	_T(Transform2D(d.angle(), o + sh))
	draw_texture_rect(A.arm, Rect2(0, -wdt / 2, ln + wdt * 0.05, wdt), false, Color(1, 1, 1, 0.36 * minf(1.0, vis)))
	_T(Transform2D(0.0, Vector2.ONE, 0.0, sh))

func _draw_fx(s: float) -> void:
	_T()
	var keep := []
	for f in FX:
		var k: float = f.age / f.life
		if f.t == "dust":
			draw_circle(map(f.x, f.y), f.r * s * (1 + k * 2), Color8(214, 190, 150, int(0.5 * (1 - k) * 255)), true, -1.0, true)
		elif f.t == "ring":
			var col: Color = f.col
			draw_arc(map(f.x, f.y), s * (0.15 + k * 0.4), 0, TAU, 40, Color(col, 0.8 * (1 - k)), maxf(2.0, s * 0.025), true)
		elif f.t == "spark":
			_star(map(f.x, f.y) - Vector2(0, k * s * 0.3), f.r * s * (1 - k), Color8(255, 224, 110, int((1 - k) * 255)))
		elif f.t == "pole":
			# đòn gánh tre mọc ra từ quân vừa đi tới hai quân bị gánh, rồi mờ dần
			var gg := minf(1.0, f.age / 0.25)
			var fade := (1 - k) / 0.4 if k > 0.6 else 1.0
			var Xm := map(f.mx, f.my)
			var Xa := map(f.ax, f.ay)
			var Xb := map(f.bx, f.by)
			var lift := s * 0.06
			var C := Vector2(Xm.x, Xm.y - s * 0.2)
			var PA := Xm + (Xa - Xm) * gg - Vector2(0, lift)
			var PB := Xm + (Xb - Xm) * gg - Vector2(0, lift)
			var curve := BG.quad(PA, C, PB, 24)
			var shd := PackedVector2Array()
			var hi := PackedVector2Array()
			for p in curve:
				shd.append(p + Vector2(s * 0.05, s * 0.07))
				hi.append(p - Vector2(0, s * 0.012))
			draw_polyline(shd, Color(0.157, 0.086, 0.024, 0.28 * fade), s * 0.07, true)
			draw_polyline(curve, Color(Color("#6b4a1c"), fade), s * 0.068, true)
			draw_polyline(curve, Color(Color("#d8b25a"), fade), s * 0.048, true)
			draw_polyline(hi, Color(1, 0.94, 0.745, 0.85 * fade), s * 0.014, true)
			for t in [0.17, 0.39, 0.61, 0.83]:
				var u: float = t
				var x0 := PA * (1 - u) * (1 - u) + C * 2.0 * (1 - u) * u + PB * u * u
				var u2 := u + 0.01
				var x1 := PA * (1 - u2) * (1 - u2) + C * 2.0 * (1 - u2) * u2 + PB * u2 * u2
				var dd := (x1 - x0)
				var l := maxf(1e-4, dd.length())
				var nv := Vector2(-dd.y, dd.x) / l * s * 0.026
				draw_line(x0 - nv, x0 + nv, Color(Color("#7a5520"), fade), maxf(1.5, s * 0.012), true)
		elif f.t == "loop":
			var fade := (1 - k) / 0.35 if k > 0.65 else 1.0
			var gg := minf(1.0, f.age / 0.3)
			for i in f.pts:
				chalk_loop(map(ptx(i), pty(i)), s * (0.5 - 0.22 * gg), s * (0.5 - 0.22 * gg), i * 2.2, Color(Color("#ffd85a"), fade), maxf(2.5, s * 0.03))
		elif f.t == "txt":
			var X := map(f.x, f.y)
			var e := minf(1.0, f.age / 0.18)
			var fs: float = maxf(18.0, s * 0.24) * f.big * (0.7 + 0.3 * e)
			var al := (1 - k) / 0.3 if k > 0.7 else 1.0
			var fo := A.font(800)
			var n := roundi(fs * K)
			var w := fo.get_string_size(f.txt, HORIZONTAL_ALIGNMENT_LEFT, -1, n).x
			var asc := fo.get_ascent(n)
			var dsc := fo.get_descent(n)
			var yy: float = (X.y - f.age * s * 0.35) * K
			var pos := Vector2(X.x * K - w / 2, yy + (asc - dsc) / 2)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			draw_string_outline(fo, pos, f.txt, HORIZONTAL_ALIGNMENT_LEFT, -1, n, roundi(fs * 0.2 * K), Color(0.353, 0.157, 0.047, 0.95 * al))
			draw_string(fo, pos, f.txt, HORIZONTAL_ALIGNMENT_LEFT, -1, n, Color(f.col, al))
			_T()
		if f.age < f.life:
			keep.append(f)
	FX = keep

# ------------------------------------------------------------ lá me khô li ti lâu lâu rơi xuống
func _step_me(dt: float) -> void:
	ME.next -= dt
	if ME.next <= 0:
		ME.next = 5 + randf() * 9
		var n := 2 + randi() % 5
		var x0: float = randf() * L.W
		var y0: float = randf() * L.H
		for k in n:
			ME.fall.append({"x": x0 + (randf() - 0.5) * 140, "y": y0 + (randf() - 0.5) * 100, "z": 1 + randf() * 0.4, "vz": 0.11 + randf() * 0.06, "ph": randf() * 6.28,
				"w": 2 + randf() * 2.5, "a": randf() * 6.28, "va": (randf() - 0.5) * 5, "dry": randf() * 0.5, "len": maxf(8.0, L.s * (0.06 + randf() * 0.025)),
				"drift": (randf() - 0.3) * 14, "age": 0.0})
	var still := []
	for f in ME.fall:
		f.z -= f.vz * dt
		f.ph += f.w * dt
		f.a += f.va * dt
		f.x += (sin(f.ph) * 22 + f.drift) * dt
		f.y += (cos(f.ph * 0.7) * 10 + 6) * dt
		if f.z <= 0:
			f.z = 0.0
			f.age = 0.0
			ME.ground.append(f)
		else:
			still.append(f)
	ME.fall = still
	for f in ME.ground:
		f.age += dt
	ME.ground = ME.ground.filter(func(f): return f.age < 70)
	if ME.ground.size() > 40:
		ME.ground = ME.ground.slice(ME.ground.size() - 40)

func _me_leaf(f: Dictionary, at: Vector2, scale: float, flip: float, alpha: float) -> void:
	var d := minf(1.0, f.dry + f.age / 35.0)
	var c := Color8(int(176 + 30 * d), int(170 - 40 * d), int(70 - 10 * d))
	var l: float = f.len * scale
	var w := l * 0.38 * maxf(0.15, absf(flip))
	draw_colored_polygon(ellipse(at, l / 2, w / 2, f.a, 12), Color(c, alpha))
	var dv := Vector2(cos(f.a), sin(f.a)) * l / 2
	draw_line(at - dv, at + dv, Color(c.r - 50 / 255.0, c.g - 50 / 255.0, c.b - 30 / 255.0, 0.6 * alpha), maxf(0.6, l * 0.05), true)

func _draw_me(air: bool) -> void:
	_T()
	var H: float = L.s * 3.2
	if not air:
		for f in ME.ground:
			var fade: float = (70 - f.age) / 6.0 if f.age > 64 else 1.0
			draw_colored_polygon(ellipse(Vector2(f.x + 0.6, f.y + 0.9), f.len * 0.52, f.len * 0.18, f.a, 12), Color(0.133, 0.078, 0.024, 0.35 * fade))
			_me_leaf(f, Vector2(f.x, f.y), 1.0, 0.9, fade)
		return
	for f in ME.fall:
		var fl := cos(f.ph * 1.7)
		var sp := Vector2(f.x + SUN.x * f.z * H, f.y + SUN.y * f.z * H)
		draw_colored_polygon(ellipse(sp, f.len * 0.55 * (1 + f.z * 0.4), f.len * 0.2 * (1 + f.z * 0.4) * maxf(0.2, absf(fl)), f.a, 12), Color(0.133, 0.078, 0.024, 0.28 * (1 - f.z * 0.5)))
		_me_leaf(f, Vector2(f.x, f.y), 1 + f.z * 0.55, fl, 1.0)

# ============================================================ hiệu ứng
func dust(x: float, y: float, n: int) -> void:
	for k in n:
		var a := randf() * TAU
		var sp := 0.15 + randf() * 0.35
		FX.append({"t": "dust", "x": x, "y": y, "vx": cos(a) * sp, "vy": sin(a) * sp, "r": 0.02 + randf() * 0.03, "life": 0.5 + randf() * 0.3, "age": 0.0})

func ring(x: float, y: float, col := Color8(255, 250, 235)) -> void:
	FX.append({"t": "ring", "x": x, "y": y, "life": 0.45, "age": 0.0, "col": col})

func float_txt(x: float, y: float, txt: String, col: Color, big := 1.0) -> void:
	FX.append({"t": "txt", "x": x, "y": y, "txt": txt, "col": col, "big": big, "life": 1.4, "age": 0.0})

func sparks(x: float, y: float, n: int) -> void:
	for k in n:
		var a := randf() * TAU
		var sp := 0.4 + randf() * 0.9
		FX.append({"t": "spark", "x": x, "y": y, "vx": cos(a) * sp, "vy": sin(a) * sp, "life": 0.6 + randf() * 0.5, "age": 0.0, "r": 0.03 + randf() * 0.03})

func petal_rain(n: int) -> void:
	for k in n:
		petals.append({"x": randf() * L.W, "y": -20 - randf() * L.H * 0.8, "vy": 40 + randf() * 60, "vx": (randf() - 0.3) * 30, "a": randf() * 6.28,
			"va": (randf() - 0.5) * 4, "s": 6 + randf() * 7, "ph": randf() * 6.28, "c": Color("#ffd23a") if randf() < 0.8 else Color("#ffefa8")})

# ============================================================ bóng cây lay (WebGL của web: nhân màu đè lên cảnh)
const SHADE_SRC := """shader_type canvas_item;
uniform vec2 res;
uniform float t;
uniform vec2 tree;
uniform float str;
uniform sampler2D fr : filter_linear, repeat_disable;
float h(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float n(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(h(i),h(i+vec2(1,0)),f.x),mix(h(i+vec2(0,1)),h(i+vec2(1,1)),f.x),f.y);}
float fbm(vec2 p){float v=0.,a=.5;for(int i=0;i<5;i++){v+=a*n(p);p=p*2.07+vec2(1.7,9.2);a*=.5;}return v;}
float tx(vec2 q){return texture(fr,vec2(q.x,1.0-q.y)).r;}
float frond(vec2 q,float r){
  if(q.x<0.||q.y<0.||q.x>1.||q.y>1.)return 0.;
  float s=tx(q)*.4;
  s+=tx(q+vec2(r,0.))*.15+tx(q-vec2(r,0.))*.15+tx(q+vec2(0.,r))*.15+tx(q-vec2(0.,r))*.15;
  return s;}
void fragment(){
  vec2 fc=vec2(UV.x,1.0-UV.y)*res;
  float m=min(res.x,res.y);vec2 p=fc/m;vec2 uv=fc/res;
  vec2 corner=res/m;vec2 d=p-corner;float dist=length(d);
  float a=(.018*sin(t*.55)+.007*sin(t*1.63+1.))*smoothstep(0.,1.,dist);
  d=mat2(vec2(cos(a),sin(a)),vec2(-sin(a),cos(a)))*d;
  d+=vec2(sin(t*1.9+p.y*9.),cos(t*1.7+p.x*8.))*.004*dist;
  vec2 q=vec2(1.)+d/1.25;
  float fsh=frond(q,.003+.006*dist)*.92;
  vec2 w=vec2(sin(t*.45+p.y*3.)+sin(t*.23+p.x*1.7),cos(t*.37+p.x*2.6)+sin(t*.19+p.y*2.))*.006;
  float big=fbm((p+w)*2.4+vec2(3.1,1.3)),fine=fbm((p+w*1.8)*8.+vec2(7.,2.)),vf=fbm((p+w*2.2)*22.+vec2(4.,8.));
  float dd=length((p-tree)*vec2(1.,1.12));
  float th=mix(.36,.95,smoothstep(.05,.9,dd));
  float v=big*.5+fine*.3+vf*.2;
  float cover=smoothstep(th-.03,th+.03,v)*.8;
  float sh=clamp(max(fsh,cover),0.,1.)*str;
  vec3 lit=vec3(1.,.99,.955);vec3 shade=vec3(.64,.66,.72);
  vec3 col=mix(lit,shade,sh);
  vec2 qv=(uv-.5)*vec2(res.x/res.y,1.);float vig=smoothstep(1.15,.35,length(qv*vec2(.9,1.15)));
  col*=mix(.88,1.,vig);
  COLOR=vec4(col,1.);
}"""

func _build_shade() -> void:
	_svp = SubViewport.new()
	_svp.disable_3d = true
	_svp.transparent_bg = false
	_svp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var cr := ColorRect.new()
	cr.name = "q"
	var sh := Shader.new()
	sh.code = SHADE_SRC
	_shade_mat = ShaderMaterial.new()
	_shade_mat.shader = sh
	_shade_mat.set_shader_parameter("fr", A.img("frond"))
	_shade_mat.set_shader_parameter("tree", Vector2(-0.08, -0.1))
	_shade_mat.set_shader_parameter("str", 0.9)
	cr.material = _shade_mat
	_svp.add_child(cr)
	add_child(_svp)
	shade = TextureRect.new()
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.texture = _svp.get_texture()
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	shade.material = m
	add_child(shade)

func _resize_shade() -> void:
	var sz := Vector2i(maxi(2, roundi(L.W * 0.5)), maxi(2, roundi(L.H * 0.5)))
	_svp.size = sz
	var cr: ColorRect = _svp.get_node("q")
	cr.size = Vector2(sz)
	_shade_mat.set_shader_parameter("res", Vector2(sz))
	shade.position = Vector2.ZERO
	shade.size = _vs
	_shade_drawn = false

func _shade_step(dt: float) -> void:
	var on := bool(int(S.fx))
	_shade_t += dt
	if not on and _shade_drawn:
		return
	if _shade_t < 0.033 and _shade_drawn:
		return
	_shade_t = 0.0
	_shade_mat.set_shader_parameter("t", Time.get_ticks_msec() / 1000.0 if on else 12.0)
	_svp.render_target_update_mode = SubViewport.UPDATE_ONCE
	_shade_drawn = true

func shade_enable(_v: bool) -> void:
	_shade_drawn = false

# ============================================================ diễn các sự kiện của luật
func wait(ms: float) -> void:
	await get_tree().create_timer(ms / 1000.0 / (float(S.speed) * Gm.ff)).timeout

func dur(sec: float) -> float:
	return sec / (float(S.speed) * Gm.ff)

func do_step(e: Dictionary, dragged: bool) -> void:
	var st = null
	for t in ST:
		if t.home == "h":
			st = t
			break
	if st == null:
		st = stone_at(e.from)
	var tx := ptx(e.to) + (randf() - 0.5) * 0.04
	var ty := pty(e.to) + (randf() - 0.5) * 0.04
	if st == null:
		return
	hand.p = e.p
	hand.track = st
	hand.show = true
	if dragged:
		fly(st, tx, ty, 0.0, dur(0.12), 0.0, land_in("p" + str(e.to), true), "p" + str(e.to))
		await wait(150)
	else:
		st.home = "air"
		fly(st, st.x, st.y, 0.28, dur(0.13), 0.0, null, "air")
		await wait(140)
		fly(st, tx, ty, 0.0, dur(0.34), 0.22, land_in("p" + str(e.to), true), "p" + str(e.to))
		await wait(370)
	hand.show = false
	await wait(60)
	hand.track = null
	Gm.trailA = 1.4
	if e.forced and not is_human(e.p):
		hud.toast(Gm.names[e.p] + " bị mở, phải gánh", "soft")

# một điểm bị ăn: quân bên kia về rổ chủ, một quân dư của bên ăn ra đứng chỗ đó
func convert_pt(i: int, p: int, delay: float) -> void:
	var old = stone_at(i)
	if old != null:
		old.home = "air"
		var q := spot_in("b" + str(1 - p), old.r)
		fly(old, q.x, q.y, 0.0, dur(0.5), 0.75, land_in("b" + str(1 - p)), "b" + str(1 - p), dur(delay))
	var pool := in_home("b" + str(p))
	var nw = null
	for t in pool:
		if nw == null or t.z > nw.z:
			nw = t
	if nw != null:
		nw.home = "air"
		fly(nw, ptx(i) + (randf() - 0.5) * 0.04, pty(i) + (randf() - 0.5) * 0.04, 0.0, dur(0.5), 0.85, land_in("p" + str(i), true), "p" + str(i), dur(delay + 0.16))
	else:
		var st := mk_stone(p, "air", Vector2(ptx(i), pty(i)))
		st.z = 1.4
		ST.append(st)
		fly(st, ptx(i), pty(i), 0.0, dur(0.35), 0.0, land_in("p" + str(i), true), "p" + str(i), dur(delay + 0.16))

func do_ganh(e: Dictionary) -> void:
	for pr in e.pairs:
		FX.append({"t": "pole", "mx": ptx(e.at), "my": pty(e.at), "ax": ptx(pr[0]), "ay": pty(pr[0]), "bx": ptx(pr[1]), "by": pty(pr[1]), "life": 1.5, "age": 0.0})
	snd.ganh(e.pts.size())
	float_txt(ptx(e.at), pty(e.at) - 0.35, "Gánh đôi!" if e.pts.size() > 2 else "Gánh!", Color("#ffe27a"), 1.3 if e.pts.size() > 2 else 1.1)
	if e.pts.size() > 2:
		hud.toast("Gánh đôi!", "big")
		shake = 6.0
	await wait(420)
	for k in e.pts.size():
		var i: int = e.pts[k]
		convert_pt(i, e.p, k * 0.09)
		sparks(ptx(i), pty(i), 8)
	await wait(780 + e.pts.size() * 90)

func do_vay(e: Dictionary) -> void:
	FX.append({"t": "loop", "pts": e.pts, "life": 1.6, "age": 0.0})
	snd.vay()
	shake = 5.0
	var c := Vector2.ZERO
	for i in e.pts:
		c += Vector2(ptx(i), pty(i)) / e.pts.size()
	float_txt(c.x, c.y - 0.35, ("Vây %d quân!" % e.pts.size()) if e.pts.size() > 1 else "Vây!", Color("#ffe27a"), 1.15)
	await wait(500)
	for k in e.pts.size():
		var i: int = e.pts[k]
		convert_pt(i, e.p, k * 0.08)
		sparks(ptx(i), pty(i), 6)
	await wait(800 + e.pts.size() * 80)

func play_events(evs: Array, dragged: bool) -> void:
	for e in evs:
		if e.t == "step":
			await do_step(e, dragged)
		elif e.t == "ganh":
			await do_ganh(e)
		elif e.t == "vay":
			await do_vay(e)
	await wait(120)
	finish_all_flights()

func visuals_match(s: Dictionary) -> bool:
	for i in 25:
		var h := "p" + str(i)
		var a := ST.filter(func(t): return t.home == h)
		if a.size() != (1 if s.b[i] else 0) or (a.size() and a[0].kind != s.b[i] - 1):
			return false
	for p in [0, 1]:
		var h := "b" + str(p)
		var n := ST.filter(func(t): return t.home == h and t.kind == p).size()
		if n != TOTAL - E.count(s.b, p):
			return false
	for t in ST:
		if t.home == "h" or t.home == "air" or t.fly != null:
			return false
	return true

# ============================================================ ván cờ
func new_game() -> void:
	Gm.R = rules_now()
	var first := 0
	if Gm.mode == "ai":
		first = 1 if S.first == "ai" else ((0 if randf() < 0.5 else 1) if S.first == "rnd" else 0)
	else:
		first = 0 if randf() < 0.5 else 1
	Gm.s = E.new_state(first)
	Gm.hist = []
	Gm.undoLeft = 3
	Gm.sel = -1
	Gm.busy = true
	Gm.moving = false
	Gm.started = true
	Gm.trailA = 0.0
	rebuild(Gm.s)
	hud.setup_cards()
	hud.close_all()
	hud.toast(((("Bạn" if Gm.mode == "ai" else Gm.names[0])) if first == 0 else Gm.names[1]) + " đi trước nghen!", "soft")
	var tok := ai_token
	await get_tree().create_timer(0.7).timeout
	if tok == ai_token:
		next_turn()

func next_turn() -> void:
	if Gm.s == null:
		return
	if Gm.needRebuild or not visuals_match(Gm.s):
		Gm.needRebuild = false
		rebuild(Gm.s)
	Gm.busy = false
	save_game()
	if Gm.s.over:
		hud.update_cards()
		end_game()
		return
	if E.forced(Gm.s, Gm.R) != null and is_human(Gm.s.turn):
		# "mở": chỉ được gánh vô điểm bên kia vừa rời; một quân đi được thì chọn sẵn
		hud.toast((Gm.names[Gm.s.turn] + " bị mở, phải gánh!") if Gm.mode == "pvp" else "Bị mở rồi, phải gánh!", "soft")
		snd.mo()
		var mov := movable().keys()
		if mov.size() == 1:
			Gm.sel = mov[0]
	hud.update_cards()
	if not is_human(Gm.s.turn):
		ai_turn()

func ai_turn() -> void:
	ai_token += 1
	var tok := ai_token
	var s0 := E.clone(Gm.s)
	var t0 := Time.get_ticks_msec()
	Gm.busy = true
	Gm.aiWaiting = true
	hud.update_cards()
	var R: Dictionary = Gm.R.duplicate()
	var lv: int = Gm.level
	var mv := -1
	if OS.has_feature("web") or OS.get_processor_count() < 2:
		await get_tree().process_frame
		await get_tree().process_frame
		if tok != ai_token:
			return
		mv = E.think(s0, R, lv)
	else:
		if _thr != null and _thr.is_started():
			_thr.wait_to_finish()
		_thr = Thread.new()
		_thr.start(Callable(E, "think").bind(s0, R, lv, 0))
		while _thr.is_alive():
			await get_tree().process_frame
		mv = _thr.wait_to_finish()
		_thr = null
	if tok != ai_token or Gm.s == null:
		return
	if mv < 0 or not E.legal(Gm.s, Gm.R).has(mv):
		mv = E.think(s0, Gm.R, mini(Gm.level, 2), 300)
	var delay := maxf(0.0, 700 - (Time.get_ticks_msec() - t0))
	await get_tree().create_timer(delay / 1000.0).timeout
	if tok != ai_token:
		return
	Gm.aiWaiting = false
	hud.update_cards()
	var f := mv / 25
	ring(ptx(f), pty(f), Color8(255, 214, 90))
	await wait(300)
	if tok != ai_token:
		return
	play_move(mv)

func play_move(mv: int, dragged := false) -> void:
	if Gm.s == null or Gm.s.over or Gm.moving:
		return
	Gm.moving = true
	var mover: int = Gm.s.turn
	if is_human(mover):
		Gm.hist.append(E.clone(Gm.s))
	Gm.busy = true
	Gm.sel = -1
	Gm.hoverT = -1
	hud.update_cards()
	hud.show_ff(true)
	var s2 := E.clone(Gm.s)
	var ev := []
	E.move(s2, mv, Gm.R, ev)
	await play_events(ev, dragged)
	Gm.s = s2
	if not visuals_match(Gm.s):
		await get_tree().create_timer(0.3).timeout
		finish_all_flights()
		if not visuals_match(Gm.s):
			rebuild(Gm.s)
	var g = null
	var v = null
	for e in ev:
		if e.t == "ganh":
			g = e
		elif e.t == "vay":
			v = e
	var n: int = (g.pts.size() if g != null else 0) + (v.pts.size() if v != null else 0)
	if Gm.mode == "ai":
		if mover == 1:
			if ev[0].forced and randf() < 0.6:
				say("mo")
			elif v != null:
				say("vay")
			elif n > 2:
				say("big")
			elif n and randf() < 0.6:
				say("eat")
		elif n >= 2 and randf() < 0.7:
			say("hurt")
	Gm.busy = false
	Gm.moving = false
	hud.show_ff(false)
	Gm.ff = 1.0
	next_turn()

func undo() -> void:
	if Gm.hist.is_empty() or Gm.busy or not is_human(Gm.s.turn):
		return
	if Gm.mode == "ai":
		if Gm.undoLeft <= 0:
			return
		Gm.undoLeft -= 1
	ai_token += 1
	Gm.s = Gm.hist.pop_back()
	Gm.sel = -1
	Gm.trailA = 0.0
	rebuild(Gm.s)
	hud.update_cards()
	save_game()
	hud.toast("Đi lại", "soft")

func say(kind: String) -> void:
	if Gm.mode != "ai":
		return
	var lines = BANTER[OPP[Gm.level].k].get(kind)
	if lines == null:
		return
	hud.bubble(lines[randi() % lines.size()])

func end_game() -> void:
	var s: Dictionary = Gm.s
	var w: int = s.winner
	store_del("cg-save-v1")
	var title := ""
	var av := ""
	if w < 0:
		title = "Hòa rồi, huề nghen!"
		av = Gm.av[0]
	elif Gm.mode == "ai":
		title = "Bạn thắng rồi nghen!" if w == 0 else OPP[Gm.level].name + " thắng rồi!"
		av = Gm.av[w]
	else:
		title = Gm.names[w] + " thắng rồi!"
		av = Gm.av[w]
	if Gm.mode == "ai":
		var k := "w" if w == 0 else ("l" if w == 1 else "d")
		stats[k][Gm.level] = int(stats[k][Gm.level]) + 1
		store_set("cg-stats-v1", stats)
		say("lose" if w == 0 else ("win" if w == 1 else "lose"))
	var human_won: bool = w >= 0 if Gm.mode == "pvp" else w == 0
	if human_won:
		snd.win()
		petal_rain(90)
	elif w >= 0:
		snd.lose()
	else:
		snd.win()
	var why: String = {"het": "Bên thua hết sạch quân", "ket": "Bên thua hết đường đi", "quiet": "%d lượt liền không ai ăn được quân nào" % int(Gm.R.quiet), "lap": "Thế cờ lặp lại ba lần"}.get(s.end, "")
	if Gm.mode == "ai":
		why += " · gặp %s: thắng %d, thua %d, hòa %d" % [OPP[Gm.level].name, int(stats.w[Gm.level]), int(stats.l[Gm.level]), int(stats.d[Gm.level])]
	hud.end_info(av, title, why, s, w)
	ended.emit(Gm.mode, int(Gm.level), w)
	await get_tree().create_timer(1.1 if human_won else 0.9).timeout
	hud.show_ov("end")

func reward(xu: int, left: int, mx: int) -> void:
	hud.set_reward(xu, left, mx)
	if xu > 0:
		hud.toast("+%d xu" % xu, "big")

func resume_game() -> void:
	var sv = store.get("cg-save-v1", null)
	if not (sv is Dictionary):
		return
	Gm.mode = String(sv.mode)
	Gm.level = int(sv.level)
	Gm.names = [String(sv.names[0]), String(sv.names[1])]
	Gm.av = [String(sv.av[0]), String(sv.av[1])]
	Gm.s = deser(sv.s)
	Gm.R = {"mo": bool(sv.R.get("mo", true)), "quiet": int(sv.R.get("quiet", 40))}
	Gm.hist = []
	for h in sv.get("hist", []):
		Gm.hist.append(deser(h))
	Gm.undoLeft = int(sv.get("undoLeft", 3))
	Gm.sel = -1
	Gm.busy = true
	Gm.moving = false
	Gm.started = true
	Gm.trailA = 1.0
	rebuild(Gm.s)
	hud.setup_cards()
	hud.close_all()
	ai_token += 1
	var tok := ai_token
	await get_tree().create_timer(0.3).timeout
	if tok == ai_token:
		next_turn()

func start(mode: String, level: int, names: Array) -> void:
	ai_token += 1
	Gm.mode = mode
	if mode == "ai":
		Gm.level = level
		Gm.names = ["Bạn", OPP[level].name]
		Gm.av = ["me", OPP[level].k]
	else:
		Gm.names = names
		Gm.av = ["me", "p2"]
	new_game()

func go_home() -> void:
	save_game()
	closed.emit()

# ============================================================ bấm, kéo
func own_piece(i: int) -> bool:
	return Gm.s != null and i >= 0 and Gm.s.b[i] == Gm.s.turn + 1

func select(i: int) -> void:
	if Gm.sel != i:
		Gm.sel = i
		snd.sel()
		if tut_step == 0:
			tut_step = 1
	hud.update_cards()

func choose(from: int, to: int, dragged := false) -> bool:
	var mv := from * 25 + to
	if not E.legal(Gm.s, Gm.R).has(mv):
		return false
	if tut_step < 2:
		tut_step = 2
		store_set("cg-tut", 2)
	play_move(mv, dragged)
	return true

func _gui_input(ev: InputEvent) -> void:
	if not _ready_ok:
		return
	var pos := Vector2.ZERO
	var kind := ""
	if ev is InputEventScreenTouch:
		if ev.index != 0:
			return
		pos = ev.position
		kind = "down" if ev.pressed else "up"
	elif ev is InputEventScreenDrag:
		if ev.index != 0:
			return
		pos = ev.position
		kind = "move"
	elif ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		pos = ev.position
		kind = "down" if ev.pressed else "up"
	elif ev is InputEventMouseMotion:
		pos = ev.position
		kind = "move"
	else:
		return
	accept_event()
	var X := pos / K
	if kind == "down":
		_pdown(X)
	elif kind == "move":
		_pmove(X)
	else:
		_end_drag()

func _pdown(X: Vector2) -> void:
	if not Gm.started or Gm.s == null:
		return
	if Gm.busy and Gm.moving:
		if Gm.ff == 1.0:
			hud.ff_toggle()
		return
	if not human_live():
		return
	var uv := unmap(X.x, X.y)
	var tol := maxf(0.42, 22.0 / L.s)
	var i := point_at(uv.x, uv.y, tol)
	if Gm.sel >= 0 and i >= 0 and targets_of(Gm.sel).has(i):
		choose(Gm.sel, i)
		return
	if own_piece(i) and movable().has(i):
		select(i)
		Gm.press = {"i": i, "X": X}
		return
	if own_piece(i):
		Gm.sel = -1
		hud.update_cards()
		hud.toast("Bị mở, phải gánh trước!" if E.forced(Gm.s, Gm.R) != null else "Quân này hết đường đi", "soft")
		return
	if Gm.sel >= 0:
		Gm.sel = -1
		hud.update_cards()

func _pmove(X: Vector2) -> void:
	var uv := unmap(X.x, X.y)
	if Gm.press != null and Gm.drag == null and (X - Gm.press.X).length() > 9:
		var st = stone_at(Gm.press.i)
		if st != null:
			st.home = "h"
			st.rest = false
			Gm.drag = {"i": Gm.press.i, "st": st, "t": -1}
			hand.p = Gm.s.turn
			hand.track = st
			hand.show = true
	if Gm.drag != null:
		var st: Dictionary = Gm.drag.st
		st.x = uv.x
		st.y = uv.y - 0.1
		st.z = 0.32
		var t := point_at(uv.x, uv.y, 0.5)
		Gm.drag.t = t if t >= 0 and targets_of(Gm.drag.i).has(t) else -1
		Gm.hoverT = Gm.drag.t
		return
	var i := point_at(uv.x, uv.y, maxf(0.42, 22.0 / L.s))
	Gm.hover = i if human_live() and own_piece(i) else -1
	Gm.hoverT = i if human_live() and Gm.sel >= 0 and i >= 0 and targets_of(Gm.sel).has(i) else -1
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if (Gm.hover >= 0 and movable().has(Gm.hover)) or Gm.hoverT >= 0 else Control.CURSOR_ARROW

func _end_drag() -> void:
	var d = Gm.drag
	Gm.press = null
	if d == null:
		return
	Gm.drag = null
	if d.t >= 0 and choose(d.i, d.t, true):
		return
	# không phải chỗ đi được: quân về chỗ cũ
	var st: Dictionary = d.st
	st.home = "air"
	fly(st, ptx(d.i), pty(d.i), 0.0, 0.18, 0.05, land_in("p" + str(d.i), true), "p" + str(d.i))
	await get_tree().create_timer(0.2).timeout
	hand.show = false
	hand.track = null

func _unhandled_key_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey) or not ev.pressed:
		return
	if hud.any_open():
		if ev.keycode == KEY_ESCAPE:
			hud.close_all()
		return
	if ev.keycode == KEY_ESCAPE:
		Gm.sel = -1
		hud.update_cards()
	elif ev.keycode == KEY_Z and (ev.ctrl_pressed or ev.meta_pressed):
		undo()
