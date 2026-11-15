extends RefCounted
# Bảng CÀI ĐẶT chép từ bản web (#pn-set trong #pov, "Cài đặt và hướng dẫn"; nút ? là dt()/K() mở Re.pop trepop).
# Số đo lấy từ chính bản web: res://ui/snap/set.json (bảng), set_rs.json (nút Chơi lại đã bấm 1 lần),
# set_pop.json (hộp giải thích). Bỏ 3 mục đo/thử của web: Nền card đồ hoạ (thử), Đo độ mượt, Xem thử cây mới.
# Toàn màn hình: toan_man.gd (cả trang lên toàn màn, không dùng toàn màn của Godot).
# Giá trị lưu theo máy ở G.cfg (user://caidat.json), như localStorage nong-trai-* của web.

const Snap = preload("res://ui/snap.gd")
const Box = preload("res://ui/box.gd")
const Css = preload("res://ui/css.gd")
const TM = preload("res://logic/toan_man.gd")

var HMAX := 281.0          # .pbody scrollHeight - clientHeight của web (trừ mục Chuyển động đã bỏ)
# nút trong từng nhóm, theo thứ tự trái qua phải: [khoá G.cfg, các giá trị]
const SEGS := {"#fsSeg": ["fs", [1, 0]], "#aSeg": ["a", [1, 0]], "#muSeg": ["mu", [1, 0]], "#qSeg": ["q", [0, 1, 2]],
	"#dSeg": ["d", ["real", "fast"]], "#xSeg": ["d", ["sang", "trua", "chieu", "dem"]], "#sSeg": ["s", ["auto", "0", "1", "2", "3"]],
	"#wSeg": ["w", ["auto", "nang", "mua", "rao", "giong", "han"]]}
const HINT := "Chạm ô đất trống để chọn giống gieo, ô khô để tưới, ô chín để thu hoạch, hoặc vuốt qua nhiều ô để làm cả loạt. Nông sản trong kho cũng là hạt giống: nhớ chừa lại để gieo tiếp. Lên cấp mở thêm giống mới. Con giống mua ở Chợ phiên, chợ nổi sáng sớm. Chạm nút Xây dựng để mua cây, nhà, đồ trang trí."
const T_SEA := ["Mùa xuân", "Mùa hạ", "Mùa thu", "Mùa khô"]

