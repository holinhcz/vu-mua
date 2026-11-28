extends CanvasLayer
# Bảng của bản web Nông Trại Nhỏ, dựng lại từ số đo của trình duyệt (res://ui/snap/*.json) và chạy
# theo luật game.gd: thanh trên (HUD), Menu, khay chọn giống (module "gieo" của web), vòng nút ô ruộng
# (module "ring"), bảng ô chưa mở (#ppop), Kho, thông báo (ta). Vẽ theo điểm ảnh thật (Css.K = dpr).

const Css = preload("res://ui/css.gd")
const Sen = preload("res://ui/sen.gd")
const SEN_LE := 13.0   # lề hai bên bảng khung sen (css px)
const Snap = preload("res://ui/snap.gd")
const Qty = preload("res://logic/qty.gd")
const Box = preload("res://ui/box.gd")
const Khuon = preload("res://ui/khuon.gd")
const VW0 := 338.0           # khổ màn hình lúc chụp số đo (css px)
const VH0 := 610.0
const RA := 28.5             # bán kính vòng nút (svg 64)
const CIRC := 179.0707812    # 2 pi RA
const SOON := "Phần này đang chuyển qua bản Godot."

var G: Node
var P: Node
var F: Node2D
var main: Node2D
var vw := VW0
var vh := VH0
var root: Control
var dpr_v := 1.0             # devicePixelRatio
var kh := {"k": "doc", "co": "nho", "r": 0.55, "s": 0.75}   # Wi của bản web: khuôn màn hình hiện tại
var U := 1.0                 # độ to giao diện so với lúc chụp số đo: Wi.s / 0,75
var anchors := []            # [Box, ax, ay]: lệch theo khổ màn hình thật
var hid := {}                # ids của thanh trên
var focus := false           # body.rmfocus
var _t := 0.0
var _vs := Vector2.ZERO
var nvp = null               # bảng Sổ nhiệm vụ (ui_nv.gd)
var bdp = null               # bảng XÂY DỰNG (ui_bd.gd)
var kdp = null               # Kho › Đồ dùng (ui_kdd.gd)
var bfp = null               # vòng hiệu ứng dưới ô giờ (ui_bf.gd)
var setp = null              # bảng CÀI ĐẶT (ui_set.gd)
var vlp = null               # bảng NHÀ DÂN (ui_vl.gd)
var ngp = null               # bảng NGHỀ THỦ CÔNG (ui_ng.gd)
var slp = null               # bảng SỔ LÀNG (ui_sl.gd)
var utp = null               # bảng UY TÍN LÀNG (ui_ut.gd)
var hrp = null               # bảng NGƯỜI LÀM THUÊ (ui_hr.gd)
var gpp = null               # bảng GIA PHẢ (ui_gp.gd)
var ghp = null               # (bản 515) bảng GHE THƯƠNG HỒ (ui_gh.gd)
var chop = null              # (bản 517) bảng CHỢ NỔI (ui_cho.gd)
var lopp = null              # (bản 547) bảng LỜ LỌP (ui_lop.gd): Menu › Làm ăn › Lờ lọp
var lgp = null               # (11-25) bảng NUNG GẠCH (ui_lg.gd): chạm lò gạch
var ccpp = null              # (bản 535) bảng CÂU CÁ trên khung Kho (ui_ccp.gd): Giỏ cá, Mồi, Đồ nghề, Sổ cá, Cài đặt
var tnp = null               # bảng THIÊN TAI (ui_tn.gd)
var hdnp = null              # bảng HỘI ĐÌNH (ui_hdn.gd)
var clgp = null              # bảng CHUYỆN LÀNG (ui_clg.gd)
var sysp = null              # bảng HỆ THỐNG (ui_sys.gd)
var dlp = null               # bảng DU LỊCH MIỆT VƯỜN (ui_dl.gd)
var ddp = null               # bảng ĐIỂM DANH (ui_dd.gd)
var napp = null              # bảng NẠP ĐẦU (ui_nap.gd)
var ttp = null               # bảng 7 NGÀY VỀ LÀNG (ui_tt.gd)
var skyp = null              # bảng TRỜI ĐẤT TRONG LÀNG (ui_sky.gd)
var thup = null              # bảng THƯ NHÀ (ui_thu.gd)
var klp = null               # bảng KỶ LỤC (ui_kl.gd)
var klcp = null              # thẻ TRÁI KHỦNG (ui_klc.gd)
var gdp = null               # SỔ TAY (ui_gd.gd)
var rkp = null               # BẢNG XẾP HẠNG (ui_rk.gd)
var lvp = null               # bảng LÊN CẤP (ui_lv.gd)
var pcp = null               # bảng Nhân vật (ui_pc.gd)
var cgp = null               # CỜ GÁNH (ui_cg.gd, #cgBtn trong Giải trí)
var oqp = null               # Ô ĂN QUAN (ui_oq.gd, #oqBtn trong Giải trí)
var xtp = null               # XẾP TRÁI (ui_xt.gd, #xtBtn trong Giải trí)
var tsop = null              # TÌM SỐ (ui_tso.gd, #tsoBtn trong Giải trí)
var ccp = null               # CÂU CÁ BỜ KÊNH (ui_cc.gd, nút "Câu cá" trong Giải trí)
var dgp = null               # ĐUA GÀ (ui_dg.gd, #dgBtn trong Giải trí)
var carop = null             # CỜ CARO (ui_caro.gd, #caroBtn trong Giải trí)
var spp = null               # Nâng sao ô ruộng (ui_sao.gd)
var ordp = null              # (11-27) Đơn hàng trên khung chung (ui_ord2.gd)
var dkp = null               # (11-28) Menu trên khung chung (ui_dock2.gd), thay bảng chụp web dock
var kupp = null              # (11-28) Nâng sao kho / nâng sớm trên khung chung (ui_kup.gd, tạo ở ui_kho.kup())
var khop = null              # (11-27) Kho trên khung chung (ui_kho2.gd), thay 4 bản chụp web khi Sen.ON
var khp = null               # sức chứa kho, Nâng sao kho, Kho đầy, Nâng sớm (ui_kho.gd)

func setup(game: Node, pics: Node, farm: Node2D, dpr: float) -> void:
	G = game
	P = pics
	F = farm
	main = farm.main if "main" in farm and farm.main != null else get_parent()
	dpr_v = maxf(1.0, dpr)
	kh = Khuon.tinh(get_viewport().get_visible_rect().size.x / dpr_v, get_viewport().get_visible_rect().size.y / dpr_v)
	U = _calc_u(get_viewport().get_visible_rect().size / dpr_v, kh)
	Css.K = dpr_v * U
	_web_zoom()
	layer = 10
	root = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_preset(Control.PRESET_FULL_RECT)   # NTWEB: gốc phủ cả màn hình, bảng neo đáy/giữa (cây ăn trái, chợ nổi, lễ hội) mới nằm trong màn
	add_child(root)
	_build_dim()
	_build_hud()
	_build_gv()
	_build_rm()
	_build_lock()
	_build_ord()
	_build_pc()
	nvp = load("res://logic/ui_nv.gd").new(self)
	lvp = load("res://logic/ui_lv.gd").new(self)
	setp = load("res://logic/ui_set.gd").new(self)
	xfp = load("res://logic/ui_xf.gd").new(self)
	bdp = load("res://logic/ui_bd.gd").new(self)
	khp = load("res://logic/ui_kho.gd").new(self)
	kdp = load("res://logic/ui_kdd.gd").new(self)
	khop = load("res://logic/ui_kho2.gd").new(self)
	ordp = load("res://logic/ui_ord2.gd").new(self)
	dkp = load("res://logic/ui_dock2.gd").new(self)
	bfp = load("res://logic/ui_bf.gd").new(self)
	spp = load("res://logic/ui_sao.gd").new(self)
	pcp = load("res://logic/ui_pc.gd").new(self)
	cgp = load("res://logic/ui_cg.gd").new(self)
	oqp = load("res://logic/ui_oq.gd").new(self)
	xtp = load("res://logic/ui_xt.gd").new(self)
	tsop = load("res://logic/ui_tso.gd").new(self)
	ccp = load("res://logic/ui_cc.gd").new(self)
	dgp = load("res://logic/ui_dg.gd").new(self)
	carop = load("res://logic/ui_caro.gd").new(self)
	G.kho_full.connect(_kho_full)
	G.changed.connect(func(): _sync_hud())
	G.toast.connect(say)
	G.level_up.connect(func(_n, _g): if lvp != null: lvp.lvT = 2.5)
	if G.w_all != null:   # NTWEB: bảng của các mô-đun dịch từ web
		G.w_all.ui_setup(self)
	_layout()
	_sync_hud()

func main_ready(m: Node2D) -> void:
	main = m

# ------------------------------------------------------------------ helpers
func _build(n: Dictionary, ids: Dictionary, origin := Vector2.ZERO) -> Control:
	return Snap.build(n, origin, ids)

func _q(b: Control, cls: String, tag := "") -> Control:
	# the first Box under b (depth first) built from an element with this class
	for k in b.kids():
		var n: Dictionary = k.get_meta("snap", {})
		if (cls == "" or String(n.get("cls", "")).split(" ").has(cls)) and (tag == "" or n.get("tag", "") == tag):
			return k
		var f := _q(k, cls, tag)
		if f != null:
			return f
	return null

func _qall(b: Control, cls: String, out: Array) -> Array:
	for k in b.kids():
		var n: Dictionary = k.get_meta("snap", {})
		if String(n.get("cls", "")).split(" ").has(cls):
			out.append(k)
		_qall(k, cls, out)
	return out

func _txt(b: Control, s: String) -> void:
	if b == null or b.texts.is_empty():
		return
	var i: int = b.get_meta("ti", 0)
	b.set_text(i, String(b.get_meta("prefix", "")) + s + String(b.get_meta("suffix", "")))

func _sm(b: Control) -> Dictionary:   # bản chụp gốc của nút (meta "snap"); thiếu thì {}
	return b.get_meta("snap") if b.has_meta("snap") else {}

func _move(b: Control, p: Vector2) -> void:
	b.r.position = p
	b.position = p * Css.K

func _click(b: Control, cb: Callable, fx := "down") -> void:
	if b == null:
		return
	b.clickable(fx)
	b.pressed.connect(func() -> void:   # (bản 511) mọi nút: đánh dấu đang xử lý cú bấm, bong bóng đặt trên nút này
		tap_on += 1
		last_btn = b
		last_btn_ms = Time.get_ticks_msec()
		if not _warn_tap(b):   # nút có "!": chạm lần này hiện lý do, chạm lần sau mới làm việc
			cb.call()
		tap_on -= 1)

func _stop(b: Control) -> void:
	# a panel: swallow taps so they do not reach the village under it
	b.mouse_filter = Control.MOUSE_FILTER_STOP

func vsize() -> Vector2:
	return get_viewport().get_visible_rect().size / Css.K

func _layout() -> void:
	var v := vsize()
	vw = v.x
	vh = v.y
	_vs = v
	# bảng toàn màn (#pov 338x610, giữa màn): màn thấp hơn khuôn (điện thoại còn thanh trình duyệt trên dưới) thì thu cả bảng
	# cho vừa chiều cao, như bản web để .pwin cao 100% màn; không thì đáy bảng bị cắt
	var fp := minf(1.0, vh / VH0)
	if Sen.ON:   # (11-26) khung sen: bảng chừa lề hai bên như ảnh mẫu (hoa sen, dây tua lòi ra ngoài khung không bị cắt)
		fp = minf(fp, (vw - 2.0 * SEN_LE) / VW0)
	Box.PS = fp   # (11-27) chữ trong bảng bù tỉ lệ thu bảng: cỡ chữ = px thật như trên S26
	for a in anchors:
		var b: Control = a[0]
		if is_instance_valid(b):
			var f := fp if a[1] == 0.5 and a[2] == 0.5 and _full_pov(b) else 1.0
			b.scale = Vector2(f, f)
			b.position = (b.r.position * f + Vector2((vw - VW0 * f) * a[1], (vh - VH0 * f) * a[2])) * Css.K
	if dim != null:
		dim.size = v * Css.K
	# lớp tối phủ cả màn (.pbk, nền popup: số đo 0,0,338x610): luôn phủ kín màn thật, không chỉ khổ lúc chụp
	for a in anchors:
		if is_instance_valid(a[0]):
			_cover(a[0], v / a[0].scale.x)

static func _full_pov(b: Control) -> bool:   # gốc là cả khuôn màn 338x610 (#pov, lớp tối bảng)
	var rr = b.get_meta("snap", {}).get("r", [])
	return rr is Array and rr.size() == 4 and absf(float(rr[2]) - VW0) < 0.5 and absf(float(rr[3]) - VH0) < 0.5

func _cover(b: Control, v: Vector2) -> void:
	for k in b.kids():
		var n: Dictionary = k.get_meta("snap", {})
		var rr = n.get("r", [])
		if rr is Array and rr.size() == 4 and absf(float(rr[0])) < 0.5 and absf(float(rr[1])) < 0.5 and absf(float(rr[2]) - VW0) < 0.5 and absf(float(rr[3]) - VH0) < 0.5:
			var gp: Vector2 = root.global_position
			k.place(Rect2(k.r.position, v))
			k.global_position = gp
		_cover(k, v)

func plot_css(i: int, h := -1.0) -> Vector2:
	# R1(en(gx+.5, gy+.5), nn(gx+.5, gy+.5, co)): tâm ô ruộng trên màn hình, css px
	var c: Dictionary = G.cells[i]
	var w := Vector2(F.en(c.gx + 0.5, c.gy + 0.5), F.nn(c.gx + 0.5, c.gy + 0.5, G.CO if h < 0.0 else h))
	return (w - main.cam) * main.zoom / Css.K

func bz() -> float:
	# ba.z của bản web: css px thật cho mỗi đơn vị làng
	return main.zoom / dpr_v

func _web_zoom() -> void:
	# uu(): zoom tối đa 1,7·s; kh() (zoom nhỏ nhất) làng tự tính
	if main != null and "zmax" in main:
		main.zmax = 1.7 * float(kh.s) * dpr_v

func web_start_cam() -> void:
	# rM(): lúc vào làng zoom 0,7·s, nhà chính lệch trái một chút (28·s, màn rộng 36·s)
	var vs := get_viewport().get_visible_rect().size / dpr_v
	var s := float(kh.s)
	var n := (28.0 if vs.x < 700.0 else 36.0) * s
	var z := clampf(0.7 * s, main.zmin / dpr_v, main.zmax / dpr_v)
	main.zoom = z * dpr_v
	main.cam = Vector2(4268.0 + 10.0 - (vs.x / 2.0 - n) / z, 968.0 + 105.0 - vs.y / 2.0 / z)
	if main.has_method("_clamp_cam"):
		main._clamp_cam()

func cz() -> float:
	# độ phóng của bản web (ba.z): css px cho mỗi đơn vị làng
	return main.zoom / Css.K

# ------------------------------------------------------------------ (bản 510) câu báo G.toast: không còn hộp báo trên đầu màn
# Chia theo lúc phát:
#  - ngay sau khi chạm (vừa bấm việc gì): có số "+N xu / được N xu…" -> chỉ số bay ở chỗ bấm; lỗi / cảnh báo / câu khác -> bong bóng
#    thông tin ngay trên nút vừa bấm (ui_kbang._dtip, kiểu nhãn ô ruộng);
#  - game tự phát (tin làng: thư, sét, xưởng xong, radio...): không hiện, ghi vào Chuyện làng (nút có chấm đỏ báo chuyện mới).
const NUMR := "(?:\\+\\s?|(?:nhận|được|thêm|thưởng|:)\\s)([\\d.]+)\\s?(xu|sen đỏ|kinh nghiệm|EXP|uy tín|♥|điểm|viên gạch|gạch)"
static var _numr: RegEx = null

func say(s: String) -> void:
	if s.strip_edges() == "":
		return
	if tap_on > 0:   # (bản 511) phản hồi việc đang xử lý cú bấm (nút bảng, nút màn, chạm làng): không đoán theo giờ
		if _numr == null:
			_numr = RegEx.create_from_string(NUMR)
		var parts := []
		for m in _numr.search_all(s):
			parts.append("+" + m.get_string(1) + " " + m.get_string(2))
		if parts.size() and not _is_err(s):
			fly("   ".join(PackedStringArray(parts.slice(0, 3))))
			return
		tip_text(s)
		return
	var wk := _warn_key(s)
	if wk != "":   # lỗi chặn việc lúc không bấm (kho đầy khi tự thu...): dấu "!" trên đúng nút liên quan, chạm nút đó hiện lý do
		warns[wk] = s
		_warn_sync()
	call_deferred("_news_log", s)   # tin làng: ghi Chuyện làng (sau clg_cap để khỏi ghi trùng)

