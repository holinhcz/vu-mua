extends RefCounted
# VÒNG HIỆU ỨNG dưới ô avatar / giờ (bản 173): mỗi thứ đang ảnh hưởng tới nhân vật, ruộng vườn là một vòng tròn nhỏ có
# hình (ui/emo), viền chạy hết dần theo thời gian còn lại; bấm vòng thì hiện hộp giải thích (tên, tác dụng, còn bao lâu).
# Gồm: bùa món ăn (g.pc.bf: Chân sáo, Tay mát...), bùa EXP +50% (nv.Fu), thời tiết (mưa dầm, mưa rào, nắng hạn).

const Css = preload("res://ui/css.gd")

const D := 22.0        # đường kính vòng (đơn vị giao diện)
const GAP := 5.0
const X0 := 7.5        # thẳng mép trái avatar
const Y0 := 49.5       # dưới thanh sức của avatar
const FOOD := {"nhanh": 0x1fa74, "gat": 0x1f33e, "ben": 0x1f4aa, "xp": 0x1f4da, "mat": 0x1f372, "cau": 0x1f3a3}
const WX := {"mua": [0x1f327, "Mưa dầm", "Ruộng, cây ăn trái tự thấm nước. Đi chậm 15%. Có sấm sét, gió có thể quật ngã cây."],
	"rao": [0x1f326, "Mưa rào", "Mưa 5 giây, tạnh là ruộng và cây ăn trái no nước."],
	"han": [0x2600, "Nắng hạn", "Ruộng khô nhanh gấp 1,6 lần, nhớ tưới thường xuyên."]}

var U
var G
var rings := {}        # khóa -> Ring
var peak := {}         # khóa -> thời gian còn lớn nhất đã thấy (ms), làm mốc cho viền chạy
var _sig := ""
var _t := 0

func _init(ui) -> void:
	U = ui
	G = ui.G

static func left_txt(ms: float) -> String:
	var a := int(ceil(ms / 1000.0))
	if a >= 3600:
		return str(a / 3600) + " giờ " + str((a % 3600) / 60) + " phút"
	if a >= 60:
		return str(a / 60) + " phút"
	return str(a) + " giây"

func _items() -> Array:   # [{k, ic, n, d, left (ms, -1 = không đếm), tot}]
	var L := []
	var b: String = G.bh()
	if b != "":
		var bf: Dictionary = G.g.pc.bf
		var tot := float(bf.u) - float(bf.get("s", float(bf.u) - G.bh_left()))
		L.append({"k": "f:" + b, "ic": FOOD.get(b, 0x2728), "n": String(G.BUFFS[b].n), "d": String(G.BUFFS[b].d) + ".", "left": G.bh_left(), "tot": tot})
	if G.nv != null and G.nv.Fu() > 0.0:
		L.append({"k": "xp", "ic": 0x1f4dc, "n": "Bùa +50% EXP", "d": "Kinh nghiệm nhận được thêm 50%.", "left": G.nv.Fu(), "tot": 0.0})
	if G.troi != null:
		var w: String = G.troi.vwx()
		if WX.has(w):
			var e: Array = WX[w]
			var left := -1.0
			var tot := 0.0
			if w == "rao":
				left = G.troi.rao_t * 1000.0
				tot = G.troi.RAO_S * 1000.0
			L.append({"k": "w:" + w, "ic": e[0], "n": e[1], "d": e[2], "left": left, "tot": tot})
	return L

func sync(force := false) -> void:
	var hl = U.hud_roots.get(".hudtl")
	if hl == null or G.g == null:
		return
	var now := Time.get_ticks_msec()
	var L := _items()
	var off: bool = G.w_all == null or G.w_all.WC._mode() == "off"
	var ks := []
	for it in L:
		ks.append(it.k)
	var sg := JSON.stringify(ks) + str(off) + str(U.focus)
	if sg == _sig and not force and now - _t < 500:
		return
	_t = now
	var vis: bool = off and not U.focus
	if sg != _sig:   # vòng mới / bỏ vòng hết hạn
		_sig = sg
		for k in rings.keys():
			if not ks.has(k):
				if is_instance_valid(rings[k]):
					rings[k].queue_free()
				rings.erase(k)
				peak.erase(k)
	for i in L.size():
		var it: Dictionary = L[i]
		var r = rings.get(it.k)
		if r == null or not is_instance_valid(r):
			r = Ring.new()
			r.tex = Css.emoji(int(it.ic))
			hl.add(r)
			var kk: String = it.k
			U._click(r, func(): _tap(kk), "scale")
			rings[it.k] = r
		var left: float = it.left
		var fr := 1.0
		if left >= 0.0:
			var tot: float = it.tot
			if tot <= 0.0:   # không biết tổng (bùa EXP cộng dồn): lấy mốc lớn nhất đã thấy
				peak[it.k] = maxf(float(peak.get(it.k, 0.0)), left)
				tot = peak[it.k]
			fr = clampf(left / maxf(1.0, tot), 0.0, 1.0)
		r.fr = fr
		r.visible = vis
		r.position = (Vector2(X0 + i * (D + GAP), Y0) - hl.r.position) * Css.K
		r.size = Vector2(D, D) * Css.K
		r.queue_redraw()

func _tap(k: String) -> void:
	if k == "xp":   # bùa EXP: mở túi đồ dùng (có chi tiết, nút Dùng)
		U.kho_open()
		U._kho_tab(2)
		return
	for it in _items():
		if it.k == k:
			var s: String = it.d
			if float(it.left) >= 0.0:
				s += " Còn " + left_txt(float(it.left)) + "."
			U.tre_help(String(it.n), s)
			U._layout()
			return

class Ring extends "res://ui/box.gd":   # vòng: nền kem, viền tre mờ, cung vàng đậm chạy theo thời gian còn lại, hình ở giữa
	var tex: Texture2D = null
	var fr := 1.0
	func _draw() -> void:
		var r := size.x * 0.5
		var c := Vector2(r, r)
		var w := maxf(1.5, r * 0.16)
		draw_circle(c + Vector2(0, w * 0.4), r, Color(0, 0, 0, 0.18))   # bóng
		draw_circle(c, r, Color("#fff8e2"))
		draw_arc(c, r - w * 0.5, 0.0, TAU, 40, Color(0.69, 0.54, 0.29, 0.35), w, true)
		if fr > 0.0:
			draw_arc(c, r - w * 0.5, -PI * 0.5, -PI * 0.5 + TAU * fr, 40, Color("#c98a0a"), w, true)
		if tex != null:
			var s := (r - w) * 1.6
			draw_texture_rect(tex, Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), false)
