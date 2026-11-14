extends "res://logic/ui_bang.gd"
# HỘP NỔI KHUNG TRE (.raceov.pcov > .rbox.pcbox bản web: Người làm thuê, Hụi làng, ...): khung chung với Kho (ui_bang.gd).
# Hộp giữa màn, cao theo nội dung (tối đa BOX_MAX, dư thì cuộn trong thân), nút × góc trên, bấm ra ngoài thì đóng.
# Khối trong thân xếp dọc, lề trái 25 so với khung lớn; "gap" của khối là khoảng cách phía trên nó (khối đầu: lề trên thân).
# Mẫu: ui/snap/hr.json (hộp trống), hui_tab.json (thẻ .tt, .vl-sec, p.note, ul.kh-gb dùng chung).

var PB := {}                # .raceov
var PT := {}                # khối mẫu chung
const BODY_TOP := 39.0      # từ mép trên .rbox tới thân
const BODY_BOT := 16.5
const BOX_MAX := 592.0      # .rbox cao tối đa (màn 610, chừa 9 trên dưới)

func _init(ui) -> void:
	super(ui)
	PB = Snap.load_snap("hr")["#pov"][0]
	PT = Snap.load_snap("hui_tab")

func _pop(blocks: Array) -> void:   # dựng hộp: khối xếp dọc trong #hrBody (gap = khoảng trên mỗi khối), hộp cao theo nội dung rồi cuộn
	var n := _cl(PB)
	var rb := _find(n, "rbox")
	var vt := _find(n, "hrbody")
	var top: float = float(blocks[0].get("gap", 0.0)) if blocks.size() else 0.0
	var ch := 0.0
	for i in blocks.size():
		if i:
			ch += float(blocks[i].get("gap", 6.0))
		ch += float(blocks[i].r[3])
		blocks[i].dx = 25.0 + float(blocks[i].get("ddx", 0.0))   # ddx: khối lệch khỏi lề (hàng tab tre)
	var bh := minf(top + ch, BOX_MAX - BODY_TOP - BODY_BOT)
	var H := BODY_TOP + bh + BODY_BOT
	_mv(rb, float(rb.r[0]), (610.0 - H) * 0.5)
	rb.r[3] = H
	vt.r[3] = bh
	rb.kids.append(tre_frame(float(rb.r[0]), float(rb.r[1]), float(rb.r[2]), H))
	_show(_ovl(n), vt, blocks, top)
	U._click(ids.get(".tre-x"), close, "scale")
	var ov = ids.get(".raceov")
	if ov != null:
		U._stop(ov)
		ov.gui_input.connect(_ov_tap.bind(ov))
	var bx = ids.get(".rbox")
	if bx != null:
		U._stop(bx)
	U._layout()

func _ov_tap(e: InputEvent, ov: Control) -> void:   # bấm ra ngoài hộp thì đóng (kx)
	var bx = ids.get(".rbox")
	if U._is_tap_down(e) and bx != null and not bx.get_global_rect().has_point(ov.global_position + e.position):
		close()


# ------------------------------------------------------------------ khối dùng chung
func _sec_p(t: String, q := "") -> Dictionary:   # .vl-sec: <b> [+ nút ? (treq) hiện lời giải thích]
	var c := _cl(PT.sec_q if q != "" else PT.sec)
	var b: Dictionary = c.kids[0]
	var tw := _tw(b, t)
	b.text = t
	b.tr = [b.r[0], b.tr[1] if b.has("tr") else b.r[1], tw, b.tr[3] if b.has("tr") else b.r[3]]
	if q != "":
		var qb: Dictionary = b.kids[0]
		_mv(qb, float(b.r[0]) + tw + 6.0, float(qb.r[1]))
		qb.act = U.tre_help.bind(t, q)
	return c

