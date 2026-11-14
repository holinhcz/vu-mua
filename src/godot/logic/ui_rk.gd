extends "res://logic/ui_bang.gd"
# BẢNG XẾP HẠNG LÀNG (Qk / S4 bản web, Sổ làng › Xếp hạng): hộp nổi khung tre, hàng tab 5 bảng (Làng đẹp, Giàu có, Cấp độ,
# Quán ngon, Chuyên cần, kéo ngang được) và thân. So với làng bạn bè cần chơi online: bản Godot chưa có nên hiện như web lúc
# chưa đăng nhập (u2empty "Cần mở game từ đường link chia sẻ"). Mẫu: ui/snap/rk.json.

var RB := {}
var cat := "dep"            # yl.cat
const CATS := [["dep", "Làng đẹp"], ["xu", "Giàu có"], ["lv", "Cấp độ"], ["sao", "Quán ngon"], ["sk", "Chuyên cần"]]

func _init(ui) -> void:
	super(ui)
	RB = Snap.load_snap("rk")["#pov"][0]

func open() -> void:   # Qk
	on = true
	_build()

func _build() -> void:
	var n := _cl(RB)
	var ts := _find(n, "tre-ts")
	var on_t: Dictionary = ts.kids[0]
	var off_t: Dictionary = ts.kids[1]
	var x := float(on_t.r[0])
	var out := []
	var onr := [0.0, 0.0]
	for c0 in CATS:
		var a: bool = c0[0] == cat
		var c := _cl(on_t if a else off_t)
		var pl := _px(c, "padding-left")
		var tw := _tw(c, String(c0[1]))
		var w := tw + pl * 2.0
		_mv(c, x, float(c.r[1]))
		c.r[2] = w
		var af: Dictionary = c.get("::after", {})
		if af.has("w"):
			af.w = str(w / _z(c)) + "px"
		c.text = c0[1]
		c.tr = [x + pl, c.tr[1], tw, c.tr[3]]
		c.act = _cat_go.bind(String(c0[0]))
		if a:
			onr = [x, x + w]
		out.append(c)
		x += w + 4.5
	_chips_keep(out, onr, x - 4.5, float(ts.r[0]), float(ts.r[0]) + float(ts.r[2]))
	ts.kids = out
	var old := box
	ids = {}
	box = U._build(n, ids)
	U.root.add_child(box)
	if old != null:
		U.anchors.erase(U._anchor_of(old))
		old.queue_free()
	U.anchors.append([box, 0.5, 0.5])
	var tr = ids.get(".tre-ts")
	if tr != null:
		tr._kids.clip_contents = true
	U._click(ids.get(".tre-x"), close, "scale")
	var ov = ids.get(".raceov")
	if ov != null:
		U._stop(ov)
		ov.gui_input.connect(func(e): if U._is_tap_down(e) and not ids[".rbox"].get_global_rect().has_point(ov.global_position + e.position): close())
	if ids.get(".rbox") != null:
		U._stop(ids[".rbox"])
	_wire(box)
	U._layout()

func _cat_go(k: String) -> void:   # data-rkc
	cat = k

func input(e: InputEvent) -> bool:
	if on and _chips_drag(e, ".tre-ts"):
		return true
	return super(e)
