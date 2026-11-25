extends "res://logic/ui_kbang.gd"
# (11-25) BẢNG NUNG GẠCH (chạm lò gạch) trên khung Kho chung, như thẻ món bảng Lờ lọp:
#  - thẻ "Nung gạch": hình lò, trạng thái (lò trống / đang nung còn N phút / gạch chín), luật (4 đất sét + 2 củi -> 3 gạch, 30 phút),
#    chip đất sét / củi có/cần, chỗ kiếm, nút Nung · Lấy gạch;
#  - dòng gạch đang có trong kho vật liệu (nâng sao xưởng, sửa nhà, góp công trình).
# Luật ở w_xuong.gd (lg_left, lg_ok, lg_start, lg_take).

const PIC := "res://ui/img/ct/logach.webp"
var k := ""

func _init(ui) -> void:
	super(ui)
	fit = true

func _W():
	return G.w_all.WX

func open(key: String) -> void:
	k = key
	on = true
	scroll = 0.0
	sig = ""
	_build()

func _sig() -> String:
	var W = _W()
	var l: float = W.lg_left(k)
	return JSON.stringify([k, int(ceil(l / 60.0)) if l > 0.0 else l, W.lg_ok(), _barn("dat_set"), _barn("cui"), G.mat_n("gach")])

func _redo() -> void:
	sig = ""
	_build()

func _build() -> void:
	sig = _sig()
	var out := _body()
	var sh := _kshell([], "", func(_k): pass, 0.0)
	_kmount(sh[0], sh[1], float(sh[2]), out[0], float(out[1]))

func _body() -> Array:
	var W = _W()
	var out := []
	var y := 6.0
	# dòng đầu: gạch đang có
	var top := _chip(X0, y, XW, 34.0, "fut")
	out.append(top)
	out.append(_icx(X0 + 18.0, y + 17.0, 22.0, _mat_ic("gach")))
	out.append(_dt(X0 + 34.0, y + 8.0, XW - 44.0, 18.0, "Gạch nung đang có: " + str(G.mat_n("gach")) + " viên", 11.5, 800, BROWN, "left"))
	y += 34.0 + GG
	var l: float = W.lg_left(k)
	var sub := "Lò trống" if l < 0.0 else ("Gạch chín rồi, lấy ra đi" if l == 0.0 else "Đang nung · còn " + str(int(ceil(l / 60.0))) + " phút")
	var desc := str(int(W.LG_IN[0][1])) + " đất sét + " + str(int(W.LG_IN[1][1])) + " củi, nung " + str(int(W.LG_T / 60.0)) + " phút ra " + str(W.LG_OUT) + " viên gạch nung. Gạch để nâng sao xưởng, sửa nhà gặp nạn, góp công trình chung."
	var blk := []
	var yy := 0.0
	if l < 0.0:
		var nl := []
		for c in W.LG_IN:
			nl.append([String(c[0]), G.item_name(String(c[0])), _barn(c[0]), int(c[1])])
		var N: Array = _nchips(0.0, 0.0, XW - 20.0, nl)
		for n in N[0]:
			Snap._move(n, Vector2(X0 + 10.0, yy))
		blk.append_array(N[0])
		yy += float(N[1]) + 4.0
		var HP: Array = _para(X0 + 10.0, yy, XW - 20.0, "Đất sét: vét mương, mò bãi bùn lúc nước ròng. Củi: cưa cây ngã, dọn bụi.", 10.0, 600, SUB, 13.0)
		blk.append_array(HP[0])
		yy += float(HP[1]) + 6.0
	var btns := []
	if l < 0.0:
		btns.append(["Nung", func(): if W.lg_start(k): _redo(), "go" if W.lg_ok() else "off"])
	elif l == 0.0:
		btns.append(["Lấy " + str(W.LG_OUT) + " gạch", func(): if W.lg_take(k): _redo(), "gold"])
	else:
		btns.append(["Đang nung", func(): pass, "off"])
	var C := _scard(y, PIC, "Nung gạch", sub, desc, btns, [blk, yy])
	out.append_array(C[0])
	y += float(C[1]) + GG
	return [out, y]
