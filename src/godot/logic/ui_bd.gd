extends RefCounted
# Bảng XÂY DỰNG chép từ bản web (module "build": Mt, Ps/k(), Qy, mM, bM, mj, bj, Iz, Fz, xj, jz, Wz, xb, _y, MM, Zy,
# TM, Jz/CM, rq/EM, lq/PM, wj, Mj, kj). 4 nhóm, 10 mục: Cây cối (Cây, Ăn trái, Hoa cỏ), Công trình (Nhà, Xưởng,
# Chuồng), Trang trí (Đồ vật, Mặt nước), Mặt đất (Đường, Nền đất). Luật ô đất + món đặt: lang.gd. Vẽ: lang_ve.gd.
# Số đo + css: ui/snap/bc_<mục> (bảng từng mục), bc_qua1 (dòng khoá), bdx (thẻ xưởng), bpl / bpl_bad / bpl_mv (đặt,
# sai chỗ, dời), bsel / bsel_f (món đã chọn, vật có sẵn), broad / bnen / bmini (lát đường, tô nền, trồng hoa cỏ),
# bdf / bdm / bds / bdp / bpen (xưởng, chuồng, Sửa làng), bdhelp (Cách xây), btier (Hạng làng).

const Snap = preload("res://ui/snap.gd")
const Box = preload("res://ui/box.gd")
const Css = preload("res://ui/css.gd")
const XV = preload("res://logic/xuong_ve.gd")
const XW = preload("res://logic/xuong.gd")
const LN = preload("res://logic/lang.gd")

const GROUPS := [{"k": "caycoi", "c": [["cay", "Cây"], ["qua", "Ăn trái"], ["hoaco", "Hoa cỏ"]]},
	{"k": "congtrinh", "c": [["nha", "Nhà"], ["xuong", "Xưởng"], ["chuong", "Chuồng"]]},
	{"k": "trangtri", "c": [["vat", "Đồ vật"], ["nuoc", "Mặt nước"]]},
	{"k": "matdat", "c": [["duong", "Đường"], ["nen", "Nền đất"]]}]
var HELP := {
	"chuong": "Xây chuồng rồi mới mua được con giống (Sổ làng › Chợ phiên, hoặc ghe cây giống ở chợ nổi sáng sớm). Mỗi chuồng 2×2 ô, nuôi tối đa 6 con. Chuồng đã xây thì chạm giữ trên làng để dời.",
	"xuong": "Mỗi loại xưởng xây tối đa 2 cái, cái thứ hai giá gấp đôi. Chọn xưởng rồi chọn chỗ đặt trên đất trống (tô xanh). Món cao cấp cần nguyên liệu do xưởng khác làm ra.",
	"hoaco": "Bụi cây, cỏ dại, lau sậy chiếm trọn 1 ô, bấm Đổi kiểu để chọn 1 trong 4 dáng. Các món còn lại: mỗi ô đất chia 4 chỗ nhỏ, mỗi chỗ trồng một khóm hoa hay bụi cỏ. Chạm để trồng, giữ kéo để trồng liền. Cứ 4 khóm thêm 1 điểm đẹp.",
	"nen": "Chọn loại nền rồi chạm lên đất đã khai hoang để tô, giữ kéo để tô liền. Đồ đạc, hoa cỏ đặt lên trên vẫn giữ nguyên. Cứ 6 ô nền thêm 1 điểm đẹp.",
	"duong": "Chọn loại đường rồi chạm từng ô để lát, giữ kéo để lát liền một dải. Đường làng có sẵn cũng gỡ hoặc lát lại được.",
	"nuoc": "Hoa sen, thuyền và cầu cần đặt trên mặt nước. Dùng \"Đào ao\" để tạo thêm ô nước.",
	"qua": "Cây ăn trái cho trái chín theo giờ, chạm cây để hái. Cây giống quý đổi được ở hội chợ thì trồng miễn phí.",
	"def": "Chọn một món rồi chạm lên đất của bạn để đặt. Chạm giữ món đã đặt trên làng để dời hoặc bán lại một nửa giá. Mỗi món thêm điểm đẹp, làng đẹp thì nông sản bán giá cao hơn."}

var U
var G
var LG                   # lang.gd
var mode := "off"        # off / shop / place / sel / pick / fmove / fsel / road / nen / mini (Mt.mode)
var cat := "cay"         # Mt.cat
var grp_cat := {}        # n[]: mục đang chọn của mỗi nhóm
var id := ""             # Mt.id (món đang đặt)
var seed := 0            # Mt.seed
var gx := 0
var gy := 0
var why := ""            # Mt.why
var move_idx := -1       # Mt.moveIdx
var sel := -1            # Mt.sel
var fac := ""            # Mt.fac (xưởng hoặc chuồng)
var fbuy := false        # Mt.fbuy
var fmv := ""            # Mt.fmv: xưởng / chuồng đang nhấc lên
var forig := Vector2i.ZERO
var fwhy := ""
var fspots := []         # Mt.fspots
var ftiles := {}         # Mt.ftiles
var road := ""           # Mt.road
var nen := ""            # Mt.nen
var nb := 1              # Mt.nb (cọ 1 ô / 3x3)
var mini := ""           # Mt.mini
var hov = null           # Mt.rg / Mt.ng / Mt.mq: ô đang chỉ
var last_k := ""         # wb / Sb / Ab: ô vừa tô khi kéo
var paint = null         # đang giữ kéo để lát / tô / trồng
var tier_i := -1         # Mt.tier
var gdrag = null         # kéo xưởng / chuồng / món bằng ngón tay
var T := {}
var pov: Control = null
var pids := {}
var sheet: Control = null
var sids := {}
var help_b: Control = null
var grid: Control = null
var lis := []
var sc := 0.0
var sc_max := 0.0
var drag = null
var ov_lo: Node2D = null
var ov_hi: Node2D = null
var t := 0.0
var _gray: ShaderMaterial = null
var _ic := {}            # TextureRect -> [gói, khoá]

func _init(ui) -> void:
	U = ui
	G = ui.G
	for gp in GROUPS:
		grp_cat[gp.k] = gp.c[0][0]
	var bx = Snap.load_snap("bdx")["#pov"][0]
	var gx0: Dictionary = Snap.find(bx, "khgrid")
	for li in gx0.kids:
		if String(li.kids[0].cls).split(" ").has("locked") and not T.has("li_lock_x"):
			T.li_lock_x = li
	T.li_open_x = gx0.kids[0]
	T.pov_xuong = bx
	for c in ["cay", "qua", "hoaco", "nha", "chuong", "vat", "nuoc", "duong", "nen"]:
		T["pov_" + c] = Snap.load_snap("bc_" + c)["#pov"][0]
	var q1 = Snap.load_snap("bc_qua1")["#pov"][0]
	T.hint = Snap.find(q1, "bhint")
	var g1 := Snap.find(q1, "khgrid")
	T.grid1 = g1
	T.li_lock = g1.kids[0]
	var gn := Snap.find(T.pov_nen, "khgrid")
	T.li_unit = gn.kids[0]          # thẻ giá "/ô"
	T.li_open = Snap.find(T.pov_cay, "khgrid").kids[0]
	for nm in ["bdf", "bdm", "bds", "bdp", "bpl", "bpl_bad", "bpl_mv", "bsel", "bsel_f", "broad", "bnen", "bmini", "bpen"]:
		T[nm] = Snap.load_snap(nm)["#buildSheet"][0]
	var hp = Snap.load_snap("bdhelp")
	T.help = hp[".u2pop"][0] if hp is Dictionary and hp.has(".u2pop") and hp[".u2pop"].size() > 0 else Snap.load_snap("set_pop")[".u2pop"][0]
	T.tier = Snap.load_snap("btier")[".u2pop"][0]
	for key in T:
		if T[key] is Dictionary:
			_coin(T[key])
	_gray = ShaderMaterial.new()
	var sh := Shader.new()
	# .bdgrid .khb.locked canvas{filter:grayscale(1);opacity:.45}
	sh.code = "shader_type canvas_item;\nuniform float a = 1.0;\nuniform float g = 0.0;\nvoid fragment(){ vec4 c = COLOR; float l = dot(c.rgb, vec3(0.2126, 0.7152, 0.0722)); c.rgb = mix(c.rgb, vec3(l), g); c.a *= a; COLOR = c; }"
	_gray.shader = sh

static func _coin(n: Dictionary) -> void:
	if n.get("tag", "") == "img" and String(n.get("cls", "")).split(" ").has("xui"):
		n.src = "xui"
	for q in n.get("kids", []):
		_coin(q)

func lg():
	if LG == null:
		LG = U.F.lang
	return LG

# ------------------------------------------------------------------ xưởng / chuồng chung (sr / mo, _5, Jv, Uy, wM, Co)
func is_pen(k: String) -> bool:
	return LN.CO.has(k)

func fsize(k: String) -> Vector2i:
	if is_pen(k):
		return Vector2i(2, 2)
	var s: Dictionary = G.xw.sr[k]
	return Vector2i(int(s.fw), int(s.fd))

func fpos(k: String) -> Vector2i:
	if is_pen(k):
		return lg().pen_pos(k)
	var s: Dictionary = G.xw.sr[k]
	return Vector2i(int(s.gx), int(s.gy))

func fbuilt(k: String) -> bool:
	return lg().pen_built(k) if is_pen(k) else G.xw.built(k)

func fcost(k: String) -> int:
	return int(lg().C.xM.get(k, 500)) if is_pen(k) else int(G.xw.sr[k].cost)

func fname(k: String) -> String:
	if is_pen(k):
		return LN.CO[k]
	var s: Dictionary = G.xw.sr[k]
	return String(s.name) + (" " + str(int(s.n) + 1) if int(s.get("n", 0)) > 0 else "")

func cg(k: String, x0: int, y0: int) -> String:   # cg: lý do không đặt xưởng / chuồng được
	var L = lg()
	var e := fsize(k)
	for r in e.x:
		for o in e.y:
			var x := x0 + r
			var y := y0 + o
			var f: String = L.fo(x, y)
			if f == "":
				return "Ra ngoài rìa làng"
			if not L.ci(f):
				return "Khu đất này chưa khai hoang"
			if L.D5(x, y):
				return "Chỗ này còn cây hoặc lúa, chạm để dọn trước"
			var s: String = L.zv(x, y, -1)
			if s != "land":
				return "Không đặt lên đường làng được" if L.o2(x, y) else ("Không đặt xuống nước được" if s == "water" else "Chỗ này đã có vật khác")
	return ""

# ------------------------------------------------------------------ mở / đóng (Bz / Mh / Fl)
func active() -> bool:
	return mode != "off"

func open_shop() -> void:   # Bz
	U.close_all()
	sel = -1
	move_idx = -1
	gdrag = null
	_fl("shop")

func close() -> void:   # Mh
	if mode == "off":
		return
	if mode == "fmove":
		_tm()
		fbuy = false
		fac = ""
	if mode == "place" and move_idx >= 0:
		move_idx = -1
		lg().changed()
	sel = -1
	move_idx = -1
	gdrag = null
	_fl("off")

func _fl(m: String) -> void:   # Fl -> Ps
	mode = m
	_ps()

func _free(b: Control) -> void:
	if b != null and is_instance_valid(b):
		U.anchors.erase(U._anchor_of(b))
		b.queue_free()

