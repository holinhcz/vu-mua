extends Control
# Ô ĂN QUAN viết lại bằng Godot (bản web: /mnt/project-files/o-an-quan/src/game.js). Sân đất miền Tây buổi trưa, bàn kẻ
# phấn 10 ô dân + 2 ô quan, sỏi rải bằng tay có vật lý nhỏ, dân ăn được bay về rổ của mỗi bên.
# Đơn vị bàn: một ô dân = 1; ô dân hàng dưới (người 0) x 0..5, y 1..2; hàng trên y 0..1; ô quan nửa elip ở x<0 và x>5.
# Màn dọc: bàn quay 90 độ theo chiều kim đồng hồ (hàng người 0 chạy dọc bên trái). Vẽ theo css px của bản web,
# nhân K (= devicePixelRatio) ra điểm ảnh thật. Nền tĩnh vẽ một lần (oq_bg.gd).

signal ended(mode: String, level: int, winner: int)
signal closed

const E := preload("res://logic/oq/oq_engine.gd")
const A := preload("res://logic/oq/oq_art.gd")
const BG := preload("res://logic/oq/oq_bg.gd")
const SND := preload("res://logic/oq/oq_snd.gd")
const HUD := preload("res://logic/oq/oq_hud.gd")
const TAN := preload("res://logic/oq/oq_tan.gd")

const QW := 0.95
const DR := 0.088
const QR := 0.235
const BW := 5 + 2 * QW
const SUN := Vector2(0.64, 0.77)
const PCOL := [Color8(86, 170, 232), Color8(240, 122, 146)]
const OPP := [
	{"k": "ut", "name": "Bé Út", "lvl": "Dễ", "tag": "mới tập chơi"},
	{"k": "ti", "name": "Thằng Tí", "lvl": "Vừa", "tag": "lanh chanh"},
	{"k": "hai", "name": "Chị Hai", "lvl": "Khó", "tag": "tính kỹ từng ô"},
	{"k": "sau", "name": "Ông Sáu", "lvl": "Cao thủ", "tag": "vô địch xóm"},
]
const DEF := {"non": 1, "qv": 10, "borrow": 1, "first": "me", "speed": 1.0, "fx": 1, "sound": 1, "hint": 1}
const BANTER := {
	"ut": {"eat": ["Hihi, em ăn được rồi!", "Ủa, em ăn hả? Vui quá!"], "big": ["Trời ơi nhiều dữ!"], "quan": ["Em ăn quan rồi nè!"], "lost": ["Ủa sao dừng rồi..."], "hurt": ["Huhu anh ăn hết của em rồi!", "Hổng chịu đâu!"], "win": ["Em thắng rồi! Hihi"], "lose": ["Thôi ván sau em gỡ!"]},
	"ti": {"eat": ["Hehe, ăn nha!", "Dô! Ăn ngon lành!"], "big": ["Thấy chưa, tui nói rồi mà!"], "quan": ["Quan về tay tui rồi nghen!"], "lost": ["Ờ... tính lộn."], "hurt": ["Ê ê, chơi gì kỳ vậy!", "Trời đất, mất cả đống!"], "win": ["Thua tui rồi nha, hehe!"], "lose": ["Ván này hên thôi nghen!"]},
	"hai": {"eat": ["Chị ăn ô này nghen.", "Vậy là gọn."], "big": ["Nước này chị tính lâu rồi."], "quan": ["Quan chị lấy nha em."], "lost": ["Ừ, chị chừa ô đó."], "hurt": ["Em đi khá đó!", "Ờ, nước hay."], "win": ["Ván sau em cẩn thận ô quan nghen."], "lose": ["Giỏi lắm, chị chịu!"]},
	"sau": {"eat": ["Hà hà, thấy chưa.", "Đi vậy mới gọi là đi."], "big": ["Ông chơi ô ăn quan từ hồi còn để chỏm!"], "quan": ["Quan non thì chờ, quan già thì ăn. Hà hà!"], "lost": ["Ông nhường bây đó."], "hurt": ["Bây được à nghen!", "Hừm, nước này ông không thấy."], "win": ["Về tập thêm rồi qua kiếm ông."], "lose": ["Hậu sinh khả úy! Ông phục."]},
}
const SAVE := "user://oanquan.json"

var K := 1.0
var L := {"W": 0.0, "H": 0.0, "port": false, "s": 100.0, "ox": 0.0, "oy": 0.0, "bx": [], "bas": [], "obst": [], "cards": [], "tools": Rect2(), "porch": 30.0}
var S := {}
var store := {}
var stats := {"w": [0, 0, 0, 0], "l": [0, 0, 0, 0], "d": [0, 0, 0, 0]}
var Gm := {"mode": "ai", "level": 1, "names": ["Bạn", "Bé Út"], "av": ["me", "ut"], "s": null, "R": {}, "hist": [], "busy": false, "sel": -1, "hover": -1, "hoverArrow": 0,
	"vis": null, "ff": 1.0, "started": false, "aiWaiting": false, "press": null, "moving": false, "undoLeft": 3, "markCell": -1, "markA": 0.0, "needRebuild": false,
	"hintKey": "", "hintVal": null}
var ST := []
var sid := 0
var clock := 0.0
var hand := {"x": 2.5, "y": 1.0, "z": 0.95, "tx": 2.5, "ty": 1.0, "vis": 0.0, "show": false, "cell": -1, "p": 0}
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
var tan: Node2D = null
var DPR := 1.0
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
var _pressing := false

# ============================================================ dựng
func setup(k: float) -> void:
	DPR = maxf(1.0, k)
	K = DPR

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_load()
	S = DEF.duplicate()
	S.merge(store.get("oaq-set-v1", {}), true)
	var st0 = store.get("oaq-stats-v1", null)
	if st0 is Dictionary:
		stats = st0
	tut_step = int(store.get("oaq-tut", 0))
	snd = SND.new()
	add_child(snd)
	snd.on = bool(int(S.sound))
	A.build_atlas()
	A.build_arm()
	ME.next = 3 + randf() * 4
	_build_shade()
	tan = TAN.new()
	add_child(tan)
	hud = HUD.new()
	hud.game = self
	add_child(hud)
	await get_tree().process_frame
	_layout()
	# bàn mẫu sau menu
	Gm.vis = E.new_state(0)
	Gm.s = null
	rebuild(Gm.vis)
	hud.build_menu()
	hud.update_cards()
	hud.show_ov("menu")
	_ready_ok = true

func _exit_tree() -> void:
	ai_token += 1
	if _thr != null and _thr.is_started():
		_thr.wait_to_finish()

func rules_now() -> Dictionary:
	return {"non": bool(int(S.non)), "qv": int(S.qv), "borrow": bool(int(S.borrow))}

func map(u: float, v: float) -> Vector2:
	if L.port:
		return Vector2(L.ox + (2 - v) * L.s, L.oy + (u + QW) * L.s)
	return Vector2(L.ox + (u + QW) * L.s, L.oy + v * L.s)

func unmap(X: float, Y: float) -> Vector2:
	if L.port:
		return Vector2((Y - L.oy) / L.s - QW, 2 - (X - L.ox) / L.s)
	return Vector2((X - L.ox) / L.s - QW, (Y - L.oy) / L.s)

# tọa độ bàn -> css px (setLogical của web)
func lg(sh := Vector2.ZERO) -> Transform2D:
	var s: float = L.s
	if L.port:
		return Transform2D(Vector2(0, s), Vector2(-s, 0), Vector2(L.ox + 2 * s, L.oy + QW * s) + sh)
	return Transform2D(Vector2(s, 0), Vector2(0, s), Vector2(L.ox + QW * s, L.oy) + sh)

# vùng cấm của bàn theo đúng hình (giữa chữ nhật + 2 đầu bầu dục cắt lát), pad tính theo ô: lá xoài được phủ góc sân trống cạnh đầu quan
func board_bans(pad: float) -> Array:
	var out := []
	var rc := func(u0: float, v0: float, u1: float, v1: float) -> Rect2:
		var a := map(u0, v0)
		var b := map(u1, v1)
		return Rect2(minf(a.x, b.x), minf(a.y, b.y), absf(b.x - a.x), absf(b.y - a.y))
	out.append(rc.call(0.0, -pad, 5.0, 2 + pad))
	var n := 6
	for k in n:
		var t0 := float(k) / n
		var t1 := float(k + 1) / n
		var h := sqrt(maxf(0.0, 1 - t0 * t0)) + pad      # nửa cao lát (lấy mép trong, to hơn)
		var w1 := t1 * QW + (pad if k == n - 1 else 0.0)
		out.append(rc.call(-w1, 1 - h, -t0 * QW, 1 + h))
		out.append(rc.call(5 + t0 * QW, 1 - h, 5 + w1, 1 + h))
	return out

