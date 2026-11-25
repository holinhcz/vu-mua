extends Node
# Gắn phần logic vào làng Godot mà không sửa main.gd của làng: chờ làng tải info.json xong,
# rồi thêm ruộng + nhân vật (farm.gd) vào làng và bảng (ui.gd) lên trên.

const GameS := preload("res://logic/game.gd")
const PicsS := preload("res://logic/pics.gd")
const FarmS := preload("res://logic/farm.gd")
const UiS := preload("res://logic/ui.gd")

var G: Node
var P: Node
var farm: Node2D
var ui: CanvasLayer
var _done := false

func _lord() -> void:
	var S: Array = G.w_all.WCA.t1()["set"]
	for e9 in S:
		e9.at = float(e9.at) - 1e8
	push_error("QKSET " + JSON.stringify(S))
	if S.size():
		var m9 = ui.main
		m9.cam = Vector2(farm.en(float(S[0].gx) + .5, float(S[0].gy) + .5), farm.nn(float(S[0].gx) + .5, float(S[0].gy) + .5)) - m9.get_viewport_rect().size / m9.zoom / 2

func _loauto() -> void:
	var W = G.w_all.WCA
	var best := Vector2i(-999, -999)
	var bd := 1e9
	for x in range(int(G.ppos.x) - 25, int(G.ppos.x) + 25):
		for y in range(int(G.ppos.y) - 25, int(G.ppos.y) + 25):
			if W._p0(x, y) and W._ci(W._fo(x, y)) and (W.yf == null or String(W.yf.get("lo", "")) == "" or W.lo_why(String(W.yf.lo), x, y) == ""):
				var d := Vector2(x - G.ppos.x, y - G.ppos.y).length()
				if d < bd:
					bd = d
					best = Vector2i(x, y)
	push_error("QKLO " + str(best))
	if best.x > -999:
		W.nk(best.x, best.y)

func _cct(a: Array) -> void:
	var gm = ui.ccp.game
	if gm == null:
		return
	var CDx = preload("res://logic/cc/cc_data.gd")
	var f: Dictionary = CDx.fish(String(a[1]))
	var w := float(a[2])
	gm.ui.show_catch({"f": f, "w": w, "cm": 20, "isNew": false, "rec": false, "xp": 5, "val": CDx.fish_value(f, w)})

func _ready() -> void:
	G = GameS.new()
	G.name = "Game"
	add_child(G)
	P = PicsS.new()
	P.name = "Pics"
	add_child(P)
	var tag := BuildTag.new()   # NTBUILD: số bản trên đồng hồ = số bản thật lần đẩy này (logic/build.txt do bước build ghi)
	tag.name = "BuildTag"
	tag.process_priority = 100000
	add_child(tag)

class BuildTag extends Node:
	var lb := ""
	func _ready() -> void:
		var f := FileAccess.open("res://logic/build.txt", FileAccess.READ)
		if f:
			lb = f.get_as_text().strip_edges()
	var re := RegEx.create_from_string("^bản \\S+ ")
	func _process(_dt: float) -> void:
		if lb == "":
			return
		var m = get_tree().current_scene
		if m == null or not ("meter" in m) or m.meter == null:
			return
		var s: String = m.meter.text
		var r := re.search(s)
		if r != null and r.get_string() != "bản " + lb + " ":
			m.meter.text = "bản " + lb + " " + s.substr(r.get_end())

var _hook_t := 0.0
var _quiet_n := 0
func _process(dt: float) -> void:
	if _done:
		_hook_t -= dt
		if _hook_t <= 0.0:
			_hook_t = 0.5
			_quiet_n += 1
			_quiet_village(get_tree().current_scene)
			if OS.has_feature("web"):
				_test_hook()
		return
	var m = get_tree().current_scene
	if m == null or not ("info" in m) or m.info.is_empty() or m.objs.is_empty() or m.obj_root == null:
		return
	_done = true
	P.setup(m.base_url)
	ui = UiS.new()
	farm = FarmS.new()
	farm.name = "Farm"
	m.add_child(farm)
	m.add_child(ui)
	ui.setup(G, P, farm, m.dpr)
	ui.set_meta("rebuild", _rebuild_ui)
	farm.setup(G, P, m, ui)
	ui.web_start_cam()
	G.cloud_loaded.connect(_cloud_loaded)
	_quiet_village(m)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.__ntlogic=1")

func _quiet_village(m: Node) -> void:
	# bản chính: giữ nguyên dòng đo + nút thử của làng, chỉ dời xuống dưới thanh trên (HUD) cho khỏi che nhau
	var Y := {"meter": 64, "song_btn": 128, "flood_btn": 160, "night_btn": 192}
	for k in Y:
		var c = m.get(k)
		if c is Control:
			c.position = Vector2(8, Y[k]) * m.dpr
	# HUD hiện khi làng đã nét (che tải xong), như bản web không có HUD đè màn tải
	if "first_ready" in m:
		ui.visible = bool(m.first_ready) and not bool(m.get("tc_on"))   # toàn cảnh (bản 244): ẩn hết nút

