# Dừa nước (nipa palm) for Sông Vàm's banks (v662, 2026-11-05)

    python3 duanuoc.py atlas <outdir> [atlas.json]     # renders the sheet img/duanuoc.webp and atlas.json
    python3 duanuoc.py 0,1 [n] [tag]                   # test renders of single clumps (n = night)

Built on the coconut kit (../dua/dua.py, painter and light from ../chuoi). No trunk: stiff fronds rise straight out
of the mud in a clump and arch only near the tip; bare petiole for the lower third, then two rows of glossy leaflets
in a shallow V; old fronds low and yellow, a dead one hanging; some clumps carry a brown fruit head at the foot.
4 day shapes (d0..d3) and their night copies (n0..n3) in one sheet.

dn.js is the game-side table (a template patch_song.py fills from atlas.json): it adds "duanuoc" to the sprite table
so the decor placer can put it on bank tiles (SGEO.bk: about 60% dừa nước, then coconut, lau, banana), and
SGEO.nud moves each clump onto the water's edge with its foot a little in the water.
Note: a .webp written to the project-files mount gets C2PA metadata appended (same pixels); publish from a local copy.