func board_rect(pad: float) -> Rect2:
	var a := map(-QW, 0)
	var b := map(5 + QW, 2)
	var x0 := minf(a.x, b.x)
	var x1 := maxf(a.x, b.x)
	var y0 := minf(a.y, b.y)
	var y1 := maxf(a.y, b.y)
	return Rect2(x0 - pad, y0 - pad, x1 - x0 + 2 * pad, y1 - y0 + 2 * pad)

func _layout() -> void:
	var vs := get_viewport_rect().size
	_vs = vs
	# Link 11-22 "sắp xếp nền cảnh cho phù hợp các màn hình": cả sân + giao diện co giãn đều theo màn như cờ gánh.
	# Khổ chuẩn: dọc 412x915 css, ngang 1280x720; màn khác nhân U = min(rộng, cao) so với khổ chuẩn.
	var wc := vs.x / DPR
	var hc := vs.y / DPR
	var U := minf(wc / 412.0, hc / 915.0) if hc > wc * 1.05 else minf(wc / 1280.0, hc / 720.0)
	K = DPR * clampf(U, 0.4, 3.0)
	var W := vs.x / K
	var H := vs.y / K
	L.W = W
	L.H = H
	L.port = H > W * 1.12
	hud.layout(W, H, L.port)
	var c0: Rect2 = hud.card_rect(0)
	var c1: Rect2 = hud.card_rect(1)
	L.cards = [c0, c1]
	L.tools = hud.tools_rect()
	var ch := maxf(maxf(c0.size.y, c1.size.y), 44.0)
	# Link 11-22 "nhỏ lại chút tán ló ra to hơn" (chỉ màn 1980x900): bàn thu nhỏ từng nấc (tối đa 20%) tới khi lá xoài thấy được đủ nhiều
	var vis := Rect2(0, (L.tools as Rect2).end.y, W, H - (L.tools as Rect2).end.y)
	var want := W * H * 0.07
	var best_f := 1.0
	var best_a := -1.0
	# chỉ màn ngang rất dài (như 1980x900) mới thu bàn; màn khác giữ cỡ bàn cũ (Link 11-22 "bảo làm 1980x900 thôi")
	for f in ([1.0, 0.95, 0.9, 0.85, 0.8] if W > H * 2.0 else [1.0]):
		var a := _place(f, W, H, c0, c1, ch, vis)
		if a > best_a * 1.15:
			best_a = a
			best_f = f
		if a >= want:
			break
	_place(best_f, W, H, c0, c1, ch, vis)
	L.tan = TAN.rects(L.tan_sc, 2, L.tan_sh)
	tan.build(L.tan_sc, L.tan_sh, K, 0.2 if L.port else 0.25)   # Link 11-23: bóng tán xoài nhạt hơn
	_resize_shade()
	_bake_bg()

# đặt bàn (cỡ nhân f) + 2 rổ + chỗ tán; trả về diện tích lá xoài thấy được
func _place(f: float, W: float, H: float, c0: Rect2, c1: Rect2, ch: float, vis: Rect2) -> float:
	# rổ của mỗi bên nằm ngay cạnh thẻ người đó
	if not L.port:
		# chừa một vòng sân quanh bàn cho gà, lu, nón vừa cỡ thật
		L.s = minf(minf((W - 24) / (7.9 if W > 1000 else 7.3), (H - 2 * (ch + 14)) / 2.6), 195.0) * f
		L.ox = (W - BW * L.s) / 2
		L.oy = (H - 2 * L.s) / 2
		var room: float = L.oy - 10
		var br := maxf(24.0, minf(minf(room / 2, L.s * 0.52), 105.0))
		# Link 11-23 (nhận xét 6): rổ trên nằm trọn trên sân, không đè mép gạch hiên -> hiên mỏng lại vừa chừa chỗ rổ
		var top: float = board_rect(0).position.y
		L.porch_max = maxf(30.0, top - 16 - 2 * br)
		var ph0 := float(roundi(minf(maxf(30.0, minf(L.s * 0.78, (top - 12) * 0.6)), L.porch_max)))
		# Link 11-23 "rổ dính vào bàn cờ?": rổ không bao giờ chạm bàn (cách mép bàn >= 8), thà ló ra mép màn / đè hiên
		var bot: float = board_rect(0).end.y
		var y0 := maxf(minf(H - 8 - br, c0.position.y + c0.size.y / 2), bot + 8 + L.s * 0.1 + br)
		var y1 := minf(maxf(maxf(8 + br, ph0 + 4 + br), c1.position.y + c1.size.y / 2), top - 8 - L.s * 0.1 - br)
		L.bx = [Vector3(c0.end.x + 14 + br, y0, br), Vector3(c1.position.x - 14 - br, y1, br)]
	else:
		L.erase("porch_max")
		L.s = minf(minf((W - 2 * maxf(62.0, W * 0.16)) / 2, (H - 2 * (ch + 16)) / (BW + 0.05)), 215.0) * f
		L.ox = (W - 2 * L.s) / 2
		L.oy = (H - BW * L.s) / 2
		var m: float = L.ox
		var br := maxf(20.0, minf(minf(m * 0.42, L.s * 0.55), 80.0))
		L.bx = [Vector3(m / 2, c0.position.y - 10 - br, br), Vector3(W - m / 2, c1.end.y + 10 + br, br)]
	L.bas = []
	for b in L.bx:
		var u := unmap(b.x, b.y)
		L.bas.append({"x": u.x, "y": u.y, "r": b.z * 0.8 / L.s})
	# tán xoài caro bên trái (như cờ gánh): to nhất mà lá không chạm bàn, rổ, thẻ mình
	var ban := board_bans(0.12)
	for b in L.bx:
		ban.append(Rect2(b.x - b.z - 6, b.y - b.z - 6, 2 * b.z + 12, 2 * b.z + 12))
	ban.append(c0.grow(4))
	var tch := TAN.choices_in(ban, vis, L.port and W < 480)
	L.tan_sc = tch[0].sc if tch.size() else 0.3
	L.tan_sh = tch[0].sh if tch.size() else Vector2(-400, -400)
	return tch[0].a / (1.0 + 0.15 * tch[0].sc) if tch.size() else 0.0

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
	if OS.has_environment("OQ_DUMP"):
		im.save_png(OS.get_environment("OQ_DUMP"))
	vp.queue_free()
	_baking = false
	place_animals()
	queue_redraw()

# ============================================================ lưu (khóa giống localStorage của web)
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

static func _ia(a) -> Array:
	var o := []
	for x in a:
		o.append(int(x))
	return o

static func deser(d: Dictionary) -> Dictionary:
	return {"c": _ia(d.c), "q": _ia(d.q), "qw": _ia(d.qw), "dan": _ia(d.dan), "debt": _ia(d.debt), "turn": int(d.turn), "over": bool(d.over),
		"end": String(d.get("end", "")), "moves": int(d.get("moves", 0))}

func save_game() -> void:
	var s = Gm.s
	if s == null or s.over:
		return
	store_set("oaq-save-v1", {"mode": Gm.mode, "level": Gm.level, "names": Gm.names, "av": Gm.av, "s": s, "R": Gm.R, "hist": Gm.hist.slice(-20), "undoLeft": Gm.undoLeft})

func has_save() -> bool:
	return store.get("oaq-save-v1", null) is Dictionary

# ============================================================ ô & vùng chứa
static func row_of(i: int) -> int:
	if i >= 1 and i <= 5:
		return 0
	if i >= 7 and i <= 11:
		return 1
	return -1

static func cell_rect(i: int) -> Rect2:
	if i >= 1 and i <= 5:
		return Rect2(i - 1, 1, 1, 1)
	return Rect2(11 - i, 0, 1, 1)

static func cell_center(i: int) -> Vector2:
	if i == 0:
		return Vector2(-0.36, 1)
	if i == 6:
		return Vector2(5.36, 1)
	return cell_rect(i).get_center()

func label_pos(i: int) -> Vector2:
	# màn dọc: số ô quan nằm cạnh hòn quan, để hai dòng "quan non" không lòi ra ngoài đầu bàn
	if i == 0:
		return Vector2(-0.42, 0.4) if L.port else Vector2(-QW + 0.19, 1)
	if i == 6:
		return Vector2(5.42, 0.4) if L.port else Vector2(5 + QW - 0.19, 1)
	var r := cell_rect(i)
	return Vector2(r.get_center().x, 1.885 if row_of(i) == 0 else 0.115)

static func cell_at(u: float, v: float) -> int:
	if u >= 0 and u <= 5 and v >= 0 and v <= 2:
		var x := mini(4, floori(u))
		return x + 1 if v >= 1 else 11 - x
	var e := func(cx: float) -> bool: return pow((u - cx) / QW, 2) + pow(v - 1, 2) <= 1.02
	if u < 0 and e.call(0.0):
		return 0
	if u > 5 and e.call(5.0):
		return 6
	return -1

