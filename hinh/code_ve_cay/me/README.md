# Tamarind tree (cây me), v657

Link asked on 2026-11-04 for the tamarind tree to be redrawn ("Vẽ lại cây me đi"). It is drawn from the real village tree,
and the game's old tree was used only for its size and for where it grows in the game. Before/after picture:
`../../xem/me-truoc-sau.jpg`.

It follows the "k2" scheme: 2 shapes × unripe/ripe.

- **Shape 0** is a younger tree. A dark trunk forks at knee height into three limbs under a round, dense crown.
- **Shape 1** is an old village tamarind. A thick, fissured trunk splits low into heavy limbs that spread wide under a
  broad, low dome.
- **Fork:** each leader starts inside the trunk as that half of the trunk carried on up, and fades in over the top of
  the trunk (`_fade_in`), so the limbs flow out of the bark with no seam, crease or flat cap. The back leader is drawn
  behind the trunk.
- **Leaves:** feathery compound leaves, each a short stalk with 9 to 13 pairs of tiny oblong leaflets. The crown is the
  longan kit's clump crown, so there's no dark lining behind the leaves.
- **Ripe:** 12 or 14 loose bunches of 2 to 5 curved, beaded, cinnamon-brown scurfy pods with round ends.
- **Unripe:** 9 or 10 bunches of olive-green pods and 8 or 9 sprays of small yellow flowers streaked red.
- **Shadow:** the sheet carries its own ground shadow, and `x$.ft_me=1` keeps the sun-cast silhouette off the tree, so
  there is one shadow.
- **Size:** the frames are about 80 wide for shape 0 and 99 for shape 1. The game bb is now [-53,-76,53,22].

## Files

- `me.py` builds on the longan kit's layout and on `../mit`, `../xoai`, `../da` and `../chuoi`.
  - `python3 me.py 0,1,2,3 [n] tag` writes a preview to /tmp/claude-0/g/me_<tag>.png.
  - `python3 me.py atlas <outdir> <atlas.json>` writes `k2_me.webp` and its frame table.
- `patch_me.py` runs as `python3 patch_me.py index.html atlas.json out.html [dbg.html]`. It hooks `plants.ft_me`.
- `atlas.json` is the frame table used in v657.
