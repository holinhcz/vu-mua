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

func _ready() -> void:
	G = GameS.new()
	G.name = "Game"
	add_child(G)
	P = PicsS.new()
	P.name = "Pics"
	add_child(P)

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
		ui.visible = bool(m.first_ready)

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
				var I := {"an": farm.anodes.keys(), "open": ui.vnp.is_open(), "sig": ui.vnp.sig != "", "b": ui.vnp.b != null, "barn": G.g.barn, "pens": G.g.pens.ga, "acts": ui.vnp.acts.map(func(x): return x.get("t", "slot"))}
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
			"vnbtn":   # vnbtn:i: bấm nút thứ i của bảng con vật
				ui.vnp._do(ui.vnp.acts[int(a[1])].cb)
			"ftset":   # ftset:id:gx:gy:fp:fw: đặt một cây ăn trái
				G.g.objs.append({"id": a[1], "gx": int(a[2]), "gy": int(a[3]), "seed": 0, "fp": float(a[4]), "fw": float(a[5])})
				G.mark()
				farm.lang.changed()
			"ftopen": ui.ft_open(int(a[1]) if int(a[1]) >= 0 else G.g.objs.size() + int(a[1]))
			"fttap":
				var oi: int = int(a[1]) if int(a[1]) >= 0 else G.g.objs.size() + int(a[1])
				farm.tap(farm.world_to_screen(farm.ft_bub(oi) + Vector2(0, 30)))
			"ftbtn": ui.ftp._do(ui.ftp.acts[a[1]])
			"ftinfo":
				var FI := {"open": ui.ftp.ti, "acts": ui.ftp.acts.keys(), "barn": G.g.barn, "q": farm.q.size()}
				for oi in G.g.objs.size():
					if G.ct.tree(oi) != null:
						FI[str(oi)] = [G.g.objs[oi].id, G.g.objs[oi].fp, G.g.objs[oi].fw, farm.lang_ve.top_of(G.g.objs[oi])]
				JavaScriptBridge.eval("window.__ntvn=" + JSON.stringify(FI))
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
				JavaScriptBridge.eval("window.__ntlp=" + JSON.stringify([ui.bdp.mode, farm.lang.obj_at(wq, V.pick_obj), farm.lang.so_pick(wq, true, V.pick_so) != null, farm.lang.so_pick(wq, false, V.pick_so) != null, ui.bdp.open_at(wq), ui.bdp.mode]))
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
			"nvday": G.nv.xI = int(floor(G.nv.d4() / 14.0)) * 14 + int(a[1]); ui.nvp.sig = ""
			"nvx": _nvx(int(a[1]))
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
		w.c.deliver = 25; w.c.harvest = 70; w.dd["1"] = 1; w.dd["2"] = 1; w.cl["40"] = 1
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