func region(home: String) -> Dictionary:
	if home[0] == "b":
		var b: Dictionary = L.bas[int(home.substr(1))]
		return {"t": "c", "x": b.x, "y": b.y, "r": b.r}
	var i := int(home.substr(1))
	if i == 0:
		return {"t": "e", "cx": 0.0, "cy": 1.0, "rx": QW - 0.07, "ry": 0.92, "side": -1.0, "lim": -QW + 0.36}
	if i == 6:
		return {"t": "e", "cx": 5.0, "cy": 1.0, "rx": QW - 0.07, "ry": 0.92, "side": 1.0, "lim": 5 + QW - 0.36}
	var r := cell_rect(i)
	var top := row_of(i) == 1
	return {"t": "r", "x0": r.position.x + 0.065, "x1": r.end.x - 0.065, "y0": 0.215 if top else 1.065, "y1": 0.935 if top else 1.785}

static func clamp_to(reg: Dictionary, p: Dictionary, rad: float) -> String:
	var hit := ""
	if reg.t == "r":
		if p.x < reg.x0 + rad:
			p.x = reg.x0 + rad; hit = "x"
		elif p.x > reg.x1 - rad:
			p.x = reg.x1 - rad; hit = "x"
		if p.y < reg.y0 + rad:
			p.y = reg.y0 + rad
			if hit == "": hit = "y"
		elif p.y > reg.y1 - rad:
			p.y = reg.y1 - rad
			if hit == "": hit = "y"
	elif reg.t == "c":
		var dx: float = p.x - reg.x
		var dy: float = p.y - reg.y
		var d := Vector2(dx, dy).length()
		var m: float = reg.r - rad
		if d > m and d > 0:
			p.x = reg.x + dx / d * m
			p.y = reg.y + dy / d * m
			hit = "c"
	else:
		var rx: float = reg.rx - rad
		var ry: float = reg.ry - rad
		var dx: float = p.x - reg.cx
		var dy: float = p.y - reg.cy
		var k := sqrt(pow(dx / rx, 2) + pow(dy / ry, 2))
		if k > 1:
			p.x = reg.cx + dx / k
			p.y = reg.cy + dy / k
			hit = "c"
		var inner: float = reg.cx + reg.side * (0.07 + rad)
		if (p.x > inner) if reg.side < 0 else (p.x < inner):
			p.x = inner; hit = "x"
		var lim: float = reg.lim - reg.side * rad
		if (p.x < lim) if reg.side < 0 else (p.x > lim):
			p.x = lim; hit = "x"
	return hit

static func rand_in(reg: Dictionary, rad: float) -> Vector2:
	for k in 40:
		var p: Vector2
		if reg.t == "r":
			p = Vector2(reg.x0 + rad + randf() * (reg.x1 - reg.x0 - 2 * rad), reg.y0 + rad + randf() * (reg.y1 - reg.y0 - 2 * rad))
		elif reg.t == "c":
			var a := randf() * TAU
			var d: float = sqrt(randf()) * (float(reg.r) - rad)
			p = Vector2(reg.x + cos(a) * d, reg.y + sin(a) * d)
		else:
			p = Vector2(reg.cx + reg.side * randf() * reg.rx, reg.cy + (randf() * 2 - 1) * reg.ry)
		var q := {"x": p.x, "y": p.y}
		clamp_to(reg, q, rad)
		if absf(q.x - p.x) + absf(q.y - p.y) < 1e-6:
			return p
	if reg.t == "r":
		return Vector2((reg.x0 + reg.x1) / 2, (reg.y0 + reg.y1) / 2)
	if reg.t == "c":
		return Vector2(reg.x, reg.y)
	return Vector2((reg.cx + reg.lim) / 2, reg.cy)

static func reg_center(home: String, reg: Dictionary) -> Vector2:
	if reg.t == "r":   # Link 11-23: đống sỏi ngay giữa vòng phấn, không lệch
		return Vector2((reg.x0 + reg.x1) / 2, (reg.y0 + reg.y1) / 2)
	if reg.t == "c":
		return Vector2(reg.x, reg.y)
	return cell_center(0 if home == "c0" else 6)

# sỏi rớt vô ô thì gom thành đống gần giữa ô, sát nhau mà không chồng lên nhau
func spot_in(home: String, rad: float) -> Vector2:
	var reg := region(home)
	var others := ST.filter(func(t): return t.home == home and t.fly == null)
	var c := reg_center(home, reg)
	var best := c
	var bs := -1e9
	# ô dân: chỉ thử chỗ trong vòng tròn giữa ô (vòng phấn rx .4), đông quá mới nới ra
	var disk := 0.3 - rad
	if reg.t == "r":
		disk = maxf(disk, sqrt(others.size() + 1.0) * rad * 1.05)
	for k in 36:
		var p := rand_in(reg, rad)
		if reg.t == "r":
			var a := randf() * TAU
			p = c + Vector2(cos(a), sin(a)) * sqrt(randf()) * disk
			var q0 := {"x": p.x, "y": p.y}
			clamp_to(reg, q0, rad)
			p = Vector2(q0.x, q0.y)
		var gap := 9.0
		for o in others:
			gap = minf(gap, Vector2(o.x - p.x, o.y - p.y).length() - o.r - rad)
		var sc := -maxf(0.0, 0.006 - gap) * 60 - (p - c).length() * (0.3 if reg.t == "c" else 1.0) + randf() * 0.05
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
			var q := {"x": nb.x, "y": nb.y}
			clamp_to(reg, q, rad)
			best = Vector2(q.x, q.y)
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
	# gà 9px của caro (Link 11-22 "lấy gà bên caro qua"): 1 ảnh nhìn từ trên, xoay theo hướng đi; chỉ bóng sát đất
	var D := ln / span
	A.on_ground(self, K, name, Rect2i(), Vector2(x, y) + off, D, D, rot, 0.0)

# ============================================================ sỏi (hình + vật lý)
func mk_stone(kind: String, home: String, p: Vector2, variant := -1) -> Dictionary:
	sid += 1
	return {"id": sid, "kind": kind, "home": home, "x": p.x, "y": p.y, "z": 0.0, "vx": 0.0, "vy": 0.0, "vz": 0.0,
		"r": QR if kind == "q" else DR * (0.9 + randf() * 0.2), "v": variant if variant >= 0 else randi() % A.PEB_N,
		"fly": null, "rest": true, "land": clock + randf(), "still": 0.0, "hp": null}

func rebuild(s: Dictionary) -> void:
	ST = []
	hand.show = false
	var put := func(home: String, kind: String, variant := -1) -> Dictionary:
		var st := mk_stone(kind, home, Vector2.ZERO, variant)
		var p := spot_in(home, st.r)
		st.x = p.x
		st.y = p.y
		ST.append(st)
		return st
	for k in [0, 1]:
		if int(s.q[k]):
			var st: Dictionary = put.call("c" + str(6 if k else 0), "q", k)
			var c := cell_center(6 if k else 0)
			st.x = c.x
			st.y = c.y
	for i in 12:
		for n in int(s.c[i]):
			put.call("c" + str(i), "d")
	for p in [0, 1]:
		for k in [0, 1]:
			if int(s.qw[k]) == p:
				put.call("b" + str(p), "q", k)
		for n in int(s.dan[p]):
			put.call("b" + str(p), "d")
	for k in 30:
		physics(1.0 / 60, true)
	for st in ST:
		st.vx = 0.0
		st.vy = 0.0
		st.vz = 0.0
		st.rest = true

func in_home(h: String) -> Array:
	return ST.filter(func(t): return t.home == h and t.fly == null)

func fly(st: Dictionary, tx: float, ty: float, tz: float, dur_: float, arc: float, on_land, to: String, delay := 0.0) -> void:
	st.fly = {"sx": st.x, "sy": st.y, "sz": st.z, "tx": tx, "ty": ty, "tz": tz, "t0": clock + delay, "dur": maxf(0.001, dur_), "arc": arc, "cb": on_land, "to": to}
	st.rest = false

func _land_now(st: Dictionary) -> void:
	var f: Dictionary = st.fly
	st.fly = null
	st.x = f.tx
	st.y = f.ty
	st.z = f.tz
	if f.cb != null:
		(f.cb as Callable).call(st, 0.0, 0.0)

func finish_all_flights() -> void:
	for st in ST.duplicate():
		if st.fly != null:
			_land_now(st)

# những viên đang bay tới `to` cho đáp liền (tua nhanh mà hình vẫn khớp)
func finish_flights(to: String) -> void:
	for st in ST.duplicate():
		if st.fly != null and st.fly.to == to:
			_land_now(st)

