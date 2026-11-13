# Cây chuối cho Nông Trại Nhỏ

Banana sprites drawn as small 3D models (pycairo, flat game tones; no edge outlines since v618, see `EDGE` in chuoi.py) and baked into `img/chuoi.webp`.

- `chuoi.py`: the model and painter (leaf with vein-aligned tears, pseudostem with sheaths/blotches/dry sheaths and crown shadow, bunch with hands of fingers + purple heart). Camera = the game's 2:1 iso (30°), sun from the upper left. Night set = least-squares fit of the game's own `v(day,night)` colour pairs.
- `build.py`: plant layouts. `python3 build.py` writes a preview to /tmp; `python3 build.py atlas ../../img > atlas.txt` writes the sheet and prints the frame table (line 2).
  Frames: `b0-b3` decor banana, `f0/f1` fruit-tree banana green/ripe (same plant), `w0-w3` wild banana; prefix `d` day, `n` night. Each: [sx,sy,sw,sh, dx,dy,dw,dh] (dx..dh in game units).
- `patch_game.py <index.html> <atlas.txt> <out>` (original or already patched): wires the sheet into the game. `K.plants.banana / wildbanana / ft_chuoi` draw their frame once the sheet loads (old vector banana until then), drop cached sprites on load, keep the ground shadow (`bl`). Wild banana bb raised to -88, banana bb to -108.

Needs `pip install pycairo` (not preinstalled).

2026-10-31 v618: Link asked to drop the edge outlines on all three new trees. `chuoi.EDGE = False` (shared by tre and dua) skips every outline stroke; leaves and leaflets are filled with a same-colour edge (`fill(grow=...)`) so they keep their old size, bamboo and coconut leaf tones sit a notch darker (v - 0.14 / v - 0.1) so the canopy keeps its weight, coconut bare stalks by the crown are green instead of olive. Inner details (veins, midribs, ring scars, nodes) stay. Set `EDGE = True` to get the v617 look back.

2026-10-31 v619: Link found v618 too flat ("bệt") and asked for a thin edge only a little darker than the leaf ("viền mỏng nhỏ nhạt gần màu lá"). `chuoi.SOFT = True`: `Painter.soft_edge` strokes each leaf, leaflet, stem, trunk side, fruit in its own fill colour x `SOFT_K` (0.8) at `SOFT_W` (0.26 units). v618 leaf tones kept. Turn SOFT off for no edge, EDGE on for the old dark outline.

2026-10-31 v620: midrib only a few shades lighter than the leaf; bunch = fewer, bigger hands, each a fan of long fingers on the outer side curving up (no full rings, no corn cob).

2026-10-31 v621: stem blotches are thin soft streaks (no round dots); the rolled young leaf is shorter and bends over to one side; hands fan sideways, fingers bend up along their length, outer ones shorter; tapers get soft edges on their long sides only.
