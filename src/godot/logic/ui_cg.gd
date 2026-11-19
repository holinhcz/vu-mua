extends RefCounted
# CỜ GÁNH (#cgBtn trong nhóm Giải trí của Menu), chép từ bản web (nong-trai-chung/src/coganh/patch_coganh.py):
# bàn cờ là trang riêng coganh/index.html nằm cạnh index.html của bản web Godot (nhánh main). Bấm nút thì trang vỏ phủ một
# lớp full màn hình, tải trang đó vào iframe (srcdoc); "Về vườn" trong bàn cờ đóng lớp phủ.
# Thắng máy được xu như web: Bé Út 20, Thằng Tí 50, Chị Hai 120, Ông Sáu 250, chỉ 5 ván thắng đầu mỗi ngày (g.cg {d, n}).
# Lúc đang chơi cờ: game Godot vẽ 4 khung/giây và tắt tiếng (web: window.NTFREEZE + tạm dừng âm thanh), đóng là trả lại.
# Tin nhắn bàn cờ -> trang vỏ (postMessage {cg:1, t}) được trang vỏ xếp vào window.__cgq, Godot đọc mỗi 0,2 giây
# (lấy ra bằng splice, không gán mảng mới: trang vỏ luôn đẩy vào window.__cgq hiện tại).

const REW := [20, 50, 120, 250]
const MAXD := 5
const VER := "d5b0aed6"   # crc32 của coganh/index.html đang đăng (đổi bàn cờ thì đổi số này để máy khỏi giữ bản cũ)

const JS_OPEN := """(function(){if(window.__cgov)return;function q(){return window.__cgq||(window.__cgq=[])}
var ov=document.createElement('div');ov.style.cssText='position:fixed;inset:0;z-index:2147483600;background:#a88a66;touch-action:none';
ov.setAttribute('role','dialog');ov.setAttribute('aria-label','Cờ gánh');
ov.innerHTML='<div class="cgld" style="position:absolute;inset:0;display:grid;place-items:center;font:800 18px/1.2 Nunito,system-ui,sans-serif;color:#fff8e6;text-shadow:0 2px 0 rgba(60,30,10,.6)">Đang kẻ bàn cờ…</div>';
document.body.appendChild(ov);window.__cgov=ov;var fr=null;
function close(why){if(window.__cgov!==ov)return;window.removeEventListener('message',onm);ov.remove();window.__cgov=null;window.__cgfr=null;
  q().push({t:'close',why:why||''});var c=document.querySelector('canvas');try{c&&c.focus()}catch(e){}}
function onm(e){var d=e.data;if(!fr||e.source!==fr.contentWindow||!d||d.cg!==1)return;
  if(d.t==='close'){close('');return}
  if(d.t==='end')q().push({t:'end',mode:String(d.mode||''),level:d.level|0,winner:+d.winner})}
window.addEventListener('message',onm);
function go(h){if(window.__cgov!==ov)return;fr=document.createElement('iframe');fr.title='Cờ gánh';fr.setAttribute('allow','autoplay');
  fr.style.cssText='position:absolute;inset:0;width:100%;height:100%;border:0;display:block';fr.srcdoc=h;ov.appendChild(fr);window.__cgfr=fr;
  fr.addEventListener('load',function(){var l=ov.querySelector('.cgld');l&&l.remove();try{fr.contentWindow.focus()}catch(e){}})}
if(window.__cgsrc){go(window.__cgsrc);return}
fetch('coganh/index.html?v=@VER@').then(function(r){if(!r.ok)throw 0;return r.text()}).then(function(h){
  window.__cgsrc=h.replace('<head>','<head><script>window.__cgFarm=1<\\/script>');go(window.__cgsrc)}).catch(function(){close('fail')})})()"""

var ui
# static: giao diện dựng lại (xoay máy, đổi khổ) tạo ui mới mà bàn cờ vẫn mở, trạng thái phải còn để đóng lại cho đúng
static var on := false
static var _fps := 0
static var _mute := false
var _t := 0.0

func _init(u) -> void:
	ui = u

func open() -> void:
	if on:
		return
	if not OS.has_feature("web"):
		ui.say("Cờ gánh chỉ mở được trên bản web.")
		return
	on = true
	_t = 0.0
	JavaScriptBridge.eval(JS_OPEN.replace("@VER@", VER), true)
	_fps = Engine.max_fps
	Engine.max_fps = 4
	_mute = AudioServer.is_bus_mute(0)
	AudioServer.set_bus_mute(0, true)

func _closed(why: String) -> void:
	on = false
	Engine.max_fps = _fps
	AudioServer.set_bus_mute(0, _mute)
	if why == "fail":
		ui.say("Chưa mở được bàn cờ, thử lại sau nghen.")

func _day() -> String:   # web day(): năm-tháng-ngày theo giờ máy, không thêm số 0
	var d := Time.get_date_dict_from_system()
	return "%d-%d-%d" % [d.year, d.month, d.day]

func _cgs() -> Dictionary:   # web cgs()
	var c = G().g.get("cg")
	if not (c is Dictionary) or String(c.get("d", "")) != _day():
		c = {"d": _day(), "n": 0}
		G().g["cg"] = c
	return c

func G() -> Node:
	return ui.G

func _end(m: Dictionary) -> void:   # web d.t==="end"
	var xu := 0
	var c := _cgs()
	if String(m.get("mode", "")) == "ai" and int(m.get("winner", -1)) == 0 and int(c.n) < MAXD:
		xu = int(REW[int(m.get("level", 0))]) if int(m.get("level", 0)) >= 0 and int(m.get("level", 0)) < REW.size() else 20
		c.n = int(c.n) + 1
		G().g.coins = int(G().g.coins) + xu
		G().mark()
	JavaScriptBridge.eval("(function(){var f=window.__cgfr;try{f&&f.contentWindow.postMessage({cg:1,t:'reward',xu:%d,left:%d,max:%d},'*')}catch(e){}})()"
		% [xu, MAXD - int(c.n), MAXD], true)

func step(dt: float) -> void:
	if not on:
		return
	_t -= dt
	if _t > 0.0:
		return
	_t = 0.2
	var s = JavaScriptBridge.eval("(function(){var q=window.__cgq||[];return JSON.stringify(q.splice(0,q.length))})()", true)
	var a = JSON.parse_string(str(s)) if s != null else null
	if not (a is Array):
		return
	for m in a:
		if not (m is Dictionary):
			continue
		if m.get("t", "") == "end":
			_end(m)
		elif m.get("t", "") == "close":
			_closed(String(m.get("why", "")))
