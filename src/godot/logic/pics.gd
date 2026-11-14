extends Node
# Hình của phần logic: mỗi hình một file webp riêng, gom trong vài gói l/<tên>.wasm (host giới hạn số file).
# Gói chỉ tải khi có hình cần vẽ; mỗi hình chỉ giải mã khi cần, vài mili giây mỗi khung.
# Gói: [u32 độ dài json][json {i:{tên:[vị trí, độ dài]}, m:{...}}][byte webp...]

signal ready_pic(bundle: String, key: String)
signal bundle_ready(bundle: String)

const DECODE_MS := 4.0
var base := ""
var B := {}         # tên gói -> {st:0 chờ/1 đang tải/2 xong/3 lỗi, data, idx, meta}
var T := {}         # "gói/hình" -> Texture2D
var want := []      # [gói, hình] chờ giải mã
var _wanted := {}
var _http: Array = []

var _lvd = null
func _lv() -> Dictionary:
	# logic/lv.json (merge_logic.py ghi): mã riêng từng gói, gói nào đổi thì điện thoại mới tải lại gói đó
	if _lvd == null:
		var t := FileAccess.get_file_as_string("res://logic/lv.json")
		_lvd = JSON.parse_string(t) if t != "" else {}
		if not (_lvd is Dictionary):
			_lvd = {}
	return _lvd

func setup(url: String) -> void:
	base = url

func meta(b: String) -> Dictionary:
	return B[b]["meta"] if B.has(b) and B[b]["st"] == 2 else {}

var _imc := {}     # b/k -> Image đã giải (chạm thử điểm ảnh gọi liên tục: giải lại mỗi lần làm giựt)
var _imq := []     # thứ tự vào, giữ tối đa 48 ảnh

func img(b: String, k: String) -> Image:   # giải mã 1 ảnh của gói đã tải (dữ liệu, không làm texture), có nhớ
	var key := b + "/" + k
	if _imc.has(key):
		return _imc[key]
	if not has_bundle(b):
		load_bundle(b)
		return null
	var e = B[b]["idx"].get(k)
	if e == null:
		return null
	var o: int = B[b]["o"] + int(e[0])
	var im := Image.new()
	if im.load_webp_from_buffer(B[b]["data"].slice(o, o + int(e[1]))) != OK:
		return null
	im.convert(Image.FORMAT_RGBA8)
	_imc[key] = im
	_imq.append(key)
	if _imq.size() > 48:
		_imc.erase(_imq.pop_front())
	return im

func has_bundle(b: String) -> bool:
	return B.has(b) and B[b]["st"] == 2

const NET_MAX := 8        # tải tối đa 8 gói một lúc (trình duyệt báo ERR_INSUFFICIENT_RESOURCES khi xin quá nhiều)
var _net := 0
var _netq := []

func load_bundle(b: String) -> void:
	if B.has(b):
		return
	B[b] = {"st": 1}
	_netq.append([b, 0])
	_net_pump()

func _net_pump() -> void:
	while _net < NET_MAX and not _netq.is_empty():
		var a: Array = _netq.pop_front()
		_fetch_b(a[0], a[1])

func _fetch_b(b: String, tries: int) -> void:
	_net += 1
	var h := HTTPRequest.new()
	h.accept_gzip = false   # trình duyệt đã giải nén
	h.download_chunk_size = 1 << 20
	add_child(h)
	h.request_completed.connect(func(res, code, _hd, body: PackedByteArray):
		h.queue_free()
		_net -= 1
		if res != HTTPRequest.RESULT_SUCCESS or code != 200 or body.size() < 4:
			if tries < 3:
				_netq.append([b, tries + 1])   # thử lại
			else:
				B[b] = {"st": 3}
				push_warning("lỗi tải gói " + b + " " + str(res) + "/" + str(code))
			_net_pump()
			return
		var n := body.decode_u32(0)
		var j = JSON.parse_string(body.slice(4, 4 + n).get_string_from_utf8())
		B[b] = {"st": 2, "data": body, "o": 4 + n, "idx": j["i"], "meta": j.get("m", {})}
		bundle_ready.emit(b)
		_net_pump())
	if h.request(base + "l/" + b + ".wasm?v=" + str(_lv().get(b, "0"))) != OK:
		h.queue_free()
		_net -= 1
		if tries < 3:
			_netq.append([b, tries + 1])

# giải sẵn mọi hình của một gói (nhân vật): mức nét trước, mức nhỏ sau, để lúc đi không có khung nào chưa giải
func warm(b: String) -> void:
	if not has_bundle(b):
		return
	var keys: Array = B[b]["idx"].keys()
	keys.sort_custom(func(x, y): return String(x).count("@") < String(y).count("@") or (String(x).count("@") == String(y).count("@") and String(x) < String(y)))
	for k in keys:
		var key: String = b + "/" + String(k)
		if not T.has(key) and not _wanted.has(key):
			_wanted[key] = true
			want.append([b, String(k)])

# texture now, or null (then it is queued and ready_pic fires later)
func tex(b: String, k: String) -> Texture2D:
	var key := b + "/" + k
	if T.has(key):
		return T[key]
	if not B.has(b):
		load_bundle(b)
	if not _wanted.has(key):
		_wanted[key] = true
		want.append([b, k])
	return null

# picture for drawing at scr screen px per world unit (ppu = picture px per world unit of the original):
# the original (lossless, every pixel) whenever the screen needs it; zoomed out, a Lanczos copy 1/2^l with picture px >=
# screen px, drawn with plain linear filtering like the village ground (no mipmap blur)
func level(ppu: float, scr: float) -> int:
	if scr <= 0.0 or ppu <= scr:
		return 0
	return clampi(int(floor(log(ppu / scr) / log(2.0))), 0, 4)

func texz(b: String, k: String, ppu: float, scr: float) -> Texture2D:
	var l := level(ppu, scr)
	var t := tex(b, k if l == 0 else k + "@" + str(l))
	if t != null:
		return t
	# while it decodes: the nearest level already decoded, sharper first
	for j in [l - 1, l - 2, l - 3, l - 4, l + 1, l + 2, l + 3, l + 4]:
		if j >= 0 and j <= 4:
			var kk: String = b + "/" + (k if j == 0 else k + "@" + str(j))
			if T.has(kk):
				return T[kk]
	return null

func _process(_dt: float) -> void:
	if want.is_empty():
		return
	var t0 := Time.get_ticks_usec()
	var i := 0
	while i < want.size():
		var w: Array = want[i]
		var b: String = w[0]
		var st: int = B.get(b, {}).get("st", 0)
		if st == 3:
			want.remove_at(i)
			continue
		if st != 2:
			i += 1
			continue
		want.remove_at(i)
		var e = B[b]["idx"].get(w[1])
		if e == null:
			continue
		var o: int = B[b]["o"] + int(e[0])
		var img := Image.new()
		if img.load_webp_from_buffer(B[b]["data"].slice(o, o + int(e[1]))) != OK:
			continue
		var key: String = b + "/" + w[1]
		T[key] = ImageTexture.create_from_image(img)
		ready_pic.emit(b, w[1])
		if (Time.get_ticks_usec() - t0) / 1000.0 > DECODE_MS:
			break
