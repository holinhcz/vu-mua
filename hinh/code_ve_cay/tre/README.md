# Bụi tre cho Nông Trại Nhỏ

Bamboo clumps (tre gai) drawn as small 3D models with the banana kit's painter, camera, sun and night transform (`../chuoi/chuoi.py`), baked into `img/tre.webp`.

- `tre.py`: the clump. 14-18 culms from a tight foot, leaning out and arching over at the top; node rings, culm sheaths (mo) low down, thorny twigs at the foot, branch whorls from mid-culm carrying drooping sprays of narrow leaves (each spray has its own outline, tone from light direction and how deep it sits in the canopy), shoots (măng) and dry leaves on the ground.
  `python3 tre.py` writes previews to /tmp/claude-0/g; `python3 tre.py atlas ../../img atlas.json` writes the sheet (4 clumps x day/night) and the frame table.
- `patch_tre.py <index.html> <atlas.json> <out>`: hooks `plants.bamboo` to draw from the sheet (old vector bamboo until it loads), drops cached bamboo sprites on load, keeps the ground shadow, sets bb to [-82,-140,82,22]. The game file gets re-minified by other work, so the patcher reads the engine's short names from the banana block; it also replaces its own earlier block.

Needs `pip install pycairo`.

2026-10-31 v618: Link asked to drop the edge outlines on all three new trees. `chuoi.EDGE = False` (shared by tre and dua) skips every outline stroke; leaves and leaflets are filled with a same-colour edge (`fill(grow=...)`) so they keep their old size, bamboo and coconut leaf tones sit a notch darker (v - 0.14 / v - 0.1) so the canopy keeps its weight, coconut bare stalks by the crown are green instead of olive. Inner details (veins, midribs, ring scars, nodes) stay. Set `EDGE = True` to get the v617 look back.

2026-10-31 v619: Link found v618 too flat ("bệt") and asked for a thin edge only a little darker than the leaf ("viền mỏng nhỏ nhạt gần màu lá"). `chuoi.SOFT = True`: `Painter.soft_edge` strokes each leaf, leaflet, stem, trunk side, fruit in its own fill colour x `SOFT_K` (0.8) at `SOFT_W` (0.26 units). v618 leaf tones kept. Turn SOFT off for no edge, EDGE on for the old dark outline.

2026-10-31 v620: ramp pulled onto the game tree greens, narrower light spread (no pale/near-black halves); each spray is one cluster (tones 70% shared, thin edge round the cluster only); shoots (măng) are cones of overlapping pointed sheaths.

2026-10-31 v621: wider light spread again (sunny, high, outer sprays light; inner, low darker) within the game greens; culm segments up in the canopy pulled toward the leaf green and sorted a little behind nearby sprays, twigs likewise.