func _ps() -> void:
	_free(pov)
	pov = null
	grid = null
	lis = []
	_ic = {}
	_free(sheet)
	sheet = null
	var b: int = lg().beauty()
	var st: int = lg().tier(b)
	if tier_i < 0:
		tier_i = st
	elif st > tier_i:
		tier_i = st
		G.toast.emit("Làng lên hạng: " + String(lg().C.Q5[st].n) + ". Giá bán nông sản +" + str(int(round(lg().sell_bonus() * 100))) + "%.")
		G.vib([12, 30, 18])
	else:
		tier_i = st
	_ov()
	if mode == "shop":
		_build_shop()
	elif mode != "off":
		_build_sheet()
	U.F.lang_ve.sync()
	_ghost()
	U._layout()

func _ghost() -> void:
	var V = U.F.lang_ve
	if mode == "place":
		V.show_ghost(id, seed, gx, gy, why != "")
	else:
		V.hide_ghost()

# ------------------------------------------------------------------ bảng cửa hàng (k())
func _grp(c: String) -> Dictionary:
	for gp in GROUPS:
		for q in gp.c:
			if q[0] == c:
				return gp
	return GROUPS[0]

func _cards() -> Array:   # [{name, pr, r (0 mở / 1 khoá / 2 đủ), lv, i, act, icon}]
	var L = lg()
	var out := []
	var add := func(d: Dictionary, r: int, lv: int) -> void:
		d.r = r
		d.lv = lv
		d.i = out.size()
		out.append(d)
	if cat == "duong":
		for gt in L.C.Kz:
			add.call({"name": gt.n, "pr": ["c", int(gt.cost), "ô"] if int(gt.cost) > 0 else ["t", "Gỡ bỏ" if gt.id == "_x" else "Miễn phí", "free"], "act": ["road", gt.id], "ic": ["road", gt.id]}, 0, 0)
	elif cat == "nen":
		for gt in L.C.Yz:
			add.call({"name": gt.n, "pr": ["c", int(gt.cost), "ô"], "act": ["nen", gt.id], "ic": ["nen", gt.id]}, 0, 0)
		add.call({"name": "Trả nền cũ", "pr": ["t", "Trả cỏ", "free"], "act": ["nen", "_x"], "ic": ["nen", "_x"]}, 0, 0)
	elif cat == "hoaco":
		for gt in L.C.og:
			if gt.cat == "hoaco" and not gt.get("hide", false):
				if not U.F.lang_ve.has_pic(gt.id):
					add.call({"name": gt.n, "pr": ["t", "SOON", "lk"], "act": ["soon", gt.id], "ic": ["id", gt.id]}, 1, 10000)
					continue
				add.call({"name": gt.n, "pr": ["c", int(gt.cost), ""], "act": ["id", gt.id], "ic": ["id", gt.id]}, 0, 0)
		for gt in L.C.LM:
			add.call({"name": gt.n, "pr": ["c", int(gt.cost), "chỗ"], "act": ["mini", gt.id], "ic": ["mini", gt.id]}, 0, 0)
		add.call({"name": "Nhổ hoa cỏ", "pr": ["t", "Nhổ bỏ", "free"], "act": ["mini", "_x"], "ic": ["mini", "_x"]}, 0, 0)
	elif cat == "chuong":
		for gt in L.C.Di:
			var A: bool = L.pen_built(gt)
			var at: int = 0 if A else L.pen_lv(gt)
			add.call({"name": LN.CO[gt], "pr": ["t", "✓ Đã xây", "ok"] if A else (["t", "Cấp " + str(at), "lk"] if at > 0 else ["c", int(L.C.xM[gt]), ""]),
				"act": ["pen", gt], "ic": ["pen", gt], "full": A}, 2 if A else (1 if at > 0 else 0), at)
	elif cat == "xuong":
		for ty in G._j("che_bien/thu_tu_xuong"):
			var a: Dictionary = G.xw.T[ty]
			var n := 0
			var pt := ""
			for k in G.xw.N0:
				if G.xw.sr[k].type != ty:
					continue
				if G.xw.built(k):
					n += 1
				elif pt == "":
					pt = k
			var zt := 0
			if pt != "" and G.lv() < int(G.xw.sr[pt].lv):
				zt = int(G.xw.sr[pt].lv)
			add.call({"name": String(a.name), "pr": ["t", "Cấp " + str(zt), "lk"] if zt > 0 else (["c", int(G.xw.sr[pt].cost), ""] if pt != "" else ["t", "✓ Đã đủ", "ok"]),
				"act": ["wt", ty], "ic": ["wt", ty], "cnt": str(n) + "/" + str(XW.I3), "full": pt == ""}, 1 if zt > 0 else (0 if pt != "" else 2), zt)
	else:
		for gt in L.C.og:
			if gt.cat != cat or gt.get("hide", false):
				continue
			var A: int = L.pg(gt.id)
			var at: int = L.cm(gt)
			if gt.id != "pond" and not U.F.lang_ve.has_pic(gt.id):   # chưa có hình 9 px gốc trong godot/
				add.call({"name": gt.n, "pr": ["t", "SOON", "lk"], "act": ["soon", gt.id], "ic": ["id", gt.id]}, 1, 10000)
				continue
			if gt.get("fest", ""):
				add.call({"name": gt.n, "pr": ["t", "Quà lễ ×" + str(A), "ok"] if A > 0 else ["t", "Lộc lễ", "lk"], "act": ["id", gt.id], "ic": ["id", gt.id]}, 0 if A > 0 else 1, 10000)
				continue
			add.call({"name": gt.n, "pr": ["t", "Cấp " + str(at), "lk"] if at > 0 else (["t", str(A) + " cây giống", "ok"] if A > 0 else ["c", int(gt.cost), ""]),
				"act": ["id", gt.id], "ic": ["id", gt.id]}, 1 if at > 0 else 0, at)
	out.sort_custom(func(p, q): return p.r < q.r if p.r != q.r else ((p.lv < q.lv) if (p.r == 1 and p.lv != q.lv) else p.i < q.i))
	return out

func _build_shop() -> void:
	var src: Dictionary = T.pov_xuong if cat == "xuong" else T["pov_" + cat]
	var n: Dictionary = src.duplicate(true)
	var C := _cards()
	var hint := ""
	var any_open := false
	for c in C:
		any_open = any_open or c.r == 0
	if not any_open and C.size() > 0:
		var full := false
		for q in C:
			full = full or q.r == 2
		for c in C:
			if c.r == 1 and c.lv < 10000:
				hint = "Cấp " + str(c.lv) + " mở " + ("món tiếp theo" if full else "món đầu tiên")
				break
	# Độ đẹp N/mốc kế + thanh tiến độ + Giá bán +x%
	var L = lg()
	var j: int = L.beauty()
	var st: int = L.tier(j)
	var nx = L.C.Q5[st + 1] if st + 1 < L.C.Q5.size() else null
	var D: Dictionary = L.C.Q5[st]
	var ra := 100.0 if nx == null else clampf(float(j - int(D.b)) / maxf(1.0, float(int(nx.b) - int(D.b))) * 100.0, 0.0, 100.0)
	var bar := Snap.find(n, "kcbar")
	if not bar.is_empty() and bar.kids.size() > 0:
		var fi: Dictionary = bar.kids[0]
		fi.r = [fi.r[0], fi.r[1], float(bar.r[2]) * ra / 100.0, fi.r[3]]
	var cap := Snap.find(n, "khcap")
	if not cap.is_empty():
		_tx(cap, "Giá bán +" + str(int(round(L.sell_bonus() * 100))) + "%", null, float(cap.r[0]) + float(cap.r[2]) / 2.0)
	var wo := Snap.find(n, "khworth2")
	if not wo.is_empty() and wo.kids.size() > 0:
		var bb: Dictionary = wo.kids[0]
		_tx(bb, str(j), float(bb.r[0]))
		var tail := ("/" + str(int(nx.b))) if nx != null else ""
		var t2: Dictionary = wo.duplicate(true)
		t2.kids = []
		t2.text = tail
		t2.erase("tr")
		var w2: float = Box.text_w(tail, Css.px(wo.css.get("font-size", "14px")), int(wo.css.get("font-weight", "400")))
		t2.r = [float(bb.r[0]) + float(bb.r[2]), wo.r[1], w2 + 2.0, wo.r[3]]
		t2.css = t2.css.duplicate()
		t2.css["text-align"] = "left"
		wo.text = String(wo.text).substr(0, String(wo.text).find("/")).strip_edges()
		wo.erase("tr")
		wo.css = wo.css.duplicate()
		wo.css["text-align"] = "left"
		Snap.find(n, "kcbox").kids.append(t2)
	var card := Snap.find(n, "khcard")
	var gi := -1
	for q in card.kids.size():
		if String(card.kids[q].cls).split(" ").has("khgrid"):
			gi = q
	if gi >= 0 and gi > 0 and String(card.kids[gi - 1].get("cls", "")).split(" ").has("bhint"):
		card.kids.remove_at(gi - 1)
		gi -= 1
	var g0: Dictionary = card.kids[gi]
	var g: Dictionary
	var pos0 := []          # chỗ từng thẻ (lấy từ bản chụp mục này)
	if hint != "":
		var hn: Dictionary = T.hint.duplicate(true)
		_tx(hn, "🔒 " + hint)
		var dy0: float = float(g0.r[1]) - float(T.grid1.r[1])
		Snap._move(hn, Vector2(0, float(Snap.find(T.pov_qua, "khgrid").r[1]) - float(T.grid1.r[1]) + 0.0) * 0.0)
		card.kids.insert(gi, hn)
		g = T.grid1.duplicate(true)
		gi += 1
		dy0 = 0.0
	else:
		g = g0.duplicate(true)
	for li in g.kids:
		pos0.append(Vector2(float(li.r[0]), float(li.r[1])))
	var li0: Vector2 = pos0[0] if pos0.size() > 0 else Vector2(16, 242)
	var dx: float = (pos0[1].x - pos0[0].x) if pos0.size() > 1 else 104.0
	var dy: float = (pos0[3].y - pos0[0].y) if pos0.size() > 3 else 89.0
	var cells := []
	for q in C.size():
		var c: Dictionary = C[q]
		var p: Vector2 = pos0[q] if q < pos0.size() else li0 + Vector2(dx * (q % 3), dy * (q / 3))
		var tp: Dictionary
		if c.act[0] == "wt":
			tp = T.li_open_x if c.r != 1 else T.li_lock_x
		elif c.r == 1:
			tp = T.li_lock
		elif c.pr[0] == "c" and c.pr[2] != "":
			tp = T.li_unit
		else:
			tp = T.li_open
		var li: Dictionary = Snap.moved(tp, p - Vector2(float(tp.r[0]), float(tp.r[1])))
		var b: Dictionary = li.kids[0]
		b.cls = "khb bcard" + (" full" if c.get("full", false) else "") + (" locked" if c.r == 1 else "")
		if c.get("full", false):
			b.css = b.css.duplicate()
			b.css["opacity"] = "0.55"
		var poor: bool = c.pr[0] == "c" and int(G.g.coins) < int(c.pr[1]) and c.r == 0
		var cx: float = float(b.r[0]) + float(b.r[2]) / 2.0
		for qn in b.kids:
			var qc := String(qn.get("cls", ""))
			if qc == "khnm":
				_tx(qn, c.name, null, cx)
			elif qc.begins_with("khpr"):
				if c.pr[0] == "c":
					qn.cls = "khpr"
					_price(qn, G.fmt_n(int(c.pr[1])), cx, ("/" + String(c.pr[2])) if c.pr[2] != "" else "")
				else:
					qn.cls = "khpr " + String(c.pr[2])
					qn.kids = []
					qn.css = qn.css.duplicate()
					if c.pr[2] == "ok":
						qn.css["color"] = "rgb(46, 139, 87)"
					_tx(qn, String(c.pr[1]), null, cx)
			elif qc == "cnt":
				qn.text = String(c.get("cnt", ""))
		if not c.has("cnt"):
			var keep := []
			for qn in b.kids:
				if String(qn.get("cls", "")) != "cnt":
					keep.append(qn)
			b.kids = keep
		if poor:
			b.cls += " poor"
		cells.append(li)
	g.kids = cells
	card.kids[gi] = g
	var gtop := float(g.r[1])
	var last: float = float(cells[-1].r[1]) + float(cells[-1].r[3]) if cells.size() > 0 else gtop
	sc_max = maxf(0.0, last + 4.0 - (gtop + float(g.r[3])))
	sc = clampf(sc, 0.0, sc_max)
	pids = {}
	pov = U._build(n, pids)
	U.root.add_child(pov)
	U.anchors.append([pov, 0.5, 0.5])
	U._click(pids.get("#pClose"), close, "scale")
	var bk = pids.get(".pbk")
	if bk != null:
		U._stop(bk)
		bk.gui_input.connect(func(e): if U._is_tap_down(e): close())
	var win = pids.get(".pwin")
	if win != null:
		U._stop(win)
	var bgs = pids.get(".bgs")
	if bgs != null:
		var Lb: Array = U._buttons(bgs, [])
		var GN := {"Cây cối": 0, "Công trình": 1, "Trang trí": 2, "Mặt đất": 3}
		for bq in Lb:
			var lb: String = U._label_of(bq)
			var gx := -1
			for nm in GN:
				if lb.contains(nm):
					gx = GN[nm]
			if gx < 0:
				continue
			var gp: Dictionary = GROUPS[gx]
			U._click(bq, func():
				grp_cat[_grp(cat).k] = cat
				cat = grp_cat[gp.k]
				sc = 0.0
				_ps())
	var chips = pids.get(".khchips")
	if chips != null:
		var Lc: Array = U._buttons(chips, [])
		var gp: Dictionary = _grp(cat)
		# thứ tự nút trong bản chụp không theo thứ tự trên màn: khớp theo chữ trên chip
		for bq in Lc:
			var lb: String = U._label_of(bq)
			var cc := ""
			for it in gp.c:
				if lb.contains(String(it[1])):
					cc = it[0]
			if cc == "":
				continue
			U._click(bq, func():
				if cc != cat:
					grp_cat[gp.k] = cc
					cat = cc
					sc = 0.0
					_ps(), "scale94")
	U._click(pids.get(".u2q"), _help, "scale")
	U._click(pids.get(".khst"), _tier_pop, "scale")
	grid = pids.get(".khgrid")
	if grid != null:
		grid._kids.clip_contents = true
		var kb: Array = grid.kids()
		for q in mini(kb.size(), C.size()):
			var li: Control = kb[q]
			lis.append([li, li.r.position])
			var bt = U._q(li, "bcard")
			var c: Dictionary = C[q]
			if bt != null and not c.get("full", false):
				U._click(bt, func(): if not _dragged(): _card(c), "scale94")
			var cv = U._q(li, "", "canvas")
			if cv != null:
				_icon(cv, c.ic, c.r == 1)
		_scroll(sc)

