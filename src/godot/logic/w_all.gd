extends RefCounted
# NTWEB: bộ ráp các mô-đun dịch 1:1 từ bản web (w_*.gd). Tạo mọi mô-đun luật theo thứ tự an toàn, gán tham chiếu chéo
# (WR, WC, WK, WS, WL, WH, WX, ...) và các ext Callable mà một mô-đun khác đã có. Không thêm luật mới ở đây:
# chỉ nối dây theo port/hooks.txt. Bước luật:
#   step(t, offline)  gọi trong lượt 0,25 s của game.gd (sau _grow) và trong vòng bù offline (catch_up)
#   frame(dt)         gọi mỗi khung trong game._process (các bước ui({step}) / wK của web, không chạy khi bù offline)
# Hệ cần G.lang (farm.gd gán sau): khi chưa có lang thì bước offline được dồn lại (pend) và chạy khi lang có.

const Css = preload("res://ui/css.gd")

var G
var WR    # w_ruong.gd  ruộng mặn, cây ăn trái, mưa rào, giống lai
var WK    # w_kho.gd    giá có lý do, tin chợ
var WC    # w_cho.gd    chợ nổi, radio, g.mult
var WX    # w_xuong.gd  xưởng, đơn, bãi bùn
var WS    # w_sys.gd    Hệ Thống, mục tiêu, du hành
var WL    # w_lang.gd   dân làng, nghề, cưới, chuyện làng
var WH    # w_htx.gd    hợp tác xã, hụi, lễ hội, nhịp Hay Day
var WCA   # w_ca.gd     câu cá, thú nuôi thêm, lờ lọp, diều
var WD    # w_duong.gd  chuồng, thiên tai, trò chơi nhỏ

var U = null    # ui.gd (ui_setup)
var TIP = null  # w_tip.gd
var WRU = null  # w_ruong_ui.gd
var WKU = null  # w_kho_ui.gd
var WCU = null  # w_cho_ui.gd
var WSU = null  # w_sys_ui.gd
var WHU = null  # w_htx_ui.gd
var WCAU = null # w_ca_ui.gd
const PILL = preload("res://logic/pill.gd")
var pills: VBoxContainer = null   # hàng nút viên HUD (Hs())

var pend := 0.0   # giây bù offline chưa chạy vì G.lang chưa có

func _init(game) -> void:
	G = game
	# 1. tạo (không _init nào đọc G.lang hay mô-đun khác)
	WR = load("res://logic/w_ruong.gd").new(G)
	WK = load("res://logic/w_kho.gd").new(G)
	WC = load("res://logic/w_cho.gd").new(G)
	WX = load("res://logic/w_xuong.gd").new(G)
	WS = load("res://logic/w_sys.gd").new(G)
	WL = load("res://logic/w_lang.gd").new(G)
	WH = load("res://logic/w_htx.gd").new(G)
	WCA = load("res://logic/w_ca.gd").new(G)
	WD = load("res://logic/w_duong.gd").new(G)
	# 2. tham chiếu chéo
	WC.WR = WR
	WC.CA = WCA            # dedupe: w_cho._Cc -> w_ca.cc (g.pet)
	WS.WR = WR
	WS.WC = WC
	WS.WK = WK
	WL.WR = WR
	WL.WC = WC
	WL.WS = WS             # dedupe: w_lang.htv -> w_sys.htv
	WL.WD = WD             # rT: việc vườn / chuồng còn làm được
	WD.ext["ac_del"] = func(u) -> void: WL.ac.erase(WL._ks(u))   # tnHit: nhà gặp nạn thì người đang đi làm về
	WH.WL = WL
	WL.WH = WH
	WH.WC = WC
	WH.WS = WS
	WH.WX = WX
	WCA.WR = WR
	WCA.WC = WC
	WCA.WS = WS
	WCA.WK = WK
	WD.WR = WR
	WD.WL = WL
	WD.WC = WC
	WD.WH = WH
	# 3. ext mà mô-đun khác đáp được (không cần giao diện)
	var jb := Callable(WH, "jb")
	WC.ext["o6"] = Callable(WCA, "o6")
	WC.ext["e6"] = Callable(WCA, "e6")
	WC.ext["VR"] = Callable(WD, "VR")
	WC.ext["Jb"] = jb
	WK.ext["Jb"] = jb
	WL.ext["Jb"] = jb
	WL.ext["y6"] = Callable(WH, "y6")
	WL.ext["Pm"] = Callable(WH, "pm")
	WL.ext["vk"] = Callable(WH, "vk")
	WL.ext["R6"] = Callable(WH, "r6")
	WL.ext["Bf"] = Callable(G, "bf")
	WH.ext["z6"] = Callable(WD, "d4")
	WX.ext["qs"] = Callable(WR, "qs")
	WX.ext["O0"] = Callable(WR, "o0")
	WCA.ext["No"] = Callable(self, "No")
	WS.ext["No"] = Callable(self, "No")
	WS.ext["utS_c"] = func() -> int: return int(WL.ut_s().get("c", 0))
	# Cài đặt Ngày / Mùa: web ghi luôn g.dm / g.sea (oJ của w_ruong đồng bộ cfg theo bản lưu mỗi giây)
	G.cfg_changed.connect(_on_cfg)

