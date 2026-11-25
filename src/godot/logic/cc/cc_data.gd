extends RefCounted
# CÂU CÁ BỜ KÊNH: bảng cá, mồi, đồ nghề, màu trời theo giờ (chép từ bản web cau-ca/src/js/00_core.js + 06_data.js).

const ZF := 40.0   # bờ bên kia cách 40 đơn vị
const HOUR_PER_SEC := 1.0 / 30.0   # 30 giây là một giờ trong game, một ngày 12 phút

const FISH := [
	{"id": "ro", "name": "Cá rô đồng", "rar": 1, "w": [.08, .35], "cm": [12, 22], "base": 8, "kg": 60, "zone": [5, 14], "time": {"d": 1, "dd": 1.2, "n": .3}, "bait": {"trun": 1, "tep": .8, "oc": .5, "com": .4}, "bite": "nhap", "win": .72, "P": .38, "st": 3, "jump": .1, "vis": .2,
		"desc": "Rô đồng mùa nước nổi, chiên giòn chấm nước mắm me là hết sẩy."},
	{"id": "sac", "name": "Cá sặc rằn", "rar": 1, "w": [.06, .3], "cm": [10, 20], "base": 6, "kg": 50, "zone": [5, 13], "time": {"d": 1, "dd": .8, "n": .2}, "bait": {"com": 1, "trun": .6}, "bite": "nhap", "win": .78, "P": .26, "st": 2.5, "jump": .05, "vis": .2,
		"desc": "Phơi một nắng làm khô cá sặc, nướng lên thơm cả xóm."},
	{"id": "linh", "name": "Cá linh", "rar": 1, "w": [.02, .08], "cm": [8, 14], "base": 5, "kg": 80, "zone": [6, 22], "time": {"d": 1, "dd": 1, "n": .4}, "bait": {"com": 1, "trun": .5}, "bite": "nhap", "win": .58, "P": .16, "st": 1.5, "jump": .1, "vis": .14,
		"desc": "Cá linh non nấu canh chua bông điên điển, đặc sản mùa nước nổi."},
	{"id": "mevinh", "name": "Cá mè vinh", "rar": 1, "w": [.15, .7], "cm": [15, 28], "base": 10, "kg": 40, "zone": [8, 24], "time": {"d": 1, "dd": .9, "n": .3}, "bait": {"com": 1, "sung": .5, "trun": .3}, "bite": "nhap", "win": .66, "P": .46, "st": 3.5, "jump": .18, "vis": .28,
		"desc": "Mè vinh kho mía, xương nhiều mà ngọt thịt."},
	{"id": "chot", "name": "Cá chốt", "rar": 1, "w": [.05, .2], "cm": [10, 18], "base": 8, "kg": 70, "zone": [6, 22], "time": {"d": .4, "dd": 1.2, "n": 1}, "bait": {"trun": 1, "chua": .8}, "bite": "nam", "win": .82, "P": .3, "st": 2.5, "jump": 0, "vis": .2,
		"desc": "Cá chốt kho tộ, ăn với cơm nóng là ăn hoài."},
	{"id": "tre", "name": "Cá trê vàng", "rar": 2, "w": [.2, 1], "cm": [20, 38], "base": 20, "kg": 60, "zone": [5, 13], "time": {"d": .2, "dd": .8, "n": 1}, "bait": {"chua": 1, "oc": .9, "trun": .8}, "bite": "nam", "win": .9, "P": .56, "st": 4, "jump": 0, "vis": .32,
		"desc": "Trê vàng nướng chấm mắm gừng, dân nhậu mê."},
	{"id": "tom", "name": "Tôm càng xanh", "rar": 2, "w": [.06, .3], "cm": [15, 30], "base": 25, "kg": 200, "zone": [5, 15], "time": {"d": .3, "dd": 1, "n": 1}, "bait": {"trun": 1, "com": .5, "chua": .4}, "bite": "nam", "win": 1.0, "P": .3, "st": 2.5, "jump": 0, "vis": .3,
		"desc": "Tôm càng xanh nướng muối ớt, càng xanh lè như ngọc."},
	{"id": "loc", "name": "Cá lóc đồng", "rar": 2, "w": [.4, 2.5], "cm": [30, 60], "base": 30, "kg": 70, "zone": [5, 15], "cover": 1, "time": {"d": .7, "dd": 1.4, "n": .4}, "bait": {"tep": 1, "oc": .9, "nhai": .9, "trun": .3}, "bite": "keo", "win": .86, "P": .72, "st": 5, "jump": .35, "vis": .5,
		"desc": "Cá lóc nướng trui, cuốn bánh tráng rau sống, chấm mắm nêm."},
	{"id": "he", "name": "Cá he đỏ đuôi", "rar": 2, "w": [.1, .6], "cm": [15, 30], "base": 18, "kg": 70, "zone": [8, 26], "time": {"d": 1, "dd": .8, "n": .2}, "bait": {"com": 1, "sung": .7}, "bite": "nhap", "win": .62, "P": .52, "st": 3.5, "jump": .3, "vis": .28,
		"desc": "Vảy bạc ánh vàng, đuôi đỏ như lửa. Kho lạt cũng ngon."},
	{"id": "luon", "name": "Lươn đồng", "rar": 2, "w": [.1, .6], "cm": [30, 60], "base": 22, "kg": 90, "zone": [4, 9], "time": {"d": .2, "dd": .8, "n": 1}, "bait": {"trun": 1, "oc": 1, "chua": .9}, "bite": "nam", "win": .9, "P": .46, "st": 3.5, "jump": 0, "vis": .5,
		"desc": "Lươn um lá nhàu, món ruột của dân miệt vườn."},
	{"id": "thatlat", "name": "Cá thát lát cườm", "rar": 3, "w": [.5, 3], "cm": [35, 70], "base": 60, "kg": 80, "zone": [10, 28], "time": {"d": .3, "dd": 1.2, "n": 1}, "bait": {"tep": 1, "nhai": .5}, "bite": "keo", "win": .76, "P": .66, "st": 5, "jump": .15, "vis": .5,
		"desc": "Thịt dai, quết chả chiên phồng. Chấm cườm đen viền trắng là dấu hiệu."},
	{"id": "bong", "name": "Cá bống tượng", "rar": 3, "w": [.4, 2], "cm": [25, 45], "base": 80, "kg": 120, "zone": [5, 16], "cover": 1, "time": {"d": .3, "dd": 1, "n": 1}, "bait": {"tep": 1, "trun": .6, "nhai": .6}, "bite": "nam", "win": .8, "P": .62, "st": 5, "jump": 0, "vis": .4,
		"desc": "Bống tượng hấp xì dầu, cá quý để đãi khách."},
	{"id": "locbong", "name": "Cá lóc bông", "rar": 3, "w": [2, 8], "cm": [60, 110], "base": 150, "kg": 60, "zone": [6, 20], "cover": 1, "time": {"d": .5, "dd": 1.5, "n": .3}, "bait": {"nhai": 1, "tep": .6}, "bite": "keo", "win": .7, "P": .98, "st": 8, "jump": .5, "vis": .8,
		"desc": "Dữ dằn nhất kênh. Nó đớp một cái là cong cần, phải gồng mới nổi."},
	{"id": "chinh", "name": "Cá chình bông", "rar": 3, "w": [1, 6], "cm": [60, 120], "base": 180, "kg": 70, "zone": [10, 30], "time": {"d": .1, "dd": .6, "n": 1}, "bait": {"chua": 1, "nhai": .5}, "bite": "keo", "win": .66, "P": .92, "st": 8, "jump": .05, "vis": .9,
		"desc": "Chình bông ăn đêm, trơn tuột, quẫy một cái là văng dây."},
	{"id": "ho", "name": "Cá hô", "rar": 4, "w": [20, 90], "cm": [100, 180], "base": 1500, "kg": 15, "zone": [20, 34], "time": {"d": 1, "dd": .7, "n": .2}, "bait": {"sung": 1}, "bite": "giat", "win": .5, "P": 1.45, "st": 14, "jump": .08, "vis": 1.6,
		"desc": "Vua của dòng Mê Kông. Ông bà kể hồi xưa có con nặng cả tạ."},
	{"id": "tradau", "name": "Cá tra dầu", "rar": 4, "w": [30, 150], "cm": [120, 250], "base": 1800, "kg": 12, "zone": [20, 34], "time": {"d": .2, "dd": 1, "n": 1}, "bait": {"cam": 1}, "bite": "giat", "win": .46, "P": 1.6, "st": 16, "jump": 0, "vis": 1.9,
		"desc": "Cá khổng lồ hiếm có khó tìm. Câu được một lần, kể cả đời chưa hết."},
	{"id": "dep", "name": "Chiếc dép lào", "rar": 0, "w": [.2, .3], "cm": [24, 26], "base": 1, "kg": 0, "zone": [4, 34], "time": {"d": 1, "dd": 1, "n": 1}, "bait": {}, "bite": "rac", "win": 1.2, "P": .2, "st": 1, "jump": 0, "vis": .25, "junk": 1,
		"desc": "Ai đánh rơi dép vậy trời? Vớt lên cho kênh sạch."},
	{"id": "lon", "name": "Lon nước ngọt", "rar": 0, "w": [.05, .1], "cm": [12, 12], "base": 1, "kg": 0, "zone": [4, 34], "time": {"d": 1, "dd": 1, "n": 1}, "bait": {}, "bite": "rac", "win": 1.2, "P": .15, "st": 1, "jump": 0, "vis": .15, "junk": 1,
		"desc": "Rác thì vớt lên, đừng để cá nuốt."},
	{"id": "non", "name": "Nón lá rách", "rar": 0, "w": [.2, .4], "cm": [40, 40], "base": 2, "kg": 0, "zone": [4, 34], "time": {"d": 1, "dd": 1, "n": 1}, "bait": {}, "bite": "rac", "win": 1.2, "P": .35, "st": 1, "jump": 0, "vis": .4, "junk": 1,
		"desc": "Nón ai bị gió thổi bay xuống kênh. Rách rồi mà còn thương."},
]
const RAR := ["Rác", "Thường", "Khá hiếm", "Hiếm", "Huyền thoại"]
const RAR_W := [.05, 1, .34, .1, .022]
const RAR_COL := ["#8a7a5a", "#6a9a3a", "#3a7ac8", "#9a4ac8", "#e09a20"]

