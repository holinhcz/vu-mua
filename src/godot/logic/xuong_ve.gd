extends Node2D
# Vẽ 1 xưởng chế biến đã xây, bằng đúng ảnh godot/xuong/<thư mục>/ (gói l/x_<thư mục>.wasm, mức 0 = byte file gốc).
# Theo README từng xưởng: lúc nghỉ chỉ ảnh i; lúc chạy ảnh r -> lửa (hạt) -> che -> khung chạy hiện tại -> hơi/khói (hạt).
# Toạ độ atlas: [x, y, rộng, cao] đơn vị làng, tính từ tâm nền (điểm giữa hình thoi nền); 9 px mỗi đơn vị.
# Trên xưởng (Ey bản web): đang làm thì thanh tiến độ, xong thì bong bóng món chờ thu.

const FOLDER := {"ruong": "ruongmuoi", "mill": "coixay", "oven": "lobanhmi", "muoi": "muoi", "ep": "ep", "rang": "rang",
	"duong": "duong", "kho": "noikho", "say": "say", "btrang": "btrang", "det": "khungdet", "nuong": "nuong",
	"bepcui": "bepcui", "quanche": "quanche", "lobanh": "lobanh", "hangcha": "hangcha"}
const FPS := {"coixay/g": 8.0}          # khung chạy khác 10 khung/s (README)
const BH := {"oven": 88, "muoi": 72, "ep": 96, "rang": 66, "kho": 76, "say": 58, "det": 72, "duong": 96, "btrang": 70,
	"mill": 82, "nuong": 64, "bepcui": 72, "quanche": 96, "lobanh": 84, "hangcha": 80}   # To[t].bh: độ cao bong bóng
const PPU := 9.0

var farm
var k := ""
var dir := ""
var b := ""
var A := {}
var seqs := []          # [tiền tố, số khung, khung/s] theo thứ tự vẽ
var t := 0.0
var front: Node2D
var bub: Node2D
var fx := []            # [CPUParticles2D, mô tả]
var _fx_on := false
const FX = preload("res://logic/xuong_fx.gd")

func setup(f, key: String) -> void:
	farm = f
	k = key
	var s: Dictionary = farm.G.xw.sr[k]
	dir = FOLDER[s.type]
	b = "x_" + dir
	farm.P.load_bundle(b)
	front = Node2D.new()
	front.set_script(load("res://logic/xuong_ve_tren.gd"))
	front.xv = self
	add_child(front)
	bub = Node2D.new()
	bub.set_script(load("res://logic/xuong_ve_tren.gd"))
	bub.xv = self
	bub.mode = "bub"
	add_child(bub)

func _meta() -> void:
	if not A.is_empty():
		return
	A = farm.P.meta(b)
	if A.is_empty():
		return
	var n := {}
	var re := RegEx.create_from_string("^([a-z]+)(\\d+)d$")
	for key in A:
		var m := re.search(String(key))
		if m != null and m.get_string(1) != "i" and m.get_string(1) != "r":
			var p := m.get_string(1)
			n[p] = maxi(int(n.get(p, 0)), int(m.get_string(2)) + 1)
	var ps: Array = n.keys()
	ps.sort()
	for p in ps:
		seqs.append([p, n[p], float(FPS.get(dir + "/" + p, 10.0))])
	_fx_make()

func _fx_make() -> void:   # lửa giữa ảnh r và ảnh che; hơi/khói/nước sau khung chạy, dưới bong bóng
	var c := centre()
	for e in FX.list(dir):
		var p: CPUParticles2D = FX.make(e, A)
		if p == null:
			continue
		p.position += c
		add_child(p)
		if e.kind == "lua":
			move_child(p, front.get_index())
		else:
			move_child(p, bub.get_index())
		fx.append([p, e])
	if dir == "lobanhmi":
		_xeng_make()
	if dir == "ep":
		_gon_make()

var xeng := []          # lò bánh mì: [bóng, xẻng] Sprite2D trượt (README "Xẻng")
var gon: Node2D = null   # xe ép: gợn trên mặt thau khi giọt chạm nước
var _t_on := 0.0
# Che xẻng theo độ sâu (README "Xẻng", lobanhmi_xeng.gdshader) tính sẵn trên CPU: shader có sampler riêng làm
# trình duyệt điện thoại (WebGL) dán nhầm ảnh độ sâu (xanh lá) lên khói và xẻng. XN mức trượt, mỗi mức 1 ảnh mặt nạ
# dựng từ chính ảnh gốc; vị trí vẫn trượt liên tục, chỉ phần bị che lấy theo mức gần nhất (0,2 đơn vị).
const XN := 33
var _xm := {}            # "d"/"n" -> [[tex bóng...], [tex xẻng...]]
var _xjob = null         # đang dựng mặt nạ (vài mức mỗi khung)

