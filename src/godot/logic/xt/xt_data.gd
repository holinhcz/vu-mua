extends RefCounted
# XẾP TRÁI MIỆT VƯỜN: số liệu dịch y nguyên từ bản web (xep-trai/src/js 06_levels, 02_art, 08b_garden, 08c_farm).

const LEVELS := [
	{"moves": 16, "kinds": 5, "goals": [{"score": 3500}], "map": [".......", ".......", ".......", ".......", ".......", ".......", "......."], "tip": "Kéo trái đổi chỗ, ráp 3 trái giống nhau"},
	{"moves": 20, "kinds": 5, "goals": [{"fruit": 0, "n": 18}, {"fruit": 1, "n": 18}], "map": ["........", "........", "........", "........", "........", "........", "........", "........"], "tip": "Ráp 4 trái liền hàng ra trái quấn khăn rằn: trâu cày nguyên hàng"},
	{"moves": 20, "kinds": 5, "goals": [{"mud": 1}], "map": ["........", "........", "..mmmm..", "..mmmm..", "..mmmm..", "..mmmm..", "........", "........"], "tip": "Ráp trái trên ô bùn để dọn bùn"},
	{"moves": 20, "kinds": 5, "goals": [{"score": 9000}], "map": ["    .    ", "   ...   ", "  .....  ", " ....... ", ".........", " ....... ", "  .....  ", "   ...   ", "    .    "], "tip": "Ráp chữ L hoặc chữ T ra trái gói lá: heo nhảy ụp"},
	{"moves": 22, "kinds": 5, "goals": [{"hay": 1}], "map": ["........", "........", "........", ".hhhhhh.", ".h....h.", "........", "........", "........"], "tip": "Ráp sát bó rơm để phá rơm"},
	{"moves": 24, "kinds": 5, "goals": [{"egg": 2}], "map": [".e......", "........", "........", "........", "........", "........", "........", "........"], "tip": "Đưa trứng vịt xuống tới đáy để lượm"},
	{"moves": 27, "kinds": 5, "goals": [{"mud": 1}], "map": ["   ...   ", "   .M.   ", "   ...   ", "mmm...mmm", "mMm...mMm", "mmm...mmm", "   ...   ", "   .M.   ", "   ...   "], "tip": "Ráp 5 trái thẳng hàng ra gà trống: gáy một tiếng sạch một loại"},
	{"moves": 22, "kinds": 5, "goals": [{"fruit": 2, "n": 30}, {"mud": 1}], "map": [".........", ".........", ".........", "..mmmmm..", "..m...m..", "..mmmmm..", ".........", ".........", "........."], "tip": "Ráp 4 trái vuông 2x2 ra vịt bay đi làm giùm"},
	{"moves": 22, "kinds": 5, "goals": [{"fruit": 3, "n": 24}], "map": ["........", ".l....l.", "........", "..llll..", "..llll..", "........", ".l....l.", "........"], "tip": "Trái bị dây quấn: ráp trúng nó để gỡ dây"},
	{"moves": 28, "kinds": 5, "goals": [{"egg": 3}, {"hay": 1}], "map": ["e.......e", ".........", ".........", "hh.....hh", ".........", "..hhhhh..", ".........", ".........", "........."]},
	{"moves": 24, "kinds": 6, "goals": [{"score": 12000}], "map": [".........", ".........", ".........", ".........", ".........", ".........", ".........", ".........", "........."]},
	{"moves": 24, "kinds": 6, "goals": [{"fruit": 5, "n": 20}, {"fruit": 4, "n": 20}], "map": ["  .....  ", " ....... ", ".........", ".........", ".........", ".........", ".........", " ....... ", "  .....  "]},
	{"moves": 31, "kinds": 6, "goals": [{"mud": 1}], "map": ["mmm   mmm", "mMm   mMm", "mmm...mmm", "  .....  ", "  .....  ", "  .....  ", "mmm...mmm", "mMm   mMm", "mmm   mmm"]},
	{"moves": 26, "kinds": 5, "goals": [{"egg": 3}], "map": ["...e...", ".......", ".......", "..hhh..", ".......", ".......", ".......", ".......", "......."]},
	{"moves": 26, "kinds": 6, "goals": [{"hay": 1}], "map": [".........", ".HHH.HHH.", ".........", ".........", ".........", ".........", ".........", ".hhhhhhh.", "........."]},
	{"moves": 25, "kinds": 6, "goals": [{"fruit": 0, "n": 25}, {"mud": 1}], "map": ["....... ", ".mmmmm..", ".mMMMm..", ".mMMMm..", ".mmmmm..", "........", "........", "........"]},
	{"moves": 26, "kinds": 6, "goals": [{"fruit": 2, "n": 20}, {"fruit": 3, "n": 20}], "map": ["lllllllll", ".........", ".........", ".........", ".........", ".........", ".........", ".........", "lllllllll"]},
	{"moves": 32, "kinds": 6, "goals": [{"egg": 2}, {"mud": 1}], "map": ["e   .   e", "..  .  ..", ".........", ".mmmmmmm.", ".mMMMMMm.", ".mmmmmmm.", ".........", "..  .  ..", "..  .  .."]},
	{"moves": 26, "kinds": 6, "goals": [{"hay": 1}, {"fruit": 1, "n": 25}], "map": [".........", "..H...H..", ".HhH.HhH.", "..H...H..", ".........", ".........", ".........", ".........", "........."]},
	{"moves": 33, "kinds": 6, "goals": [{"egg": 3}, {"hay": 1}, {"mud": 1}], "map": [".e.....e.", ".........", "hhh...hhh", ".........", "..mmmmm..", "..mMMMm..", "..mmmmm..", ".........", "........."]},
	{"moves": 22, "kinds": 6, "goals": [{"score": 9000}], "map": [".........", ". ..... .", ".........", ".........", "... . ...", ".........", ".........", ". ..... .", "........."]},
	{"moves": 30, "kinds": 6, "goals": [{"mud": 1}], "map": ["MMMMMMMMM", "m.......m", "m.......m", "m.......m", "m.......m", "m.......m", "m.......m", "m.......m", "MMMMMMMMM"]},
	{"moves": 26, "kinds": 6, "goals": [{"fruit": 4, "n": 30}, {"fruit": 5, "n": 30}], "map": ["   ...   ", "  .....  ", " ....... ", ".........", ".........", ".........", " ....... ", "  .....  ", "   ...   "]},
	{"moves": 32, "kinds": 6, "goals": [{"egg": 4}], "map": ["..e...e..", ".........", ".........", "...hhh...", "..h...h..", ".........", ".........", ".........", "........."], "eggsOn": 2},
	{"moves": 26, "kinds": 6, "goals": [{"hay": 1}], "map": [".........", "HH.HHH.HH", ".........", ".........", "hh.....hh", ".........", ".........", ".........", ".........", "........."]},
	{"moves": 32, "kinds": 6, "goals": [{"mud": 1}, {"fruit": 2, "n": 30}], "map": ["lLl...lLl", "LmL...LmL", "lLl...lLl", ".........", ".........", ".........", "lLl...lLl", "LmL...LmL", "lLl...lLl"]},
	{"moves": 34, "kinds": 6, "goals": [{"egg": 3}, {"fruit": 0, "n": 25}], "map": ["e   .   e", ".. ... ..", ".........", ".........", ".........", ".........", ".........", ".. ... ..", ".   .   ."]},
	{"moves": 28, "kinds": 6, "goals": [{"hay": 1}, {"mud": 1}], "map": [".........", ".HH...HH.", ".HmmmmmH.", "..mMMMm..", "..mMMMm..", ".HmmmmmH.", ".HH...HH.", ".........", "........."]},
	{"moves": 32, "kinds": 6, "goals": [{"fruit": 3, "n": 35}, {"fruit": 1, "n": 35}, {"mud": 1}], "map": ["mmmmmmmmm", "m.......m", "m.lllll.m", "m.l...l.m", "m.l...l.m", "m.lllll.m", "m.......m", "m.......m", "mmmmmmmmm"]},
	{"moves": 36, "kinds": 6, "goals": [{"egg": 4}, {"hay": 1}, {"mud": 1}], "map": ["e...e...e", ".........", "HHH...HHH", ".........", "..mmmmm..", ".mMMMMMm.", "..mmmmm..", ".........", "........."], "eggsOn": 3},
]
const CHAPTERS := [{"name": "Vườn Xoài Cái Bè", "sub": "Mùa trái chín", "from": 0, "to": 9, "tint": "#7fb24a"}, {"name": "Chợ Nổi Cái Răng", "sub": "Ghe xuồng tấp nập", "from": 10, "to": 19, "tint": "#4a9ab0"}, {"name": "Đồng Lúa Tháp Mười", "sub": "Điên điển trổ bông", "from": 20, "to": 29, "tint": "#d9a83a"}]
const MED := [11620, 20630, 26960, 14200, 17750, 27630, 13000, 40170, 16980, 41760, 16840, 20770, 14000, 26580, 13000, 16000, 19000, 17000, 20170, 33000, 10570, 25000, 13410, 26000, 14000, 20000, 16000, 20000, 27000, 25000]

