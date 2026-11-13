# Lửa xưởng – chuẩn chung (đọc trước khi làm lửa cho bất kỳ xưởng nào)

Mọi lửa xưởng = CPUParticles2D do Godot sinh, KHÔNG vẽ sẵn trong ảnh. Gốc là lửa lò bánh mì
(`lobanhmi/README.md`, mục "Lửa trong lò"; code `src/lobanhmi/luafx.py`):
texture `<xưởng>_lua.webp` (lưỡi lửa trắng 64x96), blend ADD, unshaded, angle ±14°, angular_velocity ±45 °/s,
split_scale + đường cong scale_x/scale_y, color_ramp đỏ cam (không vàng). Những thứ này KHÔNG được đổi.
Thứ tự vẽ: ảnh `r` → hạt lửa → ảnh `che` (che hết, chỉ chừa miệng lò) → khung `f` → hơi → khói. Không dùng clip_children.
Miệng lò trong ảnh `r` tối (bồ hóng, đỏ sẫm sát than như `em_holelit` lò bánh mì), để hạt lửa cộng sáng lên mới ra màu.

## Lửa trong miệng bếp / cà ràng (chuẩn từ Link 2026-11-12 17:10 VN "lửa to trong lò", lò bánh quê)
Lửa to, đầy miệng, không lan ra ngoài (ảnh `che` cắt):
- amount 90 cho 2 miệng, lifetime 0.7 s, preprocess 0.7 s, randomness 0.5, spread 10°
- initial_velocity 6 → 11.5 đơn vị/s, gravity (0, -7.5)
- scale_amount 0.036 → 0.063 (luafx scale 1.0 → 1.75, lưỡi rộng 2.3 → 4 đơn vị)
- điểm phát `lua`: 3 hàng x 6 điểm mỗi miệng trên lớp than, hàng ngoài sát miệng
- trong `gif.py`: `luafx.LUA_P.update(amount=90, velocity=(6.0, 11.5), gravity=(0.0, -7.5), scale=(1.0, 1.75))`

## Lửa dưới kiềng ông táo (lửa hở, bếp củi kiểu kiềng)
- amount 110 cho 2 bếp (55 mỗi bếp), lifetime 0.55 s, spread 22°, initial_velocity 3.5 → 6.5, gravity (0, -5), scale 0.65 → 1.2

## Xưởng đang dùng số nào (2026-11-12)
| Xưởng | Lửa |
|---|---|
| lobanh (lò bánh quê), noikho (nồi kho) | chuẩn miệng bếp ở trên (amount 90, 2 miệng) |
| quanche, hangcha, btrang | chuẩn miệng bếp ở trên, amount 45 (1 miệng), 3 hàng x 6 điểm (đồng bộ 11-12 22:21) |
| bepcui, rang, duong (lò đường) | chuẩn kiềng (amount 110) |
| muoi | chuẩn kiềng, amount 55 (1 bếp) (đồng bộ 11-12 22:31) |
| lobanhmi | gốc, amount 54, 1 miệng lò lớn |

**Khi Link sửa lửa ở 1 xưởng: ghi vào file này + README từng xưởng bị ảnh hưởng, để mọi xưởng đồng bộ.**
