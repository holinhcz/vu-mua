# Cây cau cho Nông Trại Nhỏ

Areca palms drawn as small 3D models with the banana kit's painter, camera, sun, night transform and thin same-colour edge (`../chuoi/chuoi.py`, SOFT on, EDGE off), baked into `img/cau.webp`. Made 2026-10-31 (v622) when Link asked "vẽ cây cau".

- `cau.py`: the palm. A tall slender grey trunk (2.95-4.05 m) standing straight out of the ground, ringed with pale leaf scars (ring shading follows the trunk's lit and shaded sides), turning grey-green over the top quarter, with a small reddish root collar at the foot; the smooth glossy green crown shaft (bẹ cau) on top, wider than the trunk, with the outer sheath's edge and a gloss line; 9-10 feather fronds rising out of it like a feather duster (young ones near upright, old ones arching out and kept off the viewer side), broad crowded leaflets held in a shallow V, a closed spear leaf; nut bunches (buồng cau) hanging from the foot of the crown shaft on a straw-coloured peduncle with 4-5 branches, egg-shaped nuts with a small calyx cap (green, orange, a few yellow). The crown's ground shadow is baked into the sheet (crown + foot in one shape).
  Frames: d0 straight, green bunch; d1 leaning, ripe orange bunch, an old yellow frond hanging beside the shaft; d2 young and shorter, small green bunch; d3 tallest with a slight S-bend, an orange and a green bunch; n0-n3 the same at night.
  `python3 cau.py 0,1,2,3 [n] tag` writes a preview to /tmp/claude-0/g/cau_tag.png; `python3 cau.py atlas ../../img atlas.json` writes the sheet and the frame table.
- `patch_cau.py <index.html> <atlas.json> <out> [dbg.html]`: hooks `plants.areca` (seed t&3) to draw from the sheet (old vector palm until it loads), drops cached areca sprites on load, fits bb to the frames. Reads the engine's short names from the banana block, replaces its own earlier block. The storm "fallen tree" drawing of areca is the game's own and untouched.

Needs `pip install pycairo`.
