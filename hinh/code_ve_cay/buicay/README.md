# Bụi cây (wild bush), v638

Kit: `buicay.py`, class `BuiCay` (extends the mango `Xoai` from `../xoai` for its clump crown and tube wood; uses
`../co` for the shadow and output helpers). Draw it with `python3 buicay.py 0,1,2,3 [n] tag` or
`python3 buicay.py atlas OUTDIR OUTDIR/buicay.json`; it goes into the game with `../co/patch_wild.py`.

The bush is a low mound of trâm ổi / ngũ sắc (lantana), the shrub that grows wild along fences and canal banks:
- a few thin woody stems out of the soil into 5-7 rounded clumps of small rough oval leaves (the mango's clump
  machinery with no dark lining: thin spots show stems and ground; leaves that would reach the soil are left off);
- 2-3 long shoots arching out of the bush's sides or back, leaves in pairs, a flower head at the tip;
- 10-13 domed flower heads on the side the camera sees, each a dome of tiny four-lobed flowers: the outer ring one
  colour, the middle buds another. Seed 0 cream/yellow, 1 pink/yellow, 2 orange/yellow, 3 white/pale yellow
  (the old bush's cream, pink, yellow, white).
- `paint()` runs a pixel test first: a head that leaves in front would mostly cover (under 80% showing) is left off,
  so no scraps of flowers peek through the leaves.

About the old bush's size (±30 game units wide, ~35 tall). Frames d0-d3 (plants.wildbush, seed & 3), n0-n3 at
night; sheet `img/buicay.webp`, table `atlas.json`.
