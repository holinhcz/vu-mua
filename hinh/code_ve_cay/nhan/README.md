# Longan tree (cây nhãn), v653

Link asked on 2026-11-04 for the longan tree redrawn with two shapes ("Vẽ lại cây nhãn đi / 2 dáng thôi"). It follows the
game's "k2" scheme for fruit trees: 2 shapes × unripe/ripe. Before/after picture: `../../xem/nhan-truoc-sau.jpg`.

- **Shape 0** is a younger tree with a round, dense dome. One trunk forks at knee height into three limbs.
- **Shape 1** is an old orchard tree, pruned low and wide the miền Tây way. A thick trunk splits low into three leaders
  under a broad umbrella crown.
- **Leaves.** Compound leaves at every twig end, each with 2 to 4 pairs of oblong, dark, glossy leaflets. The crown is
  the mango kit's clump crown, so there's no dark lining behind the leaves.
- **Ripe** trees carry 11 to 13 loose bunches of tan fruit hanging off the outside of the crown.
- **Unripe** trees show cream flower panicles over the crown and about 7 bunches of small olive-green fruit.
- **Dropped:** the coppery new leaves (`FLUSH = False`). At game size they read as dead or sick patches.
- **Size:** the sheet frames are about 81 wide for shape 0 and 97 for shape 1, compared with mango 86-89 and jackfruit
  72-90. The game bb is now [-53,-72,53,20] (it was [-48,-80,48,20]).

## Files

- `nhan.py`: the kit. It builds on `../mit` (the jackfruit) and through it on `../xoai`, `../da` and `../chuoi`.
  - `python3 nhan.py 0,1,2,3 [n] tag` writes a preview to /tmp/claude-0/g/nhan_<tag>.png.
  - `python3 nhan.py atlas <outdir> <atlas.json>` writes `k2_nhan.webp` and the frame table.
- `patch_nhan.py`: run as `python3 patch_nhan.py index.html atlas.json out.html [dbg.html]`.
  - It wires `img/k2_nhan.webp` into `plants.ft_nhan`, using frame `((t>>1)&1, t&1)` = (shape, ripe).
  - It sets `x$.ft_nhan=1` so the sun-cast silhouette skips the tree, which keeps one shadow (the sheet's own).
  - It replaces its own older block, and it reads the engine names from the file.
- `atlas.json`: the frame table used in v653.
