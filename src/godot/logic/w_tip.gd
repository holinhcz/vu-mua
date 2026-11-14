extends Node
# NTWEB: chữ hiện khi trỏ chuột lên bản đồ (bản web: pointermove chuột -> wo = Cu(x, y), sH -> #tip.tip, nội dung fp(wo)).
# .tip: max-width 220px, padding 7px 10px, bo 10px, nền --fg #1d2a1a, chữ --bg #dbe9cf, 12.5px/1.35; <b> 14px/1.2 đậm, xuống dòng.
# Vị trí: left = clamp(x, w/2 + 4, rộng - w/2 - 4), top = max(cao + 6, y - 14), translate(-50%, -100%).
# Chỉ chuột (web: e.pointerType === "mouse"), chỉ khi Mt.mode == "off" và không đang bấm giữ; cập nhật lại mỗi 0,25 s (mH) khi đứng yên.

const Css = preload("res://ui/css.gd")
const IG := {"duanuoc": "bụi dừa nước", "reed": "bụi lau", "tram": "cây tràm", "ft_saurieng": "cây sầu riêng", "ft_mangcut": "cây măng cụt",
	"ft_chomchom": "cây chôm chôm", "ft_mit": "cây mít", "ft_xoai": "cây xoài", "ft_buoi": "cây bưởi", "caosu": "cây cao su", "dieu": "cây điều",
	"mango": "cây xoài", "jackfruit": "cây mít", "coconut": "cây dừa", "banana": "cây chuối", "areca": "cây cau", "bamboo": "bụi tre",
	"haystack": "đống rơm", "house": "nhà cũ", "hut": "nhà tranh cũ", "boat": "thuyền cũ", "tallgrass": "cỏ", "wildbush": "bụi cây", "hibiscus": "bụi dâm bụt"}   # ig

var G
var U
var box: PanelContainer = null
var lb: RichTextLabel = null
var mp := Vector2(-1, -1)      # f3: vị trí chuột cuối (màn hình)
var acc := 0.0

func _init(game, ui) -> void:
	G = game
	U = ui

func _k() -> float:
	return Css.K

func _build() -> void:
	box = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#1d2a1a")
	sb.set_corner_radius_all(int(round(10 * _k())))
	sb.content_margin_left = 10 * _k()
	sb.content_margin_right = 10 * _k()
	sb.content_margin_top = 7 * _k()
	sb.content_margin_bottom = 7 * _k()
	box.add_theme_stylebox_override("panel", sb)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lb = RichTextLabel.new()
	lb.bbcode_enabled = true
	lb.fit_content = true
	lb.scroll_active = false
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lb.add_theme_font_override("normal_font", Css.font(700))
	lb.add_theme_font_override("bold_font", Css.font(800))
	lb.add_theme_font_size_override("normal_font_size", int(round(12.5 * _k())))
	lb.add_theme_font_size_override("bold_font_size", int(round(14 * _k())))
	lb.add_theme_color_override("default_color", Color("#dbe9cf"))
	lb.add_theme_constant_override("line_separation", int(round(2 * _k())))
	box.add_child(lb)
	box.visible = false
	U.root.add_child(box)

func hide_tip() -> void:
	if box != null:
		box.visible = false

func _input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		mp = e.position
		if e.button_mask != 0:
			hide_tip()
			return
		_want = true   # chọn lại ở _process, tối đa ~12 lần/giây (chuột rê bắn rất nhiều sự kiện)
	elif e is InputEventMouseButton and e.pressed:
		hide_tip()
	elif e is InputEventScreenTouch:
		mp = Vector2(-1, -1)
		hide_tip()

var _want := false
var _wt := 0.0
func _process(dt: float) -> void:
	acc += dt
	_wt -= dt
	if _want and _wt <= 0.0:
		_want = false
		_wt = 0.08
		acc = 0.0
		_show()
	elif acc >= 0.25 and box != null and box.visible:   # mH: đứng yên vẫn cập nhật (% lớn, nước)
		acc = 0.0
		_show()

