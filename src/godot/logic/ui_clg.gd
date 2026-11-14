extends "res://logic/ui_ls.gd"
# CHUYỆN LÀNG (clgOpen / clgRender bản web, Sổ làng › Tin tức trong làng): bảng sổ có tab chung (ui_ls.gd),
# tab Tất cả / Nhà mình / Xóm làng / Thiên tai / Buôn bán; chuyện gom theo ngày, chuyện mới tô nền, việc xen vào có nút.
# Mở xem 1,5 giây thì tính là đã đọc (g.clg.sn). Luật ở w_lang.gd (clg_s, clg_act, clg_act_lb, clg_tick).

var W          # w_lang.gd
var tab := "all"            # CLGV.tab
var _mk := -1.0             # CLGV.mk: đếm 1,5 giây rồi ghi đã đọc
const TABS := [["all", "Tất cả"], ["nha", "Nhà mình"], ["xom", "Xóm làng"], ["tt", "Thiên tai"], ["buon", "Buôn bán"]]

func _init(ui, wl) -> void:
	super(ui)
	W = wl

func open(t := "") -> void:   # clgOpen
	if t != "":
		tab = t
	on = true
	scroll = 0.0
	sig = ""
	_mk = -1.0
	_build()

func step(dt: float) -> void:   # clgRender mỗi giây
	if not on:
		return
	if _mk >= 0.0:
		_mk -= dt
		if _mk < 0.0:
			var o: Dictionary = W.clg_s()
			if o.sn != o.q:
				o.sn = o.q
				G.mark()
	_sig_t -= dt
	if _sig_t > 0.0:
		return
	_sig_t = 1.0
	if _sig() != sig:
		_build()

func _sig() -> String:
	var o: Dictionary = W.clg_s()
	return JSON.stringify([tab, o.q, o.sn, o.l.size(), o.l.slice(0, 40).map(func(r): return r.get("x")), W._vr()])

func _build() -> void:
	sig = _sig()
	var o: Dictionary = W.clg_s()
	if o.sn != o.q and _mk < 0.0:
		_mk = 1.5
	var L := TABS.map(func(x): return [x[0], x[1], false])
	_ls_build(L, tab, _tab_go, _body())

func _tab_go(k: String) -> void:   # data-clg="tab"
	if tab != k:
		tab = k
		scroll = 0.0

func _body() -> Array:   # clgTab
	var o: Dictionary = W.clg_s()
	var day: int = W._vr()
	var L: Array = o.l.filter(func(r): return tab == "all" or r.k == tab)
	if L.is_empty():
		return [_sum2([["Chưa có chuyện gì" + ("" if tab == "all" else " trong mục này") + ". Mỗi ngày trong làng đều có chuyện, ghé lại sau nha.", false]])]
	var out := []
	var cur = null
	var rows := []
	for r in L:
		if cur == null or int(r.d) != int(cur):
			if rows.size():
				out.append(_rows(rows))
				rows = []
			cur = r.d
			var ago := day - int(r.d)
			out.append(_sec2("Hôm nay" if ago <= 0 else ("Hôm qua" if ago == 1 else str(ago) + " ngày trước")))
		var lb: String = W.clg_act_lb(r)
		var sm := []
		if tab == "all":
			sm.append(String(W.CLGK.get(r.k, "")))
		if W._tr(r.get("r")):
			sm.append(String(r.r))
		rows.append({"b": r.t, "s": " · ".join(PackedStringArray(sm)), "right": [lb, true, true, W.clg_act.bind(int(r.q))] if lb != "" else "", "me": int(r.q) > int(o.sn)})
	if rows.size():
		out.append(_rows(rows))
	return out