func physics(dt: float, settle := false) -> void:
	for st in ST:
		if st.fly != null:
			var f: Dictionary = st.fly
			if clock < f.t0:
				continue
			var k := minf(1.0, (clock - f.t0) / f.dur)
			st.x = f.sx + (f.tx - f.sx) * k
			st.y = f.sy + (f.ty - f.sy) * k
			st.z = f.sz + (f.tz - f.sz) * k + f.arc * 4 * k * (1 - k)
			if k >= 1:
				st.fly = null
				if f.cb != null:
					(f.cb as Callable).call(st, (f.tx - f.sx) / f.dur, (f.ty - f.sy) / f.dur)
			continue
		if st.home == "h":
			var t: Array = st.hp if st.hp != null else [0.0, 0.0, 0.0]
			var a := minf(1.0, dt * 30)
			st.x += (hand.x + t[0] - st.x) * a
			st.y += (hand.y + t[1] - st.y) * a
			st.z += (hand.z + t[2] - st.z) * a
			continue
		if st.rest:
			continue
		st.vz -= 7.5 * dt
		st.z += st.vz * dt
		if st.z <= 0:
			st.z = 0.0
			if st.vz < -0.45:
				var imp: float = -st.vz
				st.vz = imp * 0.32
				if not settle and imp > 0.8:
					snd.clack(imp / 3.5, near_stone(st))
			else:
				st.vz = 0.0
		st.x += st.vx * dt
		st.y += st.vy * dt
		if st.z == 0:
			var fr := exp(-7 * dt)
			st.vx *= fr
			st.vy *= fr
	# va chạm giữa các viên, trong từng ô / rổ
	var groups := {}
	for st in ST:
		if st.fly == null and st.home != "h" and st.home != "air":
			if not groups.has(st.home):
				groups[st.home] = []
			groups[st.home].append(st)
	for h in groups:
		var a: Array = groups[h]
		var reg := region(h)
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
					var m: float = (p.r + q.r) * 0.92
					if d >= m:
						continue
					var ov := (m - d) * 0.5
					var nx := dx / d
					var ny := dy / d
					var mp := 0.1 if p.kind == "q" else 1.0
					var mq := 0.1 if q.kind == "q" else 1.0
					var ms := mp + mq
					p.x -= nx * ov * mp / ms * 2 * 0.6; p.y -= ny * ov * mp / ms * 2 * 0.6
					q.x += nx * ov * mq / ms * 2 * 0.6; q.y += ny * ov * mq / ms * 2 * 0.6
					var rv: float = (q.vx - p.vx) * nx + (q.vy - p.vy) * ny
					if rv < 0:
						var j2 := -rv * 0.6
						p.vx -= nx * j2 * mp / ms; p.vy -= ny * j2 * mp / ms; q.vx += nx * j2 * mq / ms; q.vy += ny * j2 * mq / ms
					if p.rest and ov > 0.004:
						wake(p)
					if q.rest and ov > 0.004:
						wake(q)
		for st in a:
			var hit := clamp_to(reg, st, st.r * 0.92)
			if hit == "x":
				st.vx *= -0.3
			elif hit == "y":
				st.vy *= -0.3
			elif hit == "c":
				st.vx *= -0.3
				st.vy *= -0.3
			if not st.rest and st.z == 0 and st.vz == 0 and Vector2(st.vx, st.vy).length() < 0.03:
				st.still += dt
				if st.still > 0.12:
					st.rest = true
					st.vx = 0.0
					st.vy = 0.0
					st.still = 0.0
			else:
				st.still = 0.0

func wake(st: Dictionary) -> void:
	st.rest = false
	st.still = 0.0

func near_stone(st: Dictionary) -> bool:
	for o in ST:
		if o != st and o.home == st.home and Vector2(o.x - st.x, o.y - st.y).length() < st.r + o.r + 0.02:
			return true
	return false

func land_in(home: String) -> Callable:
	return func(st: Dictionary, vx: float, vy: float) -> void:
		st.home = home
		st.z = 0.0
		st.vz = 0.55 + randf() * 0.25
		st.vx = vx * 0.1 + (randf() - 0.5) * 0.35
		st.vy = vy * 0.1 + (randf() - 0.5) * 0.35
		st.rest = false
		st.land = clock
		snd.clack(0.9, near_stone(st))
		dust(st.x, st.y, 2 if home[0] == "b" else 5)
		for o in ST:
			if o != st and o.home == home and Vector2(o.x - st.x, o.y - st.y).length() < st.r + o.r + 0.04:
				wake(o)
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
			elif Gm.vis != null:
				rebuild(Gm.vis)
			hud.update_cards()
	clock += dt
	for k in 2:
		physics(dt / 2)
	var hk := minf(1.0, dt * 14 * Gm.ff * float(S.speed))
	hand.x += (hand.tx - hand.x) * hk
	hand.y += (hand.ty - hand.y) * hk
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
	if Gm.markA > 0:
		Gm.markA -= dt * 0.5
	queue_redraw()
	_shade_step(dt)

func human_live() -> bool:
	return Gm.s != null and not Gm.busy and not Gm.s.over and is_human(Gm.s.turn) and Gm.started

func is_human(p: int) -> bool:
	return Gm.mode == "pvp" or p == 0

func score_of(v: Dictionary, p: int) -> int:
	return E.score(v, p, Gm.R if Gm.R.has("qv") else rules_now())

func cell_playable(i: int) -> bool:
	return Gm.s != null and not Gm.busy and not Gm.s.over and is_human(Gm.s.turn) and i >= 0 and row_of(i) == Gm.s.turn and int(Gm.s.c[i]) > 0

# mũi tên ở mép ô đang chọn (phía người chơi), hai bên số phấn
func arrow_chips() -> Array:
	var i: int = Gm.sel
	var r := cell_rect(i)
	var row := row_of(i)
	var ey := 2.0 if row == 0 else 0.0
	var out := 1.0 if row == 0 else -1.0
	var res := []
	for e in [[r.position.x + 0.2, -1.0], [r.end.x - 0.2, 1.0]]:
		var X := map(e[0], ey)
		var X2 := map(e[0] + e[1], ey)
		var Xo := map(e[0], ey + out)
		var u := (X2 - X).normalized()
		var o := (Xo - X).normalized()
		# hàng dưới: +x là ô +1; hàng trên: +x là ô -1
		var dir := int(e[1]) if row == 0 else -int(e[1])
		res.append({"X": X.x, "Y": X.y, "ux": u.x, "uy": u.y, "ox": o.x, "oy": o.y, "dir": dir, "r": maxf(16.0, minf(27.0, L.s * 0.14))})
	return res

# hướng này ăn được bao nhiêu (ghi bên mũi tên khi bật gợi ý)
func hint_for(i: int, dir: int) -> Dictionary:
	var key := "%d:%d:%d" % [i, dir, int(Gm.s.moves)]
	if Gm.hintKey == key:
		return Gm.hintVal
	var c := E.clone(Gm.s)
	var p: int = c.turn
	var ev := []
	var b0 := E.score(c, p, Gm.R)
	E.move(c, i * 2 + (1 if dir > 0 else 0), Gm.R, ev)
	var gain := E.score(c, p, Gm.R) - b0
	var quan := false
	var non := false
	for e in ev:
		if e.t == "cap" and e.q:
			quan = true
		if e.t == "stop" and e.why == "non":
			non = true
	var v: Dictionary
	if quan:
		v = {"t": "ăn quan +%d" % gain, "c": Color("#ffd84a"), "a": 1.0}
	elif gain > 0:
		v = {"t": "ăn +%d" % gain, "c": Color("#ffe680"), "a": 1.0}
	elif non:
		v = {"t": "quan non", "c": Color("#c8f0a0"), "a": 0.95}
	else:
		v = {"t": "hổng ăn", "c": Color("#fffaf0"), "a": 0.6}
	Gm.hintKey = key
	Gm.hintVal = v
	return v

# ------------------------------------------------------------ vẽ
func _T(xf := Transform2D.IDENTITY) -> void:
	draw_set_transform_matrix(Transform2D(0.0, Vector2(K, K), 0.0, Vector2.ZERO) * xf)

func _LG(sh := Vector2.ZERO) -> void:   # tọa độ bàn
	_T(lg(sh))

func chalk_loop(c: Vector2, rx: float, ry: float, seed: float, col: Color, lw: float) -> void:
	# vòng phấn vẽ tay méo méo, cùng một kiểu méo mỗi khung cho một ô
	for ps in 2:
		var pts := PackedVector2Array()
		for k in 49:
			var t := k / 48.0 * 6.6 + seed + ps * 0.4
			var w := 1 + 0.035 * sin(t * 3 + seed * 7 + ps) + 0.02 * sin(t * 7 + seed)
			pts.append(c + Vector2(cos(t) * rx * w, sin(t) * ry * w))
		draw_polyline(pts, Color(col, col.a * (0.55 if ps else 1.0)), lw, true)