var U
var G
var on := false
var T := {}
var box: Control = null
var ids := {}
var pn: Control = null
var _bsig := ""
var pn0 := Vector2.ZERO
var scroll := 0.0
var drag = null
var armed := 0.0
var _tm := false           # toàn màn hình lúc dựng bảng (Esc / vuốt thoát thì dựng lại)
var _tm_t := 0.0

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
	# Link 11-13: chuyển động luôn bật trên mọi máy, bỏ mục Chuyển động: chỗ đó thành hàng Xem giờ (4 nút của Ngày và đêm);
	# Ngày và đêm còn Giờ thật / Nhanh (2 nút như Toàn màn hình); thêm hàng Thời tiết (5 nút như Mùa) dưới Mùa
	var pnd := _fid(T.pov, "pn-set")
	var dS := _fid(T.pov, "dSeg")
	var fsS := _fid(T.pov, "fsSeg")
	var four: Array = dS.kids.duplicate(true)
	for j in 2:
		var bb: Dictionary = dS.kids[j]
		Snap._move(bb, Vector2(float(fsS.kids[j].r[0]) - float(bb.r[0]), 0))
		bb.r[2] = fsS.kids[j].r[2]
		_lbl(bb, ["Giờ thật", "Nhanh"][j])
	dS.kids = dS.kids.slice(0, 2)
	var mS := _fid(T.pov, "mSeg")
	var mrow := _row_of(pnd, "mSeg")
	for j in 4:
		var bb: Dictionary = four[j]
		Snap._move(bb, Vector2(0, float(mS.r[1]) - float(bb.r[1])))
		_lbl(bb, ["Sáng sớm", "Trưa", "Hoàng hôn", "Đêm"][j])
	mS.kids = four
	mS.id = "xSeg"
	_title(mrow, "Xem giờ")
	# Tài khoản: thêm hàng 2 nút dưới tên: Đăng nhập Google (trang: __ntc.login) | Nhập giftcode (trang: hộp nhập mã);
	# hai nút nổi giữa màn của trang (#ntc, #ntgb) bỏ, gom vô đây
	var ac := _fid(pnd, "acct")
	var ar := Snap.find(ac, "acctrow")
	var gr: Dictionary = fsS.duplicate(true)
	gr.id = "acSeg"
	var gy := float(ar.r[1]) + float(ar.r[3]) + 7.5
	Snap._move(gr, Vector2(0, gy - float(gr.r[1])))
	_lbl(gr.kids[0], "Đăng nhập Google")
	_lbl(gr.kids[1], "Nhập giftcode")
	var ga := float(gr.r[3]) + 7.5
	ac.kids.append(gr)
	ac.r[3] = float(ac.r[3]) + ga
	for k in pnd.kids:
		if float(k.r[1]) > float(ac.r[1]) + 1.0:
			Snap._move(k, Vector2(0, ga))
	pnd.r[3] = float(pnd.r[3]) + ga
	Snap._move(T.armed, Vector2(0, ga))
	HMAX += ga
	var srow := _row_of(pnd, "sSeg")
	var st := float(mrow.r[1]) - float(_row_of(pnd, "dSeg").r[1])   # bước giữa hai hàng
	var wrow: Dictionary = srow.duplicate(true)
	Snap._move(wrow, Vector2(0, st))
	var wS := _fid(wrow, "sSeg")
	wS.id = "wSeg"
	# 6 nút (thêm Mưa rào): 2 hàng 3 nút, rộng bằng nhau trong khung nhóm
	var WL := ["Tự động", "Nắng đẹp", "Mưa dầm", "Mưa rào", "Giông bão", "Nắng hạn"]
	var b0: Dictionary = wS.kids[0]
	var bh := float(b0.r[3])
	var bw := (float(wS.r[2]) - 2.0 * 4.5) / 3.0
	var wk := []
	for j in WL.size():
		var bb: Dictionary = b0.duplicate(true)
		Snap._move(bb, Vector2(float(wS.r[0]) + (j % 3) * (bw + 4.5) - float(bb.r[0]), float(wS.r[1]) + (j / 3) * (bh + 4.5) - float(bb.r[1])))
		bb.r[2] = bw
		_lbl(bb, WL[j])
		wk.append(bb)
	wS.kids = wk
	var wex := bh + 4.5   # hàng nút thứ hai
	wS.r[3] = float(wS.r[3]) + wex
	wrow.r[3] = float(wrow.r[3]) + wex
	_title(wrow, "Thời tiết")
	var y0 := float(srow.r[1])
	for k in pnd.kids:
		if float(k.r[1]) > y0:
			Snap._move(k, Vector2(0, st + wex))
	pnd.kids.insert(pnd.kids.find(srow) + 1, wrow)
	pnd.r[3] = float(pnd.r[3]) + st + wex
	Snap._move(T.armed, Vector2(0, st + wex))
	HMAX += st + wex
	# nút đang chọn / chưa chọn: lấy css từ nhóm Toàn màn hình (Bật chưa chọn, Tắt đang chọn)
	var fs := _fid(T.pov, "fsSeg")
	T.off = fs.kids[0].css
	T.on = fs.kids[1].css

static func _row_of(pn: Dictionary, seg: String) -> Dictionary:   # .qset chứa nhóm nút seg
	for k in pn.kids:
		if not _fid(k, seg).is_empty():
			return k
	return {}

static func _lbl(b: Dictionary, t: String) -> void:   # chữ nút, giữa nút
	var fs := Css.px(String(b.css.get("font-size", "15px"))) * float(b.get("z", 1.0))
	var w: float = Box.text_w(t, fs, int(String(b.css.get("font-weight", "400"))))
	b.text = t
	var tr: Array = b.get("tr", b.r)
	b.tr = [float(b.r[0]) + (float(b.r[2]) - w) * 0.5, tr[1], w, tr[3]]

