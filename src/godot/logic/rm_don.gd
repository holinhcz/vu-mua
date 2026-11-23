extends RefCounted
# Vòng nút DỌN (bản 219): chạm cây cỏ hoang, bụi, đá, gốc cây, cây khô, cây rừng (lang.HU) hay đồ có sẵn của làng không có
# việc gì khác (món f: hoa, đá, cây cảnh, cao su...), ô ruộng lúa hoang (bản 514) -> xài chung vòng nút ô ruộng (ui.gd rm_g, bản chụp rmg), chỉ một nút:
#   [Dọn: hình cuốc]   chip: tên vật + "+N xu". Bấm Dọn thì nhân vật đi tới dọn (farm job "scn" / "dobj").

var U          # ui.gd
var G
var key := {}  # {"hu": vật lang.HU} hoặc {"o": món f (g.objs, giữ chính dict để chỉ số đổi vẫn tìm ra)} hoặc {"pd": [x, y]} ô ruộng lúa hoang (bản 514)

func _init(ui) -> void:
	U = ui
	G = ui.G

func open(k: Dictionary) -> void:
	U.close_all()
	key = k
	U.rm_d = k
	U.rm_sig = ""
	U._rm_reset()
	U._set_focus(true)
	U.rm_g.visible = true
	U.rm_r.visible = false
	U.rm_gi[".star"].visible = false
	U.rm_gi[".water"].visible = false
	U._q(U.rm_gi[".fast"], "rmsen").visible = false
	U._move(U.rm_gi[".fast"], U.rm_gi[".star"].r.position)   # một nút: vào giữa
	var b: Control = U.rm_gi[".fast"].kids()[0]
	U._set_svg(b, U._ring("rmw", "#1e90e8", "rgba(150,112,48,.18)", 0.0))
	U._rm_ic(".fast", FileAccess.get_file_as_string("res://ui/svg/kh/pc_cuoc.svg"), true)
	U._txt(U._q(U.rm_gi[".fast"], "", "b"), "")
	sync()
	pos()

func _o() -> Variant:   # món f còn trong làng (null = đã mất)
	if not key.has("o"):
		return null
	for o in G.lang.objs():
		if is_same(o, key.o):
			return o
	return null

func _name() -> String:
	var L = G.lang
	if key.has("pd"):
		return "Lúa hoang"
	if key.has("hu"):
		var id: String = L.XV.get(key.hu.id, key.hu.id)
		return String(L.Pi[id].n) if L.Pi.has(id) else "Bụi cây"
	var o = _o()
	return String(L.Pi[o.id].n) if o != null and L.Pi.has(o.id) else ""

func _xu() -> int:
	var L = G.lang
	if key.has("hu"):
		return int(L.C.Nd.get(key.hu.id, 5))
	var o = _o()
	return L.refund(o) if o != null else 0

func sync() -> void:
	if (key.has("hu") and G.g.clr.has(key.hu.key)) or (key.has("o") and _o() == null) or (key.has("pd") and G.g.clr.has(str(key.pd[0]) + "," + str(key.pd[1]))):
		U.rm_close()
		return
	var rt: Control = U.rm_gi[".rmt"]
	U._txt(rt, _name())
	U._rm_note(rt, "Gặt · +1 lúa" if key.has("pd") else "Dọn · +" + G.fmt_n(_xu()) + " xu")

func pos() -> void:
	var F = U.F
	var M = U.main
	var L = G.lang
	var gx: float
	var gy: float
	var fw := 1.0
	var fd := 1.0
	var top := -60.0
	if key.has("pd"):
		gx = float(key.pd[0])
		gy = float(key.pd[1])
		top = -14.0
	elif key.has("hu"):
		var d: Dictionary = key.hu
		gx = float(d.gx)
		gy = float(d.gy)
		fw = float(d.fw)
		fd = float(d.fd)
		top = float(d.bb[1]) - float(d.sy)
	else:
		var o = _o()
		if o == null:
			return
		var tp: Dictionary = L.Pi[o.id]
		gx = float(o.gx)
		gy = float(o.gy)
		fw = float(tp.fw)
		fd = float(tp.fd)
		top = F.lang_ve.top_of(o)
	var foot := Vector2(F.en(gx + fw / 2.0, gy + fd / 2.0), F.nn(gx + fw / 2.0, gy + fd / 2.0))
	var box: Control = U.rm_g.kids()[0]
	var w = box.r.size.x
	var h = box.r.size.y
	var ra: Vector2 = (foot - M.cam) * M.zoom / U.Css.K
	var x := clampf(ra.x, w / 2.0 + 8.0, U.vw - w / 2.0 - 8.0)
	var y := clampf(ra.y + (top - 6.0) * U.cz(), h + 8.0, U.vh - 8.0)
	U._move(U.rm_g, Vector2(round(x), round(y)))
	U._move(box, Vector2(-w / 2.0, -h))
	var mn := Vector2(INF, INF)
	var mx := -mn
	for p in [[0, 0], [fw, 0], [fw, fd], [0, fd]]:
		var q: Vector2 = (Vector2(F.en(gx + p[0], gy + p[1]), F.nn(gx + p[0], gy + p[1])) - M.cam) * M.zoom
		mn = mn.min(q)
		mx = mx.max(q)
	mn.y = minf(mn.y, (foot.y + top - M.cam.y) * M.zoom)
	U.dim_mat.set_shader_parameter("c", (mn + mx) * 0.5)
	U.dim_mat.set_shader_parameter("r", Vector2((mx.x - mn.x) / 2.0 * 1.3 + 16.0 * U.Css.K, (mx.y - mn.y) / 2.0 * 1.3 + 16.0 * U.Css.K))

func act(k: String) -> void:   # nút Dọn (hoặc chạm chip): nhân vật đi tới dọn
	if k != "fast" and k != "chip":
		return
	var F = U.F
	var kk := key
	U.rm_close()
	if kk.has("pd"):
		F.don_job({"pd": kk.pd})
	elif kk.has("hu"):
		F.don_job({"hu": kk.hu})
	else:
		F.don_job({"o": kk.o})
