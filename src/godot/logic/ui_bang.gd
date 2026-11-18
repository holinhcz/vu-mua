extends RefCounted
# BẢNG chung kiểu web (#pov .pwin: khung tre của Kho, nút X, thân .pbody cuộn được): dựng từ bản chụp DOM của web, chữ dàn lại
# theo nội dung (xuống dòng như trình duyệt), rồi dựng một lần bằng Snap. Bảng nhà dân (ui_vl.gd), bảng Nghề (ui_ng.gd) dùng chung.
# Khối dùng chung: p.note, .vl-sec, .vlcard (_vCH: chữ + ô .need + nút), .need chip, nút có act; thân cuộn (kéo / lăn chuột).
# Cờ trong nút mẫu: act (Callable khi bấm, bấm xong dựng lại), ic (ô hình món: vẽ hình món theo id).

const Snap = preload("res://ui/snap.gd")
const Qty = preload("res://logic/qty.gd")
const Box = preload("res://ui/box.gd")
const Css = preload("res://ui/css.gd")

var U          # ui.gd
var G          # game.gd
var on := false
var box: Control = null
var ids := {}
var sig := ""
var _sig_t := 0.0
var inner: Control = null   # thân cuộn được
var in0 := Vector2.ZERO
const VScroll = preload("res://logic/vscroll.gd")
var sc = VScroll.new()      # (bản 287) cuộn thân bảng: dùng chung vscroll.gd như Kho
var scroll: float:
	get: return sc.s
	set(v): sc.s = v
var hmax: float:
	get: return sc.hmax
	set(v): sc.hmax = v
var B := {}                 # bản chụp #pov của bảng nhà dân (mẫu p.note)
var T := {}                 # khối mẫu chung (ui/snap/vl_tab.json)
var _area := ""             # lớp của vùng thân cuộn (.vltab / .lsbody)

func _init(ui) -> void:
	U = ui
	G = ui.G
	B = Snap.load_snap("vl")["#pov"][0]
	T = Snap.load_snap("vl_tab")

func close() -> void:   # cất bảng (ẩn, giữ khung + khối): mở lại như Kho, chỉ hiện, cái gì đổi mới dựng
	_qe_drop()
	on = false
	sc.drag = null
	if box != null and is_instance_valid(box):
		U.anchors.erase(U._anchor_of(box))
		box.visible = false

func _build() -> void:   # bảng con dựng lại
	pass

func step(_dt: float) -> void:   # bảng con: dựng lại khi đổi
	pass

func busy() -> bool:   # đang kéo cuộn (dọc hoặc hàng chip): ui hoãn step, khỏi dựng lại bảng giữa lúc kéo (giật, khựng)
	return (sc.drag != null and sc.moved()) or (hd != null and hd.moved)

func _barn(id) -> int:   # g.barn[id] || 0
	return int(G.g.barn.get(String(id), 0))

# ------------------------------------------------------------------ đo chữ, xếp chữ
static func _z(n: Dictionary) -> float:
	return float(n.get("z", 1.0))

static func _px(n: Dictionary, k: String) -> float:
	return Css.px(String(n.css.get(k, "0px"))) * _z(n)

static func _fs(n: Dictionary) -> float:
	return Css.px(String(n.css.get("font-size", "15px"))) * _z(n)

static func _fw(n: Dictionary) -> int:
	return int(String(n.css.get("font-weight", "400")))

static func _lh(n: Dictionary) -> float:
	var v := String(n.css.get("line-height", "normal"))
	return Css.px(v) * _z(n) if v.ends_with("px") else _fs(n) * 1.25

static func _tw(n: Dictionary, s: String) -> float:
	return Box.text_w(s, _fs(n), _fw(n))

static func _dw(n: Dictionary, s: String) -> float:   # bề ngang lúc vẽ (Box vẽ ở cỡ chữ làm tròn px): để mẩu chữ nối nhau không lệch
	var q := maxi(1, int(round(_fs(n) * Css.K)))
	return Box._line_w(s, Css.font(_fw(n)), q) / Css.K

static func _cl(n: Dictionary) -> Dictionary:
	return n.duplicate(true)

static func _mv(n: Dictionary, x: float, y: float) -> Dictionary:   # dời n (và con) tới góc (x, y)
	Snap._move(n, Vector2(x - float(n.r[0]), y - float(n.r[1])))
	return n

static func _find(n: Dictionary, cls: String, tag := "") -> Dictionary:
	return Snap.find(n, cls, tag)

static func _tag_kids(n: Dictionary, tag: String) -> Array:
	return n.get("kids", []).filter(func(k): return k.tag == tag)