func _card(c: Dictionary) -> void:
	var a: String = c.act[1]
	match c.act[0]:
		"wt": jz(a)
		"pen": wz(a)
		"road": road = a; sel = -1; move_idx = -1; last_k = ""; hov = null; _fl("road")
		"nen": nen = a; sel = -1; move_idx = -1; last_k = ""; hov = null; _fl("nen")
		"mini": mini = a; sel = -1; move_idx = -1; last_k = ""; hov = null; _fl("mini")
		"id": qy(a)
		"soon": G.toast.emit("Sắp có: " + String(lg().Pi[a].n) + ".")

# ------------------------------------------------------------------ hình trong ô thẻ / thanh dưới
func _icon(cv: Control, ic: Array, locked: bool) -> void:
	var kind: String = ic[0]
	if kind in ["road", "nen", "mini"] and not (kind == "mini" and ic[1] != "_x"):
		var d := TileIcon.new()
		d.v = self
		d.kind = kind
		d.k = ic[1]
		d.size = cv.size
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cv.add_child(d)
		return
	var tr := TextureRect.new()
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inset: Vector2 = cv.size * Vector2(3.0 / 64.0, 3.0 / 52.0)   # lg: (w-6)/(h-6) của khung 128x104
	tr.position = inset
	tr.size = cv.size - inset * 2.0
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS   # NTFAST3: dùng mipmap của texture có sẵn
	var m: ShaderMaterial = _gray.duplicate()
	m.set_shader_parameter("g", 1.0 if locked else 0.0)
	m.set_shader_parameter("a", 0.45 if locked else 1.0)
	tr.material = m
	cv.add_child(tr)
	var kb := _ic_key(ic)
	if kb.is_empty():
		return
	var bk: String = kb[0]
	var kk: String = kb[1]
	if kk == "*pen" or not _op_ok(bk, kk):
		U.F.P.load_bundle(bk)
	_ic[tr] = [bk, kk]
	_icon_fill(tr)

func _ic_key(ic: Array) -> Array:   # [gói, khung] của hình thẻ; [] = vẽ bằng code / không có
	var kind: String = ic[0]
	if kind in ["road", "nen"] or (kind == "mini" and ic[1] == "_x"):
		return []
	var bk := ""
	var kk := ""
	match kind:
		"wt":
			bk = "x_" + XV.FOLDER[ic[1]]
			kk = "i_d"
		"pen":   # chuồng: ghép đủ 6 lớp ngày (nền, chuồng + rào sau, rào phải, rào trước) như web Jo vẽ nguyên cái
			bk = "g_congtrinh_chuong_" + String(ic[1])
			kk = "*pen"
		"mini":
			bk = U.F.lang_ve.bundle("mini_" + String(ic[1]))
			kk = U.F.lang_ve.key_for("mini_" + String(ic[1]), 0)
		_:
			bk = U.F.lang_ve.bundle(String(ic[1]))
			kk = U.F.lang_ve.key_for(String(ic[1]), int(ic[2]) if ic.size() > 2 else 0)
	if bk == "":
		return []
	return [bk, kk]

func _op_ok(bk: String, kk: String) -> bool:
	# khung shop có sẵn trong làng (n/op, main.op_pic/op_box): dùng đúng file đó, khỏi cần gói l/g_*
	var m = U.F.main
	return bk.begins_with("g_") and m != null and m.has_method("op_pic") and _box_ok(m.op_box(U.F.lang_ve.op_name(bk, kk)))

static func _box_ok(a) -> bool:
	return a is Array and a.size() >= 4

const PEN_L := ["gd", "bd", "r0d", "r1d", "f0d", "f1d"]
var _pen_tx := {}
func _pen_img(bk: String) -> Image:
	if _pen_tx.has(bk):
		return _pen_tx[bk]
	var m: Dictionary = U.F.P.meta(bk)
	if m.is_empty():
		return null
	var ims := []
	var x0 := 1e9
	var y0 := 1e9
	var x1 := -1e9
	var y1 := -1e9
	for k in PEN_L:
		if not m.has(k):
			continue
		var im: Image = U.F.P.img(bk, k)
		if im == null:
			return null
		var o: Array = m[k]
		var px := Vector2(float(o[0]), float(o[1])) * 9.0
		ims.append([im, px])
		x0 = minf(x0, px.x)
		y0 = minf(y0, px.y)
		x1 = maxf(x1, px.x + im.get_width())
		y1 = maxf(y1, px.y + im.get_height())
	if ims.is_empty():
		return null
	var out := Image.create(int(ceil(x1 - x0)), int(ceil(y1 - y0)), false, Image.FORMAT_RGBA8)
	for q in ims:
		var im2: Image = q[0]
		out.blend_rect(im2, Rect2i(0, 0, im2.get_width(), im2.get_height()), Vector2i(int(round(q[1].x - x0)), int(round(q[1].y - y0))))
	_pen_tx[bk] = out
	return out

# NTFAST3: hình n/op main đã có sẵn texture (có mipmap) -> gắn thẳng texture đó vào thẻ, không đọc ngược GPU, không thu nhỏ CPU.
# Chỉ chuồng (ghép 6 lớp) và hình còn nằm trong gói l/ mới làm ảnh bằng CPU, một lần rồi cất.
var _fit_c := {}
func _fit(img: Image, key: String) -> Texture2D:
	if not _fit_c.has(key):
		var c: Image = img.duplicate()
		if c.get_format() != Image.FORMAT_RGBA8:
			c.convert(Image.FORMAT_RGBA8)
		var ur: Rect2i = c.get_used_rect()   # web lg: vẽ hình đã cắt sát cho vừa khung
		if ur.size.x > 0 and ur.size.y > 0 and ur.size != c.get_size():
			c = c.get_region(ur)
		c.fix_alpha_edges()
		c.generate_mipmaps()
		_fit_c[key] = ImageTexture.create_from_image(c)
	return _fit_c[key]

func _icon_fill(tr: TextureRect) -> void:
	var a: Array = _ic[tr]
	var tx: Texture2D = null
	if a[1] == "*pen":
		if _fit_c.has(a[0]) or U.F.P.has_bundle(a[0]):
			var ip := _pen_img(a[0])
			if ip != null:
				tx = _fit(ip, a[0])
	elif _op_ok(a[0], a[1]):
		tx = U.F.main.op_pic(U.F.lang_ve.op_name(a[0], a[1]))
	else:
		var key: String = a[0] + ":" + a[1]
		if _fit_c.has(key):
			tx = _fit_c[key]
		else:
			var im: Image = U.F.P.img(a[0], a[1])
			if im != null:
				tx = _fit(im, key)
	if tx != null:
		tr.texture = tx
		_ic.erase(tr)

class TileIcon extends Control:   # Mb / Cb / Pb: 2x2 ô đường hoặc nền (hoặc ô nhổ bỏ) vẽ bằng code
	var v
	var kind := ""
	var k := ""
	func _draw() -> void:
		var TL = v.U.F.lang_ve.tiles
		var w := size.x
		var h := size.y
		if kind == "mini":   # Pb "_x": 1 ô cỏ + dấu X
			var l := w / 80.0
			draw_set_transform(Vector2(w / 2.0, h * 0.32), 0.0, Vector2(l, l))
			_dia(0, 0, Color(TL.GRASS[0]))
			draw_line(Vector2(-10, 6), Vector2(10, 26), Color("#d9473a"), 5.0, true)
			draw_line(Vector2(10, 6), Vector2(-10, 26), Color("#d9473a"), 5.0, true)
			return
		var l2 := w / 150.0
		draw_set_transform(Vector2(w / 2.0, h * 0.22), 0.0, Vector2(l2, l2))
		for f in 2:
			for c in 2:
				var s := (c - f) * 32.0
				var hh := (c + f) * 16.0
				if k == "_x":
					_dia(s, hh, Color(TL.GRASS[(c + f) & 1]))
				else:
					_tile(s, hh, c + (7 if kind == "road" else 11), f + (3 if kind == "road" else 5))
		if k == "_x":
			draw_line(Vector2(-18, 14), Vector2(18, 50), Color("#d9473a"), 7.0, true)
			draw_line(Vector2(18, 14), Vector2(-18, 50), Color("#d9473a"), 7.0, true)
	func _dia(a: float, n: float, c: Color) -> void:
		draw_colored_polygon(PackedVector2Array([Vector2(a, n - 0.6), Vector2(a + 32.8, n + 16), Vector2(a, n + 32.6), Vector2(a - 32.8, n + 16)]), c)
	func _tile(s: float, hh: float, e: int, r: int) -> void:
		# vẽ lại bằng lớp đường/nền của làng lên chính Control này
		var TL = v.U.F.lang_ve.tiles
		TL.cv = self
		if kind == "road":
			TL._road(k, s, hh, e, r)
		else:
			TL._nen_at(k, s, hh, e, r, false)
		TL.cv = null

