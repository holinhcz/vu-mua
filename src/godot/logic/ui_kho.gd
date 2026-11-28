extends RefCounted
# KHO bản web: nút sức chứa .khst trong bảng Kho (số món/sức chứa, sao), hộp "Nâng sao kho" (m$, Re.pop u2gold),
# hộp "Kho đầy rồi!" (lL .kfov, thêm nút nâng kho), hộp "Nâng sớm" bằng sen đỏ (zF .nglkov).
# Số đo lấy từ chính bản web, mỗi trạng thái một bản chụp:
#   kup_ok (2★ đủ cấp, đủ đồ), k2_no (2★ đủ cấp, thiếu), kup_lock (2★ chưa đủ cấp, nâng sớm được),
#   k3_ok / k3_no / kup_no (từ 3★: 4 ô giá), k_hard (thiếu quá 8 cấp: 🔒), kup_max (10★)
#   kfov (có nút Nâng kho), kfov3 (💎 Nâng kho sớm), kfov2 (không nút nâng), kns_ok / kns_poor (nâng sớm).

const Snap = preload("res://ui/snap.gd")
const Box = preload("res://ui/box.gd")
const Css = preload("res://ui/css.gd")
const Qty = preload("res://logic/qty.gd")
const UB = preload("res://logic/ui_bang.gd")

var U
var G
var T := {}
var pop: Control = null      # (cũ) hộp Nâng sao kho: nay là bảng U.kupp, luôn null
var mat_svg := {}            # vật liệu -> svg
var star_on := ""
var star_off := ""
var chip_css := {}           # "ok"/"no" (vật liệu), "xok"/"xno" (xu): css ô + css chữ b
var bar_col := {"": "rgb(222, 64, 76)", "warn": "rgb(246, 111, 39)", "full": "rgb(160, 18, 30)"}

func _init(ui) -> void:
	U = ui
	G = ui.G
	for k in ["kup_lock", "kup_max", "k3_no"]:   # (11-28) chỉ lấy hình sao + kiểu ô (ui_sao dùng _chip)
		T[k] = Snap.load_snap(k)[".u2pop"][0]
	# hình vật liệu nâng kho (ván, đinh, gạch): hình món ui/svg/mat
	for m in G.KHO_MAT:
		mat_svg[m] = FileAccess.get_file_as_string("res://ui/svg/mat/" + String(m) + ".svg")
	var st: Array = Snap.find(T.kup_max, "stars").kids
	star_on = st[0].svg
	star_off = Snap.find(T.kup_lock, "stars").kids[9].svg
	var lk: Array = Snap.find(T.kup_lock, "need").kids
	chip_css.ok = lk[1]
	chip_css.no = lk[2]
	chip_css.xok = lk[0]
	chip_css.xno = Snap.find(T.k3_no, "need").kids[0]

static func _plain_css(c: Dictionary) -> Dictionary:
	var o := c.duplicate()
	o["background-color"] = "rgba(0, 0, 0, 0)"
	o["background-image"] = "none"
	o["box-shadow"] = "none"
	o["border-radius"] = "0px"
	for s in ["top", "right", "bottom", "left"]:
		o["border-" + s] = "0px none rgb(0, 0, 0)"
		o["padding-" + s] = "0px"
	o["filter"] = "none"
	o["position"] = "static"
	o["display"] = "inline"
	return o

func _mix(n: Dictionary, old_l: String, new_l: String, new_r: String, cx: float) -> void:
	# n: chữ = trái + phải, kid[0] = hình ở giữa. Đo khoảng hở hai bên hình từ bản chụp, xếp lại giữa cx.
	var ic: Dictionary = n.kids[0]
	var tr: Array = n.get("tr", n.r)
	var old_r: String = String(n.text).substr(old_l.length())
	var gl: float = float(ic.r[0]) - float(tr[0]) - U._tw(n, old_l)
	var gr: float = float(tr[0]) + float(tr[2]) - float(ic.r[0]) - float(ic.r[2]) - (U._tw(n, old_r) if old_r != "" else 0.0)
	if old_r == "":
		gr = gl
	var wl: float = U._tw(n, new_l)
	var wr: float = U._tw(n, new_r) if new_r != "" else 0.0
	var iw: float = float(ic.r[2])
	var tot: float = wl + gl + iw + (gr + wr if new_r != "" else 0.0)
	var x := cx - tot * 0.5
	n.text = new_l
	n.tr = [x, float(tr[1]), wl + 0.5, float(tr[3])]
	Snap._move(ic, Vector2(x + wl + gl - float(ic.r[0]), 0))
	var kids := [ic]
	if new_r != "":
		var sp := {"tag": "span", "id": "", "cls": "", "z": n.get("z", 1.0), "css": _plain_css(n.css), "kids": [],
			"text": new_r, "r": [x + wl + gl + iw + gr, float(tr[1]), wr + 0.5, float(tr[3])]}
		sp.tr = sp.r.duplicate()
		kids.append(sp)
	n.kids = kids

