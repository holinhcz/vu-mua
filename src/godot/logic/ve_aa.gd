extends Node2D
# Nét vẽ chung cho các hình vẽ bằng mã trên làng (con vật trong chuồng, gà vịt sổng, chim sáo...): vẽ thẳng ở độ phân giải
# màn hình (canvas_transform của làng), không phóng ảnh. Lớp con đặt `farm` rồi gọi _L / _Dt / _xe ... trong _draw, cuối cùng _flush().

const Bong = preload("res://logic/bong.gd")

var farm
var tt := 0.0

func _m(day: String, nite: String) -> Color:   # m(): màu ban ngày / ban đêm
	return Color(nite if farm.G.night else day)

# Hình vẽ thẳng ở độ phân giải màn hình (canvas_transform của làng), không phóng ảnh. Godot không khử răng cưa khi
# tô đa giác, nên mỗi hình = lõi đặc + một vòng 1 px màn hình nhạt dần ra ngoài (mép mịn như canvas bản web).
# Gom hết tam giác của một lần vẽ thành một lệnh (canvas_item_add_triangle_array), xả trước mỗi lệnh vẽ khác.
var _aa := 1.0             # 1 px màn hình, tính theo đơn vị đang vẽ
var _P := PackedVector2Array()
var _C := PackedColorArray()
var _I := PackedInt32Array()

func _flush() -> void:
	if _I.size() > 0:
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), _I, _P, _C)
	_P = PackedVector2Array()
	_C = PackedColorArray()
	_I = PackedInt32Array()

func _tf(o: Vector2, s: Vector2, rot := 0.0) -> void:   # draw_set_transform, xả lô trước
	_flush()
	draw_set_transform(o, rot, s)

static func _col(c) -> Color:
	return c if c is Color else Color(c)

func _shape(P: PackedVector2Array, col: Color) -> void:
	# lõi: tam giác hoá đa giác; vòng: mỗi cạnh đẩy ra 1 px theo pháp tuyến đỉnh, màu tắt dần
	var n := P.size()
	if n < 3:
		return
	var tri := Geometry2D.triangulate_polygon(P)
	if tri.is_empty():
		return
	var b := _P.size()
	_P.append_array(P)
	for k in n:
		_C.append(col)
	for k in tri:
		_I.append(b + k)
	var ar := 0.0
	for k in n:
		ar += P[k].cross(P[(k + 1) % n])
	var sg := 1.0 if ar > 0.0 else -1.0
	var c0 := Color(col.r, col.g, col.b, 0.0)
	var o := _P.size()
	for k in n:
		var a := P[(k + n - 1) % n]
		var c := P[(k + 1) % n]
		var e1 := (P[k] - a).normalized()
		var e2 := (c - P[k]).normalized()
		var nm := (Vector2(e1.y, -e1.x) + Vector2(e2.y, -e2.x)) * sg
		nm = nm.normalized() if nm.length() > 0.001 else Vector2(e2.y, -e2.x) * sg
		_P.append(P[k] + nm * _aa)
		_C.append(c0)
	for k in n:
		var k2 := (k + 1) % n
		_I.append_array([b + k, b + k2, o + k2, b + k, o + k2, o + k])

func _L(x: float, y: float, rx: float, ry: float, c, rot := 0.0) -> void:   # ellipse tô
	var n := clampi(int(maxf(rx, ry) / _aa * 0.9), 10, 48)
	var cr := cos(rot)
	var sr := sin(rot)
	var P := PackedVector2Array()
	for k in n:
		var a := TAU * k / n
		var px := cos(a) * rx
		var py := sin(a) * ry
		P.append(Vector2(x + px * cr - py * sr, y + px * sr + py * cr))
	_shape(P, _col(c))

func _seg(a: Vector2, b: Vector2, col: Color, w: float) -> void:   # đoạn thẳng dày w, hai đầu tròn
	var d := b - a
	if d.length() < 0.0001:
		_L(a.x, a.y, w * 0.5, w * 0.5, col)
		return
	var nm := Vector2(-d.y, d.x).normalized() * w * 0.5
	_shape(PackedVector2Array([a + nm, b + nm, b - nm, a - nm]), col)
	_L(a.x, a.y, w * 0.5, w * 0.5, col)
	_L(b.x, b.y, w * 0.5, w * 0.5, col)

func _Dt(x0: float, y0: float, x1: float, y1: float, c, w: float) -> void:   # đoạn thẳng, đầu tròn (lineCap round)
	_seg(Vector2(x0, y0), Vector2(x1, y1), _col(c), w)

func _line(P: PackedVector2Array, c, w: float) -> void:   # nét cong (đuôi heo, sừng dê)
	for k in P.size() - 1:
		_seg(P[k], P[k + 1], _col(c), w)

func _xe(p: Array, c) -> void:   # đa giác tô
	var P := PackedVector2Array()
	for i in range(0, p.size(), 2):
		P.append(Vector2(p[i], p[i + 1]))
	_shape(P, _col(c))

func _quad(p0: Vector2, c: Vector2, p1: Vector2) -> PackedVector2Array:
	var P := PackedVector2Array()
	for i in 9:
		var u := i / 8.0
		P.append(p0.lerp(c, u).lerp(c.lerp(p1, u), u))
	return P

func _x0(at: Vector2, id: String, red := false) -> void:   # X0: bong bóng dùng chung (bong.gd), hình món id
	var le: float = farm.sign_le()
	var r := 1.0 if farm.G.motion_off() else 1.0 + 0.08 * sin(tt * 5.0 + at.x)
	var s := r * le
	_flush()
	var hinh: Texture2D = Bong.anh(id.substr(1), s * farm.main.zoom) if id.begins_with("@") else farm.ui.item_ic(id, 13.6 * s * farm.main.zoom)
	Bong.ve(self, at, s, hinh, red)
