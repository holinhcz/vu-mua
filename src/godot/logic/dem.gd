extends Node
# ĐÊM (đợt 2 hiệu ứng trời): bản đồ ánh sáng + đom đóm, sao lấp lánh trên mặt nước.
# Bản đồ ánh sáng: một SubViewport bằng 1/4 màn, mỗi khung vẽ các vầng sáng mềm (bè ngang theo mặt đất, nhô lên chút
# cho mái / tán cây) ở chỗ có đèn, cộng dồn. Lớp chỉnh màu (hau_ky.gdshader) đọc nó: chỗ có sáng bớt tối, nhuộm màu đèn.
# Nguồn sáng: nhà (cửa sổ), đình, chùa, quán, miếu (nhang), đèn bẫy, hoa đăng, đèn ông sao, nồi bánh tét, lò gạch, xưởng
# đang chạy (lửa nhấp nháy), nhân vật (đèn dầu). Đom đóm và sao vẽ trên lớp chỉnh màu (không bị tối đi), toạ độ làng.

const Q := 4.0   # bản đồ ánh sáng nhỏ hơn màn Q lần

# id -> [bán kính (px làng), màu, độ sáng, lửa?]
const SRC := {
	"hut": [74, Color(1.0, 0.78, 0.46), 0.85, false], "hut2": [74, Color(1.0, 0.78, 0.46), 0.85, false],
	"hutnho": [62, Color(1.0, 0.78, 0.46), 0.8, false], "hutnho2": [62, Color(1.0, 0.78, 0.46), 0.8, false],
	"house": [84, Color(1.0, 0.8, 0.5), 0.9, false], "house2": [84, Color(1.0, 0.8, 0.5), 0.9, false],
	"pavilion": [70, Color(1.0, 0.8, 0.5), 0.75, false], "pavilion2": [70, Color(1.0, 0.8, 0.5), 0.75, false],
	"dinh": [120, Color(1.0, 0.74, 0.42), 1.0, false], "dinh2": [120, Color(1.0, 0.74, 0.42), 1.0, false],
	"chua": [120, Color(1.0, 0.76, 0.44), 1.0, false], "chua2": [120, Color(1.0, 0.76, 0.44), 1.0, false],
	"choi": [56, Color(1.0, 0.76, 0.46), 0.7, false], "choi2": [56, Color(1.0, 0.76, 0.46), 0.7, false],
	"sap": [60, Color(1.0, 0.8, 0.5), 0.8, false], "sap2": [60, Color(1.0, 0.8, 0.5), 0.8, false],
	"tramyt": [80, Color(0.95, 0.92, 0.8), 0.85, false], "tramyt2": [80, Color(0.95, 0.92, 0.8), 0.85, false],
	"quancom": [84, Color(1.0, 0.76, 0.44), 0.95, false], "quancom2": [84, Color(1.0, 0.76, 0.44), 0.95, false],
	"taphoa": [80, Color(1.0, 0.8, 0.5), 0.9, false], "taphoa2": [80, Color(1.0, 0.8, 0.5), 0.9, false],
	"cafe": [80, Color(1.0, 0.74, 0.44), 0.95, false], "cafe2": [80, Color(1.0, 0.74, 0.44), 0.95, false],
	"truong": [84, Color(1.0, 0.82, 0.55), 0.8, false], "truong2": [84, Color(1.0, 0.82, 0.55), 0.8, false],
	"bagian": [70, Color(1.0, 0.78, 0.46), 0.8, false], "bagian2": [70, Color(1.0, 0.78, 0.46), 0.8, false],
	"logach": [70, Color(1.0, 0.52, 0.24), 0.95, true], "logach2": [70, Color(1.0, 0.52, 0.24), 0.95, true],
	"shrine": [34, Color(1.0, 0.5, 0.3), 0.75, true], "shrine2": [34, Color(1.0, 0.5, 0.3), 0.75, true],
	"denbay": [64, Color(1.0, 0.9, 0.6), 1.0, false], "hoadang": [56, Color(1.0, 0.68, 0.36), 0.95, true],
	"denongsao": [60, Color(1.0, 0.62, 0.34), 0.95, true], "noibanhtet": [58, Color(1.0, 0.52, 0.24), 0.95, true]}

var G
var farm
var sv: SubViewport
var drw: Node2D
var fxl: CanvasLayer
var fxn: Node2D
var L := []        # [vị trí làng (chân), bán kính, màu, độ sáng, lửa?, pha]
var _lt := 0.0
var nk := 0.0      # độ đêm 0..1 (đèn bật dần lúc chạng vạng, tắt lúc sáng)
var t := 0.0
var fly := []      # đom đóm: {p (ô), v, ph}
var wat := []      # ô nước trong khung nhìn: [Vector2 ô]
var _wt := 0.0