# chữ phấn trên đất: rãnh mờ bên dưới, phấn tô hai lần lệch nhau cho mép bụi
func chalk_text(at: Vector2, txt: String, fs: float, col: Color, alpha := 1.0) -> void:
	var f := A.font(700)
	var n := roundi(fs * K)
	var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, n).x / K
	var asc := f.get_ascent(n) / K
	var dsc := f.get_descent(n) / K
	var p := Vector2(at.x - w / 2, at.y + (asc - dsc) / 2)
	draw_set_transform_matrix(Transform2D.IDENTITY)   # chữ vẽ thẳng theo điểm ảnh (toạ độ đã nhân K)
	draw_string(f, (p + Vector2(fs * 0.04, fs * 0.06)) * K, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, n, Color8(60, 38, 18, int(77 * alpha)))
	draw_string(f, (p + Vector2(-fs * 0.025, fs * 0.02)) * K, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, n, Color(col, 0.45 * alpha))
	draw_string(f, (p + Vector2(fs * 0.02, -fs * 0.02)) * K, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, n, Color(col, 0.45 * alpha))
	draw_string(f, p * K, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, n, Color(col, alpha))

func chalk_size(txt: String, fs: float) -> Vector2:
	var f := A.font(700)
	var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(fs * K)).x / K
	return Vector2(ceilf(w + fs * 0.6), ceilf(fs * 1.4))

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

func _pill(at: Vector2, txt: String, fg: Color, bgc: Color, fs: float, alpha: float) -> void:
	var f := A.font(800)
	var n := roundi(fs * K)
	var tw_ := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, n).x / K
	var w := maxf(fs * 1.5, tw_ + fs * 0.9)
	var h := fs * 1.3
	draw_set_transform_matrix(Transform2D.IDENTITY)   # chữ vẽ thẳng theo điểm ảnh (toạ độ đã nhân K)
	A.box(self, Rect2((at.x - w / 2 + 1) * K, (at.y - h / 2 + 2) * K, w * K, h * K), Color(50 / 255.0, 28 / 255.0, 10 / 255.0, 0.28 * alpha), h / 2, K)
	A.box(self, Rect2((at.x - w / 2) * K, (at.y - h / 2) * K, w * K, h * K), Color(bgc, alpha), h / 2, K)
	var asc := f.get_ascent(n) / K
	var dsc := f.get_descent(n) / K
	draw_string(f, Vector2(at.x - tw_ / 2, at.y + fs * 0.06 + (asc - dsc) / 2) * K, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, n, Color(fg, alpha))

func _draw_count(i: int) -> void:
	var v: Dictionary = Gm.vis
	var X := map(label_pos(i).x, label_pos(i).y)
	var s: float = L.s
	var fs := maxf(15.0, minf(30.0, s * 0.16))
	var n: int = int(v.c[i])
	if i == 0 or i == 6:
		# ô quan ghi luôn giá ăn ô đó (dân + quan), còn quan non thì ghi thêm
		var k := 0 if i == 0 else 1
		var has := int(v.q[k]) != 0
		var non: bool = has and bool(Gm.R.get("non", true)) and n < 5
		var val: int = n + (int(Gm.R.get("qv", 10)) if has else 0)
		chalk_text(X - Vector2(0, fs * 0.42 if non else 0.0), str(val), fs, Color("#fffaf0"), 0.95 if val else 0.45)
		if non:
			chalk_text(X + Vector2(0, fs * 0.5), "quan", fs * 0.56, Color("#d9f2b4"), 0.95)
			chalk_text(X + Vector2(0, fs * 1.05), "non", fs * 0.56, Color("#d9f2b4"), 0.95)
		return
	chalk_text(X, str(n), fs, Color("#fffaf0"), 1.0 if n else 0.55)

func _chalk_stroke(pts: Array, col: Color, lw: float, seed: float) -> void:
	for ps in 2:
		var pp := PackedVector2Array()
		for k in pts.size():
			var j := sin(seed + k * 2.3) * lw * 0.35 if ps else 0.0
			var p: Vector2 = pts[k]
			pp.append(Vector2(p.x + j, p.y + (j if k == 0 else -j)))
		draw_polyline(pp, Color(col, col.a * (0.5 if ps else 0.95)), lw, true)
		draw_circle(pp[0], lw / 2, Color(col, col.a * (0.5 if ps else 0.95)), true, -1.0, true)
		draw_circle(pp[pp.size() - 1], lw / 2, Color(col, col.a * (0.5 if ps else 0.95)), true, -1.0, true)

# mũi tên chọn hướng kẻ phấn trên đất như các ô: vệt phấn chà, mũi tên vẽ tay, chữ gợi ý kế bên
func _draw_arrows() -> void:
	_T()
	var bob := sin(clock * 6) * 1.6
	for a in arrow_chips():
		var X: float = a.X + a.ux * bob
		var Y: float = a.Y + a.uy * bob
		var r: float = a.r
		var hov: bool = Gm.hoverArrow == a.dir
		var sd := 1.3 if a.dir > 0 else 4.1
		draw_texture_rect_region(A.atlas, Rect2(X - r * 1.15, Y - r * 1.15, r * 2.3, r * 2.3), A.R_GLOW, Color(1.0, 0.98, 0.91, 0.42 if hov else 0.26))
		chalk_loop(Vector2(X, Y), r * 0.98, r * 0.98, sd, Color("#ffe680") if hov else Color8(255, 250, 236, 191), maxf(1.6, r * 0.08))
		var u := Vector2(a.ux, a.uy)
		var pv := Vector2(-a.uy, a.ux)
		var k := r * 0.58
		var col := Color("#ffe680") if hov else Color("#fffaf0")
		var lw := maxf(3.0, r * 0.2)
		var P := func(f: float, g: float) -> Vector2: return Vector2(X, Y) + u * k * f + pv * k * g
		_chalk_stroke([P.call(-0.85, 0.05), P.call(0.8, 0.0)], col, lw, sd)
		_chalk_stroke([P.call(0.1, 0.62), P.call(0.85, 0.0), P.call(0.1, -0.62)], col, lw, sd + 1)
		if int(S.hint):
			var h := hint_for(Gm.sel, a.dir)
			var fs := maxf(14.0, minf(21.0, L.s * 0.11))
			var sz := chalk_size(h.t, roundf(fs))
			var off: float = r * 1.02 + absf(a.ox) * sz.x * 0.42 + absf(a.oy) * sz.y * 0.4
			var hx: float = a.X + a.ox * off + a.ux * (0.0 if L.port else r * 0.3)
			var hy: float = a.Y + a.oy * off
			chalk_text(Vector2(hx, hy), h.t, roundf(fs), h.c, h.a)
			_T()

