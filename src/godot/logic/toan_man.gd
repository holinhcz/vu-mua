extends RefCounted
# TOÀN MÀN HÌNH (viết mới): cho CẢ TRANG lên toàn màn hình (document.documentElement.requestFullscreen), không dùng
# DisplayServer.window_set_mode của Godot (Godot cho riêng thẻ canvas lên toàn màn hình nên trình duyệt kéo giãn
# ảnh -> mờ trên máy tính). Trang lên toàn màn thì chỉ như cửa sổ to ra: Godot dựng lại khung vẽ theo đúng số điểm
# ảnh mới (canvasResizePolicy 2), nét như lúc thường.
# Gọi bật / tắt ngay trong lúc bấm nút (trình duyệt chỉ cho bật toàn màn khi người chơi vừa chạm / bấm).

static func _web() -> bool:
	return OS.has_feature("web")

static func co() -> bool:   # trình duyệt cho bật toàn màn hình không (iPhone Safari, khung nhúng chặn thì không)
	if not _web():
		return true
	var v = JavaScriptBridge.eval("(function(){var d=document,e=d.documentElement;return !!(d.fullscreenEnabled||d.webkitFullscreenEnabled)&&!!(e.requestFullscreen||e.webkitRequestFullscreen)})()")
	return bool(v)

static func dang_bat() -> bool:
	if not _web():
		var m := DisplayServer.window_get_mode()
		return m == DisplayServer.WINDOW_MODE_FULLSCREEN or m == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	return bool(JavaScriptBridge.eval("!!(document.fullscreenElement||document.webkitFullscreenElement)"))

static func bat() -> bool:   # true = đã gửi yêu cầu (trình duyệt có thể vẫn từ chối)
	if not _web():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return true
	if not co():
		return false
	JavaScriptBridge.eval("(function(){var e=document.documentElement,f=e.requestFullscreen||e.webkitRequestFullscreen;try{var p=f.call(e,{navigationUI:'hide'});if(p&&p.catch)p.catch(function(){window.__tmLoi=1})}catch(x){window.__tmLoi=1}})()")
	return true

static func tat() -> void:
	if not _web():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		return
	JavaScriptBridge.eval("(function(){var d=document,f=d.exitFullscreen||d.webkitExitFullscreen;if((d.fullscreenElement||d.webkitFullscreenElement)&&f){try{var p=f.call(d);if(p&&p.catch)p.catch(function(){})}catch(x){}}})()")

static func bi_tu_choi() -> bool:   # trình duyệt từ chối lần bật vừa rồi (đọc một lần rồi xóa)
	if not _web():
		return false
	return bool(JavaScriptBridge.eval("(function(){var v=!!window.__tmLoi;window.__tmLoi=0;return v})()"))