const BAIT := {
	"trun": {"name": "Trùn đất", "desc": "Mồi quốc dân, đào sau hè là có. Không tốn tiền.", "pack": 0, "price": 0, "lv": 1},
	"com": {"name": "Cơm vo cám", "desc": "Cá ăn tạp mê: sặc, linh, mè vinh, he.", "pack": 10, "price": 12, "lv": 1},
	"tep": {"name": "Tép sống", "desc": "Mồi sống cho cá dữ: lóc, bống tượng, thát lát.", "pack": 10, "price": 60, "lv": 2},
	"oc": {"name": "Ốc gạo", "desc": "Ốc nhặt ngoài ruộng mùa nước nổi (xài chung Kho vườn). Cá trê, cá lóc, lươn mê.", "pack": 0, "price": 0, "lv": 1},
	"chua": {"name": "Mồi chua", "desc": "Cám ủ chua, hôi mà cá trê, lươn, chình mê.", "pack": 10, "price": 40, "lv": 3},
	"nhai": {"name": "Nhái con", "desc": "Mồi to dụ cá lóc bông, cá chình.", "pack": 5, "price": 70, "lv": 4},
	"sung": {"name": "Trái sung chín", "desc": "Cá hô ăn trái cây rụng. Thả xa giữa kênh, ban ngày. Cần câu bậc 3 trở lên mới quăng tới.", "pack": 5, "price": 120, "lv": 5},
	"cam": {"name": "Cám rêu thơm", "desc": "Cá tra dầu ăn rêu. Thả xa giữa kênh, chiều tối. Cần câu bậc 3 trở lên mới quăng tới.", "pack": 5, "price": 150, "lv": 6},
}
const BAIT_ORDER := ["trun", "com", "tep", "oc", "chua", "nhai", "sung", "cam"]

