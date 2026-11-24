#!/usr/bin/env python3
# VẼ LẠI TÔM + 3 MÓN RÁC (dép, lon, nón) cho Câu cá (Link 11-23, đi cùng ca_ve.py).
# Mấy món này bản cũ vẽ bằng nhiều lớp cairo riêng (fish_cu.tom / junk). Giữ nguyên hình từng lớp, nhưng mỗi lớp được
# "bơm phồng" thành khối tròn theo bề dày của chính nó (khoảng cách tới mép) rồi tô sáng tối từng điểm ảnh, cùng hướng
# nắng với cá (trên-trái): càng, chân, râu thành ống tròn; vỏ đầu, đốt bụng phồng; lon thành trụ; dép dày mép.
# Ảnh to gấp 2 bản cũ.  python3 ca_ve2.py OUTDIR [tom dep lon non]
import sys, os
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import fishkit as K
import fish_cu as F

OUT = sys.argv[1] if len(sys.argv) > 1 else '/tmp/claude-0/ca'
IDS = sys.argv[2:] or ['tom', 'dep', 'lon', 'non']
os.makedirs(OUT, exist_ok=True)
RES = 3.6   # chuẩn 6px, như ca_ve.py
LIGHT = np.array([-.45, .62, .64]); LIGHT /= np.linalg.norm(LIGHT)
PUFF = {'tep': .03, 'tom': .03, 'dep': .02, 'lon': .04, 'non': .05}      # bán kính phồng (đơn vị cá)
cur = {'R': .04}

_init = K.Sprite.__init__
def _init2(self, scale=0.86, cx=0.07, cy=0.5, w=K.W, h=K.H):
    _init(self, scale, cx, cy, int(w * RES), int(h * RES))
K.Sprite.__init__ = _init2

_add = K.Sprite.add
def _add2(self, img, blur=0, clip=None, op='over', alpha=1.0):
    if blur == 0 and op == 'over':
        img = puff(img, self.L)
    return _add(self, img, blur, clip, op, alpha)
K.Sprite.add = _add2

_fin = K.Sprite.finish
def _fin2(self, outline='#2a1a0c', ow=2.2, bend=None, inner=None):
    return _fin(self, outline, ow * RES * .7, bend, inner)
K.Sprite.finish = _fin2


def puff(img, px):
    a = np.asarray(img).astype(np.float32) / 255
    al = a[..., 3]
    m = al > .3
    if m.sum() < 30:
        return img
    R = cur['R'] * px
    d = ndi.distance_transform_edt(m)
    u = np.clip(d / R, 0, 1)
    Z = R * np.sqrt(np.clip(1 - (1 - u) ** 2, 0, 1))
    Z = ndi.gaussian_filter(Z, 1.0 * RES)
    gy, gx = np.gradient(Z)
    n = np.dstack([-gx, gy, np.ones(Z.shape)])
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    dif = np.clip((n * LIGHT).sum(-1), 0, 1)
    lit = .5 + .62 * dif + .06 * np.clip(n[..., 1], 0, 1)
    lit = np.where(m, lit, 1.0)
    rgb = np.clip(a[..., :3] * lit[..., None], 0, 1)
    return Image.fromarray(np.dstack([rgb, al]).__mul__(255).astype(np.uint8), 'RGBA')