func _price(n: Dictionary, s: String, cx: float, unit := "") -> void:   # h(): "800 [xu]" (+ "/ô") giữa thẻ
	var img := {}
	var it := {}
	for q in n.kids:
		if q.tag == "img":
			img = q
		elif q.tag == "i":
			it = q
	if unit == "" and not it.is_empty():
		n.kids.erase(it)
		it = {}
	var c: Dictionary = n.css
	var fs := Css.px(c.get("font-size", "12px"))
	var fw := int(c.get("font-weight", "400"))
	var w0: float = Box.text_w(String(n.text), fs, fw)
	var gap: float = float(img.r[0]) - float(n.r[0]) - w0 if not img.is_empty() else 0.0
	var w: float = Box.text_w(s, fs, fw)
	var iw: float = float(img.r[2]) if not img.is_empty() else 0.0
	var uw := 0.0
	var ug := 0.0
	if not it.is_empty():
		it.text = unit
		uw = Box.text_w(unit, Css.px(it.css.get("font-size", "12px")), int(it.css.get("font-weight", "400")))
		ug = float(it.r[0]) - (float(img.r[0]) + float(img.r[2]))
	var tot := w + gap + iw + ug + uw
	var x := cx - tot / 2.0
	n.text = s
	n.r = [x, n.r[1], tot, n.r[3]]
	if n.has("tr"):
		n.tr = [x, n.tr[1], w, n.tr[3]]
	if not img.is_empty():
		img.r = [x + w + gap, img.r[1], img.r[2], img.r[3]]
	if not it.is_empty():
		it.r = [x + w + gap + iw + ug, it.r[1], uw, it.r[3]]
		it.erase("tr")

static func _tx(n: Dictionary, s: String, x = null, cx = null) -> void:   # đổi chữ, giữ cỡ; cx: giữa theo cx
	var c: Dictionary = n.css
	var w: float = Box.text_w(s, Css.px(c.get("font-size", "14px")), int(c.get("font-weight", "400")))
	n.text = s
	if cx != null:
		var pl := Css.px(c.get("padding-left", "0px"))
		var pr := Css.px(c.get("padding-right", "0px"))
		n.r = [float(cx) - (w + pl + pr) / 2.0, n.r[1], w + pl + pr, n.r[3]]
		if n.has("tr"):
			n.tr = [float(n.r[0]) + pl, n.tr[1], w, n.tr[3]]
	elif x != null:
		n.r = [float(x), n.r[1], w, n.r[3]]
		n.erase("tr")
	elif n.has("tr"):
		n.erase("tr")

func _scroll(s: float) -> void:
	sc = clampf(s, 0.0, sc_max)
	for e in lis:
		if is_instance_valid(e[0]):
			U._move(e[0], e[1] - Vector2(0, sc))

func _dragged() -> bool:
	return drag != null and drag.moved

func _cat_name(c: String) -> String:
	for q in _grp(c).c:
		if q[0] == c:
			return q[1]
	return ""

func _help() -> void:   # l(): Re.pop "Cách xây: <mục>"
	_pop(T.help.duplicate(true), "Cách xây: " + _cat_name(cat).to_lower(), String(HELP.get(cat, HELP.def)))

func _tier_pop() -> void:   # c(): Hạng làng
	var n: Dictionary = T.tier.duplicate(true)
	var L = lg()
	var K: int = L.beauty()
	var ft: int = L.tier(K)
	var tiers := Snap.find(n, "u2tiers")
	var rows: Array = tiers.kids
	for q in mini(rows.size(), L.C.Q5.size()):
		var r: Dictionary = rows[q]
		var on := q == ft
		var done := q < ft
		var src: Dictionary = rows[0] if on else (rows[1] if rows.size() > 1 else rows[0])
		r.cls = "u2ti" + (" on" if on else "") + (" done" if done else "")
		r.css = src.css.duplicate()
		if done:
			r.css["opacity"] = "0.6"
	var bdn := Snap.find(n, "u2bdn")
	if not bdn.is_empty() and bdn.kids.size() > 0:
		var bb: Dictionary = bdn.kids[0]
		var pct := str(snappedf(minf(0.05, K / 4800.0) * 100.0, 0.1)).replace(".0", "").replace(".", ",")
		_tx(bb, str(K) + " điểm", float(bb.r[0]))
		bdn.text = "Làng bạn:  · giá bán +" + pct + "%"
		bdn.erase("tr")
	_pop(n, "", "")

func _pop(n: Dictionary, title: String, body: String) -> void:
	var pc := Snap.find(n, "u2pc")
	var hb: Dictionary = Snap.find(n, "u2ph")
	if title != "":
		for c in hb.get("kids", []):
			if c.tag == "b":
				c.text = title
				c.erase("tr")
	var bx := Snap.find(n, "u2box")
	if body != "" and not bx.is_empty() and bx.kids.size() > 0:
		var p: Dictionary = bx.kids[0]
		var lh := Css.px(p.css.get("line-height", "21px"))
		var fs: float = U._fsz(p)
		var fw := int(p.css.get("font-weight", "500"))
		var l0 := int(round(float(p.r[3]) / lh))
		var l1: int = U._nlines(body, fs, fw, float(p.r[2]))
		p.text = body
		p.erase("tr")
		var d := (l1 - l0) * lh
		p.r = [p.r[0], p.r[1], p.r[2], float(p.r[3]) + d]
		bx.r = [bx.r[0], bx.r[1], bx.r[2], float(bx.r[3]) + d]
		pc.r = [pc.r[0], pc.r[1], pc.r[2], float(pc.r[3]) + d]
		Snap._move(pc, Vector2(0, (float(n.r[3]) - float(pc.r[3])) / 2.0 - float(pc.r[1])))
	var bk: Dictionary = n.duplicate()
	bk.kids = []
	bk.css = bk.css.duplicate()
	bk.css["z-index"] = "auto"
	bk.css["position"] = "absolute"
	pc.css["position"] = "relative"
	hb.css["border-radius"] = "22px 22px 0px 0px"
	var top := {"tag": "div", "id": "", "cls": "", "z": n.get("z", 1.0), "css": {}, "r": n.r, "kids": [bk, pc]}
	_help_close()
	var pid := {}
	help_b = U._build(top, pid)
	U.root.add_child(help_b)
	U.anchors.append([help_b, 0.5, 0.5])
	U._stop(help_b)
	var bkb = pid.get(".u2pop")
	if bkb != null:
		U._stop(bkb)
		bkb.gui_input.connect(func(e): if U._is_tap_down(e): _help_close())
	U._click(pid.get(".u2px"), _help_close, "scale")
	U._layout()

func _help_close() -> void:
	_free(help_b)
	help_b = null

# ------------------------------------------------------------------ thanh dưới (#buildSheet)
func _info(t: Dictionary) -> String:   # T(K): "⏱ 16 giờ · Đẹp +1 · 1×1 ô"
	var L = lg()
	var j := []
	var ft = L.C.Ei.get(t.id)
	if ft != null:
		j.append("⏱ " + U.fmt_t(float(ft.time)) if U.has_method("fmt_t") else "⏱ " + str(int(ft.time) / 3600) + " giờ")
	j.append("Đẹp +" + str(int(t.b)))
	j.append(str(int(t.fw)) + "×" + str(int(t.fd)) + " ô")
	return " · ".join(j)

func _set_b(bi: Dictionary, s: String) -> void:
	for q in bi.kids:
		if q.tag == "b":
			q.text = s
			q.erase("tr")

func _small(bi: Dictionary, i: int) -> Dictionary:
	var k := 0
	for q in bi.kids:
		if q.tag == "small":
			if k == i:
				return q
			k += 1
	return {}

func _btns(n: Dictionary, L: Array) -> void:   # .btns: flex 1 1 0% (chính 1.4), cách 6, đệm 0 6 mỗi nút
	var bt := Snap.find(n, "btns")
	var src: Array = bt.kids
	var plain: Dictionary = {}
	var prim: Dictionary = {}
	var dang: Dictionary = {}
	for q in src:
		var c := String(q.cls).split(" ")
		if c.has("primary"):
			prim = q
		elif c.has("danger"):
			dang = q
		elif plain.is_empty():
			plain = q
	var all_t := [T.bpl, T.bsel, T.bnen, T.bdf]
	for sn in all_t:
		for q in Snap.find(sn, "btns").kids:
			var c := String(q.cls).split(" ")
			if c.has("primary") and prim.is_empty():
				prim = q
			elif c.has("danger") and dang.is_empty():
				dang = q
			elif not c.has("primary") and not c.has("danger") and plain.is_empty():
				plain = q
	var W: float = float(bt.r[2])
	var gap := 6.0
	if src.size() > 1:
		gap = float(src[1].r[0]) - float(src[0].r[0]) - float(src[0].r[2])
	var pad := 12.0
	var sw := 0.0
	for e in L:
		sw += 1.4 if e.get("k", "") == "primary" else 1.0
	var u := (W - gap * (L.size() - 1) - pad * L.size()) / maxf(1.0, sw)
	var x := float(bt.r[0])
	var out := []
	for e in L:
		var k: String = e.get("k", "")
		var tp: Dictionary = prim if k == "primary" else (dang if k == "danger" else plain)
		var w := pad + u * (1.4 if k == "primary" else 1.0)
		var b: Dictionary = Snap.moved(tp, Vector2(x - float(tp.r[0]), float(bt.r[1]) - float(tp.r[1])))
		b.r = [x, b.r[1], w, b.r[3]]
		b.id = e.get("id", "")
		if e.get("on", false):
			b.css = b.css.duplicate()
			b.css["background-color"] = "rgb(78, 155, 68)"
			b.css["color"] = "rgb(255, 255, 255)"
		if e.get("off", false):
			for sn in [T.bdm]:
				var dis := _fid(sn, "fPut")
				if not dis.is_empty():
					b.css = dis.css.duplicate()
		var label: String = e.t
		if e.has("price"):
			b.text = label
			if not b.has("tr"):
				b.tr = [x, b.r[1], w, b.r[3]]
			_price_btn(b, label + G.fmt_n(int(e.price)))
		else:
			b.kids = []
			b.text = label
			b.erase("tr")
		x += w + gap
		out.append(b)
	bt.kids = out

