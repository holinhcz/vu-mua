extends "res://logic/ui_bang.gd"
# THẺ TRÁI KHỦNG (klShow bản web): hộp nổi khung tre .rbox.klbox: hình món, "Trái bắp khủng", mộc "Kỷ lục mới", hạng,
# cân nhảy số 1,2 giây rồi dừng, bảng thông số (ul.klinfo), nút Cất vô tủ / Xem tủ kỷ lục. Nhiều trái thì hiện lần lượt.
# Mẫu: ui/snap/kl_card.json. Luật ở w_ca.gd (klq, kl_info, kl_kg).

var WC2        # w_ca.gd
var KC := {}
var f = null               # trái đang hiện
var t0 := 0.0
var _last := -1.0

func _init(ui, wca) -> void:
	super(ui)
	WC2 = wca
	KC = Snap.load_snap("kl_card")["#pov"][0]

func show_next() -> void:   # klShow
	if on:
		return
	if WC2.klq.is_empty():
		return
	f = WC2.klq.pop_front()
	on = true
	t0 = 0.0
	_last = -1.0
	G.vib([12, 40, 12, 40, 30] if f.rec else [10, 30, 10])
	_draw_card(0.0)

func step(dt: float) -> void:   # cân nhảy số (ease-out bậc 3)
	if not on or f == null:
		return
	t0 += dt
	var a := minf(1.0, t0 / 1.2)
	if a >= 1.0 and _last >= 1.0:
		return
	if a < 1.0 and t0 - _last < 0.08 and _last >= 0.0:
		return
	_last = t0 if a < 1.0 else 1.0
	_draw_card(1.0 - pow(1.0 - a, 3.0))

func _draw_card(e: float) -> void:
	var n := _cl(KC)
	var rb := _find(n, "rbox")
	var D: Array = WC2.kld().get(f.id, ["g", 1, 1, "Trái", "Cỡ", 1, 0])
	var ic := _find(rb, "klic")
	_ic(ic, String(f.id))
	var nm := _find(rb, "klnm")
	var cx := float(_find(rb, "klcard").r[0]) + float(_find(rb, "klcard").r[2]) * 0.5
	_ctext(nm, String(D[3]) + " " + WC2.kl_name(String(f.id)).to_lower() + " khủng", cx)
	var card := _find(rb, "klcard")
	if not f.rec:
		card.kids = card.kids.filter(func(k): return String(k.get("cls", "")) != "klmoc")
	var hh := _find(rb, "klh")
	_ctext(hh, WC2.KLHANG[int(f.h)], cx, true)
	var w := _find(rb, "klw")
	_ctext(w, WC2.kl_kg(float(f.g) * e, String(f.id)), cx)
	# ul.klinfo
	var ul := _find(rb, "klinfo")
	var li0: Dictionary = ul.kids[0]
	var y := float(ul.r[1])
	var out := []
	for r in WC2.kl_info(f):
		var li := _cl(li0)
		_mv(li, float(li0.r[0]), y)
		var sp: Dictionary = li.kids[0]
		var b: Dictionary = li.kids[1]
		var sw := _tw(sp, String(r[0]))
		sp.text = r[0]
		sp.r[2] = sw
		sp.tr = sp.r.duplicate()
		var bw := _tw(b, String(r[1]))
		b.text = r[1]
		b.r = [float(li.r[0]) + float(li.r[2]) - bw, b.r[1], bw, b.r[3]]
		b.tr = b.r.duplicate()
		out.append(li)
		y += 15.65
	var dy := (y - 15.65 + 12.7) - (float(ul.r[1]) + float(ul.r[3]))
	ul.kids = out
	ul.r[3] = float(ul.r[3]) + dy
	card.r[3] = float(card.r[3]) + dy
	var jb := _find(rb, "vl-jobs")
	Snap._move(jb, Vector2(0, dy))
	jb.kids[0].act = _ok
	jb.kids[1].act = _tu
	rb.r[3] = float(rb.r[3]) + dy
	Snap._move(rb, Vector2(0, (610.0 - float(rb.r[3])) * 0.5 - float(rb.r[1])))
	var old := box
	ids = {}
	box = U._build(n, ids)
	U.root.add_child(box)
	if old != null:
		U.anchors.erase(U._anchor_of(old))
		old.queue_free()
	U.anchors.append([box, 0.5, 0.5])
	U._click(ids.get(".tre-x"), _ok, "scale")
	var ov = ids.get(".raceov")
	if ov != null:
		U._stop(ov)
		ov.gui_input.connect(func(ev): if U._is_tap_down(ev) and not ids[".rbox"].get_global_rect().has_point(ov.global_position + ev.position): _ok())
	if ids.get(".rbox") != null:
		U._stop(ids[".rbox"])
	_wire(box)
	U._layout()

func _ctext(n: Dictionary, s: String, cx: float, pad := false) -> void:   # chữ giữa thẻ (hộp co theo chữ)
	var tw := _tw(n, s)
	var pl := _px(n, "padding-left") if pad else 0.0
	n.text = s
	n.r = [cx - tw * 0.5 - pl, n.r[1], tw + pl * 2.0, n.r[3]]
	n.tr = [cx - tw * 0.5, n.tr[1], tw, n.tr[3]]

func _ok() -> void:   # Cất vô tủ / đóng: trái kế
	close()
	f = null
	if WC2.klq.size():
		G.get_tree().create_timer(0.25).timeout.connect(show_next)

func _tu() -> void:   # Xem tủ kỷ lục
	WC2.klq.clear()
	close()
	f = null
	U.kl_open("tu")