static func _st_less(a: Dictionary, b: Dictionary) -> bool:
	if a.z > 0.05 or b.z > 0.05:
		if a.z != b.z:
			return a.z < b.z
	var qa := 0 if a.kind == "q" else 1
	var qb := 0 if b.kind == "q" else 1
	if qa != qb:
		return qa < qb
	return a.land < b.land

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
	# ô đi được: vệt nắng mờ trong ô + vòng phấn
	var live := human_live()
	_LG(sh)
	if live:
		var pulse := 0.5 + 0.5 * sin(clock * 3.2)
		for mv in E.legal(Gm.s, Gm.s.turn):
			if mv & 1:
				continue
			var i: int = mv >> 1
			var c := cell_center(i)
			var sel: bool = Gm.sel == i
			var hov: bool = Gm.hover == i
			var a := 0.3 if sel else (0.24 if hov else 0.1 + 0.1 * pulse)
			draw_texture_rect_region(A.atlas, Rect2(c - Vector2(0.5, 0.5), Vector2(1, 1)), A.R_GLOW, Color(1.0, 0.965, 0.84, a))
			if not sel:
				chalk_loop(c, 0.4, 0.38, i * 1.7, Color8(255, 248, 226, int((0.28 + 0.3 * pulse) * 255)), 0.018)
			else:
				chalk_loop(c, 0.42, 0.4, i, Color8(255, 226, 120, 242), 0.03)
	# ô vừa bốc: vòng phấn mờ
	if Gm.markCell >= 0 and Gm.markA > 0 and Gm.markCell != 0 and Gm.markCell != 6:
		var c := cell_center(Gm.markCell)
		chalk_loop(c, 0.36, 0.34, Gm.markCell * 2.3, Color8(255, 214, 130, int(0.5 * minf(1.0, Gm.markA) * 255)), 0.016)
	# sỏi: bóng trước rồi tới thân
	_T(Transform2D(0.0, Vector2.ONE, 0.0, sh))
	var lst := ST.duplicate()
	lst.sort_custom(_st_less)
	for st in lst:
		if st.home == "h":
			continue
		var P := map(st.x, st.y)
		var R: float = st.r * s * (1 + st.z * 0.28)
		var off: float = (0.05 + st.z * 0.42) * s
		var ss: float = R * (2.3 + st.z * 0.9)
		var al := maxf(0.25, 1 - st.z * 0.55) * (1.0 if st.kind == "q" else 0.9)
		if st.z < 0.03:
			# nằm yên (Link 11-23 "sỏi lơ lửng"): bóng theo đúng hình viên, sát đen + đổ ngắn xuống dưới phải (tools/oq/peb_bong.py)
			var Dg: float = st.r * s * 2 / 0.8
			var q: bool = st.kind == "q"
			var sht := A.img(("peb/t%d" % (int(st.v) % 2)) if q else ("peb/s%d" % (int(st.v) % A.PEB_N)))
			draw_texture_rect(sht, Rect2(P.x - Dg * 0.75, P.y - Dg * 0.75, Dg * 1.5, Dg * 1.5), false)
			continue
		var a2 := (al * 0.45 if st.z > 0.25 else al) * 0.7
		draw_texture_rect_region(A.atlas, Rect2(P.x + off * 0.55 - ss / 2, P.y + off * 0.75 - ss / 2 + R * 0.12, ss, ss * 0.92), A.R_SOFT, Color(1, 1, 1, a2))
	var qt: Texture2D = null
	var pb: Texture2D = null
	var up := func(st: Dictionary) -> bool: return st.home == "h" or (st.fly != null and st.z > 0.05)
	for st in lst:
		if not up.call(st):
			_draw_st(st, qt, pb)
	var held := ST.filter(func(t): return t.home == "h")
	if hand.vis > 0.02 and held.size():
		# không vẽ người, chỉ có bóng cánh tay từ phía người rải thò vô tới nắm tay: sỏi trông như đang cầm, không phải bay
		var P := map(hand.x, hand.y)
		var off: float = (0.05 + hand.z * 0.42) * s
		var ss := s * (0.36 + sqrt(held.size()) * 0.07)
		_arm_shadow(P.x + off * 0.55, P.y + off * 0.75, hand.p, hand.vis, sh)
		draw_texture_rect_region(A.atlas, Rect2(P.x + off * 0.55 - ss / 2, P.y + off * 0.75 - ss * 0.42, ss, ss * 0.84), A.R_SOFT, Color(1, 1, 1, 0.5 * hand.vis))
		var dl := s * 0.05
		var gap := s * 0.04
		var rr := s * 0.3
		var circ := TAU * rr
		var ph := fposmod(clock * s * 0.2, dl + gap)
		var t := -ph
		while t < circ:
			var a0 := maxf(t, 0.0) / rr
			var a1 := minf(t + dl, circ) / rr
			if a1 > a0:
				draw_arc(P, rr, a0, a1, maxi(3, int((a1 - a0) * 12)), Color(Color("#ffd86a"), 0.7 * hand.vis), maxf(2.0, s * 0.018), true)
			t += dl + gap
	for st in lst:
		if up.call(st):
			_draw_st(st, qt, pb)
	# số đếm phấn mỗi ô
	if Gm.vis != null:
		for i in 12:
			_draw_count(i)
	# số sỏi trong tay
	var inh := held.size()
	if hand.vis > 0.05 and inh > 0:
		var P := map(hand.x, hand.y)
		_pill(Vector2(P.x, P.y - hand.z * s * 0.34 - s * 0.24 - sqrt(inh) * s * 0.03), str(inh), Color("#3a2412"), Color("#fff6dc"), maxf(13.0, s * 0.12), hand.vis)
	_draw_fx(s)
	if live and Gm.sel >= 0:
		_draw_arrows()
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

func _draw_st(st: Dictionary, qt: Texture2D, pb: Texture2D) -> void:
	var P := map(st.x, st.y)
	var Y: float = P.y - st.z * L.s * 0.34
	var D: float = st.r * L.s * 2 / 0.8 * (1 + st.z * 0.28)
	var dst := Rect2(P.x - D / 2, Y - D / 2, D, D)
	if st.kind == "q":
		draw_texture_rect(A.img("peb/q%d" % (int(st.v) % 2)), dst, false)
	else:
		draw_texture_rect(A.img("peb/p%d" % (int(st.v) % A.PEB_N)), dst, false)
	if st.z < 0.03:
		# mép dưới phải tối lại chỗ khuất sát đất: viên ngồi xuống đất, không nổi
		draw_texture_rect(A.img(("peb/b%d" % (int(st.v) % 2)) if st.kind == "q" else ("peb/a%d" % (int(st.v) % A.PEB_N))), dst, false)

# bóng mềm của cẳng tay + nắm tay trên đất, thò vô từ mép màn phía người đang rải
func _arm_shadow(fx: float, fy: float, p: int, vis: float, sh: Vector2) -> void:
	var s: float = L.s
	var o: Vector2
	if L.port:
		o = Vector2(-s * 0.6 if p == 0 else L.W + s * 0.6, fy + s * 1.4)
	else:
		o = Vector2(fx + s * (0.9 if p == 0 else -0.9), L.H + s * 0.6 if p == 0 else -s * 0.6)
	var d := Vector2(fx, fy) - o
	var ln := d.length()
	var wdt := s * 0.44
	_T(Transform2D(d.angle(), o + sh))
	draw_texture_rect(A.arm, Rect2(0, -wdt / 2, ln + wdt * 0.12, wdt), false, Color(1, 1, 1, 0.4 * minf(1.0, vis)))
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
			var rr := s * (0.15 + k * 0.4)
			draw_polyline(_ell_closed(map(f.x, f.y), rr, rr * 0.9), Color(col, 0.8 * (1 - k)), maxf(2.0, s * 0.025), true)
		elif f.t == "spark":
			_star(map(f.x, f.y) - Vector2(0, k * s * 0.3), f.r * s * (1 - k), Color8(255, 224, 110, int((1 - k) * 255)))
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