func _test_hook() -> void:
	# cho bản thử tự động: tâm từng ô ruộng trên màn hình (css px) + bảng nào đang mở
	var L := []
	for i in G.B0:
		var p: Vector2 = ui.plot_css(i)
		L.append([round(p.x), round(p.y), int(G.owned(i)), int(G.p(i).u), str(G.p(i).c)])
	var st := {"p": L, "gv": ui.gv_i, "rm": ui.rm_i, "lk": ui.lk_i, "kho": ui.kho_on, "q": farm.q.size(), "coins": G.g.coins}
	JavaScriptBridge.eval("window.__nt=" + JSON.stringify(st))
	var cmd := str(JavaScriptBridge.eval("(function(){var c=window.__ntcmd||'';window.__ntcmd='';return c})()"))
	for c in cmd.split(";", false):
		var a := c.split(":")
		match a[0]:
			"tap": ui.tap_plot(int(a[1]))
			"close": ui.close_all(); ui.kho_close()
			"kho": ui.kho_open()
			"ord": ui.ord_open()
			"dock": ui.dock_open(true)
			"ordset": G.g.orders = JSON.parse_string(str(JavaScriptBridge.eval("JSON.stringify(window.__ntord)"))); G.mark()
			"barn": G.g.barn[a[1]] = int(a[2]); G.mark()
			"ngoc": G.g.ngoc = int(a[1]); G.mark()
			"khost": G.g.khost = int(a[1]); G.g.khoB = 0; G.mark()
			"mat": G.g.mats = {}; for q in a.slice(1): G.g.mats[q.split("=")[0]] = int(q.split("=")[1])
			"kup": ui.khp.open()
			"vnset":   # vnset:loại:p,t,s;p,t,s... (p -1 = đói, s 1 = bệnh): xây chuồng + thả con
				G.g.penb[a[1]] = 1
				var PL := []
				for q in a[2].split("/"):
					var f := q.split(",")
					PL.append({"p": float(f[0]), "t": float(f[1]), "s": int(f[2]) if f.size() > 2 else 0})
				G.g.pens[a[1]] = PL
				G.mark()
				farm.lang.changed()
			"vninfo":
				var I := {"an": farm.anodes.keys(), "open": ui.rm_v, "st": ui.rv._st, "g": ui.rm_g.visible, "r": ui.rm_r.visible, "coins": G.g.coins, "barn": G.g.barn, "pens": G.g.pens.ga, "penst": G.g.get("penst", {})}
				I["zoom"] = ui.main.zoom
				I["K"] = ui.Css.K
				for k in farm.anodes:
					var q: Vector2 = (farm.anodes[k].foot() - ui.main.cam) * ui.main.zoom / ui.Css.K
					I["s" + k] = [round(q.x), round(q.y)]
				for t in G.vn.DI:
					var pp: Vector2i = farm.lang.pen_pos(t)
					I[t] = [farm.lang.pen_built(t), G.vn.ok(t), farm.lang.fo(pp.x, pp.y), G.vn.list(t).size()]
				JavaScriptBridge.eval("window.__ntvn=" + JSON.stringify(I))
			"vntap":   # vntap:loại:j: chạm bong bóng con vật như người chơi
				var nd = farm.anodes.get(a[1] + ":" + a[2])
				if nd != null:
					farm.tap(farm.world_to_screen(nd.bub_at()))
			"vnbtn":   # vnbtn:k: bấm nút k của vòng nút con vật / chuồng (fast, star, water, harvest, chip)
				ui._rm_do(a[1])
			"vnopen": ui.vn_open({"t": a[1], "j": int(a[2])}, farm.anodes[a[1] + ":0"].foot() if farm.anodes.has(a[1] + ":0") else Vector2.ZERO)
			"cam":   # cam:gx:gy: đưa camera tới ô
				ui.main.zoom = 2.0 * ui.Css.K
				ui.main.cam = Vector2(farm.en(float(a[1]), float(a[2])), farm.nn(float(a[1]), float(a[2]))) - ui.get_viewport().get_visible_rect().size / ui.main.zoom * 0.5
				if ui.main.has_method("_clamp_cam"):
					ui.main._clamp_cam()
			"khotap":
				for o in farm.lang.objs():
					if o.id == "kho" or o.id == "kho2":
						var t = farm.lang.Pi.get(o.id)
						var cx: float = float(o.gx) + float(t.fw) / 2.0
						var cy: float = float(o.gy) + float(t.fd) / 2.0
						farm.tap(farm.world_to_screen(Vector2(farm.en(cx, cy), farm.nn(cx, cy) - 60.0)))
						break
			"objs":
				var OL := []
				for o in farm.lang.objs():
					var t = farm.lang.Pi.get(o.id)
					if t == null:
						continue
					var cx: float = float(o.gx) + float(t.fw) / 2.0
					var cy: float = float(o.gy) + float(t.fd) / 2.0
					var q: Vector2 = (Vector2(farm.en(cx, cy), farm.nn(cx, cy)) - ui.main.cam) * ui.main.zoom / ui.Css.K
					OL.append([o.id, int(o.gx), int(o.gy), round(q.x), round(q.y)])
				var SL := []
				for o in farm.lang.SO:
					if o.wild or o.ring or not farm.lang.Pi.has(o.id) or not farm.lang.so_shown(o) or not farm.lang.ci(o.pc):
						continue
					var q2: Vector2 = (Vector2(o.sx, o.sy - 8.0) - ui.main.cam) * ui.main.zoom / ui.Css.K
					if q2.x > 20 and q2.x < 318 and q2.y > 120 and q2.y < 520:
						SL.append([o.id, round(q2.x), round(q2.y)])
				JavaScriptBridge.eval("window.__ntobjs=" + JSON.stringify({"so": SL.slice(0, 12), "o": OL, "mode": ui.bdp.mode, "sel": ui.bdp.sel, "mv": ui.bdp.move_idx, "coins": G.g.coins}))
			"lp":
				var wq: Vector2 = ui.main.cam + Vector2(float(a[1]), float(a[2])) * ui.Css.K / ui.main.zoom
				var V = farm.lang_ve
				JavaScriptBridge.eval("window.__ntlp=" + JSON.stringify([ui.bdp.mode, farm.lang.obj_at(wq, V.pick_obj), ui.bdp.open_at(wq), ui.bdp.mode]))
			"chips":
				var CL := []
				var ch = ui.bdp.pids.get(".khchips")
				if ch != null:
					for bt in ui._buttons(ch, []):
						var gr: Rect2 = bt.get_global_rect()
						CL.append([round(gr.position.x / ui.Css.K), round(gr.position.y / ui.Css.K), round(gr.size.x / ui.Css.K), round(gr.size.y / ui.Css.K), bt.mouse_filter, bt.is_visible_in_tree()])
				JavaScriptBridge.eval("window.__ntch=" + JSON.stringify({"c": CL, "cat": ui.bdp.cat, "mode": ui.bdp.mode}))
			"kupgo": ui.khp.up()
			"kclose": ui.khp.close(); ui.khp.kf_close(); ui.khp.ns_close()
			"kfull": G.g.kfpop = 0; G._kf_t = 0; G.kho_fit(1)
			"odsw": ui._od_swap(int(a[1]))
			"swap": G.swap(int(a[1]))
			"pc": ui.pc_open(a[1], Vector2(farm.en(farm.PC.G0[a[1]].sign[0] + 0.5, farm.PC.G0[a[1]].sign[1] + 0.5), farm.nn(farm.PC.G0[a[1]].sign[0] + 0.5, farm.PC.G0[a[1]].sign[1] + 0.5) - 48.0))
			"pcbuy": ui.pc_try(a[1])
			"coins": G.g.coins = int(a[1]); G.mark()
			"lv": G.g.pc.lv = int(a[1]); G.mark()
			"nosign": farm.sign_off = true; farm.refresh()
			"ud": ui.od_ud = {"i": int(a[1]), "t": G._now_ms() + 600000.0}
			"odgo": ui._od_deliver(int(a[1]))
			"odsen": ui._od_lack_btn(int(a[1]))
			"odget": ui._od_get(int(a[1]))
			"sel": ui.kh_sel = a[1]; ui.kh_q = 1; ui.kh_sig = ""; ui._kho_sync()
			"plant": G.plant(int(a[1]), a[2]); G.mark()
			"wet": G.p(int(a[1])).w = G.water_hold(G.p(int(a[1]))); G.mark()
			"ripe": G.p(int(a[1])).g = 999999.0; G.mark()
			"bug": G.p(int(a[1])).b = 1; G.mark()
			"sellall": ui._kho_sell_all()
			"nv": ui.nvp.open(a[1] if a.size() > 1 else "")
			"dd": ui.dd_open(a[1] if a.size() > 1 else "")
			"toast": G.toast.emit(":".join(a.slice(1)))   # thử câu báo
			"vl": var H: Array = G.w_all.WL.bl(); if H.size(): ui.vl_open(int(H[0].u))
			"xfo": G.g.work[String(a[1])] = {"b": 1, "q": [], "r": {}}; ui.xf_open(String(a[1]))   # thử: mở xưởng a[1] (xfo:bepcui)
			"xw2": for k in ["ruong", "mill"]: G.g.work[k] = {"b": 1, "q": [], "r": {}}   # test: có Ruộng muối, Cối xay
			"ng": ui.ng_open(a[1] if a.size() > 1 else "")
			"nglearn": G.w_all.WL.t6()[a[1]] = 1; G.mark()
			"vlbk": var H3: Array = G.w_all.WL.bl(); if H3.size(): G.w_all.WL._fam_of(int(H3[0].u)).bk = {"a": 1, "x": 1, "d": 1}
			"vlreq": var H2: Array = G.w_all.WL.bl(); if H2.size(): G.w_all.WL._fam_of(int(H2[0].u)).req = {"why": "đem ra chợ huyện", "xu": 998, "it": [["qua_dieu", 4], ["lua", 2]]}; G.w_all.WL._fam_of(int(H2[0].u)).dp = 145; G.w_all.WL._fam_of(int(H2[0].u)).tim = 1
			"nvday": G.nv.xI = int(floor(G.nv.d4() / 14.0)) * 14 + int(a[1]); ui.nvp.sig = ""
			"nvx": _nvx(int(a[1]))
			"ngsim": _ngsim(a)
			"tnsim": _tnsim(a)
			"tn": ui.tn_open(a[1] if a.size() > 1 else "")
			"ut": ui.ut_open(a[1] if a.size() > 1 else "")
			"hr": ui.hr_open()
			"gd": ui.gd_open(a[1] if a.size() > 1 else "")
			"dl": ui.dl_open()
			"thu": _thu(a)
			"thumi": var T8: Dictionary = G.w_all.WTH.Eg(); T8.d = -1; T8.un = null; T8.rq = null; G.w_all.WTH.mi.st = 0; G.mark()   # (bản 492) ông đưa thư tới lại (cần giờ 8:30–12)
			"thuyn": G.w_all.WTH.YN()
			"gptree": _gptree()
			"chox": G.troi.hh = 7.0; G.w_all.WC.Ui.al = 1.0; G.w_all.WCU.open_cho(int(a[1]) if a.size() > 1 else 0)   # (bản 517) thử bảng Chợ nổi: chox[:ghe]
			"kllua": G.w_all.WCA.klq.append({"id": "lua", "g": 8.1, "h": 1, "s": 33.1, "t": 0, "d": G.day(), "sea": 2, "day": 1, "wx": "mua", "st": 1, "who": "", "c": 45, "rec": false}); G.w_all.WCA.klq.append({"id": "bap", "g": 900.0, "h": 3, "s": 22.0, "br": 13.0, "t": 0, "d": G.day(), "sea": 0, "day": 3, "wx": "nang", "st": 2, "who": "", "c": 80, "rec": true}); ui.kl_show()   # (bản 526) thử thẻ trái khủng: bông lúa rồi trái bắp kỷ lục
			"mgx": {"caro": ui.carop, "cg": ui.cgp, "oq": ui.oqp, "tso": ui.tsop}[a[1]].open()   # (bản 533) thử mở mini game (tải gói hình riêng)
			"ccb": G.g.ccsv = {"basket": [{"id": "ro", "w": .3}, {"id": "loc", "w": 1.2}, {"id": "ho", "w": 30.0}]}; G.mark()   # (bản 539) thử: save cũ còn cá trong giỏ
			"cct": _cct(a)   # cct:<cá>:<cân> (bản 539) thử thẻ cá câu được
			"ccfull": G.g.barn["lua"] = int(G.g.barn.get("lua", 0)) + 200; G.mark()   # thử: Kho đầy
			"ccc": if ui.ccp.game != null: ui.ccp.game.caught(preload("res://logic/cc/cc_data.gd").fish(String(a[1])), float(a[2]))   # (bản 540) thử: câu được 1 con
			"ccd": push_error("QKDEX " + JSON.stringify(G.g.get("fish", {}).get("dex", {})) + " CC " + JSON.stringify(G.g.get("ccsv", {}).get("dex", {})))
			"ccdo": if ui.ccp.game != null: ui.ccp._pan(ui.ccp.game, "shop", "gear"); if a.size() > 1 and ui.ccpp != null: ui.ccpp.sel = String(a[1]); ui.ccpp._redo()   # thử: bảng Đồ nghề câu cá (ccdo:luoi chọn món)
			"ccmoi": if ui.ccp.game != null: ui.ccp._pan(ui.ccp.game, "shop", "bait"); if a.size() > 1 and ui.ccpp != null: ui.ccpp.sel = String(a[1]); ui.ccpp._redo()   # thử: bảng Mồi câu (ccmoi:oc)
			"ccq": if ui.ccp.game != null: ui.ccp.game.close_game()   # (bản 540) thử: thoát câu cá
			"lot": G.g.pc.lv = maxi(int(G.g.pc.lv), 20); G.g.coins = int(G.g.coins) + 3000; G.w_all.WCA.lo_place(a[1] if a.size() > 1 else "lo")   # (bản 541) thử: mua + bấm Đặt lờ
			"landall": for k9 in farm.PC.G0: G.g.land[k9] = 1   # thử: mở hết khu đất
			"choq": G.w_all.WC.dbg_cho = true   # thử: chợ nổi họp ngay
			"camc": var c9 = G.w_all.GHV.cho; push_error("QK cho " + str(c9.size()) + " " + str(c9.map(func(b): return [b.p, b.al, b.key, b.visible]))); if c9.size(): ui.main.cam = Vector2(farm.en(c9[1].p.x, c9[1].p.y), farm.nn(c9[1].p.x, c9[1].p.y)) - ui.main.get_viewport_rect().size / ui.main.zoom / 2   # thử: camera tới ghe chợ
			"zm": var m7 = ui.main; var c7 = m7.cam + m7.get_viewport_rect().size / m7.zoom / 2; m7.zoom = float(a[1]) * m7.dpr; m7.cam = c7 - m7.get_viewport_rect().size / m7.zoom / 2; push_error("QK zoom " + str(m7.zoom) + " dpr " + str(m7.dpr) + " zmax " + str(m7.zmax))   # thử: zoom (css) giữ tâm
			"camg": var B9 = G.w_all.GHV.cho + G.w_all.GHV.xus.map(func(x): return x.b) + ([G.w_all.GHV.ghe] if G.w_all.GHV.ghe != null else []); var b9 = null; for q9 in B9: if q9 != null and q9.visible: b9 = q9; if b9 != null: ui.main.cam = Vector2(farm.en(b9.p.x, b9.p.y), farm.nn(b9.p.x, b9.p.y)) - ui.main.get_viewport_rect().size / ui.main.zoom / 2   # thử: camera tới ghe
			"camt": var m8 = ui.main; m8.cam = Vector2(farm.en(float(a[1]), float(a[2])), farm.nn(float(a[1]), float(a[2]))) - m8.get_viewport_rect().size / m8.zoom / 2   # thử: camera tới ô
			"dbg2": push_error("QKD ids " + str(G.lang.objs().map(func(o): return String(o.id)).filter(func(x): return "kho" in x or "nha" in x)) + " meo " + str(farm.song._meo_pos()) + " has " + str(G.w_all.WCA.cc().meo) + " cg " + str(G.w_all.WCA.cg()) + " sea " + str(G.season()) + " wx " + G.troi.wx() + " h " + str(G.w_all.WCA._d0()) + " night " + str(G.night))
			"lopo": G.g.pc.lv = maxi(int(G.g.pc.lv), 20); G.g.coins = int(G.g.coins) + 9000; for m8 in ["tre", "may", "cuoc", "luoi", "phao"]: G.mat_add(m8, 12)
			"lopu": ui.lop_open()
			"wind": G.troi.hh = 15.0; G.w_all.WCA.dbg_wind = true   # thử: chiều có gió chướng
			"camm": var mp8 = farm.song._meo_pos(); if mp8 != null: ui.main.cam = Vector2(farm.en(mp8.x, mp8.y), farm.nn(mp8.x, mp8.y)) - ui.main.get_viewport_rect().size / ui.main.zoom / 2
			"dieuq": var d8: Dictionary = G.w_all.WCA.fh(); d8["has"]["sao"] = 1; d8.cur = "sao"; d8.on = 1   # thử: thả diều
			"meoq": G.g.pc.lv = maxi(int(G.g.pc.lv), 20); G.g.coins = int(G.g.coins) + 2000; G.w_all.WCA.vq("meo"); for f9 in ["ca_ro"]: G.g.barn[f9] = 3   # thử: xin mèo
			"vitq": G.g.pc.lv = maxi(int(G.g.pc.lv), 20); G.g.coins = int(G.g.coins) + 2000; G.g.barn["lua"] = int(G.g.barn.get("lua", 0)) + 20; G.w_all.WCA.vq("vit")   # thử: mua vịt (vào chọn chỗ)
			"loauto": _loauto()   # thử: tự tìm ô nước sát bờ gần nhất rồi chạm
			"lost": push_error("QKST " + JSON.stringify(G.w_all.WCA.t1()["set"]) + " pick " + JSON.stringify(farm.pick(farm.screen_to_world(Vector2(float(a[1]), float(a[2])) * ui.main.dpr))) if a.size() > 2 else "")
			"lord": _lord()   # thử: lờ có cá liền, camera tới lờ đầu tiên
			"ccx": ui.ccp.open()   # (bản 529) thử mở Câu cá (tải gói hình ghi thẳng ra file)
			"ghxa": _ghxa()
			"ghx": _ghet()   # thử bảng ghe (ghet trong hooks đã có: đặt bến)
			"paddyt": _paddyt(a)
			"ctdump": _ctdump()
			"hdnx": var WH9 = G.w_all.WH; if a[1] == "open": WH9.hdn_open_hoi()
			"hdng": var cu8 = G.w_all.WH.hdn_s().get("cur"); if cu8 is Dictionary: cu8.g = {"de": {"rd": 2, "st": "xong", "rank": 1}, "do": {"rd": 0, "st": "xong", "rank": 0}}; G.mark()   # thử: đá dế nhất, đố vui trượt
			"hdnend": var cu7 = G.w_all.WH.hdn_s().get("cur"); if cu7 is Dictionary: G.w_all.WH._hdn_end0(cu7); G.mark()   # thử: hội xong, ghi sổ
			"hdnt": var cu9 = G.w_all.WH.hdn_s().get("cur"); if cu9 is Dictionary: cu9.d = G.w_all.WH._vr(); G.w_all.WH.hdn_start(cu9); G.mark()   # thử: hội diễn ra hôm nay
			"hdn": ui.hdn_open(a[1] if a.size() > 1 else "")   # (bản 501) thử Hội đình: hdn[:tab]
			"slall": var T6: Dictionary = G.w_all.WCA.tc(); for i6 in G.w_all.WCA.book_ct(): T6.obj[i6] = 1   # (bản 498) thử: coi như đã có mọi công trình
			"slt": _slt(a)
			"sl": ui.sl_open(); if a.size() > 1: ui.slp.tab = a[1]; if a.size() > 2: ui.slp.bs = a[2]; ui.slp._build()   # sl[:tab[:loại bst]]
			"gpt": var t0 := Time.get_ticks_usec(); ui.gpp._tab_go(a[1] if a.size() > 1 else "db"); ui.gpp._build(); if OS.has_feature("web"): JavaScriptBridge.eval("window.__ordt=" + JSON.stringify({"gp": (Time.get_ticks_usec() - t0) / 1000.0}))   # (bản 495) đo dựng Gia phả
			"gp": ui.gp_open(int(a[2]) if a.size() > 2 else null); if a.size() > 1: ui.gpp._tab_go(a[1]); ui.gpp._build()   # gp[:tab[:nhà]]
			"thux": G.w_all.WTH.wU(a[1])
			"thugive": var T7: Dictionary = G.w_all.WTH.Eg(); var o7 = T7.get("rq") if T7.get("rq") is Dictionary else T7.get("un"); if o7 is Dictionary and o7.has("id"): G.g.barn[o7.id] = int(o7.q) + 1; G.mark()
			"dlrv": var R6: Dictionary = G.w_all.WDL.r6(); for i in 4: R6.rv.push_front({"s": [5, 4, 3, 2][i], "t": ["Làng đẹp, quán ngon, sẽ quay lại!", "Ở được, hơi ít món.", "Phòng ổn mà chẳng có gì chơi.", "Mưa suốt, chán."][i], "k": ["sg", "tay", "sg", "tay"][i], "n": 2, "xu": 300 - i * 50, "at": Time.get_unix_time_from_system() * 1000.0 - i * 3600000.0}); R6.n = 8; R6.xu = 1200; G.mark()
			"kl": ui.kl_open(a[1] if a.size() > 1 else "")
			"clg": ui.clg_open(a[1] if a.size() > 1 else "")
			"famx": var F0: Dictionary = G.w_all.WL._r0().fam; var k0 = F0.keys()[0]; for i in int(a[1]): F0[str(900 + i)] = F0[k0].duplicate(true); F0[str(900 + i)].n = "Nhà " + str(i); F0[str(900 + i)].tal = ["ruong", "vuon", "chan", "xuong"][i % 4]
			"hrt": _hrt()
			"utc": G.w_all.WL.ut_s().c = int(a[1]); G.w_all.WL.ut_s().p = int(a[2]) if a.size() > 2 else G.w_all.WL.ut_s().p; G.mark()
			"hidev": ui.get_parent().visible = false
			"gio": G.troi.hh = float(a[1])
			"troi": G.troi.force = a[1]
			"nga": G.troi.bao.storm(false) if a.size() < 2 else G.troi.bao.lk(int(a[1]))
			"set": G.troi.bao.strike()
			"lvq":
				G.g.lvq = []
				for x in String(a[1]).split(","):
					G.g.lvq.append(int(x))
			"xp": G.add_xp(int(a[1]), "")
			"cuatap": _cuatap()
			"caidat": ui.setp.open()
			"xay": G.xw.build(a[1]); G.g.coins = maxi(int(G.g.coins), 5000); G.mark()
			"xlam":
				for x in R2(a[2]):
					G.g.barn[x[0]] = int(G.g.barn.get(x[0], 0)) + int(x[1])
				G.xw.make(a[1], a[2])
			"xxong": G.xw.step(99999.0)
			"xmo": ui.xf_open(a[1])
			"xchon": ui.xfp._pick(a[1])
			"xbam": ui.xfp._do(a[1])
			"xq":
				G.xw.w(a[1]).q = Array(String(a[2]).split(","))
				G.xw.w(a[1]).p = float(a[3]) if a.size() > 3 else 0.0
			"xr": G.xw.w(a[1]).r = {a[2]: int(a[3])}
			"khoset":
				for x in String(a[1]).split(","):
					var kv := x.split("=")
					G.g.barn[kv[0]] = int(kv[1])
				G.mark()
			"lv": G.g.pc.lv = int(a[1]); G.mark()
			"bd": ui.bdp.open_shop()
			"bdx": ui.bdp.jz(a[1])
			"bdput": ui.bdp.mm()
			"bdsel": ui.bdp.fac = a[1]; ui.bdp._fl("fsel")
			"bdmv": ui.bdp.xb()
			"bdto": ui.bdp._y(Vector2(ui.F.en(float(a[1]) + 0.5, float(a[2]) + 0.5), ui.F.nn(float(a[1]) + 0.5, float(a[2]) + 0.5)), false)
			"bdoff": ui.bdp.close()
			"bdcat": ui.bdp.cat = a[1]; ui.bdp._ps()
			"bdq": G.g.coins = maxi(int(G.g.coins), 50000); ui.bdp.qy(a[1])
			"bdk": ui.bdp.k5(int(a[1]), int(a[2]))
			"bdok": ui.bdp.mm_put()
			"bdv": ui.bdp.vj(int(a[1]))
			"bdm": ui.bdp.bm()
			"bdxoay": ui.bdp.mj()
			"bdban": ui.bdp.bj()
			"bdpen": ui.bdp.wz(a[1])
			"datall": for t in ui.F.PC.G0: G.g.land[ui.F.PC.tg.get(t, t)] = 1
			"bdroad": ui.bdp.road = a[1]; ui.bdp._fl("road"); for q in range(int(a[4])): ui.bdp._paint(Vector2(ui.F.en(float(a[2]) + q + 0.5, float(a[3]) + 0.5), ui.F.nn(float(a[2]) + q + 0.5, float(a[3]) + 0.5)), true)
			"bdnen": ui.bdp.nen = a[1]; ui.bdp._fl("nen"); for q in range(int(a[4])): ui.bdp._paint(Vector2(ui.F.en(float(a[2]) + q + 0.5, float(a[3]) + 0.5), ui.F.nn(float(a[2]) + q + 0.5, float(a[3]) + 0.5)), true)
			"giu": ui.bdp.open_at(Vector2(ui.F.en(float(a[1]) + 0.5, float(a[2]) + 0.5), ui.F.nn(float(a[1]) + 0.5, float(a[2]) + 0.5)))
			"don": ui.F.tap(ui.F.world_to_screen(Vector2(ui.F.en(float(a[1]) + 0.5, float(a[2]) + 0.5), ui.F.nn(float(a[1]) + 0.5, float(a[2]) + 0.5))))
			"noxeng": load("res://logic/xuong_ve.gd").no_xeng = a.size() < 2 or a[1] == "1"
			"cdcuon": ui.setp._scroll_to(float(a[1]))
			"cdhoi": ui.setp.help(a[1])
			"cdchon": ui.setp.pick(a[1], a[2])
			"cdreset": ui.setp.reset_tap()
			"giado":
				for k in G.troi.bao.wx().fell:
					G.troi.bao.wx().fell[k].at = float(G.troi.bao.wx().fell[k].at) - float(a[1]) * 1000.0