# .tt (.got): bên trái <b> (runs) + <small>, bên phải một nút [chữ, chính?, bật, act] hoặc không
func _tt_p(got: bool, bruns: Array, small: String, btn = null) -> Dictionary:
	var c := _cl(PT.tt_got if got else PT.tt)
	var lf: Dictionary = c.kids[0]
	var bt: Dictionary = c.kids[1] if c.kids.size() > 1 else {}
	var x := float(c.r[0]) + 9.0
	var y0 := float(c.r[1])
	var W0 := float(c.r[2]) - 18.0
	var bw := 0.0
	if btn != null:
		bt = _cl(PT.btn_p if btn[1] and btn[2] else PT.tt_plain.kids[1])
		bw = _tw(bt, String(btn[0])) + _px(bt, "padding-left") + _px(bt, "padding-right") + 2.0
	var lw := W0 - ((bw + 6.0) if btn != null else 0.0)
	var b: Dictionary = lf.kids[0]
	var hs_sty: Dictionary = b.kids[0] if b.get("kids", []).size() else b
	var bs := _cl(b)
	bs.erase("kids")
	var sm: Dictionary = lf.kids[1]
	var hb := _put(b, bruns.map(func(z): return _r(String(z[0]), hs_sty if z[1] else bs)), "left", lw)
	var hs := _put(sm, [_r(small, _cl(sm))], "left", lw)
	var ch := hb + 0.2 + hs
	var H := maxf(ch, float(bt.r[3]) if btn != null else 0.0) + 18.0
	var cy := y0 + (H - ch) * 0.5
	b.r = [x, cy, lw, hb]
	_flow_to(b, x, cy)
	sm.r = [x, cy + hb + 0.2, lw, hs]
	_flow_to(sm, x, cy + hb + 0.2)
	lf.r = [x, cy, lw, ch]
	lf.kids = [b, sm]
	c.r[3] = H
	c.kids = [lf]
	if btn != null:
		var bx := x + W0 - bw
		_mv(bt, bx, y0 + (H - float(bt.r[3])) * 0.5)
		bt.r[2] = bw
		var tw := _tw(bt, String(btn[0]))
		bt.text = btn[0]
		bt.tr = [bx + (bw - tw) * 0.5, float(bt.r[1]) + (float(bt.r[3]) - float(bt.tr[3])) * 0.5, tw, bt.tr[3]]
		_act(bt, btn[3], btn[2])
		c.kids.append(bt)
	return c

func _flow_to(n: Dictionary, x: float, y: float) -> void:   # dời mẩu chữ đã xếp về (x, y)
	var k: Array = n.get("kids", [])
	if k.is_empty():
		return
	var dx := x - float(k[0].r[0])
	var dy := y - float(k[0].r[1])
	for p in k:
		Snap._move(p, Vector2(dx, dy))

func _ul_p(lines: Array) -> Dictionary:   # ul.kh-gb > li
	var u := _cl(PT.ul)
	var tpl: Dictionary = u.kids[0]
	var x := float(u.r[0])
	var y := float(u.r[1])
	var out := []
	for s in lines:
		var li := _cl(tpl)
		_mv(li, x, y)
		var st := _cl(li)
		st.erase("kids")
		var h := _put(li, [_r(String(s), st)])
		li.r[3] = h + _px(li, "padding-top") + _px(li, "padding-bottom")
		out.append(li)
		y += float(li.r[3]) + 4.5
	u.kids = out
	u.r[3] = y - 4.5 - float(u.r[1])
	return u

var note_open := false
func _note_p(s: String) -> Dictionary:   # p.note.u2cl: gấp 2 dòng + "Xem thêm", bấm thì mở hết
	var p := _cl(PT.note)
	var st := _cl(p)
	st.erase("::after")
	var W0 := float(p.r[2])
	var f := _flow([_r(s, st)], float(p.r[0]), float(p.r[1]), W0, _lh(p))
	p.erase("text")
	p.erase("tr")
	if note_open or f.n <= 2:
		p.erase("::after")
		p.kids = f.kids
		p.r[3] = f.h
	else:
		p.kids = f.kids.filter(func(k): return float(k.r[1]) < float(p.r[1]) + _lh(p) * 1.5)
		p.r[3] = _lh(p) * 2.0
	p.act = _note_tog
	return p

func _note_tog() -> void:
	note_open = not note_open