static func _kid(n: Dictionary, tag: String) -> Dictionary:
	for k in n.get("kids", []):
		if k.tag == tag:
			return k
	return {}

func _ctext(n: Dictionary, s: String) -> void:
	var cx: float = float(n.r[0]) + float(n.r[2]) * 0.5
	U._set_t(n, s, cx - U._tw(n, s) * 0.5)

func _chip(c: Dictionary, kind: String, ok: bool, have: int, need: int, svg: String) -> Dictionary:
	# Q4/pJ: ô xu "[xu] 1.500", ô vật liệu "[hình] có/cần": khuôn chung qty.gd (bản 291), rộng theo chữ; xếp hàng bằng Qty.row
	var src: Dictionary = chip_css[("x" if kind == "xu" else "") + ("ok" if ok else "no")]
	var o: Dictionary = c.duplicate(true)
	o.cls = src.cls
	o.css = src.css
	var b := Snap.find(o, "", "b")
	var sp: Dictionary = _kid(o, "span")
	var ic: Dictionary = o.kids[0]
	if kind != "xu":
		Snap.find(o, "", "svg").svg = svg
	var s: String = G.fmt_n(need) if kind == "xu" else Qty.text(have, need)
	b.css = Qty.css(Snap.find(src, "", "b").css, ok)
	sp.css = Qty.css(sp.css, ok)
	sp.text = ""
	var w: float = U._tw(b, s)
	var cw: float = Qty.chip_w(w)
	var x0: float = float(o.r[0])
	var cy: float = float(o.r[1]) + Qty.H * 0.5
	o.r = [x0, o.r[1], cw, Qty.H]
	var ix: float = x0 + (cw - (Qty.ICON + Qty.GAP + w)) * 0.5
	ic.r = [ix, cy - Qty.ICON * 0.5, Qty.ICON, Qty.ICON]
	var bx: float = ix + Qty.ICON + Qty.GAP
	b.text = s
	b.r = [bx, cy - 9.0, w + 0.5, 18.0]
	b.tr = [bx, cy - 9.0 + Qty.DY, w + 0.5, 18.0]
	sp.r = b.r.duplicate()
	sp.tr = b.r.duplicate()
	return o