func _piece(sty: Dictionary, s: String, x: float, y: float, w: float, h: float) -> Dictionary:   # một mẩu chữ (một dòng, một kiểu)
	var c := {"display": "inline", "position": "static", "font-size": sty.css.get("font-size", "15px"), "font-weight": sty.css.get("font-weight", "400"),
		"color": sty.css.get("color", "rgb(0,0,0)"), "text-align": "left", "white-space": "nowrap", "text-shadow": sty.css.get("text-shadow", "none"), "z-index": "auto"}
	return {"z": _z(sty), "tag": "span", "id": "", "cls": "", "r": [x, y, w + 1.0, h], "tr": [x, y, w + 1.0, h], "css": c, "text": s}

# runs = [[chữ, kiểu (nút mẫu)]]; xếp chữ xuống dòng như trình duyệt; trả {kids, h, w, n}
func _flow(runs: Array, x: float, y: float, W0: float, lh: float, al := "left") -> Dictionary:
	var lines := [[]]   # mỗi dòng: [[chữ, kiểu, rộng]]
	var lw := [0.0]
	for r in runs:
		var sty: Dictionary = r[1]
		var sw := _dw(sty, "a a") - _dw(sty, "aa")   # bề ngang khoảng trắng (đo riêng: chữ có trắng ở đuôi đo hụt)
		var words: PackedStringArray = String(r[0]).split(" ")
		for wi in words.size():
			var wd: String = words[wi]
			var cur: Array = lines[-1]
			var sp := wi > 0 and not cur.is_empty()
			var tok := (" " if sp else "") + wd
			var tw := (sw if sp else 0.0) + (_dw(sty, wd) if wd != "" else 0.0)
			if not cur.is_empty() and lw[-1] + tw > W0 + 0.5 and wd != "":
				lines.append([])
				lw.append(0.0)
				cur = lines[-1]
				tok = wd
				tw = _dw(sty, wd)
			if tok == "":
				continue
			if not cur.is_empty() and cur[-1][1] == sty:
				cur[-1][0] += tok
				cur[-1][2] += tw
			else:
				cur.append([tok, sty, tw])
			var s := 0.0
			for p in cur:
				s += p[2]
			lw[-1] = s
	var kids := []
	var mw := 0.0
	for li in lines.size():
		var ww: float = lw[li]
		mw = maxf(mw, ww)
		var px := x + ((W0 - ww) * 0.5 if al == "center" else ((W0 - ww) if al == "right" else 0.0))
		for p in lines[li]:
			kids.append(_piece(p[1], p[0], px, y + li * lh, p[2], lh))
			px += p[2]
	var n := lines.size() if not (lines.size() == 1 and lines[0].is_empty()) else 0
	return {"kids": kids, "h": n * lh, "w": mw, "n": n}

# đặt chữ vào hộp n (bỏ chữ cũ): x, y, rộng lấy từ khung trong (padding); trả chiều cao chữ
func _put(n: Dictionary, runs: Array, al := "left", W0 := -1.0, keep_kids := false) -> float:
	var pl := _px(n, "padding-left")
	var pt := _px(n, "padding-top")
	var pr := _px(n, "padding-right")
	var w := W0 if W0 > 0.0 else float(n.r[2]) - pl - pr
	var f := _flow(runs, float(n.r[0]) + pl, float(n.r[1]) + pt, w, _lh(n), al)
	n.erase("text")
	n.erase("tr")
	n.kids = (n.get("kids", []) if keep_kids else []) + f.kids
	return f.h

func _r(s: String, sty: Dictionary) -> Array:
	return [s, sty]

# ------------------------------------------------------------------ dựng: xếp khối vô vùng thân, dựng, gắn nút
func _show(n: Dictionary, vt: Dictionary, blocks: Array, top := 7.5) -> void:
	# xếp khối dọc: .vl-sec cách khối trên 12, khối sau .vl-sec 4,5, còn lại 6
	var x0 := 16.5
	var y := float(vt.r[1]) + top
	var y0 := y
	var prev := ""
	var kids := []
	for b in blocks:
		b.key = JSON.stringify(b)   # khoá giữ khối (_mount): lấy lúc khối còn ở chỗ mẫu, dời chỗ không làm đổi khoá
		var k := String(b.cls).split(" ")[0]
		if kids.size():
			y += float(b.get("gap", 4.5 if prev == "vl-sec" else (12.0 if k == "vl-sec" else 6.0)))
		_mv(b, x0 + float(b.get("dx", 0.0)), y)
		y += float(b.r[3])
		kids.append(b)
		prev = k
	_mount(n, vt, kids, y0, y - y0 + 7.5, top)

static func _ovl(n: Dictionary) -> Dictionary:   # lớp tối .lvov thành lớp riêng (ui._cover phủ kín màn thật), hộp vẽ trên nó
	var bk := n.duplicate()
	bk.kids = []
	bk.css = bk.css.duplicate()
	bk.css["position"] = "absolute"
	bk.css["z-index"] = "auto"   # lớp tối vẽ trước hộp
	return {"tag": "div", "id": "", "cls": "", "z": n.get("z", 1.0), "css": {}, "r": n.r, "kids": [bk] + n.kids}

