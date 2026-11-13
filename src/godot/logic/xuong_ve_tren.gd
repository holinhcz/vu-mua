extends Node2D
# Lớp trên của xưởng (vẽ sau lửa): ảnh che, khung chạy hiện tại; rồi thanh tiến độ / bong bóng món xong (Ey, X0 bản web).

var xv
var mode := "front"     # front: ảnh che + khung chạy; bub: bong bóng / thanh tiến độ (trên hơi khói)

func _draw() -> void:
	if xv == null or xv.A.is_empty():
		return
	var farm = xv.farm
	var G = farm.G
	var run: bool = xv.running()
	if mode == "front":
		if run:
			_img("che")
			for s in xv.seqs:
				var f := int(floor(xv.t * float(s[2]))) % int(s[1])
				_img(String(s[0]) + str(f))
		return
	# Ey: bong bóng / thanh tiến độ ở độ cao bh của xưởng
	var k: String = xv.k
	var sr: Dictionary = G.xw.sr[k]
	var w: Dictionary = G.xw.w(k)
	var cx: float = sr.gx + sr.fw / 2.0
	var cy: float = sr.gy + sr.fd / 2.0
	var bh: float = float(xv.BH.get(sr.type, 40 + sr.fd * 30))
	var p := Vector2(farm.en(cx, cy), farm.nn(cx, cy, bh))
	var o := 0.0 if G.motion_off() else sin(xv.t * 3.0 + p.x) * 1.2
	var n: int = G.xw.df(k)
	if n > 0:
		_x0(Vector2(p.x, p.y + o), String(w.r.keys()[0]))
	elif w.q.size() > 0:
		var c := minf(1.0, float(w.p) / float(G.xw.R[w.q[0]].time))
		draw_rect(Rect2(p.x - 11, p.y + o + 8, 22, 3.6), Color(0, 0, 0, 0.35))
		var pal = G.troi.st.get("pal", {}) if G.troi != null else {}
		draw_rect(Rect2(p.x - 11, p.y + o + 8, 22 * c, 3.6), Color(String(pal.get("leaf2", "#5aa83a"))))

func _img(name: String) -> void:
	var farm = xv.farm
	var d: String = farm.dn()
	var r = xv.A.get(name + d)
	if r == null:
		return
	var tx: Texture2D = farm.P.texz(xv.b, name + "_" + d, xv.PPU, farm.main.zoom)
	if tx == null:
		return
	var c: Vector2 = xv.centre()
	draw_texture_rect(tx, Rect2(c.x + float(r[0]), c.y + float(r[1]), float(r[2]), float(r[3])), false)

func _x0(at: Vector2, id: String) -> void:   # X0: bong bóng trắng r 10 + đuôi, icon món 6,8
	var farm = xv.farm
	var le: float = farm.sign_le()
	var r := 1.0 if farm.G.motion_off() else 1.0 + 0.08 * sin(xv.t * 5.0 + at.x)
	var s := r * le
	draw_set_transform(at, 0.0, Vector2(s, s))
	draw_circle(Vector2.ZERO, 10.0, Color(1, 1, 1, 0.97))
	draw_arc(Vector2.ZERO, 10.0, 0, TAU, 32, Color(0, 0, 0, 0.28), 1.0, true)
	draw_colored_polygon(PackedVector2Array([Vector2(-3.2, 8.6), Vector2(3.2, 8.6), Vector2(0, 13.5)]), Color(1, 1, 1, 0.97))
	var tx: Texture2D = farm.ui.item_ic(id, 13.6 * s * farm.main.zoom)
	if tx != null:
		draw_texture_rect(tx, Rect2(-6.8, -6.8, 13.6, 13.6), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
