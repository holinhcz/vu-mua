#!/usr/bin/env python3
# CÁ KÈO (11-25 Link: ô Kho cá kèo chưa có hình thật -> vẽ bằng bộ vẽ cá ca_ve.py, chuẩn 6px RES 3.6).
# Dáng cá kèo thật: thân rất dài thon (dài ~9 lần cao), trước tròn sau dẹt, đầu tù, mắt lồi sát đỉnh đầu,
# vây lưng 1 ngắn có gai + vây lưng 2 dài gần nửa thân, vây hậu môn dài đối diện, đuôi dài nhọn hình mũi giáo,
# lưng xám ô liu lấm tấm đốm nâu tối + vạch xiên mảnh, bụng vàng kem.
# python3 ve_keo.py OUTDIR   -> OUTDIR/keo.webp (+ .png)
import sys, os
OUT = sys.argv[1] if len(sys.argv) > 1 else '/tmp/claude-0/keo'
sys.argv = [sys.argv[0], OUT]
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import fish_cu as F
from fish_cu import seq, gill, mouth, blotches
import ca_ve as V

F.FISH['keo'] = dict(
    top=[(.15, .022), (.25, .032), (.4, .042), (.6, .049), (.78, .052), (.88, .05), (.95, .042), (.99, .022), (1.0, .004)],
    bot=[(1.0, .004), (.995, -.016), (.96, -.034), (.86, -.048), (.66, -.05), (.45, -.044), (.27, -.032), (.15, -.022)],
    col=dict(back='#6a6a50', flank='#a8a27c', belly='#ece2c0', fin='#9a9272', ray='#4e4a36'),
    mid=.42, bel=.72,
    fins=[
        dict(b0=(.66, .05), b1=(.75, .052), o=[(.655, .088), (.68, .108), (.72, .106), (.748, .07)], rays=6, a=.85),
        dict(b0=(.2, .028), b1=(.62, .049), o=[(.17, .046), (.26, .072), (.4, .084), (.55, .088), (.63, .066)], rays=22, a=.85),
        dict(b0=(.2, -.028), b1=(.55, -.048), o=[(.17, -.046), (.27, -.066), (.42, -.074), (.56, -.068)], rays=18, a=.85),
        dict(b0=(.155, .022), b1=(.155, -.022), o=[(.11, .042), (.05, .036), (.0, .016), (-.03, .0), (.0, -.016), (.05, -.036), (.11, -.042)], rays=14, fade='#5e5a44'),
        dict(b0=(.84, .004), b1=(.83, -.03), o=[(.77, .012), (.73, -.014), (.75, -.044)], rays=9, layer='front', a=.8, col='#aaa282'),
        dict(b0=(.8, -.048), b1=(.77, -.05), o=[(.75, -.074), (.72, -.07)], rays=5, layer='front', a=.8),
    ],
    soft=seq(blotches(51, 170, .18, .94, -.012, .05, .0028, .0055, '#3a3424', .6, .4),
             blotches(52, 16, .3, .9, -.04, -.01, .005, .008, '#7a7258', .35)), softblur=1.0,
    pattern=None,
    scales=(.012, .009, .2, .8, .12), headx=.82,
    head=seq(gill(.86, .046, -.044, .014, a=.4), mouth(.955, -.02, .998, -.004, w=.004)),
    eye=(.93, .044, .015, '#c8a65a'), shiney=.02, shinew=.012, shinex=(.15, .88),
)
V.EXTRA['keo'] = dict(thick=.8)

if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    im = V.render('keo')
    im.save(os.path.join(OUT, 'keo.webp'), lossless=True, quality=100, method=6)
    im.save(os.path.join(OUT, 'keo.png'))
    print('ok keo', im.size)
