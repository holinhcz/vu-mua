extends "res://logic/w_ui_base.gd"
# HỤI, LỄ HỘI (giao diện): phần bảng bản web còn thiếu ở bản Godot. Luật ở w_htx.gd.
#  - bảng "Hụi làng" dựng từ mẫu chụp ở ui_hui.gd.
#  - QT: bảng lễ hội ($r.mode === "hoi": #vlName = tên lễ, #vlBody): ghi chú, danh sách lễ vật (.ws-rec li.rec + .tbar, nút Góp),
#    nút "Nhận lộc lễ hội" (data-fest = claim). Dựng lại khi chữ ký $r.sig đổi (JSON [h4, số trong kho, ngày còn]).
#  - bQ: nút viên lễ hội (.ghepill.festpill, .hurry), chạm -> gu("hoi") = open_fest().
# Dựng bằng Control thường của Godot như w_cho_ui.gd; chỉ dựng lại khi đổi, không vẽ mỗi khung.


var W          # w_htx.gd
# ext: việc của hệ khác (bộ ráp gán)
#   Ai(id) -> Texture2D    (thiếu thì U.item_ic)

var fest: Control = null    # bảng lễ hội ($r.mode === "hoi")
var fest_sig := ""          # $r.sig
const PILL = preload("res://logic/pill.gd")
var pill: Control = null    # k2

func _init(ui, wh) -> void:
	U = ui
	G = ui.G
	W = wh
	W.ui = self
	W.render.connect(_on_render)

func _on_render() -> void:   # kn
	if fest != null:
		sync_fest()

# ------------------------------------------------------------------ khối dựng chung (như w_sys_ui.gd)
func _note(b: String, rest: String) -> Control:   # p.note (<b> đầu dòng + chữ thường)
	var v := VBoxContainer.new()
	if b != "":
		v.add_child(_lbl(b, 12, 700, Color8(0x5a, 0x4a, 0x3a)))
	if rest != "":
		v.add_child(_lbl(rest, 12, 400, Color8(0x8a, 0x7a, 0x6a)))
	return v

func _jobs(btns: Array) -> Control:   # .vl-jobs
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", int(_k(6)))
	f.add_theme_constant_override("v_separation", int(_k(6)))
	for b in btns:
		f.add_child(b)
	return f

func _bar(r: float) -> Control:   # .tbar > i (width %)
	var p := ProgressBar.new()
	p.min_value = 0
	p.max_value = 100
	p.value = r
	p.show_percentage = false
	p.custom_minimum_size = Vector2(0, _k(6))
	return p

static func _clear(n: Control) -> void:
	for c in n.get_children():
		c.queue_free()

# ------------------------------------------------------------------ bảng lễ hội (gu("hoi") -> QT)
func open_fest() -> void:   # gu("hoi")
	close_fest()
	U.close_all()
	fest_sig = ""
	var p := _panel("", close_fest)
	fest = p[0]
	sync_fest()

func close_fest() -> void:   # i1
	if fest != null:
		fest.queue_free()
		fest = null

func sync_fest() -> void:   # QT (gọi mỗi khung khi bảng mở; chỉ dựng lại khi chữ ký đổi)
	if fest == null:
		return
	var t = W.h4()
	if t == null:
		close_fest()   # i1()
		return
	var a: Dictionary = W.tm(t)
	var n: int = int(t.d) - W._vr()
	var have := []
	for o in t.need:
		have.append(W._barn(o[0]))
	var r := JSON.stringify([t, have, n])
	if r == fest_sig:
		return
	fest_sig = r
	(fest.get_meta("name") as Label).text = String(a.n)
	var bd: VBoxContainer = fest.get_meta("body")
	_clear(bd)
	bd.add_child(_note(("Còn " + str(n) + " ngày nữa là tới " + String(a.sh) + ".") if n > 0 else ("Hôm nay là " + String(a.sh) + "!"),
		String(a.d) + " Bà con nhờ góp lễ vật để " + String(a.why) + ". Đủ lễ thì tới ngày hội cả làng nhận lộc."))
	if W._tr(t.get("done")):
		if n > 0:
			bd.add_child(_note("Đã đủ lễ vật.", "Tới ngày hội ghé lại nhận lộc: " + W._sa(W.d_t()) + " xu, gạch nung, nhà nào cũng thân thêm 1 ♥ và cây lớn nhanh suốt ngày hội."))
		elif W._tr(t.get("claim")):
			bd.add_child(_note("", "Đã nhận lộc. Chúc làng mình một mùa an lành, mưa thuận gió hòa!"))
		else:
			bd.add_child(_jobs([_btn("Nhận lộc lễ hội · " + W._sa(W.d_t()) + " xu", true, true, func(): W.v_t())]))
	else:
		for o in t.need:
			var id: String = o[0]
			var q: int = int(o[1])
			var l: int = W._i(t.got.get(id))
			var c := q - l
			var f: int = W._barn(id)
			var s := c <= 0
			var h := HBoxContainer.new()   # li.rec
			h.add_theme_constant_override("separation", int(_k(8)))
			h.add_child(_ic(id, 36))
			var v := VBoxContainer.new()
			v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			v.add_child(_lbl(W._ho(id, q), 13.5, 700, Color8(0x3a, 0x2a, 0x1a)))
			v.add_child(_lbl("Đã góp " + str(l) + "/" + str(q) + (" · đủ" if s else ""), 11.5, 500, Color8(0x8a, 0x6a, 0x48)))
			v.add_child(_bar(W._rnd(minf(1.0, float(l) / q) * 100)))
			h.add_child(v)
			var b := _btn("Đủ" if s else "Góp " + str(mini(c, f)), true, not (s or f <= 0), func(): W.j_t(id))
			b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			h.add_child(b)
			bd.add_child(h)
		if n == 0:
			bd.add_child(_note("", "Hôm nay là ngày hội rồi, góp cho đủ trước nửa đêm vẫn kịp nhận lộc."))

# ------------------------------------------------------------------ nút viên lễ hội (bQ)
func pill_sync(parent: Control) -> void:   # bQ (gọi mỗi khung hoặc mỗi giây; parent = Hs(): hàng nút viên trên HUD)
	var d: Dictionary = W.fest_pill()
	if d.is_empty():
		if pill != null:
			pill.visible = false
		return
	if pill == null:
		pill = PILL.new(U)
		pill.kind = "le"
		pill.pressed.connect(open_fest)
		parent.add_child(pill)
	pill.visible = true
	if pill.text != String(d.text):
		pill.text = String(d.text)
	pill.hurry = bool(d.hurry)   # .hurry