func _show() -> void:
	if box == null:
		_build()
	var F = G.lang.F if G.lang != null else null
	if F == null or mp.x < 0 or F.main == null:
		hide_tip()
		return
	if U.bdp != null and U.bdp.active():   # Mt.mode !== "off"
		hide_tip()
		return
	var hc = U.get_viewport().gui_get_hovered_control()
	if hc != null and hc != U.root and hc != box and hc != lb:   # chuột trên bảng / nút giao diện, không phải #stage
		hide_tip()
		return
	var w: Vector2 = F.screen_to_world(mp)
	var t := fp(_cu(F, w))
	if t == "":
		hide_tip()
		return
	lb.text = t
	var vw: float = U.get_viewport().get_visible_rect().size.x
	box.custom_minimum_size = Vector2.ZERO
	box.size = Vector2.ZERO
	lb.custom_minimum_size = Vector2.ZERO
	var mw := 220.0 * _k()
	var tw: float = lb.get_theme_font("normal_font").get_multiline_string_size(t.replace("[b]", "").replace("[/b]", "\n"), HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(14 * _k()))).x
	lb.custom_minimum_size.x = minf(mw - 20.0 * _k(), tw + 2.0)
	box.visible = true
	box.reset_size()
	var n: float = box.size.x
	var x := maxf(n / 2.0 + 4.0, minf(vw - n / 2.0 - 4.0, mp.x))
	var y := maxf(box.size.y + 6.0, mp.y - 14.0)
	box.position = Vector2(x - n / 2.0, y - box.size.y)

# ------------------------------------------------------------------ Cu / cH: thứ dưới chuột (cùng cách chọn với chạm: farm.pick)
func _cu(F, w: Vector2) -> Dictionary:
	return F.pick(w)

