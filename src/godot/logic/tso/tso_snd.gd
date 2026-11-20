extends "res://logic/cg/cg_snd.gd"
# TÌM SỐ: tiếng động tổng hợp (dùng chung bộ máy của Cờ gánh): bút bi khoanh số (sột soạt), chạm nhầm, thắng / thua.

func _build() -> void:
	super._build()
	# bút bi xoẹt một vòng: tiếng ồn dải cao, to nhỏ theo nhịp tay
	_add("scrib", 0.4, func(B):
		for i in 4:
			_noise(B, 2600 + randf() * 1400, 2.5, 0.07 + randf() * 0.03, 0.08, "bandpass", i * 0.075 + randf() * 0.01)
		_noise(B, 900, 1.0, 0.04, 0.25, "lowpass"), 4)
	_add("buzz", 0.3, func(B): _tone(B, 180, 0.09, 0.18, "square", 0, 0.8); _noise(B, 400, 1, 0.05, 0.1, "lowpass"))

func scribble() -> void: _play("scrib", 0.9)
func buzz() -> void: _play("buzz", 0.7)