func _on_cfg(k: String) -> void:
	if not (G.g is Dictionary) or G.g.is_empty():
		return
	if k == "d":
		G.g.dm = G.cfg.d
		G.mark()
	elif k == "s":
		G.g.sea = str(G.cfg.s)
		G.mark()

# ------------------------------------------------------------------ bản lưu
func on_load() -> void:   # sau load_game/_migrate, reset_game/_fresh, bản mạng
	var g: Dictionary = G.g
	WC.mult_init()          # W3: g.mult mọi món = 1, g.mt = 45
	WS.sys()                # LX: g.sys đủ khóa
	WS._up()
	if not g.has("goal"):
		g.goal = 0
	WS.gJ()
	WS.TF = not bool(g.get("pc", {}).get("made", false))
	g.fish = WCA.jf(g.get("fish"))   # JF
	if not (g.get("rain") is float or g.get("rain") is int):
		g.rain = 150

# ------------------------------------------------------------------ bước luật
func _ok() -> bool:
	return G.lang != null and G.g is Dictionary and not G.g.is_empty()

func step(t: float, offline: bool) -> void:
	if not _ok():
		if offline:
			pend += t
		return
	if pend > 0.0:
		var p := pend
		pend = 0.0
		_offline_all(p)
	if offline:
		_offline(t)
		return
	# vw đuôi (sau _grow): fq, TD, mưa rào; Rq (làm thuê); bước 5 s 'mk'
	WR.step(t, false)
	WL.rq(t, false)
	WK.step(t, false)

func _offline(e: float) -> void:   # vw(e, true): phần chạy cả lúc tắt game
	WR.step(e, true)
	WL.rq(e, true)
	WC.step(e, true)     # chỉ g.mt trôi giá
	WCA.step(e, true)    # chỉ dN
	WK.step(e, true)     # sang ngày: ghi giá, tin chợ

func _offline_all(off: float) -> void:   # chia nhỏ như catch_up
	var stp := maxf(15.0, off / 2400.0)
	var a := off
	while a > 0.0:
		var e := minf(stp, a)
		_offline(e)
		a -= e

func frame(dt: float) -> void:   # mỗi khung, chỉ lúc đang mở game
	if not _ok():
		return
	WR.frame(dt)
	WX.step(dt, false)
	WC.step(dt, false)
	WS.step(dt, false)
	WL.step(dt, false)
	WH.step(dt, false)
	WCA.step(dt, false)
	WD.step(dt, false)

# ------------------------------------------------------------------ móc vào luật game.gd
func boost_add() -> float:   # tw: jH() + (gB() - 1) + (Dx() > 1 ? .04 : 0)
	return WS.jH() + WS.htv("n_cay") + (0.04 if WH.dx() > 1.0 else 0.0)

func um_add() -> float:   # vw: um() > 1 ? .04 : 0
	return 0.04 if _ok() and WR.um() > 1.0 else 0.0

func t_o(e: int) -> float:   # vw: * tO(e)
	return WR.t_o(e) if _ok() else 1.0

func is_hyb(seed: String) -> bool:
	return WR.ol.has(seed)

func qi(a: String) -> void:   # lớp bọc qi: thi đua tuần của xã (m9) theo cI().k
	if not (G.g.get("hx") is Dictionary):
		return
	var k: String = ["harvest", "xuong", "nuoi", "don"][posmod(WH.i2(), 4)]   # cI() = WJ[I2() % 4]
	if (a == "harvest" and k == "harvest") or (a == "collect" and k == "nuoi"):
		WH.m9(1)
	elif a == "deliver" and k == "don":
		WH.m9(3)
	elif k == "xuong" and WC.Ge.has(a):
		WH.m9(1)