func R2(rid: String) -> Array:
	return G.xw.R[rid].in

func _slt(a: Array) -> void:   # (bản 497) đo Sổ làng: slt:tab[:loại] -> window.__ordt {open, sig, body, mount}
	var t0 := Time.get_ticks_usec()
	ui.sl_open()
	var t_open := (Time.get_ticks_usec() - t0) / 1000.0
	var P = ui.slp
	P.tab = a[1] if a.size() > 1 else "lang"
	if a.size() > 2:
		P.bs = a[2]
	t0 = Time.get_ticks_usec()
	P._sig()
	var t_sig := (Time.get_ticks_usec() - t0) / 1000.0
	t0 = Time.get_ticks_usec()
	var o: Array = P._bst() if P.tab == "bst" else (P._dh() if P.tab == "dh" else P._lang())
	var t_body := (Time.get_ticks_usec() - t0) / 1000.0
	t0 = Time.get_ticks_usec()
	P._build()
	var t_all := (Time.get_ticks_usec() - t0) / 1000.0
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.__ordt=" + JSON.stringify({"open": t_open, "sig": t_sig, "body": t_body, "n": o[0].size(), "build": t_all}))

func _ctdump() -> void:   # (bản 498) công cụ: xuất hình công trình (đúng hình bảng Xây dựng dựng ra) -> window.__ctd {mã: png base64}; src/tools/bake_ct.py thu nhỏ thành ui/img/ct
	var ids: Array = G.w_all.WCA.book_ct()
	print("CTD ids ", ids.size(), " bdp ", ui.bdp != null)
	var cvs := {}
	for id in ids:
		var cv := Control.new()
		cv.size = Vector2(128, 104)
		ui.root.add_child(cv)
		cv.visible = false
		ui.bdp._icon(cv, ["id", String(id)], false)
		cvs[id] = cv
	var out := {}
	for t in 120:   # chờ tải gói hình (tối đa ~30 giây)
		await get_tree().create_timer(0.25).timeout
		var left := 0
		for id in cvs:
			if out.has(id):
				continue
			var cv: Control = cvs[id]
			var tr = cv.get_child(0) if cv.get_child_count() else null
			if tr is TextureRect and tr.texture == null and ui.bdp._ic.has(tr):
				ui.bdp._icon_fill(tr)
			if tr is TextureRect and tr.texture != null:
				var im: Image = tr.texture.get_image()
				if im != null:
					if im.is_compressed():
						im.decompress()
					out[id] = Marshalls.raw_to_base64(im.save_png_to_buffer())
			elif not (tr is TextureRect):
				out[id] = ""   # hình vẽ bằng code (đường, nền): để bảng tự vẽ
			if not out.has(id):
				left += 1
		if left == 0:
			break
		if t % 20 == 0:
			print("CTD wait ", left)
	for id in cvs:
		cvs[id].queue_free()
	print("CTD out ", out.size(), " thiếu ", ids.filter(func(i): return not out.has(i)))
	if OS.has_feature("web"):   # từng hình một (một chuỗi lớn eval không nổi)
		JavaScriptBridge.eval("window.__ctx={}")
		for id in out:
			JavaScriptBridge.eval("window.__ctx[" + JSON.stringify(String(id)) + "]=" + JSON.stringify(out[id]))
		JavaScriptBridge.eval("window.__ctd=window.__ctx")