# (bản 536) giá đồ nghề x0,57 (tròn chục): cá bán theo giá Kho (thấp hơn giá giỏ cũ) -> số con phải câu để đổi giữ như cũ
const ROD := [
	{"name": "Cần trúc", "desc": "Cần trúc ông nội để lại.", "range": 16, "pow": 1, "acc": 1.1},
	{"name": "Cần tre già", "desc": "Tre già phơi khói bếp, dẻo mà chắc. Quăng xa hơn.", "range": 21, "pow": 1.3, "acc": .85, "price": 200, "need": {"ro": 3}},
	{"name": "Cần câu lục", "desc": "Cần ráp ba khúc, quăng tới giữa kênh.", "range": 27, "pow": 1.7, "acc": .65, "price": 800, "need": {"bong": 1, "tre": 1}},
	{"name": "Cần ông Năm", "desc": "Cần của ông Năm câu cá hô, giờ ổng nhường lại.", "range": 34, "pow": 2.3, "acc": .5, "price": 2390, "need": {"locbong": 1, "chinh": 1}},
]
const LINE := [
	{"name": "Cước 0.2", "desc": "Dây mảnh, cá lớn là đứt.", "str": 1},
	{"name": "Cước 0.35", "desc": "Chịu được cá lóc cỡ vừa.", "str": 1.35, "price": 160, "need": {"sac": 3}},
	{"name": "Cước 0.5", "desc": "Dây to, kéo cá ký mấy ký.", "str": 1.8, "price": 630, "need": {"thatlat": 1, "loc": 1}},
	{"name": "Dây dù bện", "desc": "Bện tay, cá hô cũng khó giựt đứt.", "str": 2.6, "price": 2050, "need": {"chinh": 1}},
]
const FLO := [
	{"name": "Phao lông nhím", "desc": "Phao truyền thống, nhạy vừa.", "win": 1, "glow": 0},
	{"name": "Phao lông công", "desc": "Nhạy hơn: có thêm thời gian để giật.", "win": 1.18, "glow": 0, "price": 280, "need": {"loc": 1}},
	{"name": "Phao đèn đêm", "desc": "Đầu phao phát sáng, câu đêm thấy rõ.", "win": 1.28, "glow": 1, "price": 540, "need": {"tre": 2}},
	{"name": "Phao sơn mài khảm xà cừ", "desc": "Đầu đèn vàng, nhạy nhất: cá rỉa nhẹ cũng thấy.", "win": 1.38, "glow": 1, "price": 1400, "need": {"locbong": 1, "thatlat": 1}},
]
# cap: sức chứa (bản chơi riêng); rare: trong vườn (không giỏ, cá vô Kho) giỏ = cá hiếm (rar >= 3) dễ dính hơn
const CAGE := [
	{"name": "Giỏ tre nhỏ", "desc": "Đựng được 8 con.", "cap": 8, "rare": 1.0},
	{"name": "Giỏ tre lớn", "desc": "Đựng được 16 con.", "cap": 16, "rare": 1.15, "price": 170, "need": {"ro": 2}},
	{"name": "Lồng lưới", "desc": "Đựng được 30 con, cá sống lâu.", "cap": 30, "rare": 1.3, "price": 680, "need": {"luon": 2}},
	{"name": "Rọ mây sơn dầu đai đồng", "desc": "Đựng được 50 con, nắp gỗ kín.", "cap": 50, "rare": 1.5, "price": 1500, "need": {"chinh": 1, "luon": 2}},
]
# lưỡi câu (11-25): hold = dây chùng bao lâu cá mới sút lưỡi (x 2,8 giây)
const LUOI := [
	{"name": "Lưỡi sắt rèn", "desc": "Lưỡi sắt rèn buộc chỉ đỏ, dây chùng chút là cá sút.", "hold": 1.0},
	{"name": "Lưỡi thép có ngạnh", "desc": "Có ngạnh + chì: cá dính chắc hơn khi dây chùng.", "hold": 1.3, "price": 180, "need": {"linh": 3}},
	{"name": "Lưỡi đôi đồng", "desc": "Hai lưỡi đồng + khoá xoay, cá vặn mình khó sút.", "hold": 1.6, "price": 700, "need": {"bong": 1, "he": 1}},
	{"name": "Lưỡi chùm 3 mạ vàng", "desc": "Ba lưỡi mạ vàng, cá dính là khó thoát.", "hold": 2.0, "price": 2200, "need": {"ho": 1, "chinh": 1}},
]
# cá câu được -> món trong Kho Nông Trại (g.barn) (bản gắn trong vườn: nút "Vô Kho"). Link 11-23 "nối đủ": cả 16 loài,
# 10 món mới khai trong godot/data/che_bien/vat_pham.json + icon ui/svg/kh/<món>.svg (tools/cc/kho/ca_kho_svg.py). Rác không vô Kho.
const KHO := {"ro": "ca_ro", "sac": "ca_sac", "linh": "ca_linh", "mevinh": "ca_mevinh", "chot": "ca_chot", "tre": "ca_tre", "tom": "tom",
	"loc": "ca_loc", "he": "ca_he", "luon": "luon", "thatlat": "ca_thatlat", "bong": "ca_bong", "locbong": "ca_locbong", "chinh": "ca_chinh",
	"ho": "ca_ho", "tradau": "ca_tradau"}
