# Cây xoài (mango tree), v632, fixed in v634 and v635

Kit: `xoai.py`. Class `Xoai` extends `Da` from `../da/da.py` (the banyan) and reuses its clump crown, tube trunk and
shadow code; `../chuoi/chuoi.py` gives the camera, sun, night tones and the thin same-colour edge, `../dambut/dambut.py`
gives `hull`. About the old tree's size (crown about ±50 game units wide, top about 76 up).

A mango tree is a small 3D model painted in flat game tones:
- a short trunk that forks low (about half way up) into 4-5 limbs, one to each lower leaf clump, small limbs to the top;
- a dense dome crown: a ring of 4-5 lower clumps and 2-3 top clumps, each covered with rosettes of 5-7 long pointed
  drooping leaves, lit on top, darker underneath; nothing lines the inside, so thin spots show the limbs, the leaves
  on the far side and the ground behind;
- patches of young red "lộc non" leaves hanging limp on the top clumps (most trees);
- tree 0 (d0, not ripe): up to 20 cream flower cones (panicles) sticking out of the crown;
- trees 1-3 (d1-d3): 3, 4, 5 ripe mangoes on stalks below the crown, varied height, yellow with an orange-red blush.
The ground shadow is drawn last under everything (DEST_OVER).

Frames: d0-d3 (plants.mango, seed&3), n0-n3 at night. The planted orchard mango (ft_xoai) draws through
plants.mango.draw(t&1?3:0), so unripe shows the flowering tree and ripe shows 5 fruit.

Commands:
- preview: `python3 xoai.py 0,1,2,3 [n] tag` writes /tmp/claude-0/g/xoai_tag.png
- sheet: `python3 xoai.py atlas OUTDIR atlas.json` (write to a local folder, then copy: webp written straight to
  /mnt/project-files gets C2PA metadata appended)
- game: `python3 patch_xoai.py index.html atlas.json out.html [dbg.html]` (re-runnable, replaces its own block; clears
  cached `pmango*` and `pft_xoai*` sprites)

Before/after picture: `../../xem/xoai-truoc-sau.jpg`.

v634 (Link: "hình tròn nền phía sau ... trên tán cây"): the banyan's clump drew a round dark inner mass and a round
shade on the clump behind (ATOP). Where leaves were thin they showed on the crown as smooth round patches. `Xoai`
now overrides `_clump_leaves`: no round mass, no cast shade, a shell of dark leaves instead (`dark=True` in
`_cluster`, tones `deep`). A leaf-shaped cast shade was tried too and read as a ghost smudge, so it is gone. Picture:
`../../xem/xoai-bo-hinh-tron.jpg`. The banyan kit (../da) still has its round mass; untouched.

v635 (Link: "thưa thì lộ ra bt chứ có cc gì phải che cho kín"): the v634 dark-leaf lining and hidden core are off
(`LINING = False` in xoai.py). Thin spots in a crown should show what is behind; never fill a crown in to hide them.
Picture: `../../xem/xoai-mai-thua.jpg`.