func No(k: String, a = 1.0, pos = null) -> void:   # No: vật liệu rơi (Lu = nang_cap/roi_vat_lieu)
	var e = G.D.drop.get(k)
	if not (e is Array):
		return
	var m := float(a) if (a is float or a is int) and float(a) != 0.0 else 1.0
	var r := []
	for c in e:
		if randf() < float(c[1]) * m:
			G.mat_add(String(c[0]), 1)
			r.append(G.item_name(String(c[0])))
	if not r.is_empty():
		var p: Vector2 = _v2(pos) if pos != null else G.ppos
		G.float_text.emit(p.x, p.y - 0.3, "+1 " + ", +1 ".join(r))

static func _v2(p) -> Vector2:
	if p is Vector2:
		return p
	if p is Array and p.size() >= 2:
		return Vector2(float(p[0]), float(p[1]))
	if p is Dictionary:
		return Vector2(float(p.get("x", p.get("gx", 0.0))), float(p.get("y", p.get("gy", 0.0))))
	return Vector2.INF

# ------------------------------------------------------------------ giao diện (ui.gd gọi sau khi dựng xong)
func ui_setup(ui) -> void:
	U = ui
	var F = U.F
	WRU = load("res://logic/w_ruong_ui.gd").new(U, WR)
	WKU = load("res://logic/w_kho_ui.gd").new(U, WK)
	WCU = load("res://logic/w_cho_ui.gd").new(U, WC)
	WSU = load("res://logic/w_sys_ui.gd").new(U, WS)
	WHU = load("res://logic/w_htx_ui.gd").new(U, WH)
	WCAU = load("res://logic/w_ca_ui.gd").new(U, WCA)
	TIP = load("res://logic/w_tip.gd").new(G, U)   # NTWEB sH/fp: chữ khi trỏ chuột lên bản đồ
	TIP.name = "WebTip"
	U.add_child(TIP)
	# hàng nút viên HUD (Hs()): dưới cụm trên bên trái
	pills = VBoxContainer.new()
	pills.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pills.position = Vector2(21.0, 325.44) * Css.K   # .xpills: dưới thẻ mục tiêu bên trái
	pills.add_theme_constant_override("separation", int(round(4.5 * Css.K)))
	U.root.add_child(pills)
	# Mt.mode / qc / bận
	var mt := func() -> String: return String(U.bdp.mode) if U.bdp != null else "off"
	for m in [WC, WL, WH]:
		m.ext["Mt_mode"] = mt
	WX.ext["bdMode"] = mt
	var qc := func() -> String: return ""   # bản Godot chưa có màn bản đồ
	WC.ext["qc"] = qc
	WH.ext["qc"] = qc
	WCU.ext["qc"] = qc
	WS.ext["busy"] = func() -> bool:
		return mt.call() != "off" or (U.pcp != null and U.pcp.on) or U.kho_on or (U.nvp != null and U.nvp.on) or (U.setp != null and U.setp.on) or U.od_on
	# việc nhân vật (aa.q của farm.gd)
	if F != null:
		WX.ext["u2"] = Callable(F, "seeds_queued")
		WRU.job = func(idx: int, kind: String) -> void:
			var p = WR.ax_pos(idx)
			if p == null:
				WR.tree_run(idx, kind)
				return
			_job("tree" + str(idx) + kind, p, 0.35, func() -> bool: return WR.tree_run(idx, kind))
		WCA.ext["Gl"] = func(j: Dictionary) -> void:
			_job(String(j.get("key", "")), j.get("pos"), float(j.get("dur", 0.35)), j.get("run", Callable()))
		WCAU.ext["Ns"] = func(o: Dictionary) -> void:   # {type: "lo", key}
			var key := String(o.get("key", ""))
			var p = WCA.lo_stand(key)
			if p != null:
				_job("lov" + key, p, 0.35, func() -> bool: return WCA.rk(key))
		WCU.ext["Ns"] = func(o: Dictionary) -> void:   # {type: "cho", k}
			var k := int(o.get("k", 1))
			var p = WC.vQ(k)
			if p != null:
				_job("cho" + str(k), p, 0.05, func() -> bool:
					WCU.open_cho(k)
					return false)
	# bảng nhân vật
	var ec := func() -> void:
		if U.pcp != null and U.pcp.on:
			U.pcp.sig = ""
	var g2 := func() -> void:
		if U.pcp != null and U.pcp.on:
			U.pcp.close()
	WCA.ext["ec"] = ec
	WCA.ext["klShow"] = func() -> void: U.kl_show()   # thẻ trái khủng
	WCA.ext["g2"] = g2
	WCAU.ext["ec"] = ec
	WCAU.ext["g2"] = g2
	WCA.ext["L1"] = func(o: Dictionary) -> void:
		U._lack_open(o.get("items", []), String(o.get("why", "")), o.get("go", Callable()), int(o.get("xu", 0)), o.get("mats", []))
	WHU.ext["Ai"] = func(id: String) -> Texture2D: return U.item_ic(id, 64.0)
	WSU.ext["Ai"] = WHU.ext["Ai"]
	# #goal trên HUD: chạm khi đủ thì nhận thưởng (#goalGo)
	var gb = U.hid.get("#goal")
	if gb != null:
		U._click(gb, func():
			var v: Dictionary = WS.goal_view()
			if v.get("ready", false):
				WS.goal_claim()
				U._sync_hud())

