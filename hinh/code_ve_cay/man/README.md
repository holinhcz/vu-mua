# Wax apple tree (cây mận), v656

Link asked for this on 2026-11-04. The Nam Bộ "mận" is the wax apple (roi, Syzygium samarangense). I drew it from the
real miền Tây orchard tree; the game's old tree only set the size. It uses the "k2" scheme: 2 shapes × unripe/ripe.
Before/after picture: `../../xem/man-truoc-sau.jpg`.

- **Shape 0, mận An Phước.** A short, pale trunk forks low into a dense dome. The fruit is deep crimson.
- **Shape 1, mận hồng đào.** An older tree with a taller clear trunk and a broad umbrella crown. The fruit is rosy
  pink-red.
- **Leaves.** Simple, long and oval with a short point, leathery and glossy. They fan down the slope of the crown, on the
  same clump crown as the other fruit trees, with no dark lining behind them.
- **Bark.** Pale grey, with reddish flakes.
- **Ripe.** 13 or 14 tight bunches of 4-7 waxy bells hanging off the twigs. Each bell is narrow at the stalk and broad at
  the bottom, with faint lobes, a white shine down the lit side, and calyx teeth in the dip at the bottom.
- **Unripe.** Smaller pale green-white bells, plus a few white puffs of stamens (bông mận).
- **Shadow.** The sheet carries its own ground shadow, and `x$.ft_man=1` keeps the sun-cast silhouette off it, so the
  tree has one shadow, not two.
- **Size.** The frames are 80-90 wide and 84-90 tall. The game bb changed from [-50,-84,50,20] to [-50,-77,50,20].

## Files

- `man.py` is the kit. It builds on the pomelo kit and on `../mit`, `../xoai`, `../da` and `../chuoi`.
  - `python3 man.py 0,1,2,3 [n] tag` writes a preview.
  - `python3 man.py atlas <outdir> <atlas.json>` writes `k2_man.webp` and the frame table.
- `patch_man.py` hooks `plants.ft_man`. Run it as `python3 patch_man.py index.html atlas.json out.html [dbg.html]`.
- `atlas.json` is the frame table used in v656.
