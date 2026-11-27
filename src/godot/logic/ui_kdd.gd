extends "res://logic/ui_bang.gd"
# KHO › ĐỒ DÙNG: danh sách đồ dùng (items: bùa +50% EXP theo L3, bùa đang chạy, phần cơm hồi sức) + định dạng thời gian.
# (11-27) giao diện dựng ở ui_kho2.gd (Kho trên khung chung).

static func MA(t: float) -> String:
	var a := int(ceil(t / 6e4))
	var n := a / 1440
	var e := (a % 1440) / 60
	var r := a % 60
	return (str(n) + " ngày " + str(e) + "g") if n else ((str(e) + "g " + str(r) + "p") if e else (str(r) + " phút"))

func items() -> Array:   # l()
	var nv = G.nv
	var p: Dictionary = nv.A3()
	var d: float = nv.Fu()
	var v := false
	var h := []
	var ks := []
	for k in nv.L3:
		ks.append(int(k))
	for k in p.keys():
		if not ks.has(int(k)):
			ks.append(int(k))
	for k in ks:
		var c := int(p.get(str(k), 0))
		if c > 0:
			h.append({"k": "b" + str(k), "h": k, "n": nv.xA(k), "c": c, "art": "bua", "run": 0.0 if v else d,
				"d": "+50% kinh nghiệm trong " + (str(k) + " giờ" if k < 24 else str(k / 24) + " ngày") + ". Dùng thêm thì cộng dồn thời gian.", "btn": "Dùng"})
			v = true
	if d > 0.0 and not v:
		h.push_front({"k": "brun", "h": 0, "n": "Bùa +50% EXP", "c": 0, "art": "bua", "run": d, "d": "Đang có hiệu lực: kinh nghiệm nhận được +50%.", "btn": ""})
	if nv.tu() > 0:
		h.append({"k": "com", "h": 0, "n": "Phần cơm hồi sức", "c": nv.tu(), "art": "com", "run": 0.0, "d": "Hồi đầy thể lực cho nhân vật ngay lập tức.", "btn": "Ăn"})
	return h