# gắn khối đã xếp (kids, tọa độ tuyệt đối) vào vùng cuộn vt: phần cuộn bắt đầu ở y0, cao ch; top = lề trên trước y0.
# GIỮ ĐỒ ĐÃ DỰNG: khung bảng (mọi thứ trừ khối trong thân) chỉ dựng lại khi nó đổi (_shell_key); mỗi khối giữ theo khoá nội
# dung (_pool, khoá lấy lúc khối còn ở chỗ mẫu: "key" do _show đặt), khối không đổi thì gắn lại nút cũ, chỉ dời chỗ. Nút bấm
# đọc việc cần làm lúc bấm (meta "snap".act), nên khối dùng lại vẫn làm đúng việc mới. Trước đây đổi gì cũng xoá cả bảng
# rồi dựng lại hết.
var shell_new := true      # lần _mount vừa rồi có dựng lại khung không (bảng con nối nút khung chỉ khi true)
var _shell_key := ""
var _pool := {}            # khoá khối -> [Control, ids của khối]

func _mount(n: Dictionary, vt: Dictionary, kids: Array, y0: float, ch: float, top := 0.0) -> void:
	var inn := {"z": _z(vt), "tag": "div", "id": "", "cls": "vlin", "r": [vt.r[0], y0, vt.r[2], ch], "css": {"display": "block", "position": "static"}, "kids": []}
	vt.kids = [inn]
	_area = String(vt.cls).split(" ")[0]
	hmax = maxf(0.0, ch + top - float(vt.r[3]))
	scroll = clampf(scroll, 0.0, hmax)
	var sk := JSON.stringify(n)
	shell_new = false
	if box == null or not is_instance_valid(box) or sk != _shell_key:
		_shell_swap(sk)
	elif not box.visible:   # mở lại bảng đã cất
		box.visible = true
		U.root.move_child(box, -1)
		U.anchors.append([box, 0.5, 0.5])
		_vis = true
	if shell_new:
		ids = {}
		box = U._build(n, ids)
		U.root.add_child(box)
		U.anchors.append([box, 0.5, 0.5])
		U._click(ids.get("#pClose"), close, "scale")
		_vis = true
		var bk = ids.get(".pbk")
		if bk != null:
			U._stop(bk)
			U.tap_close(bk, close)
		var win = ids.get(".pwin")
		if win != null:
			U._stop(win)
		var vb: Control = ids.get("." + _area)
		if vb != null:
			vb._kids.clip_contents = true
		_wire(box)
	if U.help_pop != null:   # hộp giải thích (nút ?) luôn nằm trên bảng vừa dựng lại
		U.root.move_child(U.help_pop, -1)
	inner = ids.get(".vlin")
	in0 = inner.r.position if inner != null else Vector2.ZERO
	var io := Vector2(float(inn.r[0]), float(inn.r[1]))
	var used := {}
	for k in kids:
		var key0: String = String(k.get("key", "")) if k.has("key") else JSON.stringify(k)
		var key := key0
		var dup := 1
		while used.has(key):   # hai khối giống hệt: khoá riêng
			dup += 1
			key = key0 + "#" + str(dup)
		used[key] = 1
		var e = _pool.get(key)
		var node: Control = null
		if e != null and is_instance_valid(e[0]):
			node = e[0]
			if node.get_parent() != null and node.get_parent() != inner._kids:
				node.get_parent().remove_child(node)
			_re_act(node, k)
			ids.merge(e[1], true)
		else:
			var bid := {}
			node = U._build(k, bid, io)
			_wire(node)
			ids.merge(bid, true)
			_pool[key] = [node, bid]
		if inner != null and node.get_parent() == null:
			inner.add(node)
		U._move(node, Vector2(float(k.r[0]), float(k.r[1])) - io)
	for key in _pool.keys():   # khối không còn: bỏ
		if not used.has(key):
			var c1 = _pool[key][0]
			if is_instance_valid(c1):
				c1.queue_free()
			_pool.erase(key)
	_scroll_to(scroll)
	_sig_sh[sig] = _shell_key
	if _vis:   # khung mới / vừa hiện lại: canh giữa, thu nhỏ theo màn
		_vis = false
		U._layout()

var _vis := false

# GIỮ KHUNG THEO TAB (như Kho, bản 183): mỗi khung (tab đang chọn, chữ trên khung...) dựng một lần, đổi tab thì cất khung cũ
# (ẩn, giữ cả khối của nó) rồi lấy lại khung đã có; tối đa SH_N khung, quá thì bỏ khung lâu nhất.
const SH_N := 6
var _shells := {}          # khoá khung -> [box, ids, _pool]
var _sh_order := []