func _build_sheet() -> void:
	var L = lg()
	var n: Dictionary
	var acts := []      # [Callable] theo thứ tự nút
	var icon = null
	var bi: Dictionary
	if mode == "place":
		var Wt: Dictionary = L.Pi[id]
		n = (T.bpl_mv if move_idx >= 0 else T.bpl).duplicate(true)
		bi = Snap.find(n, "bi")
		_set_b(bi, ("Dời " if move_idx >= 0 else "") + String(Wt.n))
		_tx(_small(bi, 0), _info(Wt), float(_small(bi, 0).r[0]))
		var mv := move_idx >= 0
		var poor: bool = not mv and int(G.g.coins) < int(Wt.cost) and L.pg(id) == 0
		var h := _small(bi, 1)
		var bad: Dictionary = _small(Snap.find(T.bpl_bad, "bi"), 1)
		h.text = why if why != "" else ("Cần " + G.fmt_n(int(Wt.cost)) + " xu" if poor else ("Chạm đất để đổi chỗ, rồi bấm Dời." if mv else "Chạm đất để chọn chỗ."))
		h.erase("tr")
		if why != "" or poor:
			h.css = bad.css.duplicate()
		var B := []
		var pt := "Dời đến đây" if mv else ("Đặt · quà lễ hội" if L.pg(id) > 0 and Wt.get("fest", "") else ("Trồng · cây giống quý" if L.pg(id) > 0 else "Đặt · "))
		var pb := {"t": pt, "k": "primary", "id": "bpPut", "off": why != "" or poor}
		if not mv and L.pg(id) == 0:
			pb.price = int(Wt.cost)
		B.append(pb)
		acts.append(mm_put if why == "" and not poor else Callable())
		if int(Wt.vars) > 1:
			B.append({"t": "Đổi kiểu"})
			acts.append(func(): seed = (seed + 1) % int(L.Pi[id].vars); k5(gx, gy); _ps())
		if Wt.get("rot", ""):
			B.append({"t": "Xoay"})
			acts.append(func(): id = String(L.Pi[id].rot); k5(gx, gy); _ps())
		B.append({"t": "Hủy dời" if mv else "Món khác"})
		acts.append(iz)
		_btns(n, B)
		icon = ["id", id, seed]
	elif mode == "sel":
		var It: Dictionary = L.objs()[sel]
		var Wt: Dictionary = L.Pi[It.id]
		var f := bool(It.get("f", 0))
		n = (T.bsel_f if f else T.bsel).duplicate(true)
		bi = Snap.find(n, "bi")
		_set_b(bi, String(Wt.n))
		_tx(_small(bi, 0), "Có sẵn trên đất" if f else _info(Wt), float(_small(bi, 0).r[0]))
		var s1 := _small(bi, 1)
		_price_small(s1, ("Dọn" if f else "Bán lại") + " được +" + G.fmt_n(L.refund(It)))
		var B := []
		if Wt.get("rot", ""):
			B.append({"t": "Xoay"})
			acts.append(mj)
		B.append({"t": "Di chuyển"})
		acts.append(bm)
		B.append({"t": "Dọn bỏ" if f else "Bán lại", "k": "danger"})
		acts.append(bj)
		B.append({"t": "Xong"})
		acts.append(func(): sel = -1; fac = ""; _fl("pick"))
		_btns(n, B)
		icon = ["id", It.id, int(It.get("seed", 0))]
	elif mode == "road" or mode == "nen" or mode == "mini":
		var src: Dictionary = T.broad if mode == "road" else (T.bnen if mode == "nen" else T.bmini)
		n = src.duplicate(true)
		bi = Snap.find(n, "bi")
		var r: Dictionary = L.Yv[road] if mode == "road" else (L.ug[nen] if mode == "nen" else L.tm[mini])
		var x: bool = r.id == "_x"
		_set_b(bi, String(r.n))
		var s0 := _small(bi, 0)
		if x:
			s0.kids = []
			_tx(s0, "Gỡ đường" if mode == "road" else ("Trả lại cỏ" if mode == "nen" else "Nhổ bỏ"), float(s0.r[0]))
		else:
			_price_small(s0, G.fmt_n(int(r.cost)), " / ô" if mode != "mini" else " / chỗ · 4 chỗ/ô")
		var s1 := _small(bi, 1)
		s1.text = ("Chạm ô đường để gỡ." if x else "Chạm ô để lát, giữ kéo để lát liền.") if mode == "road" else (("Chạm ô đã tô để trả lại cỏ." if x else "Chạm để tô, giữ kéo để tô liền.") if mode == "nen" else ("Chạm khóm hoa cỏ để nhổ." if x else "Chạm để trồng, giữ kéo để trồng liền."))
		s1.erase("tr")
		var B := []
		if mode == "nen":
			B.append({"t": "Cọ 1 ô", "on": nb != 3})
			acts.append(func(): nb = 1; _ps())
			B.append({"t": "Cọ 3×3", "on": nb == 3})
			acts.append(func(): nb = 3; _ps())
		B.append({"t": "Xong"})
		acts.append(func(): sel = -1; fac = ""; _fl("shop"))
		_btns(n, B)
		icon = [mode, road if mode == "road" else (nen if mode == "nen" else mini)]
	elif mode == "fsel" or mode == "fmove":
		var buy: bool = fbuy and fac != "" and not fbuilt(fac)
		var nm := "bds"
		if mode == "fmove":
			nm = ("bpen" if is_pen(fac) else "bdf") if buy else "bdm"
		n = T[nm].duplicate(true)
		bi = Snap.find(n, "bi")
		_set_b(bi, ("Xây " if buy else ("Dời " if mode == "fmove" else "")) + fname(fac))
		if mode == "fmove":
			var put := _fid(n, "fPut")
			if buy:
				_price_btn(put, "Xây ở đây · " + G.fmt_n(fcost(fac)))
			else:
				var ok: Dictionary = _fid(T.bdf, "fPut")
				put.css = ok.css.duplicate() if fwhy == "" else put.css
				put.text = "Dời đến đây"
			var h := _fid(n, "fHint")
			var hs: Dictionary = _fid(T.bdm if fwhy != "" else T.bdf, "fHint")
			h.css = hs.css.duplicate()
			h.cls = "bad" if fwhy != "" else ""
			h.text = fwhy if fwhy != "" else "Chạm hoặc kéo tới chỗ tô xanh, rồi bấm Dời đến đây."
			h.erase("tr")
			acts = [mm if fwhy == "" else Callable(), zy]
			if buy:
				icon = ["pen", fac] if is_pen(fac) else ["wt", String(G.xw.sr[fac].type)]
		else:
			acts = [xb, func(): fac = ""; _fl("pick")]
	else:   # pick: Sửa làng
		n = T.bdp.duplicate(true)
		acts = [func(): sel = -1; fac = ""; _fl("shop")]
	sids = {}
	sheet = U._build(n, sids)
	U.root.add_child(sheet)
	U.anchors.append([sheet, 0.5, 1.0])
	U._stop(sheet)
	U._click(sids.get("#bdClose"), close, "scale")
	var cv = U._q(sheet, "", "canvas")
	if cv != null and icon != null:
		_icon(cv, icon, false)
	var Lb: Array = U._buttons(sids.get(".btns"), []) if sids.get(".btns") != null else []
	for q in mini(Lb.size(), acts.size()):
		if acts[q].is_valid():
			U._click(Lb[q], acts[q])

func _price_small(s: Dictionary, txt: String, unit := "") -> void:   # "Bán lại được +210 [xu]" / "6 [xu] / ô"
	var img := {}
	for q in s.kids:
		if q.tag == "img":
			img = q
	var c: Dictionary = s.css
	var fs := Css.px(c.get("font-size", "12px"))
	var fw := int(c.get("font-weight", "400"))
	var w: float = Box.text_w(txt, fs, fw)
	var gap := 2.5
	if not img.is_empty() and s.has("tr"):
		gap = float(img.r[0]) - (float(s.tr[0]) + Box.text_w(String(s.text).strip_edges(), fs, fw))
	s.text = txt
	s.erase("tr")
	var x0 := float(s.r[0])
	if not img.is_empty():
		img.r = [x0 + w + gap, img.r[1], img.r[2], img.r[3]]
		if unit != "":
			var u: Dictionary = s.duplicate()
			u.kids = []
			u.text = unit
			u.erase("tr")
			u.r = [x0 + w + gap + float(img.r[2]), s.r[1], Box.text_w(unit, fs, fw) + 2.0, s.r[3]]
			s.kids = [img, u]
			s.r = [x0, s.r[1], w + 1.0, s.r[3]]
			return
	s.r = [x0, s.r[1], w + 1.0, s.r[3]]

static func _fid(n: Dictionary, idd: String) -> Dictionary:
	if n.get("id", "") == idd:
		return n
	for k in n.get("kids", []):
		var f := _fid(k, idd)
		if not f.is_empty():
			return f
	return {}

func _price_btn(b: Dictionary, s: String) -> void:   # "Xây ở đây · 300 [xu]" giữa nút
	var img := {}
	for q in b.get("kids", []):
		if q.tag == "img":
			img = q
	var c: Dictionary = b.css
	var fs := Css.px(c.get("font-size", "13px"))
	var fw := int(c.get("font-weight", "700"))
	var w: float = Box.text_w(s, fs, fw)
	var w0: float = Box.text_w(String(b.text), fs, fw)
	var gap := 4.0
	if not img.is_empty() and b.has("tr"):
		gap = float(img.r[0]) - (float(b.tr[0]) + w0)
	gap = clampf(gap, 2.0, 6.0)
	var iw: float = float(img.r[2]) if not img.is_empty() else 0.0
	var tot := w + gap + iw
	var x := float(b.r[0]) + (float(b.r[2]) - tot) / 2.0
	b.text = s
	b.tr = [x, b.tr[1] if b.has("tr") else b.r[1], w, b.tr[3] if b.has("tr") else b.r[3]]
	if not img.is_empty():
		img.r = [x + w + gap, img.r[1], img.r[2], img.r[3]]

# ------------------------------------------------------------------ đặt món (Qy, K5, mM, bM, mj, bj, Iz)
func qy(t: String) -> void:   # Qy: chọn món trong cửa hàng
	var L = lg()
	var a: Dictionary = L.Pi[t]
	if L.cm(a) > 0:
		G.toast.emit("Lên cấp " + str(int(a.lv)) + " mới mua được cây " + String(a.n).to_lower() + ".")
		return
	if int(G.g.coins) < int(a.cost) and L.pg(t) == 0:
		G.toast.emit("Cần " + G.fmt_n(int(a.cost)) + " xu để mua " + String(a.n).to_lower() + ".")
		return
	var c := _view_tile(0.36)
	var l = L.az(a, int(round(c.x - a.fw / 2.0)), int(round(c.y - a.fd / 2.0)), -1)
	if l == null:
		var w := str(a.get("water", ""))
		G.toast.emit("Chưa có mặt nước trống. Hãy mua \"Đào ao\" trước." if w == "only" else ("Cầu cần một ô nước trống. Hãy mua \"Đào ao\" trước." if w == "mixed" else "Không còn chỗ trống hợp lệ, hãy khai hoang thêm đất."))
		return
	id = t
	seed = 0
	move_idx = -1
	sel = -1
	k5(l.x, l.y, false)
	_fl("place")

