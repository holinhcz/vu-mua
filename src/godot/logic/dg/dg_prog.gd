extends RefCounted
# ĐUA GÀ: tiến trình riêng (save của web 'duaga-save-v1' + kỷ lục + bóng ma), giữ trong save nông trại ở g.dgsv
# (lưu chung với game, lên mây theo game). Xu đua riêng như web: đua ăn xu, mua đồ ăn lên chỉ số và đồ đội.
# Giải Làng 3 chặng, nhiệm vụ hằng ngày (3 việc bốc theo ngày), mở map / gà bằng cúp.

const FEEDS := [{"k": "spd", "food": "Lúa", "stat": "Tốc độ"}, {"k": "acc", "food": "Giun", "stat": "Tăng tốc"}, {"k": "turn", "food": "Rau", "stat": "Bẻ lái"}]
const FEED_COST := [30, 60, 100, 150, 220]
const FEED_STEP := 0.025
const FEED_MAX := 5
const CUP_PTS := [10, 7, 5, 3, 2, 1]
const EARN := [60, 45, 35, 25, 15, 10]
const DIFF_K := [0.7, 1.0, 1.4]

var S: Dictionary
var save_fn := Callable()
var maps: Array = []       # dg_card meta: {id, name, sub, banner, tod, music, unlock, fall}
var hats: Array = []
var stages: Array = []
var pool: Array = []       # nhiệm vụ
var done_now: Array = []   # nhiệm vụ xong trong ván này

func _init(save: Dictionary, sf: Callable) -> void:
	S = save
	save_fn = sf
	for k in ["up", "hatOf", "cups", "best", "tt"]:
		if not (S.get(k) is Dictionary):
			S[k] = {}
	if not (S.get("hats") is Array):
		S.hats = []
	if not S.has("coins"):
		S.coins = 0
	if not S.has("map"):
		S.map = "nongtrai"

func set_data(m: Dictionary) -> void:
	maps = m.get("maps", [])
	hats = m.get("hats", [])
	stages = m.get("stages", [])
	pool = m.get("missions", [])

func persist() -> void:
	if save_fn.is_valid():
		save_fn.call()

func coins() -> int:
	return int(S.coins)

func map_def(id: String) -> Dictionary:
	for m in maps:
		if m.id == id:
			return m
	return maps[0] if maps.size() else {"id": "nongtrai", "name": "Nông Trại", "tod": "day", "music": 0}

func map_name(id: String) -> String:
	return String(map_def(id).get("name", id))

# con gà / map có "unlock": thắng Giải Làng ở map đó mới mở
func unlocked(x: Dictionary) -> bool:
	var u = x.get("unlock")
	return u == null or String(u) == "" or bool(S.cups.get(String(u), false))

func up_of(id: String, k: String) -> int:
	return int(S.up.get(id, {}).get(k, 0))

func stat_of(ch: Dictionary, k: String) -> float:
	return float(ch[k]) * (1 + FEED_STEP * up_of(String(ch.id), k))

func feed(id: String, k: String) -> bool:
	var lv := up_of(id, k)
	if lv >= FEED_MAX or coins() < int(FEED_COST[lv]):
		return false
	S.coins = coins() - int(FEED_COST[lv])
	var u: Dictionary = S.up.get(id, {}).duplicate()
	u[k] = lv + 1
	S.up[id] = u
	persist()
	return true

func hat_of(id: String) -> String:
	var h = S.hatOf.get(id)
	return "" if h == null else String(h)

# bấm nút nón: chưa có thì mua và đội luôn; có rồi thì đội / cởi
func hat_tap(id: String, h: Dictionary) -> bool:
	var own: bool = S.hats.has(h.id)
	if not own:
		if coins() < int(h.cost):
			return false
		S.coins = coins() - int(h.cost)
		S.hats.append(h.id)
		S.hatOf[id] = h.id
	else:
		S.hatOf[id] = null if hat_of(id) == String(h.id) else h.id
	persist()
	return true

# ---- nhiệm vụ hằng ngày
static func today() -> String:
	var d := Time.get_date_dict_from_system()
	return "%d-%d-%d" % [d.year, d.month, d.day]