func _paddyt(a: Array) -> void:   # (bản 513) thử: tìm ô ruộng hoang khu đã mua, đưa camera tới; paddyt:clr gặt 3x3 ô đó
	var L = G.lang
	for x in range(-10, 90):
		for y in range(-10, 90):
			if L.il(x, y) == "paddy" and L.fo(x, y) != "" and not L.kc(x, y) and not L.n2(x, y):
				if not L.ci(L.fo(x, y)):   # thử: coi như đã mua khu này
					G.g.land[String(ui.F.PC.tg.get(L.fo(x, y), L.fo(x, y)))] = 1
					G.mark()
				var F = ui.F
				var vp: Vector2 = ui.get_viewport().get_visible_rect().size
				ui.main.cam = Vector2(F.en(x + 1.5, y + 1.5), F.nn(x + 1.5, y + 1.5)) - Vector2(vp.x * 0.5, vp.y * 0.5) / ui.main.zoom
				if a.size() > 1:
					for i in range(-4, 8):
						for j in range(-4, 8):
							if L.il(x + i, y + j) == "paddy":
								G.g.clr[str(x + i) + "," + str(y + j)] = 1
					G.mark()
				print("PADDY ", x, ",", y)
				return

func _ghet() -> void:   # (bản 515) thử: ghe đậu bến ngay với 6 thùng, có món đủ
	var WG = G.w_all.WGH
	var L: Array = WG.ft()
	if L.size():
		G.g.barn[L[0].id] = int(L[0].q) + 3
	WG.Ae.offers = L
	WG.Ae.st = 2
	WG.Ae.left = 3.0 * 3600.0 + 1380.0
	WG.Ae.from = "Cái Bè"
	WG.test_hold = true
	G.g.gh = {"from": "Cái Bè", "cr": L, "until": G._now_ms() + WG.Ae.left * 1000.0, "key": ""}
	G.mark()
	ui.ghe_open()