var tap_on := 0                # (bản 511) > 0: đang chạy việc của một cú bấm
var tap_anchor := Rect2()      # chỗ đặt bong bóng khi bấm không phải nút bảng (làng: trên vật vừa chạm, nút màn: trên nút)
var tap_anchor_ms := 0
var warns := {}                # "kho" / "suc" -> câu lỗi chờ người chơi chạm xem
const WARN_AT := {"kho": "#dockBtn", "suc": "#pcAv"}
static func _warn_key(s: String) -> String:
	var t := s.to_lower()
	if t.contains("kho đầy"):
		return "kho"
	if t.contains("mệt") or t.contains("hết sức") or t.contains("đuối sức"):
		return "suc"
	return ""

func _warn_sync() -> void:   # vẽ / gỡ chấm "!" đỏ góc trên phải nút HUD
	for k in WARN_AT:
		var b = hid.get(WARN_AT[k])
		if not (b is Control):
			continue
		var d: Control = b.get_node_or_null("warn")
		if warns.has(k) and d == null:
			var lb := Label.new()
			lb.name = "warn"
			lb.text = "!"
			lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			lb.add_theme_font_override("font", Css.font(900))
			lb.add_theme_font_size_override("font_size", int(round(12.0 * Css.K)))
			lb.add_theme_color_override("font_color", Color.WHITE)
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color8(226, 64, 56)
			sb.set_corner_radius_all(int(9.0 * Css.K))
			sb.border_color = Color.WHITE
			sb.set_border_width_all(int(round(1.5 * Css.K)))
			lb.add_theme_stylebox_override("normal", sb)
			lb.size = Vector2(18, 18) * Css.K
			lb.position = Vector2((b as Control).size.x - 13.0 * Css.K, -5.0 * Css.K)
			lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(lb)
		elif not warns.has(k) and d != null:
			d.queue_free()

func _warn_tap(b: Control) -> bool:   # chạm nút đang có "!": hiện lý do (bong bóng trên nút), gỡ dấu; true = đã hiện
	for k in warns:
		if hid.get(WARN_AT[k]) == b:
			var s: String = warns[k]
			warns.erase(k)
			_warn_sync()
			if k == "kho" and G.kho_n() < G.kho_cap():   # đã hết đầy thì thôi
				return false
			tip_text(s)
			return true
	return false

static func _is_err(s: String) -> bool:   # câu lỗi / cảnh báo
	var t := s.to_lower()
	for k in ["chưa đủ", "không đủ", "thiếu", "đầy", "chưa tới cấp", "chưa mở", "chưa có", "hết lượt", "không được", "không thể", "phải "]:
		if t.contains(k):
			return true
	return false

func tip_text(s: String) -> void:   # bong bóng thông tin chữ trơn ngay trên nút vừa bấm
	if _tipper == null:
		_tipper = load("res://logic/ui_kbang.gd").new(self)
	_tipper._dtip(s)

func _news_log(s: String) -> void:
	if G == null or G.w_all == null or G.w_all.WL == null:
		return
	var o: Dictionary = G.w_all.WL.clg_s()
	var t := s.strip_edges()
	for r in (o.l as Array).slice(0, 30):
		if String(r.get("t", "")) == t:
			return
	G.w_all.WL.clg_add("nha", t)

