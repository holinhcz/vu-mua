extends SceneTree
# Smoke test NTWEB (tạm, xóa sau khi chạy): game.gd + w_all không có làng thật, bản lưu mới trong bộ nhớ.

class TG extends "res://logic/game.gd":
	func _ready() -> void:
		pass
	func save_game() -> void:   # không ghi đè bản lưu thật
		dirty = false
	func _cloud_step(_dt: float) -> void:
		pass

class StubFarm extends Node2D:
	var main = null
	var PC := {"G0": {}}
	var ui = null
	var lang_ve = null
	func pc_own(t) -> bool:
		return String(t) == "nha" or String(t) == "vuon" or String(t) == "dong"
	func onscreen(_x, _y, _m) -> bool:
		return true
	func ts(_i, _k, _c = "") -> void:
		pass
	func burst(_a = null, _b = null, _c = null, _d = null, _e = null, _f = null, _g = null, _h = null, _i = null, _j = null) -> void:
		pass
	func seeds_queued(_s) -> int:
		return 0

var G
var t0 := 0
var frames := 0
var phase := 0

func _initialize() -> void:
	print("SMOKE start")
	G = TG.new()
	G.name = "Game"
	root.add_child(G)
	G.cfg_load()
	G.nv = load("res://logic/nv.gd").new(G)
	G.troi = load("res://logic/troi.gd").new(G)
	G._load_data()
	G.xw = load("res://logic/xuong.gd").new(G)
	G.vn = load("res://logic/vatnuoi.gd").new(G)
	G.w_all = load("res://logic/w_all.gd").new(G)
	G.g = G._fresh()
	G.w_all.on_load()
	G.ord_fill()
	G.toast.connect(func(m): print("  TOAST: ", m))
	var old := {"plots": [], "barn": {"lua": 3}, "coins": 5, "land": {"nha": 1}, "pc": {"lv": 3, "xp": 0, "en": 50.0, "et": 0, "n": 0, "cnt": {}}, "sys": {"pts": 0}, "gio": {"lv": 3}}
	var mg: Dictionary = G._migrate(old)
	print("migrate old: hdv=", mg.get("hdv"), " sv2=", mg.get("sv2"), " rain=", mg.get("rain"), " goal=", mg.get("goal"))
	print("fresh ok; goal=", G.w_all.WS.goal_view())
	# bù offline trước khi có làng (dồn pend)
	G.catch_up(600.0)
	print("pend before lang = ", G.w_all.pend)
	var F := StubFarm.new()
	root.add_child(F)
	G.lang = load("res://logic/lang.gd").new(G, F)
	G.troi.bao.farm = F
	G.g.pc.lv = 30
	G.g.objs.append({"id": "ft_dua", "gx": 3, "gy": 8, "v": 0})
	G.g.objs.append({"id": "ft_chuoi", "gx": 5, "gy": 8, "v": 0})
	G.g.objs.append({"id": "thungong", "gx": 7, "gy": 8, "v": 0})
	G.lang.changed()
	print("tree ql=", G.w_all.WR.ql(0), " ax=", G.w_all.WR.ax_pos(0))
	print("zb=", G.w_all.WR.zb(true), " tree_run water=", G.w_all.WR.tree_run(1, "twater"))
	print("hyb sd_n=", G.sd_n(String(G.w_all.WR.Wc[0]) if G.w_all.WR.Wc.size() else "lua"))
	# gieo vài ô để có việc
	for i in 6:
		G.g.barn["lua"] = 20
		G.plant(i, "lua")
		G.water(i)
	print("price lua=", G.price("lua"), " price0=", G.price0("lua"), " rel=", G.rel("lua"), " boost=", G.boost())
	G.vib([12, 30, 18])

func _process(dt: float) -> bool:
	frames += 1
	if phase == 0:
		# 10 phút mô phỏng: lượt luật 0,25 s + khung 1/60
		for k in 2400:
			G._grow(0.25)
			G.w_all.step(0.25, false)
			G.xw.step(0.25)
			G.vn.step(0.25)
			G.nv.step(0.25)
			G._mk_step(0.25)
			G._ord_step(0.25)
			for f in 15:
				G.w_all.frame(1.0 / 60.0)
				G.troi.step(1.0 / 60.0)
		print("10 min done; rain=", G.g.get("rain"), " mt=", G.g.get("mt"), " plots0.g=", G.g.plots[0].g)
		for i in 6:
			if G.ripe(G.p(i)):
				G.harvest(i)
		phase = 1
		return false
	if phase == 1:
		G.catch_up(3.0 * 3600.0)
		print("catch_up 3h done; pend=", G.w_all.pend, " plots1.g=", G.g.plots[1].g)
		G.deliver(0)
		G.nv.S8("water")
		print("has_hx=", G.nv.has_hx())
		print("tree after: ", G.w_all.WR.ql(0), " harvest=", G.w_all.WR.tree_run(0, "tharvest"))
		print("mkWhy lua=", G.w_all.WK.mkWhy("lua"), " jb=", G.w_all.WH.jb())
		phase = 2
		# giao diện: ui.gd + các *_ui (không có làng thật)
		var P = load("res://logic/pics.gd").new()
		root.add_child(P)
		var F = G.lang.F
		F.main = Node2D.new()
		root.add_child(F.main)
		var ui = load("res://logic/ui.gd").new()
		root.add_child(ui)
		F.ui = ui
		ui.setup(G, P, F, 1.0)
		var W = G.w_all
		print("ui ok: ", W.WRU != null, " ", W.WCAU != null)
		W.WRU.open_tree(0)
		W.ui_tick()
		print("tree popup: ", W.WRU.tree != null)
		ui.close_all()
		print("after close_all tree_i=", W.WRU.tree_i)
		W.WCU.open_rd()
		W.WHU.open_fest()
		W.WCU.open_cho(1)
		W.ui_tick()
		ui.close_all()
		for id in ["nuoi", "dieu", "lo"]:
			var c: Control = W.WCAU.tab_body(id)
			print("tab ", id, " kids=", c.get_child_count())
			c.free()
		ui.pcp.open("nuoi")
		ui.pcp.step()
		print("pc nuoi open: ", ui.pcp.box != null)
		ui.pcp._tab("lo")
		ui.pcp._tab("dieu")
		ui.pcp.close()
		ui._sync_hud()
		W.WSU.open_sys() if W.WSU.has_method("open_sys") else null
		ui.close_all()
		print("ui phase done")
		return false
	if phase == 5:
		var old := {"plots": [], "barn": {"lua": 3}, "coins": 5, "land": {"nha": 1}, "pc": {"lv": 8, "xp": 0, "en": 50.0, "et": 0, "n": 0, "cnt": {}}, "sys": {"pts": 35}, "gio": {"lv": 8}, "objs": [{"id": "ft_dua", "gx": 3, "gy": 8}]}
		for k in ["clr", "mv", "minis", "road", "unroad", "gt", "penb", "fac"]:
			old[k] = {}
		G.g = G._migrate(old)
		G.w_all.on_load()
		G.lang.changed()
		for k in 400:
			G.w_all.step(0.25, false)
			G.w_all.frame(0.25)
		G.catch_up(3600.0)
		print("old save ok: pts=", G.g.sys.pts, " hdv=", G.g.hdv, " plots0.st=", G.g.plots[0].get("st"), " mult n=", G.g.mult.size())
	if phase < 10:
		phase += 1   # cho create_timer kịp chạy
		return false
	print("SMOKE end")
	return true
