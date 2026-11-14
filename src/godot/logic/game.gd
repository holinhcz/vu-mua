extends Node
# Luật game Nông Trại Nhỏ chép từ bản web (phiên bản 1794362238-2880): bản lưu, đồng hồ giờ thật, cấp, sức,
# ô ruộng (gieo, tưới, lớn, gặt, sâu, rầy nâu). Không vẽ gì ở đây; farm.gd vẽ, ui.gd làm bảng.
# Số liệu đọc từ res://data/*.json (bộ data Link gửi). Tên biến theo bản web để dễ đối chiếu.

signal changed            # có gì đổi (bảng cần vẽ lại)
signal toast(msg: String)
signal float_text(gx: float, gy: float, msg: String)
signal level_up(lv: int, gifts: Array)

const SAVE_PATH := "user://nong_trai_save.json"
const SAVE_VER := 1
const B0 := 44            # số ô ruộng trên bản đồ
const VA := 6             # ô mở sẵn
const M5 := 1.5           # mọi nguồn tăng tốc cộng lại tối đa x1,5
const KI := 4268.0        # gốc lưới isometric (en/nn bản web)
const HI := 968.0
const CO := 5.0           # ô ruộng nổi 5 đơn vị

var D := {}               # data
var g := {}               # bản lưu (g của bản web)
var cells := []           # vị trí 44 ô: {gx, gy, pc}
var xo: Array = []        # thứ tự giống (xo bản web)
var dirty := false
var _save_t := 0.0
var _last_ms := 0
var _tick_acc := 0.0
var _bug_t := 90.0        # Xo.st
var _ray_t := 0.0         # WS
var _ray_g := 0.0         # jS
var _ray_d := 0.0         # DS
var _en_t := 0.0          # CT
var night := false        # Xn
var nv                    # sổ nhiệm vụ (nv.gd)
var xw                    # xưởng chế biến (xuong.gd)
var vn                    # vật nuôi (vatnuoi.gd)
var troi                  # trời: buổi, thời tiết, mùa (troi.gd)
var lang = null           # lang.gd (farm.gd gán): ô nước, món đặt — UM
var w_all = null          # NTWEB: w_all.gd, các mô-đun dịch từ web

# ------------------------------------------------------------------ data
func _j(p: String):
	var s := FileAccess.get_file_as_string("res://data/" + p + ".json")
	if s == "":
		push_error("thiếu data " + p)
		return null
	return JSON.parse_string(s)

func _load_data() -> void:
	D.crops = _j("nong_trai/cay_trong")
	D.crop_lv = _j("nong_trai/cay_mo_cap")
	D.xp = _j("nhan_vat/kinh_nghiem_theo_viec")
	D.suc = _j("nhan_vat/suc_theo_viec")
	D.y7 = _j("khac/Y7")
	D.drop = _j("nang_cap/roi_vat_lieu")
	D.items = _j("che_bien/vat_pham")
	D.mua = _j("nong_trai/cay_dung_mua")
	D.mat = _j("nang_cap/vat_lieu")
	D.need = _j("cho/nhu_cau_tiem")         # Sv: nhóm hàng (c) và món (i) mỗi tiệm cần
	D.who = _j("cho/ds_nguoi_dat_don")      # k5
	D.shop = _j("cho/chu_quan")             # w5
	# xo: thứ tự giống của bản web = thứ tự trong cay_trong.json
	xo = D.crops.keys()
	for k in xo:
		if D.crop_lv.has(k):
			D.crops[k]["lv"] = int(D.crop_lv[k])
	# 44 ô: 20 ô nhà (gx 1..5, gy 1..4), 12 ô vườn, 12 ô đồng
	for t in 20:
		cells.append({"gx": 1 + t % 5, "gy": 1 + t / 5, "pc": "nha"})
	for t in 12:
		cells.append({"gx": -5 + t % 4, "gy": 1 + t / 4, "pc": "vuon"})
	for t in 12:
		cells.append({"gx": 10 + t % 4, "gy": 1 + t / 4, "pc": "dong"})

func crop(id: String) -> Dictionary:
	return D.crops.get(id, {})

func item_name(id: String) -> String:
	if D.crops.has(id):
		return D.crops[id]["name"]
	if D.items.has(id):
		return D.items[id].get("name", id)
	if D.mat is Dictionary and D.mat.has(id):
		var m = D.mat[id]
		return m.get("n", m.get("name", id)) if m is Dictionary else str(m)
	return id

# ------------------------------------------------------------------ save
func _fresh() -> Dictionary:
	var plots := []
	for e in B0:
		plots.append({"u": e < VA, "c": null, "g": 0.0, "w": 0.0})
	var now := _now_ms()
	return {"v": SAVE_VER, "coins": 30, "plots": plots, "barn": {"lua": 6, "rau_muong": 4}, "sel": "lua",
		"harvested": 0, "last": now, "land": {"nha": 1},
		"pc": {"lv": 1, "xp": 0, "en": 100.0, "et": now, "n": 0, "cnt": {}},
		"ray": {"p": {}, "th": 0, "cd": 0, "k": 0}, "gio": {"lv": 1}, "sys": {"pts": 0, "stats": {}}, "lvq": [],
		"orders": [], "delivered": 0, "ngoc": 0, "rain": 150, "goal": 0}   # NTWEB rain, goal như bản web

func _migrate(s: Dictionary) -> Dictionary:
	# bản lưu cũ hơn: thêm khóa thiếu, không xóa gì
	if not s.has("hdv"):   # NTWEB: bản lưu Godot đã theo nhịp Hay Day, không để SH (w_htx) đổi tỉ lệ
		s.hdv = 2
	if not s.has("sv2"):   # NTWEB: bản lưu Godot đã có sao, không để gJ (w_sys) cộng thêm 1 sao
		s.sv2 = 1
	if not s.has("ht"):   # NTWEB: điểm Hệ Thống theo cấp đã cộng ở _on_level, không để htS (w_sys) cộng lần nữa
		s.ht = {"mig": 1}
	var f := _fresh()
	for k in f.keys():
		if not s.has(k):
			s[k] = f[k]
	for k in f.pc.keys():
		if not s.pc.has(k):
			s.pc[k] = f.pc[k]
	# bộ đếm của sổ nhiệm vụ (g.sys.stats): bản lưu cũ lấy số đã gặt, đã giao
	if not (s.sys.get("stats") is Dictionary):
		s.sys.stats = {"harvest": int(s.get("harvested", 0)), "deliver": int(s.get("delivered", 0))}
	while s.plots.size() < B0:
		s.plots.append({"u": false, "c": null, "g": 0.0, "w": 0.0})
	s.v = SAVE_VER
	return s

func load_game() -> void:
	var txt := FileAccess.get_file_as_string(SAVE_PATH)
	var s = JSON.parse_string(txt) if txt != "" else null
	if s is Dictionary and s.has("plots"):
		g = _migrate(s)
	else:
		g = _fresh()
	if w_all != null:   # NTWEB
		w_all.on_load()
	# tính bù thời gian tắt game (bản web: vw(t, true) chia nhỏ từng bước)
	var off := clampf((_now_ms() - float(g.get("last", _now_ms()))) / 1000.0, 0.0, 86400.0 * 30.0)
	if off > 1.0:
		catch_up(off)
	_regen()
	ord_fill()
	save_game()

func catch_up(off: float) -> void:
	# chia nhỏ từng bước như vw(t, true) của bản web
	var stp := maxf(15.0, off / 2400.0)
	var a := off
	while a > 0.0:
		var e := minf(stp, a)
		_grow(e)
		if w_all != null:   # NTWEB vw(e, true) đuôi
			w_all.step(e, true)
		if xw != null:
			xw.step(e)
		if vn != null:
			vn.step(e, true)
		a -= e
	mark()

func save_game() -> void:
	g.last = _now_ms()
	if (_c_rev != 0 or _c_out()) and not _c_kick():   # NTCLOUD: giờ lưu "thật" = chỉ những lần lưu sau khi đã đọc bản trên mạng (lần lưu lúc mở game không tính)
		g.svt = g.last   # bị máy khác đẩy ra thì thôi: vào lại máy này vẫn lấy bản của máy kia
	var txt := JSON.stringify(g)
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(txt)
		f.close()
	dirty = false
	_cloud_save(txt)

# ------------------------------------------------------------------ LƯU LÊN MẠNG (src/godot/logic/CLOUD.md: trang tạo window.__ntc, Firebase vu-mua)
signal cloud_loaded          # đã thay bản lưu bằng bản trên mạng: dựng lại giao diện, vẽ lại làng
var _ntc = null
var _c_rev := 0              # rev của __ntc đã xử lý (0 = chưa đọc được bản trên mạng lần nào)
var _c_t := 0.0

func _ntc_obj():
	if not OS.has_feature("web"):
		return null
	if _ntc == null and bool(JavaScriptBridge.eval("!!window.__ntc", true)):
		_ntc = JavaScriptBridge.get_interface("__ntc")
	return _ntc

func _prog(s: Dictionary) -> float:   # NTCLOUD: độ xa của bản lưu (cấp, kinh nghiệm, xu) để chọn khi chưa có svt
	var pc = s.get("pc", {})
	if not (pc is Dictionary):
		pc = {}
	return float(pc.get("lv", 1)) * 1e12 + float(pc.get("xp", 0)) * 1e5 + minf(99999.0, float(s.get("coins", 0)))

func _c_out() -> bool:   # NTCLOUD: chưa đăng nhập (chơi chỉ trên máy): lần lưu nào cũng là lưu thật
	var n = _ntc_obj()
	return n == null or str(n.st) == "out"

func _c_kick() -> bool:   # NTCLOUD: tài khoản đang chơi ở máy khác (trang đã che màn, thôi lưu lên mạng)
	var n = _ntc_obj()
	return n != null and str(n.st) == "kick"

func _cloud_save(txt: String) -> void:
	# chỉ đẩy lên sau khi đã đọc bản trên mạng của tài khoản này (khỏi đè làng trên mạng bằng làng mới tinh của máy lạ)
	var n = _ntc_obj()
	if n == null or _c_rev == 0 or str(n.st) != "in":
		return
	n.save(txt)

