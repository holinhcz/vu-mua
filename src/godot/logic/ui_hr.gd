extends "res://logic/ui_bang.gd"
# NGƯỜI LÀM THUÊ (ZD / sm bản web, Sổ làng › Làm thuê): hộp .raceov.pcov > .rbox, mỗi nhà một thẻ .tt (.got khi đang làm):
# tên + tim, việc đang làm, ô chọn việc (select.hrsel), ô chọn giống / món (label.hrlab), nút Ghé nhà; cuối là Cho nghỉ hết.
# Ô chọn của trình duyệt: bấm vô thì xổ danh sách ngay dưới ô (mỗi dòng một lựa chọn), chọn xong thì gập lại.
# Mẫu: ui/snap/hr.json (hộp), hr_tab.json (thẻ). Luật ở w_lang.gd (n4, jq, xd, lm, vg, yx, om, wage).

var W          # w_lang.gd
var HB := {}                # .raceov
var HT := {}                # thẻ mẫu
var dd := ""                # ô chọn đang xổ: "<nhà>|job" / "<nhà>|crop" / "<nhà>|jr"
const BODY_TOP := 39.0      # từ mép trên .rbox tới #hrBody
const BODY_BOT := 16.5
const BOX_MAX := 530.0      # .rbox cao tối đa, còn lại cuộn trong #hrBody
const CHEV := "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\"><path d=\"M5 9l7 7 7-7\" fill=\"none\" stroke=\"#5a3e14\" stroke-width=\"3.4\" stroke-linecap=\"round\" stroke-linejoin=\"round\"/></svg>"

func _init(ui, wl) -> void:
	super(ui)
	W = wl
	HB = Snap.load_snap("hr")["#pov"][0]
	HT = Snap.load_snap("hr_tab")

func open() -> void:   # ZD
	on = true
	dd = ""
	scroll = 0.0
	sig = ""
	_build()

func step(dt: float) -> void:   # sm khi đổi
	if not on:
		return
	_sig_t -= dt
	if _sig_t > 0.0:
		return
	_sig_t = 1.0
	if _sig() != sig:
		_build()

func _sig() -> String:
	var L = G.g.get("lang")
	return JSON.stringify([dd, L.get("fam") if L is Dictionary else null, G.g.coins, W.ut_s().c, W._vr()])

# ------------------------------------------------------------------ dựng
func _build() -> void:
	sig = _sig()
	var n := _cl(HB)
	var rb := _find(n, "rbox")
	var vt := _find(n, "hrbody")
	var blocks := _body()
	var ch := 0.0
	for i in blocks.size():
		if i:
			ch += float(blocks[i].get("gap", 6.0))
		ch += float(blocks[i].r[3])
		blocks[i].dx = 25.0
	var bh := minf(7.5 + ch, BOX_MAX - BODY_TOP - BODY_BOT)
	var H := BODY_TOP + bh + BODY_BOT
	_mv(rb, float(rb.r[0]), (610.0 - H) * 0.5)
	rb.r[3] = H
	vt.r[3] = bh
	rb.kids.append(tre_frame(float(rb.r[0]), float(rb.r[1]), float(rb.r[2]), H))
	_show(n, vt, blocks, 7.5)
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

func _body() -> Array:   # sm
	var out := []
	var L = G.g.get("lang")
	if not (L is Dictionary):
		return out   # p.note: bản web giấu (.u2sub .note{display:none})
	var F: Dictionary = W._r0().fam
	var ks: Array = W._okeys(F)
	var r := 0
	for u in ks:
		if W._tr(F[u].get("job")):
			r += 1
	for u in ks:
		out.append(_tt(u, F[u]))
	if r:
		var j := _cl(HT.jobs)
		var b: Dictionary = j.kids[0]
		b.act = _off
		j.gap = 7.5
		out.append(j)
	return out

func _off() -> void:   # data-hr="off"
	W.hr_off()

func _co(f: String) -> String:   # c(f): tên chỗ làm, chữ thường
	return "ruộng lúa" if f == "ruong" else String(W.CO.get(f, f)).to_lower()

# ------------------------------------------------------------------ thẻ một nhà (.tt)
func _tt(u, s: Dictionary) -> Dictionary:
	var job := String(s.get("job")) if W._tr(s.get("job")) else ""
	var c := _cl(HT.tt_got if job != "" else HT.tt)
	var lf: Dictionary = c.kids[0]
	var gb: Dictionary = c.kids[1]
	var x := float(lf.r[0])
	var y := float(lf.r[1])
	var lw := float(lf.r[2])
	var K: Array = lf.kids
	var b: Dictionary = K[0]
	var hs: Dictionary = b.kids[0]          # span.vl-heart
	var bs := _cl(b)
	bs.erase("kids")
	var hb := _put(b, [_r(String(s.n) + " ", bs), _r(W.e_t(W._i(s.get("tim"))), hs)], "left", lw)
	b.r = [x, y, lw, hb]
	var kids := [b]
	var yy := y + hb + 0.2
	var sm: Dictionary = K[1]
	var t := ("Đang làm: " + _co(job) + " · " + str(W.wage(s)) + " xu/phút") if job != "" else "Đang ở nhà"
	if W._tr(s.get("req")):
		t += " · đang nhờ " + W._r_tx(s.req)
	sm.r = [x, yy, lw, 0.0]
	var h := _put(sm, [_r(t, _cl(sm))], "left", lw)
	sm.r[3] = h
	kids.append(sm)
	yy += h + 4.5
	var sel: Dictionary = K[2]
	yy = _select(kids, sel, _job_opts(u, s, job), job, String(u) + "|job", W.n4.bind(u), x, yy, lw)
	if job == "ruong":
		yy = _labeled(kids, K, "Gieo cây", _crop_opts(), String(s.get("crop", "")), String(u) + "|crop", W.jq.bind(u), x, yy + 4.5, lw)
	elif job != "" and G.xw.sr.has(job):
		var rec: Array = G.xw.sr[job].rec
		var ro := rec.map(func(e): return [String(e), String(W._ae(e).get("name", e)) + ("" if G.xw.has_in(String(e)) else " (thiếu đồ)"), false])
		yy = _labeled(kids, K, "Làm món", ro, String(s.get("jr", "")), String(u) + "|jr", W.xd.bind(u), x, yy + 4.5, lw)
	lf.kids = kids
	var ch := yy - y
	lf.r[3] = ch
	var H := ch + 18.0
	c.r[3] = H
	gb.act = _go.bind(u)
	_mv(gb, float(gb.r[0]), float(c.r[1]) + (H - float(gb.r[3])) * 0.5)
	return c