func ensure_daily() -> void:
	var day := today()
	if S.get("daily") is Dictionary and String(S.daily.get("day", "")) == day:
		return
	var h := 7
	for c in day.to_utf8_buffer():
		h = (h * 31 + c) & 0x7fffffff
	var rg := RandomNumberGenerator.new()
	rg.seed = h
	var pl := pool.duplicate()
	var list := []
	for q in 3:
		if pl.is_empty():
			break
		var m: Dictionary = pl.pop_at(rg.randi() % pl.size())
		var lv: int = rg.randi() % m.ns.size()
		list.append({"k": m.k, "n": int(m.ns[lv]), "rw": int(m.rw[lv]), "p": 0, "done": false})
	S.daily = {"day": day, "list": list}
	persist()

func mission_text(m: Dictionary) -> String:
	for q in pool:
		if q.k == m.k:
			return String(q.t).replace("{n}", str(m.n))
	return String(m.k)

# một việc làm được: trả về các nhiệm vụ vừa xong (để báo, ăn xu liền)
func mission(k: String) -> Array:
	ensure_daily()
	var out := []
	var ch := false
	for m in S.daily.list:
		if m.k != k or m.done:
			continue
		m.p = int(m.p) + 1
		ch = true
		if int(m.p) >= int(m.n):
			m.done = true
			S.coins = coins() + int(m.rw)
			done_now.append(m)
			out.append(m)
	if ch:
		persist()
	return out

# ---- kỷ lục, bóng ma (theo map)
func best(mid: String) -> Dictionary:
	return S.best.get(mid, {})

func ghost(mid: String):
	return S.tt.get(mid)

static func fmt(t: float) -> String:
	var m := floori(t / 60)
	var s := fmod(t, 60.0)
	return "%d:%s%.2f" % [m, "0" if s < 10 else "", s]