func k5(x: int, y: int, redraw := true) -> void:   # K5: đổi chỗ đặt + lý do
	gx = x
	gy = y
	var L = lg()
	var w: String = L.mb(L.Pi[id], x, y, move_idx)
	var ch := w != why
	why = w
	_ghost()
	if redraw and ch and mode == "place":
		_ps()

func _vy(w: Vector2) -> void:   # Vy: theo ngón tay (giữa món)
	var a: Dictionary = lg().Pi[id]
	var tl: Vector2 = LN.tile_of(w)
	k5(int(round(tl.x - a.fw / 2.0)), int(round(tl.y - a.fd / 2.0)))

func _zz(w: Vector2) -> bool:   # zz: chạm trúng món đang đặt
	var a: Dictionary = lg().Pi[id]
	var tl: Vector2 = LN.tile_of(w)
	if tl.x >= gx and tl.x < gx + a.fw and tl.y >= gy and tl.y < gy + a.fd:
		return true
	if id == "pond":
		return false
	var V = U.F.lang_ve
	var m: Dictionary = U.F.P.meta(V.bundle(id))
	var k: String = V.key_for(id, seed)
	var r = m.get(k)
	if r == null:
		return false
	var cx: float = gx + a.fw / 2.0
	var cy: float = gy + a.fd / 2.0
	return Rect2(LN.en(cx, cy) + float(r[0]), LN.nn(cx, cy) + float(r[1]), float(r[2]), float(r[3])).has_point(w)

func _vm(t0: Dictionary, x: int, y: int) -> void:   # vM: bụi sao + vòng sáng
	var F = U.F
	var cx: float = x + t0.fw / 2.0
	var cy: float = y + t0.fd / 2.0
	var pal = G.troi.st.get("pal", {}) if G.troi != null else {}
	F.burst(Vector2(LN.en(cx, cy), LN.nn(cx, cy) - 6.0), 14, ["#e3d09b", "#fff3b0", "#a4764d", String(pal.get("leaf2", "#7bbf53"))], 100.0, 2.8, 320.0, 2.4, 0.7, float(t0.fw) * 24.0)

func mm_put() -> void:   # mM: Đặt / Dời đến đây
	var L = lg()
	var t0: Dictionary = L.Pi[id]
	var a: String = L.mb(t0, gx, gy, move_idx)
	if a != "":
		G.toast.emit(a + ".")
		return
	if move_idx >= 0:
		var e: Dictionary = L.objs()[move_idx]
		e.id = id
		e.gx = gx
		e.gy = gy
		e.seed = seed
		_vm(t0, gx, gy)
		G.vib(10)
		sel = move_idx
		move_idx = -1
		L.changed()
		G.toast.emit("Đã dời " + String(t0.n).to_lower() + ".")
		_fl("sel")
		return
	if L.objs().size() >= int(L.C.V5):
		G.toast.emit("Làng đã đủ " + str(int(L.C.V5)) + " món, hãy bán bớt.")
		return
	var r: int = L.pg(id)
	if L.cm(t0) > 0:
		G.toast.emit("Lên cấp " + str(int(t0.lv)) + " mới mua được cây " + String(t0.n).to_lower() + ".")
		return
	if r == 0 and int(G.g.coins) < int(t0.cost):
		G.toast.emit("Cần " + G.fmt_n(int(t0.cost)) + " xu để mua " + String(t0.n).to_lower() + ".")
		return
	if r > 0:
		G.g.lang.cg[id] = int(G.g.lang.cg[id]) - 1
		if int(G.g.lang.cg[id]) <= 0:
			G.g.lang.cg.erase(id)
		G.toast.emit("Đã trồng cây giống quý từ ghe thương hồ.")
	else:
		G.g.coins = int(G.g.coins) - int(t0.cost)
	L.objs().append({"id": id, "gx": gx, "gy": gy, "seed": seed, "t": Time.get_unix_time_from_system() * 1000.0})
	L.changed()
	_vm(t0, gx, gy)
	G.vib(14)
	if int(t0.vars) > 1:
		seed = (seed + 1) % int(t0.vars)
	var nx = L.az(t0, gx, gy, -1)
	if nx != null:
		k5(nx.x, nx.y, false)
	else:
		k5(gx, gy, false)
	_ps()

func bm() -> void:   # bM: nhấc món đã chọn lên để dời
	var L = lg()
	if sel < 0 or sel >= L.objs().size():
		return
	var o: Dictionary = L.objs()[sel]
	if _pond_full(o):
		G.toast.emit("Hãy dọn đồ trên ao trước khi dời ao.")
		return
	move_idx = sel
	id = o.id
	seed = int(o.get("seed", 0))
	L.changed()
	k5(int(o.gx), int(o.gy), false)
	_fl("place")

func _pond_full(o: Dictionary) -> bool:   # a1[gx,gy] có hơn 1 món (ao + đồ trên ao)
	if String(o.id) != "pond":
		return false
	var L = lg()
	L._a1()
	return (L.a1.get(str(int(o.gx)) + "," + str(int(o.gy)), []) as Array).size() > 1

func mj() -> void:   # mj: xoay món đã đặt
	var L = lg()
	var o: Dictionary = L.objs()[sel]
	var a: Dictionary = L.Pi[o.id]
	if not a.get("rot", ""):
		return
	var nt: Dictionary = L.Pi[a.rot]
	var e: String = L.mb(nt, int(o.gx), int(o.gy), sel)
	if e != "":
		G.toast.emit("Không xoay được ở chỗ này: " + e.substr(0, 1).to_lower() + e.substr(1) + ". Hãy dời đi chỗ rộng hơn rồi xoay.")
		return
	o.id = a.rot
	L.changed()
	_vm(nt, int(o.gx), int(o.gy))
	G.vib(8)
	_ps()

func bj() -> void:   # bj: bán lại / dọn bỏ
	var L = lg()
	if sel < 0 or sel >= L.objs().size():
		return
	var a: Dictionary = L.objs()[sel]
	if _pond_full(a):
		G.toast.emit("Hãy dọn đồ trên ao trước khi lấp ao.")
		return
	var n: Dictionary = L.Pi[a.id]
	var e: int = L.refund(a)
	var cx: float = a.gx + n.fw / 2.0
	var cy: float = a.gy + n.fd / 2.0
	L.objs().remove_at(sel)
	G.g.coins = int(G.g.coins) + e
	sel = -1
	L.changed()
	var F = U.F
	var pal = G.troi.st.get("pal", {}) if G.troi != null else {}
	F.burst(Vector2(LN.en(cx, cy), LN.nn(cx, cy, 10.0)), 12, ["#e3d09b", "#fff3b0", String(pal.get("accent", "#dba013"))], 90.0, 2.8, 300.0, 2.2, 0.6, float(n.fw) * 20.0)
	G.vib(10)
	G.float_text.emit(cx, cy, "+" + G.fmt_n(e) + " xu")
	G.toast.emit("Đã bán lại " + String(n.n).to_lower() + ", nhận " + G.fmt_n(e) + " xu.")
	_fl("pick")

func iz() -> void:   # Iz: Hủy dời / Món khác
	if move_idx >= 0:
		sel = move_idx
		move_idx = -1
		lg().changed()
		_fl("sel")
	else:
		sel = -1
		_fl("shop")

func vj(n: int) -> void:   # vj: chọn món đã đặt
	sel = n
	move_idx = -1
	_fl("sel")

# ------------------------------------------------------------------ xưởng + chuồng (jz, Wz, xb, _y, MM, TM, Zy)
func jz(ty: String) -> void:
	var a := ""
	for h in G.xw.N0:
		if a == "" and G.xw.sr[h].type == ty and not G.xw.built(h):
			a = h
	if a == "":
		G.toast.emit("Mỗi loại xưởng chỉ xây được tối đa " + str(XW.I3) + " cái.")
		return
	var s: Dictionary = G.xw.sr[a]
	if G.lv() < int(s.lv):
		G.toast.emit("Lên cấp " + str(int(s.lv)) + " mới xây được " + String(s.name).to_lower() + ".")
		return
	if int(G.g.coins) < int(s.cost):
		G.toast.emit("Cần " + G.fmt_n(int(s.cost)) + " xu để xây " + String(s.name).to_lower() + ".")
		return
	fac = a
	fbuy = true
	sel = -1
	move_idx = -1
	forig = fpos(a)
	fmv = a
	_spots()
	var x8 = lg().M.X8.get(ty)
	if fspots.is_empty() and x8 != null and int(s.n) == 0:
		# chỗ mặc định của xưởng đầu tiên: dời vật cảnh có sẵn đi (web g.mv)
		s.gx = int(x8[0])
		s.gy = int(x8[1])
		for o in lg().SO:
			if o.sk == "" or o.wild or o.ring or G.g.mv.has(o.sk):
				continue
			if o.gx < s.gx + s.fw and o.gx + o.fw > s.gx and o.gy < s.gy + s.fd and o.gy + o.fd > s.gy:
				G.g.mv[o.sk] = 1
		lg().changed()
		_spots()
	if fspots.is_empty():
		_tm()
		fac = ""
		fbuy = false
		_fl("shop")
		G.toast.emit("Làng chưa còn chỗ trống đủ rộng (" + str(int(s.fw)) + "×" + str(int(s.fd)) + " ô). Hãy dọn bớt hoặc khai hoang thêm.")
		return
	_pick_spot(a, 1e9)
	_fl("fmove")

func wz(p: String) -> void:   # Wz: xây chuồng
	var L = lg()
	if L.pen_built(p):
		G.toast.emit("Đã có " + LN.CO[p].to_lower() + " rồi.")
		return
	if L.pen_lv(p) > 0:
		G.toast.emit("Lên cấp " + str(int(L.C.bb[p])) + " mới xây được " + LN.CO[p].to_lower() + ".")
		return
	var a := fcost(p)
	if int(G.g.coins) < a:
		G.toast.emit("Cần " + G.fmt_n(a) + " xu để xây " + LN.CO[p].to_lower() + ".")
		return
	fac = p
	fbuy = true
	sel = -1
	move_idx = -1
	forig = fpos(p)
	fmv = p
	_spots()
	if fspots.is_empty():
		_tm()
		fbuy = false
		fac = ""
		_fl("shop")
		G.toast.emit("Làng chưa còn chỗ trống đủ rộng (2×2 ô). Hãy dọn bớt hoặc khai hoang thêm.")
		return
	var c := _view_tile(0.5)
	var o = null
	var l := 1e9
	var m := fpos(p)
	if cg(p, m.x, m.y) == "":
		l = Vector2(m.x, m.y).distance_to(c)
		if l <= 14.0:
			o = [m.x, m.y]
	if o == null:
		_pick_spot(p, 1e9)
	else:
		_yb(p, o[0], o[1])
		fwhy = ""
	_fl("fmove")

func _pick_spot(a: String, _x) -> void:   # chỗ xanh gần giữa màn nhất; xa hơn 8 ô thì đưa máy quay tới
	var c := _view_tile(0.5)
	var best = null
	var bd := 1e9
	for p in fspots:
		var d := Vector2(p[0], p[1]).distance_to(c)
		if d < bd:
			bd = d
			best = p
	_yb(a, best[0], best[1])
	fwhy = ""
	if bd > 8.0:
		var e := fsize(a)
		_look(best[0] + e.x / 2.0, best[1] + e.y / 2.0)

func xb() -> void:   # xb: nhấc xưởng / chuồng đã xây lên để dời
	if fac == "":
		return
	forig = fpos(fac)
	fmv = fac
	fwhy = ""
	_spots()
	_fl("fmove")

