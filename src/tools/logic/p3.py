p='/tmp/claude-0/-home-user/ec30a73d-a632-5817-a52f-4d1a59b285b5/scratchpad/proj/logic/ui.gd'; s=open(p).read()
def rep(old,new,cnt=1):
    global s
    assert s.count(old)==cnt, (s.count(old), old[:70])
    s=s.replace(old,new)
rep('''var kh_grid0 := Rect2()
var kh_grid: Control = null
var kh_sel := ""''','''var kh_grid0 := Rect2()
var kh_grid0s := Rect2()     # lưới khi đang chọn một món (khDet mở, lưới thấp lại)
var kh_tpl_sel := {}         # thẻ đang chọn (viền xanh, nền xanh nhạt)
var kh_det: Control = null   # #khDet: món đang chọn, giá, số lượng, nút bán
var kh_q := 1                # vi.q
var kh_sel := ""''')
rep('''	for nm in ["kho", "kho2", "kho3"]:
		var d: Dictionary = Snap.load_snap(nm)
		var n: Dictionary = d["#pov"][0]
		if nm == "kho":''','''	for nm in ["kho", "kho2", "kho3", "kho_sel"]:
		var d: Dictionary = Snap.load_snap(nm)
		var n: Dictionary = d["#pov"][0]
		if nm == "kho_sel":
			var g2 := Snap.find(n, "khgrid")
			for li in g2.get("kids", []):
				if String(li.cls).split(" ").has("sel"):
					kh_tpl_sel = li
			kh_grid0s = Rect2(g2.r[0], g2.r[1], g2.r[2], g2.r[3])
			g2.kids = []
		if nm == "kho":''')
rep('''func _kho_tab(j: int) -> void:
	kho_tab = j
	for q in kho_roots.size():
		kho_roots[q].visible = kho_on and q == j''','''func _kho_tab(j: int) -> void:
	if j != kho_tab:
		kh_sel = ""
	kho_tab = j
	_kho_show()

func _kho_show() -> void:
	# Hàng hóa có 2 dáng: chưa chọn (nút Bán hết) / đang chọn một món (khDet)
	var vis := kho_tab if not (kho_tab == 0 and kh_sel != "") else 3
	for q in kho_roots.size():
		kho_roots[q].visible = kho_on and q == vis''')
rep('''	var ids: Dictionary = kho_ids[0]
	var e := _kho_items()''','''	if kh_sel != "" and int(G.g.barn.get(kh_sel, 0)) <= 0:
		kh_sel = ""
	var selm := kh_sel != ""
	if kho_roots[3].visible != selm or kho_roots[0].visible == selm:
		_kho_show()
	var ids: Dictionary = kho_ids[3] if selm else kho_ids[0]
	var grid: Control = ids.get(".khgrid")
	var grid0 := kh_grid0s if selm else kh_grid0
	var e := _kho_items()''')
rep('''	var sig := kh_f + kh_sort + kh_sel + str(tot_n)''','''	var sig := kh_f + kh_sort + kh_sel + str(kh_q) + "|" + str(G.price(kh_sel) if selm else 0) + "|" + str(tot_n)''')
rep('''	for k in kh_grid.kids():
		k.queue_free()
	var o := kh_grid0.position''','''	for g0 in [kho_ids[0].get(".khgrid"), kho_ids[3].get(".khgrid")]:
		for k in g0.kids():
			k.queue_free()
	var o := grid0.position''')
rep('''		var hx: float = G.hot_x(t)
		var tp: Dictionary = kh_tpl_hot if hx > 1.0 else kh_tpl''','''		var hx: float = G.hot_x(t)
		var tp: Dictionary = kh_tpl_hot if hx > 1.0 else kh_tpl
		if t == kh_sel and not kh_tpl_sel.is_empty():
			tp = kh_tpl_sel.duplicate(true)
			if hx <= 1.0:
				tp.erase("::before")''')
rep('''		kh_grid.add(cb)''','''		grid.add(cb)''')
rep('''			_click(btn, func(): kh_sel = "" if kh_sel == tt else tt; kh_sig = ""; _kho_sync(), "scale94")
			if kh_sel == t:
				btn.style(Snap.css_of(btn.get_meta("snap")) + "border-top:2px solid rgb(78,155,68);border-right:2px solid rgb(78,155,68);border-bottom:2px solid rgb(78,155,68);border-left:2px solid rgb(78,155,68);", btn.z)
				btn.place(btn.r)''','''			_click(btn, func(): kh_sel = "" if kh_sel == tt else tt; kh_q = 1; kh_sig = ""; _kho_sync(), "scale94")''')
rep('''	kh_grid.place(Rect2(kh_grid.r.position, Vector2(kh_grid.r.size.x, maxf(kh_grid0.size.y, rows * dy + 8.0))))''','''	grid.place(Rect2(grid.r.position, Vector2(grid.r.size.x, maxf(grid0.size.y, rows * dy + 8.0))))
	if selm:
		_det_sync()''')
rep('''# Vật liệu
var kh_vl := ""''', open('/tmp/claude-0/-home-user/ec30a73d-a632-5817-a52f-4d1a59b285b5/scratchpad/tools/det.gd.txt').read() + '''
# Vật liệu
var kh_vl := ""''')
open(p,'w').write(s)
print('ok')
