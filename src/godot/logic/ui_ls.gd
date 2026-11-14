extends "res://logic/ui_bang.gd"
# BẢNG SỔ CÓ TAB (khung chung với Kho, ui_bang.gd): .khseg.lstabs + .lsbody với khối .vlcard (.nvsh, thanh), .vl-sec, .lslist (.lsrow),
# p.lssum, nút .utbig. Dùng cho Uy tín làng (ui_ut.gd), Thiên tai (ui_tn.gd).
# Mẫu: ui/snap/ut.json (khung + tab), ut_tab.json (khối mẫu).

var UB := {}                # #pov
var UT := {}                # khối mẫu

func _init(ui) -> void:
	super(ui)
	UB = Snap.load_snap("ut")["#pov"][0]
	UT = Snap.load_snap("ut_tab")

func _ls_build(L: Array, cur: String, go: Callable, blocks: Array) -> void:   # tab + thân
	var n := _cl(UB)
	_seg_tabs(_find(n, "lstabs"), L, cur, go, {})
	var top := 6.0 if blocks.size() and String(blocks[0].cls).begins_with("vl-sec") else 3.0
	_show(n, _find(n, "lsbody"), blocks, top)
	U._layout()

# ------------------------------------------------------------------ khối dùng chung trong bảng
func _sb() -> Dictionary:   # kiểu chữ small trong .vlcard
	return _tag_kids(UT.card, "small")[0]

func _bb() -> Dictionary:   # kiểu chữ <b> trong small của .vlcard
	return _tag_kids(UT.card, "small")[0].kids[0]

func _sec2(t: String, small := "") -> Dictionary:   # .vl-sec: <b> [+ <small>]
	var c := _cl(UT.sec if small != "" else UT.sec_b)
	var b: Dictionary = c.kids[0]
	var x := float(c.r[0])
	var y := float(c.r[1])
	var W0 := float(c.r[2])
	var hb := _put(b, [_r(t, _cl(b))], "left", W0)
	b.r = [x, y, W0, hb]
	var h := hb
	if small != "":
		var sm: Dictionary = c.kids[1]
		var sy := y + hb + 3.0
		sm.r = [x, sy, W0, 0.0]
		var hs := _put(sm, [_r(small, _cl(sm))], "left", W0)
		sm.r[3] = hs
		h = sy + hs - y
	c.r[3] = h
	return c

func _sum2(runs: Array) -> Dictionary:   # p.lssum: [[chữ, đậm?]]
	var p := _cl(UT.sum)
	var sp := _cl(p)
	sp.erase("kids")
	var sb: Dictionary = p.kids[0]
	var h := _put(p, runs.map(func(z): return _r(String(z[0]), sb if z[1] else sp)))
	p.r[3] = h
	return p

func _bar(tpl: Dictionary, f: float, x: float, y: float, w: float) -> Dictionary:   # .combar.nvbar > i (width %)
	var b := _cl(tpl)
	_mv(b, x, y)
	b.r[2] = w
	b.kids[0].r[2] = w * clampf(f, 0.0, 1.0)
	return b