static func _title(row: Dictionary, t: String) -> void:   # chữ đầu hàng, bỏ nút ?
	var b: Dictionary = row.kids[0]
	b.text = t
	b.kids = []
	if b.has("tr"):
		b.tr = [b.tr[0], b.tr[1], Box.text_w(t, Css.px(String(b.css.get("font-size", "15px"))) * float(b.get("z", 1.0)), int(String(b.css.get("font-weight", "700")))) + 1.0, b.tr[3]]

static func _fid(n: Dictionary, id: String) -> Dictionary:
	if n.get("id", "") == id:
		return n
	for k in n.get("kids", []):
		var f := _fid(k, id)
		if not f.is_empty():
			return f
	return {}

func _val(k: String):
	if k == "fs":
		return 1 if _tm else 0
	return G.cfg[k]

# ------------------------------------------------------------------ mở / dựng
func open() -> void:   # zc("set") -> Al("set")
	U.close_all()
	scroll = 0.0
	on = true
	_build()

func _build() -> void:
	_tm = TM.dang_bat()
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
	var ac := _acct()   # tên / trạng thái lưu mạng, nút đăng nhập
	_ac_sig = JSON.stringify(ac)
	var an := _fid(n, "acctName")
	if not an.is_empty():
		an.text = String(ac.t)
		an.tr = [an.tr[0], an.tr[1], Box.text_w(String(ac.t), Css.px(String(an.css.get("font-size", "15px"))) * float(an.get("z", 1.0)), int(String(an.css.get("font-weight", "400")))) + 1.0, an.tr[3]]
		an.r = [an.r[0], an.r[1], maxf(float(an.r[2]), float(an.tr[2])), an.r[3]]
	var acs := _fid(n, "acSeg")
	if not acs.is_empty():
		_lbl(acs.kids[0], String(ac.b))
		acs.kids[0].css = (T.on if ac.out else T.off).duplicate()
		acs.kids[1].css = T.off.duplicate()
	var sk := JSON.stringify(n)   # bảng y hệt lần dựng trước (mở lại, chưa đổi gì): hiện lại bảng cũ, khỏi dựng
	if sk == _bsig and box != null and is_instance_valid(box):
		if not box.visible:
			box.visible = true
			U.root.move_child(box, -1)
			U.anchors.append([box, 0.5, 0.5])
		pn = ids.get("#pn-set")
		_scroll_to(scroll)
		U._layout()
		return
	_bsig = sk
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
	# nút ? theo thứ tự: Tài khoản, Toàn màn hình, Chất lượng hình, Ngày và đêm, Mùa, Cách chơi nhanh
	var qs: Array = U._qall(box, "treq", [])
	var keys := ["acct", "fs", "q", "d", "s", "hint"]
	for j in mini(qs.size(), keys.size()):
		var kk: String = keys[j]
		U._click(qs[j], func(): help(kk), "scale")
	U._click(ids.get("#reset"), reset_tap, "down")
	var acb = ids.get("#acSeg")
	if acb != null:
		var L2: Array = U._buttons(acb, [])
		L2.sort_custom(func(a, b): return a.r.position.x < b.r.position.x)
		if L2.size() >= 2:
			U._click(L2[0], _login, "scale94")
			U._click(L2[1], _gift, "scale94")
	U._layout()

# ------------------------------------------------------------------ tài khoản (trang: window.__ntc), giftcode (window.__ntgopen)
var _ac_sig := ""
var _ac_t := 0.0