static func _ell_closed(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 41:
		var a := TAU * k / 40.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts

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
uniform sampler2D fr : filter_linear_mipmap, repeat_disable;
float h(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float n(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(h(i),h(i+vec2(1,0)),f.x),mix(h(i+vec2(0,1)),h(i+vec2(1,1)),f.x),f.y);}
float fbm(vec2 p){float v=0.,a=.5;for(int i=0;i<5;i++){v+=a*n(p);p=p*2.07+vec2(1.7,9.2);a*=.5;}return v;}
// Link 11-23 "bóng lá dừa từng đốm đen": làm mờ bằng mipmap (1 lần lấy mẫu, mịn liền vệt), không chồng nhiều bản lệch
float frond(vec2 q,float lod){
  if(q.x<0.||q.y<0.||q.x>1.||q.y>1.)return 0.;
  float e=smoothstep(0.,.04,q.x)*smoothstep(0.,.04,q.y)*smoothstep(1.,.96,q.x)*smoothstep(1.,.96,q.y);
  return textureLod(fr,vec2(q.x,1.0-q.y),lod).r*e;}
void fragment(){
  vec2 fc=vec2(UV.x,1.0-UV.y)*res;
  float m=min(res.x,res.y);vec2 p=fc/m;vec2 uv=fc/res;
  vec2 corner=res/m;vec2 d=p-corner;float dist=length(d);
  float a=(.018*sin(t*.55)+.007*sin(t*1.63+1.))*smoothstep(0.,1.,dist);
  d=mat2(vec2(cos(a),sin(a)),vec2(-sin(a),cos(a)))*d;
  d+=vec2(sin(t*1.9+p.y*9.),cos(t*1.7+p.x*8.))*.004*dist;
  vec2 q=vec2(1.)+d/.8;   // Link 11-23: bóng tàu lá góc phải nhỏ lại, mờ + nhạt
  float fsh=frond(q,2.6+1.6*dist)*.5;
  vec2 w=vec2(sin(t*.45+p.y*3.)+sin(t*.23+p.x*1.7),cos(t*.37+p.x*2.6)+sin(t*.19+p.y*2.))*.006;
  float big=fbm((p+w)*2.4+vec2(3.1,1.3)),fine=fbm((p+w*1.8)*8.+vec2(7.,2.)),vf=fbm((p+w*2.2)*22.+vec2(4.,8.));
  float dd=length((p-tree)*vec2(1.,1.12));
  float th=mix(.36,.95,smoothstep(.05,.9,dd));
  float v=big*.5+fine*.3+vf*.2;
  // Link 11-23 "đen loang lổ": vệt bóng tán chỉ quanh gốc cây, mép mềm, nhạt; ngoài sân không còn mảng loang
  float cover=smoothstep(th-.1,th+.1,v)*.45*(1.-smoothstep(.25,.7,dd));
  float sh=clamp(max(fsh,cover),0.,1.)*str;
  vec3 lit=vec3(1.,.99,.955);vec3 shade=vec3(.78,.79,.83);
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
	_shade_mat.set_shader_parameter("str", 0.6)
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

func hand_to(i: int, z = null) -> void:
	var c := cell_center(i)
	hand.tx = c.x
	hand.ty = c.y
	hand.cell = i
	if z != null:
		hand.z = float(z)

func arrange_hand() -> void:
	var k := 0
	for t in ST:
		if t.home == "h":
			var a := k * 2.4
			var rr := 0.03 * sqrt(k)
			t.hp = [cos(a) * rr, sin(a) * rr * 0.8, 0.05 * floori(k / 4.0) + 0.012 * k]
			k += 1

func do_pick(i: int) -> void:
	hand_to(i, 0.95)
	hand.show = true
	await wait(170)
	finish_flights("c" + str(i))
	var src := in_home("c" + str(i)).filter(func(t): return t.kind == "d")
	var c := cell_center(i)
	for k in src.size():
		fly(src[k], c.x, c.y, hand.z, dur(0.2), 0.15, func(st, _vx, _vy): st.home = "h"; arrange_hand(), "h", dur(k * 0.018))
	snd.rattle(src.size())
	Gm.vis.c[i] = 0
	Gm.markCell = i
	Gm.markA = 1.0
	await wait(230 + mini(src.size(), 12) * 14)
	# chắc chắn đã nằm hết trong tay
	finish_flights("h")
	arrange_hand()

func do_drop(i: int) -> void:
	hand_to(i)
	await wait(110)
	finish_flights("h")
	var hs := ST.filter(func(t): return t.home == "h")
	if hs.size():
		var t: Dictionary = hs[hs.size() - 1]
		t.home = "air"
		var p := spot_in("c" + str(i), t.r)
		fly(t, p.x, p.y, 0.0, dur(0.17), 0.22, land_in("c" + str(i)), "c" + str(i))
	Gm.vis.c[i] = int(Gm.vis.c[i]) + 1
	await wait(120)

func do_tap(i: int) -> void:
	hand_to(i, 0.7)
	await wait(150)
	var c := cell_center(i)
	ring(c.x, c.y)
	dust(c.x, c.y, 6)
	snd.tap()
	await wait(230)

func do_cap(e: Dictionary) -> void:
	hand_to(e.i, 0.7)
	await wait(130)
	finish_flights("c" + str(e.i))
	var src := in_home("c" + str(e.i))
	var c := cell_center(e.i)
	var p: int = e.p
	for k in src.size():
		var t: Dictionary = src[k]
		t.home = "air"
		var q := spot_in("b" + str(p), t.r)
		fly(t, q.x, q.y, 0.0, dur(0.42 + randf() * 0.1), 0.9 if t.kind == "q" else 0.55 + randf() * 0.3, land_in("b" + str(p)), "b" + str(p), dur(k * 0.032))
	Gm.vis.c[e.i] = 0
	Gm.vis.dan[p] = int(Gm.vis.dan[p]) + int(e.n)
	if e.q:
		Gm.vis.q[e.k] = 0
		Gm.vis.qw[e.k] = p
	if e.q:
		shake = 9.0
		snd.quan()
		sparks(c.x, c.y, 26)
		float_txt(c.x, c.y, "Ăn quan!", Color("#ffe27a"), 1.35)
		hud.toast("Ăn quan!", "big")
	else:
		snd.eat(int(e.n))
		sparks(c.x, c.y, 8 + int(e.n))
		float_txt(c.x, c.y, "+" + str(e.n), Color("#fff3c4"), 1.25 if int(e.n) >= 8 else 1.0)
	if int(e.chain) >= 2:
		var ch: int = e.chain
		get_tree().create_timer(0.12).timeout.connect(func(): if is_instance_valid(hud): hud.toast("Ăn kép!" if ch == 2 else "Ăn liền %d ô!" % ch, ""))
	hud.update_cards()
	await wait(420 + src.size() * 28)

func do_stop(e: Dictionary, ate: int) -> void:
	hand.show = false
	var msg: String = {"quan": "Đụng ô quan, ngừng", "non": "Quan non, chưa ăn được đâu!", "empty2": "Hai ô trống, hết phiên", "loop": ""}.get(e.why, "")
	if e.why == "non" and e.has("i"):
		var c := cell_center(e.i)
		if L.port:
			hud.toast("Quan non, chưa ăn được đâu!", "soft")
		else:
			float_txt(0.9 if c.x < 2.5 else 4.1, -0.32, "Quan non, chưa ăn được!", Color("#e8ffd2"), 0.62)
		snd.non()
	elif msg != "" and not ate:
		var c := cell_center(e.i) if e.has("i") else Vector2(2.5, 1)
		float_txt(c.x, c.y, msg, Color("#fff8e6"), 0.62)
		snd.stop()
	await wait(380)

func do_vay(e: Dictionary) -> void:
	var p: int = e.p
	var from: int = e.from
	var who: String = Gm.names[p]
	hud.toast(("%s hết quân, lấy 5 dân rải lại" % who) if from == p else ("%s hết quân, mượn %s 5 dân" % [who, Gm.names[from]]), "soft")
	await wait(500)
	var pool := in_home("b" + str(from)).filter(func(t): return t.kind == "d")
	pool = pool.slice(maxi(0, pool.size() - 5))
	var b := E.row_start(p)
	for k in pool.size():
		var t: Dictionary = pool[k]
		t.home = "air"
		var q := spot_in("c" + str(b + k), t.r)
		fly(t, q.x, q.y, 0.0, dur(0.45), 0.6, land_in("c" + str(b + k)), "c" + str(b + k), dur(k * 0.11))
	Gm.vis.dan[from] = int(Gm.vis.dan[from]) - 5
	if from != p:
		Gm.vis.debt[p] = int(Gm.vis.debt[p]) + 5
	for k in 5:
		Gm.vis.c[b + k] = 1
	hud.update_cards()
	await wait(1000)

func do_end(e: Dictionary) -> void:
	hud.toast("Hết quan, tàn dân, thu quân kéo về!" if e.why == "hetquan" else ("Hết quân rải rồi, ngừng ván" if e.why == "hetdan" else "Ngừng ván"), "soft")
	await wait(900)
	for p in [0, 1]:
		var b := E.row_start(p)
		for i in range(b, b + 5):
			var lst := in_home("c" + str(i))
			for k in lst.size():
				var t: Dictionary = lst[k]
				t.home = "air"
				var q := spot_in("b" + str(p), t.r)
				fly(t, q.x, q.y, 0.0, dur(0.5), 0.6, land_in("b" + str(p)), "b" + str(p), dur(k * 0.04 + (i - b) * 0.05))
			Gm.vis.c[i] = 0
		Gm.vis.dan[p] = int(Gm.vis.dan[p]) + int(e.got[p])
	# ván dừng vì không ai rải được: phần còn trong ô quan về người còn đi được
	for qc in e.get("qcells", []):
		var tk: int = e.taker
		var lst := in_home("c" + str(qc.i))
		for k in lst.size():
			var t: Dictionary = lst[k]
			t.home = "air"
			var q := spot_in("b" + str(tk), t.r)
			fly(t, q.x, q.y, 0.0, dur(0.6), 0.8, land_in("b" + str(tk)), "b" + str(tk), dur(0.3 + k * 0.05))
		Gm.vis.c[qc.i] = 0
		Gm.vis.dan[tk] = int(Gm.vis.dan[tk]) + int(qc.n)
		if qc.q:
			Gm.vis.q[qc.k] = 0
			Gm.vis.qw[qc.k] = tk
	hud.update_cards()
	await wait(1100)

func play_events(evs: Array) -> void:
	var ate := 0
	for e in evs:
		match e.t:
			"pick": await do_pick(e.i)
			"drop": await do_drop(e.i)
			"tap": await do_tap(e.i)
			"cap":
				ate += 1
				await do_cap(e)
			"stop": await do_stop(e, ate)
			"vay": await do_vay(e)
			"end": await do_end(e)
	hand.show = false
	await wait(200)
	finish_all_flights()

func visuals_match(s: Dictionary) -> bool:
	for i in 12:
		var h := "c" + str(i)
		var n := ST.filter(func(t): return t.home == h and t.kind == "d").size()
		if n != int(s.c[i]):
			return false
	for p in [0, 1]:
		var h := "b" + str(p)
		var n := ST.filter(func(t): return t.home == h and t.kind == "d").size()
		if n != int(s.dan[p]):
			return false
	for t in ST:
		if t.home == "h" or t.home == "air":
			return false
	return true

# ============================================================ ván chơi
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
	Gm.markA = 0.0
	Gm.vis = E.clone(Gm.s)
	rebuild(Gm.s)
	hud.setup_cards()
	hud.close_all()
	hud.toast(((("Bạn" if Gm.mode == "ai" else Gm.names[0])) if first == 0 else Gm.names[1]) + " đi trước nghen!", "soft")
	ai_token += 1
	var tok := ai_token
	await get_tree().create_timer(0.7).timeout
	if tok == ai_token:
		next_turn()

func next_turn() -> void:
	if Gm.s == null:
		return
	var ev := []
	var s2 := E.clone(Gm.s)
	var ok := E.prep(s2, Gm.R, ev)
	if ev.size():
		Gm.busy = true
		hud.update_cards()
		hud.show_ff(true)
		await play_events(ev)
	Gm.s = s2
	Gm.vis = E.clone(s2)
	if Gm.needRebuild or not visuals_match(Gm.s):
		Gm.needRebuild = false
		rebuild(Gm.s)
	Gm.busy = false
	hud.show_ff(false)
	save_game()
	hud.update_cards()
	if not ok:
		end_game()
		return
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
	if mv < 0 or not E.legal(Gm.s, Gm.s.turn).has(mv):
		mv = E.think(s0, Gm.R, Gm.level)
	var delay := maxf(0.0, 650 - (Time.get_ticks_msec() - t0))
	await get_tree().create_timer(delay / 1000.0).timeout
	if tok != ai_token:
		return
	Gm.aiWaiting = false
	Gm.sel = mv >> 1
	hud.update_cards()
	var c := cell_center(mv >> 1)
	ring(c.x, c.y, Color8(255, 214, 90))
	await wait(360)
	if tok != ai_token:
		return
	Gm.sel = -1
	play_move(mv)

func play_move(mv: int) -> void:
	if Gm.s == null or Gm.s.over or Gm.moving:
		return
	Gm.moving = true
	var mover: int = Gm.s.turn
	hand.p = mover
	if is_human(mover):
		Gm.hist.append(E.clone(Gm.s))
	Gm.busy = true
	Gm.sel = -1
	Gm.hoverArrow = 0
	hud.update_cards()
	hud.show_ff(true)
	var before := [score_of(Gm.s, 0), score_of(Gm.s, 1)]
	var s2 := E.clone(Gm.s)
	var ev := []
	E.move(s2, mv, Gm.R, ev)
	Gm.vis = E.clone(Gm.s)
	await play_events(ev)
	Gm.s = s2
	Gm.vis = E.clone(s2)
	await wait(250)
	if not visuals_match(Gm.s):
		await get_tree().create_timer(0.4).timeout
		if not visuals_match(Gm.s):
			rebuild(Gm.s)
	# nói chọc
	var gain := [score_of(Gm.s, 0) - before[0], score_of(Gm.s, 1) - before[1]]
	var quan := false
	for e in ev:
		if e.t == "cap" and e.q:
			quan = true
	if Gm.mode == "ai":
		if mover == 1:
			if quan:
				say("quan")
			elif gain[1] >= 8:
				say("big")
			elif gain[1] > 0 and randf() < 0.5:
				say("eat")
			elif not gain[1] and randf() < 0.25:
				say("lost")
		elif quan or gain[0] >= 8:
			say("hurt")
	Gm.busy = false
	Gm.moving = false
	hud.show_ff(false)
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
	Gm.vis = E.clone(Gm.s)
	Gm.sel = -1
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
	var a := score_of(s, 0)
	var b := score_of(s, 1)
	store_del("oaq-save-v1")
	var title := ""
	var av := ""
	if a == b:
		title = "Hòa rồi, huề nghen!"
		av = Gm.av[0]
	elif Gm.mode == "ai":
		title = "Bạn thắng rồi nghen!" if a > b else OPP[Gm.level].name + " thắng rồi!"
		av = Gm.av[0] if a > b else Gm.av[1]
	else:
		title = (Gm.names[0] if a > b else Gm.names[1]) + " thắng rồi!"
		av = Gm.av[0] if a > b else Gm.av[1]
	if Gm.mode == "ai":
		var k := "w" if a > b else ("l" if a < b else "d")
		stats[k][Gm.level] = int(stats[k][Gm.level]) + 1
		store_set("oaq-stats-v1", stats)
		say("lose" if a > b else "win")
	var human_won: bool = a != b if Gm.mode == "pvp" else a > b
	if human_won:
		snd.win()
		petal_rain(90)
	elif a != b:
		snd.lose()
	else:
		snd.win()
	var sub := ""
	if Gm.mode == "ai":
		sub = "Gặp %s: thắng %d · thua %d · hòa %d" % [OPP[Gm.level].name, int(stats.w[Gm.level]), int(stats.l[Gm.level]), int(stats.d[Gm.level])]
	else:
		sub = "Hết quan, tàn dân, thu quân, kéo về" if s.end == "hetquan" else "Hết quân để rải, dừng ván"
	var w := 0 if a > b else (1 if b > a else -1)
	hud.end_info(av, title, sub, s, [a, b])
	ended.emit(Gm.mode, int(Gm.level), w)
	await get_tree().create_timer(0.9 if human_won else 0.7).timeout
	hud.show_ov("end")

func reward(xu: int, left: int, mx: int) -> void:
	hud.set_reward(xu, left, mx)
	if xu > 0:
		hud.toast("+%d xu" % xu, "big")

func resume_game() -> void:
	var sv = store.get("oaq-save-v1", null)
	if not (sv is Dictionary):
		return
	Gm.mode = String(sv.mode)
	Gm.level = int(sv.level)
	Gm.names = [String(sv.names[0]), String(sv.names[1])]
	Gm.av = [String(sv.av[0]), String(sv.av[1])]
	Gm.s = deser(sv.s)
	Gm.R = {"non": bool(sv.R.get("non", true)), "qv": int(sv.R.get("qv", 10)), "borrow": bool(sv.R.get("borrow", true))}
	Gm.hist = []
	for h in sv.get("hist", []):
		Gm.hist.append(deser(h))
	Gm.undoLeft = int(sv.get("undoLeft", 3))
	Gm.sel = -1
	Gm.busy = true
	Gm.moving = false
	Gm.started = true
	Gm.vis = E.clone(Gm.s)
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

# ============================================================ bấm, vuốt, phím
func choose(i: int, dir: int) -> void:
	if tut_step < 2:
		tut_step = 2
		store_set("oaq-tut", 2)
	snd.sel()
	play_move(i * 2 + (1 if dir > 0 else 0))

func arrow_hit(X: Vector2) -> int:
	if Gm.sel < 0:
		return 0
	for a in arrow_chips():
		if Vector2(X.x - a.X, X.y - a.Y).length() < a.r * 1.5:
			return a.dir
	return 0

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
		_pressing = true
		_pdown(X)
	elif kind == "move":
		_pmove(X)
	else:
		_pressing = false
		Gm.press = null

func _pdown(X: Vector2) -> void:
	if not Gm.started or Gm.s == null:
		return
	if Gm.busy and Gm.moving:
		if Gm.ff == 1.0:
			hud.ff_toggle()
		return
	var ad := arrow_hit(X)
	if ad:
		choose(Gm.sel, ad)
		return
	var uv := unmap(X.x, X.y)
	var i := cell_at(uv.x, uv.y)
	if i >= 0 and cell_playable(i):
		Gm.press = {"i": i, "X": X}
		if Gm.sel != i:
			Gm.sel = i
			snd.sel()
			if tut_step == 0:
				tut_step = 1
		hud.update_cards()
	elif Gm.sel >= 0:
		Gm.sel = -1
		hud.update_cards()

func _pmove(X: Vector2) -> void:
	if Gm.press != null and _pressing:
		# vuốt dọc theo hàng là chọn hướng
		var d: Vector2 = X - Gm.press.X
		if d.length() > maxf(34.0, L.s * 0.35):
			var i: int = Gm.press.i
			Gm.press = null
			if Gm.sel == i:
				var best := -1e9
				var dir := 0
				for c in arrow_chips():
					var dot: float = d.x * c.ux + d.y * c.uy
					if dot > best:
						best = dot
						dir = c.dir
				if dir:
					choose(i, dir)
			return
	var uv := unmap(X.x, X.y)
	var i := cell_at(uv.x, uv.y)
	Gm.hover = i if cell_playable(i) else -1
	Gm.hoverArrow = arrow_hit(X) if human_live() else 0
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if Gm.hover >= 0 or Gm.hoverArrow else Control.CURSOR_ARROW

func _unhandled_key_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey) or not ev.pressed:
		return
	if hud.any_open():
		if ev.keycode == KEY_ESCAPE:
			hud.close_all()
		return
	if Gm.s == null or Gm.busy or not is_human(Gm.s.turn):
		return
	var p: int = Gm.s.turn
	if ev.keycode >= KEY_1 and ev.keycode <= KEY_5:
		# phím số đếm ô từ trái qua phải như trên màn (màn dọc: trên xuống dưới)
		var order := []
		for k in 5:
			var i := E.row_start(p) + k
			order.append({"i": i, "X": map(cell_center(i).x, cell_center(i).y)})
		order.sort_custom(func(a, b): return a.X.y < b.X.y if L.port else a.X.x < b.X.x)
		var i: int = order[ev.keycode - KEY_1].i
		if cell_playable(i):
			Gm.sel = i
			snd.sel()
			hud.update_cards()
	elif Gm.sel >= 0 and ev.keycode in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]:
		var v: Vector2 = {KEY_LEFT: Vector2(-1, 0), KEY_RIGHT: Vector2(1, 0), KEY_UP: Vector2(0, -1), KEY_DOWN: Vector2(0, 1)}[ev.keycode]
		for c in arrow_chips():
			if c.ux * v.x + c.uy * v.y > 0.7:
				choose(Gm.sel, c.dir)
				break
	elif ev.keycode == KEY_ESCAPE:
		Gm.sel = -1
		hud.update_cards()
	elif ev.keycode == KEY_Z and (ev.ctrl_pressed or ev.meta_pressed):
		undo()