func _go(u) -> void:   # data-go: đóng, về nhà đó
	close()
	U.vl_open(int(u))

func _job_opts(u, s: Dictionary, job: String) -> Array:   # [[mã, chữ, tắt]]
	var h := [["", "Nghỉ ở nhà", false]]
	var p: Array = W.lm()
	var d := maxi(1, int(ceil(W._gg().size() / 12.0)))
	var full := job != "ruong" and p.size() >= d
	h.append(["ruong", "Làm ruộng" + (" (đủ người)" if full else ""), full])
	var l: Array = G.xw.N0.filter(func(k): return G.xw.built(k) and k != "ruong")
	for v in ["vuon", "chan"] + l:
		var xn: String = W.vg(v)
		var k: bool = xn != "" and job != v
		var M: bool = W.yx(v) if W.E4.has(v) else true
		h.append([v, String(W.CO.get(v, v)) + ((" (" + xn + ")") if k else ("" if M else " (chưa có gì)")), k or (not M and job != v)])
	for o in h:
		if o[0] != "" and job != o[0]:
			o[1] = String(o[1]) + " · " + str(W.om(s, o[0])) + " xu/phút"
	return h

func _crop_opts() -> Array:   # Xq: theo thứ tự giống của web
	var a: Array = W.xq({}).slice(1)
	a.sort_custom(func(p, q): return int(p.i) < int(q.i))
	return [["", "Giữ giống cũ", false]] + a.map(func(o): return [String(o.id), String(o.t), false])

# label.hrlab: chữ nhỏ + ô chọn
func _labeled(kids: Array, K: Array, txt: String, opts: Array, cur: String, key: String, cb: Callable, x: float, y: float, lw: float) -> float:
	var lb: Dictionary = _cl(K[3]) if K.size() > 3 else _cl(HT.tt_got.kids[0].kids[3])
	var ls: Dictionary = lb.kids[0]
	_mv(lb, x, y)
	lb.erase("kids")
	lb.text = txt
	var tw := _tw(lb, txt)
	lb.tr = [x, y + 1.0, tw, 11.0]
	lb.r = [x, y, lw, 15.0]
	kids.append(lb)
	return _select(kids, ls, opts, cur, key, cb, x, y + 15.0, lw)

# select.hrsel: ô đang chọn (+ mũi tên); đang xổ thì thêm từng dòng lựa chọn bên dưới
func _select(kids: Array, tpl: Dictionary, opts: Array, cur: String, key: String, cb: Callable, x: float, y: float, lw: float) -> float:
	var s := _cl(tpl)
	s.erase("kids")
	_mv(s, x, y)
	s.r[2] = lw
	var lab := ""
	for o in opts:
		if String(o[0]) == cur:
			lab = o[1]
	var pl := _px(s, "padding-left")
	var tw := lw - pl * 2.0 - 14.0
	var t := _fit(s, lab, tw)
	var th := _lh(s)
	s.text = t
	s.tr = [x + pl, y + (23.0 - th) * 0.5, _tw(s, t), th]
	s.kids = [{"z": _z(s), "tag": "svg", "id": "", "cls": "", "r": [x + lw - pl - 10.5, y + 6.25, 10.5, 10.5], "css": {"display": "block", "position": "absolute"}, "svg": CHEV}]
	s.act = _dd.bind(key)
	kids.append(s)
	var yy := y + 23.0
	if dd == key:
		for o in opts:
			var r := _cl(tpl)
			r.erase("kids")
			var on: bool = String(o[0]) == cur
			var st := _cl(r)
			_mv(r, x, yy + 3.0)
			r.r[2] = lw
			var f := _flow([_r(("✓ " if on else "") + String(o[1]), st)], x + pl, yy + 3.0 + 4.0, lw - pl * 2.0, _lh(st))
			r.erase("text")
			r.erase("tr")
			r.kids = f.kids
			r.r[3] = f.h + 8.0
			if on:
				r.css["border-top"] = "1.33333px solid rgb(90, 160, 70)"
				r.css["background-color"] = "rgb(236, 246, 228)"
			if o[2]:
				r.css.opacity = "0.55"
			else:
				r.act = _pick.bind(cb, String(o[0]))
			kids.append(r)
			yy += 3.0 + float(r.r[3])
	return yy

func _fit(n: Dictionary, s: String, w: float) -> String:   # cắt chữ cho vừa ô (…)
	if _tw(n, s) <= w:
		return s
	while s.length() > 1 and _tw(n, s + "…") > w:
		s = s.substr(0, s.length() - 1)
	return s.strip_edges() + "…"

func _dd(key: String) -> void:
	dd = "" if dd == key else key

func _pick(cb: Callable, v: String) -> void:   # change: n4 / Jq / XD
	dd = ""
	cb.call(v)