const FRUITS := [
	{"key": "xoai", "name": "Xoài cát", "col": "#f7b820", "juice": ["#ffe066", "#ffc42e", "#ffef9a"], "ink": "#a85a0c"},
	{"key": "quyt", "name": "Quýt hồng", "col": "#f57a1c", "juice": ["#ffb050", "#ff8a2a", "#ffd29a"], "ink": "#a3400c"},
	{"key": "chom", "name": "Chôm chôm", "col": "#e02f38", "juice": ["#ff6a5a", "#e8323c", "#ffd0c8"], "ink": "#7a0e1e"},
	{"key": "mang", "name": "Măng cụt", "col": "#8a2f7c", "juice": ["#c36ab4", "#9a3d8c", "#f4e2ef"], "ink": "#2e0a28"},
	{"key": "buoi", "name": "Bưởi da xanh", "col": "#5fae36", "juice": ["#a6e06a", "#6cbb3c", "#fde2d4"], "ink": "#24561c"},
	{"key": "dua", "name": "Dừa Bến Tre", "col": "#8a5a2e", "juice": ["#fffaf0", "#efe6d2", "#cfe7e2"], "ink": "#4a2c12"},
]

static func r5(v: float) -> int:
	return maxi(500, int(round(v / 500.0)) * 500)