# mồi xài chung số lượng với Kho vườn (bản gắn trong vườn): mã mồi câu cá -> món Kho
const KHO_BAIT := {"tep": "tep", "oc": "oc"}
const GEAR_KEYS := ["rod", "line", "flo", "luoi", "cage"]
const GEAR_NAME := {"rod": "Cần câu", "line": "Dây câu", "flo": "Phao", "luoi": "Lưỡi câu", "cage": "Giỏ đựng"}

static var BY := {}

static func gear(k: String) -> Array:
	match k:
		"rod": return ROD
		"line": return LINE
		"flo": return FLO
		"luoi": return LUOI
	return CAGE

static func fish(id: String) -> Dictionary:
	if BY.is_empty():
		for f in FISH:
			BY[f.id] = f
	return BY.get(id, {})

static func xp_need(lv: int) -> int:
	return 40 + lv * 35

static var kho_price := Callable()   # (bản 536) chạy trong vườn: giá Kho vườn của món (G.price)
static func fish_value(f: Dictionary, w: float) -> int:
	# (bản 536) trong vườn: một giá chung với Kho = giá Kho x căn(cân con này / cân giữa của loài): con trung bình bán đúng giá Kho,
	# con to hơn bán cao hơn -> bán ở giỏ hay ở Kho cùng một giá (trước giỏ ăn gấp 1,5-5 lần Kho)
	if kho_price.is_valid() and KHO.has(f.id):
		var mid: float = (float(f.w[0]) + float(f.w[1])) * 0.5
		return maxi(1, int(round(float(kho_price.call(String(KHO[f.id]))) * maxf(1.0, sqrt(w / maxf(0.001, mid))))))   # (11-25) ít nhất giá Kho (bán ngay không thiệt hơn cất Kho), con to tới ~1,3 giá Kho
	return maxi(1, int(round(f.base + f.kg * w)))