func _cloud_step(dt: float) -> void:
	_c_t -= dt
	if _c_t > 0.0:
		return
	_c_t = 0.5
	var n = _ntc_obj()
	if n == null or str(n.st) != "in":
		return
	var rev := int(n.rev)
	if rev == _c_rev or rev <= 0:
		return
	_c_rev = rev
	var uid := str(n.uid)
	var c := str(n.cloud) if n.cloud != null else ""
	var s = JSON.parse_string(c) if c != "" else null
	var take := false
	if s is Dictionary and s.has("plots"):
		# bản máy chưa từng gắn với tài khoản này thì lấy bản mạng; đã gắn thì bản nào lưu sau thì lấy
		# NTCLOUD: so giờ lưu thật (svt). Lúc mở game, load_game đã lưu một lần với last = bây giờ, nên so last làm bản cũ của máy luôn "mới hơn" bản mạng.
		# Bản lưu cũ (trước bản 90) chưa có svt: không tin giờ nữa, lấy bản đi xa hơn (cấp, rồi kinh nghiệm, rồi xu).
		if s.has("svt") and g.has("svt"):
			take = str(g.get("cuid", "")) != uid or float(s.svt) > float(g.svt)
		else:
			take = _prog(s) > _prog(g)
	if take:
		g = _migrate(s)
		g.cuid = uid
		if w_all != null:   # NTWEB
			w_all.on_load()
		for k in ["objs"]:
			if not (g.get(k) is Array):
				g[k] = []
		for k in ["clr", "mv", "minis", "road", "unroad", "gt", "penb", "fac"]:
			if not (g.get(k) is Dictionary):
				g[k] = {}
		var off := clampf((_now_ms() - float(g.get("last", _now_ms()))) / 1000.0, 0.0, 86400.0 * 30.0)
		if off > 1.0:
			catch_up(off)
		_regen()
		ord_fill()
		if xw != null:
			xw.sync_pos()
		save_game()
		cloud_loaded.emit()
		changed.emit()
	else:
		g.cuid = uid
		save_game()   # bản máy mới hơn (hoặc tài khoản chưa có bản lưu): đẩy lên

func _now_ms() -> float:
	return Time.get_unix_time_from_system() * 1000.0

func mark() -> void:
	dirty = true
	changed.emit()

func reset_game() -> void:   # #reset bấm lần 2
	g = _fresh()
	g.sys.welcomed = true
	if w_all != null:   # NTWEB
		w_all.on_load()
	ord_fill()
	save_game()
	changed.emit()

# ------------------------------------------------------------------ calendar (vr, t3)
func day() -> int:   # vr
	# ngày game = ngày lịch thật theo giờ máy, tính từ 12/10/2026; Cài đặt "Nhanh": 1 phút ngoài đời = 1 giờ làng
	if cfg.d == "fast":
		return int(floor(Time.get_unix_time_from_system() / 1440.0)) - int(floor(Time.get_unix_time_from_datetime_string("2026-10-12T00:00:00") / 1440.0))
	var t: float = Time.get_unix_time_from_system() + Time.get_time_zone_from_system()["bias"] * 60.0
	return int(floor(t / 86400.0)) - int(floor(Time.get_unix_time_from_datetime_string("2026-10-12T00:00:00") / 86400.0))

func season() -> int:   # t3().i: Cài đặt Mùa khác "Theo lịch" thì giữ cố định
	if cfg.s != "auto":
		return int(cfg.s)
	return int(floor(posmod(day(), 28) / 7.0))

# ------------------------------------------------------------------ Cài đặt (localStorage nong-trai-* của bản web: lưu theo máy, không theo bản lưu)
const CFG_PATH := "user://caidat.json"
signal cfg_changed(k: String)
var cfg := {"a": 1, "mu": 1, "q": 2, "d": "real", "m": "auto", "s": "auto"}
var rm_dev := false        # kw: máy đang bật giảm chuyển động

func cfg_load() -> void:
	var s = JSON.parse_string(FileAccess.get_file_as_string(CFG_PATH)) if FileAccess.file_exists(CFG_PATH) else null
	if s is Dictionary:
		for k in cfg.keys():
			if s.has(k):
				cfg[k] = s[k]
	if OS.has_feature("web"):
		rm_dev = bool(JavaScriptBridge.eval("!!(window.matchMedia&&matchMedia('(prefers-reduced-motion: reduce)').matches)", true))

func cfg_set(k: String, v) -> void:
	cfg[k] = v
	var f := FileAccess.open(CFG_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(cfg))
		f.close()
	cfg_changed.emit(k)
	changed.emit()

func motion_off() -> bool:   # he: Link 11-13 chuyển động luôn bật trên mọi máy
	return false

func vib(ms) -> void:   # gr: rung khi bật Âm thanh và rung
	if ms is Array:   # NTWEB: gr([rung, nghỉ, rung]) -> rung lần đầu
		ms = ms[0] if ms.size() > 0 else 0
	if int(cfg.a) == 1:
		Input.vibrate_handheld(int(ms))

# ------------------------------------------------------------------ level, xp, sức
func lv() -> int:
	return int(g.pc.lv)

func xp_need(n: int) -> int:
	return 30 + n * 20 + int(floor(n * n * 2.5))

func add_xp(t: int, kind: String) -> void:
	var p: Dictionary = g.pc
	if float(g.get("xpU", 0)) > _now_ms():   # bùa +50% EXP (Sm)
		t = int(round(t * 1.5))
	elif bh() == "xp":   # Sm: bùa "Sáng dạ"
		t = int(round(t * 1.5))
	p.xp = int(p.xp) + t
	p.n = int(p.n) + 1
	if kind != "":
		p.cnt[kind] = int(p.cnt.get(kind, 0)) + 1
	while int(p.lv) < 100 and int(p.xp) >= xp_need(int(p.lv)):
		p.xp = int(p.xp) - xp_need(int(p.lv))
		p.lv = int(p.lv) + 1
		if not (g.get("lvq") is Array):
			g.lvq = []
		g.lvq.append(int(p.lv))   # bảng LÊN CẤP chờ mở (g.lvq bản web)
		_on_level(int(p.lv))
	if int(p.lv) >= 100:
		p.lv = 100

func _on_level(n: int) -> void:
	# vZ: tặng 4 hạt mỗi giống mới mở; +5 điểm Hệ Thống
	var gifts := []
	var old := int(g.gio.get("lv", n - 1))
	for e in xo:
		if crop(e).get("hyb", 0):   # Vs bản web: giống lai không tính
			continue
		var r := int(crop(e).get("lv", 1))
		if r > old and r <= n:
			g.barn[e] = int(g.barn.get(e, 0)) + 4
			gifts.append(e)
	g.gio.lv = n
	if not gifts.is_empty():
		var nm := []
		for e in gifts:
			nm.append(crop(e).name)
		toast.emit("Lên cấp mở giống mới: " + ", ".join(nm) + ". Được tặng mỗi thứ 4 hạt để gieo thử!")
	g.sys.pts = int(g.sys.get("pts", 0)) + 5
	level_up.emit(n, gifts)

func en_max() -> float:   # Wl
	return 100.0 + 20.0 * fd("gui")

# ------------------------------------------------------------------ ĐỒ NGHỀ (hB, dB, Fd, SV) + BÙA (Sf, Bh)
const TOOLS := [
	{"id": "binh", "n": "Bình tưới thiếc"},
	{"id": "liem", "n": "Liềm cắt lúa"},
	{"id": "cuoc", "n": "Cuốc xới đất"},
	{"id": "gui", "n": "Gùi tre"}]
const TOOL_COST := [[600, 0], [3500, 8], [15000, 25]]   # dB: [xu, gạch nung]
const BUFFS := {
	"nhanh": {"n": "Chân sáo", "d": "Đi nhanh hơn 30%"},
	"gat": {"n": "Tay mát", "d": "Thu hoạch 10% được thêm 1"},
	"ben": {"n": "Dẻo dai", "d": "Làm việc tốn sức một nửa"},
	"xp": {"n": "Sáng dạ", "d": "Kinh nghiệm thêm 50%"},
	"mat": {"n": "No ấm", "d": "Hồi sức nhanh gấp đôi"},
	"cau": {"n": "Tay câu đỏ", "d": "Dễ câu được cá quý"}}

static func tool_desc(id: String, t: int) -> String:   # hB[].d
	match id:
		"binh": return ("Tưới thêm " + str(t) + " ô bên cạnh mỗi lần tưới") if t else "Tưới từng ô"
		"liem": return ("Gặt nhanh hơn " + str(15 * t) + "%, " + str(6 * t) + "% cơ hội được thêm 1") if t else "Gặt bình thường"
		"cuoc": return ("Gieo xong tự tưới, " + str(10 * t) + "% cơ hội tiết kiệm hạt") if t else "Gieo xong phải tưới"
		"gui": return "Sức tối đa " + str(100 + 20 * t)
	return ""

func fd(t: String) -> int:   # Fd
	var a = g.pc.get("tools", {})
	return clampi(int(a.get(t, 0)) if a is Dictionary else 0, 0, 3)

func tool_up(t: String) -> bool:   # SV
	var a := fd(t)
	if a >= 3:
		return false
	var n: Array = TOOL_COST[a]
	if int(g.coins) < int(n[0]):
		toast.emit("Cần " + fmt_n(int(n[0])) + " xu.")
		return false
	if mat_n("gach") < int(n[1]):
		toast.emit("Cần " + str(n[1]) + " viên gạch nung (đổi ở ghe thương hồ).")
		return false
	g.coins = int(g.coins) - int(n[0])
	mat_add("gach", -int(n[1]))
	if not (g.pc.get("tools") is Dictionary):
		g.pc.tools = {}
	g.pc.tools[t] = a + 1
	var nm := ""
	for o in TOOLS:
		if o.id == t:
			nm = o.n
	toast.emit(("Nâng " if a else "Sắm ") + nm.to_lower() + " lên cấp " + str(a + 1) + ".")
	mark()
	return true

const RIDES := [
	{"id": "xe", "n": "Xe đạp", "lv": 3, "xu": 2500, "d": "Chạy nhanh gấp rưỡi khi đi xa trên đất"},
	{"id": "xuong", "n": "Xuồng ba lá", "lv": 6, "xu": 6000, "d": "Băng qua nước không bị chậm, ra giữa sông Vàm câu cá to"}]   # wB

func ride_buy(t: String) -> bool:   # qV
	var a := {}
	for o in RIDES:
		if o.id == t:
			a = o
	if a.is_empty() or g.pc.get(t, 0):
		return false
	if lv() < int(a.lv):
		toast.emit("Cần cấp " + str(a.lv) + ".")
		return false
	if t == "xuong":
		var n := 0
		for k in ["song_dong", "song", "song_tay"]:   # O0: W5
			if g.land.has(k):
				n += 1
		if n == 0:
			toast.emit("Mở sông Vàm trước đã.")
			return false
	if int(g.coins) < int(a.xu):
		toast.emit("Cần " + fmt_n(int(a.xu)) + " xu.")
		return false
	g.coins = int(g.coins) - int(a.xu)
	g.pc[t] = 1
	toast.emit("Đã sắm " + String(a.n).to_lower() + "!")
	mark()
	return true

func bh() -> String:   # Bh: bùa đang có (pc.bf = {k, u})
	var a = g.pc.get("bf")
	if not (a is Dictionary) or not BUFFS.has(String(a.get("k", ""))) or not (float(a.get("u", 0)) > _now_ms()):
		return ""
	return String(a.k)

