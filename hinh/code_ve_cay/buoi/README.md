# Pomelo tree (cây bưởi), v655

Link asked for this on 2026-11-04. I drew it from the real miền Tây orchard trees; the game's old tree only set the size
and where it grows. It follows the "k2" scheme of 2 shapes × unripe/ripe. Before/after picture:
`../../xem/buoi-truoc-sau.jpg`.

- **Shape 0, bưởi da xanh.** A short trunk forks low into three limbs under a dense round crown that is a little taller
  than wide. The fruit is round with a flat top.
- **Shape 1, bưởi Năm Roi.** An older tree with a wider, more open crown. The fruit is pear shaped with a neck.
- **Leaves.** They are simple, broad and oval with a blunt tip, thick and very glossy. They fan down the slope of the
  crown, built on the same clump crown as the mango, longan and rambutan, with no dark lining.
- **Ripe.** 7 or 8 big yellow-green fruits with a waxy sheen and fine oil dots. They hang one or two together on short
  stalks from the lower and outer crown.
- **Unripe.** Smaller fruits in a lighter green than the leaves, so they still show.
- **Shadow.** The sheet carries its own ground shadow, and `x$.ft_buoi=1` keeps the sun-cast silhouette off it, so there
  is only one shadow.
- **Size.** The frames are 76-92 wide and 81-83 tall. The game bb went from [-46,-80,46,20] to [-50,-73,50,20].

## Files

- `buoi.py` is the kit. It builds on the rambutan and longan kits' layout and on `../mit`, `../xoai`, `../da` and
  `../chuoi`.
  - `python3 buoi.py 0,1,2,3 [n] tag` writes a preview to /tmp/claude-0/g/buoi_<tag>.png.
  - `python3 buoi.py atlas <outdir> <atlas.json>` writes `k2_buoi.webp` and its frame table.
- `patch_buoi.py` runs as `python3 patch_buoi.py index.html atlas.json out.html [dbg.html]`. It hooks
  `plants.ft_buoi`, which covers both the farm tree and the wild trees on the cù lao.
- `atlas.json` is the frame table used in v655.
