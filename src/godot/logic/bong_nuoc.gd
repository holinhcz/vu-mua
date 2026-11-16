extends Sprite2D
# BÓNG DƯỚI NƯỚC (bản 179): hình soi ngược của một món đứng trên mặt nước (sông, kênh, ao, rạch): ghe, xuồng, lục bình,
# sen, súng, thuyền, cầu, bến... Dùng chung một kiểu: BongNuoc.add(main, hình, chỗ) là xong.
# Là node con của hình gốc, lật dọc quanh đường chân (fy, toạ độ riêng của hình) nên đi theo món (trôi, nhấp nhô, zoom) mà
# không tốn gì mỗi khung; chỉ chép lại ảnh khi hình gốc đổi ảnh (zoom, góc ghe). Vẽ bằng vật liệu + lớp (z) của bộ bóng cây
# sông / ao bên nền (main.refl_set_at): cắt đúng mặt nước, lay theo sóng, phai dần, tối theo đêm, theo nước nổi.

var M                    # main.gd
var src: Sprite2D
var at                   # "r" (sông), "p" (ao, kênh) hoặc điểm làng (Vector2) để dò
var fy := 0.0            # đường chân, theo toạ độ riêng của hình gốc
var foot: Node2D = null  # có thì đường chân = chỗ node này (tính lại mỗi lần đổi ảnh)

static func add(main, s: Sprite2D, where, y := 0.0, ft: Node2D = null) -> void:
	var b = load("res://logic/bong_nuoc.gd").new()
	b.M = main
	b.src = s
	b.at = where
	b.fy = y
	b.foot = ft
	b.visible = false
	b.z_as_relative = false
	s.add_child(b)
	s.texture_changed.connect(b._sync, CONNECT_DEFERRED)
	if not b.place():
		main.refl_wait.append(b)

func place() -> bool:   # true: xong (có lớp bóng, hoặc không ở trên nước thì bỏ); false: chờ bản đồ nước
	if not is_instance_valid(src):
		return true
	var r = M.refl_set_at(at)
	if r == null:
		queue_free()
		return true
	if not (r is Node2D):
		return false
	material = r.material
	z_index = r.z_index + 1   # cùng z với nước thì vẽ theo thứ tự cây node, obj_root đứng trước nước nên bị nước che: nhích lên 1
	visible = true
	_sync()
	return true

func _sync() -> void:
	if not is_instance_valid(src):
		return
	texture = src.texture
	offset = src.offset
	centered = src.centered
	flip_h = src.flip_h
	if foot != null and is_instance_valid(foot) and src.is_inside_tree() and foot.is_inside_tree():
		fy = src.to_local(foot.global_position).y
	transform = Transform2D(Vector2(1, 0), Vector2(0, -1), Vector2(0, 2.0 * fy))
