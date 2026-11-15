extends "res://logic/ui_bang.gd"
# BẢNG THƯ NHÀ (kU bản web, dựng trong khung bảng nhà dân gu("thu")): lời thư (.vl-talk), nút Nhận xu / gạch,
# thư nhờ gửi đồ quê (.ws-rec: món, chip đủ / thiếu, nút Gửi) + Để dành gửi sau, hoặc hẹn gửi còn lại (p.note + .ws-rec).
# Luật ở w_thu.gd (wU). Mẫu: ui/snap/thu.json (tools/mk_thu.py).

var TH            # w_thu.gd
var P := {}       # thu.json

func _init(ui, wth) -> void:
	super(ui)
	TH = wth
	P = Snap.load_snap("thu")
	B = P["#pov"][0]

func open() -> void:
	on = true
	scroll = 0.0
	sig = ""
	_build()

func step(dt: float) -> void:
	if not on:
		return
	_sig_t -= dt
	if _sig_t > 0.0:
		return
	_sig_t = 0.5
	if _sig() != sig:
		_build()

func _sig() -> String:
	var t: Dictionary = TH.Eg()
	var a = t.get("un")
	var o = t.get("rq")
	return JSON.stringify([t, _barn(a.id) if a is Dictionary and a.has("id") else 0, _barn(o.id) if o is Dictionary else 0])

func _btn_txt(b: Dictionary, s: String) -> void:   # chữ một dòng giữa nút
	var w := _tw(b, s)
	b.text = s
	b.tr = [float(b.r[0]) + (float(b.r[2]) - w) * 0.5, b.tr[1], w, b.tr[3]]

func _talk(s: String) -> Dictionary:   # .vl-talk > b
	var n := _cl(P.talk)
	var b: Dictionary = n.kids[0]
	var top := float(b.r[1]) - float(n.r[1])
	var bot := float(n.r[3]) - top - float(b.r[3])
	var sty := _cl(b)
	sty.erase("kids")
	var h := _put(b, [_r(s, sty)], "left", float(b.r[2]))
	b.r[3] = h
	n.r[3] = top + h + bot
	return n

func _jobs(prim: bool, s: String, cb: Callable) -> Dictionary:   # .vl-jobs: một nút ngang khung
	var n := _cl(P.jobs_p if prim else P.jobs)
	var b: Dictionary = n.kids[0]
	_btn_txt(b, s)
	_act(b, cb)
	return n

func _rec(id: String, q: int, small: String, cb: Callable) -> Dictionary:   # .ws-rec > li.rec: Gửi n món
	var n := _cl(P.rec)
	var li: Dictionary = n.kids[0]
	var sv: Dictionary = li.kids[0]
	var dv: Dictionary = li.kids[1]
	var ok := _barn(id) >= q
	_ic(sv, id)
	var bt: Dictionary = _cl(P.ok) if ok else li.kids[2]
	var t: String = "Gửi " + G.w_all.WC.ho(id, q)
	var bb: Dictionary = dv.kids[0]
	bb.text = t
	bb.r[2] = _tw(bb, t) + 1.0
	if bb.has("tr"):
		bb.tr = [bb.r[0], bb.tr[1], bb.r[2], bb.tr[3]]
	var sm: Dictionary = dv.kids[1]
	sm.text = small
	if sm.has("tr"):
		sm.tr = [sm.r[0], sm.tr[1], _tw(sm, small) + 1.0, sm.tr[3]]
	var nd: Dictionary = dv.kids[2]
	dv.kids[2] = _chips(nd, [[id, q]], float(nd.r[0]), float(nd.r[1]), {})
	_act(bt, cb, ok)
	li.kids[2] = bt
	return n

func _build() -> void:   # kU
	sig = _sig()
	var t: Dictionary = TH.Eg()
	var a = t.get("un")
	var blocks := []
	if a is Dictionary:
		blocks.append(_talk(String(a.txt)))
		if a.k == "tien":
			blocks.append(_jobs(true, "Nhận " + G.fmt_n(int(a.xu)) + " xu", TH.wU.bind("nhan")))
		elif a.k == "tin":
			blocks.append(_jobs(true, "Nhận " + str(int(a.gach)) + " viên gạch", TH.wU.bind("nhan")))
		else:
			blocks.append(_rec(String(a.id), int(a.q), String(a.who) + " gửi tiền cước về " + G.fmt_n(int(a.xu)) + " xu", TH.wU.bind("gui")))
			blocks.append(_jobs(false, "Để dành gửi sau", TH.wU.bind("de")))
	elif t.get("rq") is Dictionary:
		var o: Dictionary = t.rq
		var nt := _cl(P.note)
		var s: String = "Còn hẹn gửi " + G.w_all.WC.ho(String(o.id), int(o.q)) + " cho " + String(o.who) + "."
		var top := _px(nt, "padding-top")
		var h := _put(nt, [_r(s, _cl(P.note))])
		nt.r[3] = top + h + _px(nt, "padding-bottom")
		blocks.append(nt)
		blocks.append(_rec(String(o.id), int(o.q), "Được " + G.fmt_n(int(o.xu)) + " xu", TH.wU.bind("gui2")))
	else:
		close()
		return
	var n := _cl(B)
	var vt := _find(n, "vlBody")
	_show(n, vt, blocks, float(P.talk.r[1]) - float(vt.r[1]))
	U._layout()