func _ghxa() -> void:   # (bản 516) thử: kho đủ mọi thùng, chất hết trừ thùng cuối
	var WG = G.w_all.WGH
	var L: Array = WG.Ae.offers
	for o in L:
		G.g.barn[o.id] = int(G.g.barn.get(o.id, 0)) + int(o.q)
	for i in L.size() - 1:
		WG.Hd(i)

func _gptree() -> void:   # (bản 493) test Gia phả: nhân bản 12 nhà, chia 3 họ, nối cha con thành cây, tim / việc khác nhau
	var F0: Dictionary = G.w_all.WL._r0().fam
	var k0 = F0.keys()[0]
	var hos := ["Nguyễn", "Trần", "Lê"]
	var nm := ["Ông Ba Tèo", "Bà Tư Lành", "Anh Năm Sang", "Chị Sáu Mai", "Út Hiền", "Cô Bảy Lan", "Chú Tám Hùng", "Anh Hai Phúc", "Chị Mười Thu", "Bé Na", "Thằng Tí", "Dì Sáu"]
	for i in 12:
		var f: Dictionary = F0[k0].duplicate(true)
		var h: int = 0 if i < 6 else (1 if i < 10 else 2)
		f.n = nm[i]; f.ho = hos[h]; f.lk = i % 8; f.tim = [5, 3, 2, 0, 1, 4, 2, 0, 3, 1, 0, 2][i]
		f.cha = null; f.doi = 1
		if h == 0 and i > 0:
			f.cha = 900 + (0 if i < 3 else (1 if i < 5 else 2)); f.doi = 2 if i < 3 else 3
		if h == 1 and i > 6:
			f.cha = 906; f.doi = 2
		f.mo = 1 if i % 3 == 0 else 0
		F0[str(900 + i)] = f
	G.mark()