func _init(g, f) -> void:
	G = g
	farm = f
	sv = SubViewport.new()
	sv.transparent_bg = true
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sv.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	sv.disable_3d = true
	sv.size = Vector2i(64, 64)
	add_child(sv)
	drw = Node2D.new()
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	drw.material = m
	drw.draw.connect(_draw_lights)
	sv.add_child(drw)
	fxl = CanvasLayer.new()
	fxl.layer = 7   # trên lớp chỉnh màu (6), dưới giao diện (10)
	add_child(fxl)
	fxn = Node2D.new()
	var m2 := CanvasItemMaterial.new()
	m2.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	fxn.material = m2
	fxn.draw.connect(_draw_fx)
	fxl.add_child(fxn)

var _glow: Texture2D = null
func glow() -> Texture2D:   # vầng tròn mềm trắng -> trong
	if _glow == null:
		var gr := Gradient.new()
		gr.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
		gr.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
		var gt := GradientTexture2D.new()
		gt.gradient = gr
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
		gt.width = 64
		gt.height = 64
		_glow = gt
	return _glow

func texture() -> Texture2D:
	return sv.get_texture()

static func night_k(h: float) -> float:   # đèn bật 17g45 -> 19g, tắt 5g15 -> 6g15
	if h >= 19.0 or h < 5.25:
		return 1.0
	if h >= 17.75:
		return (h - 17.75) / 1.25
	if h < 6.25:
		return 1.0 - (h - 5.25)
	return 0.0

func moon_k() -> float:   # trăng: rằm (ngày 15 tháng 28 ngày) sáng nhất, cuối tháng tối nhất -> 0..1
	var d := float(posmod(G.day(), 28)) + 1.0
	return 1.0 - absf(d - 15.0) / 14.0

func _gather() -> void:   # gom nguồn sáng (4 lần / giây)
	L = []
	var lg = G.lang
	if lg == null:
		return
	var O: Array = lg.objs()
	for o in O:
		if not (o is Dictionary):
			continue
		var s = SRC.get(o.id)
		var t0 = lg.Pi.get(o.id)
		if s == null or t0 == null:
			continue
		_add(float(o.gx) + float(t0.fw) / 2.0, float(o.gy) + float(t0.fd) / 2.0, s, float(o.gx) * 1.7 + float(o.gy))
	for o in lg.SO:
		var s = SRC.get(o.id)
		if s == null or o.wild or not lg.so_shown(o):
			continue
		_add(float(o.gx) + float(o.fw) / 2.0, float(o.gy) + float(o.fd) / 2.0, s, float(o.gx) * 1.3 + float(o.gy))
	for k in G.xw.sr:   # xưởng đang chạy: lửa
		var w: Dictionary = G.xw.w(k)
		if int(w.get("b", 0)) == 1 and w.q.size() > 0:
			var r: Dictionary = G.xw.sr[k]
			_add(float(r.gx) + float(r.fw) / 2.0, float(r.gy) + float(r.fd) / 2.0, [66, Color(1.0, 0.55, 0.26), 0.9, true], float(r.gx))

func _add(x: float, y: float, s: Array, ph: float) -> void:
	L.append([Vector2(farm.en(x, y), farm.nn(x, y)), float(s[0]), s[1], float(s[2]), bool(s[3]), ph])

func step(dt: float, on: bool, h: float, full: bool) -> void:
	t += dt
	nk = night_k(h) if on else 0.0
	var vs: Vector2 = farm.get_viewport().get_visible_rect().size
	var want := Vector2i(maxi(8, int(vs.x / Q)), maxi(8, int(vs.y / Q)))
	if sv.size != want:
		sv.size = want
	_lt -= dt
	if _lt <= 0.0 and nk > 0.0:
		_lt = 0.25
		_gather()
	drw.queue_redraw()
	fxn.visible = full and nk > 0.0
	if fxn.visible:
		_fx_step(dt)
		fxn.queue_redraw()

func _scr(w: Vector2) -> Vector2:
	return (w - farm.main.cam) * farm.main.zoom

func _draw_lights() -> void:
	if nk <= 0.0:
		return
	var z: float = farm.main.zoom
	var tx := glow()
	var vs := Vector2(sv.size) * Q
	var mo: bool = G.motion_off()
	for e in L:
		var p := _scr(e[0])
		var r: float = float(e[1]) * z
		if p.x < -r or p.y < -r or p.x > vs.x + r or p.y > vs.y + r:
			continue
		var k: float = float(e[3]) * nk
		if e[4] and not mo:   # lửa nhấp nháy
			k *= 0.82 + 0.12 * sin(t * 9.0 + float(e[5])) + 0.06 * sin(t * 23.0 + float(e[5]) * 2.0)
		var c: Color = e[2]
		c.a = 1.0
		var col := Color(c.r * k, c.g * k, c.b * k, 1.0)
		# mặt đất: bè ngang; thêm vầng nhỏ phía trên (mái, tán cây gần đèn)
		var g := Rect2((p.x - r) / Q, (p.y - r * 0.62 - r * 0.15) / Q, 2.0 * r / Q, 1.24 * r / Q)
		drw.draw_texture_rect(tx, g, false, col)
		var r2 := r * 0.55
		var g2 := Rect2((p.x - r2) / Q, (p.y - r * 0.55 - r2) / Q, 2.0 * r2 / Q, 2.0 * r2 / Q)
		drw.draw_texture_rect(tx, g2, false, col * Color(0.6, 0.6, 0.6, 1.0))
	# nhân vật cầm đèn dầu
	var pp: Vector2 = G.ppos
	var pl := _scr(Vector2(farm.en(pp.x, pp.y), farm.nn(pp.x, pp.y)))
	var pr := 40.0 * z
	var pk := 0.55 * nk * (1.0 if mo else 0.92 + 0.08 * sin(t * 7.0))
	drw.draw_texture_rect(tx, Rect2((pl.x - pr) / Q, (pl.y - pr * 0.9) / Q, 2.0 * pr / Q, 1.5 * pr / Q), false, Color(pk, pk * 0.85, pk * 0.6, 1.0))