var _sig_sh := {}          # sig của bảng -> khoá khung đã dựng đúng trạng thái đó (đổi tab quay lại: lấy ra, khỏi dựng)
var _jump := false         # vừa bấm tab (_seg_tabs)

func _tab_jump(go: Callable, k) -> void:
	_jump = true
	go.call(k)

func _jump_back() -> bool:   # đổi tab về trạng thái đã dựng: chỉ hiện lại khung cất, không tính lại khối
	if not has_method("_sig"):
		return false
	var s: String = call("_sig")
	var sk = _sig_sh.get(s)
	if sk == null or sk == _shell_key or not _shells.has(sk) or not is_instance_valid(_shells[sk][0]):
		return false
	var e: Array = _shells[sk]
	_shell_swap(sk)
	hmax = e[3]
	_area = e[4]
	sig = s
	inner = ids.get(".vlin")
	in0 = inner.r.position if inner != null else Vector2.ZERO
	_scroll_to(e[5])
	if _vis:
		_vis = false
		U._layout()
	return true

func _shell_swap(sk: String) -> void:   # cất khung đang hiện, lấy khung sk (chưa có thì shell_new = true để dựng)
	if box != null and is_instance_valid(box):
		var was := box.visible
		box.visible = false
		U.anchors.erase(U._anchor_of(box))
		_shells[_shell_key] = [box, ids, _pool, hmax, _area, scroll]
		_sh_order.erase(_shell_key)
		_sh_order.append(_shell_key)
		if not was:
			_vis = true
	_shell_key = sk
	var e = _shells.get(sk)
	if e != null and is_instance_valid(e[0]):
		_shells.erase(sk)
		_sh_order.erase(sk)
		box = e[0]
		ids = e[1]
		_pool = e[2]
		box.visible = true
		U.root.move_child(box, -1)
		U.anchors.append([box, 0.5, 0.5])
		_vis = true
	else:
		box = null
		_pool = {}
		shell_new = true
	while _sh_order.size() > SH_N:   # quá nhiều khung cất: bỏ khung lâu nhất (cả khối không gắn)
		var k0: String = _sh_order.pop_front()
		var o = _shells.get(k0)
		_shells.erase(k0)
		if o != null:
			for kk in o[2]:
				var c = o[2][kk][0]
				if is_instance_valid(c) and c.get_parent() == null:
					c.queue_free()
			if is_instance_valid(o[0]):
				o[0].queue_free()

static func _acts(n: Dictionary, out: Array) -> Array:   # các khối có việc bấm, theo thứ tự dựng
	if n.has("act"):
		out.append(n)
	for k in n.get("kids", []):
		_acts(k, out)
	return out

static func _act_nodes(b: Control, out: Array) -> Array:
	if b.get_meta("snap", {}).has("act"):
		out.append(b)
	for k in b.kids():
		_act_nodes(k, out)
	return out

func _re_act(node: Control, k: Dictionary) -> void:   # khối dùng lại: trỏ nút bấm sang việc của bản mới
	var A := _acts(k, [])
	var B := _act_nodes(node, [])
	for q in mini(A.size(), B.size()):
		B[q].set_meta("snap", A[q])

func _seg_tabs(seg: Dictionary, L: Array, cur: String, go: Callable, bd: Dictionary) -> void:   # hàng tab .khseg: L = [[khóa, chữ, chấm?]]
	var K: Array = seg.kids
	var on_t: Dictionary = K[0] if String(K[0].cls).split(" ").has("on") else K[1]
	var off_t: Dictionary = K[1] if on_t == K[0] else K[0]
	var n := L.size()
	# U2TRE.ttFit: thử lần lượt [chia đều?, cỡ chữ, đệm ngang] tới khi chữ tab nào cũng vừa một dòng
	var z0 := _z(off_t)
	var tw0 := []
	for i in n:
		tw0.append(_tw(off_t, String(L[i][1])))
	var fs0 := _px(off_t, "font-size") / z0
	var weq := (305.0 - (n - 1) * 4.5) / n
	var pick := [true, fs0, 8.0]
	for P in [[true, 14.0, 8.0], [true, 14.0, 5.0], [false, 14.0, 8.0], [false, 14.0, 5.0], [false, 13.0, 8.0], [false, 13.0, 5.0], [false, 12.0, 8.0], [false, 12.0, 5.0], [false, 12.0, 3.0]]:
		pick = P
		var sum := (n - 1) * 4.5
		var ok := true
		for i in n:
			var ww: float = float(tw0[i]) * float(P[1]) / fs0 + (float(P[2]) * 2.0 + 7.0) * z0
			sum += ww
			if P[0] and ww > weq:
				ok = false
		if ok and (P[0] or sum <= 305.0):
			break
	var out := []
	var x := 16.5
	for i in n:
		var a: bool = cur == L[i][0]
		var c := _cl(on_t if a else off_t)
		var z := _z(c)
		var tw: float = float(tw0[i]) * float(pick[1]) / fs0
		var w: float = weq if pick[0] else tw + (float(pick[2]) * 2.0 + 7.0) * z
		if float(pick[1]) != fs0:
			c.css["font-size"] = str(pick[1]) + "px"
		_mv(c, x, float(c.r[1]))
		var w0 := float(c.r[2])
		c.r[2] = w
		var af: Dictionary = c.get("::after", {})
		if af.has("w"):
			af.w = str(Css.px(String(af.w)) + (w - w0) / z) + "px"
		c.kids = []
		c.text = L[i][1]
		c.tr = [x + (w - tw) * 0.5, c.tr[1], tw, c.tr[3]]
		c.act = _tab_jump.bind(go, L[i][0])
		if L[i][2] and not bd.is_empty():
			c.css["z-index"] = "3"   # chấm nằm đè lên tab bên cạnh
			var b := _cl(bd)
			_mv(b, x + w - 11.5, float(c.r[1]) - 3.5)
			c.kids = [b]
		out.append(c)
		x += w + 4.5
	seg.kids = out