func _thu(a: Array) -> void:   # (bản 491) test Thư nhà: thu:tien|tin|nho|rq[:lg] (lg: thêm thư cũ giả)
	var T: Dictionary = G.w_all.WTH.Eg()
	var k: String = a[1] if a.size() > 1 else "nho"
	var tx := "Út Mến viết: \"Trên này mua đồ quê đắt mà không ngon. Nhà mình gửi giùm con 12 trứng gà theo đường bưu điện nha, con gửi tiền cước về.\""
	match k:
		"tien": T.un = {"k": "tien", "who": "Hai Lúa", "xu": 1061, "txt": "Hai Lúa ở Sài Gòn viết thư về: \"Con đi làm ở xưởng may cũng đỡ, gửi về chút tiền ông bà tiêu Tết.\""}
		"tin": T.un = {"k": "tin", "who": "Bé Na", "gach": 5, "txt": "Bé Na gửi thư thăm: \"Con gửi kèm mấy viên gạch nung cũ ở nhà chủ cho, để dành sửa nhà.\""}
		"rq": T.un = null; T.rq = {"id": "trung", "q": 12, "xu": 1061, "who": "Út Mến"}
		_: T.un = {"k": "nho", "who": "Út Mến", "id": "trung", "q": 12, "xu": 1061, "txt": tx}
	if a.size() > 2:
		var d: int = G.w_all.WL._vr()
		T.lg = [{"w": "Hai Lúa", "s": "+820 xu", "ic": "xu", "k": "tien", "d": d - 1}, {"w": "Bé Na", "s": "+4 gạch", "ic": "svg:res://ui/svg/mat/gach.svg", "k": "tin", "d": d - 2}, {"w": "Cậu Ba", "s": "Gửi 6 trứng", "ic": "trung", "k": "nho", "d": d - 4}]
	G.mark()
	ui.thu_open()