func bh_left() -> float:   # oN (ms)
	var a = g.pc.get("bf")
	return maxf(0.0, float(a.u) - _now_ms()) if a is Dictionary else 0.0

func eat(t: String) -> bool:   # MV
	var a: Array = []
	for r in FB:
		if r[0] == t:
			a = r
	if a.is_empty() or not (int(g.barn.get(t, 0)) > 0):
		return false
	var e := en_max()
	if float(g.pc.en) >= e:
		toast.emit("Đang no sức rồi.")
		return false
	g.barn[t] = int(g.barn[t]) - 1
	g.pc.en = minf(e, float(g.pc.en) + int(a[1]))
	toast.emit("Ăn " + String(a[2]).to_lower() + ", hồi " + str(a[1]) + " sức.")
	mark()
	return true

const FB := [["banh_mi_thit", 45, "Bánh mì thịt"], ["ca_kho", 45, "Cá kho tộ"], ["thit_kho", 40, "Thịt kho trứng"], ["thit_kho_nd", 45, "Thịt kho nước dừa"], ["che_chuoi", 40, "Chè chuối"], ["nuoc_mia", 30, "Nước mía"], ["sinh_to", 30, "Sinh tố xoài"], ["banh", 25, "Bánh mì"], ["banh_bo", 25, "Bánh bò"], ["bong_lan", 25, "Bánh bông lan"], ["gao", 12, "Cơm gạo mới"], ["mat_ong", 12, "Nước mật ong"], ["sua", 10, "Ly sữa"], ["qua_dua", 10, "Nước dừa"], ["qua_xoai", 8, "Xoài chín"], ["qua_chuoi", 6, "Chuối chín"], ["trung", 4, "Trứng luộc"]]   # fB

# ------------------------------------------------------------------ BẾP NHÀ (kg, g4, Ux, $b, J7)
const KG := [["com_trung", "Cơm trắng trứng chiên", [["gao", 1], ["trung", 1]], 35, null, 0, 4], ["com_tam", "Cơm tấm sườn trứng", [["gao", 1], ["thit", 1], ["trung", 1]], 60, "nhanh", 8, 6], ["canh_chua", "Canh chua cá lóc", [["ca_loc", 1], ["cachua", 1], ["hanh", 1], ["ot", 1]], 70, "gat", 10, 7], ["ca_kho_to", "Cá rô kho tộ", [["ca_ro", 2], ["hanh", 1], ["ot", 1], ["muoi_hot", 1]], 80, "ben", 12, 8], ["banh_xeo", "Bánh xèo tôm", [["bot_gao", 2], ["trung", 1], ["tom", 1], ["nuoc_cot", 1]], 70, "xp", 10, 7], ["canh_bi", "Canh bí đỏ nấu tôm", [["bido", 1], ["tom", 1]], 45, "mat", 15, 5], ["keo_nuong", "Cá kèo nướng muối ớt", [["ca_keo", 3], ["muoi_hot", 1], ["ot", 1]], 65, "nhanh", 10, 6], ["oc_luoc", "Ốc luộc sả", [["oc", 5]], 30, null, 0, 4], ["lau_mam", "Lẩu mắm điên điển", [["mam_ca", 1], ["ca_loc", 1], ["dien_dien", 2], ["catim", 1]], 100, "cau", 15, 9]]   # [id, tên, in, sức, bùa, phút, giây nấu]

func kg(t: String) -> Array:   # Vd
	for r in KG:
		if r[0] == t:
			return r
	return []

func cook_ok(r: Array) -> bool:   # g4
	for a in r[2]:
		if int(g.barn.get(a[0], 0)) < int(a[1]):
			return false
	return int(g.barn.get("cui", 0)) >= 1

func cook_lv(r: Array) -> int:   # J7
	var a := 1
	for n in r[2]:
		a = maxi(a, bf(n[0]))
	return a

func cook_done(t: String) -> bool:   # Ux job run
	var a := kg(t)
	if a.is_empty():
		return false
	if not cook_ok(a):
		toast.emit("Thiếu nguyên liệu, không nấu được.")
		return false
	for r in a[2]:
		g.barn[r[0]] = int(g.barn[r[0]]) - int(r[1])
	g.barn.cui = int(g.barn.cui) - 1
	var n: Dictionary = g.pc
	n.en = minf(en_max(), float(n.en) + int(a[3]))
	if a[4] != null:
		n.bf = {"k": a[4], "u": _now_ms() + int(a[5]) * 60000.0}
	n.ck = int(n.get("ck", 0)) + 1
	if not (n.get("cks") is Dictionary):
		n.cks = {}
	n.cks[t] = 1
	if not (n.get("ckn") is Dictionary):
		n.ckn = {}
	n.ckn[t] = int(n.ckn.get(t, 0)) + 1
	toast.emit("Nấu xong " + String(a[1]).to_lower() + ", ăn ngon lành! Hồi " + str(a[3]) + " sức" + ((", được \"" + String(BUFFS[a[4]].n) + "\": " + String(BUFFS[a[4]].d).to_lower() + " trong " + str(a[5]) + " phút") if a[4] != null else "") + ".")
	vib(15)
	mark()
	return true

func buy_cui() -> bool:   # $b
	if int(g.coins) < 60:
		toast.emit("Cần 60 xu.")
		return false
	g.coins = int(g.coins) - 60
	g.barn.cui = int(g.barn.get("cui", 0)) + 5
	toast.emit("Mua 5 bó củi khô của bà Năm hàng xóm.")
	mark()
	return true

func after_plant(t: int, a: String) -> void:   # LV: cuốc
	var n := fd("cuoc")
	var e := p(t)
	if n:
		e.w = water_hold(e)
		if randf() < 0.1 * n and crops_has(a):
			g.barn[a] = int(g.barn.get(a, 0)) + 1
			float_text.emit(cells[t].gx + 0.5, cells[t].gy + 0.5, "Tiết kiệm 1 hạt giống")

func crops_has(a: String) -> bool:
	return D.crops.has(a)

func after_water(t: int) -> void:   # CV: bình tưới thiếc tưới thêm ô quanh
	var a := fd("binh")
	if not a:
		return
	var n: Dictionary = cells[t]
	var e := 0
	for r in B0:
		if e >= a:
			break
		if r == t:
			continue
		var o: Dictionary = cells[r]
		if absi(int(o.gx) - int(n.gx)) > 1 or absi(int(o.gy) - int(n.gy)) > 1:
			continue
		if water(r):
			e += 1
			if lang != null and lang.F != null:
				lang.F.ts(r, "water")

func after_harvest(t: int, a: String) -> void:   # EV: liềm bén, tay mát (được mùa HTX chưa có)
	var n := fd("liem")
	if n and randf() < 0.06 * n:
		g.barn[a] = int(g.barn.get(a, 0)) + 1
		float_text.emit(cells[t].gx + 0.5, cells[t].gy + 0.5, "+1 nhờ liềm bén")
	if bh() == "gat" and randf() < 0.1:   # Qx
		g.barn[a] = int(g.barn.get(a, 0)) + 1
		float_text.emit(cells[t].gx + 0.5, cells[t].gy + 0.5, "+1 tay mát")

func tired() -> bool:
	return float(g.pc.en) < 1.0

func use_en(t: float) -> void:
	if t <= 0.0:
		return
	var was := float(g.pc.en) >= 1.0
	g.pc.en = maxf(0.0, float(g.pc.en) - t * (0.5 if bh() == "ben" else 1.0))   # cN
	if was and float(g.pc.en) < 1.0:
		toast.emit("Nhân vật mệt rồi, đi đứng chậm hẳn. Cho ăn uống hoặc về nhà ngủ để lấy lại sức.")

func _regen() -> void:
	# wV: hồi 1 sức mỗi 10 giây (đêm x1,5), tính cả lúc tắt game, tối đa 8 tiếng
	var p: Dictionary = g.pc
	var a := _now_ms()
	if not p.has("et") or float(p.et) <= 0.0:
		p.et = a
		return
	var n := minf(8.0 * 3600.0, (a - float(p.et)) / 1000.0)
	p.et = a
	if n > 0.0 and float(p.en) < en_max():
		p.en = minf(en_max(), float(p.en) + n / 10.0 * (1.5 if night else 1.0) * (2.0 if bh() == "mat" else 1.0))   # fN

func speed(l := 0.0) -> float:
	# pV: 2,6 ô/giây x (1 + min(0,4; 0,02 x (cấp-1))), hết sức x0,55
	return 2.6 * (1.0 + minf(0.4, 0.02 * (lv() - 1))) * (0.55 if tired() else 1.0) * (float(troi.walk_k()) if troi != null else 1.0) * (1.3 if bh() == "nhanh" else 1.0) * (1.7 if g.pc.get("xe", 0) and l > 2.5 else 1.0)   # lN, xe đạp (đi xa > 2,5 ô)

# ------------------------------------------------------------------ plots
func p(i: int) -> Dictionary:
	return g.plots[i]

func owned(i: int) -> bool:   # $1: khu đất của ô đã có chưa
	return g.land.has(cells[i].pc)

func n_open() -> int:          # ru
	var n := 0
	for a in g.plots:
		if a.u:
			n += 1
	return n

func max_open(l: int = -1) -> int:   # Zg
	if l < 0:
		l = lv()
	return mini(B0, 4 + 2 * l) if l <= 10 else mini(B0, 24 + int(floor((l - 10) / 2.0)))

func lv_for_more() -> int:     # Xg
	var t := n_open()
	if t < max_open():
		return 0
	for a in range(lv() + 1, 101):
		if max_open(a) > t:
			return a
	return 0

func open_cost() -> int:       # j3
	var t := n_open() - VA + 1
	var a := mini(t, 15)
	var n := int(round(15.0 * a * pow(1.15, a) * 0.7))
	return int(round(n * (1.0 + 0.35 * (t - 15)))) if t > 15 else n

func water_hold(a: Dictionary) -> float:   # Z1: giây giữ nước theo sao ô
	return float(D.y7[clampi(int(a.get("st", 1)), 1, 6)])

func stage(a: Dictionary) -> int:   # T5
	var r := float(a.g) / float(crop(a.c).time)
	return 3 if r >= 1.0 else 2 if r >= 0.55 else 1 if r >= 0.15 else 0

func ripe(a: Dictionary) -> bool:   # V0
	return a.c != null and float(a.g) >= float(crop(a.c).time)

func star(a: Dictionary) -> int:    # E1
	return clampi(int(a.get("st", 1)), 1, 6)

func in_season(c: String) -> bool:  # ls(c) > 1
	return D.mua[season()].has(c)

func boost() -> float:   # tw(): 1 + PX() + jH() + (gB() - 1) + (Dx() > 1 ? .04 : 0)
	return 1.0 + (w_all.boost_add() if w_all != null else 0.0)   # NTWEB

