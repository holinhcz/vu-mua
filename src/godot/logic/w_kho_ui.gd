extends RefCounted
# KHO, BÁN HÀNG (giao diện): phần bảng Kho bản web còn thiếu ở bản Godot.
#  - iP: món có trong kho và hợp mục đang lọc (bảng Kho, nút Bán hết).
#  - mkChart: biểu đồ giá 7 ngày cuối khung chi tiết #khDet (div.mkch: svg 220×44 + dòng small).
#    CSS web: .mkch{grid-column:1/-1;margin-top:6px}
#             .mkch svg{width:100%;height:44px;display:block;background:#fff;border-radius:10px;box-shadow:inset 0 0 0 1px rgba(150,112,48,.22)}
#             .mkch small{display:block;margin-top:3px;font:500 11.5px/1.35 var(--font-body);color:#8a6a3a}
#    Vẽ một lần mỗi khi số liệu đổi (bộ ráp so chữ ký sig() rồi mới dựng lại), không vẽ lại mỗi khung hình.
#  - det_hint: câu nhắc .kdhint (giữ lại cho đơn / để gieo).

const Box = preload("res://ui/box.gd")
const Css = preload("res://ui/css.gd")

var U          # ui.gd
var G          # game.gd
var W          # w_kho.gd

func _init(ui, wk) -> void:
	U = ui
	G = ui.G
	W = wk

func iP(t: String, f: String) -> bool:   # iP: jf[t].cat = rP(t) (ui._cat)
	return int(G.g.barn.get(t, 0)) > 0 and (f == "all" or U._cat(t) == f)

func det_hint(s: String, M: int) -> String:   # eG: chữ .kdhint
	return W.det_hint(s, M)

# chữ ký để bộ ráp biết khi nào dựng lại biểu đồ
func sig(t: String) -> String:
	var d: Dictionary = W.mkChart(t)
	if d.is_empty():
		return t + "|"
	return t + "|" + str(d.pts) + "|" + String(d.label)

# Line: vẽ polyline + chấm của svg (viewBox 220×44, preserveAspectRatio mặc định = xMidYMid meet)
class Line extends Control:
	var pts: Array = []
	var vw := 220.0
	var vh := 44.0
	func _draw() -> void:
		var s: float = minf(size.x / vw, size.y / vh)
		var off := Vector2((size.x - vw * s) * 0.5, (size.y - vh * s) * 0.5)
		var P := PackedVector2Array()
		for p in pts:
			P.append(off + (p as Vector2) * s)
		if P.size() >= 2:
			draw_polyline(P, Color8(0xc9, 0x8a, 0x2a), 2.0 * s, true)
		for i in P.size():
			var last := i == P.size() - 1
			draw_circle(P[i], (3.2 if last else 2.0) * s, Color8(0x3f, 0x9a, 0x3a) if last else Color8(0xc9, 0x8a, 0x2a))

# mkChart: trả về Box (đặt ở x, y trong #khDet, rộng w css px, zoom z của bảng Kho); null khi chưa đủ 2 ngày giá.
func chart(t: String, x: float, y: float, w: float, z: float = 1.0) -> Control:   # mkChart
	var d: Dictionary = W.mkChart(t)
	if d.is_empty():
		return null
	var h_svg := 44.0 * z
	var fs := 11.5 * z
	var lh := fs * 1.35
	var mt := 3.0 * z
	var lbl: String = d.label
	var nl: int = U._nlines(lbl, fs, 500, w)
	var root := Box.new()
	root.z = z
	root.place(Rect2(x, y, w, h_svg + mt + lh * nl))
	var sv := Box.new()
	sv.style("background-color:rgb(255, 255, 255);border-radius:10px;box-shadow:rgba(150, 112, 48, 0.22) 0px 0px 0px 1px inset;", z)
	root.add(sv)
	sv.place(Rect2(0, 0, w, h_svg))
	var ln := Line.new()
	ln.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ln.vw = float(d.W)
	ln.vh = float(d.H)
	ln.pts = d.pts
	ln.position = Vector2.ZERO
	ln.size = Vector2(w, h_svg) * Css.K
	sv.add(ln)
	root.text(lbl, Rect2(0, h_svg + mt, w, lh * nl), fs, 500, Color8(0x8a, 0x6a, 0x3a), "left", [], true)
	root.redraw()
	return root