func _acct() -> Dictionary:
	var st := "web"
	var nm := ""
	var msg := ""
	if OS.has_feature("web"):
		var r = JavaScriptBridge.eval("JSON.stringify(window.__ntc?{st:__ntc.st,name:__ntc.name,msg:__ntc.msg||''}:null)", true)
		var o = JSON.parse_string(str(r)) if r != null else null
		if o is Dictionary:
			st = String(o.st)
			nm = String(o.name)
			msg = String(o.msg)
	match st:
		"in":
			return {"t": "Đã nối · " + nm + " (làng lưu lên mạng)", "b": "Đã đăng nhập", "out": false}
		"out":
			return {"t": "Chưa đăng nhập: làng chỉ lưu trên máy này", "b": "Đăng nhập Google", "out": true}
		"kick":
			return {"t": "Đang chơi ở máy khác", "b": "Đã đăng nhập", "out": false}
		"loading":
			return {"t": "Đang tải…", "b": "Đăng nhập Google", "out": false}
	return {"t": msg.replace("☁ ", "") if msg != "" else "Không nối được máy chủ lưu", "b": "Đăng nhập Google", "out": false}

func _login() -> void:
	if not OS.has_feature("web"):
		return
	if String(JavaScriptBridge.eval("window.__ntc?__ntc.st:''", true)) == "out":
		JavaScriptBridge.eval("window.__ntc.login()", true)

func _gift() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.__ntgopen&&window.__ntgopen()", true)

func close() -> void:   # Zh
	on = false
	armed = 0.0
	pop_close()
	if box != null and is_instance_valid(box):   # cất bảng (ẩn), mở lại hiện ngay
		U.anchors.erase(U._anchor_of(box))
		box.visible = false
	pn = null

func _scroll_to(s: float) -> void:
	scroll = clampf(s, 0.0, HMAX)
	if pn != null:
		U._move(pn, pn0 - Vector2(0, scroll))

# ------------------------------------------------------------------ chọn
func pick(k: String, v) -> void:
	if k == "fs":   # bật / tắt ngay lúc bấm; trình duyệt đổi xong thì step thấy và dựng lại
		if int(v) == 1 and not _tm:
			if not TM.bat():
				G.toast.emit("Trình duyệt này không cho bật toàn màn hình. Mở trang game bằng Chrome rồi bấm lại.")
			_tm_t = 1.0
		elif int(v) == 0 and _tm:
			TM.tat()
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
			return ["Tài khoản", "Đăng nhập Google để lưu làng lên mạng và chơi tiếp trên máy khác. Mỗi tài khoản chơi ở một máy một lúc. Nhập giftcode để nhận quà."]
		"fs":
			return ["Toàn màn hình", "Ẩn thanh trình duyệt cho cảnh rộng hơn. Bấm Esc hoặc chọn Tắt để thoát."]
		"q":
			return ["Chất lượng hình", "Nếu máy nóng hoặc nhanh hết pin thì chọn Tiết kiệm. Máy mạnh thì chọn Nét."]
		"d":
			return ["Ngày và đêm", "Giờ thật: tối từ 19:30 đến 5:30 theo đồng hồ máy. Nhanh: 1 phút ngoài đời bằng 1 giờ trong làng. Xem giờ: làng đứng ở sáng sớm, trưa, hoàng hôn hoặc đêm."]
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
	U.tre_help(tx[0], tx[1])

func pop_close() -> void:
	U.tre_help_close()

# ------------------------------------------------------------------ cuộn, giờ
func input(e: InputEvent) -> bool:
	if not on or pn == null or U.help_pop != null:
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
	if on:
		if _tm_t > 0.0:
			_tm_t -= dt
			if _tm_t <= 0.0 and TM.bi_tu_choi():
				G.toast.emit("Trình duyệt không cho bật toàn màn hình lúc này. Bấm lại nút Bật thử lần nữa.")
		if TM.dang_bat() != _tm:
			_build()
		_ac_t -= dt
		if _ac_t <= 0.0:   # đăng nhập xong / lưu xong: đổi chữ tài khoản
			_ac_t = 1.0
			if JSON.stringify(_acct()) != _ac_sig:
				_build()
	if armed > 0.0:
		armed -= dt
		if armed <= 0.0:
			armed = 0.0
			if on:
				_build()
