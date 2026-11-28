extends "res://logic/ui_kbang.gd"
# (11-28) BẢNG CÀI ĐẶT trên khung chung (ui_kbang: khung sen, tiêu đề mục chung, đáy chung), thay bảng chụp web cũ
#   (#pn-set: ô rời, dấu ? dính chữ, khoảng hở lệch, cuối bị cắt). 4 mục: Tài khoản · Hiển thị · Âm thanh · Giờ và thời tiết,
#   rồi Cách chơi nhanh + Chơi lại từ đầu. Mỗi cài đặt một thẻ: tên (chạm ? xem giải thích) + hàng nút chọn (chọn = nút xanh
#   gờ vàng như chip lọc Kho); tên + nút vừa một hàng thì nút nằm bên phải, không vừa thì nút xuống dòng dưới tên.
# Giá trị lưu theo máy ở G.cfg (user://caidat.json). Toàn màn hình: toan_man.gd.

const TM = preload("res://logic/toan_man.gd")
const HINT := "Chạm ô đất trống để chọn giống gieo, ô khô để tưới, ô chín để thu hoạch, hoặc vuốt qua nhiều ô để làm cả loạt. Nông sản trong kho cũng là hạt giống: nhớ chừa lại để gieo tiếp. Lên cấp mở thêm giống mới. Con giống mua ở Chợ phiên, chợ nổi sáng sớm. Chạm nút Xây dựng để mua cây, nhà, đồ trang trí."
const T_SEA := ["Mùa xuân", "Mùa hạ", "Mùa thu", "Mùa khô"]
# mục: [tiêu đề, [[khóa G.cfg, tên, giải thích (khóa help, "" không có), [[giá trị, chữ]]]]]
const MUC := [
	["Hiển thị", [
		["fs", "Toàn màn hình", "fs", [[1, "Bật"], [0, "Tắt"]]],
		["q", "Chất lượng hình", "q", [[0, "Tiết kiệm"], [1, "Cân bằng"], [2, "Nét"]]]]],
	["Âm thanh", [
		["a", "Âm thanh và rung", "", [[1, "Bật"], [0, "Tắt"]]],
		["mu", "Nhạc nền đờn ca tài tử", "", [[1, "Bật"], [0, "Tắt"]]]]],
	["Giờ và thời tiết", [
		["d", "Ngày và đêm", "d", [["real", "Giờ thật"], ["fast", "Nhanh"], ["hold", "Đứng giờ"]]],
		["dx", "Đứng ở", "", [["sang", "Sáng sớm"], ["trua", "Trưa"], ["chieu", "Hoàng hôn"], ["dem", "Đêm"]]],   # chỉ hiện khi chọn Đứng giờ
		["s", "Mùa", "s", [["auto", "Theo lịch"], ["0", "Xuân"], ["1", "Hạ"], ["2", "Thu"], ["3", "Khô"]]],
		["w", "Thời tiết", "", [["auto", "Tự động"], ["nang", "Nắng đẹp"], ["mua", "Mưa dầm"], ["han", "Nắng hạn"]]],
		["*rao", "Mưa rào thử 5 giây", "", []]]]]   # nút việc (không phải lựa chọn giữ)
const HOLD := ["sang", "trua", "chieu", "dem"]
const RH := 24.0   # cao nút chọn

var armed := 0.0
var _tm := false           # toàn màn hình lúc dựng bảng (Esc / vuốt thoát thì dựng lại)
var _tm_t := 0.0

func _val(k: String):
	if k == "fs":
		return 1 if _tm else 0
	if k == "dx":
		return G.cfg.d
	if k == "d" and HOLD.has(String(G.cfg.d)):   # (11-28) 4 giờ đứng gộp vào nút Đứng giờ
		return "hold"
	if k == "w" and G.cfg[k] == "giong":   # cài đặt cũ: giông gộp vô mưa dầm
		return "mua"
	return G.cfg[k]

# ------------------------------------------------------------------ mở / dựng
func open() -> void:   # zc("set") -> Al("set")
	U.close_all()
	on = true
	scroll = 0.0
	sig = ""
	_build()

func _sig() -> String:
	return JSON.stringify([TM.dang_bat(), _acct(), armed > 0.0, G.cfg])