# .lslist: mỗi dòng {b, s, bar (0..1 | null), right: "done" | "fail" | "" | ["lsg", chữ, âm?] | [nút: chữ, chính?, bật, act], me}
func _rows(rows: Array) -> Dictionary:
	var ls := _cl(UT.list)
	var x := float(ls.r[0])
	var y := float(ls.r[1])
	var W0 := float(ls.r[2])
	var out := []
	for R in rows:
		var c := _cl(UT.row_me if R.get("me", false) else UT.row)
		var nm: Dictionary = c.kids[0]
		var bb: Dictionary = _cl(nm.kids[0])
		var sm: Dictionary = _cl(nm.kids[1])
		var pl := 4.5
		var pr := 6.0
		var rt = R.get("right", "")
		var rn = null      # nút / dấu / số bên phải
		var rw := 0.0
		if rt is Array and rt[0] == "lsg":
			rn = _cl(UT.lsg_neg if rt[2] else UT.lsg)
			rw = _tw(rn, String(rt[1]))
			rn.text = rt[1]
		elif rt is Array:
			rn = _cl(UT.btnp if rt[1] and rt[2] else UT.btn)
			rw = _tw(rn, String(rt[0])) + _px(rn, "padding-left") + _px(rn, "padding-right") + 2.0
			rn.text = rt[0]
			_act(rn, rt[3], rt[2])
		elif rt == "done" or rt == "fail" or rt == "none":
			rn = _cl(UT.done if rt != "fail" else UT.fail)
			rw = 22.5
			if rt == "none":
				rn.text = ""
		var bw := W0 - pl - pr - ((rw + 6.0) if rn != null else 0.0)
		var hb := _put(bb, [_r(String(R.b), _cl(bb))], "left", bw)
		var ch := hb
		var kids := [bb]
		var bar = null
		if R.get("bar") != null:
			bar = _bar(UT.bar, float(R.bar), x + pl, 0.0, bw)
			ch += 1.4 + 6.0
			kids.append(bar)
		var hs := 0.0
		if String(R.get("s", "")) != "":
			hs = _put(sm, [_r(String(R.s), _cl(sm))], "left", bw)
			ch += 1.5 + hs
			kids.append(sm)
		var h := maxf(33.0, ch + 9.0)
		if rn is Dictionary and rt is Array and rt[0] != "lsg":
			h = maxf(h, 36.0)
		var cy := y + (h - ch) * 0.5
		_mv(c, x, y)
		c.r[2] = W0
		c.r[3] = h
		bb.r = [x + pl, cy, bw, hb]
		_flow_at(bb, x + pl, cy)
		var yy := cy + hb
		if bar != null:
			_mv(bar, x + pl, yy + 1.4)
			yy += 1.4 + 6.0
		if hs > 0.0:
			sm.r = [x + pl, yy + 1.5, bw, hs]
			_flow_at(sm, x + pl, yy + 1.5)
		nm.r = [x + pl, cy, bw, ch]
		nm.kids = kids
		nm.erase("text")
		nm.erase("tr")
		var ck := [nm]
		if rn != null:
			var rh := float(rn.r[3])
			var rx := x + W0 - pr - rw
			_mv(rn, rx, y + (h - rh) * 0.5)
			rn.r[2] = rw
			if rn.has("tr"):
				var tw := _tw(rn, String(rn.text))
				rn.tr = [rx + (rw - tw) * 0.5, float(rn.r[1]) + (rh - float(rn.tr[3])) * 0.5, tw, rn.tr[3]]
			ck.append(rn)
		c.kids = ck
		out.append(c)
		y += h + 3.75
	ls.kids = out
	ls.r[3] = maxf(0.0, y - 3.75 - float(ls.r[1]))
	return ls

func _flow_at(n: Dictionary, x: float, y: float) -> void:   # dời mẩu chữ đã xếp trong n về (x, y)
	var k: Array = n.get("kids", [])
	if k.is_empty():
		return
	var dx := x - float(k[0].r[0])
	var dy := y - float(k[0].r[1])
	for p in k:
		p.r[0] = float(p.r[0]) + dx
		p.r[1] = float(p.r[1]) + dy
		if p.has("tr"):
			p.tr[0] = float(p.tr[0]) + dx
			p.tr[1] = float(p.tr[1]) + dy

func _big(t: String, kind: String, ok: bool, cb: Callable) -> Dictionary:   # button.btn.utbig (kind: "primary" | "plain")
	var b := _cl(UT.bigp if kind == "primary" and ok else UT.big)
	var tw := _tw(b, t)
	b.text = t
	b.tr = [float(b.r[0]) + (float(b.r[2]) - tw) * 0.5, b.tr[1], tw, b.tr[3]]
	return _act(b, cb, ok)

func _card_nv(tpl: Dictionary, left: String, right: Array, bar, runs: Array) -> Dictionary:   # .vlcard: .nvsh [+ thanh] + small (chữ có <b>)
	var c := _cl(tpl)
	var x := float(c.r[0]) + _px(c, "padding-left")
	var W0 := float(c.r[2]) - _px(c, "padding-left") - _px(c, "padding-right")
	var y := float(c.r[1]) + _px(c, "padding-top")
	var hd: Dictionary = c.kids[0]
	y += _nvsh(hd, left, right, x, y, W0) + 6.0
	var kids := [hd]
	if bar != null:
		var b := _bar(UT.bar, float(bar), x, y, W0)
		kids.append(b)
		y += 6.0 + 6.0
	var sm: Dictionary = _cl(_sb())
	var sp := _cl(sm)
	sp.erase("kids")
	var sb := _bb()
	sm.r = [x, y, W0, 0.0]
	var h := _put(sm, runs.map(func(z): return _r(String(z[0]), sb if z[1] else sp)), "left", W0)
	sm.r[3] = h
	kids.append(sm)
	y += h
	c.kids = kids
	c.r[3] = y + _px(c, "padding-bottom") - float(c.r[1])
	return c