func time_left(a: Dictionary) -> float:   # b3
	var c := minf(M5, boost()) * (1.04 if in_season(a.c) else 1.0)   # ch() x ls (dX 1,04)
	return maxf(0.0, (float(crop(a.c).time) - float(a.g)) / c)

func _grow(t: float) -> void:
	# vw: phần thời gian đất còn ướt lớn nhanh hơn 10%; ô có sâu thì ngưng lớn
	for e in B0:
		var r: Dictionary = g.plots[e]
		if r.c == null or ripe(r) or r.get("b", 0) or (troi != null and troi.bao.blocks(e)):
			continue
		var l: float = drain(e) * (troi.dry_k() if troi != null else 1.0)   # UM(e) x VB
		var o := minf(t, float(r.w) / l) if float(r.w) > 0.0 else 0.0
		r.w = maxf(0.0, float(r.w) - o * l)
		var c: float = boost() + 0.04 * (star(r) - 1) + (0.04 if in_season(r.c) else 0.0) + (w_all.um_add() if w_all != null else 0.0)   # NTWEB um
		r.g = minf(float(crop(r.c).time), float(r.g) + (o * minf(M5, c + 0.1) + (t - o) * minf(M5, c)) * (w_all.t_o(e) if w_all != null else 1.0))   # NTWEB tO

var _dr := {}
var _dr_sig := ""
const KD := {"lunuoc": 1, "well": 1, "pond": 1}
func drain(i: int) -> float:   # UM: trong 2 ô có nước / kênh / lu nước / giếng / ao thì đất giữ nước lâu (0,6)
	if lang == null:
		return 1.0
	var sig := str(lang.ver) + ":" + str(lang.objs().size()) + ":" + str(g.land.size())
	if sig != _dr_sig:
		_dr_sig = sig
		_dr = {}
	if _dr.has(i):
		return _dr[i]
	var gx: int = int(cells[i].gx)
	var gy: int = int(cells[i].gy)
	var l := false
	lang._a1()
	for x in range(gx - 2, gx + 3):
		if l:
			break
		for y in range(gy - 2, gy + 3):
			if lang.is_water(x, y) or lang.il(x, y) == "canal":
				l = true
				break
			for n in lang.a1.get(str(x) + "," + str(y), []):
				if KD.has(String(lang.objs()[n].id)):
					l = true
					break
			if l:
				break
	_dr[i] = 0.6 if l else 1.0
	return _dr[i]

func can_plant(i: int, seed: String) -> String:
	var e := p(i)
	if not e.u or e.c != null or not D.crops.has(seed):
		return "x"
	if int(crop(seed).get("lv", 1)) > lv():
		return crop(seed).name + " tới cấp " + str(crop(seed).lv) + " mới mở khóa giống."
	if sd_n(seed) < 1:   # NTWEB sdN
		if w_all != null and w_all.is_hyb(seed):
			return "Hết hạt lai " + crop(seed).name.to_lower() + ". Trồng hai giống gốc sát nhau để lai tiếp."
		return "Hết giống " + crop(seed).name.to_lower() + ". Mua ở Chợ phiên, chợ nổi sáng sớm hoặc nhà hàng xóm."
	return ""

func sd_n(seed: String) -> int:   # NTWEB sdN: giống lai ở g.lai.h
	return w_all.WR.sd_n(seed) if w_all != null else int(g.barn.get(seed, 0))

func plant(i: int, seed: String) -> bool:   # Ev
	if can_plant(i, seed) != "":
		return false
	var e := p(i)
	if w_all != null:   # NTWEB sdUse
		w_all.WR.sd_use(seed)
	else:
		g.barn[seed] = int(g.barn[seed]) - 1
	e.c = seed
	e.g = 0.0
	e.w = 0.0
	e.b = 0
	g.sel = seed
	nv.qi("plant")
	float_text.emit(cells[i].gx + 0.5, cells[i].gy + 0.5, "-1 giống")
	if w_all != null:   # NTWEB Ev bọc: phân xanh
		w_all.WS.ht_after_plant(i)
	return true

func fast_ripe(i: int) -> bool:   # fL: chín ngay bằng sen đỏ
	var a := p(i)
	if a.c == null or ripe(a):
		return false
	var n := maxi(1, int(ceil(time_left(a) / 600.0)))   # Ro(b3)
	if int(g.get("ngoc", 0)) < n:
		toast.emit("Cần " + str(n) + " sen đỏ, đang có " + str(int(g.get("ngoc", 0))) + ".")
		return false
	g.ngoc = int(g.ngoc) - n   # x0(-n)
	nv.spent(n)
	a.g = float(crop(a.c).time)
	if lang != null and lang.F != null:
		lang.F.ts(i, "unlock")
	toast.emit(String(crop(a.c).name) + " chín ngay, tốn " + str(n) + " sen đỏ.")
	mark()
	return true

func water(i: int) -> bool:   # Wp
	var a := p(i)
	if a.c == null or ripe(a) or float(a.w) >= water_hold(a) - 0.5:
		return false
	a.w = water_hold(a)
	nv.S8("water")
	if w_all != null and lang != null:   # NTWEB aO: ô nhiễm mặn tốn nước ngọt
		w_all.WR.a_o(i)
	return true

func harvest(i: int) -> bool:   # Xu
	var a := p(i)
	if not ripe(a):
		return false
	if not kho_fit(1):   # g8 (bản web bọc Xu)
		return false
	var pre: Array = w_all.WS.ht_dat_before(i) if w_all != null else []   # NTWEB dat(Xu)
	var n := 2 + (1 if randf() < 0.12 else 0)   # l7
	var c: String = a.c
	g.barn[c] = int(g.barn.get(c, 0)) + n
	_drop("harvest", i)
	if c.begins_with("lua") or c.begins_with("nep"):
		_drop("rice", i)
	g.harvested = int(g.harvested) + 1
	if w_all != null and lang != null:   # NTWEB z4: lai giống
		w_all.WR.z4(i, c, true)
	nv.qi("harvest")
	float_text.emit(cells[i].gx + 0.5, cells[i].gy + 0.5, "+" + str(n) + " " + crop(c).name)
	if nv.bt_harvest(c):
		float_text.emit(cells[i].gx + 0.5, cells[i].gy + 0.2, "+1 bội thu")
	a.lc = c
	a.c = null
	a.g = 0.0
	a.w = 0.0
	a.b = 0
	if w_all != null:   # NTWEB dat(Xu): đất lành
		w_all.WS.ht_dat_after(i, true, pre)
	return true

func catch_bug(i: int) -> bool:   # Ty
	var a := p(i)
	if not a.get("b", 0):
		return false
	a.b = 0
	g.coins = int(g.coins) + 2
	float_text.emit(cells[i].gx + 0.5, cells[i].gy + 0.5, "Bắt sâu! +2 xu")
	return true

func open_plot(i: int) -> bool:   # iy + hw
	var a := p(i)
	if a.u or not owned(i):
		return false
	var need := lv_for_more()
	if need > 0:
		toast.emit("Lên cấp " + str(need) + " mới mở thêm được ô ruộng (đang có " + str(n_open()) + "/" + str(max_open()) + " ô).")
		return false
	var t := open_cost()
	if int(g.coins) < t:
		toast.emit("Cần " + str(t) + " xu để mở thêm một ô đất.")
		return false
	g.coins = int(g.coins) - t
	a.u = true
	toast.emit("Đã mở thêm một ô đất.")
	mark()
	return true

func _drop(key: String, i: int) -> void:
	# No(): vật liệu nâng sao rơi ra khi làm việc
	var L = D.drop.get(key, [])
	for r in L:
		if randf() < float(r[1]):
			var id: String = r[0]
			mat_add(id, 1)
			float_text.emit(cells[i].gx + 0.5, cells[i].gy + 0.2, "+1 " + item_name(id))

# sâu (uW): mỗi 70–140 giây ban ngày, nếu ít hơn 2 ô có sâu
func _bug_step(t: float) -> void:
	if night:
		return
	var n := 0
	for a in g.plots:
		if a.get("b", 0):
			n += 1
	if n >= 2:
		return
	_bug_t -= t
	if _bug_t > 0.0:
		return
	_bug_t = randf_range(70.0, 140.0)
	var L := []
	for e in B0:
		var a: Dictionary = g.plots[e]
		if a.u and a.c != null and not a.get("b", 0) and not ripe(a) and owned(e) and stage(a) >= 1:
			L.append(e)
	if L.size() > 0:
		g.plots[L[randi() % L.size()]].b = 1
		mark()

# rầy nâu (i_): mỗi phút có thể bùng dịch (mùa hạ 2x, thu 1,5x, khô 0,4x), cây teo 7% mỗi 20 giây, lây ô kề
const RAY_MUA := [1.0, 2.0, 1.5, 0.4]
func _ray_cells() -> Array:   # hR
	var t := []
	for a in B0:
		var n: Dictionary = g.plots[a]
		if n.u and n.c != null and owned(a) and not ripe(n):
			t.append(a)
	return t

func near(i: int) -> Array:   # Ok
	var a: Dictionary = cells[i]
	var n := []
	for e in B0:
		if e != i and absi(int(cells[e].gx) - int(a.gx)) <= 1 and absi(int(cells[e].gy) - int(a.gy)) <= 1:
			n.append(e)
	return n

func ray_n() -> int:
	return g.ray.p.size()

func has_ray(i: int) -> bool:
	return g.ray.p.has(str(i))

func ray_safe(i: int) -> bool:   # uR: có đèn bẫy rầy trong 6 ô
	var a: Dictionary = cells[i]
	for o in g.objs:
		if o is Dictionary and o.get("id", "") == "denbay" and Vector2(float(o.gx) - float(a.gx), float(o.gy) - float(a.gy)).length() <= 6.0:
			return true
	return false

func _ray_start(t: int) -> void:   # e_
	var a := _ray_cells().filter(func(f): return not ray_safe(f))
	if a.is_empty():
		return
	var lua := a.filter(func(f): return g.plots[f].c == "lua")
	var pool: Array = lua if lua.size() > 0 else a
	var e: int = pool[randi() % pool.size()]
	var o: Dictionary = g.ray
	var now := _now_ms()
	o.p[str(e)] = {"at": now}
	var r := 1
	var l := near(e).filter(func(f): return a.has(f))
	while r < t and l.size() > 0:
		var c: int = l.pop_at(randi() % l.size())
		o.p[str(c)] = {"at": now}
		r += 1
	o.k = int(o.k) + 1
	toast.emit("Dịch rầy nâu! " + str(r) + " ô ruộng bị rầy cắn, cây teo dần. Chạm ô có rầy để phun thuốc.")
	mark()