# ------------------------------------------------------------------ nút sức chứa trong bảng Kho
func sync_panel(ids: Dictionary, n: int, cap: int) -> void:
	var l := mini(100, int(round(float(n) / maxf(1.0, cap) * 100.0)))
	var c := "full" if n >= cap else ("warn" if l >= 85 else "")
	var bar = ids.get(".kcbar")
	var st0 = ids.get(".khst")
	if bar != null and st0 != null:   # (bản 299) thanh sức chứa dừng trước nút sao (nút nở sang trái khi số dài: 165/200)
		if not bar.has_meta("gap"):
			bar.set_meta("gap", st0.r.position.x - bar.r.end.x)
		var bw: float = st0.r.position.x - float(bar.get_meta("gap")) - bar.r.position.x
		if absf(bw - bar.r.size.x) > 0.01 and bw > 20.0:
			bar.place(Rect2(bar.r.position, Vector2(bw, bar.r.size.y)))
	if bar != null and bar.kids().size() > 0:
		var fi: Control = bar.kids()[0]
		fi.place(Rect2(fi.r.position, Vector2(bar.r.size.x * l / 100.0, fi.r.size.y)))
		var sn: Dictionary = fi.get_meta("snap", {})
		if not sn.is_empty() and fi.get_meta("kc", "?") != c:
			fi.set_meta("kc", c)
			var cs: Dictionary = sn.css.duplicate()
			cs["background-color"] = bar_col[c]
			fi.style(Snap.css_of({"css": cs}), fi.z)
			fi.place(fi.r)
	var st = ids.get(".khst")
	if st == null:
		return
	var cp: Control = U._q(st, "khcap")
	var sn2: Control = U._q(st, "khsn")
	var s1: String = G.fmt_n(n) + "/" + str(cap)
	var s2 := str(G.kho_star())
	if st.get_meta("ks", "") == s1 + "|" + s2:
		return
	st.set_meta("ks", s1 + "|" + s2)
	# (bản 299) xếp lại cả nút từ đầu mỗi lần số đổi: đệm trái = đệm phải như bản web (12 / khoảng 5), mép phải giữ chỗ,
	# nút nở sang trái; thanh sức chứa bên trái dừng trước nút (trước đây cộng dồn phần chênh nên lệch dần, chữ sát mép)
	if cp == null or sn2 == null or cp.texts.is_empty() or sn2.texts.is_empty():
		return
	if not st.has_meta("r0"):
		st.set_meta("r0", st.r)
	var r0: Rect2 = st.get_meta("r0")
	var t0: Dictionary = cp.texts[0]
	var t1: Dictionary = sn2.texts[0]
	U._txt(cp, s1)
	U._txt(sn2, s2)
	var pad: float = cp.r.position.x if not st.has_meta("pad") else float(st.get_meta("pad"))
	st.set_meta("pad", pad)
	var gap := 5.0
	var w1: float = Box.text_w(s1, t0.size, t0.w)
	var w2: float = Box.text_w(s2, t1.size, t1.w)
	var ic: Control = null
	for k in st.kids():
		if k != cp and k != sn2:
			ic = k
	var wi: float = ic.r.size.x if ic != null else 0.0
	var tot: float = pad + w1 + gap + wi + gap + w2 + pad
	st.place(Rect2(Vector2(r0.end.x - tot, st.r.position.y), Vector2(tot, st.r.size.y)))
	cp.place(Rect2(Vector2(pad, cp.r.position.y), Vector2(w1, cp.r.size.y)))
	if ic != null:
		ic.place(Rect2(Vector2(pad + w1 + gap, ic.r.position.y), ic.r.size))
	sn2.place(Rect2(Vector2(pad + w1 + gap + wi + gap, sn2.r.position.y), Vector2(w2, sn2.r.size.y)))
	for t in [t0, t1]:
		t.rect = Rect2(Vector2(0, t.rect.position.y), Vector2(maxf(t.rect.size.x, w1 if t == t0 else w2), t.rect.size.y))
	cp.redraw()
	sn2.redraw()
	if bar != null and bar.has_meta("gap"):
		var bw2: float = st.r.position.x - float(bar.get_meta("gap")) - bar.r.position.x
		if bw2 > 20.0:
			bar.place(Rect2(bar.r.position, Vector2(bw2, bar.r.size.y)))
			if bar.kids().size() > 0:
				var fi2: Control = bar.kids()[0]
				fi2.place(Rect2(fi2.r.position, Vector2(bw2 * l / 100.0, fi2.r.size.y)))

# lớp tối là một lớp riêng phủ kín màn thật (U._cover), hộp nằm giữa (như ui_set.help)
func _show(n: Dictionary, box_cls: String, ids: Dictionary, on_close: Callable) -> Control:
	if not Snap.find(Snap.find(n, box_cls), "u2tre").is_empty():
		UB.tre_apply(n, box_cls)   # (bản 293) hộp nổi nào cũng khung ngoài của Kho (nẹp tre, hoa, nền giấy)
	var bx := Snap.find(n, box_cls)
	var bk: Dictionary = n.duplicate()
	bk.kids = []
	bk.css = bk.css.duplicate()
	bk.css["z-index"] = "auto"
	bk.css["position"] = "absolute"
	var keep := []
	for k in n.kids:
		if k == bx or not Snap.find(k, box_cls).is_empty():
			keep.append(k)
	for k in keep:
		k.css = k.css.duplicate()
		k.css["position"] = "relative"
	var top := {"tag": "div", "id": "", "cls": "", "z": n.get("z", 1.0), "css": {}, "r": n.r, "kids": [bk] + keep}
	var b: Control = U._build(top, ids)
	U.root.add_child(b)
	U.anchors.append([b, 0.5, 0.5])
	var first: Control = b.kids()[0] if b.kids().size() > 0 else null
	if first != null:
		U._stop(first)
		U.tap_close(first, on_close)
	var bb = ids.get("." + box_cls)
	if bb != null:
		U._stop(bb)
	return b

