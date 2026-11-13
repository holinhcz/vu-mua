# Cây cảnh 1 ô (v759/760, 2026-11-07)

Link: "loại nào to thì vẽ cỡ to 1 ô". The big kinds of the Hoa cỏ tab are whole-tile og items (cat "hoaco", b:1, vars 4):
bông trang (4 colours), hoa lài, hướng dương, lưỡi hổ, nha đam, xương rồng tai thỏ, bụi sả. The small new kinds
(dạ yến thảo, mai địa thảo, móng tay, cúc lá nho, ớt kiểng, húng quế, cỏ lan chi) stay quarter-tile minis in ../hoaco.

- `caycanh.py`: KU 29*1.12 like the fern. Bông trang and lài are shrubs on the hibiscus dome (subclass of
  ../dambut Dambut + hoaco.Mini primitives). The patch kinds are hoaco models placed and scaled through `Sub`
  (a painter with move+scale; wk thins line widths). hoaco.BIG lists the hoaco models used only here (not in the mini sheet).
- preview: `python3 caycanh.py ids|all x out.png`; sheet: `python3 caycanh.py atlas OUTDIR OUTDIR/caycanh.json`
- game: `python3 patch_caycanh.py in.html atlas.json out.html` (block before og, per-kind bb, x$ no-cast, fallback
  wildbush/tallgrass), then `../hoaco/patch_hoaco.py` (adds the new minis to LM + iq stubs, REV hc4).
Picture: ../../xem/hoaco-v759.jpg