func _ray_step(t: float) -> void:
	var a: Dictionary = g.ray
	var n := _now_ms()
	_ray_t -= t
	if _ray_t <= 0.0:
		_ray_t = 60.0
		if ray_n() == 0 and n > float(a.cd):
			if _ray_cells().size() >= 6:
				var o: float = 0.016 * RAY_MUA[season()] * (1.5 if troi != null and (troi.cur == "mua" or troi.cur == "giong") else 1.0)
				if randf() < o:
					_ray_start(2 + randi() % 3)
	if ray_n() == 0:
		return
	_ray_g -= t
	if _ray_g <= 0.0:
		_ray_g = 20.0
		for k in a.p.keys():
			var c: Dictionary = g.plots[int(k)]
			if c.c == null:
				a.p.erase(k)
				continue
			var f := crop(c.c)
			c.g = maxf(0.0, float(c.g) - float(f.time) * 0.07)
			if float(c.g) <= 0.0 and n - float(a.p[k].at) > 60000.0:
				toast.emit("Rầy cắn chết một ô " + f.name.to_lower() + "!")
				c.c = null
				c.g = 0.0
				a.p.erase(k)
		for k in a.p.keys():
			if randf() > 0.3:
				continue
			var E := near(int(k)).filter(func(R): return g.plots[R].c != null and not a.p.has(str(R)) and not ray_safe(R) and owned(R))
			if E.size() > 0:
				a.p[str(E[randi() % E.size()])] = {"at": n}
		if ray_n() == 0:
			a.cd = n + 20.0 * 60000.0
		mark()
	_ray_d -= t   # DS: mỗi 25 giây vịt nhà ăn rầy, hoặc người làm ruộng thuê phun thuốc (tốn thuốc của mình)
	if _ray_d > 0.0:
		return
	_ray_d = 25.0
	if ray_n() == 0:
		return
	var s0 := int(a.p.keys()[0])
	var vit = g.get("pet", {}).get("vit") if g.get("pet") is Dictionary else null
	if vit is Dictionary and int(vit.get("n", 0)) > 0:
		_ray_clear(s0)
		float_text.emit(cells[s0].gx + 0.5, cells[s0].gy + 0.5, "Vịt ăn sạch rầy")
		mark()
		return
	var x = null
	var fam = g.get("lang", {}).get("fam") if g.get("lang") is Dictionary else null
	if fam is Dictionary:
		for k in fam:
			if fam[k] is Dictionary and fam[k].get("job") == "ruong":
				x = fam[k]
	if x != null and int(a.th) > 0:
		a.th = int(a.th) - 1
		for r in [s0] + near(s0):
			_ray_clear(r)
		float_text.emit(cells[s0].gx + 0.5, cells[s0].gy + 0.5, String(x.get("n", "")) + " phun thuốc")
		mark()

func _ray_clear(i: int) -> bool:   # VS: ô hết rầy; hết dịch thì 20 phút sau mới có thể có lại
	var a: Dictionary = g.ray
	if not a.p.has(str(i)):
		return false
	a.p.erase(str(i))
	if ray_n() == 0:
		a.cd = _now_ms() + 20.0 * 60000.0
	return true

func spray(i: int) -> bool:   # QS: bình thuốc 150 xu = 5 lần, sạch luôn ô kề
	var a: Dictionary = g.ray
	if not a.p.has(str(i)):
		toast.emit("Ô này hết rầy rồi.")
		return false
	if int(a.th) < 1:
		if int(g.coins) < 150:
			toast.emit("Cần 150 xu mua bình thuốc.")
			return false
		g.coins = int(g.coins) - 150
		a.th = int(a.th) + 5
		toast.emit("Mua 1 bình thuốc trừ rầy (5 lần phun).")
	a.th = int(a.th) - 1
	var n := 0
	for r in [i] + near(i):
		if _ray_clear(r):
			n += 1
	float_text.emit(cells[i].gx + 0.5, cells[i].gy + 0.5, "Sạch rầy " + str(n) + " ô")
	if ray_n() == 0:
		toast.emit("Hết dịch rầy rồi! Đèn bẫy rầy giúp ruộng đỡ bị lại.")
	if nv != null:
		nv.qi("phun")
	mark()
	return true

# ------------------------------------------------------------------ chợ: giá bán trong Kho ($i, ngKho, B3, mk* bản web)
# danh sách hợp mùa qO: Xuân, Hạ, Thu, Khô
const SEA := [["lua", "dau", "rau_muong", "hanh", "xa_lach", "dua_leo", "sa", "rau_ram", "kho_qua", "dau_den"],
	["bap", "cachua", "duahau", "ot", "catim", "huong_duong", "me", "bong_vai", "sa", "dau_xanh", "la_dua", "bau", "bi_dao", "kho_qua", "dau_rong", "dau_bap", "muop", "khoai_mon"],
	["lua", "carot", "khoai", "bido", "dauphong", "nep", "cham", "gung", "nghe", "bau", "bi_dao", "dau_rong", "dau_bap", "muop", "khoai_mon"],
	["carot", "cachua", "cai", "mia", "hanh_tay", "dau_nanh", "tieu", "gung", "dau_den"]]
const SEA_N := ["Xuân", "Hạ", "Thu", "Khô"]
const LY := 4			   # Bán hết chừa lại mỗi thứ 4 hạt giống
var _hot_day := -99999
var _hot := []
var _mk_t := 0.0

func item(t: String) -> Dictionary:   # ae
	if D.crops.has(t):
		return D.crops[t]
	if D.items.has(t):
		return D.items[t]
	return {}

func hot() -> Array:   # B3: 3 món được giá hôm nay (x2, x1,8, x1,5)
	var d := day()
	if d == _hot_day:
		return _hot
	_hot_day = d
	var e := []
	for k in xo:
		if int(crop(k).get("lv", 1)) <= lv() and float(crop(k).get("sell", 0)) > 0.0:
			e.append(k)
	e.sort()
	var r := (d * 2654435761) & 0xffffffff
	var L := []
	var cs := [2.0, 1.8, 1.5]
	for f in 3:
		if e.is_empty():
			break
		# xorshift như JS: r^=r<<13, r>>>=0, r^=r>>17 (dịch có dấu 32 bit), r^=r<<5, r>>>=0
		r = (r ^ (r << 13)) & 0xffffffff
		var rs := _i32(r)
		r = _i32(rs ^ (rs >> 17))
		r = (r ^ (r << 5)) & 0xffffffff
		var s := int(floor(float(r) / 4294967296.0 * e.size()))
		L.append([e[s], cs[f]])
		e.remove_at(s)
	_hot = L
	return L

static func _i32(x: int) -> int:
	x = x & 0xffffffff
	return x - 0x100000000 if x >= 0x80000000 else x

func hot_x(t: String) -> float:   # NA
	for h in hot():
		if h[0] == t:
			return h[1]
	return 1.0

func price(t: String) -> int:   # NTWEB ngKho: $i bọc chợ có lý do (w_kho)
	return w_all.WK.ngKho(t) if w_all != null else price0(t)

func price0(t: String) -> int:   # $i gốc: giá x hệ số chợ x (1 + đẹp làng) x được giá
	var base := int(round(float(item(t).get("sell", 0)) * float(g.get("mult", {}).get(t, 1.0))))
	return int(round(base * hot_x(t)))

func mk() -> Dictionary:   # mkS
	if not (g.get("mk") is Dictionary):
		g.mk = {}
	var o: Dictionary = g.mk
	if not (o.get("sat") is Dictionary):
		o.sat = {}
	if not (o.get("h") is Dictionary):
		o.h = {}
	if not (o.get("t") is float or o.get("t") is int):
		o.t = _now_ms()
	return o

func mk_c(t: String) -> float:
	return maxf(10.0, round(1500.0 / maxf(1.0, float(item(t).get("sell", 10)))))

func mk_f(t: String, s: float) -> float:   # bán dồn thì rớt giá, tối đa -40%
	return maxf(0.6, 1.0 - 0.4 * s / mk_c(t))

func mk_ev(t: String) -> float:   # mkWhy: hợp mùa rẻ hơn, trái mùa đắt hơn
	if D.crops.has(t) and not crop(t).get("hyb", false):
		return 0.9 if SEA[season()].has(t) else 1.1
	return 1.0

func rel(t: String) -> float:   # mkRel: > 1,08 lên giá (▲), < 0,92 rớt giá (▼)
	if w_all != null:   # NTWEB mkRel có lý do (w_kho)
		return w_all.WK.mkRel(t)
	return float(g.get("mult", {}).get(t, 1.0)) * mk_ev(t) * mk_f(t, float(mk().sat.get(t, 0.0)))

func sell_value(t: String, n: int, peek: bool = true) -> int:   # mkTong
	if n <= 0:
		return 0
	var b := float(price(t))
	var s0 := float(mk().sat.get(t, 0.0))
	var k := maxi(1, int(ceil(n / 20.0)))
	var st := float(n) / k
	var tot := 0.0
	for i in k:
		tot += st * b * mk_f(t, s0 + i * st + st / 2.0)
	if not peek:
		mk().sat[t] = minf(mk_c(t) * 1.5, s0 + n)
	return int(round(tot))

func sell(t: String, n: int) -> int:   # nG
	n = mini(n, int(g.barn.get(t, 0)))
	if n <= 0:
		return 0
	var e := sell_value(t, n, false)
	g.coins = int(g.coins) + e
	g.barn[t] = int(g.barn[t]) - n
	toast.emit("Bán " + str(n) + " " + item(t).get("name", t) + ", nhận " + fmt_n(e) + " xu.")
	mark()
	return e

func sell_all(ids: Array) -> int:   # #sellAll: chừa 4 hạt mỗi thứ để gieo
	var a := 0
	var n := 0
	var kept := 0
	for t in ids:
		var c := int(g.barn.get(t, 0))
		var o := mini(LY, c) if D.crops.has(t) else 0
		var l := c - o
		if l <= 0:
			continue
		kept += o
		a += sell_value(t, l, false)
		n += l
		g.barn[t] = o
	if n > 0:
		g.coins = int(g.coins) + a
		toast.emit("Bán " + str(n) + " món, nhận " + fmt_n(a) + " xu." + (" Chừa lại mỗi thứ " + str(LY) + " hạt giống để gieo." if kept else ""))
		mark()
	return a

func _mk_step(t: float) -> void:   # 5 s một lần: chợ hồi giá dần (25% sức chứa mỗi giờ)
	_mk_t -= t
	if _mk_t > 0.0:
		return
	_mk_t = 5.0
	var o := mk()
	var now := _now_ms()
	var h := (now - float(o.t)) / 3600000.0
	o.t = now
	if h > 0.0:
		for k in o.sat.keys():
			o.sat[k] = maxf(0.0, float(o.sat[k]) - mk_c(k) * 0.25 * h)
			if o.sat[k] < 0.5:
				o.sat.erase(k)

static func fmt_n(v: float) -> String:   # Sa: 1.234 kiểu Việt
	var s := str(int(round(absf(v))))
	var out := ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if v < 0 else "") + s + out