# ------------------------------------------------------------------ hộp Nâng sao kho (m$)
func kup():   # (11-28) bảng nâng sao kho / nâng sớm trên khung chung (ui_kup.gd)
	if U.kupp == null:
		U.kupp = load("res://logic/ui_kup.gd").new(U, self)
	return U.kupp

func open() -> void:
	G.g.kbOpen = false
	kup().open_up()

func close() -> void:
	if U.kupp != null and U.kupp.on and U.kupp.kind == "up":
		U.kupp.close()

func _sig() -> String:
	return "|".join([G.kho_star(), int(G.g.coins / 50), G.mat_n("van"), G.mat_n("dinh"), G.mat_n("gach"), G.lv(), int(G.g.get("ngoc", 0)), int(G.g.get("khoB", 0))])

func up() -> void:   # mp (bản web có lớp bọc: thiếu cấp thì mở hộp nâng sớm)
	var a: int = G.kho_star()
	if a >= 10:
		return
	var nd: Dictionary = G.kho_need(a + 1)
	if G.lv() < int(nd.lv):
		if G.early_ok(int(nd.lv)):
			ns_open()
		else:
			U.say("Cần cấp " + str(nd.lv) + ". Chỉ nâng sớm được khi thiếu tối đa " + str(G.KHO_SA) + " cấp.")
		return
	if not G.can_pay(nd):   # vá L1 cho mp: đủ cấp mà thiếu đồ -> "Nâng sao còn thiếu:" bù bằng sen đỏ
		var mats := []
		for m in nd.m:
			var d: int = int(m[1]) - G.mat_n(m[0])
			if d > 0:
				mats.append([m[0], d])
		U._lack_open([], "Nâng sao còn thiếu:", func():
			G.kho_up()
			open(), maxi(0, int(nd.xu) - int(G.g.coins)), mats)
		return
	G.kho_up()

# ------------------------------------------------------------------ hộp Nâng sớm (zF): bảng khung chung ui_kup.gd kiểu "ns"
func ns_on() -> bool:   # hộp nâng sớm đang mở
	return U.kupp != null and U.kupp.on and U.kupp.kind == "ns"

func ns_close() -> void:
	if ns_on():
		U.kupp.close()

func ns_open() -> void:   # mp bọc: zF({t: "kho lên N★", nd, fee: V9(CA[N], lv), extra, go: mp})
	var a: int = G.kho_star()
	var nd: Dictionary = G.kho_need(a + 1)
	ns_show({"t": "kho lên " + str(a + 1) + "★", "nd": nd, "fee": G.KHO_CA[a + 1] * G.early_lv(int(nd.lv)),
		"extra": " Kho chứa được " + str(G.KHO_VP[a + 1] + int(G.g.get("khoB", 0))) + " món.",
		"go": G.kho_up, "done": open})

func ns_show(sp: Dictionary) -> void:   # zF (cả nâng sao ô ruộng / chuồng ui_sao.gd dùng)
	kup().open_ns(sp)

func _xn(b: Dictionary, s: String) -> void:
	# "×n" đỏ ở góc phải trên ô
	var br: float = float(b.r[0]) + float(b.r[2])
	b.erase("::before")
	var w: float = U._tw(b, s)
	b.text = s
	b.r = [br - w, b.r[1], w + 0.5, b.r[3]]
	b.tr = [br - w, b.get("tr", b.r)[1], w + 0.5, b.get("tr", b.r)[3]]

# ------------------------------------------------------------------ hộp Kho đầy (lL)
func full(cnt: int, cap: int) -> void:   # (11-28) Kho đầy: bảng khung chung ui_kup.gd kiểu "kf"
	if kf_on() or (U.bdp != null and U.bdp.mode != "off"):
		return
	G.g.kfpop = G._now_ms()
	kup().open_kf(cnt, cap)

func kf_on() -> bool:
	return U.kupp != null and U.kupp.on and U.kupp.kind == "kf"

func kf_close() -> void:
	if kf_on():
		U.kupp.close()