func _wire(b: Control) -> void:   # nút bấm + hình món theo cờ trong bản dựng
	var n: Dictionary = b.get_meta("snap", {})
	if n.has("act"):
		U._click(b, _on_b.bind(b), "down")
	if n.has("ic"):
		var t: Texture2D = U.item_ic(String(n.ic), float(b.r.size.x) * Css.K)
		if t != null:
			b.pic(t, Rect2(Vector2.ZERO, b.r.size))
	for k in b.kids():
		_wire(k)

func _on_b(b: Control) -> void:   # việc của nút đọc lúc bấm (khối dùng lại có việc mới)
	var n: Dictionary = b.get_meta("snap", {})
	if n.get("act") is Callable:
		_on(n.act)

func _on(cb: Callable) -> void:
	if sc.moved():
		return
	cb.call()
	_redo()

func _act(n: Dictionary, cb: Callable, ok := true) -> Dictionary:
	if ok:
		n.act = cb
		n.css.opacity = "1"
		n.css.filter = "none"
	else:
		n.css.opacity = "0.55"   # :disabled (web còn grayscale 0.6)
	return n

func _ic(n: Dictionary, id: String) -> void:   # ô hình món: bỏ svg chụp, vẽ hình món id
	n.erase("svg")
	n.ic = id
	n.kids = []

func _flush(row: Array, rh: float, out: Array) -> void:   # hàng nút cao bằng nút cao nhất, chữ giữa
	for c in row:
		var dd: float = (rh - float(c.r[3])) * 0.5
		c.r[3] = rh
		for k in c.kids:
			Snap._move(k, Vector2(0, dd))
	out.append_array(row)

func _gap(n: Dictionary, extra: float) -> Dictionary:   # thêm khoảng trên khối (vlops cách vlcv 9)
	Snap._move(n, Vector2(0, extra))
	var w := {"z": _z(n), "tag": "div", "id": "", "cls": "vlgap", "r": [n.r[0], float(n.r[1]) - extra, n.r[2], float(n.r[3]) + extra], "css": {"display": "block", "position": "static"}, "kids": [n]}
	return w

# ------------------------------------------------------------------ khối chung
func _note(runs: Array) -> Dictionary:   # p.note
	var n := _cl(_find(B, "note"))
	var h := _put(n, runs)
	n.r[3] = _px(n, "padding-top") + h + _px(n, "padding-bottom")
	return n

func _nb() -> Dictionary:   # kiểu chữ đậm trong p.note
	return T.tal.kids[-1].kids[0]

func _np() -> Dictionary:   # kiểu chữ thường trong p.note
	return _find(B, "note")

func _sec(t: String, small := "") -> Dictionary:   # .vl-sec: <b> + <small>
	var n := _cl(T.thue.kids[0])
	var b: Dictionary = n.kids[0]
	var s: Dictionary = n.kids[1]
	var hb := _put(b, [_r(t, b)])
	b.r[3] = hb
	if small == "":
		n.kids = [b]
		n.r[3] = hb
		return n
	_mv(s, float(s.r[0]), float(b.r[1]) + hb + 3.0)
	var hs := _put(s, [_r(small, s)])
	s.r[3] = hs
	n.r[3] = float(s.r[1]) + hs - float(n.r[1])
	return n

