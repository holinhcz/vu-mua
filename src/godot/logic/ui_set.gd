extends RefCounted
# Bảng CÀI ĐẶT chép từ bản web (#pn-set trong #pov, "Cài đặt và hướng dẫn"; nút ? là dt()/K() mở Re.pop trepop).
# Số đo lấy từ chính bản web: res://ui/snap/set.json (bảng), set_rs.json (nút Chơi lại đã bấm 1 lần),
# set_pop.json (hộp giải thích). Bỏ 3 mục đo/thử của web: Nền card đồ hoạ (thử), Đo độ mượt, Xem thử cây mới.
# Giá trị lưu theo máy ở G.cfg (user://caidat.json), như localStorage nong-trai-* của web.

const Snap = preload("res://ui/snap.gd")
const Box = preload("res://ui/box.gd")
const Css = preload("res://ui/css.gd")

var HMAX := 281.0          # .pbody scrollHeight - clientHeight của web (trừ mục Chuyển động đã bỏ)
# nút trong từng nhóm, theo thứ tự trái qua phải: [khoá G.cfg, các giá trị]
const SEGS := {"#fsSeg": ["fs", [1, 0]], "#aSeg": ["a", [1, 0]], "#muSeg": ["mu", [1, 0]], "#qSeg": ["q", [0, 1, 2]],
	"#dSeg": ["d", ["real", "fast", "day", "night"]], "#sSeg": ["s", ["auto", "0", "1", "2", "3"]]}
const HINT := "Chạm ô đất trống để chọn giống gieo, ô khô để tưới, ô chín để thu hoạch, hoặc vuốt qua nhiều ô để làm cả loạt. Nông sản trong kho cũng là hạt giống: nhớ chừa lại để gieo tiếp. Lên cấp mở thêm giống mới. Con giống mua ở Chợ phiên, chợ nổi sáng sớm. Chạm nút Xây dựng để mua cây, nhà, đồ trang trí."
const T_SEA := ["Mùa xuân", "Mùa hạ", "Mùa thu", "Mùa khô"]

var U
var G
var on := false
var T := {}
var box: Control = null
var ids := {}
var pn: Control = null
var pn0 := Vector2.ZERO
var scroll := 0.0
var drag = null
var armed := 0.0
var pop: Control = null
var _fs_want := -1
var _fs_t := 0.0

func _init(ui) -> void:
	U = ui
	G = ui.G
	T.pov = Snap.load_snap("set")["#pov"][0]
	var rs: Dictionary = Snap.load_snap("set_rs")["#pov"][0]
	T.armed = _fid(rs, "reset")
	# nút "Bấm lần nữa…" chụp lúc đã cuộn: đưa về toạ độ chưa cuộn
	var pn_rs := _fid(rs, "pn-set")
	var pn_0 := _fid(T.pov, "pn-set")
	T.armed = T.armed.duplicate(true)
	Snap._move(T.armed, Vector2(0, float(pn_0.r[1]) - float(pn_rs.r[1])))
	T.pop = Snap.load_snap("set_pop")[".u2pop"][0]
	# Link 11-13: chuyển động luôn bật trên mọi máy, bỏ mục Chuyển động; các mục dưới dồn lên
	var d := _drop_qset(T.pov, "mSeg")
	Snap._move(T.armed, Vector2(0, -d))
	HMAX -= d
	# nút đang chọn / chưa chọn: lấy css từ nhóm Toàn màn hình (Bật chưa chọn, Tắt đang chọn)
	var fs := _fid(T.pov, "fsSeg")
	T.off = fs.kids[0].css
	T.on = fs.kids[1].css

static func _drop_qset(root: Dictionary, seg: String) -> float:
	var pn := _fid(root, "pn-set")
	var L: Array = pn.kids
	for j in L.size():
		if not _fid(L[j], seg).is_empty():
			var d: float = float(L[j + 1].r[1]) - float(L[j].r[1])
			var y: float = float(L[j].r[1])
			L.remove_at(j)
			for k in L:
				if float(k.r[1]) > y:
					Snap._move(k, Vector2(0, -d))
			pn.r = [pn.r[0], pn.r[1], pn.r[2], float(pn.r[3]) - d]
			return d
	return 0.0