# ------------------------------------------------------------ màu trời theo giờ (TOD)
const TOD := [
	[0, {"top": "#0a1430", "hor": "#2a3a64", "sun": "#a8bcff", "si": 0, "tint": "#4a5a80", "water": "#14384c", "glow": 1, "cloud": "#26304a", "fog": "#18223a", "star": 1}],
	[4.6, {"top": "#121c40", "hor": "#3e4064", "sun": "#c8a0a0", "si": 0, "tint": "#525a7a", "water": "#183a4a", "glow": .9, "cloud": "#3a3a52", "fog": "#2a2c44", "star": .8}],
	[5.6, {"top": "#2a3c74", "hor": "#d08a7a", "sun": "#ffb070", "si": .35, "tint": "#7a7080", "water": "#24404e", "glow": .5, "cloud": "#c88a8a", "fog": "#a8807e", "star": .2}],
	[6.6, {"top": "#4a7ec0", "hor": "#ffcf98", "sun": "#ffbe70", "si": 1, "tint": "#d8bca0", "water": "#2f7a78", "glow": .05, "cloud": "#ffe0c0", "fog": "#f0d0b0", "star": 0}],
	[9, {"top": "#4a8edc", "hor": "#cfe6f4", "sun": "#fff4d8", "si": .9, "tint": "#f6f4ec", "water": "#2a9a8e", "glow": 0, "cloud": "#ffffff", "fog": "#d8e8f2", "star": 0}],
	[12.5, {"top": "#3c86da", "hor": "#d6ecf8", "sun": "#fffbea", "si": .85, "tint": "#ffffff", "water": "#289c94", "glow": 0, "cloud": "#ffffff", "fog": "#dcecf6", "star": 0}],
	[16, {"top": "#4884d0", "hor": "#f2e2c4", "sun": "#ffe2a4", "si": .95, "tint": "#f6e6cc", "water": "#329a8a", "glow": 0, "cloud": "#fff4e0", "fog": "#f0e0c8", "star": 0}],
	[17.8, {"top": "#3a4c8e", "hor": "#ff9c5c", "sun": "#ff8c3c", "si": 1.15, "tint": "#b8846e", "water": "#3a5e62", "glow": .25, "cloud": "#ffa476", "fog": "#e8906c", "star": 0}],
	[18.8, {"top": "#232c64", "hor": "#b85a5a", "sun": "#ff6a3a", "si": .45, "tint": "#6a5468", "water": "#244252", "glow": .7, "cloud": "#8a4a5e", "fog": "#6a4458", "star": .2}],
	[19.8, {"top": "#121a44", "hor": "#46406a", "sun": "#c86a5a", "si": 0, "tint": "#525878", "water": "#163a4c", "glow": 1, "cloud": "#30304a", "fog": "#2a2a44", "star": .7}],
	[24, {"top": "#0a1430", "hor": "#2a3a64", "sun": "#a8bcff", "si": 0, "tint": "#4a5a80", "water": "#14384c", "glow": 1, "cloud": "#26304a", "fog": "#18223a", "star": 1}],
]
const PHASES := [[4.6, "Rạng sáng"], [6, "Sáng sớm"], [8, "Buổi sáng"], [11, "Trưa"], [14, "Buổi chiều"], [17.3, "Hoàng hôn"], [18.7, "Chạng vạng"], [19.6, "Tối"], [23, "Khuya"]]