static func fmt_k(v: int) -> String:   # ry: 12,3k
	if v >= 10000:
		return str(floor(v / 100.0) / 10.0).replace(".", ",") + "k"
	return str(v)

# ------------------------------------------------------------------ KHO (module "kho" bản web: sao kho, sức chứa, vật liệu kho)
const KHO_VP := [0, 50, 75, 100, 125, 150, 200, 250, 300, 400, 500]   # vp: sức chứa theo sao
const KHO_LV := [0, 1, 3, 7, 12, 18, 25, 35, 48, 62, 80]              # p8: cấp cần
const KHO_XU := [0, 0, 100, 300, 700, 1500, 3000, 5500, 9000, 14000, 22000]   # CJ
const KHO_M := [null, null, [1, 1, 0], [2, 2, 1], [3, 3, 3], [4, 4, 4], [5, 5, 5], [6, 6, 6], [8, 8, 8], [10, 10, 10], [12, 12, 12]]   # EJ then/bao/ton
const KHO_CA := [0, 0, 2, 3, 5, 6, 7, 8, 10, 12, 15]   # CA: sen đỏ mỗi cấp nâng sớm
const KHO_SA := 8   # SA: nâng sớm tối đa 8 cấp
signal kho_full(n: int, cap: int)   # lL: bảng "Kho đầy rồi!"
var _kf_t := 0   # JH

func kho_star() -> int:   # D1
	return clampi(int(g.get("khost", 0)) if int(g.get("khost", 0)) != 0 else 1, 1, 10)

func kho_cap() -> int:   # t5
	return KHO_VP[kho_star()] + int(g.get("khoB", 0))

func kho_n() -> int:   # td: chỉ đếm hàng thường (ae)
	var n := 0
	for k in g.barn.keys():
		var e := int(g.barn[k])
		if e > 0 and not item(k).is_empty():
			n += e
	return n

func kho_room() -> int:   # _s
	return kho_cap() - kho_n()

func mat_n(t: String) -> int:   # ul
	var m = g.get("mats", {})
	return int(m.get(t, 0)) if m is Dictionary else 0

func mat_add(t: String, a: int) -> void:   # S0 (tối đa 999)
	if not (g.get("mats") is Dictionary):
		g.mats = {}
	g.mats[t] = mini(999, int(g.mats.get(t, 0)) + a)

func kho_need(t: int) -> Dictionary:   # Z4
	var m := []
	var q: Array = KHO_M[t]
	var ids := ["then", "bao", "ton"]
	for j in 3:
		if int(q[j]) > 0:
			m.append([ids[j], int(q[j])])
	return {"xu": KHO_XU[t], "lv": KHO_LV[t], "m": m}

static func kho_stars(t: int) -> String:   # ZH
	var a := ""
	for n in range(1, 11):
		a += "★" if n <= t else "☆"
	return a

func can_pay(t: Dictionary) -> bool:   # j1
	if int(g.coins) < int(t.xu):
		return false
	for a in t.m:
		if mat_n(a[0]) < int(a[1]):
			return false
	return z3 or lv() >= int(t.lv)

func early_lv(t: int) -> int:   # EA
	return maxi(0, t - lv())

func early_ok(t: int) -> bool:   # f1
	var a := early_lv(t)
	return a > 0 and a <= KHO_SA

func early_fee(t: int) -> int:   # V9(CA[n+1], lv) + mL(thiếu vật liệu) + bL(thiếu xu)
	var r: int = KHO_CA[mini(10, kho_star() + 1)] * early_lv(int(t))
	return r

func kho_early_cost(t: Dictionary) -> int:   # v$
	var a := early_lv(int(t.lv))
	var r: int = (KHO_CA[kho_star() + 1] * a) if a > 0 else 0
	for m in t.m:
		var lack := int(m[1]) - mat_n(m[0])
		if lack > 0:
			r += lack * (4 if m[0] == "gach" else 3)   # mL
	var e := maxi(0, int(t.xu) - int(g.coins))
	if e > 0:
		r += maxi(1, int(ceil(e / 25.0)))   # bL
	return r

func _pay(t: Dictionary) -> bool:   # Yg (z3: đang nâng sớm, bỏ qua cấp)
	if not z3 and lv() < int(t.lv):
		toast.emit("Lên cấp " + str(t.lv) + " mới nâng được tới mức này.")
		return false
	if int(g.coins) < int(t.xu):
		toast.emit("Cần " + fmt_n(int(t.xu)) + " xu.")
		return false
	var lack := []
	for a in t.m:
		var c := mat_n(a[0])
		if c < int(a[1]):
			lack.append(str(int(a[1]) - c) + " " + item_name(a[0]).to_lower())
	if not lack.is_empty():
		toast.emit("Thiếu vật liệu: " + ", ".join(lack) + ".")
		return false
	g.coins = int(g.coins) - int(t.xu)   # zH
	for a in t.m:
		mat_add(a[0], -int(a[1]))
	return true

var z3 := false
# ------------------------------------------------------------------ NÂNG SAO Ô RUỘNG (dJ.plot, hl, lf, e$, R2)
const DJ_PLOT := {"m": ["rom", "phan", "voi"], "xu": [0, 0, 50, 150, 400, 1200, 3000], "q": [null, null, [1, 1, 0], [2, 1, 1], [2, 2, 2], [3, 3, 3], [5, 5, 5]]}
const HJ := [0, 0, 3, 7, 12, 25, 40]
const NS_FEE := [0, 0, 2, 3, 4, 6, 10]   # n$

const DJ_PEN := {"m": ["tre", "la", "may"], "xu": [0, 0, 150, 400, 1200, 3000, 7500], "q": [null, null, [2, 1, 0], [3, 2, 1], [4, 3, 2], [6, 6, 5], [10, 10, 8]]}

func up_need(a: int, n := 1, kind := "plot") -> Dictionary:   # hl(kind, a, n): ô ruộng / chuồng
	var D2: Dictionary = DJ_PEN if kind == "pen" else DJ_PLOT
	var r: Array = D2.q[a]
	var m := []
	for l in 3:
		if int(r[l]) * n > 0:
			m.append([D2.m[l], int(r[l]) * n])
	return {"xu": int(D2.xu[a]) * n, "m": m, "lv": HJ[a]}

func k4(t: int) -> Array:   # K4: các ô đã mở đang t sao
	var a := []
	for e in B0:
		if g.plots[e].u and star(g.plots[e]) == t:
			a.append(e)
	return a

static func ao(t: float) -> String:   # ao: "5 phút", "1 giờ 30 phút"
	var x := int(maxf(0.0, ceil(t)))
	var a := x / 3600
	var n := (x % 3600) / 60
	var e := x % 60
	if a >= 24:
		var r := a / 24
		a %= 24
		return str(r) + " ngày" + ((" " + str(a) + " giờ") if a else "")
	if a:
		return str(a) + " giờ" + ((" " + str(n) + " phút") if n else "")
	if n >= 10:
		return str(n) + " phút"
	if n:
		return str(n) + " phút" + ((" " + str(e) + " giây") if e else "")
	return str(e) + " giây"

func us_plot(a: int) -> String:   # Us("plot", a)
	if a <= 1:
		return "Giữ nước " + ao(float(D.y7[1])) + ", chưa tăng tốc"
	return "Cây lớn nhanh +" + str(4 * (a - 1)) + "% · giữ nước " + ao(float(D.y7[a]))

static func us_pen(a: int) -> String:   # Us("pen", a)
	if a <= 1:
		return "Chưa nâng"
	return "Ra hàng nhanh +" + str(6 * (a - 1)) + "%" + (" · 25% lần cho ăn không tốn đồ ăn" if a >= 4 else "")

func pen_up(t: String) -> bool:   # lf("pen", t)
	if vn == null:
		return false
	var n: int = vn.ps(t)
	if n >= 6:
		return false
	if not _pay(up_need(n + 1, 1, "pen")):
		return false
	g.penst[t] = n + 1
	toast.emit(String(lang.CO.get(t, "Chuồng")) + " lên " + str(n) + "★: " + us_pen(n + 1) + ".")
	vib(15)
	mark()
	return true

static func stars5(t: int) -> String:   # $h
	var a := ""
	for n in range(1, 6):
		a += "★" if n <= t - 1 else "☆"
	return a

func plot_up(i: int) -> bool:   # lf("plot", i)
	var r: Dictionary = g.plots[i]
	if not r.u:
		return false
	var n := star(r)
	if n >= 6:
		return false
	if not _pay(up_need(n + 1)):
		return false
	r.st = n + 1
	if lang != null and lang.F != null:
		lang.F.ts(i, "unlock")
	toast.emit("Ô ruộng lên " + str(n) + "★: " + us_plot(n + 1) + ".")
	vib(15)
	mark()
	return true

func plot_up_all(n: int) -> bool:   # lf("plotall", n)
	var o := k4(n)
	if o.is_empty() or n >= 5:
		return false
	if not _pay(up_need(n + 1, o.size())):
		return false
	for c in o:
		g.plots[c].st = n + 1
		if c < 12 and lang != null and lang.F != null:
			lang.F.ts(c, "unlock")
	toast.emit("Nâng " + str(o.size()) + " ô ruộng lên " + str(n) + "★.")
	vib(15)
	mark()
	return true

func early_cost(nd: Dictionary, fee: int) -> int:   # zF: r = fee + mL(thiếu) + bL(thiếu xu)
	var r := fee
	for m in nd.m:
		var lack := int(m[1]) - mat_n(m[0])
		if lack > 0:
			r += lack * (4 if m[0] == "gach" else 3)
	var e := maxi(0, int(nd.xu) - int(g.coins))
	if e > 0:
		r += maxi(1, int(ceil(e / 25.0)))
	return r

func early_go(nd: Dictionary, fee: int, go: Callable) -> bool:   # zF nút "Nâng ngay": trả sen đỏ, bù phần thiếu, z3 = 1 rồi nâng; hỏng thì hoàn lại
	var r := early_cost(nd, fee)
	if int(g.get("ngoc", 0)) < r:
		toast.emit("Còn thiếu " + str(r - int(g.get("ngoc", 0))) + " sen đỏ.")
		return false
	var lack := []
	for m in nd.m:
		var d := int(m[1]) - mat_n(m[0])
		if d > 0:
			lack.append([m[0], d])
	var e := maxi(0, int(nd.xu) - int(g.coins))
	g.ngoc = int(g.ngoc) - r
	for d in lack:
		mat_add(d[0], d[1])
	g.coins = int(g.coins) + e
	z3 = true
	var p := false
	p = go.call()
	z3 = false
	if not p:
		g.ngoc = int(g.ngoc) + r
		for d in lack:
			mat_add(d[0], -d[1])
		g.coins = int(g.coins) - e
		toast.emit("Chưa nâng được, đã hoàn lại sen đỏ.")
	else:
		nv.spent(r)
	mark()
	return p