func _spots() -> void:   # mọi chỗ đặt được + ô tô xanh
	fspots = []
	ftiles = {}
	if fac == "":
		return
	var L = lg()
	var e := fsize(fac)
	var B: Array = L.M.B
	var own := {}
	for y in range(int(B[2]), int(B[3])):
		for x in range(int(B[0]), int(B[1])):
			var pc: String = L.fo(x, y)
			if pc == "":
				continue
			if not own.has(pc):
				own[pc] = L.ci(pc)
			if not own[pc]:
				continue
			if cg(fac, x, y) != "":
				continue
			fspots.append([x, y])
			for r in e.x:
				for o in e.y:
					ftiles[str(x + r) + "," + str(y + o)] = 1

func _yb(k: String, x: int, y: int) -> void:   # yb: dời chỗ vẽ
	if is_pen(k):
		G.g.fac[k] = [x, y]
		lg().changed()
		U.F.lang_ve.sync()
	else:
		var s: Dictionary = G.xw.sr[k]
		s.gx = x
		s.gy = y
		U.F._xw_sync()

func _y(w: Vector2, snap: bool) -> void:   # _y: theo ngón tay; chạm thì hút về chỗ xanh gần nhất (<= 3 ô)
	if fac == "" or fmv != fac:
		return
	var e := fsize(fac)
	var tl: Vector2 = LN.tile_of(w)
	var r := Vector2i(int(floor(tl.x - (e.x - 1) / 2.0)), int(floor(tl.y - (e.y - 1) / 2.0)))
	var o := cg(fac, r.x, r.y)
	if o != "" and snap:
		var best = null
		var bd := 1e9
		for p in fspots:
			var d := Vector2(p[0] - r.x, p[1] - r.y).length()
			if d < bd:
				bd = d
				best = p
		if best != null and bd <= 3.0:
			r = Vector2i(best[0], best[1])
			o = ""
	_yb(fac, r.x, r.y)
	if o != fwhy:
		fwhy = o
		_ps()

func _gz(w: Vector2) -> bool:   # Gz: chạm trong nền (nới .3 ô)
	if fac == "":
		return false
	var p := fpos(fac)
	var e := fsize(fac)
	var tl: Vector2 = LN.tile_of(w)
	return tl.x >= p.x - 0.3 and tl.x < p.x + e.x + 0.3 and tl.y >= p.y - 0.3 and tl.y < p.y + e.y + 0.3

func mm() -> void:   # MM: xây / dời đến đây
	if fac == "" or fmv != fac:
		return
	var t0 := fac
	var p := fpos(t0)
	var sz := fsize(t0)
	var n := cg(t0, p.x, p.y)
	if n != "":
		G.toast.emit(n + ". Chọn chỗ tô xanh.")
		return
	var e: bool = fbuy and not fbuilt(t0)
	if e:
		var c := fcost(t0)
		if int(G.g.coins) < c:
			G.toast.emit("Cần " + G.fmt_n(c) + " xu để xây " + fname(t0).to_lower() + ".")
			return
		G.g.coins = int(G.g.coins) - c
		if is_pen(t0):
			G.g.penb[t0] = 1
		else:
			G.xw.w(t0).b = 1
	fmv = ""
	G.g.fac[t0] = [p.x, p.y]
	U.F._xw_sync()
	lg().changed()
	var F = U.F
	var cx: float = p.x + sz.x / 2.0
	var cy: float = p.y + sz.y / 2.0
	var pal = G.troi.st.get("pal", {}) if G.troi != null else {}
	F.burst(Vector2(LN.en(cx, cy), LN.nn(cx, cy) - 6.0), 16, ["#e3d09b", "#fff3b0", "#a4764d", String(pal.get("leaf2", "#7bbf53"))], 100.0, 2.8, 320.0, 2.4, 0.7, float(sz.x) * 24.0)
	G.vib(12)
	ftiles = {}
	fspots = []
	if e:
		fbuy = false
		fac = ""
		G.toast.emit("Đã xây xong " + fname(t0).to_lower() + (". Giờ mua con giống ở Sổ làng › Chợ phiên hoặc chợ nổi sáng sớm." if is_pen(t0) else ". Chạm vào để chọn món làm."))
		_fl("shop")
		return
	G.toast.emit("Đã dời " + fname(t0).to_lower() + ".")
	_fl("fsel")

func _tm() -> void:   # TM: trả về chỗ cũ
	if fac == "" or fmv != fac:
		return
	var k := fac
	fmv = ""
	if is_pen(k) and not fbuilt(k):
		G.g.fac.erase(k)
		lg().changed()
		U.F.lang_ve.sync()
	else:
		_yb(k, forig.x, forig.y)
	U.F._xw_sync()
	ftiles = {}
	fspots = []
	fwhy = ""

func zy() -> void:   # Zy: Hủy / Hủy dời
	var was := fbuy
	_tm()
	fbuy = false
	if was:
		fac = ""
		_fl("shop")
	else:
		_fl("fsel")

# ------------------------------------------------------------------ chạm làng khi đang xây (xj / Fz / Ej / kéo)
func world_down(w: Vector2) -> bool:   # true = ngón tay cầm món / tô liền, làng không kéo
	if mode == "fmove" and _gz(w):
		gdrag = {"p": w, "moved": false}
		return true
	if mode == "place" and _zz(w):
		gdrag = {"p": w, "moved": false}
		return true
	if mode == "road" or mode == "nen" or mode == "mini":
		gdrag = {"p": w, "moved": false, "paint": true}
		last_k = ""
		return true
	return false

func world_drag(w: Vector2, css_d: float) -> bool:
	if gdrag == null:
		return false
	if not gdrag.moved and css_d < 6.0:
		return true
	gdrag.moved = true
	if gdrag.get("paint", false):
		_paint(w, true)
	elif mode == "place":
		_vy(w)
	else:
		_y(w, false)
	return true

func world_up() -> bool:   # true = vừa kéo, bỏ chạm
	if gdrag == null:
		return false
	var mv: bool = gdrag.moved
	gdrag = null
	if mv and mode == "place":
		_ps()
	return mv

func _paint(w: Vector2, quiet: bool) -> bool:   # CM / EM / PM theo ô dưới ngón tay
	var L = lg()
	var tl: Vector2 = LN.tile_of(w)
	var ok := false
	if mode == "mini":
		var q := Vector2i(int(floor(tl.x * 2.0)), int(floor(tl.y * 2.0)))
		hov = q
		var k := str(q.x) + "," + str(q.y)
		if quiet and k == last_k:
			return false
		last_k = k
		ok = L.mini_put(q.x, q.y, mini, quiet)
	else:
		var q := Vector2i(int(floor(tl.x)), int(floor(tl.y)))
		hov = q
		var k := str(q.x) + "," + str(q.y)
		if quiet and k == last_k:
			return false
		last_k = k
		ok = L.road_put(q.x, q.y, road, quiet) if mode == "road" else L.nen_put(q.x, q.y, nen, nb, quiet)
	if ok:
		var c: Vector2 = (Vector2(hov) + Vector2(0.5, 0.5)) / (2.0 if mode == "mini" else 1.0)
		if mode == "mini":
			c = Vector2(hov) / 2.0 + Vector2(0.25, 0.25)
		U.F.burst(Vector2(LN.en(c.x, c.y), LN.nn(c.x, c.y) - 4.0), 5 if mode == "mini" else 8,
			["#a4764d", "#7bbf53"] if (mode == "mini" and mini == "_x") else ["#7bbf53", "#fff3b0", "#f2589a"] if mode == "mini" else ["#e3d09b", "#a4764d"], 50.0, 2.4, 260.0, 1.6, 0.4, 8.0)
		U.F.lang_ve.sync()
		U.F.lang_ve.tiles.queue_redraw()
		G.mark()
	_ov()
	return ok

func fz(w: Vector2):   # Fz: món / vật cảnh / xưởng / chuồng / cây rừng bị chạm -> việc làm
	var L = lg()
	var V = U.F.lang_ve
	var n: int = L.obj_at(w, V.pick_obj)
	if n >= 0:
		return func(): vj(n)
	var e = L.so_pick(w, true, V.pick_so)
	if e != null:
		return func(): _hz(e)
	var r := _sj(w)
	if r != "":
		return func(): fac = r; sel = -1; G.vib(15); _fl("fsel")
	var o = L.so_pick(w, false, V.pick_so)
	if o != null:
		return func(): _hz(o)
	var l = L.hu_pick(w)
	if l != null and l.type == "scn" and L.Pi.has(l.o.id):
		return func(): _rz(l.o)
	return null

func _sj(w: Vector2) -> String:   # Sj: xưởng hoặc chuồng đã xây bị chạm
	var k: String = U.F.xw_at(w)
	if k != "":
		return k
	var tl: Vector2 = LN.tile_of(w)
	for p in lg().C.Di:
		if lg().pen_built(p):
			var q: Vector2i = lg().pen_pos(p)
			if tl.x >= q.x and tl.x < q.x + 2 and tl.y >= q.y and tl.y < q.y + 2:
				return p
	return ""

func _hz(o: Dictionary) -> void:   # Hz: nhận vật cảnh có sẵn rồi dời
	var n: int = lg().take_so(o)
	if n < 0:
		return
	_hide_sync()
	sel = n
	bm()

func _rz(o: Dictionary) -> void:   # Rz
	var n: int = lg().take_hu(o)
	if n < 0:
		return
	_hide_sync()
	sel = n
	bm()

func _hide_sync() -> void:
	U.F._xw_sig = ""
	U.F._xw_sync()

func world_tap(w: Vector2) -> void:   # xj
	match mode:
		"place":
			if _zz(w) and why == "":
				mm_put()
			else:
				_vy(w)
				_ps()
			return
		"fmove":
			if _gz(w) and fwhy == "":
				mm()
				return
			_y(w, true)
			return
		"road", "nen", "mini":
			_paint(w, false)
			return
		"shop":
			return
	var f = fz(w)
	if f != null:
		f.call()
		return
	var s = lg().hu_pick(w)
	if s != null and s.type == "scn":
		_rz(s.o)
		return
	if s != null and s.type == "scnlock":
		var h = U.F.PC.G0.get(s.id)
		if h != null:
			G.toast.emit("Khai hoang " + String(h.name).to_lower() + " trước đã.")
		return
	if mode == "sel" or mode == "fsel":
		sel = -1
		fac = ""
		_fl("pick")

func open_at(w: Vector2) -> bool:   # yj: ngoài Xây dựng, chạm món / vật cảnh / xưởng... không có việc khác -> mở Sửa làng
	if mode != "off":
		return false
	var f = fz(w)
	if f == null:
		return false
	move_idx = -1
	gdrag = null
	f.call()
	if mode != "off":
		G.vib(15)
	return true

func _view_tile(fy: float) -> Vector2:   # ô ở giữa màn (Qy: 36% chiều cao)
	var vp: Vector2 = U.get_viewport().get_visible_rect().size
	return LN.tile_of(U.main.cam + Vector2(vp.x * 0.5, vp.y * fy) / U.main.zoom)

func _look(x: float, y: float) -> void:
	var vp: Vector2 = U.get_viewport().get_visible_rect().size
	U.main.cam = Vector2(LN.en(x, y), LN.nn(x, y)) - vp * 0.5 / U.main.zoom
	if U.main.has_method("_clamp_cam"):
		U.main._clamp_cam()