func _build() -> void:
	_tm = TM.dang_bat()
	sig = _sig()
	var sh := _kshell([], "", func(_k): pass)
	var out := []
	var y := 4.0
	# tài khoản
	out.append_array(_hdq(y, "Tài khoản", "acct"))
	y += 26.0 + 6.0
	var ac := _acct()
	var P := _para(X0 + 12.0, y + 9.0, XW - 24.0, String(ac.t), 10.5, 600, SUB)
	var bh := float(P[1]) + 9.0 + 8.0 + 28.0 + 10.0
	out.append(_chip(X0, y, XW, bh, "fut"))
	out.append_array(P[0])
	var by := y + float(P[1]) + 17.0
	var hw := (XW - 24.0 - 6.0) * 0.5
	out.append(_btn(X0 + 12.0, by, hw, 28.0, String(ac.b), _login, "go" if ac.out else "off"))
	out.append(_btn(X0 + 12.0 + hw + 6.0, by, hw, 28.0, "Nhập giftcode", _gift, "plain"))
	y += bh + GG
	# các mục cài đặt
	for m in MUC:
		out.append_array(_hdq(y, String(m[0]), ""))
		y += 26.0 + 6.0
		for r in m[1]:
			if String(r[0]) == "dx" and not HOLD.has(String(G.cfg.d)):
				continue
			if String(r[0]) == "*rao":   # (11-28) mưa rào: nút làm ngay, tách khỏi hàng chọn Thời tiết
				out.append(_chip(X0, y, XW, 40.0, "fut"))
				out.append(_dt(X0 + 12.0, y, 180.0, 40.0, String(r[1]), 12.0, 800, BROWN, "left"))
				out.append(_btn(X0 + XW - 12.0 - 84.0, y + 8.0, 84.0, RH, "Cho mưa", pick.bind("w", "rao"), "plain"))
				y += 40.0 + 6.0
				continue
			var R := _row(y, r)
			out.append_array(R[0])
			y += float(R[1]) + 6.0
		y += GG - 6.0
	# cách chơi nhanh + chơi lại
	out.append_array(_hdq(y, "Cách chơi", ""))
	y += 26.0 + 6.0
	var c := _chip(X0, y, XW, 40.0, "fut")
	out.append(c)
	out.append(_dt(X0 + 12.0, y, 180.0, 40.0, "Cách chơi nhanh", 12.0, 800, BROWN, "left"))
	out.append(_btn(X0 + XW - 12.0 - 84.0, y + 8.0, 84.0, RH, "Xem ›", help.bind("hint"), "plain"))
	y += 40.0 + 6.0
	out.append(_btn(X0, y, XW, 30.0, "Bấm lần nữa để xoá hết làng" if armed > 0.0 else "Chơi lại từ đầu", reset_tap, "red"))
	y += 30.0 + GG
	_kmount(sh[0], sh[1], sh[2], out, y)

func _hdq(y: float, t: String, hk: String) -> Array:   # tiêu đề mục; hk: có nút ? (chip tre nhỏ, cách chữ)
	if hk == "":
		return _hd(y + 5.0, t)
	var L := _hd(y + 5.0, t, "", 28.0)
	var q := _chip(X0 + XW - 22.0, y + 1.0, 22.0, 22.0, "tre", true)
	q.kids = [_dt(X0 + XW - 22.0, y + 1.0, 22.0, 22.0, "?", 12.0, 800, BROWN)]
	q.act = help.bind(hk)
	L.append(q)
	return L

func _row(y: float, r: Array) -> Array:   # thẻ 1 cài đặt: [khối, cao]
	var k := String(r[0])
	var O: Array = r[3]
	var cur = _val(k)
	var need := []
	for o in O:
		need.append(Box.text_w(String(o[1]), 10.5, 800) + 18.0)
	var sw := 6.0 * (O.size() - 1)
	for w in need:
		sw += float(w)
	var tw: float = Box.text_w(String(r[1]), 12.0, 800) + (28.0 if String(r[2]) != "" else 0.0)
	var iw := XW - 24.0
	var one := O.size() <= 3 and tw + 12.0 + maxf(sw, 64.0 * O.size()) <= iw   # một hàng: nút bên phải
	var two := not one and sw > iw   # (11-28) nút không vừa 1 hàng (Thời tiết 5 nút): chia 2 hàng, không cắt chữ
	var h := 40.0 if one else 8.0 + 20.0 + 6.0 + RH + 10.0 + ((RH + 6.0) if two else 0.0)
	var out := [_chip(X0, y, XW, h, "fut")]
	var ly := y if one else y + 8.0
	var lh := 40.0 if one else 20.0
	out.append(_dt(X0 + 12.0, ly, tw, lh, String(r[1]), 12.0, 800, BROWN, "left"))
	if String(r[2]) != "":
		var qx := X0 + 12.0 + Box.text_w(String(r[1]), 12.0, 800) + 6.0
		var qy := ly + (lh - 18.0) * 0.5
		var q := _chip(qx, qy, 18.0, 18.0, "tre", true)
		q.kids = [_dt(qx, qy, 18.0, 18.0, "?", 10.5, 800, BROWN)]
		q.act = help.bind(String(r[2]))
		out.append(q)
	var segw := maxf(sw, 64.0 * O.size()) if one else iw
	var sx := X0 + XW - 12.0 - segw if one else X0 + 12.0
	var sy := y + 8.0 if one else y + 8.0 + 20.0 + 6.0
	var n1 := ceili(O.size() / 2.0) if two else O.size()   # số nút hàng trên
	var W: Array = _flex_w(need.slice(0, n1), segw, 6.0) + (_flex_w(need.slice(n1), segw, 6.0) if two else [])
	for i in O.size():
		if two and i == n1:
			sx = X0 + 12.0
			sy += RH + 6.0
		var o: Array = O[i]
		var cw: float = W[i]
		var b: Dictionary
		if str(o[0]) == str(cur):
			b = _onbtn(sx, sy, cw, RH, "", null)
			b.kids = [_dt(sx, sy, cw, RH, _fitw(String(o[1]), 10.5, 800, cw - 6.0), 10.5, 800, "rgb(255, 255, 255)")]
		else:
			b = _chip(sx, sy, cw, RH, "fut", true)
			b.kids = [_dt(sx, sy, cw, RH, _fitw(String(o[1]), 10.5, 800, cw - 6.0), 10.5, 800, BROWN)]
			b.act = pick.bind("d" if k == "dx" else k, o[0])
		out.append(b)
		sx += cw + 6.0
	return [out, h]