func _job(key: String, pos, dur: float, run) -> void:   # Gl / Ns / Px: xếp việc đi tới pos rồi chạy run
	var F = U.F if U != null else null
	var p := _v2(pos)
	if F == null or p == Vector2.INF or not (run is Callable):
		if run is Callable and (run as Callable).is_valid():
			run.call()
		return
	F.ext_job(key, p, dur, run)

func ui_tick() -> void:   # ui.gd mỗi 0,25 s
	if WRU == null or not _ok():
		return
	var gb = U.hid.get("#goal") if U.hid is Dictionary else null   # .xpills nằm ngay dưới thẻ mục tiêu
	if gb != null and pills != null:
		var gr: Rect2 = gb.get_global_rect()
		pills.position = Vector2(gr.position.x, (gr.end.y if gb.is_visible_in_tree() else gr.position.y) + 4.5 * Css.K)
	WRU.cz()
	if WRU.pill != null and WRU.pill.get_parent() != pills:
		WRU.pill.reparent(pills, false)
	WCU.sync_cho()
	WCU.pill_sync(pills)
	WHU.sync_fest()
	WHU.pill_sync(pills)
	_ray_pill()
	_tn_pill()
	_hdn_pill()

var pl := {}   # nút viên theo khóa: tn (TNPILL), hdn (HDNPILL)
func _pill_put(k: String, tx, cb: Callable) -> void:   # tx: [chữ, gấp?] hoặc rỗng = ẩn (ẩn cả lúc đang xây)
	var show: bool = tx is Array and not tx.is_empty() and (U.bdp == null or String(U.bdp.mode) == "off")
	var p = pl.get(k)
	if not show:
		if p != null:
			p.visible = false
		return
	if p == null:
		p = PILL.new(U)
		p.pressed.connect(cb)
		pills.add_child(p)
		pl[k] = p
	p.visible = true
	p.text = String(tx[0])
	p.hurry = bool(tx[1])

func _tn_pill() -> void:   # tnPill: "Đêm nay bão lớn về · phòng chống" / "N nhà gặp nạn · giúp bà con"
	_pill_put("tn", WD.tn_pill_txt(), func() -> void: U.tn_open("phong" if WL.tn_on(WL._vr() + 1) != null else "nan"))

func _hdn_pill() -> void:   # hdnPill: "Hội đình còn N ngày · chuẩn bị" / "Hôm nay hội đình · vào thi"
	_pill_put("hdn", WH.hdn_pill_txt(), func() -> void: U.hdn_open("giai" if WH.hdn_today() else "mo"))

var rpill: Control = null   # Lg: nút viên "Rầy nâu: N ô · phun thuốc"
func _ray_pill() -> void:   # l_
	var t: int = G.ray_n()
	if t == 0:
		if rpill != null:
			rpill.visible = false
		return
	if rpill == null:
		rpill = PILL.new(U)
		rpill.pressed.connect(func() -> void:   # tới ô rầy đầu tiên rồi đi phun
			var k = G.g.ray.p.keys()
			if k.is_empty():
				return
			var i := int(k[0])
			var c: Dictionary = G.cells[i]
			var M = U.main
			M.cam = Vector2(U.F.en(c.gx + 0.5, c.gy + 0.5), U.F.nn(c.gx + 0.5, c.gy + 0.5)) - U.get_viewport().get_visible_rect().size / M.zoom * 0.5
			if M.has_method("_clamp_cam"):
				M._clamp_cam()
			U.close_all()
			U.F.queue_job(i, "spray"))
		rpill.hurry = true   # .hurry
		pills.add_child(rpill)
	rpill.visible = true
	var tx := "Rầy nâu: " + str(t) + " ô · phun thuốc"
	if rpill.text != tx:
		rpill.text = tx

func close_all() -> void:   # ui.close_all
	if WRU == null:
		return
	WRU.close_man()
	WCU.close_cho()
	WCU.close_rd()
	WHU.close_fest()