func kho_up() -> bool:   # mp
	var t := kho_star()
	if t >= 10:
		return false
	var a := kho_need(t + 1)
	if not _pay(a):
		return false
	g.khost = t + 1
	toast.emit("Kho lên " + str(t + 1) + "★: chứa được " + str(KHO_VP[t + 1]) + " món.")
	vib(15)
	mark()
	return true

func kho_up_early() -> bool:   # zF "nâng sớm": trả sen đỏ bù cấp + phần thiếu, rồi nâng như thường (z3 bỏ qua cấp)
	var t := kho_star()
	if t >= 10:
		return false
	var a := kho_need(t + 1)
	if not early_ok(int(a.lv)):
		return false
	var r := kho_early_cost(a)
	if int(g.ngoc) < r:
		toast.emit("Còn thiếu " + str(r - int(g.ngoc)) + " sen đỏ.")
		return false
	g.ngoc = int(g.ngoc) - r
	nv.spent(r)
	for m in a.m:
		var lack := int(m[1]) - mat_n(m[0])
		if lack > 0:
			mat_add(m[0], lack)
	var e := maxi(0, int(a.xu) - int(g.coins))
	g.coins = int(g.coins) + e
	var b := a.duplicate()
	b.lv = 0
	if not _pay(b):
		return false
	g.khost = t + 1
	toast.emit("Kho lên " + str(t + 1) + "★: chứa được " + str(KHO_VP[t + 1]) + " món.")
	vib(15)
	mark()
	return true

func _kho_mig() -> void:   # XH + _H + LJ (chạy mỗi lượt luật)
	if not g.get("khv", 0):   # XH: sao kho ban đầu theo cấp
		var a := 1
		for n in range(2, 11):
			if lv() >= KHO_LV[n]:
				a = n
		if int(g.get("khost", 0)) < a:
			g.khost = a
		g.khv = 1
	if not g.get("khv2", 0):   # _H: hàng cũ nhiều hơn sức chứa thì cho chứa thêm tạm
		g.khv2 = 1
		var n: int = kho_n() + 30 - KHO_VP[kho_star()]
		if n > 0:
			g.khoB = n
			var msg := "Kho giờ có sức chứa " + str(kho_star()) + "★. Hàng đang có được chứa thêm tạm " + fmt_n(n) + " món; bán bớt hàng thì phần chứa thêm thu lại dần."
			get_tree().create_timer(3.0).timeout.connect(func(): toast.emit(msg))
	if int(g.get("khoB", 0)) > 0:   # LJ: phần chứa thêm thu lại dần
		var t: int = maxi(0, kho_n() + 30 - KHO_VP[kho_star()])
		if t < int(g.khoB):
			g.khoB = t

func kho_fit(n: int = 1) -> bool:   # g8
	if kho_n() + maxi(1, n) > kho_cap():
		_kho_full()
		return false
	return true

func _kho_full() -> void:   # lL
	var t := Time.get_ticks_msec()
	if t - _kf_t < 2500 and _kf_t != 0:
		return
	_kf_t = t
	toast.emit("Kho đầy (" + fmt_n(kho_n()) + "/" + fmt_n(kho_cap()) + "). Bán bớt hoặc nâng kho rồi mới lấy thêm hàng.")
	var now := _now_ms()
	if g.get("kfpop", 0) and now - float(g.kfpop) < 60000.0:
		return
	kho_full.emit(kho_n(), kho_cap())   # ui quyết định có mở bảng không (không mở khi đang xây dựng)

# ------------------------------------------------------------------ loop
func _ready() -> void:
	cfg_load()
	nv = load("res://logic/nv.gd").new(self)
	troi = load("res://logic/troi.gd").new(self)
	_load_data()
	xw = load("res://logic/xuong.gd").new(self)
	vn = load("res://logic/vatnuoi.gd").new(self)
	w_all = load("res://logic/w_all.gd").new(self)   # NTWEB
	load_game()
	xw.sync_pos()

func _process(dt: float) -> void:
	# luật chạy 4 lần mỗi giây, không theo từng khung hình
	# đo bằng đồng hồ thật (khung hình chậm vẫn đúng giờ); hở lâu hơn 5 s thì tính như chơi bù
	if troi != null:
		troi.step(dt)
	var now := Time.get_ticks_msec()
	if _last_ms == 0:
		_last_ms = now
	_tick_acc = (now - _last_ms) / 1000.0
	if _tick_acc >= 0.25:
		var t := _tick_acc
		_last_ms = now
		if t > 5.0:
			catch_up(t)
			t = 0.25
		var before := _sig()
		_grow(t)
		if w_all != null:   # NTWEB vw đuôi
			w_all.step(t, false)
		xw.step(t)
		vn.step(t)
		_bug_step(t)
		_ray_step(t)
		_mk_step(t)
		_kho_mig()
		_cloud_step(t)
		_ord_step(t)
		nv.step(t)
		_en_t -= t
		if _en_t <= 0.0:
			_en_t = 1.0
			_regen()
		if _sig() != before:
			changed.emit()
	if w_all != null:   # NTWEB các bước mỗi khung
		w_all.frame(dt)
	_save_t += dt
	if _save_t > 5.0:
		_save_t = 0.0
		if dirty:
			save_game()

# ------------------------------------------------------------------ đơn hàng (fh, U3, ks, Ed, rI, L1 bản web)
# nhóm món của tiệm (UA, ZF): món không thuộc nhóm nào là "khac"
const UA := {
	"hat": ["lua", "nep", "bap", "dau_nanh", "dau_xanh", "dauphong", "me", "huong_duong", "dau_den"],
	"rau": ["rau_muong", "hanh", "cai", "carot", "bido", "catim", "ot", "cachua", "khoai", "xa_lach", "hanh_tay", "dua_leo", "bau", "bi_dao", "kho_qua", "dau_rong", "dau_bap", "khoai_mon", "muop"],
	"gvi": ["sa", "rau_ram", "gung", "nghe", "la_dua", "tieu"],
	"traic": ["dau", "duahau", "mia"],
	"soi": ["cham", "bong_vai", "len"],
	"trung": ["trung", "trung_vit"],
	"sua": ["sua", "sua_de"],
	"thit": ["thit_ga", "thit_cuu", "thit_bo", "thit", "suon", "thit_de", "thit_vit"]}
const Y8 := 300000.0      # đổi đơn: khách mới tới sau 5 phút
var ppos := Vector2(6.3, 4.6)   # chỗ nhân vật (farm.gd cập nhật): chữ "+1 ..." bay lên ở đó
var _ord_t := 2.0         # YY mỗi 60 s
var _slot_t := 0.0        # U3 mỗi 1,5 s
var _slots := -1

func ord_slots() -> int:   # iN
	var t := lv()
	return 9 if t >= 50 else 6 if t >= 30 else 4 if t >= 15 else 3

func _zf(t: String) -> String:
	for a in UA:
		if UA[a].has(t):
			return a
	return "khac"

func _g3(shop: String, t: String) -> bool:   # tiệm này có cần món này không
	var n = D.need.get(shop)
	if n == null:
		return true
	return n.get("i", {}).has(t) or n.get("c", {}).has(_zf(t))

const QR_MAKE := {"ga": ["trung", "thit_ga"], "cuu": ["len", "thit_cuu"], "bo": ["sua", "thit_bo"], "heo": ["thit", "suon"], "de": ["sua_de", "thit_de"]}
const BB_LV := {"ga": 1, "bo": 6, "heo": 10, "cuu": 13, "de": 20}
const DI := ["ga", "cuu", "bo", "heo", "de"]
const WF := ["ca_ro", "ca_tre", "ca_chep", "tom", "ca_loc", "ca_koi"]
const WV := ["ruong", "mill", "oven", "muoi", "ep", "rang", "duong", "kho", "say", "btrang", "det", "nuong", "bepcui", "quanche", "lobanh", "hangcha"]

func _pen_n(r: String) -> int:   # g.pens[r].length
	var P = g.get("pens", {})
	return (P[r] as Array).size() if P is Dictionary and P.get(r) is Array else 0

func cd(t: String) -> bool:   # Cd: đã xây ít nhất một xưởng loại t
	if xw == null:
		return false
	for k in xw.N0:
		if xw.sr[k].type == t and xw.built(k):
			return true
	return false

var _ds := {}
func bf(t: String, a := 0) -> int:   # Bf: cấp mở món t (cây, trái, chuồng, cá; món xưởng = max cấp xưởng và nguyên liệu)
	if _ds.is_empty():
		for r in xo:
			if not crop(r).get("hyb", false):
				_ds[r] = int(crop(r).get("lv", 1))
		var Ei = lang.C.Ei if lang != null else {}
		for r in Ei:
			_ds[String(Ei[r].p)] = int(Ei[r].get("lv", 1))
		for r in DI:
			for m in QR_MAKE[r]:
				_ds[m] = int(BB_LV.get(r, 1))
		for r in WF:
			_ds[r] = 5      # V4.cau
		_ds["luon"] = 7     # V4.lo
		_ds["oc"] = 1
		_ds["ca_keo"] = 1
		_ds["luc_binh"] = 1
	if _ds.has(t):
		return _ds[t]
	var n = xw.R.get(t) if xw != null else null
	if n == null or a > 9:
		return 1
	var e: int = int(xw.T[String(n.w)].get("lv", 1)) if xw.T.has(String(n.w)) else 1
	for r in n["in"]:
		e = maxi(e, bf(String(r[0]), a + 1))
	_ds[t] = e
	return e

var _i8 := {}
var _ep := 0
func _f8(t: String, a := 0) -> bool:   # F8: món còn làm ra được (hoặc đang có trong kho)
	if a > 4:
		return false
	var nw := _now_ms()
	if nw - _ep > 3000:
		_i8 = {}
		_ep = nw
	if _i8.has(t):
		return _i8[t]
	_i8[t] = false
	var e := lv()
	var r := false
	var Ei = lang.C.Ei if lang != null else {}
	var fruit := false
	for l in Ei:
		if String(Ei[l].p) == t:
			for c in (lang.objs() if lang != null else []):
				if c is Dictionary and c.get("id") == l:
					fruit = true
	var pen := false
	for l in DI:
		if QR_MAKE[l].has(t) and _pen_n(l) > 0:
			pen = true
	if D.crops.has(t):
		r = (not crop(t).get("hyb", false) and int(crop(t).get("lv", 1)) <= e) or int(g.barn.get(t, 0)) > 0
	elif fruit:
		r = true
	elif pen:
		r = true
	elif t == "thit_vit" or t == "trung_vit":
		r = int(g.barn.get(t, 0)) > 0      # vịt: chưa có ở bản Godot
	elif WF.has(t) or t == "luon" or t == "oc" or t == "ca_keo":
		r = int(g.barn.get(t, 0)) > 0      # cá (lc): ao câu chưa có ở bản Godot
	elif xw != null and xw.R.has(t):
		var o: Dictionary = xw.R[t]
		r = cd(String(o.w)) and bf(t) <= e and not o.get("fest", "")   # lễ hội (Vx): chưa có ở bản Godot
		if r:
			for l in o["in"]:
				if not _f8(String(l[0]), a + 1):
					r = false
					break
	_i8[t] = r
	return r

