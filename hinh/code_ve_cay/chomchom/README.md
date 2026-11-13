# Rambutan tree (cây chôm chôm), v654

Link asked on 2026-11-04 for the rambutan tree to be redrawn, and to work from the real tree rather than the game's old
one ("dựa theo cây cũ làm gì vẽ lại theo cây thực tế ngoài ấy"). The old tree was used only for its size and for where
it grows in the game. Before/after picture: `../../xem/chomchom-truoc-sau.jpg`.

It follows the "k2" scheme: 2 shapes × unripe/ripe.

- **Shape 0** is a miền Tây orchard tree, pruned low. A short trunk splits near the ground into limbs under a broad,
  dense dome whose skirt hangs low.
- **Shape 1** is an older, taller tree with a clear grey trunk and a high oval crown.
- **Leaves:** compound, with 2 to 4 pairs of broad, glossy, blunt leaflets. They are bigger than the longan's.
- **Ripe:** 12 or 13 loose bunches of oval red fruit, covered in soft curled hairs (râu), with a few hair tips still
  yellow-green.
- **Unripe:** the same bunches in yellow-green with green hairs. About one bunch in seven is turning yellow-orange.
- **Shadow:** the sheet carries its own ground shadow, and `x$.ft_chomchom=1` keeps the sun-cast silhouette off the
  tree, so there is one shadow.
- **Size:** the frames are 87-92 wide and 80-90 tall. The game bb is now [-52,-78,52,20] (it was [-46,-78,46,20]).

## Files

- `chom.py` builds on the longan kit's layout and on `../mit`, `../xoai`, `../da` and `../chuoi`.
  - `python3 chom.py 0,1,2,3 [n] tag` writes a preview to /tmp/claude-0/g/chom_<tag>.png.
  - `python3 chom.py atlas <outdir> <atlas.json>` writes `k2_chomchom.webp` and its frame table.
- `patch_chomchom.py` runs as `python3 patch_chomchom.py index.html atlas.json out.html [dbg.html]`. It hooks
  `plants.ft_chomchom`, which covers the farm tree and the wild cù lao trees.
- `atlas.json` is the frame table used in v654.