# ------------------------------------------------------------ TÔM CÀNG XANH vẽ lại dáng (bản cũ thân thẳng đơ như ống,
# chân cắm lung tung, càng mọc ra từ bụng): bụng cong vồng lên rồi cụp xuống đuôi, 6 đốt vỏ chồng nhau có vạt hông,
# quạt đuôi xoè, vỏ đầu + chuỷ răng cưa cong lên, mắt có cuống, 2 râu dài vắt ra sau, 3 cặp chân bò có khớp dưới vỏ đầu,
# chân bơi dưới bụng, 2 càng xanh dài mọc từ dưới vỏ đầu (khúc trên gập xuống, khúc dưới chĩa tới, bàn càng thon + 2 ngón).
import math
# (11-24) dáng càng gập này lưu art/cc_fish/tom_kho.webp (chỉ ô Kho); câu cá giữ art/cc_fish/tom.webp càng chĩa ngang (bản trước)
def tom2():
    sp = K.Sprite(scale=.58, cx=.03, cy=.45, h=420)   # khung cao hơn: càng thõng xuống
    hc = K.hexc
    BODY = '#7fa8a6'; BACK = '#3e6266'; BELLY = '#c4d8cc'
    blue = hc('#2f63b8'); blue_d = K.mix(blue, (0, 0, 0, 1), .45); blue_l = hc('#7fb0f0')
    # trục bụng: từ sau vỏ đầu vồng lên rồi cụp xuống đuôi
    AX = [(.57, .015), (.49, .052), (.405, .07), (.32, .062), (.24, .036), (.17, -.002), (.115, -.045)]
    RW = [.07, .07, .066, .06, .052, .044, .036]
    def tangent(i):
        a = AX[max(0, i - 1)]; b = AX[min(len(AX) - 1, i + 1)]
        dx, dy = a[0] - b[0], a[1] - b[1]; L = math.hypot(dx, dy); return dx / L, dy / L
    def claw(c, far):
        # (11-24 Link "càng gập cong xuống để ảnh to lên"): càng không chĩa thẳng tới trước nữa mà vươn ra rồi
        # gập cong xuống, bàn càng quặp ngược về dưới đầu (dáng chữ C) -> hình gọn gần vuông, ô Kho phóng to hơn ~1/3
        dy = .035 if far else 0.0; dx = -.1 if far else 0.0
        col = K.mix(blue, (0, 0, 0, 1), .28) if far else blue
        dk = K.mix(col, (0, 0, 0, 1), .45)
        J = [(.8 + dx, -.045 + dy), (.95 + dx, -.07 + dy), (1.075 + dx, -.14 + dy), (1.115 + dx, -.255 + dy)]
        W = [.034, .03, .026]
        for i in range(3):
            c.set_line_cap(1)
            c.move_to(*J[i]); c.line_to(*J[i + 1]); c.set_source_rgba(*dk); c.set_line_width(W[i] + .008); c.stroke()
            c.move_to(*J[i]); c.line_to(*J[i + 1]); c.set_source_rgba(*col); c.set_line_width(W[i]); c.stroke()
        # gai nhỏ dọc khúc dưới, phía ngoài (càng tôm càng xanh nhám)
        ex, ey = J[3][0] - J[2][0], J[3][1] - J[2][1]; el = math.hypot(ex, ey); ex, ey = ex / el, ey / el
        nx, ny = -ey, ex
        if nx < 0: nx, ny = -nx, -ny
        for i in range(9):
            t = (i + .5) / 9; p = K.lerp(J[2], J[3], t)
            q = (p[0] + nx * .012, p[1] + ny * .012)
            c.move_to(*q); c.line_to(q[0] + nx * .008 - ex * .008, q[1] + ny * .008 - ey * .008)
        c.set_source_rgba(*dk); c.set_line_width(.003); c.stroke()
        # khớp cam
        for p in J[1:3]:
            c.arc(p[0], p[1], .013, 0, 6.3); c.set_source_rgba(*hc('#e0843a', .9 if not far else .6)); c.fill()
        # bàn càng + 2 ngón: vẽ trong khung riêng gốc ở J[3], trục x theo hướng thõng xuống (hơi ngả ra sau)
        c.save(); c.translate(*J[3]); c.rotate(math.atan2(-.89, -.45) if not far else math.atan2(-.5, -.86))
        c.translate(-1.2, .045)
        palm = [(1.18, -.036), (1.26, -.008), (1.36, .006), (1.43, .002), (1.45, -.02),
                (1.4, -.045), (1.3, -.06), (1.21, -.062)]
        K.crpath(c, palm, True); c.set_source_rgba(*dk); c.set_line_width(.01); c.stroke_preserve(); c.set_source_rgba(*col); c.fill()
        # 2 ngón hơi há
        for pts in ([(1.42, .0), (1.5, .012), (1.58, .014), (1.61, .006), (1.5, -.006), (1.43, -.014)],
                    [(1.43, -.03), (1.51, -.036), (1.59, -.026), (1.615, -.016), (1.51, -.05), (1.42, -.046)]):
            K.crpath(c, pts, True); c.set_source_rgba(*dk); c.set_line_width(.008); c.stroke_preserve()
            c.set_source_rgba(*K.mix(col, (1, 1, 1, 1), .1)); c.fill()
        c.arc(1.607, .008, .007, 0, 6.3); c.arc(1.612, -.018, .007, 0, 6.3)
        c.set_source_rgba(*hc('#e0843a', .95)); c.fill()
        c.restore()
    def legs(c, far):
        a = .55 if far else 1.0; o = .012 if far else 0
        col = hc('#56797e' if far else '#6f9496', a)
        for i in range(3):
            x = .64 + i * .055 + o
            K.barbel(c, [(x, -.04), (x + .03, -.085), (x + .015 + i * .01, -.14), (x + .03 + i * .012, -.16)], .011, .005, col)
        for i in range(1, 6):    # chân bơi dưới mỗi đốt bụng
            x, y = AX[i]; w = RW[i]
            K.barbel(c, [(x, y - w * .85), (x - .01, y - w - .028), (x - .028, y - w - .04)], .012, .004, hc('#8fb0ae', .8 * a))
    def antenna(c):
        for pts, w in [([(.86, .03), (.72, .17), (.48, .28), (.2, .33), (-.02, .31)], .005),
                       ([(.87, .025), (.78, .2), (.58, .34), (.34, .42)], .004)]:
            K.barbel(c, pts, w, .0015, hc('#7a4e30', .95))
        for pts in ([(.88, .03), (.97, .075), (1.04, .085)], [(.88, .025), (.98, .045), (1.05, .045)]):
            K.barbel(c, pts, .005, .002, hc('#7a5a3a', .95))
    def tail(c):
        x, y = AX[-1]; tx_, ty_ = tangent(len(AX) - 1)
        ang = math.atan2(ty_, tx_) + math.pi      # tangent() chỉ về phía đầu, quạt đuôi quay ngược lại
        c.save(); c.translate(x, y); c.rotate(ang)
        # telson nhọn giữa + 4 cánh quạt xoè
        for rot, L, wd in [(-.6, .15, .05), (-.28, .17, .055), (.28, .17, .055), (.6, .15, .05)]:
            c.save(); c.rotate(rot)
            K.crpath(c, [(0, wd * .4), (L * .55, wd), (L, wd * .45), (L * 1.02, -wd * .2), (L * .55, -wd * .7), (0, -wd * .4)], True)
            c.set_source_rgba(*hc('#6a9296', .92)); c.fill_preserve(); c.set_source_rgba(*hc('#2a4246', .7)); c.set_line_width(.004); c.stroke()
            for k in range(4):
                c.move_to(.01, 0); c.line_to(L * .95, (k - 1.5) * wd * .35)
            c.set_source_rgba(.12, .22, .24, .3); c.set_line_width(.002); c.stroke()
            c.restore()
        K.crpath(c, [(0, .026), (.11, .016), (.18, 0), (.11, -.016), (0, -.026)], True)
        c.set_source_rgba(*hc('#7aa2a4')); c.fill_preserve(); c.set_source_rgba(*hc('#2a4246', .75)); c.set_line_width(.004); c.stroke()
        c.restore()
    def abdomen(c):
        for i in range(len(AX) - 1, -1, -1):     # đốt sau vẽ trước, đốt trước chồng lên
            x, y = AX[i]; w = RW[i]
            tx_, ty_ = tangent(i); ang = math.atan2(ty_, tx_)
            c.save(); c.translate(x, y); c.rotate(ang + math.pi)
            L = .05 if i < 6 else .042
            # đốt vỏ: lưng tròn + vạt hông thả xuống
            K.crpath(c, [(-L, w * .78), (0, w), (L, w * .85), (L * 1.05, -w * .1), (L * .7, -w * .98), (-L * .6, -w * 1.0), (-L * 1.05, -w * .2)], True)
            c.set_source(K.vgrad(c, w, -w, [(0, hc(BACK)), (.3, hc(BODY)), (.8, hc(BELLY)), (1, hc('#a8c2b8'))])); c.fill_preserve()
            c.set_source_rgba(*hc('#1f3438', .7)); c.set_line_width(.004); c.stroke()
            # vạch sẫm ngang đốt (sọc tôm)
            c.move_to(-L * .3, w * .95); c.curve_to(-L * .1, w * .2, -L * .2, -w * .4, -L * .45, -w * .85)
            c.set_source_rgba(.1, .2, .22, .3); c.set_line_width(.007); c.stroke()
            c.restore()
    def cara(c):
        pts = [(.55, .072), (.66, .09), (.77, .084), (.84, .066), (.875, .05), (.88, .02), (.865, -.015), (.82, -.05), (.7, -.065), (.56, -.055), (.53, .0)]
        K.crpath(c, pts, True)
        c.set_source(K.vgrad(c, .09, -.065, [(0, hc(BACK)), (.38, hc(BODY)), (1, hc(BELLY))])); c.fill_preserve()
        c.set_source_rgba(*hc('#1e3236', .75)); c.set_line_width(.004); c.stroke()
        # rãnh vỏ đầu + mấy sọc mờ
        c.move_to(.61, .07); c.curve_to(.66, .03, .72, .012, .8, .012); c.set_source_rgba(.1, .2, .22, .4); c.set_line_width(.005); c.stroke()
        for i in range(3):
            c.move_to(.62 + i * .06, .085); c.line_to(.64 + i * .06, -.05)
        c.set_source_rgba(.15, .25, .3, .2); c.set_line_width(.007); c.stroke()
        # chuỷ: lưỡi cong lên, răng cưa phía trên
        K.crpath(c, [(.84, .06), (.92, .085), (1.0, .11), (1.03, .118), (.99, .095), (.91, .062), (.86, .045)], True)
        c.set_source_rgba(*hc('#5f878a')); c.fill_preserve(); c.set_source_rgba(*hc('#1e3236', .8)); c.set_line_width(.0035); c.stroke()
        for i in range(7):
            x = .865 + i * .02; y = .068 + i * .0075
            c.move_to(x, y); c.line_to(x + .005, y + .016); c.line_to(x + .014, y + .005)
        c.set_source_rgba(*hc('#2a4048', .9)); c.set_line_width(.003); c.stroke()
        # mắt có cuống
        c.set_line_cap(1); c.move_to(.84, .028); c.line_to(.875, .044); c.set_source_rgba(*hc('#4c6262')); c.set_line_width(.014); c.stroke()
        c.arc(.88, .047, .017, 0, 6.3); c.set_source_rgba(.05, .05, .05, 1); c.fill()
        c.arc(.874, .053, .0055, 0, 6.3); c.set_source_rgba(1, 1, 1, .9); c.fill()
    sp.draw(lambda c: claw(c, True))
    sp.draw(lambda c: legs(c, True))
    sp.draw(antenna)
    sp.draw(tail)
    sp.draw(abdomen)
    sp.draw(lambda c: legs(c, False))
    sp.draw(cara)
    sp.draw(lambda c: claw(c, False))
    return sp.finish('#1a242a', 1.8)