func fly(s: String) -> void:   # (bản 505) chữ bay: kết quả bấm (+1.000 xu...) nổi lên từ chỗ chạm rồi mờ
	var lb := Label.new()
	lb.text = s
	lb.add_theme_font_override("font", Css.font(800))
	lb.add_theme_font_size_override("font_size", int(round(13.0 * Css.K)))
	lb.add_theme_color_override("font_color", Color8(40, 120, 50))
	lb.add_theme_color_override("font_outline_color", Color8(255, 252, 240))
	lb.add_theme_constant_override("outline_size", int(round(5.0 * Css.K)))
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_layer().add_child(lb)
	var sz := lb.get_minimum_size()
	var vp := get_viewport().get_visible_rect().size
	var p0 := Vector2(clampf(last_tap.x - sz.x * 0.5, 6.0, vp.x - sz.x - 6.0), last_tap.y - sz.y - 18.0 * Css.K)
	lb.position = p0
	var tw := lb.create_tween()
	tw.tween_property(lb, "position", p0 - Vector2(0, 46.0 * Css.K), 1.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(lb, "modulate:a", 0.0, 0.5).set_delay(0.8)
	tw.tween_callback(lb.queue_free)

func panel_rect() -> Rect2:   # (bản 506) thân bảng đang mở (vùng nội dung dưới hàng tab, css); rỗng = không có bảng
	for p in _pans() + [ngp, nvp, vlp]:
		if p != null and "on" in p and p.on and "box" in p and p.box != null and is_instance_valid(p.box) and p.box.visible:
			var w = (p.ids.get(".bk2v", p.ids.get(".pwin")) if "ids" in p else null)
			var c: Control = w if w is Control else p.box
			var r := c.get_global_rect()
			return Rect2(r.position / Css.K, r.size / Css.K)
	return Rect2()

# ------------------------------------------------------------------ (bản 504) bong bóng chạm xem: khung nhỏ ngay chỗ chạm (thay toast cho chữ giải thích)
var last_tap := Vector2.ZERO   # chỗ chạm xuống gần nhất (px)
var last_btn: Control = null   # (bản 506) ô bảng vừa bấm (ui_bang._on_b)
var last_btn_ms := 0
var _fx: CanvasLayer = null    # (bản 505) lớp trên cùng cho bong bóng, chữ bay (bảng tự dời lên trước mỗi khung nên không bỏ chung root được)
func fx_layer() -> CanvasLayer:
	if _fx == null or not is_instance_valid(_fx):
		_fx = CanvasLayer.new()
		_fx.layer = 90
		add_child(_fx)
	return _fx
var tip_b: Control = null
var _tip_t := 0.0
func tip_show(c: Control, sec := 3.5) -> void:
	tip_close()
	tip_b = c
	fx_layer().add_child(c)
	_tip_t = sec

func tip_close() -> void:
	if tip_b != null and is_instance_valid(tip_b):
		tip_b.queue_free()
	tip_b = null

static func _nlines(s: String, fs: float, fw: int, w: float) -> int:
	var n := 1
	var cur := ""
	for word in s.split(" "):
		var t := word if cur == "" else cur + " " + word
		if cur != "" and Box.text_w(t, fs, fw) > w:
			n += 1
			cur = word
		else:
			cur = t
	return n

# ------------------------------------------------------------------ HUD
const AX := {".hudtl": [0, 0], ".hudq": [0, 0.5], ".hudtr": [1, 0], ".zoomctl": [0, 1], ".autob": [0, 1], "#nvBtn": [1, 1], "#dockBtn": [1, 1]}
var hud_roots := {}
var focus_hide := []

static func _grow_w(n: Dictionary, x: float, d: float, pad := 1.5) -> void:
	# như _grow_at theo bề ngang: dời mọi thứ nằm bên phải x sang d, kéo rộng những gì chạm mép phải (trong khoảng pad)
	var x0 := float(n.r[0])
	var x1 := x0 + float(n.r[2])
	if x0 >= x - 0.5:
		Snap._move(n, Vector2(d, 0))
		return
	if x1 > x - pad and not n.has("text"):
		n.r = [n.r[0], n.r[1], float(n.r[2]) + d, n.r[3]]
	for k in n.get("kids", []):
		_grow_w(k, x, d, pad)

var goal_built := 0.0
const S_REF := 0.9   # Wi.s trên máy chuẩn của Link (S26 Ultra: screen 339x735 css)
static func _calc_u(vs: Vector2, k: Dictionary) -> float:
	# Link: S26 Ultra cố định 1 (bảng y số đo), màn khác phóng theo tỉ lệ Wi.s với máy đó; không rộng quá màn
	return minf(float(k.s) / S_REF, vs.x / VW0)

func goal_w() -> float:
	# .hudq .goal: width min(66vw, 320px) trong .hudq (zoom s), ra đơn vị số đo
	return minf(0.66 * vw * U, 320.0) * Khuon.S_SNAP

const TC_SVG := '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="M3 6.2l5.6-2.2 6.8 2.2 5.6-2.2v13.8l-5.6 2.2-6.8-2.2L3 20z" fill="rgb(242, 211, 168)" stroke="rgb(138, 90, 26)" stroke-width="1.3px" stroke-linejoin="round"/><path d="M8.6 4v13.8M15.4 6.2V20" stroke="rgb(138, 90, 26)" stroke-width="1.1px"/><path d="M3.8 14.5c2-1.6 3.4-.6 4.8-1.6M9.2 10.8c2.2-.4 3.6 1.6 5.6.6M16 12.5c1.4-1.2 2.6-1.8 4.2-1.4" stroke="rgb(90, 150, 60)" stroke-width="1.2px" fill="none" stroke-linecap="round"/><circle cx="12" cy="8.4" r="1.3" fill="rgb(200, 70, 50)"/></svg>'
func _toan_canh_btn(d: Dictionary) -> void:   # (bản 244) nút Toàn cảnh ngay trên nút nhà (cùng khung #zHome); nút AUTO lên theo
	if not d.has(".zoomctl"):
		return
	var zc: Dictionary = d[".zoomctl"][0]
	if zc.kids.is_empty():
		return
	var hb: Dictionary = zc.kids[0]
	var st := float(hb.r[3]) + 6.0   # cao nút + gap 6px
	var tb: Dictionary = hb.duplicate(true)
	tb.id = "zToan"
	Snap._move(tb, Vector2(0, -st))
	for k in tb.kids:
		if k.get("tag", "") == "svg":
			k.svg = TC_SVG
	zc.kids.insert(0, tb)
	zc.r[1] = float(zc.r[1]) - st
	zc.r[3] = float(zc.r[3]) + st
	if d.has(".autob"):
		Snap._move(d[".autob"][0], Vector2(0, -st))

func _build_hud() -> void:
	var d: Dictionary = Snap.load_snap("hud").duplicate(true)
	vw = vsize().x
	vh = vsize().y
	if d.has(".hudq"):
		var q: Dictionary = d[".hudq"][0]
		var gl := Snap.find(q, "goal")
		if not gl.is_empty():
			goal_built = goal_w()
			var dw := goal_built - float(gl.r[2])
			if absf(dw) > 0.01:
				_grow_w(q, float(gl.r[0]) + float(gl.r[2]), dw, 16.0)   # thanh tiến độ cách mép phải bằng lề trong
	_toan_canh_btn(d)
	for sel in d:
		for n in d[sel]:
			var b := _build(n, hid)
			root.add_child(b)
			var a: Array = AX.get(sel, [0, 0])
			anchors.append([b, a[0], a[1]])
			hud_roots[sel] = b
	# body.rmfocus: khi mở khay giống / vòng nút thì giấu mấy nút này
	for k in [".hudq", ".autob", ".zoomctl", "#nvBtn", "#dockBtn"]:
		if hud_roots.has(k):
			focus_hide.append(hud_roots[k])
	for k in [".evrail", "#setBtn"]:
		if hid.has(k):
			focus_hide.append(hid[k])
	_click(hid.get("#dockBtn"), func(): dock_open(true), "scale")
	_click(hid.get("#zHome"), func(): F.home() if F.has_method("home") else null)
	_click(hid.get("#zToan"), func(): main.tc_open() if main != null and main.has_method("tc_open") else null)
	_click(hid.get("#nvBtn"), func(): nvp.open(), "scale")
	_click(hid.get("#setBtn"), func(): setp.open(), "scale")
	_click(hid.get("#pcAv"), func(): pcp.open(), "scale")
	_auto_setup(hid.get(".autob"))
	_click(hid.get("#hudTab"), func(): hud_min(not hm), "scale")   # yO: thu gọn / mở thẻ nhiệm vụ bên trái
	hm_badge = null
	hud_min(bool(G.cfg.get("hm", false)), true)
	for k in [".ngpill", "#coinsPill"]:
		var b = hid.get(k)
		if b != null:
			_click(b, func(): say(SOON))
	_click(hid.get("#clock"), func(): sky_open())   # RN: Trời đất trong làng
	rail_sig = ""
	rail_v = null
	_rail_sync()

# ------------------------------------------------------------------ hộp giải thích chung (nút ? khung tre)

var _tipper = null   # (bản 509) bảng khung Kho ẩn dùng dựng bong bóng (ui_kbang._dtip) cho mọi chỗ gọi tre_help
func tre_help(title: String, text: String) -> void:   # nút ?: (bản 509) giải thích = bong bóng nhãn ô ruộng ngay trên chỗ chạm (dài thì khung rộng giữa bảng), bỏ hộp nâu giữa màn
	if _tipper == null:
		_tipper = load("res://logic/ui_kbang.gd").new(self)
	_tipper._dtip(text, "", title)

func tre_help_close() -> void:   # tắt bong bóng giải thích
	tip_close()

# ------------------------------------------------------------------ cột sự kiện bên phải (WY bản web): Điểm danh, Nạp đầu, 7 ngày
# Dựng lại theo mẫu .evrail trong hud.json mỗi khi số chấm / nút hiện đổi; bỏ Sự kiện, Luyện võ.
const RAIL_DY := 45.75   # khoảng cách hai nút trong cột (nút 42,8 + gap)
var rail_v: Control = null
var rail_sig := ""
var rail_auto := false
static var RAIL := {}

func _pan_on() -> bool:   # đang mở bảng / hộp nào đó (lvov, bảng sổ, kho, lên cấp)
	for p in _pans():
		if p != null and p.on:
			return true
	return (lvp != null and lvp.on) or (vlp != null and vlp.on) or (nvp != null and nvp.on) or (khp != null and khp.get("on") == true)   # (bản 433) nhà dân, Sổ nhiệm vụ đang mở: Điểm danh không tự bật đè lên

func _rail_sync() -> void:
	var rl = hid.get(".evrail")
	if rl == null or G.w_all == null or G.w_all.WEV == null:
		return
	var E = G.w_all.WEV
	var dd: int = E.rF()
	var first := _tr(G.w_all.WH.ng0().get("first"))
	var tt: bool = E.on()
	var vi: int = E.VI() if tt else 0
	var sp: Dictionary = E.Sp()
	if dd > 0 and not rail_auto and int(sp.get("auto", -1)) != E.z9() and G.lv() >= 3 and not _pan_on():   # RY: tự mở Điểm danh một lần mỗi ngày
		rail_auto = true
		sp.auto = E.z9()
		G.mark()
		get_tree().create_timer(2.5).timeout.connect(func(): if not _pan_on(): dd_open("7" if E.N8() and E.Cp() else "m"))
	var sg := JSON.stringify([E.ld(), dd, first, tt, vi])
	if sg == rail_sig and rail_v != null:
		return
	rail_sig = sg
	if RAIL.is_empty():
		for n in Snap.load_snap("hud").get(".hudtr", []):
			var f := Snap.find(n, "evrail")
			if not f.is_empty():
				RAIL = f
	if RAIL.is_empty():
		return
	var n: Dictionary = RAIL.duplicate(true)
	var by := {}
	for k in n.kids:
		by[String(k.cls).split(" ")[1]] = k
	var em0: Dictionary = by["evb-dd"].kids.filter(func(k): return k.tag == "em")[0]
	var L := [["evb-dd", dd, func(): dd_open("7" if E.N8() and E.Cp() else "m")]]
	if not first:
		L.append(["evb-ng", 0, func(): nap_open()])
	if tt:
		L.append(["evb-tt", vi, func(): tt_open()])
	var kids := []
	var cbs := []
	var y0 := float(n.r[1])
	for i in L.size():
		var b: Dictionary = by[L[i][0]]
		b.kids = b.kids.filter(func(k): return k.tag != "em")
		Snap._move(b, Vector2(0, y0 + i * RAIL_DY - float(b.r[1])))
		if int(L[i][1]) > 0:
			var em: Dictionary = em0.duplicate(true)
			Snap._move(em, Vector2(float(b.r[0]) - float(by["evb-dd"].r[0]), float(b.r[1]) - 103.5))
			em.text = str(L[i][1])
			b.kids.append(em)
		if L[i][0] == "evb-dd":   # ngày trên tờ lịch
			var sv: Dictionary = b.kids[0].kids[0]
			var re := RegEx.create_from_string(">\\d+</text>")
			sv.svg = re.sub(String(sv.svg), ">" + str(E.ld()) + "</text>")
		kids.append(b)
		cbs.append(L[i][2])
	n.kids = kids
	n.r[3] = maxf(0.0, L.size() * RAIL_DY - 3.0)
	Snap._move(n, Vector2(-float(n.r[0]), -float(n.r[1])))
	if rail_v != null:
		rail_v.queue_free()
	rail_v = _build(n, {})
	rail_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for k in rl.get_children():
		if k != rail_v:
			k.visible = false
	rl.add_child(rail_v)
	var bs: Array = rail_v.kids()
	for i in bs.size():
		_click(bs[i], cbs[i], "scale")

static func _tr(v) -> bool:
	return not (v == null or v is bool and not v or (v is float or v is int) and v == 0 or v is String and v == "")

# ------------------------------------------------------------------ nút AUTO (IA bản web): dựng theo mẫu autob.json (tắt / bật + số việc)
var auto_b: Control = null   # .autob gốc trong HUD (giữ chỗ, ẩn nét vẽ của nó)
var auto_v: Control = null   # bản dựng theo trạng thái
var auto_sig := ""
static var AUTOB := {}

func _auto_setup(b) -> void:
	if b == null:
		return
	auto_b = b
	_click(b, func(): G.w_all.WAU.toggle(); _auto_sync(), "scale")
	_auto_sync()

func _auto_sync() -> void:   # IA
	if auto_b == null or G.w_all == null or G.w_all.WAU == null:
		return
	var A = G.w_all.WAU
	var lb: String = A.label()
	var sg := str(A.on) + lb
	if sg == auto_sig:
		return
	auto_sig = sg
	if AUTOB.is_empty():
		AUTOB = Snap.load_snap("autob")
	var n: Dictionary = (AUTOB.on if A.on else AUTOB.off).duplicate(true)
	if A.on:
		var sm: Dictionary = n.kids[3]
		var fs := Css.px(String(sm.css.get("font-size", "11px"))) * float(sm.get("z", 1.0))
		var tw := Box.text_w(lb, fs, int(String(sm.css.get("font-weight", "700"))))
		if lb == "":
			n.kids = n.kids.slice(0, 3)
			n.r[2] = float(sm.r[0]) - 6.0 * 0.75 + 7.5 - float(n.r[0])
		else:
			sm.text = lb
			sm.r[2] = tw
			if sm.has("tr"):
				sm.tr[2] = tw
			n.r[2] = float(sm.r[0]) + tw + 7.5 - float(n.r[0])
	Snap._move(n, Vector2(-float(n.r[0]), -float(n.r[1])))
	if auto_v != null:
		auto_v.queue_free()
	auto_v = _build(n, {})
	auto_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	auto_b.self_modulate = Color(1, 1, 1, 0)
	for k in auto_b.get_children():
		if k != auto_v:
			k.visible = false
	auto_b.add_child(auto_v)
	auto_b.size.x = float(n.r[2]) * Css.K   # vùng bấm theo bề ngang mới

func _set_focus(on: bool) -> void:
	if on == focus:
		return
	focus = on
	for b in focus_hide:
		b.visible = not on

func _sync_hud() -> void:
	if hid.is_empty():
		return
	_rail_sync()
	_txt(hid.get(".lv"), str(G.lv()))
	var en = hid.get(".en")
	if en != null and en.kids().size() > 0:
		var bar: Control = en.kids()[0]
		var fr := clampf(float(G.g.pc.en) / maxf(1.0, G.en_max()), 0.0, 1.0)
		bar.place(Rect2(bar.r.position, Vector2(en.r.size.x * fr, bar.r.size.y)))
	_coins_txt(G.fmt_n(int(G.g.coins)))
	var ng = hid.get(".ngpill")
	if ng != null:
		_txt(_q(ng, "", "b"), str(int(G.g.get("ngoc", 0))))
	var t := (posmod(G.day(), 28))
	_txt(hid.get("#seaT"), G.SEA_N[G.season()] + (" " + str(t % 7 + 1) if G.cfg.s == "auto" else ""))

# ------------------------------------------------------------------ thẻ nhiệm vụ bên mép trái (.hudq bản web: yO, xO, #goalGo)
# Nút ‹ thu gọn thẻ mục tiêu + hàng nút viên (body.hudmin), thành › kèm số nút viên đang có (chấm đỏ); nhớ theo máy.
# Chạm thẻ mục tiêu lúc đủ: nhận thưởng (#goalGo).
var hm := false
var hm_badge: Control = null
var hm_n := -1

func hud_min(on: bool, quiet := false) -> void:   # yO
	hm = on
	if G.cfg.get("hm", false) != on:
		G.cfg["hm"] = on
		var f := FileAccess.open(G.CFG_PATH, FileAccess.WRITE)
		if f:
			f.store_string(JSON.stringify(G.cfg))
			f.close()
	var tb = hid.get("#hudTab")
	if tb != null:
		var ar := _q(tb, "ar")
		_txt(ar, "›" if on else "‹")
	if hid.get("#goal") != null:   # (bản 362) thẻ mục tiêu chỉ làm mẫu cho cột việc (pill.gd), không hiện
		hid["#goal"].visible = false
	if G.w_all != null and G.w_all.pills != null:
		G.w_all.pills.visible = not on
	hm_n = -1
	_hm_badge()

func _hm_badge() -> void:   # xO: số nút viên đang hiện, chỉ lúc thu gọn
	var tb = hid.get("#hudTab")
	if tb == null:
		return
	var n := 0
	if G.w_all != null and G.w_all.pills != null:
		for c in G.w_all.pills.get_children():
			if c is Control and c.visible and not c.has_meta("nocount"):
				n += 1
	if not hm:
		n = 0
	if n == hm_n:
		return
	hm_n = n
	if hm_badge == null or not is_instance_valid(hm_badge):
		hm_badge = Control.new()
		hm_badge.set_meta("snap", {})
		hm_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hm_badge.draw.connect(func():
			if hm_n <= 0:
				return
			var k := Css.K
			var t := str(hm_n)
			var f: Font = Css.font(800)
			var fs := int(round(10.0 * 0.75 * k))
			var w := maxf(17.0 * 0.75 * k, f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 8.0 * 0.75 * k)
			var h := 17.0 * 0.75 * k
			var r := Rect2(hm_badge.size.x - w + 8.0 * 0.75 * k, -8.0 * 0.75 * k, w, h)
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color("#e04b3a")
			sb.set_corner_radius_all(int(h / 2.0))
			sb.anti_aliasing = true
			hm_badge.draw_style_box(sb, r)
			var tw := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			hm_badge.draw_string(f, Vector2(r.position.x + (w - tw) / 2.0, r.position.y + h / 2.0 + fs * 0.36), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE))
		tb.add_child(hm_badge)
	hm_badge.position = Vector2.ZERO
	hm_badge.size = tb.size
	hm_badge.queue_redraw()

# #coinsPill bản web rộng theo số (width auto, bám mép phải): số dài hơn thì ô xu nới sang trái, không cắt chữ
func _coins_txt(s: String) -> void:
	var c = hid.get("#coins")
	if c == null or c.texts.is_empty():
		return
	var i: int = c.get_meta("ti", 0)
	var t0: Dictionary = c.texts[i]
	var ns: String = String(c.get_meta("prefix", "")) + s + String(c.get_meta("suffix", ""))
	if t0.s == ns:
		return
	var d: float = Box.text_w(ns, t0.size, t0.w) - Box.text_w(t0.s, t0.size, t0.w)
	c.set_text(i, ns)
	if absf(d) < 0.01:
		return
	var pl = hid.get("#coinsPill")
	if pl != null and pl != c:
		pl.place(Rect2(pl.r.position - Vector2(d, 0), pl.r.size + Vector2(d, 0)))
	c.place(Rect2(c.r.position, c.r.size + Vector2(d, 0)))
	t0.rect = Rect2(t0.rect.position, t0.rect.size + Vector2(d, 0))
	c.redraw()

var _ph := ""
func _clock() -> void:
	# hE: giờ của d0 (giờ thật), hình #clkI theo buổi (kX), chữ #wxT theo ti.cur (uQ, xm)
	var h: float = G.troi.hour()
	var e := int(floor(h))
	var m := int(floor((h - e) * 60.0))
	_txt(hid.get("#clkT"), "Ban ngày" if G.cfg.d == "day" and G.troi.hh < 0.0 else ("Ban đêm" if G.cfg.d == "night" and G.troi.hh < 0.0 else "%02d:%02d" % [e, m]))
	var ph: String = G.troi.dh().phase
	var ci = hid.get("#clkI")
	if ph != _ph and ci != null and ci.kids().size() > 0:
		_ph = ph
		_set_svg(ci.kids()[0], G.troi.KX[ph])
	var w: String = G.troi.cur if G.troi.cur != "" else "nang"
	_txt(hid.get("#wxT"), G.troi.TEN[w])

# ------------------------------------------------------------------ Menu: ui_dock2.gd (dkp)

func _buttons(b: Control, out: Array) -> Array:
	# theo thứ tự trong trang (Snap.build xếp con theo z-index để vẽ: nút "on" bị đẩy xuống cuối)
	var ks: Array = b.kids()
	var sk: Array = b.get_meta("snap", {}).get("kids", [])
	if sk.size() > 0:
		ks.sort_custom(func(x, y): return _di(sk, x) < _di(sk, y))
	for k in ks:
		var n: Dictionary = k.get_meta("snap", {})
		if n.get("tag", "") == "button":
			out.append(k)
		else:
			_buttons(k, out)
	return out

static func _di(sk: Array, k: Control) -> int:
	var n = k.get_meta("snap") if k.has_meta("snap") else null   # get_meta(.., null) vẫn báo lỗi khi thiếu
	for i in sk.size():
		if is_same(sk[i], n):
			return i
	return sk.find(n)

func _label_of(b: Control) -> String:
	var n: Dictionary = b.get_meta("snap", {})
	var s := _all_text(n)
	return s.strip_edges()

func _all_text(n: Dictionary) -> String:
	var s: String = n.get("text", "")
	for k in n.get("kids", []):
		var t := _all_text(k)
		if t != "":
			s += (" " if s != "" else "") + t
	return s

func dock_open(on: bool) -> void:   # (11-28) Menu = bảng khung chung dkp
	if dkp == null:
		return
	if on:
		for p in _pans():
			if p != null and p != dkp and p.on:
				p.close()
		dkp.open()
	elif dkp.on:
		dkp.close()
	var b = hid.get("#dockBtn")
	if b != null:
		b.visible = not on and not focus

func tap_close(c: Control, cb: Callable, inner = null) -> void:   # (bản 287) chạm nền c (chạm xuống) thì đóng: một hàm cho mọi bảng
	# inner: khung bảng (Control hoặc Callable trả Control); chạm trong khung thì không đóng
	c.gui_input.connect(func(e):
		if not _is_tap_down(e):
			return
		var w = inner.call() if inner is Callable else inner
		if w != null and is_instance_valid(w) and w.get_global_rect().has_point(c.global_position + e.position):
			return
		cb.call())

func _is_tap_down(e: InputEvent) -> bool:
	return (e is InputEventScreenTouch and e.pressed) or (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT)

# ------------------------------------------------------------------ camera (gv T/w/E, ring E/C/R)
var cam_tw = null      # {z0, z1, w0, w1, s, t}
var cam_back = null    # {c0, to, t}
var cam0 = null        # {c: world centre, z}

func _view_c() -> Dictionary:
	var vp := get_viewport().get_visible_rect().size
	return {"c": main.cam + vp * 0.5 / main.zoom, "z": main.zoom}

func _cam_to(i: int, z1: float, sy: float) -> void:
	# tween so plot i's centre comes to screen (vw/2, sy) at css zoom z1, .32 s ease-out cubic
	var c: Dictionary = G.cells[i]
	var w1 := Vector2(F.en(c.gx + 0.5, c.gy + 0.5), F.nn(c.gx + 0.5, c.gy + 0.5, G.CO))
	var s := Vector2(vw * 0.5, sy)
	var w0: Vector2 = main.cam + s * Css.K / main.zoom
	cam_tw = {"z0": main.zoom, "z1": z1 * Css.K, "w0": w0, "w1": w1, "s": s * Css.K, "t": 0.0}

func _cam_open() -> void:
	if cam0 == null:
		cam0 = cam_back.to if cam_back != null else _view_c()
		cam_back = null

func _cam_close() -> void:
	cam_tw = null
	if cam0 != null:
		cam_back = {"c0": _view_c(), "to": cam0, "t": 0.0}
		cam0 = null

func _cam_step(dt: float) -> void:
	dt = minf(0.05, dt)
	if cam_tw != null:
		var k: Dictionary = cam_tw
		k.t = minf(1.0, k.t + dt / 0.32)
		var e := 1.0 - pow(1.0 - k.t, 3.0)
		main.zoom = lerpf(k.z0, k.z1, e)
		var w: Vector2 = k.w0.lerp(k.w1, e)
		main.cam = w - k.s / main.zoom
		if main.has_method("_clamp_cam"):
			main._clamp_cam()
		if k.t >= 1.0:
			cam_tw = null
	elif cam_back != null:
		var k: Dictionary = cam_back
		k.t = minf(1.0, k.t + dt / 0.3)
		var e := 1.0 - pow(1.0 - k.t, 3.0)
		var vp := get_viewport().get_visible_rect().size
		main.zoom = lerpf(k.c0.z, k.to.z, e)
		var c: Vector2 = k.c0.c.lerp(k.to.c, e)
		main.cam = c - vp * 0.5 / main.zoom
		if main.has_method("_clamp_cam"):
			main._clamp_cam()
		if k.t >= 1.0:
			cam_back = null

func world_down() -> void:
	# chạm/kéo làng: web đóng khay giống, vòng nút, bảng ô (pointerdown ngoài bảng) và dừng camera về
	cam_back = null if gv_i < 0 and rm_i < 0 and not (xfp != null and xfp.is_open()) else cam_back
	cam_tw = null
	if xfp != null:
		xfp.close()
	gv_close()
	rm_close()
	lock_close()
	dock_open(false)

# ------------------------------------------------------------------ khay chọn giống ("gieo")
var gv_b: Control = null
var gv_top: Control = null
var gv_bar: Control = null
var gv_tpl_sel := {}
var gv_tpl := {}
var gv_lk := {}
var gv_bar0 := Rect2()
var gv_i := -1
var gv_sig := ""
var gv_seeds := []

func _build_gv() -> void:
	var d: Dictionary = Snap.load_snap("gv").duplicate(true)   # sửa bản sao: mẫu chụp dùng chung khi dựng lại giao diện
	for sel in d:
		for nq in d[sel]:
			Snap.star_big(nq)
	var n0: Dictionary = d[".gv"][0]
	var bar: Dictionary = Snap.find(n0, "gvbar")
	var seeds := []
	for k in bar.kids:
		if String(k.cls).split(" ").has("gvs"):
			seeds.append(k)
		elif String(k.cls).split(" ").has("gvlk"):
			gv_lk = k
	gv_tpl_sel = seeds[0]
	gv_tpl = seeds[1] if seeds.size() > 1 else seeds[0]
	gv_bar0 = Rect2(bar.r[0], bar.r[1], bar.r[2], bar.r[3])
	bar.kids = []
	var ids := {}
	gv_b = _build(n0, ids)
	gv_b.visible = false
	root.add_child(gv_b)
	gv_top = ids[".gvtop"]
	gv_bar = ids[".gvbar"]
	_stop(gv_bar)
	_click(ids.get(".gvst"), func():
		var gi := gv_i
		gv_close()
		if gi >= 0:
			spp.open(gi), "down")

func _gv_order() -> Array:
	# d(): giống đã tới cấp; có hạt + hợp mùa trước, rồi có hạt, rồi hết hạt
	var L := []
	var j := 0
	for c in G.xo:
		if int(G.crop(c).get("lv", 1)) <= G.lv() and (not G.crop(c).get("hyb", false) or int(G.g.barn.get(c, 0)) > 0):
			var n := int(G.g.barn.get(c, 0))
			L.append([c, (0 if G.in_season(c) else 1) if n > 0 else 2, j])
			j += 1
	L.sort_custom(func(a, b): return a[1] < b[1] or (a[1] == b[1] and a[2] < b[2]))
	var out := []
	for a in L:
		out.append(a[0])
	return out

func _gv_locked() -> String:
	# v(): "Cấp N mở: ..." giống cấp kế tiếp
	var best := 999
	for c in G.xo:
		var l := int(G.crop(c).get("lv", 1))
		if l > G.lv() and not G.crop(c).get("hyb", false):
			best = mini(best, l)
	if best == 999:
		return ""
	var names := []
	for c in G.xo:
		if int(G.crop(c).get("lv", 1)) == best and not G.crop(c).get("hyb", false):
			names.append(G.crop(c).name)
	return "Cấp " + str(best) + " mở: " + ", ".join(names)

func gv_open(i: int) -> void:
	gv_sc.s = 0.0
	pc_close()
	lock_close()
	rm_close()
	dock_open(false)
	_cam_open()
	gv_i = i
	gv_sig = ""
	gv_b.visible = true
	_set_focus(true)
	_gv_sync()
	_gv_pos()
	# T(W): đưa ô vào giữa khoảng trống giữa bảng trên và khay dưới; phóng lên 1,6 nếu đang nhỏ hơn 1,2
	var z := cz()
	var zoom_up := bz() < 1.2
	var z1 := clampf(1.6, main.zmin / dpr_v, main.zmax / dpr_v) / U if zoom_up else z
	var D = gv_top.r.size.y
	var wt = vh - 12.0 - gv_bar.r.size.y - 8.0
	var nt = 96.0 + D + 6.0
	var pa = wt - 18.0 * z1
	var g := plot_css(i)
	if not zoom_up and g.y >= nt and g.y <= pa and g.x > 40.0 and g.x < vw - 40.0:
		cam0 = null
		return
	_cam_to(i, z1, clampf((nt + pa) * 0.5, nt, pa))

func gv_close() -> void:
	if gv_i < 0:
		return
	gv_i = -1
	gv_b.visible = false
	_set_focus(false)
	_cam_close()

func _ring5(st: int, cls := "") -> String:
	# e(W) / h(): 5 cung quanh nút sao, cung đã có sao màu vàng
	var s := "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 64 64\">"
	for f in 5:
		var j := -90.0 + f * 72.0 + 8.0
		var e := j + 56.0
		var a := "%.2f %.2f" % [32.0 + RA * cos(deg_to_rad(j)), 32.0 + RA * sin(deg_to_rad(j))]
		var b := "%.2f %.2f" % [32.0 + RA * cos(deg_to_rad(e)), 32.0 + RA * sin(deg_to_rad(e))]
		s += "<path d=\"M" + a + "A" + str(RA) + " " + str(RA) + " 0 0 1 " + b + "\" fill=\"none\" stroke=\"" + ("#ffc21a" if f < st else "#f3ead0") + "\" stroke-width=\"5\" stroke-linecap=\"round\"/>"
	return s + "</svg>"

func _set_svg(b: Control, svg: String) -> void:
	if b == null or b.pics.is_empty():
		return
	var t := Css.svg_tex(svg, b.r.size.x, b.r.size.y)
	if t != null and b.pics[0].tex != t:
		b.pics[0].tex = t
		b.redraw()

func _gv_sync() -> void:
	var i := gv_i
	if i < 0:
		return
	var a: Dictionary = G.p(i)
	var order := _gv_order()
	var any_seed := false
	var any_sea := false
	var sig := ""
	for c in order:
		var n := int(G.g.barn.get(c, 0))
		any_seed = any_seed or n > 0
		any_sea = any_sea or G.in_season(c)
		sig += c + str(n) + ("m" if G.in_season(c) else "") + ","
	var st: int = G.star(a) - 1
	sig += "|" + str(G.g.sel) + "|" + str(st)
	if sig == gv_sig:
		return
	gv_sig = sig
	# nhãn: "Hợp mùa · lớn nhanh hơn" (lá xanh) hoặc "Gieo 1 hạt, gặt 2"
	var lab := _q(gv_top, "gvlab")
	var sm := _q(lab, "", "small")
	if sm != null:
		var leaf: Control = sm.kids()[0] if sm.kids().size() > 0 else null
		if leaf != null:
			leaf.visible = any_sea
		_txt(sm, "Hợp mùa · lớn nhanh hơn" if any_sea else "Gieo 1 hạt, gặt 2")
		if not sm.texts.is_empty():
			sm.texts[0].col = Color8(63, 138, 52) if any_sea else Color8(138, 106, 72)
			if not any_sea:
				sm.texts[0].rect = Rect2(0, sm.texts[0].rect.position.y, sm.r.size.x, sm.texts[0].rect.size.y)
			sm.redraw()
	var stb := _q(gv_top, "gvst")
	if stb != null and stb.kids().size() > 0:
		_set_svg(stb.kids()[0], _ring5(st))
	# khay: dựng lại các nút giống từ nút mẫu đã chụp
	for k in gv_bar.kids():
		k.queue_free()
	gv_seeds.clear()
	var o := gv_bar0.position
	var dx: float = float(gv_tpl.r[0]) - float(gv_tpl_sel.r[0])
	if dx <= 0.0:
		dx = 60.0
	var dy := 82.0
	var idx := 0
	for c in order:
		var n := int(G.g.barn.get(c, 0))
		var tp: Dictionary = gv_tpl_sel if (G.g.sel == c and n > 0) else gv_tpl
		var base := Vector2(float(gv_tpl_sel.r[0]), float(gv_tpl_sel.r[1]))
		var to := base + Vector2((idx % 5) * dx, int(idx / 5) * dy)
		var nd := Snap.moved(tp, to - Vector2(float(tp.r[0]), float(tp.r[1])))
		_gv_fill(nd, c, n)
		var sb := _build(nd, {}, o)
		gv_bar.add(sb)
		if n < 1:
			var gi := _q(sb, "gvi")
			if gi != null:
				gi.modulate.a = 0.7
			var gn := _q(sb, "gvn")
			if gn != null:
				gn.modulate.a = 0.6
		var cc: String = c
		_click(sb, func():
			if gv_sc.moved():
				return   # vừa kéo cuộn, không phải chạm
			_gv_pick(cc), "scale92")
		gv_seeds.append(sb)
		idx += 1
	var rows := int(ceil(idx / 5.0))
	var lk := _gv_locked()
	if lk != "" and not gv_lk.is_empty():
		var y := float(gv_tpl_sel.r[1]) + rows * dy + (76.0 - float(gv_lk.r[3])) * 0.5
		var nd := Snap.moved(gv_lk, Vector2(0, y - float(gv_lk.r[1])))
		nd.text = lk
		nd.erase("tr")
		gv_bar.add(_build(nd, {}, o))
		rows += 1
	if not any_seed:
		var e: Control = Box.new()
		e.style("", 1.0)
		e.place(Rect2(10, 8, gv_bar0.size.x - 20, 76))
		e.text("Hết giống rồi! Mua ở Chợ phiên, nhà hàng xóm hoặc chợ nổi sáng sớm.", Rect2(0, 0, gv_bar0.size.x - 20, 76), 14, 600, Color.WHITE, "center", [], true)
		gv_bar.add(e)
		rows = maxi(rows, 1)
	var full := 16.0 + rows * 76.0 + maxf(0, rows - 1) * 6.0
	var h := minf(256.0, full)
	gv_bar.place(Rect2(Vector2((vw - gv_bar0.size.x) * 0.5, vh - 12.0 - h), Vector2(gv_bar0.size.x, h)))
	gv_sc.setup(gv_bar, full, h)

func _gv_fill(nd: Dictionary, c: String, n: int) -> void:
	# đổi nút mẫu thành nút của giống c: hình, tên, số hạt, lá hợp mùa
	var gi := Snap.find(nd, "gvi")
	# (bản 276) hình giống = hình món trong Kho (ui/svg/kh, ảnh mới), món chưa có hình thì hình giống cũ (ui/svg/gv)
	var sv: String = FileAccess.get_file_as_string("res://ui/svg/kh/" + c + ".svg")
	if sv == "":
		sv = FileAccess.get_file_as_string("res://ui/svg/gv/" + c + ".svg")
	for k in gi.get("kids", []):
		if k.tag == "svg" and sv != "":
			k.svg = sv
	var cnt := Snap.find(nd, "gvc")
	if n > 0 and not cnt.is_empty():
		cnt.text = G.fmt_k(n)
		cnt.erase("tr")
		var fs := 14.0
		var tw: float = Box.text_w(cnt.text, fs, 800)
		var right: float = float(gi.r[0]) + float(gi.r[2]) + 7.0
		cnt.r = [right - tw, cnt.r[1], tw, cnt.r[3]]
	elif n <= 0:
		Snap.remove(nd, "gvc")
	if not G.in_season(c):
		Snap.remove(nd, "gvm")
	var gn := Snap.find(nd, "gvn")
	var name: String = G.crop(c).name
	gn.text = name
	gn.erase("tr")
	var tw2: float = Box.text_w(name, 12.0, 600)
	var bw: float = float(nd.r[2])
	var cx: float = float(nd.r[0]) + bw * 0.5
	var lines := 1 if tw2 <= bw - 2.0 else 2
	var w := minf(tw2, bw)
	gn.r = [cx - w * 0.5, gn.r[1], w, 13.2 * lines]
	gn.css["white-space"] = "normal" if lines > 1 else "nowrap"

func _gv_pick(c: String) -> void:
	var i := gv_i
	if i < 0:
		return
	if int(G.g.barn.get(c, 0)) <= F.seeds_queued(c):
		say("Hết giống " + String(G.crop(c).name).to_lower() + ". Mua ở Chợ phiên, nhà hàng xóm hoặc chợ nổi sáng sớm.")
		return
	G.g.sel = c
	F.queue_job(i, "plant", c)
	gv_close()

func _gv_pos() -> void:
	# k(): bảng sao + nhãn đứng trên ô, không ra khỏi màn hình
	if gv_i < 0:
		return
	var ft := plot_css(gv_i)
	var st = gv_top.r.size.x
	var ut = gv_top.r.size.y
	var x := clampf(ft.x, st / 2.0 + 8.0, vw - st / 2.0 - 8.0)
	var y := maxf(ut + 96.0 - 30.0, ft.y - 6.0 * cz())
	_move(gv_top, Vector2(round(x) - st / 2.0, round(y) - ut))

# ------------------------------------------------------------------ vòng nút ô ruộng ("ring")
var rm_g: Control = null      # đang lớn: chín ngay / sao / tưới + nhãn giờ
var rm_r: Control = null      # chín: nút liềm
var rm_gi := {}
var rm_i := -1
var rm_t := -1               # cây ăn trái đang mở (g.objs idx): xài chung vòng nút ô ruộng, không có nút sao
var rm_v := {}               # con vật {t, j} / chuồng {t, j: -1}: xài chung vòng nút ô ruộng (rm_vn.gd lo phần riêng)
var rv = null                # rm_vn.gd
var rm_d := {}               # vật đang mở vòng nút Dọn (rm_don.gd): {hu} cây cỏ hoang / {o} đồ có sẵn của làng
var rd = null                # rm_don.gd
var rm_x0 := {}              # chỗ gốc của .fast / .water
var rm_in0 := {}             # hình trong gốc của .star / .water / .rmth (+ vòng gốc .rmth)
var rm_sig := ""
var dim: Control = null
var dim_mat: ShaderMaterial = null
var dim_a := 0.0

func _build_rm() -> void:
	var d: Dictionary = Snap.load_snap("rmg").duplicate(true)   # sửa bản sao: mẫu chụp dùng chung khi dựng lại giao diện
	# nút .fast thêm một ô hình trong (chép ô hình của .star, dời sang): con vật / chuồng đặt hình món vào đó
	var fn := Snap.find(d[".rm"][0], "fast")
	var sn := Snap.find(d[".rm"][0], "star")
	fn.kids.append(Snap.moved(sn.kids[1], Vector2(float(fn.r[0]) - float(sn.r[0]), 0.0)))
	rm_g = _build(d[".rm"][0], rm_gi)
	rm_g.visible = false
	root.add_child(rm_g)
	var d2: Dictionary = Snap.load_snap("rmr")
	var ids2 := {}
	rm_r = _build(d2[".rm"][0], ids2)
	rm_r.visible = false
	root.add_child(rm_r)
	for k in [".fast", ".water"]:
		rm_x0[k] = rm_gi[k].r.position
	# (bản 257) nút sao + nút tưới: dùng ảnh bong bóng (ui/img/bong sao, nuoc) thay hình vẽ của bản web, giọt nước
	# cùng một hình với bong bóng cần tưới trên làng
	rm_in0[".star"] = Css.img_svg("res://ui/img/bong/sao.png")
	rm_in0[".water"] = Css.img_svg("res://ui/img/bong/nuoc.png")
	var th: Control = ids2.get(".rmth")
	rm_in0[".rmth"] = th.kids()[-1].get_meta("snap", {}).get("svg", "")
	rm_in0["rmth_ring"] = th.kids()[0].get_meta("snap", {}).get("svg", "")
	rm_gi[".rmth"] = th
	rv = load("res://logic/rm_vn.gd").new(self)
	rd = load("res://logic/rm_don.gd").new(self)
	_click(rm_gi.get(".rmt"), func(): _rm_do("chip"))
	_click(rm_gi.get(".fast"), func(): _rm_do("fast"))
	_click(rm_gi.get(".star"), func(): _rm_do("star"))
	_click(rm_gi.get(".water"), func(): _rm_do("water"))
	_click(ids2.get(".rmth"), func(): _rm_do("harvest"))

func _build_dim() -> void:
	# .rmdim: tối nhẹ quanh ô đang chọn (radial-gradient ellipse)
	dim = Control.new()
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nuniform vec2 c; uniform vec2 r; uniform float a;\nvoid fragment(){ vec2 p = (FRAGCOORD.xy - c) / r; float d = length(p); float k = clamp((d - 0.7) / 0.3, 0.0, 1.0); COLOR = vec4(0.0, 0.0, 0.0, 0.25 * k * a); }"
	dim_mat.shader = sh
	dim.material = dim_mat
	dim.draw.connect(func(): dim.draw_rect(Rect2(Vector2.ZERO, dim.size), Color.WHITE))
	dim.visible = false
	root.add_child(dim)

func rm_open(i: int) -> void:
	pc_close()
	lock_close()
	gv_close()
	dock_open(false)
	_cam_open()
	rm_i = i
	rm_t = -1
	rm_sig = ""
	_rm_kind(false)
	_set_focus(true)
	_rm_sync()
	_rm_pos()
	# E(It): chỉ đưa camera khi đang nhỏ hơn 1,2
	if bz() >= 1.2:
		cam0 = null
		return
	var z1 := clampf(1.6, main.zmin / dpr_v, main.zmax / dpr_v) / U
	var a: Dictionary = G.p(i)
	var gt: float = F.OU[G.stage(a)] if a.c != null else 20.0
	var box := _rm_in()
	var A = box.r.size.y if box != null else 120.0
	var at = -(gt + 16.0) * z1 - A
	var pt := 18.0 * z1
	_cam_to(i, z1, (96.0 + vh) / 2.0 - (at + pt) / 2.0)

func _rm_in() -> Control:
	var a: Dictionary = G.p(rm_i) if rm_i >= 0 else {}
	var top := rm_r if (not a.is_empty() and G.ripe(a)) else rm_g
	return top.kids()[0] if top.kids().size() > 0 else null

func rm_on() -> bool:
	return rm_i >= 0 or rm_t >= 0 or not rm_v.is_empty() or not rm_d.is_empty()

func rm_close() -> void:
	if not rm_on():
		return
	var plot := rm_i >= 0
	rm_i = -1
	rm_t = -1
	rm_v = {}
	rm_d = {}
	if xfp != null:
		xfp._ask_close()   # chip hỏi (chín ngay, chữa bệnh...) đi theo vòng nút
	rm_g.visible = false
	rm_r.visible = false
	_set_focus(false)
	if plot:
		_cam_close()

func _rm_kind(tree: bool) -> void:   # ô ruộng / cây ăn trái (cây: ẩn nút sao, dồn chín ngay / tưới vào giữa)
	_rm_reset()
	rm_gi[".star"].visible = not tree
	var d := 32.0 if tree else 0.0
	for k in rm_x0:
		_move(rm_gi[k], rm_x0[k] + Vector2(d if k == ".fast" else -d, 0.0))

func _rm_reset() -> void:   # trả vòng nút về như ô ruộng (hình trong gốc, sen hiện, chip có đồng hồ)
	for k in [".fast", ".star", ".water"]:
		var b: Control = rm_gi[k]
		b.visible = true
		b.modulate.a = 1.0
		_move(b, rm_x0.get(k, b.r.position))
	_rm_ic(".fast", "")
	if rm_gi[".fast"].has_meta("vfic"):
		rm_gi[".fast"].remove_meta("vfic")
	_rm_ic(".star", rm_in0[".star"])
	_rm_ic(".water", rm_in0[".water"])
	_rm_ic(".rmth", rm_in0[".rmth"])
	_set_svg(rm_gi[".rmth"].kids()[0], rm_in0["rmth_ring"])
	_q(rm_gi[".fast"], "rmsen").visible = true
	var sm := _q(rm_gi[".rmt"], "", "small")
	if sm != null:
		sm.visible = true

func _rm_ic(k: String, svg: String, big := false) -> void:   # hình trong của nút k ("" = ẩn); big: hình món (khung 64 có chừa lề) 40 thay 28
	var b: Control = rm_gi[k].kids()[-1]
	b.visible = svg != ""
	if not b.has_meta("r0"):
		b.set_meta("r0", b.r)
	var r0: Rect2 = b.get_meta("r0")
	# ảnh sao / giọt nước (bản 257) to hơn hình gốc một chút (28 -> 38)
	var r1 := r0.grow(6.0) if big else (r0.grow(5.0) if svg != "" and (svg == rm_in0.get(".star") or svg == rm_in0.get(".water") or svg == rm_in0.get("heart")) else r0)
	if b.r != r1:
		b.place(r1)
		if not b.pics.is_empty():
			b.pics[0].rect = Rect2(Vector2.ZERO, r1.size)
			b.pics[0].tex = null   # vẽ lại svg đúng cỡ mới
	if svg != "":
		_set_svg(b, svg)

func _rm_col(b: Control, col) -> void:   # màu chữ dòng nhỏ của chip (null = màu gốc của bản chụp)
	if b.texts.is_empty():
		return
	if not b.has_meta("c0"):
		b.set_meta("c0", b.texts[0].col)
	var c: Color = col if col is Color else b.get_meta("c0")
	if b.texts[0].col != c:
		b.texts[0].col = c
		b.redraw()

func _rm_title(rt: Control, mid: bool) -> void:   # tên trên chip: mid = chỉ có tên thì đưa vào giữa chip
	var ti: int = rt.get_meta("ti", 0)
	if rt.texts.size() <= ti:
		return
	if not rt.has_meta("ty0"):
		rt.set_meta("ty0", rt.texts[ti].rect.position.y)
	var y: float = (rt.r.size.y - rt.texts[ti].rect.size.y) * 0.5 if mid else float(rt.get_meta("ty0"))
	if absf(rt.texts[ti].rect.position.y - y) > 0.01:
		rt.texts[ti].rect.position.y = y
		rt.redraw()

func _rm_note(rt: Control, s: String, col = null) -> void:   # dòng chữ nhỏ của chip không có đồng hồ ("" = ẩn dòng, tên vào giữa); col: màu chữ
	_rm_title(rt, s == "")
	var sm := _q(rt, "", "small")
	if sm == null:
		return
	sm.visible = s != ""
	if s == "":
		return
	for k in sm.kids():
		var n: Dictionary = k.get_meta("snap", {})
		if n.get("tag", "") == "svg":
			k.visible = false
		elif n.get("tag", "") == "b":
			var w := Box.text_w(s, 12.0, 800) + 2.0
			_txt(k, s)
			_rm_col(k, col)
			k.place(Rect2(Vector2((sm.r.size.x - w) * 0.5, k.r.position.y), Vector2(w, k.r.size.y)))
			k.texts[0].rect = Rect2(0, k.texts[0].rect.position.y, w, k.texts[0].rect.size.y)
			k.texts[0].al = "left"
			k.redraw()
	if sm.has_meta("wet"):
		sm.get_meta("wet").visible = false

func dn_open(k: Dictionary) -> void:   # chạm cây cỏ hoang / đồ có sẵn của làng: vòng nút Dọn
	rd.open(k)

func rm_tree(t: int) -> void:   # hg: chạm cây ăn trái
	close_all()
	if G.w_all.WR.ql(t) == null:
		return
	rm_t = t
	rm_sig = ""
	var vf: bool = _rm_vf()
	_rm_kind(not vf)   # cây có sẵn của làng: thêm nút Dọn ở giữa (chỗ nút sao)
	if vf:
		_set_svg(rm_gi[".star"].kids()[0], _ring("rmw", "#1e90e8", "rgba(150,112,48,.18)", 0.0))
		_rm_ic(".star", FileAccess.get_file_as_string("res://ui/svg/kh/pc_cuoc.svg"), true)
	_set_focus(true)
	_rm_sync()
	_rm_pos()

func _rm_vf() -> bool:   # cây ăn trái đang mở là cây có sẵn của làng (f): Dọn + Hái, sống lang.SONG (7 ngày) rồi tự mất
	var O: Array = G.lang.objs()
	return rm_t >= 0 and rm_t < O.size() and int(O[rm_t].get("f", 0)) == 1

func _rm_tree_sync() -> void:   # Rj: vòng trái (đỏ) + số sen đỏ, vòng nước, nhãn tên + giờ còn lại
	var R = G.w_all.WR
	var t = R.ql(rm_t)
	if t == null:
		rm_close()
		return
	var ripe: bool = R.wc(t)
	var vf := _rm_vf()
	rm_g.visible = not ripe or vf
	rm_r.visible = ripe and not vf
	if vf:   # chip: còn mấy lần hái
		var left_n: int = G.lang.days_left(t)
		var ic := String(R._ei()[t.id].p) if ripe else ""
		if rm_gi[".fast"].get_meta("vfic", "?") != ic:   # đổi hình nút chỉ khi chín / hết chín
			rm_gi[".fast"].set_meta("vfic", ic)
			_rm_ic(".fast", rv._svg(ic) if ripe else "", true)
			if ripe:
				_set_svg(rm_gi[".fast"].kids()[0], rm_in0["rmth_ring"])
		_q(rm_gi[".fast"], "rmsen").visible = not ripe
		if ripe:
			_txt(_q(rm_gi[".fast"], "", "b"), "")
			var rt0 = rm_gi.get(".rmt")
			if rt0 != null:
				_txt(rt0, String(G.lang.Pi[t.id].n))
				_rm_note(rt0, "Còn " + str(left_n) + " ngày")
			return
	elif ripe:
		return
	var e: Dictionary = R._ei()[t.id]
	var fw := float(t.fw)
	var c: float = R.tree_left(rm_t)
	var fast = rm_gi.get(".fast")
	if fast != null:
		_set_svg(fast.kids()[0], _ring("rmf", "#e8324a", "rgba(232,50,74,.16)", round(minf(1.0, float(t.fp) / float(e.time)) * 1000.0) / 1000.0))
		_txt(_q(fast, "", "b"), str(R.ro(c)))
	var wat = rm_gi.get(".water")
	if wat != null:
		_set_svg(wat.kids()[0], _ring("rmw", "#1e90e8", "rgba(30,144,232,.15)", round(clampf(fw / R.f2(), 0.0, 1.0) * 1000.0) / 1000.0))
		wat.modulate.a = 0.5 if fw >= R.f2() * 0.85 else 1.0   # "Đất còn ướt"
	var rt = rm_gi.get(".rmt")
	if rt != null:
		_txt(rt, String(G.lang.Pi[t.id].n))
		var tm := tfmt((c - minf(c, fw) * 0.09) if fw > 0.0 else c)
		if vf:   # cây có sẵn của làng: cùng dòng giờ, ghi còn mấy ngày thì tự mất (bỏ chữ "Đang ướt" cho vừa chip: vòng nước đã báo)
			tm += " · Còn " + str(G.lang.days_left(t)) + " ngày"
		_rm_small(rt, fw > 0.0 and not vf, tm)

func _rm_tree_pos() -> void:   # am (fi.t): vòng nút đứng trên ngọn cây
	var L = G.lang
	var o: Dictionary = L.objs()[rm_t]
	var tp: Dictionary = L.Pi[o.id]
	var fw := float(tp.fw)
	var fd := float(tp.fd)
	var gx := float(o.gx)
	var gy := float(o.gy)
	var foot := Vector2(F.en(gx + fw / 2.0, gy + fd / 2.0), F.nn(gx + fw / 2.0, gy + fd / 2.0))
	var top: float = L.F.lang_ve.top_of(o)
	var tb := rm_r if (G.w_all.WR.wc(o) and not _rm_vf()) else rm_g
	var box: Control = tb.kids()[0]
	var w = box.r.size.x
	var h = box.r.size.y
	var ra: Vector2 = (foot - main.cam) * main.zoom / Css.K
	var x := clampf(ra.x, w / 2.0 + 8.0, vw - w / 2.0 - 8.0)
	var y := clampf(ra.y + (top - 6.0) * cz(), h + 8.0, vh - 8.0)
	_move(tb, Vector2(round(x), round(y)))
	_move(box, Vector2(-w / 2.0, -h))
	# vignette quanh gốc cây + ngọn
	var mn := Vector2(INF, INF)
	var mx := -mn
	for p in [[0, 0], [fw, 0], [fw, fd], [0, fd]]:
		var q: Vector2 = (Vector2(F.en(gx + p[0], gy + p[1]), F.nn(gx + p[0], gy + p[1])) - main.cam) * main.zoom
		mn = mn.min(q)
		mx = mx.max(q)
	mn.y = minf(mn.y, (foot.y + top - main.cam.y) * main.zoom)
	dim_mat.set_shader_parameter("c", (mn + mx) * 0.5)
	dim_mat.set_shader_parameter("r", Vector2((mx.x - mn.x) / 2.0 * 1.3 + 16.0 * Css.K, (mx.y - mn.y) / 2.0 * 1.3 + 16.0 * Css.K))

func _rm_tree_do(k: String) -> void:
	var t := rm_t
	var R = G.w_all.WR
	var o = R.ql(t)
	if o == null:
		return
	var WRU = G.w_all.WRU
	if _rm_vf():
		if k == "star":   # Dọn: xoá cây ngay
			rm_close()
			G.lang.drop_obj(t)
			return
		if k == "fast" and R.wc(o):   # Hái
			k = "harvest"
	if k == "harvest":
		if R.wc(o):
			rm_close()
			WRU.px(t, "tharvest")
	elif k == "water":
		if float(o.fw) >= R.f2() * 0.85:
			G.toast.emit("Đất còn ướt.")
			return
		rm_close()
		WRU.px(t, "twater")
	elif k == "fast" and not R.wc(o):
		var pa := func():
			if rm_t == t and R.tree_now(t):
				rm_close()
				WRU.px(t, "tharvest")
		xfp._ask(rm_gi.get(".fast"), R.ro(R.tree_left(t)), "Ra trái ngay cây " + String(G.lang.Pi[o.id].n).to_lower() + "?", "", pa)

func _ring(cls: String, col: String, bg: String, fr: float) -> String:
	# s(): vòng tiến độ (lớn: đỏ, nước: xanh), bắt đầu từ đỉnh
	var d := fr * CIRC
	return "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 64 64\"><circle cx=\"32\" cy=\"32\" r=\"28.5\" fill=\"none\" stroke=\"" + bg + "\" stroke-width=\"5\"/>" + ("<circle cx=\"32\" cy=\"32\" r=\"28.5\" fill=\"none\" stroke=\"" + col + "\" stroke-width=\"5\" stroke-linecap=\"round\" stroke-dasharray=\"%.2f %.2f\" transform=\"rotate(-90 32 32)\"/>" % [d, CIRC] if fr > 0.004 else "") + "</svg>"

static func tfmt(t: float) -> String:   # o(): 1g 5p / 3p 20s / 40s
	var s := int(maxf(0.0, ceil(t)))
	var h := s / 3600
	var m := (s % 3600) / 60
	var x := s % 60
	return (str(h) + "g " + str(m) + "p") if h else ((str(m) + "p " + str(x) + "s") if m else (str(x) + "s"))

func _rm_sync() -> void:
	if not rm_d.is_empty():
		rd.sync()
		return
	if not rm_v.is_empty():
		rv.sync()
		return
	if rm_t >= 0:
		_rm_tree_sync()
		return
	var i := rm_i
	if i < 0:
		return
	var a: Dictionary = G.p(i)
	if a.c == null or not a.u:
		rm_close()
		return
	var ripe: bool = G.ripe(a)
	rm_g.visible = not ripe
	rm_r.visible = ripe
	if ripe:
		return
	var cr: Dictionary = G.crop(a.c)
	var gfr := minf(1.0, float(a.g) / float(cr.time))
	var hold: float = G.water_hold(a)
	var wfr := clampf(float(a.w) / hold, 0.0, 1.0)
	var at: float = G.time_left(a)
	var pearls := maxi(1, int(ceil(at / 600.0)))
	var st: int = G.star(a) - 1
	var fast = rm_gi.get(".fast")
	if fast != null:
		_set_svg(fast.kids()[0], _ring("rmf", "#e8324a", "rgba(232,50,74,.16)", round(gfr * 1000.0) / 1000.0))
		_txt(_q(fast, "", "b"), str(pearls))
	var wat = rm_gi.get(".water")
	if wat != null:
		_set_svg(wat.kids()[0], _ring("rmw", "#1e90e8", "rgba(30,144,232,.15)", round(wfr * 1000.0) / 1000.0))
	var star = rm_gi.get(".star")
	if star != null:
		_set_svg(star.kids()[0], _ring5(st).replace("#f3ead0", "#f3ead0"))
	# nhãn: tên cây + (Đang ướt ·) đồng hồ + giờ còn lại
	var rt = rm_gi.get(".rmt")
	if rt != null:
		_txt(rt, cr.name)
		var left := (at - minf(at, float(a.w)) * 0.09) if float(a.w) > 0.0 else at
		_rm_small(rt, float(a.w) > 0.0, tfmt(left))

func _rm_small(rt: Control, wet: bool, tm: String) -> void:
	# small: flex, giữa, gap 4: [Đang ướt][·] [đồng hồ 16] [giờ]
	var sm := _q(rt, "", "small")
	if sm == null:
		return
	var clk: Control = null
	var tb: Control = null
	for k in sm.kids():
		var n: Dictionary = k.get_meta("snap", {})
		if n.get("tag", "") == "svg":
			clk = k
		elif n.get("tag", "") == "b":
			tb = k
	if clk == null or tb == null:
		return
	_txt(tb, tm)
	_rm_col(tb, null)
	_rm_title(rt, false)
	sm.visible = true
	var w1 := Box.text_w("Đang ướt", 12.0, 600) if wet else 0.0
	var w2 := Box.text_w("·", 12.0, 600) if wet else 0.0
	var wt := Box.text_w(tm, 12.0, 800)
	var gap := 4.0
	var total := (w1 + gap + w2 + gap if wet else 0.0) + 16.0 + gap + wt
	var x = (sm.r.size.x - total) * 0.5
	if not sm.has_meta("wet"):
		var b1: Control = Box.new()
		b1.style("", 1.0)
		b1.place(Rect2(0, 0, 60, sm.r.size.y))
		b1.text("Đang ướt", Rect2(0, 0, 60, sm.r.size.y), 12.0, 600, Color8(138, 106, 72), "left")
		b1.text("·", Rect2(0, 0, 10, sm.r.size.y), 12.0, 600, Color8(138, 106, 72), "left")
		sm.add(b1)
		sm.set_meta("wet", b1)
	var wb: Control = sm.get_meta("wet")
	wb.visible = wet
	if wet:
		wb.texts[0].rect = Rect2(x, 0, w1, sm.r.size.y)
		wb.texts[1].rect = Rect2(x + w1 + gap, 0, w2, sm.r.size.y)
		wb.redraw()
		x += w1 + gap + w2 + gap
	clk.visible = true
	_move(clk, Vector2(x, clk.r.position.y))
	x += 16.0 + gap
	tb.place(Rect2(Vector2(x, tb.r.position.y), Vector2(wt + 2.0, tb.r.size.y)))
	tb.texts[0].rect = Rect2(0, tb.texts[0].rect.position.y, wt + 2.0, tb.texts[0].rect.size.y)
	tb.texts[0].al = "left"
	tb.redraw()

func _rm_pos() -> void:
	# rt(): vòng nút đứng trên ngọn cây
	if not rm_d.is_empty():
		rd.pos()
		return
	if not rm_v.is_empty():
		rv.pos()
		return
	if rm_t >= 0:
		_rm_tree_pos()
		return
	if rm_i < 0:
		return
	var a: Dictionary = G.p(rm_i)
	var top := rm_r if G.ripe(a) else rm_g
	var box: Control = top.kids()[0]
	var ra := plot_css(rm_i)
	var gt: float = F.OU[G.stage(a)] if a.c != null else 20.0
	var w = box.r.size.x
	var h = box.r.size.y
	var x := clampf(ra.x, w / 2.0 + 8.0, vw - w / 2.0 - 8.0)
	var y := clampf(ra.y - (gt + 16.0) * cz(), h + 8.0, vh - 8.0)
	_move(top, Vector2(round(x), round(y)))
	_move(box, Vector2(-w / 2.0, -h))
	# vignette quanh ô
	var q := []
	var c: Dictionary = G.cells[rm_i]
	for p in [[0, 0], [1, 0], [1, 1], [0, 1]]:
		q.append((Vector2(F.en(c.gx + p[0], c.gy + p[1]), F.nn(c.gx + p[0], c.gy + p[1], G.CO)) - main.cam) * main.zoom)
	var mn: Vector2 = q[0]
	var mx: Vector2 = q[0]
	for p in q:
		mn = mn.min(p)
		mx = mx.max(p)
	mn.y -= gt * main.zoom
	var rr := Vector2((mx.x - mn.x) / 2.0 * 1.3 + 16.0 * Css.K, (mx.y - mn.y) / 2.0 * 1.3 + 16.0 * Css.K)
	dim_mat.set_shader_parameter("c", (mn + mx) * 0.5)
	dim_mat.set_shader_parameter("r", rr)

func _rm_do(k: String) -> void:
	if not rm_d.is_empty():
		rd.act(k)
		return
	if not rm_v.is_empty():
		rv.act(k)
		return
	if k == "chip":
		return
	if rm_t >= 0:
		_rm_tree_do(k)
		return
	var i := rm_i
	if i < 0:
		return
	var a: Dictionary = G.p(i)
	if k == "harvest":
		if G.ripe(a):
			rm_close()
			F.queue_job(i, "harvest")
		return
	if k == "fast":   # dd(nút, Ro(b3), fL, "Chín ngay ...?")
		if G.ripe(a) or a.c == null:
			return
		var nt := maxi(1, int(ceil(G.time_left(a) / 600.0)))   # Ro
		var pa := func():
			if rm_i == i and G.fast_ripe(i):
				rm_close()
				F.queue_job(i, "harvest")
		xfp._ask(rm_gi.get(".fast"), nt, "Chín ngay " + String(G.crop(a.c).name).to_lower() + "?", "", pa)
		return
	if k == "star":
		rm_close()
		spp.open(i)
		return
	if k == "water":
		rm_close()
		F.queue_job(i, "water")

# ------------------------------------------------------------------ ô chưa mở (#ppop, G1 "lock")
var lk_b: Control = null
var lk_ids := {}
var lk_i := -1
var lk_note: Control = null
var lk_h0 := 0.0

func _build_lock() -> void:
	var d: Dictionary = Snap.load_snap("lock")
	lk_b = _build(d["#ppop"][0], lk_ids)
	lk_b.visible = false
	_stop(lk_b)
	root.add_child(lk_b)
	lk_h0 = lk_b.r.size.y
	_click(lk_ids.get(".ppbig"), _lock_buy)
	_click(lk_ids.get(".ppx"), lock_close)

func lock_open(i: int) -> void:
	pc_close()
	gv_close()
	rm_close()
	dock_open(false)
	lk_i = i
	lk_b.visible = true
	_lock_sync()
	_lock_pos()

func lock_close() -> void:
	lk_i = -1
	if lk_b != null:
		lk_b.visible = false

func _lock_sync() -> void:
	if lk_i < 0:
		return
	var c: int = G.open_cost()
	var btn = lk_ids.get(".ppbig")
	if btn != null:
		_txt(btn, "Mở ô đất · " + G.fmt_n(c))
		btn.modulate.a = 1.0 if int(G.g.coins) >= c else 0.55
	var more: int = G.lv_for_more()
	var note := ("Đã đủ " + str(G.max_open()) + " ô cho cấp này. Lên cấp " + str(more) + " mở thêm.") if more > 0 else ""
	if note != "" and lk_note == null:
		lk_note = Box.new()
		lk_note.style("", 1.0)
		var pin = lk_ids.get(".u2pin")
		var y: float = (pin.r.end.y if pin != null else lk_h0) - 10.0
		lk_note.place(Rect2(12, y, lk_b.r.size.x - 24, 18))
		lk_note.text(note, Rect2(0, 0, lk_b.r.size.x - 24, 18), 12.0, 400, Color8(138, 120, 96), "center", [], true)
		lk_b.add(lk_note)
	if lk_note != null:
		lk_note.visible = note != ""
		if note != "":
			lk_note.set_text(0, note)
	var h := lk_h0 + (18.0 if note != "" else 0.0)
	if absf(lk_b.r.size.y - h) > 0.5:
		lk_b.place(Rect2(lk_b.r.position, Vector2(lk_b.r.size.x, h)))

func _lock_pos() -> void:
	# am(): trên ô 26 px; sát mép trên thì xuống dưới ô; mũi tên chỉ đúng ô (--ax)
	if lk_i < 0:
		return
	var t := plot_css(lk_i, 0.0)
	var o = lk_b.r.size.x
	var l = lk_b.r.size.y
	var s := maxf(8.0, minf(vw - o - 8.0, t.x - o / 2.0))
	var h = t.y - l - 26.0
	var below := false
	if h < 70.0:
		h = t.y + 24.0
		below = true
	h = maxf(8.0, minf(vh - l - 8.0, h))
	_move(lk_b, Vector2(round(s), round(h)))
	var ax := clampf(t.x - s, 18.0, o - 18.0)
	var arrow: Control = null
	for k in lk_b.kids():
		if not k.has_meta("snap"):
			arrow = k
	if arrow != null:
		arrow.position = Vector2(ax - arrow.r.size.x * 0.5, (-arrow.r.size.y * 0.5) if below else (l - arrow.r.size.y * 0.5)) * Css.K

func _lock_buy() -> void:
	var i := lk_i
	if i < 0:
		return
	# vá L1 cho iy: đủ cấp mà thiếu xu -> "Mở ô đất còn thiếu xu:" bù bằng sen đỏ rồi mở luôn (hw)
	var t: int = G.open_cost()
	if G.lv_for_more() == 0 and int(G.g.coins) < t and not G.p(i).u and G.owned(i):
		lock_close()
		_lack_open([], "Mở ô đất còn thiếu xu:", func():
			if G.open_plot(i):
				F.ts(i, "unlock"), t - int(G.g.coins))
		return
	if G.open_plot(i):
		F.ts(i, "unlock")
		lock_close()

# ------------------------------------------------------------------ Kho
var kho_tab := 0
var kho_on := false
var kh_q := 1                # vi.q
var kh_sel := ""
var kh_f := "all"
var kh_sort := "n"
const KH_CAT := [["all", "Tất cả"], ["nong", "Nông sản"], ["trai", "Trái cây"], ["nuoi", "Vật nuôi"], ["song", "Cá"], ["chebien", "Chế biến"], ["khac", "Khác"]]
const KH_SORT := [["n", "Nhiều nhất"], ["v", "Đáng giá nhất"], ["p", "Giá lên"], ["a", "Tên A–Z"]]

func kho_open() -> void:
	for p in _pans():
		if p != null:
			p.close()
	if vlp != null:
		vlp.close()
	if ngp != null:
		ngp.close()
	if nvp != null:
		nvp.close()
	pc_close()
	ord_close()
	gv_close()
	rm_close()
	lock_close()
	kho_on = true
	khop.open_tab(kho_tab)
	khop.open()

func _kho_full(n: int, cap: int) -> void:
	if khp != null:
		khp.full(n, cap)

func kho_close() -> void:
	kho_on = false
	if khop != null and khop.on:
		khop.close()

func _kho_tab(j: int) -> void:
	if j != kho_tab:
		kh_sel = ""
	kho_tab = j
	khop.open_tab(j)

func _cat(t: String) -> String:   # rP
	if G.D.crops.has(t):
		return "nong"
	var a: Dictionary = G.item(t)
	var n: String = a.get("from", "")
	if n in ["fish", "bun", "ao", "song"]:
		return "song"
	if n == "tree":
		return "trai"
	if n in ["ga", "cuu", "bo", "heo", "de", "vit", "ong"]:
		return "nuoi"
	if n != "":
		return "chebien"
	return "khac"

func _kho_items() -> Array:
	var e := []
	for t in G.g.barn.keys():
		if int(G.g.barn[t]) > 0 and (kh_f == "all" or _cat(t) == kh_f):
			e.append(t)
	var s := kh_sort
	e.sort_custom(func(a, b):
		var na := int(G.g.barn[a])
		var nb := int(G.g.barn[b])
		if s == "v":
			return nb * G.price(b) < na * G.price(a)
		if s == "p":
			return float(G.g.get("mult", {}).get(b, 1.0)) < float(G.g.get("mult", {}).get(a, 1.0))
		if s == "a":
			return String(G.item(a).get("name", a)) < String(G.item(b).get("name", b))
		return nb < na)
	return e

static func _xn(x: float) -> String:
	# 2 -> "2", 1.5 -> "1,5" (như web: String(số))
	if absf(x - round(x)) < 0.001:
		return str(int(round(x)))
	return str(snappedf(x, 0.01)).replace(".", ",")

func _cat_name(c: String) -> String:
	for q in KH_CAT:
		if q[0] == c:
			return q[1]
	return ""

func _mat_id(name: String) -> String:
	if G.D.mat is Dictionary:
		for k in G.D.mat.keys():
			var m = G.D.mat[k]
			if m is Dictionary and m.get("n", "") == name:
				return k
	return ""


# ------------------------------------------------------------------ chạm ô ruộng (c2 bản web)
# ------------------------------------------------------------------ đơn hàng (#pn-orders, ws / jp bản web)
var od_on := false
var od_src := ""              # (bản 353) "" = Đơn hàng; quancom / taphoa / cafe = khách quán (w_quan.cards) trên cùng bảng
var od_L := []                # danh sách thẻ của od_src (làm mới mỗi lần _ord_sync)
var od_ud := {"i": -1, "t": 0.0}
var od_lk: Control = null
var od_lk_tpl := {}
var od_xu_span := {}

func _build_ord() -> void:   # (11-27) Đơn hàng vẽ ở ui_ord2.gd; đây chỉ còn mẫu popup "Còn thiếu một chút!"
	# ô "xu" của popup thiếu xu (Khai hoang ... còn thiếu xu:), cùng khổ ô món
	var xl: Dictionary = Snap.load_snap("pc_lack")[".nglkov"][0].duplicate(true)
	var xb := Snap.find(xl, "nglk")
	var xm := RegEx.create_from_string("matrix\\(([0-9.]+)").search(String(xb.css.get("transform", "")))
	if xm != null:
		_od_unscale(xb, Vector2(float(xb.r[0]) + float(xb.r[2]) * 0.5, float(xb.r[1]) + float(xb.r[3]) * 0.5), float(xm.get_string(1)))
	od_xu_span = Snap.find(xb, "nglc")
	for nm in ["ord_lack", "ord_lack2"]:
		# số đo chụp lúc popup còn đang hiện dần (mờ .72, phóng 1,04): đưa về lúc hiện xong
		var n: Dictionary = Snap.load_snap(nm)[".nglkov"][0].duplicate(true)
		n.css["opacity"] = "1"
		var bx := Snap.find(n, "nglk")
		var m := RegEx.create_from_string("matrix\\(([0-9.]+)").search(String(bx.css.get("transform", "")))
		if m != null:
			var k := float(m.get_string(1))
			var c := Vector2(float(bx.r[0]) + float(bx.r[2]) * 0.5, float(bx.r[1]) + float(bx.r[3]) * 0.5)
			_od_unscale(bx, c, k)
			bx.css["transform"] = "none"
		od_lk_tpl[nm] = n

static func _od_unscale(n: Dictionary, c: Vector2, k: float) -> void:
	for key in ["r", "tr"]:
		if n.has(key):
			var r: Array = n[key]
			n[key] = [c.x + (float(r[0]) - c.x) / k, c.y + (float(r[1]) - c.y) / k, float(r[2]) / k, float(r[3]) / k]
	for q in n.get("kids", []):
		_od_unscale(q, c, k)

static func _fsz(n: Dictionary) -> float:
	return Css.px(n.css.get("font-size", "15px")) * float(n.get("z", 1.0))

static func _tw(n: Dictionary, s: String) -> float:
	return Box.text_w(s, _fsz(n), int(n.css.get("font-weight", "400")))

static func _set_t(n: Dictionary, s: String, x: float, w := -1.0) -> void:
	# chữ mới, hộp chữ bắt đầu ở x (css px trang)
	n.text = s
	var tr: Array = n.get("tr", n.r)
	n.tr = [x, float(tr[1]), _tw(n, s) + 0.5 if w < 0.0 else w, float(tr[3])]

static func _nshift(n: Dictionary, dx: float) -> void:
	n.r = [float(n.r[0]) + dx, n.r[1], n.r[2], n.r[3]]
	if n.has("tr"):
		n.tr = [float(n.tr[0]) + dx, n.tr[1], n.tr[2], n.tr[3]]

static func rf(t: float) -> String:   # RF(ao): 4p 59s / 12p / 40s
	var s := int(maxf(1.0, ceil(t)))
	var h := s / 3600
	var m := (s % 3600) / 60
	var e := s % 60
	if h:
		return str(h) + "g" + ((" " + str(m) + "p") if m else "")
	if m >= 10:
		return str(m) + "p"
	if m:
		return str(m) + "p" + ((" " + str(e) + "s") if e else "")
	return str(e) + "s"

func qk_open(k: String) -> void:   # bảng khách quán: dùng chung bảng Đơn hàng
	ord_open(k)

func _od_list() -> Array:
	return G.g.orders if od_src == "" else od_L

func ord_open(src := "") -> void:   # (11-27) bảng Đơn hàng trên khung chung (ui_ord2.gd); src: "" đơn hàng / quancom / taphoa / cafe
	if nvp != null:
		nvp.close()
	pc_close()
	gv_close()
	rm_close()
	lock_close()
	kho_close()
	for p in _pans():
		if p != null and p != ordp:
			p.close()
	ordp.open(src)

func ord_close() -> void:
	_lack_close()
	if ordp != null and ordp.on:
		ordp.close()
	od_on = false

func _anchor_of(b: Control):
	for a in anchors:
		if a[0] == b:
			return a
	return null

func _od_order() -> Array:
	# thẻ đủ hàng trước (order 1), đơn thường (2), khách đang tới cuối (3)
	if od_src != "":
		od_L = G.w_all.WQ.cards(od_src)
	var plan: Array = G.ord_plan(null if od_src == "" else od_L)
	var L := []
	for f in _od_list().size():
		var k := 3 if plan[f] == null else (1 if plan[f].ok else 2)
		L.append([k, f])
	L.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	return [L, plan]

func _ord_sync() -> void:   # dựng lại bảng Đơn hàng (đổi đơn, giao, mua bù...)
	if ordp != null and ordp.on:
		ordp.sig = ""
		ordp._build()

func _od_deliver(f: int) -> void:
	if od_src != "":
		G.w_all.WQ.giao(od_src, f)
		_ord_sync()
		return
	var r = G.deliver(f)
	if r is Dictionary and r.has("lack"):
		_lack_open(r.lack, r.why, func(): _od_deliver(f))
	_ord_sync()

func _od_lack_btn(f: int) -> void:
	var pl: Array = G.ord_plan()
	if f >= pl.size() or pl[f] == null or pl[f].ok or pl[f].miss.is_empty():
		return
	_lack_open(pl[f].miss, "Đơn của " + str(G.g.orders[f].who) + " còn thiếu:", func(): _od_deliver(f))

func _od_swap(f: int) -> void:
	# chạm 1: "Đổi?" 3 giây; chạm 2: đổi đơn, khách mới tới sau 5 phút
	var now: float = G._now_ms()
	if od_ud.i == f and now < od_ud.t:
		od_ud.i = -1
		G.swap(f)
	else:
		od_ud = {"i": f, "t": now + 3000.0}
	_ord_sync()

func _od_kind(t: String) -> String:   # d$: món này lấy ở đâu (bản Godot mới có ruộng)
	if G.D.crops.has(t):
		return "crop"
	var a: Dictionary = G.item(t)
	var fr: String = a.get("from", "")
	if fr in ["ga", "cuu", "bo", "heo", "de"]:
		return "pen:" + fr
	if t == "thit_vit" or t == "trung_vit":
		return "vit"
	if fr in ["fish", "bun", "ao", "song"]:
		return "fish"
	if fr == "tree":
		return "tree"
	if fr != "":
		return "work"
	return "cho"

const OD_PEN := {"ga": "Chuồng gà", "cuu": "Chuồng cừu", "bo": "Chuồng bò", "heo": "Chuồng heo", "de": "Chuồng dê"}

func _od_get(f: int) -> void:   # g$
	var pl: Array = G.ord_plan(null if od_src == "" else od_L)
	if f >= pl.size() or pl[f] == null or pl[f].ok or pl[f].miss.is_empty():
		return
	var o: Dictionary = _od_list()[f]
	var e: String = pl[f].miss[0][0]
	var r := int(pl[f].miss[0][1])
	var nm: String = G.item_name(e)
	var c := int(G.g.barn.get(e, 0))
	var need := 0
	for it in o.items:
		if it[0] == e:
			need = int(it[1])
	var s := (" Kho có " + str(c) + " nhưng đang để cho đơn khác.") if c >= need else ""
	var h := "Thiếu " + str(r) + " " + nm.to_lower() + ": "
	var k := _od_kind(e)
	if k == "crop":
		var p: int = c - (F.seeds_queued(e) if F.has_method("seeds_queued") else 0)
		if p <= 0:
			say(h + "hết hạt, mua ở Chợ phiên.")
			ord_close()
			return
		var d := -1
		for v in G.g.plots.size():
			var x: Dictionary = G.g.plots[v]
			if x.u and x.c == null:
				d = v
				break
		if d < 0:
			say(h + "ruộng đang kín, gặt xong rồi gieo " + nm.to_lower() + "." + s)
			ord_close()
			return
		ord_close()
		gv_open(d)
		say(h + "gieo ở ruộng, 1 hạt gặt 2." + s)
		return
	if k.begins_with("pen:"):
		ord_close()
		say(h + "lấy ở " + String(OD_PEN.get(k.substr(4), "chuồng")).to_lower() + "." + s)
		return
	if k == "work":
		ord_close()
		say(h + "làm ở xưởng." + s)
		return
	if k == "fish":
		ord_close()
		say(h + "đi câu cá." + s)
		return
	if k == "vit":
		say(h + "nuôi vịt ở ao." + s)
		return
	if k == "tree":
		say(h + "hái ở cây trái trong vườn." + s)
		return
	ord_close()
	say(h + "mua ở Chợ phiên." + s)

# ---- L1: "Còn thiếu một chút!" bù phần thiếu bằng sen đỏ
func _lack_open(items: Array, why: String, go: Callable, xu := 0, mats := []) -> void:
	_lack_close()
	# L1: sen đỏ = H2(món) + mL(vật liệu: gạch 4, khác 3) + bL(xu) (1 sen mỗi 25 xu, ít nhất 1)
	var r: int = (G.lack_cost(items) if not items.is_empty() else 0) + (maxi(1, int(ceil(xu / 25.0))) if xu > 0 else 0)
	for q in mats:
		r += int(q[1]) * (4 if q[0] == "gach" else 3)
	var have := int(G.g.ngoc)
	var rich := have >= r
	var n: Dictionary = od_lk_tpl["ord_lack" if rich else "ord_lack2"].duplicate(true)
	var bx: Dictionary = Snap.find(n, "nglk")
	var cxb: float = float(bx.r[0]) + float(bx.r[2]) * 0.5
	var p: Dictionary = Snap.find(bx, "", "p")
	_set_t(p, why, cxb - _tw(p, why) * 0.5)
	# món thiếu: [hình][×n][tên], xếp giữa, cách 8
	var cs := Snap.find(bx, "nglcs")
	var c0: Dictionary = cs.kids[0]
	var spans := []
	var W := 0.0
	var L := items.duplicate()
	for q in mats:
		L.append(["__m", q[1], q[0]])
	if xu > 0:
		L.append(["__xu", xu])
	for it in L:
		var sp: Dictionary = (c0 if it[0] != "__xu" else od_xu_span).duplicate(true)
		var sv: String = "" if it[0] == "__xu" else (String(khp.mat_svg.get(it[2], "")) if it[0] == "__m" else FileAccess.get_file_as_string("res://ui/svg/kh/" + String(it[0]) + ".svg"))
		for k in sp.kids:
			if k.tag == "svg" and sv != "":
				k.svg = sv
		var bn: Dictionary = Snap.find(sp, "", "b")
		var sm: Dictionary = Snap.find(sp, "", "small")
		var nm: String = "xu" if it[0] == "__xu" else G.item_name(it[2] if it[0] == "__m" else it[0])
		var w: float = maxf(float(c0.r[2]), _tw(sm, nm) + 8.0)
		var d: float = (w - float(c0.r[2])) * 0.5
		for k in sp.kids:
			_nshift(k, d)
		sp.r = [sp.r[0], sp.r[1], w, sp.r[3]]
		# "×n" đỏ ở góc phải trên ô (b::before "×" + số): một dòng chữ
		var br: float = float(bn.r[0]) + float(bn.r[2])
		var xs: String = "×" + (G.fmt_n(int(it[1])) if it[0] == "__xu" else str(int(it[1])))
		var nw := _tw(bn, xs)
		bn.erase("::before")
		_set_t(bn, xs, br - nw, nw)
		bn.r = [br - nw, bn.r[1], nw, bn.r[3]]
		var scx: float = float(sp.r[0]) + w * 0.5
		_set_t(sm, nm, scx - _tw(sm, nm) * 0.5)
		sm.r = [float(sp.r[0]), sm.r[1], w, sm.r[3]]
		spans.append(sp)
		W += w
	W += 8.0 * maxf(0.0, spans.size() - 1)
	var x := cxb - W * 0.5
	var out := []
	for sp in spans:
		out.append(Snap.moved(sp, Vector2(x - float(sp.r[0]), 0)))
		x += float(sp.r[2]) + 8.0
	cs.kids = out
	# nút: "Bù ngay [sen r]" / "Nạp thêm sen đỏ [sen r]"
	var bt := Snap.find(bx, "ngbuy")
	var cost := Snap.find(bt, "ngcost")
	var cb: Dictionary = Snap.find(cost, "", "b")
	var old_cw: float = float(cb.r[2])
	var nw2 := _tw(cb, str(r))
	var dcw := nw2 - old_cw
	cb.r = [cb.r[0], cb.r[1], nw2, cb.r[3]]
	if cb.has("tr"):
		cb.tr = [cb.tr[0], cb.tr[1], nw2, cb.tr[3]]
	cb.text = str(r)
	cost.r = [cost.r[0], cost.r[1], float(cost.r[2]) + dcw, cost.r[3]]
	var bw: float = float(bt.r[2]) + dcw
	var bx0 := cxb - bw * 0.5
	var sh := bx0 - float(bt.r[0])
	bt.r = [bx0, bt.r[1], bw, bt.r[3]]
	if bt.has("tr"):
		bt.tr = [float(bt.tr[0]) + sh, bt.tr[1], bt.tr[2], bt.tr[3]]
	Snap._move(cost, Vector2(sh, 0))
	var hv := Snap.find(bx, "nghave")
	var hs: String = "Đang có " + G.fmt_n(have) + " sen đỏ"
	_set_t(hv, hs, cxb - _tw(hv, hs) * 0.5)
	var ids := {}
	od_lk = _build(n, ids)
	root.add_child(od_lk)
	anchors.append([od_lk, 0.5, 0.5])
	_stop(od_lk)
	tap_close(od_lk, _lack_close)
	var box = ids.get(".nglk")
	if box != null:
		_stop(box)
	_click(ids.get(".ngx"), _lack_close, "scale")
	_click(ids.get(".ngbuy"), func():
		_lack_close()
		if int(G.g.ngoc) < r:
			say("Còn thiếu " + str(r - int(G.g.ngoc)) + " sen đỏ.")
		else:
			G.g.ngoc = int(G.g.ngoc) - r
			G.nv.spent(r)
			for q in items:
				G.g.barn[q[0]] = int(G.g.barn.get(q[0], 0)) + int(q[1])
			for q in mats:
				G.mat_add(q[0], int(q[1]))   # S0
			G.g.coins = int(G.g.coins) + xu
			G.mark()
			go.call()
		_ord_sync(), "down")
	_layout()

func _lack_close() -> void:
	if od_lk != null:
		anchors.erase(_anchor_of(od_lk))
		od_lk.queue_free()
		od_lk = null

const VScroll = preload("res://logic/vscroll.gd")
var gv_sc = VScroll.new()   # cuộn khay giống ô ruộng (bản 276: nhiều giống quá 3 hàng thì kéo được)
var _scs := []              # (bản 287) cuộn của các bảng khối Godot (w_ui_base._panel): ui._input đưa sự kiện vào

func scroll_add(v) -> void:
	_scs = _scs.filter(func(q): return q.area != null and is_instance_valid(q.area))
	_scs.append(v)

func scroll_moved() -> bool:   # vừa kéo cuộn một bảng (nhả tay không tính là bấm)
	for v in [gv_sc] + _scs:
		if v.moved():
			return true
	return false

# ------------------------------------------------------------------ khai hoang: bảng chạm biển (Vm "parcel" + Qm + xC bản web)
var pc_id := ""
var pc_w := Vector2.ZERO        # chỗ chạm (làng)
var pc_b: Control = null
var pc_sig := ""
var pc_off := Vector2.ZERO
var pc_tpl := {}

func _build_pc() -> void:
	for k in ["lv", "buy", "far"]:
		var d: Dictionary = Snap.load_snap("pc_" + k)
		pc_tpl[k] = d[d.keys()[0]][0]

func pc_open(id: String, w: Vector2) -> void:
	close_all()
	pc_id = id
	pc_w = w
	pc_sig = ""
	_pc_sync()

func pc_close() -> void:
	pc_id = ""
	if pc_b != null:
		pc_b.queue_free()
		pc_b = null

static func _grow_at(n: Dictionary, y: float, d: float) -> void:
	# dời mọi thứ nằm dưới y xuống d, kéo dài những gì vắt qua y
	var y0 := float(n.r[1])
	var y1 := y0 + float(n.r[3])
	if y0 >= y - 0.5:
		Snap._move(n, Vector2(0, d))
		return
	if y1 > y - 0.5:
		n.r = [n.r[0], n.r[1], n.r[2], float(n.r[3]) + d]
	for k in n.get("kids", []):
		_grow_at(k, y, d)

func _pc_state() -> Array:
	# [dáng, tiêu đề, mô tả] như Vm(): chưa kề = "Đất hoang"; chưa đủ cấp = không nút; còn lại = nút Khai hoang · giá
	var n: Dictionary = F.PC.G0[pc_id]
	if not F.pc_next(pc_id):
		return ["far", "Đất hoang", "Khai hoang khu đất bên cạnh trước để mở khu này."]
	var t := "Khai hoang " + String(n.name).to_lower()
	var r: int = F.pc_lv(pc_id)
	if r > 0:
		return ["lv", t, "Lên cấp " + str(r) + " mới khai hoang được. " + String(n.desc)]
	return ["buy", t, String(n.desc)]

func _pc_sync() -> void:
	if pc_id == "":
		return
	if F.pc_own(pc_id):
		pc_close()
		return
	var st := _pc_state()
	var n: Dictionary = (pc_tpl[st[0]] as Dictionary).duplicate(true)
	var cost := int(F.PC.G0[pc_id].cost)
	# chữ: tiêu đề một dòng; mô tả xuống dòng theo bề ngang (12,5px, dòng 18,125px)
	var tb: Dictionary = Snap.find(n, "u2pt").kids[0]
	_set_t(tb, st[1], float(tb.r[0]))
	tb.r = [tb.r[0], tb.r[1], tb.tr[2], tb.r[3]]
	var ps: Array = []
	_qall_n(n, "hdes", ps)
	var p0: Dictionary = ps[0]
	var lh := Css.px(p0.css.get("line-height", "18.125px"))
	var fs := _fsz(p0)
	var fw := int(p0.css.get("font-weight", "500"))
	var l0 := int(round(float(p0.r[3]) / lh))
	var l1 := _nlines(st[2], fs, fw, float(p0.r[2]))
	p0.text = st[2]
	p0.erase("tr")
	var d := (l1 - l0) * lh
	if absf(d) > 0.01:
		var yb: float = float(p0.r[1]) + float(p0.r[3])
		p0.r = [p0.r[0], p0.r[1], p0.r[2], float(p0.r[3]) + d]
		for k in n.kids:
			_grow_at(k, yb, d)
		n.r = [n.r[0], n.r[1], n.r[2], float(n.r[3]) + d]
	if st[0] == "buy":
		# "Khai hoang · 300 [xu]": nút ôm chữ
		var bt := Snap.find(n, "hmini")
		var im := Snap.find(bt, "xui")
		var tr: Array = bt.tr
		var pl: float = float(tr[0]) - float(bt.r[0])
		var g: float = float(im.r[0]) - (float(tr[0]) + float(tr[2]))
		var pr: float = float(bt.r[0]) + float(bt.r[2]) - (float(im.r[0]) + float(im.r[2]))
		var s: String = "Khai hoang · " + G.fmt_n(cost)
		var tw := _tw(bt, s)
		bt.text = s
		bt.tr = [tr[0], tr[1], tw + 0.5, tr[3]]
		bt.css["text-align"] = "left"
		im.r = [float(tr[0]) + tw + g, im.r[1], im.r[2], im.r[3]]
		bt.r = [bt.r[0], bt.r[1], pl + tw + g + float(im.r[2]) + pr, bt.r[3]]
	# chỗ đặt (xC): ngang giữa chỗ chạm, trên chỗ chạm 18; sát mép trên quá thì lật xuống dưới
	var H: float = float(n.r[3])
	var Wd: float = float(n.r[2])
	var a: Vector2 = (Vector2(pc_w.x, pc_w.y - 18.0) - main.cam) * main.zoom / Css.K
	var l := maxf(8.0, minf(vw - Wd - 8.0, a.x - Wd * 0.5))
	var c := a.y - H - 18.0
	var below := false
	if c < 70.0:
		c = a.y + 40.0
		below = true
	c = maxf(8.0, minf(vh - H - 8.0, c))
	var ax := roundf(maxf(18.0, minf(Wd - 18.0, a.x - l)))
	if n.has("::after"):
		n["::after"].left = str(ax - 8.0) + "px"
		n["::after"].top = (str(-6.05) if below else str(H - 9.95)) + "px"
	var sig := JSON.stringify(st) + str(cost) + str(ax) + str(below) + str(H)
	pc_off = Vector2(l, c) - Vector2(float(n.r[0]), float(n.r[1]))
	if sig != pc_sig:
		pc_sig = sig
		if pc_b != null:
			pc_b.queue_free()
		var ids := {}
		pc_b = _build(n, ids)
		root.add_child(pc_b)
		_stop(pc_b)
		_click(ids.get(".ppx"), pc_close, "scale")
		var id := pc_id
		_click(ids.get(".hmini"), func(): pc_close(); pc_try(id), "down")
	pc_b.position = (pc_b.r.position + pc_off) * Css.K

func _qall_n(n: Dictionary, cls: String, out: Array) -> void:
	if String(n.get("cls", "")).split(" ").has(cls):
		out.append(n)
	for k in n.get("kids", []):
		_qall_n(k, cls, out)

func pc_try(id: String) -> void:
	# pb + vá L1: đủ điều kiện mà thiếu xu -> "Khai hoang ... còn thiếu xu:" bù bằng sen đỏ rồi mua luôn
	var n: Dictionary = F.PC.G0[id]
	var cost := int(n.cost)
	if not F.pc_own(id) and F.pc_next(id) and F.pc_lv(id) == 0 and int(G.g.coins) < cost:
		_lack_open([], "Khai hoang " + String(n.name).to_lower() + " còn thiếu xu:", func(): pc_try(id), cost - int(G.g.coins))
		return
	F.pc_buy(id)

func tap_plot(i: int) -> void:
	var a: Dictionary = G.p(i)
	if not a.u:
		lock_open(i)
	elif a.c == null:
		gv_open(i)
	else:
		rm_open(i)

func vn_open(va: Dictionary, _w := Vector2.ZERO) -> void:   # chạm con vật / chuồng: vòng nút chung (rm_vn.gd)
	rv.open(va)

var xfp = null               # vòng xưởng (ui_xf.gd)
func xf_open(k: String) -> void:
	xfp.open(k)

func vl_open(u: int) -> void:   # gu("nha", u): chạm nhà dân
	if G.w_all == null:
		return
	if vlp == null:
		vlp = load("res://logic/ui_vl.gd").new(self, G.w_all.WL, G.w_all.WC)
	close_all()
	kho_close()
	vlp.open(u)

func ng_open(t := "") -> void:   # ngcOpen: nút Nghề trong Menu
	if G.w_all == null:
		return
	if ngp == null:
		ngp = load("res://logic/ui_ng.gd").new(self, G.w_all.WL)
	close_all()
	kho_close()
	ngp.open(t)

func sl_open() -> void:   # Al("book"): nút Sổ làng trong Menu
	if G.w_all == null:
		return
	if slp == null:
		slp = load("res://logic/ui_sl.gd").new(self, G.w_all.WCA, G.w_all.WL, G.w_all.WH)
	close_all()
	kho_close()
	slp.open()

func ut_open(t := "") -> void:   # utOpen: Sổ làng › Uy tín làng
	if G.w_all == null:
		return
	if utp == null:
		utp = load("res://logic/ui_ut.gd").new(self, G.w_all.WL)
	close_all()
	kho_close()
	utp.open(t)

func kl_open(t := "") -> void:   # klOpen: Sổ làng › Kỷ lục
	if G.w_all == null:
		return
	if klp == null:
		klp = load("res://logic/ui_kl.gd").new(self, G.w_all.WCA)
	close_all()
	kho_close()
	klp.open(t)

func kl_show() -> void:   # klShow: thẻ trái khủng (người chơi gặt)
	if G.w_all == null:
		return
	if klcp == null:
		klcp = load("res://logic/ui_klc.gd").new(self, G.w_all.WCA)
	klcp.show_next()

func gd_open(t := "") -> void:   # ZC: Sổ làng › Sổ tay
	if gdp == null:
		gdp = load("res://logic/ui_gd.gd").new(self)
	close_all()
	kho_close()
	gdp.open(t)

func rk_open() -> void:   # Qk: Sổ làng › Xếp hạng (Jg("xephang"))
	if G.w_all == null or not G.w_all.WL._jg("xephang"):
		return
	if rkp == null:
		rkp = load("res://logic/ui_rk.gd").new(self)
	close_all()
	kho_close()
	rkp.open()

func _pans() -> Array:   # các bảng dựng từ mẫu web (ui_bang.gd): đóng, step, input chung
	return [slp, utp, hrp, gpp, ghp, chop, ccpp, lopp, lgp, tnp, hdnp, clgp, sysp, dlp, klp, klcp, gdp, rkp, ddp, napp, ttp, skyp, thup, pcp, khop, ordp, dkp, kupp, bdp.shop if bdp != null else null]

func _pan_open(v: String, path: String, args: Array) -> Variant:   # tạo bảng lần đầu, đóng bảng khác
	if get(v) == null:
		set(v, load(path).callv("new", [self] + args))
	close_all()
	kho_close()
	return get(v)

func lg_open(k: String) -> void:   # (11-25) chạm lò gạch: bảng Nung gạch
	if G.w_all == null or k == "":
		return
	_pan_open("lgp", "res://logic/ui_lg.gd", []).open(k)

func lop_open() -> void:   # (bản 547) Menu › Làm ăn › Lờ lọp
	if G.w_all == null:
		return
	_pan_open("lopp", "res://logic/ui_lop.gd", []).open()

func hdn_open(t := "") -> void:   # hdnOpen: Sổ làng › Hội đình
	if G.w_all == null:
		return
	_pan_open("hdnp", "res://logic/ui_hdn.gd", [G.w_all.WH]).open(t)

func dl_open() -> void:   # O6: Du lịch miệt vườn (Jg("dulich"): chưa tới cấp thì báo)
	if G.w_all == null or not G.w_all.WL._jg("dulich"):
		return
	_pan_open("dlp", "res://logic/ui_dl.gd", [G.w_all.WDL]).open()

func sys_open(t := "") -> void:   # gu("sys"): Menu › Hệ Thống
	if G.w_all == null:
		return
	_pan_open("sysp", "res://logic/ui_sys.gd", [G.w_all.WS]).open(t)

func dd_open(t := "") -> void:   # aA: Điểm danh (cột sự kiện)
	if G.w_all == null:
		return
	_pan_open("ddp", "res://logic/ui_dd.gd", [G.w_all.WEV]).open(t)

func nap_open() -> void:   # o9(0): Nạp đầu
	_pan_open("napp", "res://logic/ui_nap.gd", []).open()

func tt_open() -> void:   # XI: 7 ngày về làng
	if G.w_all == null:
		return
	_pan_open("ttp", "res://logic/ui_tt.gd", [G.w_all.WEV]).open()

func cho_open(k: int) -> void:   # (bản 517) Chợ nổi sông Vàm (khung Kho), k: ghe đang chọn
	if G.w_all == null:
		return
	_pan_open("chop", "res://logic/ui_cho.gd", []).open(k)

func ghe_open() -> void:   # (bản 515) Ghe thương hồ (khung Kho)
	if G.w_all == null:
		return
	_pan_open("ghp", "res://logic/ui_gh.gd", []).open()

func thu_open() -> void:   # gu("thu"): bảng đọc thư nhà
	if G.w_all == null:
		return
	_pan_open("thup", "res://logic/ui_thu.gd", [G.w_all.WTH]).open()

func sky_open() -> void:   # RN: chạm ô giờ / thời tiết -> Trời đất trong làng
	if G.w_all == null:
		return
	_pan_open("skyp", "res://logic/ui_sky.gd", []).open()

func clg_open(t := "") -> void:   # clgOpen: Sổ làng › Chuyện làng
	if G.w_all == null:
		return
	_pan_open("clgp", "res://logic/ui_clg.gd", [G.w_all.WL]).open(t)

func tn_open(t := "") -> void:   # tnOpen: Sổ làng › Thiên tai, hoạn nạn
	if G.w_all == null:
		return
	if tnp == null:
		tnp = load("res://logic/ui_tn.gd").new(self, G.w_all.WL, G.w_all.WD)
	close_all()
	kho_close()
	tnp.open(t)

func gp_open(u = null) -> void:   # gpOpen: Sổ làng › Gia phả
	if G.w_all == null:
		return
	if gpp == null:
		gpp = load("res://logic/ui_gp.gd").new(self, G.w_all.WL)
	close_all()
	kho_close()
	gpp.open(u)

func hr_open() -> void:   # ZD: Sổ làng › Làm thuê
	if G.w_all == null:
		return
	if hrp == null:
		hrp = load("res://logic/ui_hr.gd").new(self, G.w_all.WL)
	close_all()
	kho_close()
	hrp.open()

var open_at_down := false   # (bản 286) lúc ngón tay chạm xuống có bảng / vòng nào đang mở (bảng tự đóng khi chạm xuống,
                            # nên tới lúc nhấc tay -> farm.tap thì đã đóng rồi: phải nhớ từ lúc chạm xuống)
var gv_at_down := false
var _hold := false   # cú chạm này bắt đầu lúc đang mở bảng: làng không lướt / zoom tới khi nhấc hết ngón
var _fing := {}      # ngón tay (chuột: -1) đang chạm

func any_open() -> bool:   # (bản 283) đang mở bảng / vòng nút / khay nào trên làng
	if rm_on() or kho_on or od_on or pc_b != null:
		return true
	if (gv_b != null and gv_b.visible) or (lk_b != null and lk_b.visible) or (dkp != null and dkp.on):
		return true
	if xfp != null and xfp.k != "":
		return true
	if (spp != null and spp.pop != null) or (khp != null and khp.pop != null):
		return true
	for p in _pans() + [ngp, nvp, setp, lvp, pcp, vlp]:
		if p != null and "on" in p and p.on:
			return true
	if G != null and G.w_all != null and G.w_all.any_on():
		return true
	return false

func close_all() -> void:
	for p in _pans():
		if p != null and p.on:
			p.close()
	if ngp != null and ngp.on:
		ngp.close()
	if vlp != null:
		vlp.close()
	if pcp != null and pcp.on:
		pcp.close()
	if xfp != null:
		xfp.close()
	if nvp != null:
		nvp.close()
	if setp != null and setp.on:
		setp.close()
	pc_close()
	ord_close()
	gv_close()
	rm_close()
	lock_close()
	dock_open(false)
	if G != null and G.w_all != null:   # NTWEB bảng cây, hạn mặn, chợ nổi, radio, lễ hội
		G.w_all.close_all()

func item_ic(id: String, px: float) -> Texture2D:
	# hình món của bản web (Ai, ui/svg/kh, khung 64), vẽ ra đúng số px màn hình cần (làm tròn lên 2^n): luôn nét
	var n := int(pow(2.0, ceil(log(maxf(16.0, px)) / log(2.0))))
	n = maxi(n, mini(n * 2, 128))   # (bản 566) gấp 2 điểm màn (tới 128px nướng sẵn) rồi thu nhỏ: nét như ảnh gốc, không nhòe
	var key := "kh/" + id + "_" + str(n)
	if _icons.has(key):
		return _icons[key]
	if n <= 128:   # (bản 497) ảnh nướng sẵn 64 / 128px (src/tools/bake_kh.py): giải nhanh hơn ảnh 512 bọc trong svg ~10 lần
		var bz := 64 if n <= 64 else 128
		var raw := FileAccess.get_file_as_bytes("res://ui/img/kh/" + id + ("_64" if bz == 64 else "") + ".webp")
		if raw.size():
			var im := Image.new()
			if im.load_webp_from_buffer(raw) == OK:
				if n < bz:
					im.convert(Image.FORMAT_RGBA8)
					im.premultiply_alpha()
					im.resize(n, n, Image.INTERPOLATE_LANCZOS)
					Css._unpremul(im)
				_icons[key] = ImageTexture.create_from_image(im)
				return _icons[key]
	var svg := FileAccess.get_file_as_string("res://ui/svg/kh/" + id + ".svg")
	var img := Image.new()
	if svg == "" or Css.svg_load(img, svg, n / 64.0) != OK:
		_icons[key] = null
		return null
	_icons[key] = ImageTexture.create_from_image(img)
	return _icons[key]

var _icons := {}
func icon(id: String, px: float) -> Texture2D:
	# icon vector của gói thiết kế (icons/<id>.svg), vẽ ra đúng số px màn hình cần (làm tròn lên 2^n): luôn nét
	var n := int(pow(2.0, ceil(log(maxf(16.0, px)) / log(2.0))))
	var key := id + "_" + str(n)
	if _icons.has(key):
		return _icons[key]
	var svg := FileAccess.get_file_as_string("res://icons/" + id + ".svg")
	var img := Image.new()
	if svg == "" or Css.svg_load(img, svg, n / 64.0) != OK:
		return null
	_icons[key] = ImageTexture.create_from_image(img)
	return _icons[key]

# ------------------------------------------------------------------ frame
func _process(dt: float) -> void:
	if root == null:
		return
	if vsize() != _vs:
		var vs := get_viewport().get_visible_rect().size / dpr_v
		var k2 := Khuon.tinh(vs.x, vs.y)
		if (absf(_calc_u(vs, k2) - U) > 0.001 or absf(minf(0.66 * vs.x, 320.0) * Khuon.S_SNAP - goal_built) > 0.5) and has_meta("rebuild"):
			# khác độ to: dựng lại cả giao diện theo s mới (như web đổi --ks)
			_vs = vsize()
			(get_meta("rebuild") as Callable).call_deferred()
			return
		kh = k2
		_layout()
	_cam_step(dt)
	if nvp != null:
		nvp.step(dt)
	if lvp != null:
		lvp.step(dt)
	if setp != null:
		setp.step(dt)
	if vlp != null and not vlp.busy():
		vlp.step(dt)
	if ngp != null and not ngp.busy():
		ngp.step(dt)
	for p in _pans():
		if p != null and not p.busy():
			p.step(dt)
	_auto_sync()
	if xfp != null:
		xfp.step(dt)
	if bdp != null:
		bdp.step(dt)
	if khp != null:
		khp.step()
	if spp != null:
		spp.step()
	if cgp != null:
		cgp.step(dt)
	if oqp != null:
		oqp.step(dt)
	if xtp != null:
		xtp.step(dt)
	if carop != null:
		carop.step(dt)
	_t -= dt
	if _t <= 0.0:
		_t = 0.25
		_clock()
		_sync_hud()
		if gv_i >= 0:
			var a: Dictionary = G.p(gv_i)
			if not a.u or a.c != null:
				gv_close()
			else:
				_gv_sync()
		if rm_on():
			_rm_sync()
		if lk_i >= 0:
			if G.p(lk_i).u:
				lock_close()
			else:
				_lock_sync()
		if bfp != null:
			bfp.sync()
		_hm_badge()
		if G.w_all != null:   # NTWEB bảng cây, chợ nổi, lễ hội, nút viên
			G.w_all.ui_tick()
	if pc_id != "":
		_pc_sync()
	if gv_i >= 0:
		_gv_pos()
	if rm_on():
		_rm_pos()
	if lk_i >= 0:
		_lock_pos()
	var want := 1.0 if rm_on() or (xfp != null and xfp.is_open()) else 0.0
	dim_a = move_toward(dim_a, want, dt / 0.2)
	dim.visible = dim_a > 0.001
	if dim.visible:
		dim.size = get_viewport().get_visible_rect().size
		dim_mat.set_shader_parameter("a", dim_a)
		dim.queue_redraw()
	if tip_b != null:
		_tip_t -= dt
		if is_instance_valid(tip_b):
			tip_b.modulate.a = clampf(_tip_t / 0.25, 0.0, 1.0)
		if _tip_t <= 0.0:
			tip_close()

func _input(e: InputEvent) -> void:
	# bảng che cả màn đang mở (Cài đặt, Kho, Nhiệm vụ, Lên cấp, cửa hàng Xây dựng): bản đồ không được lướt/zoom theo ngón tay (như web: .pbk chặn).
	# main.gd đọc cờ này trong _unhandled_input; không chặn sự kiện ở đây để main vẫn đếm đủ ngón tay.
	# (bản 289) một luật: đang mở bất cứ bảng / popup / vòng nút nào (any_open) thì làng đứng yên; chạm xuống lúc đang mở
	# thì giữ đứng yên tới khi nhấc hết ngón (bảng tự đóng khi chạm ra ngoài, kéo tiếp cũng không lướt làng)
	if e is InputEventScreenTouch or (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT):
		if e.pressed:
			last_tap = e.position
			if tip_b != null:   # chạm chỗ khác: tắt bong bóng
				tip_close()
			_fing[e.index if e is InputEventScreenTouch else -1] = true
			open_at_down = any_open()
			gv_at_down = gv_b != null and gv_b.visible
			if open_at_down:
				_hold = true
		else:
			_fing.erase(e.index if e is InputEventScreenTouch else -1)
	get_tree().set_meta("ui_modal", _hold or any_open() or (bdp != null and bdp.mode == "shop"))
	if _fing.is_empty():
		_hold = false
	gv_sc.input(e)
	for v in _scs:
		if v.area != null and is_instance_valid(v.area):
			v.input(e)
	if gv_sc.grabbing(e):
		get_tree().set_meta("ui_modal", true)   # kéo khay giống: làng đứng yên (main đọc cờ trong _unhandled_input)
	if nvp != null:
		nvp.input(e)
	# dd: chạm ra ngoài hộp hỏi "Tốn ... sen đỏ" thì đóng (pointerdown bắt trước, không chặn)
	if xfp != null and xfp.ask != null and is_instance_valid(xfp.ask) and _is_tap_down(e):
		var pp: Vector2 = e.position
		if not xfp.ask.get_global_rect().has_point(pp):
			xfp._ask_close()
	if lvp != null:
		lvp.input(e)
	if setp != null:
		setp.input(e)
	if vlp != null:
		vlp.input(e)
	if ngp != null:
		ngp.input(e)
	for p in _pans():
		if p != null:
			p.input(e)
	if xfp != null:
		xfp.input(e)