# ------------------------------------------------------------------ vẽ trên làng (wj ô, Mj khung + mũi tên)
func _ov() -> void:
	var F = U.F
	if ov_lo == null:
		ov_lo = Node2D.new()
		ov_lo.z_index = -3
		ov_lo.draw.connect(_draw_lo)
		F.add_child(ov_lo)
		ov_hi = Node2D.new()
		ov_hi.z_index = 45
		ov_hi.draw.connect(_draw_hi)
		F.add_child(ov_hi)
	var on := mode != "off" and mode != "shop"
	ov_lo.visible = on
	ov_hi.visible = on
	ov_lo.queue_redraw()
	ov_hi.queue_redraw()

static func _dia(x: float, y: float, n: float) -> PackedVector2Array:   # U5
	var e := 4268.0 + (x - y) * 32.0
	var r := 968.0 + (x + y) * 16.0
	return PackedVector2Array([Vector2(e, r + n), Vector2(e + 32 - n * 2, r + 16), Vector2(e, r + 32 - n), Vector2(e - 32 + n * 2, r + 16)])

func _poly(nd: Node2D, q: PackedVector2Array, fill: Color, line: Color, w: float) -> void:
	nd.draw_colored_polygon(q, fill)
	var ql := q.duplicate()
	ql.append(q[0])
	nd.draw_polyline(ql, line, w, true)

func _view_rect() -> Rect2:
	var vp: Vector2 = U.get_viewport().get_visible_rect().size
	return Rect2(U.main.cam - Vector2(40, 30), vp / U.main.zoom + Vector2(80, 60))

func _draw_lo() -> void:
	var L = lg()
	var vr := _view_rect()
	if mode == "place":
		var a: Dictionary = L.Pi[id]
		var t0 := LN.tile_of(vr.position)
		var t1 := LN.tile_of(vr.end)
		var t2 := LN.tile_of(Vector2(vr.end.x, vr.position.y))
		var t3 := LN.tile_of(Vector2(vr.position.x, vr.end.y))
		var x0 := int(floor(minf(minf(t0.x, t1.x), minf(t2.x, t3.x))))
		var x1 := int(ceil(maxf(maxf(t0.x, t1.x), maxf(t2.x, t3.x))))
		var y0 := int(floor(minf(minf(t0.y, t1.y), minf(t2.y, t3.y))))
		var y1 := int(ceil(maxf(maxf(t0.y, t1.y), maxf(t2.y, t3.y))))
		if (x1 - x0) * (y1 - y0) < 20000:
			var fill := Color(1, 1, 1, 0.13)
			var line := Color(1, 1, 1, 0.4)
			var wt := str(a.get("water", ""))
			for e in range(y0, y1 + 1):
				for n in range(x0, x1 + 1):
					var r := 4268.0 + (n - e) * 32.0
					var o := 968.0 + (n + e) * 16.0
					if r + 34 < vr.position.x or r - 34 > vr.end.x or o + 34 < vr.position.y or o - 2 > vr.end.y:
						continue
					var l: String = L.zv(n, e, move_idx)
					if l == "" and a.get("onroad", 0) and L.lz(n, e, move_idx):
						l = "land"
					var c := (l == "water") if wt == "only" else (l != "" if wt == "mixed" else l == "land")
					if c:
						_poly(ov_lo, _dia(n, e, 3.0), fill, line, 1.2)
		var k := why != ""
		for d in int(a.fw):
			for v in int(a.fd):
				_poly(ov_lo, _dia(gx + d, gy + v, 1.0), Color(226 / 255.0, 70 / 255.0, 56 / 255.0, 0.55) if k else (Color(70 / 255.0, 170 / 255.0, 235 / 255.0, 0.7) if id == "pond" else Color(120 / 255.0, 225 / 255.0, 80 / 255.0, 0.5)), Color("#fff1ee") if k else Color.WHITE, 1.6)
	elif mode == "road" and hov != null:
		var M: String = L.xz(hov.x, hov.y, road)
		_poly(ov_lo, _dia(hov.x, hov.y, 1.0), Color(226 / 255.0, 70 / 255.0, 56 / 255.0, 0.45) if M != "" else Color(120 / 255.0, 225 / 255.0, 80 / 255.0, 0.45), Color.WHITE, 1.6)
	elif mode == "nen" and hov != null:
		var o := 1 if nb == 3 else 0
		for y in range(-o, o + 1):
			for x in range(-o, o + 1):
				var j: String = L.nq(hov.x + x, hov.y + y, nen)
				_poly(ov_lo, _dia(hov.x + x, hov.y + y, 1.0), Color(226 / 255.0, 70 / 255.0, 56 / 255.0, 0.38) if j != "" else Color(120 / 255.0, 225 / 255.0, 80 / 255.0, 0.42), Color(1, 1, 1, 0.85), 1.4)
	elif mode == "mini" and hov != null:
		var w: String = L.oq(hov.x, hov.y, mini)
		var E: float = hov.x / 2.0
		var C2: float = hov.y / 2.0
		var q := PackedVector2Array([Vector2(LN.en(E, C2), LN.nn(E, C2)), Vector2(LN.en(E + 0.5, C2), LN.nn(E + 0.5, C2)), Vector2(LN.en(E + 0.5, C2 + 0.5), LN.nn(E + 0.5, C2 + 0.5)), Vector2(LN.en(E, C2 + 0.5), LN.nn(E, C2 + 0.5))])
		_poly(ov_lo, q, Color(226 / 255.0, 70 / 255.0, 56 / 255.0, 0.5) if w != "" else Color(120 / 255.0, 225 / 255.0, 80 / 255.0, 0.5), Color.WHITE, 1.4)
	elif mode == "fmove":
		var fill := Color(120 / 255.0, 225 / 255.0, 80 / 255.0, 0.30)
		var line := Color(1, 1, 1, 0.55)
		for key in ftiles:
			var p: PackedStringArray = String(key).split(",")
			var x := float(p[0])
			var y := float(p[1])
			var e := 4268.0 + (x - y) * 32.0
			var r := 968.0 + (x + y) * 16.0
			if e + 34 < vr.position.x or e - 34 > vr.end.x or r + 34 < vr.position.y or r - 2 > vr.end.y:
				continue
			_poly(ov_lo, _dia(x, y, 3.0), fill, line, 1.2)
	elif mode == "sel" and sel >= 0 and sel < L.objs().size():
		var dt: Dictionary = L.objs()[sel]
		var Wt: Dictionary = L.Pi[dt.id]
		var K := 0.5 if G.motion_off() else 0.5 + 0.5 * sin(t * 5.0)
		var acc := Color(String((G.troi.st.get("pal", {}) if G.troi != null else {}).get("accent", "#dba013")))
		for d in int(Wt.fw):
			for v in int(Wt.fd):
				_poly(ov_lo, _dia(dt.gx + d, dt.gy + v, 1.0), Color(1, 236 / 255.0, 150 / 255.0, 0.28), acc, 2.2 + K * 1.6)

func _draw_hi() -> void:   # Mj: khung ô + mũi tên nhún
	var L = lg()
	var fw := 0
	var fd := 0
	var n := 0
	var e := 0
	var r := false
	var f := Color.WHITE
	var top = null
	var acc := Color(String((G.troi.st.get("pal", {}) if G.troi != null else {}).get("accent", "#dba013")))
	if mode == "place":
		var a: Dictionary = L.Pi[id]
		fw = int(a.fw)
		fd = int(a.fd)
		n = gx
		e = gy
		r = why != ""
		f = Color("#e2432f") if r else Color("#2f9e44")
		top = [id, seed]
	elif mode == "sel" and sel >= 0 and sel < L.objs().size():
		var p: Dictionary = L.objs()[sel]
		var a: Dictionary = L.Pi[p.id]
		fw = int(a.fw)
		fd = int(a.fd)
		n = int(p.gx)
		e = int(p.gy)
		f = acc
		top = [p.id, int(p.get("seed", 0))]
	elif (mode == "fsel" or mode == "fmove") and fac != "":
		var d := fpos(fac)
		var v := fsize(fac)
		fw = v.x
		fd = v.y
		n = d.x
		e = d.y
		r = mode == "fmove" and fwhy != ""
		f = (Color("#e2432f") if fwhy != "" else Color("#2f9e44")) if mode == "fmove" else acc
	else:
		return
	for o in fw:
		for l in fd:
			var q := _dia(n + o, e + l, 1.0)
			q.append(q[0])
			ov_hi.draw_polyline(q, Color(0, 0, 0, 0.35), 4.0, true)
			ov_hi.draw_polyline(q, Color("#ffd9d4") if r else Color.WHITE, 2.0, true)
	var x := LN.en(n + fw / 2.0, e + fd / 2.0)
	var k := LN.nn(n + fw / 2.0, e + fd / 2.0)
	var c := k - 22.0
	if top == null:
		c = k - 70.0
	elif top[0] != "pond":
		var V = U.F.lang_ve
		var m: Dictionary = U.F.P.meta(V.bundle(top[0]))
		var rr = m.get(V.key_for(top[0], top[1]))
		if rr != null:
			c = minf(c, k + float(rr[1]) - 4.0)
	var bob := 0.0 if G.motion_off() else sin(t * 5.0) * 3.0
	var le: float = U.F.sign_le()
	ov_hi.draw_set_transform(Vector2(x, c + bob), 0.0, Vector2(le, le))
	var tri := PackedVector2Array([Vector2(0, 0), Vector2(-9, -14), Vector2(9, -14)])
	ov_hi.draw_colored_polygon(tri, f)
	var tl := tri.duplicate()
	tl.append(tri[0])
	ov_hi.draw_polyline(tl, Color.WHITE, 2.2, true)
	ov_hi.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ------------------------------------------------------------------ mỗi khung, cuộn
func step(dt: float) -> void:
	t += dt
	if ov_hi != null and ov_hi.visible:
		ov_hi.queue_redraw()
		ov_lo.queue_redraw()
	var t0 := Time.get_ticks_usec()
	for tr in _ic.keys():
		if is_instance_valid(tr):
			if Time.get_ticks_usec() - t0 < 4000:
				_icon_fill(tr)
		else:
			_ic.erase(tr)

func input(e: InputEvent) -> void:   # cuộn lưới thẻ trong bảng
	if mode != "shop" or grid == null or not is_instance_valid(grid):
		return
	if e is InputEventMouseButton and e.pressed and (e.button_index == MOUSE_BUTTON_WHEEL_UP or e.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		_scroll(sc + (-40.0 if e.button_index == MOUSE_BUTTON_WHEEL_UP else 40.0))
		return
	if e is InputEventScreenTouch or (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT):
		var pos: Vector2 = e.position / Css.K
		if e.pressed:
			var gr := Rect2(grid.get_global_rect().position / Css.K, grid.r.size)
			drag = {"y0": pos.y, "s0": sc, "moved": false} if gr.has_point(pos) else null
		elif drag != null:
			var d = drag
			U.get_tree().create_timer(0.05).timeout.connect(func(): if drag == d: drag = null)
	elif (e is InputEventScreenDrag or e is InputEventMouseMotion) and drag != null:
		var pos: Vector2 = e.position / Css.K
		var dy: float = pos.y - drag.y0
		if absf(dy) > 6.0:
			drag.moved = true
		if drag.moved:
			_scroll(drag.s0 - dy)