# nút việc (.btn.vljb): bt = [{b, s, st: "on" | "off" | "dis", act}]; cols cột; tpl: "jobs" | "pick"
func _card(sub_runs: Array, chips: Array, btns: Array) -> Dictionary:
	var n := _cl(T.x_su.kids[4])
	var cl := _find(n, "vlcl")
	var cr := _find(n, "vlcr")
	var sm: Dictionary = _tag_kids(cl, "small")[0]
	var need := _find(cl, "need")
	var x := float(cl.r[0])
	var y := float(cl.r[1])
	var kids := []
	if sub_runs.size():
		_mv(sm, x, y)
		var h := _put(sm, sub_runs)
		sm.r[3] = h
		kids.append(sm)
		y += h
	if chips.size():
		y += 4.5 if kids.size() else 0.0
		var nd := _chips(need, chips, x, y)
		kids.append(nd)
		y += float(nd.r[3])
	cl.kids = kids
	cl.r[3] = y - float(cl.r[1])
	var out := [cl]
	if btns.size():
		y += 6.0
		var bt0: Dictionary = cr.kids[0]
		var bp := _find(T.x_su.kids[2], "primary")
		var bx := float(cl.r[0]) + float(cl.r[2])
		var by := y
		var bl := []
		for b in btns:
			var c := _cl(bp if b[1] else bt0)
			var tw := _tw(c, String(b[0]))
			var bw := tw + _px(c, "padding-left") + _px(c, "padding-right")
			if bx - bw < float(cl.r[0]) - 0.5:
				bx = float(cl.r[0]) + float(cl.r[2])
				by += 34.5
			bx -= bw
			_mv(c, bx, by)
			c.r[2] = bw
			c.text = b[0]
			c.tr = [bx + (bw - tw) * 0.5, c.tr[1], tw, c.tr[3]]
			bx -= 6.0
			_act(c, b[3], b[2])
			bl.append(c)
		cr.kids = bl
		_mv(cr, float(cr.r[0]), y)
		cr.r[3] = by + 30.0 - y
		y = by + 30.0
		out.append(cr)
	n.kids = out
	n.r[3] = y + 7.5 - float(n.r[1])
	return n

# chips: [món, cần] (có = kho) | [món, có, cần] | [món, có, cần, tên hiện]; tok0: mẫu ô đủ (mặc định lấy màu của Kho)
func _chips(need: Dictionary, chips: Array, x: float, y: float, tok0 := {}) -> Dictionary:   # .need: nc(món, cần), ngChip
	var nd := _cl(need)
	var tno: Dictionary = need.kids[0]
	var tok: Dictionary = tok0 if not tok0.is_empty() else _ok_chip(tno)
	var cx := x
	var cy := y
	var out := []
	for z in chips:
		var hv: int = _barn(z[0]) if z.size() < 3 else int(z[1])
		var q: int = int(z[1]) if z.size() < 3 else int(z[2])
		var good := hv >= q
		var c := _cl(tok if good else tno)
		var sv: Dictionary = c.kids[0]
		var sp: Dictionary = c.kids[1]
		var bb: Dictionary = sp.kids[0]
		var s1 := Qty.text(hv, q)   # (bản 291) "có/cần" một khối chữ chung (qty.gd), tên món đi sau
		bb.css = Qty.css(bb.css, good)
		var s2 := " " + (String(z[3]) if z.size() > 3 else String(G.item(z[0]).get("name", z[0])))
		var w1 := _tw(bb, s1)
		var w2 := _tw(sp, s2)
		var pad := float(sp.r[0]) - float(c.r[0])
		var cw := pad + w1 + w2 + 6.0
		if cx > x and cx + cw > x + float(need.r[2]):
			cx = x
			cy += 31.5
		_mv(c, cx, cy)
		c.r[2] = cw
		_ic(sv, String(z[0]))
		var sx := float(c.r[0]) + pad
		bb.r = [sx, bb.r[1], w1, bb.r[3]]
		bb.tr = [sx, bb.tr[1], w1, bb.tr[3]]
		bb.text = s1
		sp.r = [sx, sp.r[1], w1 + w2, sp.r[3]]
		sp.tr = [sx + w1, sp.tr[1], w2, sp.tr[3]]
		sp.text = s2
		out.append(c)
		cx += cw + 4.5
	nd.kids = out
	nd.r = [x, y, nd.r[2], cy + 27.0 - y]
	return nd

func _ok_chip(no: Dictionary) -> Dictionary:   # .chip.ok: lấy màu ô đủ đồ của kho (kup_lock .need)
	if has_meta("okc"):
		return get_meta("okc")
	var c := _cl(no)
	var k: Dictionary = Snap.find(Snap.load_snap("kup_lock")[".u2pop"][0], "need").kids[1]
	for key in ["background-color", "background-image", "box-shadow", "border-top", "border-right", "border-bottom", "border-left", "color"]:
		if k.css.has(key):
			c.css[key] = k.css[key]
	var kb := Snap.find(k, "", "b")
	if not kb.is_empty():
		Snap.find(c, "", "b").css.color = kb.css.color
	c.cls = "chip ok"
	set_meta("okc", c)
	return c

func _csm() -> Dictionary:   # kiểu chữ small trong .vlcard
	return _tag_kids(_find(T.x_su.kids[4], "vlcl"), "small")[0]