func _xeng_make() -> void:
	if not (A.get("xeng_move") is Dictionary):
		return
	for shade in [true, false]:
		var sp := Sprite2D.new()
		sp.centered = false
		sp.visible = false
		sp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(sp)
		move_child(sp, front.get_index() + 1)   # ngay sau ảnh che, trước khói (khói bay trên xẻng)
		xeng.append(sp)

static func _dec(d: PackedByteArray, i: int, d0: float, dr: float) -> float:
	return d0 + (float(d[i]) * 256.0 + float(d[i + 1])) / 65535.0 * dr

func _xeng_build(dn: String) -> bool:   # true = xong
	var mv: Dictionary = A.xeng_move
	if _xjob == null or _xjob.dn != dn:
		var P = farm.P
		var ims := [P.img(b, "xengbong_" + dn), P.img(b, "xeng_" + dn), P.img(b, "xengdo"), P.img(b, "canhdo")]
		for im in ims:
			if im == null:
				return false
		_xjob = {"dn": dn, "i": 0, "ims": ims, "out": [[], []]}
	var j: Dictionary = _xjob
	var cd: Image = j.ims[3]
	var cdd := cd.get_data()
	var cw := cd.get_width()
	var chh := cd.get_height()
	var cr: Array = A.canhdo
	var d0 := float(mv.d0)
	var dr := float(mv.dr)
	var dk := float(mv.dk)
	var st := Vector2(mv.step[0], mv.step[1])
	var xdd: PackedByteArray = j.ims[2].get_data()
	var xw: int = j.ims[2].get_width()
	var xh: int = j.ims[2].get_height()
	var n := 0
	while j.i < XN and n < 3:
		var ins := float(mv.ins) * float(j.i) / float(XN - 1)
		for q in 2:   # 0 bóng, 1 xẻng
			var im: Image = j.ims[q]
			var w := im.get_width()
			var h := im.get_height()
			var r: Array = A.get(("xengbong" if q == 0 else "xeng") + dn)
			var src := im.get_data()
			var out := PackedByteArray()
			out.resize(w * h * 4)
			for y in h:
				var py := float(r[1]) + (y + 0.5) / h * float(r[3]) + st.y * ins
				var cy := int(floor((py - float(cr[1])) / float(cr[3]) * chh))
				for x in w:
					var i := (y * w + x) * 4
					var a := src[i + 3]
					if a == 0:
						continue
					var px := float(r[0]) + (x + 0.5) / w * float(r[2]) + st.x * ins
					var cx := int(floor((px - float(cr[0])) / float(cr[2]) * cw))
					var has := false
					var ds := 0.0
					if cx >= 0 and cy >= 0 and cx < cw and cy < chh:
						var ci := (cy * cw + cx) * 4
						if cdd[ci + 3] > 127:
							has = true
							ds = _dec(cdd, ci, d0, dr)
					if q == 0:
						var d := _dec(src, i, d0, dr) - ins * dk
						if has and absf(d - ds) < 0.6:
							out[i + 3] = a
					else:
						var xi: int = (mini(xh - 1, y * xh / h) * xw + mini(xw - 1, x * xw / w)) * 4
						var d := _dec(xdd, xi, d0, dr) - ins * dk
						if not has or d > ds:
							out[i] = src[i]
							out[i + 1] = src[i + 1]
							out[i + 2] = src[i + 2]
							out[i + 3] = a
			j.out[q].append(ImageTexture.create_from_image(Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, out)))
		j.i += 1
		n += 1
	if j.i < XN:
		return false
	_xm[dn] = j.out
	_xjob = null
	return true

static var no_xeng := false   # thử: tắt xẻng
func _xeng_step(on: bool) -> void:
	if no_xeng:
		on = false
	var mv: Dictionary = A.xeng_move
	var d: String = farm.dn()
	for sp in xeng:
		sp.visible = false
	if not on:
		return
	if not _xm.has(d) and not _xeng_build(d):
		return
	var ins := float(mv.ins) * (0.5 - 0.5 * cos(TAU * t / float(mv.period)))
	var si := clampi(int(round(ins / float(mv.ins) * (XN - 1))), 0, XN - 1)
	var c := centre()
	for j in 2:
		var sp: Sprite2D = xeng[j]
		var r = A.get(("xengbong" if j == 0 else "xeng") + d)
		var tx: Texture2D = _xm[d][j][si]
		if r == null or tx == null:
			continue
		sp.texture = tx
		sp.scale = Vector2(float(r[2]) / tx.get_width(), float(r[3]) / tx.get_height())
		sp.position = c + Vector2(r[0], r[1]) + Vector2(mv.step[0], mv.step[1]) * ins
		sp.visible = true