def tep2():
    # TÉP ĐỒNG (11-24 Link "vẽ ếch cá chép với tép"): dáng tom2 nhưng vỏ trong ngà hồng lấm tấm nâu, chuỷ thẳng,
    # không có 2 càng xanh dài: chỉ cặp chân càng mảnh có kẹp nhỏ
    import random
    sp = K.Sprite(scale=.58, cx=.03, cy=.56)
    hc = K.hexc
    BODY = '#d9b49a'; BACK = '#9a6248'; BELLY = '#f4e4d4'
    blue = hc('#2f63b8'); blue_d = K.mix(blue, (0, 0, 0, 1), .45); blue_l = hc('#7fb0f0')
    # trục bụng: từ sau vỏ đầu vồng lên rồi cụp xuống đuôi
    AX = [(.57, .015), (.49, .052), (.405, .07), (.32, .062), (.24, .036), (.17, -.002), (.115, -.045)]
    RW = [.07, .07, .066, .06, .052, .044, .036]
    def tangent(i):
        a = AX[max(0, i - 1)]; b = AX[min(len(AX) - 1, i + 1)]
        dx, dy = a[0] - b[0], a[1] - b[1]; L = math.hypot(dx, dy); return dx / L, dy / L
    def claw(c, far):
        dy = .022 if far else 0.0; dx = -.03 if far else 0.0
        col = K.mix(blue, (0, 0, 0, 1), .28) if far else blue
        dk = K.mix(col, (0, 0, 0, 1), .45)
        J = [(.8 + dx, -.045 + dy), (.9 + dx, -.1 + dy), (1.07 + dx, -.085 + dy), (1.2 + dx, -.045 + dy)]
        W = [.034, .03, .026]
        for i in range(3):
            c.set_line_cap(1)
            c.move_to(*J[i]); c.line_to(*J[i + 1]); c.set_source_rgba(*dk); c.set_line_width(W[i] + .008); c.stroke()
            c.move_to(*J[i]); c.line_to(*J[i + 1]); c.set_source_rgba(*col); c.set_line_width(W[i]); c.stroke()
        # gai nhỏ dọc khúc dưới (càng tôm càng xanh nhám)
        for i in range(9):
            t = (i + .5) / 9; p = K.lerp(J[2], J[3], t)
            c.move_to(p[0], p[1] + .012); c.line_to(p[0] - .008, p[1] + .02)
        c.set_source_rgba(*dk); c.set_line_width(.003); c.stroke()
        # khớp cam
        for p in J[1:3]:
            c.arc(p[0], p[1], .013, 0, 6.3); c.set_source_rgba(*hc('#e0843a', .9 if not far else .6)); c.fill()
        # bàn càng thon dài
        palm = [(1.18 + dx, -.036 + dy), (1.26 + dx, -.008 + dy), (1.36 + dx, .006 + dy), (1.43 + dx, .002 + dy), (1.45 + dx, -.02 + dy),
                (1.4 + dx, -.045 + dy), (1.3 + dx, -.06 + dy), (1.21 + dx, -.062 + dy)]
        K.crpath(c, palm, True); c.set_source_rgba(*dk); c.set_line_width(.01); c.stroke_preserve(); c.set_source_rgba(*col); c.fill()
        # 2 ngón hơi há
        for pts in ([(1.42 + dx, .0 + dy), (1.5 + dx, .012 + dy), (1.58 + dx, .014 + dy), (1.61 + dx, .006 + dy), (1.5 + dx, -.006 + dy), (1.43 + dx, -.014 + dy)],
                    [(1.43 + dx, -.03 + dy), (1.51 + dx, -.036 + dy), (1.59 + dx, -.026 + dy), (1.615 + dx, -.016 + dy), (1.51 + dx, -.05 + dy), (1.42 + dx, -.046 + dy)]):
            K.crpath(c, pts, True); c.set_source_rgba(*dk); c.set_line_width(.008); c.stroke_preserve()
            c.set_source_rgba(*K.mix(col, (1, 1, 1, 1), .1)); c.fill()
        c.arc(1.607 + dx, .008 + dy, .007, 0, 6.3); c.arc(1.612 + dx, -.018 + dy, .007, 0, 6.3)
        c.set_source_rgba(*hc('#e0843a', .95)); c.fill()
    def pinc(c, far):
        a = .6 if far else 1.0; o = .02 if far else 0
        col = hc('#b08a72' if far else '#d8b09a', a)
        K.barbel(c, [(.78 + o, -.04), (.84 + o, -.1), (.93 + o, -.12), (.99 + o, -.105)], .012, .008, col)
        for pts in ([(.985 + o, -.1), (1.02 + o, -.09), (1.035 + o, -.098)], [(.985 + o, -.11), (1.02 + o, -.118), (1.035 + o, -.112)]):
            K.barbel(c, pts, .007, .003, col)
    def legs(c, far):
        a = .55 if far else 1.0; o = .012 if far else 0
        col = hc('#b08a72' if far else '#d0aa90', a)
        for i in range(3):
            x = .64 + i * .055 + o
            K.barbel(c, [(x, -.04), (x + .03, -.085), (x + .015 + i * .01, -.14), (x + .03 + i * .012, -.16)], .011, .005, col)
        for i in range(1, 6):    # chân bơi dưới mỗi đốt bụng
            x, y = AX[i]; w = RW[i]
            K.barbel(c, [(x, y - w * .85), (x - .01, y - w - .028), (x - .028, y - w - .04)], .012, .004, hc('#e6c8b2', .8 * a))
    def antenna(c):
        for pts, w in [([(.86, .03), (.72, .17), (.48, .28), (.2, .33), (-.06, .3)], .0045),
                       ([(.87, .025), (.78, .2), (.58, .34), (.34, .42)], .004)]:
            K.barbel(c, pts, w, .0015, hc('#7a4e30', .95))
        for pts in ([(.88, .03), (.97, .075), (1.04, .085)], [(.88, .025), (.98, .045), (1.05, .045)]):
            K.barbel(c, pts, .005, .002, hc('#7a5a3a', .95))
    def tail(c):
        x, y = AX[-1]; tx_, ty_ = tangent(len(AX) - 1)
        ang = math.atan2(ty_, tx_) + math.pi      # tangent() chỉ về phía đầu, quạt đuôi quay ngược lại
        c.save(); c.translate(x, y); c.rotate(ang)
        # telson nhọn giữa + 4 cánh quạt xoè
        for rot, L, wd in [(-.6, .15, .05), (-.28, .17, .055), (.28, .17, .055), (.6, .15, .05)]:
            c.save(); c.rotate(rot)
            K.crpath(c, [(0, wd * .4), (L * .55, wd), (L, wd * .45), (L * 1.02, -wd * .2), (L * .55, -wd * .7), (0, -wd * .4)], True)
            c.set_source_rgba(*hc('#d8ae94', .9)); c.fill_preserve(); c.set_source_rgba(*hc('#6a3a26', .7)); c.set_line_width(.004); c.stroke()
            for k in range(4):
                c.move_to(.01, 0); c.line_to(L * .95, (k - 1.5) * wd * .35)
            c.set_source_rgba(.4, .2, .12, .3); c.set_line_width(.002); c.stroke()
            c.restore()
        K.crpath(c, [(0, .026), (.11, .016), (.18, 0), (.11, -.016), (0, -.026)], True)
        c.set_source_rgba(*hc('#dcb49a')); c.fill_preserve(); c.set_source_rgba(*hc('#6a3a26', .75)); c.set_line_width(.004); c.stroke()
        c.restore()
    def abdomen(c):
        for i in range(len(AX) - 1, -1, -1):     # đốt sau vẽ trước, đốt trước chồng lên
            x, y = AX[i]; w = RW[i]
            tx_, ty_ = tangent(i); ang = math.atan2(ty_, tx_)
            c.save(); c.translate(x, y); c.rotate(ang + math.pi)
            L = .05 if i < 6 else .042
            # đốt vỏ: lưng tròn + vạt hông thả xuống
            K.crpath(c, [(-L, w * .78), (0, w), (L, w * .85), (L * 1.05, -w * .1), (L * .7, -w * .98), (-L * .6, -w * 1.0), (-L * 1.05, -w * .2)], True)
            c.set_source(K.vgrad(c, w, -w, [(0, hc(BACK)), (.3, hc(BODY)), (.8, hc(BELLY)), (1, hc('#ecd2bc'))])); c.fill_preserve()
            c.set_source_rgba(*hc('#5a2e1c', .7)); c.set_line_width(.004); c.stroke()
            # đốm nâu li ti trên vỏ (tép đồng)
            rr = random.Random(i * 7 + 3)
            for k in range(9):
                c.arc(rr.uniform(-L * .8, L * .8), rr.uniform(-w * .7, w * .85), rr.uniform(.0025, .005), 0, 6.3)
                c.set_source_rgba(.42, .2, .1, .55); c.fill()
            # vạch sẫm ngang đốt (sọc tôm)
            c.move_to(-L * .3, w * .95); c.curve_to(-L * .1, w * .2, -L * .2, -w * .4, -L * .45, -w * .85)
            c.set_source_rgba(.5, .22, .12, .28); c.set_line_width(.007); c.stroke()
            c.restore()
    def cara(c):
        pts = [(.55, .072), (.66, .09), (.77, .084), (.84, .066), (.875, .05), (.88, .02), (.865, -.015), (.82, -.05), (.7, -.065), (.56, -.055), (.53, .0)]
        K.crpath(c, pts, True)
        c.set_source(K.vgrad(c, .09, -.065, [(0, hc(BACK)), (.38, hc(BODY)), (1, hc(BELLY))])); c.fill_preserve()
        c.set_source_rgba(*hc('#5a2e1c', .75)); c.set_line_width(.004); c.stroke()
        # rãnh vỏ đầu + mấy sọc mờ
        c.move_to(.61, .07); c.curve_to(.66, .03, .72, .012, .8, .012); c.set_source_rgba(.45, .2, .1, .35); c.set_line_width(.005); c.stroke()
        for i in range(3):
            c.move_to(.62 + i * .06, .085); c.line_to(.64 + i * .06, -.05)
        c.set_source_rgba(.5, .25, .15, .18); c.set_line_width(.007); c.stroke()
        # chuỷ: lưỡi cong lên, răng cưa phía trên
        K.crpath(c, [(.84, .06), (.92, .072), (1.0, .084), (1.035, .086), (.99, .07), (.91, .05), (.86, .045)], True)
        c.set_source_rgba(*hc('#cfa286')); c.fill_preserve(); c.set_source_rgba(*hc('#5a2e1c', .8)); c.set_line_width(.0035); c.stroke()
        for i in range(7):
            x = .865 + i * .02; y = .062 + i * .0035
            c.move_to(x, y); c.line_to(x + .005, y + .016); c.line_to(x + .014, y + .005)
        c.set_source_rgba(*hc('#6a3a26', .9)); c.set_line_width(.003); c.stroke()
        # mắt có cuống
        c.set_line_cap(1); c.move_to(.84, .028); c.line_to(.875, .044); c.set_source_rgba(*hc('#a87a62')); c.set_line_width(.014); c.stroke()
        c.arc(.88, .047, .017, 0, 6.3); c.set_source_rgba(.05, .05, .05, 1); c.fill()
        c.arc(.874, .053, .0055, 0, 6.3); c.set_source_rgba(1, 1, 1, .9); c.fill()
    sp.draw(lambda c: pinc(c, True))
    sp.draw(lambda c: legs(c, True))
    sp.draw(antenna)
    sp.draw(tail)
    sp.draw(abdomen)
    sp.draw(lambda c: legs(c, False))
    sp.draw(cara)
    sp.draw(lambda c: pinc(c, False))
    return sp.finish('#1a242a', 1.8)


def crop(im):
    im = im.convert('RGBA')
    bb = im.getchannel('A').point(lambda q: 255 if q > 6 else 0).getbbox()
    p = int(3 * RES)
    return im.crop((max(0, bb[0] - p), max(0, bb[1] - p), min(im.width, bb[2] + p), min(im.height, bb[3] + p)))


if __name__ == '__main__':
    for k in IDS:
        cur['R'] = PUFF[k]
        im = tom2() if k == 'tom' else tep2() if k == 'tep' else F.junk(k)
        im = crop(im)
        im.save(os.path.join(OUT, k + '.webp'), lossless=True, quality=100, method=6)
        im.save(os.path.join(OUT, k + '.png'))
        print('ok', k, im.size)