static func _fid(n: Dictionary, id: String) -> Dictionary:
	if n.get("id", "") == id:
		return n
	for k in n.get("kids", []):
		var f := _fid(k, id)
		if not f.is_empty():
			return f
	return {}

func _fs_on() -> bool:
	var m := DisplayServer.window_get_mode()
	return m == DisplayServer.WINDOW_MODE_FULLSCREEN or m == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN

func _val(k: String):
	if k == "fs":
		return 1 if _fs_on() else 0
	return G.cfg[k]

# ------------------------------------------------------------------ mở / dựng
func open() -> void:   # zc("set") -> Al("set")
	U.close_all()
	scroll = 0.0
	on = true
	_build()

func _build() -> void:
	var n: Dictionary = T.pov.duplicate(true)
	for sid in SEGS:
		var sg := _fid(n, sid.substr(1))
		var k: String = SEGS[sid][0]
		var vals: Array = SEGS[sid][1]
		var cur = _val(k)
		for j in mini(vals.size(), sg.kids.size()):
			var b: Dictionary = sg.kids[j]
			b.css = (T.on if str(vals[j]) == str(cur) else T.off).duplicate()
	if armed > 0.0:
		var pn_n := _fid(n, "pn-set")
		var L: Array = pn_n.kids
		for j in L.size():
			if L[j].get("id", "") == "reset":
				L[j] = T.armed.duplicate(true)
	var old := box
	ids = {}
	box = U._build(n, ids)
	U.root.add_child(box)
	if old != null:
		U.anchors.erase(U._anchor_of(old))
		old.queue_free()
	U.anchors.append([box, 0.5, 0.5])
	U._click(ids.get("#pClose"), close, "scale")
	var bk = ids.get(".pbk")
	if bk != null:
		U._stop(bk)
		bk.gui_input.connect(func(e): if U._is_tap_down(e): close())
	var win = ids.get(".pwin")
	if win != null:
		U._stop(win)
	var body = ids.get(".pbody")
	if body != null:
		body._kids.clip_contents = true   # overflow: hidden auto (cuộn trong khung)
	pn = ids.get("#pn-set")
	pn0 = pn.r.position
	_scroll_to(scroll)
	for sid in SEGS:
		var sg = ids.get(sid)
		if sg == null:
			continue
		var L: Array = U._buttons(sg, [])
		# _buttons trả về không theo thứ tự trái qua phải (nút đang chọn của snap nằm cuối: Mùa "Theo lịch" ra sau "Đông",
		# nên bấm Hạ lại chọn Xuân); xếp theo vị trí để nút j luôn là giá trị j
		L.sort_custom(func(a, b): return a.r.position.x < b.r.position.x)
		var vals: Array = SEGS[sid][1]
		for j in mini(vals.size(), L.size()):
			var k: String = SEGS[sid][0]
			var v = vals[j]
			U._click(L[j], func(): pick(k, v), "scale94")
	# nút ? theo thứ tự: Tài khoản, Toàn màn hình, Chất lượng hình, Ngày và đêm, Chuyển động, Mùa, Cách chơi nhanh
	var qs: Array = U._qall(box, "treq", [])
	var keys := ["acct", "fs", "q", "d", "s", "hint"]
	for j in mini(qs.size(), keys.size()):
		var kk: String = keys[j]
		U._click(qs[j], func(): help(kk), "scale")
	U._click(ids.get("#reset"), reset_tap, "down")
	U._layout()

func close() -> void:   # Zh
	on = false
	armed = 0.0
	pop_close()
	if box != null:
		U.anchors.erase(U._anchor_of(box))
		box.queue_free()
		box = null
	pn = null