func _lv_items() -> Array:   # Lv (+ bọc F8)
	_ep = 0
	var a := lv()
	var n := []
	for r in xo:
		if not crop(r).get("hyb", false) and int(crop(r).get("lv", 1)) <= a:
			n.append(r)
	var e: Array = n.slice(maxi(0, n.size() - 5))
	if n.size() > 5:
		e.append(n[randi() % (n.size() - 5)])
	for r in DI:
		if _pen_n(r) > 0:
			e.append(QR_MAKE[r][0])
			e.append(QR_MAKE[r][1])
	if cd("mill"):
		e.append("bot")
	if cd("oven"):
		e.append("banh")
		if _pen_n("bo") > 0:
			e.append("kem")
	if xw != null:
		for r in WV:
			if r == "mill" or r == "oven" or not cd(r) or not xw.T.has(r):
				continue
			for o in xw.T[r].rec:
				if randf() < 0.5 and bf(String(o)) <= a:
					e.append(String(o))
	return e.filter(func(x): return _f8(x))

static func _pick(a: Array):
	return a[randi() % a.size()]

func _sell0(t: String) -> float:
	return float(item(t).get("sell", 10))

func _fh0() -> Dictionary:
	var t := []
	for x in _lv_items():
		if not t.has(x):
			t.append(x)
	var a := mini(4, int(floor(int(g.delivered) / 2.0)))
	var r := lv()
	var l := (20.0 + 10.0 * mini(60, r) + 6.0 * a) * randf_range(0.8, 1.2)
	var busy := {}
	for w in g.orders:
		if w is Dictionary and w.has("who"):
			busy[w.who] = 1
	var s := []
	for w in D.who:
		if not busy.has(w):
			s.append(w)
	if s.is_empty():
		s = D.who.duplicate()
	var h := {}
	var p := 0
	for w in s:
		var E := t.filter(func(c): return _g3(D.shop[w], c))
		h[w] = E
		p = maxi(p, E.size())
	var o := mini(3, p)
	var d := s.filter(func(w): return h[w].size() >= o) if o > 0 else []
	var v: String
	var x: String
	if not d.is_empty():
		var k := []
		for w in d:
			for c in h[w]:
				if not k.has(c):
					k.append(c)
		x = _pick(k)
		v = _pick(d.filter(func(w): return h[w].has(x)))
	else:
		v = "Bà Tư" if s.has("Bà Tư") else _pick(s)
		x = _pick(t) if not t.is_empty() else "lua"
		o = 1
		h[v] = [x]
	var M: String = D.shop.get(v, _pick(["quán cơm", "tiệm bánh", "quán chè", "nhà hàng", "quầy rau", "trường mầm non", "tiệm tạp hóa", "quán phở"]))
	var T: Array = h[v].filter(func(w): return w != x)
	var n := [x]
	o = mini(o, 1 + T.size())
	while n.size() < o:
		n.append(T.pop_at(randi() % T.size()))
	var e := 0.0
	var c := []
	for w in n:
		var q := clampi(int(round(l / o / _sell0(w))), 1, 15)
		e += q * _sell0(w)
		c.append([w, q])
	return {"who": v, "shop": M, "items": c, "reward": int(round(e * randf_range(1.5, 1.8))), "sf": 1, "m3": 2}

func _fh1() -> Dictionary:
	# vá 1: đơn phải có ít nhất 1 món làm ra được (thử 8 lần)
	for n in 8:
		var e := _fh0()
		for r in e.items:
			if D.crops.has(r[0]) or int(g.barn.get(r[0], 0)) > 0:
				return e
	return _fh0()

func new_order() -> Dictionary:   # fh: 45% đơn cố có món được giá hôm nay; có thì thưởng x1,3
	var r := _fh1()
	var o := hot().map(func(c): return c[0])
	var has := func(q): return q.items.any(func(c): return o.has(c[0]))
	if randf() < 0.45:
		var l := 0
		while l < 6 and not has.call(r):
			r = _fh1()
			l += 1
	if has.call(r):
		r.reward = int(round(r.reward * 1.3))
		r.hot = day()
	return r

func ord_fill() -> bool:   # U3
	var t: int = g.orders.size()
	while g.orders.size() < ord_slots():
		g.orders.append(new_order())
	return g.orders.size() > t

func ord_wait(o: Dictionary) -> bool:
	return float(o.get("w", 0)) > _now_ms()

func ord_plan() -> Array:   # zA: chia hàng trong kho cho các đơn, đơn đủ trước giữ hàng trước
	var a := {}
	var out := []
	var cnt := func(r): return a[r] if a.has(r) else int(g.barn.get(r, 0))
	for o in g.orders:
		if ord_wait(o):
			out.append(null)
			continue
		var ok: bool = o.items.all(func(c): return cnt.call(c[0]) >= int(c[1]))
		if ok:
			for c in o.items:
				a[c[0]] = cnt.call(c[0]) - int(c[1])
		out.append({"ok": ok, "have": o.items.map(func(c): return int(c[1])) if ok else null, "miss": []})
	for q in g.orders.size():
		var l = out[q]
		if l == null or l.ok:
			continue
		var o: Dictionary = g.orders[q]
		l.have = o.items.map(func(c): return maxi(0, mini(cnt.call(c[0]), int(c[1]))))
		var m := []
		for f in o.items.size():
			var d: int = int(o.items[f][1]) - int(l.have[f])
			if d > 0:
				m.append([o.items[f][0], d])
		l.miss = m
	return out

func lack_cost(items: Array) -> int:   # H2: sen đỏ để bù phần thiếu
	var a := 0.0
	for n in items:
		a += _sell0(n[0]) * int(n[1])
	return maxi(1, int(ceil(a / 20.0)))

func missing(items: Array) -> Array:   # zu
	var out := []
	for a in items:
		var d := int(a[1]) - int(g.barn.get(a[0], 0))
		if d > 0:
			out.append([a[0], d])
	return out

func deliver(i: int) -> Variant:   # ks (+ vá: khách chưa tới, thiếu hàng -> bảng bù)
	if i < 0 or i >= g.orders.size():
		return null
	var x: Dictionary = g.orders[i]
	if ord_wait(x):
		toast.emit("Khách mới chưa tới.")
		return null
	var k := missing(x.items)
	if not k.is_empty():
		return {"lack": k, "why": "Đơn của " + str(x.who) + " còn thiếu:"}
	for e in x.items:
		g.barn[e[0]] = int(g.barn.get(e[0], 0)) - int(e[1])
	var c0 := int(g.coins)   # NTWEB ks bọc
	g.coins = int(g.coins) + int(x.reward)
	g.delivered = int(g.delivered) + 1
	nv.qi("deliver")
	nv.bt_deliver(int(x.reward))
	add_xp(maxi(4, int(round(x.reward / 8.0))), "deliver")
	_drop_at("deliver", ppos)
	toast.emit("Giao hàng cho " + str(x.who) + ", nhận " + fmt_n(x.reward) + " xu.")
	if w_all != null:   # NTWEB ks bọc: giá chợ + mối ruột (Hệ Thống)
		w_all.WS.ht_deliver(c0)
	g.orders[i] = new_order()
	mark()
	return true

func swap(i: int) -> void:   # Ed + vá: khách mới tới sau 5 phút
	g.orders[i] = new_order()
	toast.emit("Đã đổi sang một đơn khác.")
	g.orders[i].w = _now_ms() + Y8
	mark()

func call_cost(o: Dictionary) -> int:
	return maxi(1, int(ceil((float(o.get("w", 0)) - _now_ms()) / 150000.0)))

func spend_ngoc(n: int) -> bool:   # sc
	if int(g.ngoc) < n:
		toast.emit("Cần " + str(n) + " sen đỏ, đang có " + str(int(g.ngoc)) + ".")
		return false
	g.ngoc = int(g.ngoc) - n
	nv.spent(n)
	return true

func call_now(i: int) -> void:   # rI "ngcall": gọi khách ngay bằng sen đỏ
	var n: Dictionary = g.orders[i]
	if not spend_ngoc(call_cost(n)):
		return
	n.w = 0
	toast.emit("Khách mới tới rồi!")
	mark()

func buy_lack(items: Array) -> bool:   # L1 "ok": bù phần thiếu bằng sen đỏ
	var r := lack_cost(items)
	if int(g.ngoc) < r:
		toast.emit("Còn thiếu " + str(r - int(g.ngoc)) + " sen đỏ.")
		return false
	g.ngoc = int(g.ngoc) - r
	nv.spent(r)
	for p in items:
		g.barn[p[0]] = int(g.barn.get(p[0], 0)) + int(p[1])
	mark()
	return true

func _drop_at(key: String, at: Vector2) -> void:
	var L = D.drop.get(key, [])
	var got := []
	for r in L:
		if randf() < float(r[1]):
			var id: String = r[0]
			mat_add(id, 1)
			got.append(item_name(id))
	if not got.is_empty():
		float_text.emit(at.x, at.y - 0.3, "+1 " + ", +1 ".join(got))

func _ord_step(t: float) -> void:
	_slot_t -= t
	if _slot_t <= 0.0:
		_slot_t = 1.5
		var a := ord_slots()
		if _slots >= 0 and a > _slots and g.orders.size() < a:
			ord_fill()
			toast.emit("Lên cấp mở thêm ô đơn hàng: giờ nhận được " + str(a) + " đơn cùng lúc!")
			mark()
		elif g.orders.size() < a:
			ord_fill()
			mark()
		_slots = a
	_ord_t -= t
	if _ord_t <= 0.0:
		_ord_t = 60.0
		# YY: đơn có món không còn làm ra được thì đổi đơn khác
		var ch := false
		for n in g.orders.size():
			var o: Dictionary = g.orders[n]
			if not ord_wait(o) and not o.items.all(func(e): return _f8(e[0]) or int(g.barn.get(e[0], 0)) >= int(e[1])):
				g.orders[n] = new_order()
				ch = true
		if ch:
			mark()

func _sig() -> String:
	# đổi giai đoạn cây / nước / sâu thì báo vẽ lại
	var s := ""
	for a in g.plots:
		if a.c != null:
			s += str(stage(a)) + ("w" if float(a.w) > 0.0 else "") + ("b" if a.get("b", 0) else "")
		s += ","
	return s + str(int(g.pc.en))

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if not g.is_empty():
			save_game()