func _tnsim(a: Array) -> void:   # thử Thiên tai: tnsim:next (dời ngày tới hôm trước trận kế) | tnsim:hit:loại (trận xảy ra hôm nay)
	var W = G.w_all.WL
	match String(a[1]):
		"next":
			for n in 60:
				if W.tn_on(G._day0() + n + 1) != null:
					G.day_off = n
					break
		"hit":
			G.w_all.WD._tn_hit0({"k": String(a[2]), "d": G.day()}, false)
	G.mark()

func _hrt() -> void:   # thử: đo thời gian dựng bảng Làm thuê (ghi window.__ordt)
	var t0 := Time.get_ticks_usec()
	ui.hrp._build()
	var b := (Time.get_ticks_usec() - t0) / 1000.0
	var t1 := Time.get_ticks_usec()
	var r: Dictionary = ui.hrp._body()[0].size() > 0 and {} or {}
	var b2 := (Time.get_ticks_usec() - t1) / 1000.0
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.__ordt=" + JSON.stringify({"build": b, "body": b2}))

func _ngsim(a: Array) -> void:   # thử bảng Nghề: ngsim:sao:nghề:số sao[:c] | ngsim:thi:nghề | ngsim:don4
	var W = G.w_all.WL
	var o: Dictionary = W.ng_s()
	match String(a[1]):
		"sao":
			var b := String(a[2])
			var sv := int(a[3])
			W.t6()[b] = 1
			o.sao[b] = sv
			o.xp[b] = W.NGSAO[sv - 1]
			if a.size() > 4 and not o.chinh.has(b):
				o.chinh.append(b)
		"thi":
			var b := String(a[2])
			W.t6()[b] = 1
			o.xp[b] = 99999
			o.mk[b] = 9999
			o.hq[b] = [999, 999]
			var u: int = W.ng_thay(b)
			var f = W._fam_of(u) if u else null
			if f != null:
				f.tim = 5
			for sf in ["", "_k", "_x"]:
				G.g.barn[b + sf] = 99
			G.g.coins = 999999
		"don4":
			W.ng_d().l.append({"id": "t4", "src": "cuoi", "t": "Nhà Chị Hai Bông sắp cưới con", "u": "", "it": [["banh_pt", 4, 1], ["chieu", 1, 1], ["khan_theu", 2, 0], ["ruou_nep", 2, 0]], "dl": W._vr() + 2, "xu": 5200, "ut": 2, "th": 0})
	G.mark()

