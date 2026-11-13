# Durian tree (cây sầu riêng), v658

Link asked on 2026-11-04 to finish the last three old fruit trees ("vẽ nốt 3 cây đi"). The durian is drawn from the real
miền Tây orchard tree, and the game's old tree was used only for its size. Before/after picture of all three:
`../../xem/3cay-truoc-sau.jpg`.

It follows the "k2" scheme: 2 shapes × unripe/ripe.

- **Shape 0** is an orchard tree in its prime. One straight trunk runs up through a dense crown shaped like a tall egg,
  with level branches all the way down.
- **Shape 1** is an old tall tree. A clear trunk carries the crown in loose tiers of level branches.
- **Leaves:** oblong with a drawn-out tip, in flat sprays. They are glossy dark green on top and olive-gold underneath.
- **Ripe:** 10 or 11 big olive-gold spiny ovals on short thick stalks. Each has a spiked outline and rows of little
  cones with brown tips.
- **Unripe:** smaller fresh-green fruit, plus bunches of cream flowers hanging under the branches.
- **Wood:** the upper ring of clumps always has one straight in front, so the leader never shows up the face of the
  crown. Branches fade in across the trunk (`_fade_in`), so no flat ends show.
- **Size:** the frames are 82×105 for shape 0 and 96×114 for shape 1. The game bb is [-54,-101,54,20] (it was
  [-44,-104,44,20]).

## Files

- `saurieng.py`: `python3 saurieng.py 0,1,2,3 [n] tag` writes a preview, and
  `python3 saurieng.py atlas <outdir> <atlas.json>` writes the sheet. The mangosteen kit (`../mangcut`) builds on it.
- `patch_saurieng.py`: run as `python3 patch_saurieng.py index.html atlas.json out.html [dbg.html]`. It hooks
  `plants.ft_saurieng` and sets `x$.ft_saurieng=1` (one shadow).
- `atlas.json`: the frame table.