func _gon_make() -> void:
	if not (A.get("cot") is Array) or not (A.get("cot_day") is Array):
		return
	gon = Node2D.new()
	gon.draw.connect(_gon_draw)
	add_child(gon)
	move_child(gon, bub.get_index())

func _gon_draw() -> void:
	# giọt rơi mỗi 0,48 s, chạm nước sau sqrt(2*dy/210); gợn rộng 0,45 -> 2,9 đơn vị trong 0,45 s, alpha 0,75 -> 0, màu x0,8
	if not running():
		return
	var tx: Texture2D = farm.P.tex(b, "gon")
	if tx == null:
		return
	var c0: Array = A.cot
	var c1: Array = A.cot_day
	var hit := sqrt(2.0 * (float(c1[1]) - float(c0[1])) / 210.0)
	var ph := fmod(t - _t_on - hit + 4.8, 0.48)
	if ph > 0.45:
		return
	var k := ph / 0.45
	var w := lerpf(0.45, 2.9, k)
	var h := w * tx.get_height() / tx.get_width()
	var col := Color("#c7bfb8" if farm.dn() == "n" else "#fffcf2") * Color(0.8, 0.8, 0.8, 1.0)
	col.a = 0.75 * (1.0 - k)
	var p := centre() + Vector2(float(c0[0]), float(c1[1]))
	gon.draw_texture_rect(tx, Rect2(p.x - w / 2.0, p.y - h / 2.0, w, h), false, col)

func _fx_step() -> void:
	var on := running()
	var n := 1 if farm.dn() == "n" else 0
	for a in fx:
		var p: CPUParticles2D = a[0]
		var e: Dictionary = a[1]
		if p.texture == null:
			p.texture = farm.P.tex(b, String(e.tex))
		if e.has("col"):
			p.color = Color(String(e.col[n]))
		if on != p.emitting:
			p.emitting = on
			if on:
				p.restart()
				_t_on = t

func centre() -> Vector2:
	var s: Dictionary = farm.G.xw.sr[k]
	var cx: float = s.gx + s.fw / 2.0
	var cy: float = s.gy + s.fd / 2.0
	return Vector2(farm.en(cx, cy), farm.nn(cx, cy))

func running() -> bool:   # qW: w = đã xây và có món trong hàng đợi
	var w: Dictionary = farm.G.xw.w(k)
	return int(w.get("b", 0)) == 1 and w.q.size() > 0

func img(name: String) -> void:   # vẽ ảnh <name>_d/_n ở đúng chỗ atlas
	var d: String = farm.dn()
	var r = A.get(name + d)
	if r == null:
		return
	var tx: Texture2D = farm.P.texz(b, name + "_" + d, PPU, farm.main.zoom)
	if tx == null:
		return
	var c := centre()
	draw_texture_rect(tx, Rect2(c.x + float(r[0]), c.y + float(r[1]), float(r[2]), float(r[3])), false)

func _process(dt: float) -> void:
	t += dt
	queue_redraw()
	front.queue_redraw()
	bub.queue_redraw()
	if not fx.is_empty():
		_fx_step()
	if not xeng.is_empty():
		_xeng_step(running())
	if gon != null:
		gon.queue_redraw()

func _draw() -> void:
	_meta()
	if A.is_empty():
		return
	_focus()
	img("r" if running() else "i")

func _focus() -> void:   # By bản web: đang mở bảng xưởng -> nền sáng nhấp nháy + viền gạch đứt 8/6
	var xf = farm.ui.xfp
	if xf == null or xf.k != k:
		return
	var s: Dictionary = farm.G.xw.sr[k]
	var e := 0.18
	var q := []
	for p in [[s.gx - e, s.gy - e], [s.gx + s.fw + e, s.gy - e], [s.gx + s.fw + e, s.gy + s.fd + e], [s.gx - e, s.gy + s.fd + e]]:
		q.append(Vector2(farm.en(p[0], p[1]), farm.nn(p[0], p[1])))
	var ia := 0.55 + 0.25 * sin(t * 4.0)
	draw_colored_polygon(PackedVector2Array(q), Color(1.0, 236.0 / 255.0, 150.0 / 255.0, 0.22 * ia))
	var col := Color(1.0, 250.0 / 255.0, 215.0 / 255.0, 0.9 * ia)
	var off := fmod(t * 18.0, 14.0)    # lineDashOffset = -(t*18 % 14)
	var d := -off
	for j in 4:
		var a: Vector2 = q[j]
		var b: Vector2 = q[(j + 1) % 4]
		var L := a.distance_to(b)
		var u := (b - a) / L
		var x := fmod(d, 14.0)
		if x > 0.0:
			x -= 14.0
		while x < L:
			var x0 := maxf(0.0, x)
			var x1 := minf(L, x + 8.0)
			if x1 > x0:
				draw_line(a + u * x0, a + u * x1, col, 3.0, true)
			x += 14.0
		d = x - L
