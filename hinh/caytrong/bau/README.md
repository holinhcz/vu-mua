# bau
Cắt nguyên điểm ảnh (không thu nhỏ, không nén mất) từ ảnh gốc 9 px/đơn vị của game web, mỗi khung 1 file PNG.
Tên file: chữ đầu d = ngày, n = đêm; số cuối = giai đoạn / dáng (theo khoá gốc của game).
atlas.json: w,h = cỡ ảnh (px); ox,oy = góc trên trái của ảnh so với điểm neo (đơn vị game, neo = tâm ô đất);
gw,gh = cỡ vẽ trong game (đơn vị game) = w/9, h/9. Godot: Sprite2D centered=false, offset=(ox,oy), scale=1/9 nếu 1 đơn vị game = 1 px.