func _nvx(k: int) -> void:
	# trạng thái thử giống mấy ảnh chụp bản web (act_nv2.json)
	var N = G.nv
	var n: Dictionary = N.Pl()
	N.MI()
	var s: Dictionary = N.SI()
	if k == 1:
		n.c.harvest = 10; n.c.deliver = 2; n.c.water = 4; n.cl["20"] = 1
		s.c = 3; s.last = N.d4() - 1; s.best = 33
	elif k == 2:
		n.sw = 1; n.c.plant = 12; n.c.water = 12; n.c.fish = 3; s.c = 7; s.last = N.d4(); n.cl["40"] = 1; n.cl["60"] = 1
	elif k == 3:
		var w: Dictionary = n.wk
		w.c.deliver = 25; w.c.harvest = 70; w.cl["m0"] = 1
	elif k == 4:
		G.g.sys.stats.harvest = 12; n.ach.collect = 5; n.ln.kho = 9
	elif k == 5:
		var e = N.ev()
		e.p = 60; e.day["1"] = 55; e.cl["d:1:0"] = 1
	elif k == 6:
		var e = N.ev()
		e.ve = 7
	G.mark()
	ui.nvp.sig = ""

func _cloud_loaded() -> void:
	# bản lưu trên mạng vừa thay bản trên máy: dựng lại bảng, vẽ lại làng (đồ xây, xưởng, ruộng)
	if farm.lang != null:
		farm.lang.ver += 1
	_rebuild_ui()
	farm.refresh()

func _rebuild_ui() -> void:
	# đổi khổ màn hình ra độ to khác (Wi.s): dựng lại bảng với số mới, như bản web đổi --ks
	var m = ui.get_parent()
	var old := ui
	ui = UiS.new()
	m.add_child(ui)
	ui.setup(G, P, farm, m.dpr)
	ui.set_meta("rebuild", _rebuild_ui)
	ui.visible = old.visible
	farm.ui = ui
	old.queue_free()

func _cuatap() -> void:
	# thử: chạm vào cây ngã đầu tiên (đúng chỗ qK bản web bắt chạm)
	var B = G.troi.bao
	for k in B.wx().fell:
		var o: Dictionary = B.wx().fell[k]
		if o.s != "down":
			continue
		var l: Dictionary = B.by[k]
		var c := float(l.gx) + float(l.fw) / 2.0 + float(o.d[0]) * 0.6
		var f := float(l.gy) + float(l.fd) / 2.0 + float(o.d[1]) * 0.6
		var w := Vector2(4268.0 + (c - f) * 32.0, 968.0 + (c + f) * 16.0 - 10.0)
		farm.tap(farm.world_to_screen(w))
		return