# ------------------------------------------------------------------ fp: chữ của từng loại (bản web, nguyên văn)
func fp(t: Dictionary) -> String:   # fp
	var ty := String(t.get("type", ""))
	if ty == "":
		return ""
	var WR = G.w_all.WR if G.w_all != null else null
	if ty == "ray":   # mô-đun ray tip
		var th := int(G.g.ray.get("th", 0))
		return "[b]Ruộng bị rầy nâu[/b]\nCây đang teo dần. Chạm để phun thuốc (sạch luôn mấy ô quanh đó). Còn " + str(th) + " lần phun" + ("" if th else ", tự mua bình 150 xu") + "."
	if ty == "tree":
		if WR == null:
			return ""
		var o = WR.ql(int(t.i))
		if o == null:
			return ""
		var l: Dictionary = WR._ei()[o.id]
		var s := "[b]" + String(G.lang.Pi[o.id].n) + "[/b]\n"
		if WR.wc(o):
			s += "Trái đã chín, chạm để hái."
		elif float(o.get("fw", 0.0)) > 0.0:
			s += "Đang ra trái " + str(int(round(float(o.fp) / float(l.time) * 100.0))) + "%."
		else:
			s += "Đất khô, chạm để tưới."
		if WR.ib(int(t.i)):
			s += " Có ong thụ phấn: thêm 1 trái mỗi lần hái."
		return s
	if G.w_all != null and G.w_all.WL != null and G.w_all.WL.has_method("vq"):   # Vq: nhà dân, người làng...
		var c = G.w_all.WL.vq(t)
		if c != null and String(c) != "":
			return String(c).replace("<b>", "[b]").replace("</b>", "[/b]\n")
	if ty == "scn":
		var oid := String(t.o.get("id", ""))
		var nm := String(IG.get(oid, IG.get(oid.trim_suffix("nho").trim_suffix("2"), "cảnh vật")))
		return "[b]" + nm.substr(0, 1).to_upper() + nm.substr(1) + "[/b]\nChạm để dọn, được " + str(int(G.lang.C.Nd.get(oid, 5))) + " xu."
	if ty == "sap":
		return "[b]Sạp bán hàng[/b]\nBày hàng trong kho bán cho khách. Chạm để xem và nâng sạp."
	if ty == "khohang":
		return "[b]Kho hàng[/b]\nHàng trong kho bày trên kệ. Chạm để mở kho."
	if ty == "paddy":
		return "[b]Ruộng lúa[/b]\nChạm để gặt, được 1 lúa vào kho."
	if ty == "scnlock":
		return "[b]Đất chưa khai hoang[/b]\nMua khu này rồi mới dọn được."
	if ty == "plot":
		var i := int(t.i)
		var a: Dictionary = G.g.plots[i]
		if not a.get("u", false):
			return "[b]Ô đất chưa mở[/b]\nChạm để mở với " + _sa(G.open_cost()) + " xu."
		if a.get("c") == null:
			return "[b]Ô đất trống[/b]\nChạm để chọn giống gieo." + _cq(i)
		var f: Dictionary = G.crop(String(a.c))
		if G.ripe(a):
			return "[b]" + String(f.name) + " đã chín[/b]\nChạm để thu hoạch."
		return "[b]" + String(f.name) + "[/b]\nLớn " + str(int(round(float(a.g) / float(f.time) * 100.0))) + "%, nước " + str(int(round(minf(1.0, float(a.w) / G.water_hold(a)) * 100.0))) + "%." + (" Đất khô, tưới để lớn nhanh hơn 10%." if float(a.w) <= 0.0 else " Chạm để tưới thêm.") + _cq(i)
	if ty == "parcel":
		var F = G.lang.F
		var s2: Dictionary = F.PC.G0[t.id]
		if F.pc_next(String(t.id)):
			if F.pc_lv(String(t.id)) > 0:
				return "[b]Khai hoang " + String(s2.name).to_lower() + "[/b]\nLên cấp " + str(F.pc_lv(String(t.id))) + " mới mở được. " + String(s2.get("desc", ""))
			return "[b]Khai hoang " + String(s2.name).to_lower() + "[/b]\n" + _sa(int(s2.cost)) + " xu. " + String(s2.get("desc", ""))
		return "[b]Đất hoang[/b]\nHãy khai hoang khu đất bên cạnh trước để mở khu này."
	if ty == "animal":
		var V = G.vn
		var n: Dictionary = V.Q[t.k]
		var P: Array = G.g.pens.get(t.k, [])
		if int(t.j) >= P.size():
			return ""
		var e: Dictionary = P[int(t.j)]
		if float(e.p) >= float(n.time):
			return "[b]" + String(n.name) + "[/b]\nCó " + G.item_name(String(n.make)) + ". Chạm để thu."
		if float(e.p) < 0.0:
			return "[b]" + String(n.name) + " đang đói[/b]\nChạm để cho ăn 1 " + G.item_name(String(n.feed)) + " (kho còn " + str(int(G.g.barn.get(n.feed, 0))) + ")."
		return "[b]" + String(n.name) + "[/b]\nĐang làm ra " + G.item_name(String(n.make)) + ": " + str(int(round(float(e.p) / float(n.time) * 100.0))) + "%."
	if ty == "work":
		var k := String(t.k)
		var h: Dictionary = G.xw.sr[k]
		var p: Dictionary = G.g.work[k]
		if not p.get("b", false):
			return "[b]Xây " + String(h.name).to_lower() + "[/b]\n" + _sa(int(h.cost)) + " xu. " + String(h.get("blurb", ""))
		var d := " Gần kho hàng: làm nhanh hơn 25%." if float(G.xw.mc(k)) > 1.0 else ""
		var v := _vg(k)
		if v != "":
			d += " " + v + " đang làm ở đây."
		if G.xw.df(k) > 0:
			return "[b]" + String(h.name) + "[/b]\nCó hàng đã xong. Chạm để mở xưởng thu hàng." + d
		if (p.q as Array).size() > 0:
			return "[b]" + String(h.name) + "[/b]\nĐang làm " + G.item_name(String(p.q[0])).to_lower() + ". Chạm để xem hàng đợi." + d
		return "[b]" + String(h.name) + "[/b]\n" + String(h.get("blurb", "")) + " Chạm để chọn món." + d
	return ""

func _vg(t: String) -> String:   # vg: người nhà đang làm ở xưởng t
	var a = G.g.get("lang")
	if not (a is Dictionary) or not (a.get("fam") is Dictionary):
		return ""
	for n in a.fam:
		if String(a.fam[n].get("job", "")) == t:
			return String(a.fam[n].get("n", ""))
	return ""

func _cq(t: int) -> String:   # Cq
	var a := ""
	if G.drain(t) < 1.0:
		a += " Gần nước: lâu khô hơn 40%."
	var WR = G.w_all.WR if G.w_all != null else null
	if WR != null and WR.fence(t):
		a += " Có rào: gà vịt không vào phá."
	var WL = G.w_all.WL if G.w_all != null else null
	if WL != null:
		var n: String = WL.ed(t)
		if n != "":
			a += " " + n + " đang chăm ô này."
	return a

func _sa(n: int) -> String:   # Sa: 12.345
	return G.fmt_n(float(n))