static func stars_of(i: int) -> Array:
	var L: Dictionary = LEVELS[i]
	var m: float = MED[i] if i < MED.size() else 10000.0
	var sg := 0
	for g in L.goals:
		if g.has("score"):
			sg = int(g.score)
	if sg > 0:
		return [sg, r5(maxf(sg * 1.35, m * 0.95)), r5(maxf(sg * 1.8, m * 1.3))]
	return [r5(m * 0.5), r5(m * 0.9), r5(m * 1.3)]

static func chapter_of(i: int) -> Dictionary:
	for c in CHAPTERS:
		if i >= c.from and i <= c.to:
			return c
	return CHAPTERS[0]

# ---------- dựng vườn (08b_garden.js)
const SPOTS := [
	{"id": "nha1", "c": 0, "k": "nha", "n": "Nhà lá ông Tư", "cost": 3, "f": 0.12},
	{"id": "xoai1", "c": 0, "k": "xoai", "n": "Cây xoài cát", "cost": 2, "f": 0.26},
	{"id": "gieng", "c": 0, "k": "gieng", "n": "Cái giếng", "cost": 3, "f": 0.42},
	{"id": "chuong", "c": 0, "k": "chuong", "n": "Chuồng gà", "cost": 3, "f": 0.56},
	{"id": "xoai2", "c": 0, "k": "xoai", "n": "Cây xoài cát", "cost": 2, "f": 0.7},
	{"id": "cong", "c": 0, "k": "cong", "n": "Cổng vườn", "cost": 2, "f": 0.86},
	{"id": "ben", "c": 1, "k": "ben", "n": "Bến ghe", "cost": 3, "f": 0.12, "on": "bank"},
	{"id": "dua1", "c": 1, "k": "dua", "n": "Cây dừa", "cost": 2, "f": 0.26},
	{"id": "cau", "c": 1, "k": "cau", "n": "Cầu khỉ", "cost": 4, "f": 0.42, "on": "bridge"},
	{"id": "quan", "c": 1, "k": "quan", "n": "Quán nước", "cost": 3, "f": 0.58},
	{"id": "ghe", "c": 1, "k": "ghe", "n": "Ghe chở trái", "cost": 3, "f": 0.72, "on": "water"},
	{"id": "dua2", "c": 1, "k": "dua", "n": "Cây dừa", "cost": 2, "f": 0.86},
	{"id": "ruong1", "c": 2, "k": "ruong", "n": "Thửa ruộng", "cost": 3, "f": 0.12},
	{"id": "rom", "c": 2, "k": "rom", "n": "Đụn rơm", "cost": 2, "f": 0.26},
	{"id": "bunhin", "c": 2, "k": "bunhin", "n": "Ông bù nhìn", "cost": 2, "f": 0.42},
	{"id": "ruong2", "c": 2, "k": "ruong", "n": "Thửa ruộng", "cost": 3, "f": 0.56},
	{"id": "dien", "c": 2, "k": "dien", "n": "Bụi điên điển", "cost": 3, "f": 0.7},
	{"id": "mieu", "c": 2, "k": "mieu", "n": "Miếu nhỏ", "cost": 4, "f": 0.86},
]
const GIFT := {"cuoc": 2, "trau": 1, "doi": 2}
const BOX := {"nha": [-1.25, -1.55, 1.25, 0.3], "xoai": [-1.1, -2.05, 1.1, 0.3], "dua": [-1.25, -2.4, 1.25, 0.3], "gieng": [-1.1, -1.6, 1.1, 0.3],
	"chuong": [-1.2, -1.45, 1.2, 0.3], "cong": [-1.3, -1.6, 1.3, 0.3], "ghe": [-1.15, -0.95, 1.15, 0.3], "quan": [-1.2, -1.45, 1.2, 0.3],
	"ben": [-1.1, -1.25, 1.1, 0.35], "ruong": [-1.3, -0.75, 1.3, 0.25], "rom": [-1.05, -1.3, 1.05, 0.3], "bunhin": [-1.05, -1.7, 1.05, 0.3],
	"dien": [-1.1, -1.4, 1.1, 0.3], "mieu": [-0.95, -1.4, 0.95, 0.3]}