# ------------------------------------------------------------------ tài khoản (trang: window.__ntc), giftcode (window.__ntgopen)
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
	armed = 0.0
	super()

# ------------------------------------------------------------------ chọn
func pick(k: String, v) -> void:
	if sc.moved():
		return   # vừa kéo cuộn, không phải bấm (bản 287)
	if k == "fs":   # bật / tắt ngay lúc bấm; trình duyệt đổi xong thì step thấy và dựng lại
		if int(v) == 1 and not _tm:
			if not TM.bat():
				G.toast.emit("Trình duyệt này không cho bật toàn màn hình. Mở trang game bằng Chrome rồi bấm lại.")
			_tm_t = 1.0
		elif int(v) == 0 and _tm:
			TM.tat()
		return
	if k == "w" and v == "rao":   # Mưa rào: đổ ngay một trận 5 giây (không phải chế độ giữ), nút vẫn ở Tự động
		G.cfg_set("w", "auto")
		G.troi.rao_start()
		_build()
		return
	if k == "d" and str(v) == "hold":   # Đứng giờ: đứng ở sáng sớm (chọn giờ khác ở hàng dưới)
		if HOLD.has(String(G.cfg.d)):
			return
		v = "sang"
	if str(G.cfg[k]) == str(v):
		return
	G.cfg_set(k, v)
	if k == "mu":   # PN()
		G.toast.emit("Đã bật nhạc đờn ca tài tử và tiếng rao." if int(v) == 1 else "Đã tắt nhạc nền.")
	elif k == "a" and int(v) == 1:
		G.vib(12)
	_build()

func reset_tap() -> void:   # bấm 1 lần đổi chữ đỏ 4 giây, bấm lần 2 trong lúc đó thì xoá hết
	if armed > 0.0:
		armed = 0.0
		G.reset_game()
		G.toast.emit("Đã bắt đầu một nông trại mới.")
		_build()
		return
	armed = 4.0
	_build()

# ------------------------------------------------------------------ giải thích (bong bóng chung tại chỗ chạm)
func _help_text(k: String) -> Array:
	match k:
		"acct":
			return ["Tài khoản", "Đăng nhập Google để lưu làng lên mạng và chơi tiếp trên máy khác. Mỗi tài khoản chơi ở một máy một lúc. Nhập giftcode để nhận quà."]
		"fs":
			return ["Toàn màn hình", "Ẩn thanh trình duyệt cho cảnh rộng hơn. Bấm Esc hoặc chọn Tắt để thoát."]
		"q":
			return ["Chất lượng hình", "Nếu máy nóng hoặc nhanh hết pin thì chọn Tiết kiệm. Máy mạnh thì chọn Nét."]
		"d":
			return ["Ngày và đêm", "Giờ thật: tối từ 19:30 đến 5:30 theo đồng hồ máy. Nhanh: 1 phút ngoài đời bằng 1 giờ trong làng. Đứng giờ: làng đứng yên ở sáng sớm, trưa, hoàng hôn hoặc đêm."]
		"s":
			return ["Mùa", "Mỗi mùa 7 ngày, 4 mùa là một tháng 28 ngày. Cây hợp mùa lớn nhanh hơn 4%. " + _sea_now()]
	return ["Cách chơi nhanh", HINT]

func _sea_now() -> String:   # fE: #seaNow
	var t := posmod(G.day(), 28)
	var i: int = G.season()
	var auto: bool = G.cfg.s == "auto"
	var a := []
	for c in G.D.mua[i]:
		a.append(G.item_name(c).to_lower())
	var hm: String = a[0] if a.size() == 1 else ", ".join(a.slice(0, a.size() - 1)) + " và " + a[a.size() - 1]
	return "Hôm nay: " + T_SEA[i] + (", ngày " + str(t % 7 + 1) + "/7 (ngày " + str(t + 1) + "/28 của tháng)" if auto else " (đang giữ cố định)") + ". Hợp mùa: " + hm + "."

func help(k: String) -> void:
	var tx := _help_text(k)
	_dtip(String(tx[1]), "", String(tx[0]))

# ------------------------------------------------------------------ giờ
func step(dt: float) -> void:
	if on and _tm_t > 0.0:
		_tm_t -= dt
		if _tm_t <= 0.0 and TM.bi_tu_choi():
			G.toast.emit("Trình duyệt không cho bật toàn màn hình lúc này. Bấm lại nút Bật thử lần nữa.")
	if armed > 0.0:
		armed -= dt
		if armed <= 0.0:
			armed = 0.0
			if on:
				_build()
	super(dt)
