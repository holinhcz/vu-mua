# Dương xỉ (fern, Nephrolepis), v754, restyled v755 (2026-11-07)

v755 (Link: "đã cùng style vẽ cây cối chưa"): same greens as dambut/mai, ~12 big leaflets a side (lp .17) instead of a fine comb, stronger light/shade, fuller clump (44 fronds, fountain arch), pot fronds shorter, smaller shadow. Before/after ../../xem/duongxi-truoc-sau.jpg; v754 kit kept as /tmp only.

Kit: `duongxi.py` (imports ../chuoi for camera, sun, night tones, thin same-colour edge; ../co for the render/atlas
helpers and ground shadow; ../mai for the terracotta pot). Rendered at KU x1.12 (v1 read small next to the hibiscus).

Two shapes (vars 2, frame = seed & 1):
- d0/n0 wild clump on the ground: 40 arching once-pinnate fronds + 9 young upright ones, 3 old brown fronds lying low,
  3 fiddleheads (ngọn cuộn); long fronds lie along the soil instead of going in.
- d1/n1 fern in the mai's pot (x0.86), fronds spill over the rim and hang down; the pot sorts by its middle so
  fronds behind it go under it.
Leaflets: lance-shaped, sickle tip, paler undersides with faint brown spore dots; light rachis without edge lines.

Commands:
- preview: `python3 duongxi.py 0,1 [n] tag` -> /tmp/claude-0/g/duongxi_tag.png
- sheet: `python3 duongxi.py atlas OUTDIR OUTDIR/duongxi.json` (write locally, copy after: C2PA gotcha)
- game: `python3 patch_duongxi.py index.html atlas.json out.html` adds plants.duongxi (block before the build list
  `og`, so its start-up pass sees it) and the build item {id:"duongxi",n:"Dương xỉ",cat:"cay",cost:40,vars:2}
  after Dâm bụt; sets x$.duongxi=1 (sheet has its own shadow). Re-runnable.
Picture: ../../xem/duongxi.jpg