func _scroll_to(s: float) -> void:
	scroll = clampf(s, 0.0, HMAX)
	if pn != null:
		U._move(pn, pn0 - Vector2(0, scroll))

# ------------------------------------------------------------------ chọn
func pick(k: String, v) -> void:
	if k == "fs":   # #fsSeg -> #fsBtn
		if (int(v) == 1) != _fs_on():
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if int(v) == 1 else DisplayServer.WINDOW_MODE_WINDOWED)
			_fs_want = int(v)
			_fs_t = 0.4
		_build()
		return
	if str(G.cfg[k]) == str(v):
		return
	G.cfg_set(k, v)
	if k == "mu":   # PN()
		G.toast.emit("Đã bật nhạc đờn ca tài tử và tiếng rao." if int(v) == 1 else "Đã tắt nhạc nền.")
	elif k == "a" and int(v) == 1:
		G.vib(12)
	_build()

func reset_tap() -> void:   # #reset: bấm 1 lần đổi chữ đỏ 4 giây, bấm lần 2 trong lúc đó thì xoá hết
	if armed > 0.0:
		armed = 0.0
		G.reset_game()
		G.toast.emit("Đã bắt đầu một nông trại mới.")
		_build()
		return
	armed = 4.0
	_build()

# ------------------------------------------------------------------ hộp giải thích (Re.pop trepop)
func _help_text(k: String) -> Array:
	match k:
		"acct":
			return ["Tài khoản", "Mở game trong ứng dụng Claude (đã đăng nhập) để lưu tiến trình theo tài khoản và chơi tiếp trên máy khác. Hiện chỉ lưu trên máy này."]
		"fs":
			return ["Toàn màn hình", "Ẩn thanh trình duyệt cho cảnh rộng hơn."]
		"q":
			return ["Chất lượng hình", "Nếu máy nóng hoặc nhanh hết pin thì chọn Tiết kiệm. Máy mạnh thì chọn Nét."]
		"d":
			return ["Ngày và đêm", "Giờ thật: tối từ 19:30 đến 5:30 theo đồng hồ máy. Nhanh: 1 phút ngoài đời bằng 1 giờ trong làng."]
		"m":
			return ["Chuyển động", "Máy này đang tắt hiệu ứng chuyển động. Chọn Bật để con vật đi lại, cây lay, lá rơi." if G.rm_dev else "Con vật đi lại, cây lay, lá rơi, bướm bay."]
		"s":
			return ["Mùa", "Mỗi mùa 7 ngày, 4 mùa là một tháng 28 ngày. Cây hợp mùa lớn nhanh hơn 4%. " + _sea_now()]
	return ["Cách chơi nhanh", HINT]

func _sea_now() -> String:   # fE: #seaNow
	var t := posmod(G.day(), 28)
	var i: int = G.season()
	var auto: bool = G.cfg.s == "auto"
	var a := []
	for c in G.SEA[i]:
		a.append(G.item_name(c).to_lower())
	var hm: String = a[0] if a.size() == 1 else ", ".join(a.slice(0, a.size() - 1)) + " và " + a[a.size() - 1]
	return "Hôm nay: " + T_SEA[i] + (", ngày " + str(t % 7 + 1) + "/7 (ngày " + str(t + 1) + "/28 của tháng)" if auto else " (đang giữ cố định)") + ". Hợp mùa: " + hm + "."