func _nvsh(n: Dictionary, left: String, right: Array, x: float, y: float, W0: float) -> float:   # .nvsh: <b>trái</b><span>phải (có <b>)</span>
	var b: Dictionary = n.kids[0]
	var sp: Dictionary = n.kids[1]
	var sb: Dictionary = sp.kids[0] if sp.get("kids", []).size() else b
	var rr := right.map(func(z): return _r(String(z[0]), sb if z[1] else sp))
	var rw := 0.0
	for z in rr:
		rw += _dw(z[1], String(z[0]))
	var fr := _flow(rr, x + W0 - rw, y, rw + 1.0, maxf(_lh(sp), 16.2))
	sp.r = [x + W0 - rw, y, rw, fr.h]
	sp.erase("text")
	sp.erase("tr")
	sp.kids = fr.kids
	var fl := _flow([_r(left, b)], x, y, W0 - rw - 6.0, _lh(b) * 0.75)
	b.r = [x, y, W0 - rw - 6.0, fl.h]
	b.erase("text")
	b.erase("tr")
	b.kids = fl.kids
	var h := maxf(fl.h, fr.h)
	n.r = [x, y, W0, h]
	return h

static var _TRE := {}

# (bản 293) KHUNG TRE CHUNG = khung ngoài của Kho (.pwin trong kho: hai bông hoa, nền giấy vân lá); nẹp tre là ảnh của
# ui/tre.gd (bản 294), Snap.build vẽ cho mọi .u2tre.
# Mọi hộp nổi (nâng sao ruộng / chuồng / xưởng / kho, Điểm danh, 7 ngày...) lấy khung ở đây, không chép khung riêng.
static func _tre_src() -> Dictionary:
	if _TRE.is_empty():
		var w: Dictionary = Snap.find(Snap.load_snap("kho")["#pov"][0], "pwin")
		_TRE = {"win": w, "tre": Snap.find(w, "u2tre"), "hoa": Snap.find(w, "u2hoa"), "body": Snap.find(w, "pbody")}
	return _TRE

static func tre_frame(x: float, y: float, w: float, h: float) -> Dictionary:   # lớp trên: khung tre (ảnh, ui/tre.gd qua Snap) + hoa
	var T: Dictionary = _tre_src()
	var o: Dictionary = T.tre.duplicate(true)
	o.r = [x, y, w, h]
	o.kids = []   # Snap.build thay bằng các mảnh ảnh của ui/tre.gd
	var hoa: Dictionary = T.hoa.duplicate(true)
	hoa.r = [x, y, w, h]
	var h1: Dictionary = hoa.kids[0]   # hoa góc trên trái / dưới phải, cùng chỗ so với mép hộp như ở Kho (dời cả hình bên trong)
	var h2: Dictionary = hoa.kids[1]
	Snap._move(h1, Vector2(x - 15.5 - float(h1.r[0]), y - 20.0 - float(h1.r[1])))
	Snap._move(h2, Vector2(x + w - 37.0 - float(h2.r[0]), y + h - 33.0 - float(h2.r[1])))   # đè góc khung như hoa trên, không che nút
	return {"tag": "div", "id": "", "cls": "trechung", "z": o.get("z", 1.0), "css": {}, "r": [x, y, w, h], "kids": [o, hoa]}

static func tre_bg(x: float, y: float, w: float, h: float) -> Dictionary:   # lớp dưới: nền giấy vân lá của Kho
	var b: Dictionary = _tre_src().body.duplicate(true)
	b.kids = []
	b.r = [x, y, w, h]
	b.css = b.css.duplicate()
	b.css["border-radius"] = "16px"   # = ui/tre.gd R
	return b

static func tre_apply(n: Dictionary, box_cls := "u2pc") -> void:   # hộp nổi chụp từ web (.u2pc + .u2tre dày): đổi sang khung Kho
	var bx := Snap.find(n, box_cls)
	if bx.is_empty():
		return
	var x: float = float(bx.r[0])
	var y: float = float(bx.r[1])
	var w: float = float(bx.r[2])
	var h: float = float(bx.r[3])
	bx.css = tre_box_css(bx.css)
	var kids := [tre_bg(x, y, w, h)]
	for k in bx.kids:
		if not String(k.get("cls", "")).split(" ").has("u2tre"):
			kids.append(k)
	kids.append(tre_frame(x, y, w, h))
	bx.kids = kids

static func tre_box_css(c: Dictionary) -> Dictionary:   # màu nền, bo góc, bóng của hộp = .pwin của Kho
	var o := c.duplicate()
	var wc: Dictionary = _tre_src().win.css
	for k in ["background-color", "box-shadow"]:
		o[k] = wc[k]
	o["border-radius"] = "16px"   # = ui/tre.gd R: nền bo khớp vòng tre
	return o

# ------------------------------------------------------------------ hàng chip .khchips cuộn ngang (scrollLeft)
var chx := 0.0              # khchips.scrollLeft
var hd = null               # đang kéo ngang hàng chip