# ---- tổng kết ván (showResults của web). R = luật đua, cup = {stage, pts} hoặc null, mid = map
# trả về {title, sub, stage, rows: [{r, pts, rank}], kind: single/cup/tt, notes: [dòng], podium: [r], next: bool, win: bool}
func results(R, cup, mid: String, dif: int, chars: Array) -> Dictionary:
	var pl = R.player
	var s: Array = R.racers.duplicate()
	s.sort_custom(func(a, b): return a.rank < b.rank)
	var out := {"kind": "single", "rows": [], "notes": [], "podium": [], "next": false, "stage": "", "title": "", "sub": "", "win": false}
	var mline := ""
	if R.tt:
		var prev = ghost(mid)
		var rec: bool = prev == null or pl.finT < float(prev.t)
		if rec:
			S.tt[mid] = {"t": pl.finT, "ch": pl.id, "g": R.ghost_rec.duplicate()}
		var earn := 20 + (40 if rec and prev != null else 0)
		S.coins = coins() + earn
		persist()
		out.kind = "tt"
		out.stage = "Đua tính giờ"
		out.title = ((("Kỷ lục mới! " if prev != null else "Kỷ lục đầu tiên: ") if rec else "Về đích: ") + fmt(pl.finT))
		out.podium = [pl]
		for i in mini(pl.lapTimes.size(), R.laps):
			out.rows.append({"lap": i + 1, "t": pl.lapTimes[i]})
		out.notes.append("+%d xu (đang có %d xu)." % [earn, coins()])
		_mis_notes(out)
		if prev != null:
			var dlt: float = pl.finT - float(prev.t)
			out.notes.append(("Nhanh hơn kỷ lục cũ %.2f giây. Lần sau bóng ma sẽ chạy theo lần này." % -dlt) if dlt < 0 else ("Chậm hơn kỷ lục %.2f giây (%s). Bóng ma vẫn giữ lần cũ." % [dlt, fmt(float(prev.t))]))
		else:
			out.notes.append("Lần sau sẽ có bóng ma của lần chạy này chạy cùng.")
		out.win = rec
		return out
	var place: int = pl.place
	out.title = "Về nhất!" if place == 1 else "Về thứ %d" % place
	out.sub = "Gà nhà mày đỉnh thật" if place == 1 else ("Lên bục rồi, ráng chút nữa là nhất" if place <= 3 else "Đua lại gỡ gạc không?")
	var earn := roundi(EARN[place - 1] * DIFF_K[dif])
	var cup_line := ""
	var cup_done := false
	if cup != null:
		for i in s.size():
			var id: String = s[i].id
			cup.pts[id] = int(cup.pts.get(id, 0)) + CUP_PTS[i]
		cup.stage = int(cup.stage) + 1
		cup_done = cup.stage >= stages.size()
		var order: Array = R.racers.duplicate()
		order.sort_custom(func(a, b): return int(cup.pts.get(a.id, 0)) > int(cup.pts.get(b.id, 0)))
		out.kind = "cup"
		out.stage = "Giải Làng · Tổng kết" if cup_done else String(stages[cup.stage - 1].name) + " · xong"
		for r in order:
			out.rows.append({"r": r, "pts": int(cup.pts.get(r.id, 0)), "rank": r.rank + 1})
		if cup_done:
			var cp := order.find(pl)
			var bonus: int = [150, 90, 50][cp] if cp < 3 else 0
			earn += bonus
			out.title = ("Vô địch Giải Làng " + map_name(mid) + "!") if cp == 0 else "Hạng %d Giải Làng" % (cp + 1)
			out.podium = order.slice(0, 3)
			if bonus:
				cup_line = "Thưởng cúp: +%d xu." % bonus
			if cp == 0 and not bool(S.cups.get(mid, false)):
				S.cups[mid] = true
				var got := []
				for m in maps:
					if str(m.get("unlock", "")) == mid:
						got.append("đường đua " + String(m.name))
				for c in chars:
					if str(c.get("unlock", "")) == mid:
						got.append(String(c.name))
				if mid == "choque" and not S.hats.has("vuong"):
					S.hats.append("vuong")
					got.append("Vương miện (tặng)")
				if got.size():
					cup_line += " Mở khóa: " + ", ".join(got) + "!"
					out.unlock = true
		else:
			out.podium = s.slice(0, 3)
	else:
		for r in s:
			out.rows.append({"r": r})
		out.podium = s.slice(0, 3)
	var laps: Array = pl.lapTimes.slice(0, R.laps)
	var fl := 1e9
	for t in laps:
		fl = minf(fl, t)
	var bk: Dictionary = best(mid).duplicate()
	var rec_notes := []
	if not bk.has("total") or pl.finT < float(bk.total):
		if bk.has("total"):
			rec_notes.append("Kỷ lục mới cả ván!")
		bk.total = pl.finT
		bk.ch = String(pl.ch.name)
	if laps.size() and (not bk.has("lap") or fl < float(bk.lap)):
		if bk.has("lap"):
			rec_notes.append("Kỷ lục vòng mới!")
		bk.lap = fl
	S.best[mid] = bk
	if rec_notes.size():
		earn += 20
	if place <= 3:
		mission("top3")
	if place == 1:
		mission("win")
	S.coins = coins() + earn
	persist()
	out.notes.append(("+%d xu (đang có %d xu). " % [earn, coins()]) + cup_line)
	_mis_notes(out)
	if laps.size():
		var ls := []
		for t in laps:
			ls.append(fmt(t))
		out.notes.append("Từng vòng: " + " · ".join(ls))
	out.notes.append("Kỷ lục của mày: cả ván %s (%s) · vòng nhanh nhất %s" % [fmt(float(bk.total)), String(bk.ch), fmt(float(bk.lap)) if bk.has("lap") else "chưa có"])
	if rec_notes.size():
		out.notes.append(" ".join(rec_notes))
	out.next = cup != null and not cup_done
	out.win = place <= 3
	out.cup_done = cup_done
	return out

func _mis_notes(out: Dictionary) -> void:
	if done_now.size():
		var ls := []
		for m in done_now:
			ls.append("%s (+%d xu)" % [mission_text(m), int(m.rw)])
		out.notes.append("Xong nhiệm vụ: " + " · ".join(ls))