# ---------- nông trại (08c_farm.js)
const ITEMS := {"0": {"n": "Xoài", "p": 1}, "1": {"n": "Quýt", "p": 1}, "2": {"n": "Chôm chôm", "p": 1}, "3": {"n": "Măng cụt", "p": 2},
	"4": {"n": "Bưởi", "p": 2}, "5": {"n": "Dừa", "p": 2}, "rom": {"n": "Rơm", "p": 1}, "trung": {"n": "Trứng vịt", "p": 6}, "cam": {"n": "Cám", "p": 15}}
const PETS := [
	{"k": "trau", "n": "Trâu cày", "sp": "Trái khăn rằn", "eat": {"rom": 8}, "lv": ["Cày 1 hàng", "Cày 2 hàng", "Cày 3 hàng"]},
	{"k": "heo", "n": "Heo ụp", "sp": "Trái gói lá", "eat": {"cam": 2, "5": 10}, "lv": ["Ụp quanh 2 ô", "Ụp vuông 5×5", "Ụp rộng 3 ô"]},
	{"k": "vit", "n": "Vịt bay", "sp": "Trái ráp vuông", "eat": {"cam": 3}, "lv": ["1 con bay đi", "2 con bay đi", "3 con bay đi"]},
	{"k": "trong", "n": "Gà trống", "sp": "Ráp 5 trái", "eat": {"cam": 4}, "lv": ["Gáy một loại trái", "Gáy loại nhiều nhất", "Gáy 2 loại trái"]},
]
const FEEDS := [3, 5]
const MERCH := ["cô Ba", "chú Tư", "dì Năm", "anh Sáu", "bà Bảy", "chị Tám", "ông Chín"]
const SHOP := [{"k": "cam", "n": "1 bao cám", "cost": 15, "give": {"cam": 1}}, {"k": "rom", "n": "10 bó rơm", "cost": 25, "give": {"rom": 10}},
	{"k": "b_cuoc", "n": "Cuốc", "cost": 60, "boost": "cuoc"}, {"k": "b_trau", "n": "Trâu cày", "cost": 90, "boost": "trau"}, {"k": "b_doi", "n": "Đổi chỗ", "cost": 75, "boost": "doi"}]

const PRAISE := ["", "", "", "Ngon!", "Đã quá!", "Hết sẩy!", "Bá cháy!", "Trùm miệt vườn!"]
const HELPER := {"h": "trau", "v": "trau", "bomb": "heo", "duck": "vit", "rooster": "trong"}
const CHEER_WORD := {"trau": "Ụmm bò!", "heo": "Ụt ịt!", "trong": "Ò ó o!", "vit": "Cạp cạp!"}

# ---------- srand của web (xorshift 32 bit), để vẽ bản đồ giống y
class SRand:
	var s: int
	func _init(seed: int) -> void:
		s = seed & 0xffffffff
		if s == 0:
			s = 1
	func r() -> float:
		s = (s ^ (s << 13)) & 0xffffffff
		var sh := s >> 17
		if s & 0x80000000:
			sh |= 0xffff8000   # JS: s>>17 dịch có dấu (int32)
		s = (s ^ sh) & 0xffffffff
		s = (s ^ (s << 5)) & 0xffffffff
		return float(s) / 4294967296.0