func _chips_keep(chips: Array, onr: Array, x_end: float, x0 := 16.5, x1 := 321.5) -> void:   # giữ chip đang chọn trong khung (web: scrollLeft += lố + 8)
	if onr[1] > x1 + chx:
		chx += onr[1] - x1 - chx + 6.0
	elif onr[0] < x0 + chx:
		chx -= x0 + chx - onr[0] + 6.0
	chx = clampf(chx, 0.0, maxf(0.0, x_end - x1))
	for c in chips:
		Snap._move(c, Vector2(-chx, 0))

func _chips_drag(e: InputEvent, sel := ".khchips") -> bool:   # kéo ngang hàng chip / tab cuộn; true = đã dùng sự kiện
	var row = ids.get(sel) if box != null else null
	if row == null:
		return false
	if e is InputEventScreenTouch or e is InputEventMouseButton:
		if e is InputEventMouseButton and e.button_index != MOUSE_BUTTON_LEFT:
			return false
		var p: Vector2 = e.position / Css.K
		if e.pressed:
			var gr := Rect2(row.get_global_rect().position / Css.K, row.r.size)
			hd = {"x0": p.x, "s0": chx, "moved": false} if gr.has_point(p) else null
		elif hd != null:
			if hd.moved:
				sig = ""
			hd = null
	elif (e is InputEventScreenDrag or e is InputEventMouseMotion) and hd != null:
		var p: Vector2 = e.position / Css.K
		var d: float = p.x - hd.x0
		if absf(d) > 6.0:
			hd.moved = true
			sc._moved = true   # kéo ngang hàng chip: nhả tay không tính là bấm
		if hd.moved:
			var mx := 0.0
			for c in row.kids():
				mx = maxf(mx, c.r.end.x + chx)
			var nx := clampf(hd.s0 - d, 0.0, maxf(0.0, mx - row.r.size.x))
			for c in row.kids():
				U._move(c, c.r.position - Vector2(nx - chx, 0))
			chx = nx
		return true
	return false

# ------------------------------------------------------------------ ô tìm (input[type=search]): LineEdit nằm đè lên ô chụp, giữ qua các lần dựng lại
var qe: LineEdit = null
var _qe_sel := ""

func _qe_make(sel: String, ph: String, txt: String, cb: Callable) -> void:
	_qe_sel = sel
	if qe == null:
		qe = LineEdit.new()
		qe.placeholder_text = ph
		qe.flat = true
		qe.text = txt
		qe.add_theme_font_override("font", Css.font(500))
		qe.add_theme_font_size_override("font_size", int(round(12.0 * 0.75 * Css.K)))
		qe.add_theme_color_override("font_color", Color8(58, 42, 16))
		qe.add_theme_color_override("font_placeholder_color", Color8(138, 120, 96))
		var sb := StyleBoxEmpty.new()
		for s in ["normal", "focus", "read_only"]:
			qe.add_theme_stylebox_override(s, sb)
		qe.text_changed.connect(func(t: String) -> void:
			cb.call(t)
			if qe != null:
				qe.grab_focus())
		U.root.add_child(qe)
	_qe_place()

func _qe_place() -> void:   # gọi mỗi khung lúc bảng mở (ô có thể cuộn theo thân)
	if qe == null or box == null:
		return
	var inp = ids.get(_qe_sel)
	if inp == null:
		return
	var r: Rect2 = inp.get_global_rect()
	var pad := 9.0 * Css.K
	qe.position = r.position + Vector2(pad, 0)
	qe.size = Vector2(r.size.x - pad * 2.0, r.size.y)
	var vb = ids.get("." + _area) if _area != "" else null
	qe.visible = inp.is_visible_in_tree() and (vb == null or vb.get_global_rect().grow(1.0).encloses(r))
	qe.move_to_front()

func _qe_drop() -> void:
	if qe != null:
		qe.queue_free()
		qe = null

# ------------------------------------------------------------------ cuộn
func _redo() -> void:
	var j := _jump
	_jump = false
	sig = ""
	_sig_t = 0.0
	if not on:
		return
	if j:
		if _jump_back():
			return
	else:   # bấm việc khác (mua, nhận...): trạng thái có thể đổi ngoài sig, khung cất của tab khác không dùng lại nguyên được
		_sig_sh.clear()
	_build()

func _scroll_to(v: float) -> void:
	sc.s = clampf(v, 0.0, sc.hmax)
	if inner != null:
		U._move(inner, in0 - Vector2(0, sc.s))

func input(e: InputEvent) -> bool:
	if not on or inner == null:
		sc.input(e)   # vẫn xoá cờ "vừa kéo" khi chạm xuống
		return false
	var vb: Control = ids.get("." + _area)
	if vb != null and sc.area != vb:
		sc.area = vb
		sc.mover = _scroll_to
	return sc.input(e)