func help(k: String) -> void:
	var tx := _help_text(k)
	var n: Dictionary = T.pop.duplicate(true)
	var pc := Snap.find(n, "u2pc")
	var hb: Dictionary = Snap.find(n, "u2ph")
	for c in hb.kids:
		if c.tag == "b":
			c.text = tx[0]
			c.erase("tr")
	var bx := Snap.find(n, "u2box")
	var p: Dictionary = bx.kids[0]
	var lh := Css.px(p.css.get("line-height", "21px"))
	var fs: float = U._fsz(p)
	var fw := int(p.css.get("font-weight", "500"))
	var l0 := int(round(float(p.r[3]) / lh))
	var l1: int = U._nlines(tx[1], fs, fw, float(p.r[2]))
	p.text = tx[1]
	p.erase("tr")
	var d := (l1 - l0) * lh
	p.r = [p.r[0], p.r[1], p.r[2], float(p.r[3]) + d]
	bx.r = [bx.r[0], bx.r[1], bx.r[2], float(bx.r[3]) + d]
	pc.r = [pc.r[0], pc.r[1], pc.r[2], float(pc.r[3]) + d]
	# hộp giữa màn (flex center)
	var dy := (float(n.r[3]) - float(pc.r[3])) / 2.0 - float(pc.r[1])
	Snap._move(pc, Vector2(0, dy))
	# lớp tối thành lớp riêng phủ kín màn thật, hộp nằm giữa
	var bk: Dictionary = n.duplicate()
	bk.kids = []
	bk.css = bk.css.duplicate()
	bk.css["z-index"] = "auto"
	bk.css["position"] = "absolute"
	pc.css["position"] = "relative"   # hộp vẽ sau lớp tối
	hb.css["border-radius"] = "22px 22px 0px 0px"   # .u2pc overflow hidden bo góc đầu hộp
	var top := {"tag": "div", "id": "", "cls": "", "z": n.get("z", 1.0), "css": {}, "r": n.r, "kids": [bk, pc]}
	pop_close()
	var pid := {}
	pop = U._build(top, pid)
	U.root.add_child(pop)
	U.anchors.append([pop, 0.5, 0.5])
	U._stop(pop)
	var bkb = pid.get(".u2pop")
	if bkb != null:
		U._stop(bkb)
		bkb.gui_input.connect(func(e): if U._is_tap_down(e): pop_close())
	var pcb = pid.get(".u2pc")
	if pcb != null:
		U._stop(pcb)
	U._click(pid.get(".u2px"), pop_close, "scale")
	U._layout()

func pop_close() -> void:
	if pop != null:
		U.anchors.erase(U._anchor_of(pop))
		pop.queue_free()
		pop = null

# ------------------------------------------------------------------ cuộn, giờ
func input(e: InputEvent) -> bool:
	if not on or pn == null or pop != null:
		return false
	var pos := Vector2.ZERO
	if e is InputEventMouseButton and e.pressed and (e.button_index == MOUSE_BUTTON_WHEEL_UP or e.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		_scroll_to(scroll + (-40.0 if e.button_index == MOUSE_BUTTON_WHEEL_UP else 40.0))
		return true
	if e is InputEventScreenTouch or e is InputEventMouseButton:
		if e is InputEventMouseButton and e.button_index != MOUSE_BUTTON_LEFT:
			return false
		pos = e.position / Css.K
		if e.pressed:
			var body: Control = ids.get(".pbody")
			var gr := Rect2(body.get_global_rect().position / Css.K, body.r.size)
			drag = {"y0": pos.y, "s0": scroll, "moved": false} if gr.has_point(pos) else null
		else:
			drag = null
	elif (e is InputEventScreenDrag or e is InputEventMouseMotion) and drag != null:
		pos = e.position / Css.K
		var d: float = pos.y - drag.y0
		if absf(d) > 6.0:
			drag.moved = true
		if drag.moved:
			_scroll_to(drag.s0 - d)
	return false

func step(dt: float) -> void:
	if armed > 0.0:
		armed -= dt
		if armed <= 0.0:
			armed = 0.0
			if on:
				_build()
	if _fs_t > 0.0:
		_fs_t -= dt
		if _fs_t <= 0.0:
			if _fs_want == 1 and not _fs_on():   # cw()
				G.toast.emit("Ứng dụng đang mở game không cho bật toàn màn hình. Mở trang game bằng trình duyệt (Chrome) rồi bấm nút này, hoặc xoay ngang điện thoại.")
			_fs_want = -1
			if on:
				_build()