# ------------------------------------------------------------------ đom đóm, sao trên mặt nước (mức Nét)
func _view_tiles() -> Rect2:   # khung nhìn theo ô (gộp 4 góc)
	var vs: Vector2 = farm.get_viewport().get_visible_rect().size
	var a := Vector2(1e9, 1e9)
	var b := Vector2(-1e9, -1e9)
	for c in [Vector2.ZERO, Vector2(vs.x, 0), Vector2(0, vs.y), vs]:
		var w: Vector2 = farm.main.cam + c / farm.main.zoom
		var q: Vector2 = farm.to_tile(w)
		a = Vector2(minf(a.x, q.x), minf(a.y, q.y))
		b = Vector2(maxf(b.x, q.x), maxf(b.y, q.y))
	return Rect2(a, b - a)

func _fx_step(dt: float) -> void:
	var v := _view_tiles()
	_wt -= dt
	if _wt <= 0.0:
		_wt = 1.0
		wat = []
		var lg = G.lang
		if lg != null and v.size.x * v.size.y < 9000.0:
			for x in range(int(floor(v.position.x)), int(ceil(v.end.x))):
				for y in range(int(floor(v.position.y)), int(ceil(v.end.y))):
					if lg.is_water(x, y):
						wat.append(Vector2(x, y))
	var want := clampi(int(v.size.x * v.size.y / 40.0), 8, 40)
	while fly.size() < want:
		fly.append(_new_fly(v))
	while fly.size() > want:
		fly.pop_back()
	var mo: bool = G.motion_off()
	for f in fly:
		if not v.grow(2.0).has_point(f.p):
			var n := _new_fly(v)
			f.p = n.p
			f.ph = n.ph
		if not mo:
			f.a += (randf() - 0.5) * dt * 3.0
			f.p += Vector2(cos(f.a), sin(f.a)) * dt * 0.35

func _new_fly(v: Rect2) -> Dictionary:
	return {"p": v.position + Vector2(randf() * v.size.x, randf() * v.size.y), "a": randf() * TAU, "ph": randf() * TAU, "h": 6.0 + randf() * 14.0}

func _draw_fx() -> void:
	var k: float = farm.main.dpr if "dpr" in farm.main else 1.0
	var sea: int = G.season()
	var nf := 1.0 if sea == 1 or sea == 2 else (0.6 if sea == 0 else 0.35)   # hạ, thu nhiều đom đóm
	var mo: bool = G.motion_off()
	var n := int(fly.size() * nf)
	for i in n:
		var f: Dictionary = fly[i]
		var w := Vector2(farm.en(f.p.x, f.p.y), farm.nn(f.p.x, f.p.y) - float(f.h))
		var p := _scr(w)
		var bl := 1.0 if mo else maxf(0.0, sin(t * 2.2 + float(f.ph)))
		bl = bl * bl * nk
		if bl < 0.02:
			continue
		fxn.draw_circle(p, 5.0 * k, Color(0.55, 0.9, 0.25, 0.22 * bl))
		fxn.draw_circle(p, 1.6 * k, Color(0.85, 1.0, 0.5, 0.95 * bl))
	# sao, ánh trăng lấp lánh trên mặt nước
	var mk := 0.45 + 0.55 * moon_k()
	for q in wat:
		var hsh := fposmod(sin(q.x * 12.9898 + q.y * 78.233) * 43758.5453, 1.0)
		var o := Vector2(fposmod(hsh * 7.31, 1.0), fposmod(hsh * 3.17, 1.0))
		var w := Vector2(farm.en(q.x + o.x, q.y + o.y), farm.nn(q.x + o.x, q.y + o.y))
		var tw := 1.0 if mo else pow(maxf(0.0, sin(t * (1.2 + hsh * 2.0) + hsh * 40.0)), 6.0)
		var a := tw * nk * mk
		if a < 0.03:
			continue
		var p := _scr(w)
		fxn.draw_circle(p, 2.6 * k, Color(0.7, 0.8, 1.0, 0.18 * a))
		fxn.draw_circle(p, 0.9 * k, Color(0.95, 0.97, 1.0, 0.9 * a))