static var _todc := []

static func smooth(a: float, b: float, x: float) -> float:
	var t := clampf((x - a) / (b - a), 0, 1)
	return t * t * (3 - 2 * t)

static func tod_at(h: float) -> Dictionary:
	if _todc.is_empty():
		for kf in TOD:
			var o := {}
			for k in kf[1]:
				var v = kf[1][k]
				o[k] = Color(v) if v is String else float(v)
			_todc.append([float(kf[0]), o])
	h = fposmod(h, 24.0)
	var i := 0
	while i < _todc.size() - 2 and _todc[i + 1][0] <= h:
		i += 1
	var h0: float = _todc[i][0]
	var a: Dictionary = _todc[i][1]
	var h1: float = _todc[i + 1][0]
	var b: Dictionary = _todc[i + 1][1]
	var t := smooth(0, 1, (h - h0) / (h1 - h0))
	var o := {}
	for k in a:
		if a[k] is Color:
			o[k] = (a[k] as Color).lerp(b[k], t)
		else:
			o[k] = lerpf(a[k], b[k], t)
	var st := (h - 5.6) / 13.2
	o.sunUp = st > 0 and st < 1
	var tt: float = st if o.sunUp else fposmod(h - 18.8 + 24, 24.0) / 10.8
	o.sunX = 0.06 + 0.88 * clampf(tt, 0, 1)
	o.sunElev = sin(PI * clampf(tt, 0, 1))
	o.moon = 0.0 if o.sunUp else smooth(0, .12, tt) * smooth(1, .88, tt)
	o.night = clampf(o.glow, 0, 1)
	return o

static func phase_name(h: float) -> String:
	var n := "Khuya"
	for p in PHASES:
		if h >= p[0]:
			n = p[1]
	return "Khuya" if h < 4.6 else n

static func is_night(h: float) -> bool:
	return h >= 19.3 or h < 5.2
static func is_dusk_dawn(h: float) -> bool:
	return (h >= 5 and h < 8) or (h >= 16.8 and h < 19.6)

static func def_save() -> Dictionary:
	return {"xu": 60, "xp": 0, "lv": 1, "bait": "trun", "baits": {"trun": 999, "com": 10}, "rod": 0, "line": 0, "flo": 0, "luoi": 0, "cage": 0,
		"basket": [], "dex": {}, "luck": 0.0, "hour": 6.4, "sound": 1, "music": 1, "tut": 0, "stats": {"casts": 0, "catches": 0, "snaps": 0}}
