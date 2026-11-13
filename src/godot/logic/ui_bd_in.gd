extends Node
# chuyển sự kiện vào bảng Xây dựng (cuộn lưới thẻ), tách khỏi ui._input
var bd
func _input(e: InputEvent) -> void:
	if bd != null:
		bd.input(e)
