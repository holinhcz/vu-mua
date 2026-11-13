# Cây dừa cho Nông Trại Nhỏ

Coconut palms drawn as small 3D models with the banana kit's painter, camera, sun and night transform (`../chuoi/chuoi.py`), baked into `img/dua.webp`.

- `dua.py`: the palm. A slender trunk that leans and curves back up (3.55-3.85 m), ring scars with a pale ridge, a flared foot with a round ground line, a fibrous collar (xơ dừa) under the crown, 11-13 feather fronds on a golden-angle spiral (young ones rise, old ones arch over; old fronds are kept off the viewer side so the trunk stays visible), a closed spear leaf on top, each frond a thin pale rachis with two rows of long narrow leaflets hanging in a V (grouped, the odd one missing), and nut bunches under the crown (painted over the inner fronds, the outer parts of front fronds painted back over them).
  v617 (Link's 9-point round): rachis darker and closer to the leaf green, wider leaflets in clumps with a frond-level tone, plain fibre collar, nut bunch on a visible stalk with the front leaf bases passing over it, a half-open young frond instead of a bare spear, uneven ring scars with a few weathered bands, the crown's ground shadow baked in as a flat ellipse (the patch keeps only a small vl(15,0,2) at the foot), four clearly different palms (0 tall and nearly straight, 1 low and bent hard, 2 young and short, 3 tallest with an S-bend), the dead frond snaps near the base and hangs in a curve.
  Frames: d0-d3 decor coconut (d1 has a dead frond, d3 a yellowing one, d2/d3 one brown nut), d4 planted tree without nuts, d5 with nuts; n0-n5 the same at night.
  `python3 dua.py 0,1,2,3 [n] tag` writes a preview to /tmp/claude-0/g/dua_tag.png; `python3 dua.py atlas ../../img atlas.json` writes the sheet and the frame table.
- `patch_dua.py <index.html> <atlas.json> <out> [dbg.html]`: hooks `plants.coconut` (seed t&3) and `plants.ft_dua` (t&1 = has nuts) to draw from the sheet (old vector palm until it loads), drops cached coconut sprites on load, keeps the ground shadow, fits both bb to the frames. Reads the engine's short names from the banana block, replaces its own earlier block.

Needs `pip install pycairo`.

2026-10-31 v618: Link asked to drop the edge outlines on all three new trees. `chuoi.EDGE = False` (shared by tre and dua) skips every outline stroke; leaves and leaflets are filled with a same-colour edge (`fill(grow=...)`) so they keep their old size, bamboo and coconut leaf tones sit a notch darker (v - 0.14 / v - 0.1) so the canopy keeps its weight, coconut bare stalks by the crown are green instead of olive. Inner details (veins, midribs, ring scars, nodes) stay. Set `EDGE = True` to get the v617 look back.

2026-10-31 v619: Link found v618 too flat ("bệt") and asked for a thin edge only a little darker than the leaf ("viền mỏng nhỏ nhạt gần màu lá"). `chuoi.SOFT = True`: `Painter.soft_edge` strokes each leaf, leaflet, stem, trunk side, fruit in its own fill colour x `SOFT_K` (0.8) at `SOFT_W` (0.26 units). v618 leaf tones kept. Turn SOFT off for no edge, EDGE on for the old dark outline.

2026-10-31 v620 (Link: "nhận xét" then "fix hết", xem/3cay-nhan-xet.jpg): coconut shadow is one shape (crown + foot union) and the game adds no foot shadow; trunk rings thinned/faded by a separate rng (crown unchanged); collar shorter and closer to the trunk colour; frond bases start on the collar, leaflets from 0.12 of the frond (no bare spokes); leaflets 0.104 wide; fronds toward the sun and upper fronds lighter (SUNXY, em).

2026-10-31 v621 (second "nhận xét", xem/3cay-nhan-xet-2.jpg, then "fix"): leaflets swept forward at an even angle in a deeper V (a frond reads as one feather), inner leaflets long and starting at 0.06, stalks a leaf green, fibre band in the crown shade; rachis edges on its long sides only (no joint lines).
