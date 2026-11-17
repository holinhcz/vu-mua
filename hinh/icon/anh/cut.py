import sys, json, os, unicodedata
import numpy as np
from PIL import Image
from scipy import ndimage as nd
NAMES = {
 'traicay1': "Xoài cát,Quýt hồng,Chôm chôm,Măng cụt,Bưởi da xanh,Dừa Bến Tre,Sầu riêng,Thanh long,Dưa hấu,Nhãn,Mận,Đu đủ,Mít,Cam sành,Chuối,Điều,Me,Dâu tây",
 'rau1': "Cà rốt,Củ cải trắng,Củ dền,Khoai tây,Hành tím,Tỏi,Bắp cải,Cải thảo,Cải xanh,Rau muống,Mồng tơi,Rau dền,Bông điên điển,Bông súng,Bồn bồn,Kèo nèo,Rau nhút,Bông bí",
 'nongsan1': "Bắp,Lúa,Khoai lang,Khoai mì,Khoai môn,Đậu phộng,Đậu xanh,Đậu nành,Đậu đũa,Đậu bắp,Cà tím,Khổ qua,Bí đỏ,Bí đao,Bầu,Mướp,Dưa leo,Ớt",
 'rauthom1': "Rau răm,Lá é,Húng quế,Húng lủi,Tía tô,Diếp cá,Ngò rí,Ngò gai,Rau om,Hành lá,Hẹ,Sả,Đậu que,Đậu rồng,Đậu đen,Đậu đỏ,Gừng,Nghệ",
 'traicay2': "Ổi,Mãng cầu xiêm,Mãng cầu ta,Sapôchê,Vú sữa,Cóc,Khế,Sơ ri,Táo ta,Dâu da,Bòn bon,Chùm ruột,Cà na,Bình bát,Ô môi,Lê-ki-ma,Khóm,Chanh dây",
 'cay2': ("Bông vải,Chàm,Thốt nốt,Xà lách", 2, 2),
 'thit1': ("Thịt gà,Trứng gà,Thịt bò,Sữa bò", 2, 2),
 'thit2': ("Thịt cừu,Lông cừu,Thịt vịt,Trứng vịt", 2, 2),
 'thit3': ("Thịt heo,Sườn heo,Thịt dê,Sữa dê", 2, 2),
}
def slug(s):
    s = unicodedata.normalize('NFD', s.replace('đ','d').replace('Đ','D'))
    s = ''.join(c for c in s if unicodedata.category(c) != 'Mn').lower()
    return ''.join(c for c in s if c.isalnum())
def main(indir, outdir):
    meta = {}
    for sheet, nm in NAMES.items():
        cols, rows = 6, 3
        if isinstance(nm, tuple):
            nm, cols, rows = nm
        im = np.array(Image.open(os.path.join(indir, sheet + '.png')).convert('RGBA')).astype(np.float32)
        H, W = im.shape[:2]
        rgb = im[..., :3]; a = im[..., 3] / 255.0
        if a.min() > 0.99:   # nền màu kem: tách nền nối với mép
            bg = np.median(np.concatenate([rgb[:3].reshape(-1, 3), rgb[-3:].reshape(-1, 3)]), axis=0)
            d = np.sqrt(((rgb - bg) ** 2).sum(-1))
            cand = d < 26
            lab, n = nd.label(cand)
            border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
            # nền = vùng ứng viên lớn nối mép, hoặc vùng ứng viên rất lớn (khoảng giữa các hình)
            sizes = nd.sum(cand, lab, range(1, n + 1))
            bgm = np.zeros_like(cand)
            for i, sz in enumerate(sizes, 1):
                if i in border or sz > 4000:
                    bgm |= lab == i
            near = nd.binary_dilation(bgm, iterations=2) & ~bgm
            a = np.ones_like(d)
            a[bgm] = 0.0
            ra = np.clip((d - 8.0) / 45.0, 0.0, 1.0)
            a[near] = np.minimum(1.0, ra[near])
            safe = np.maximum(a, 1e-3)[..., None]
            rgb = np.clip((rgb - bg * (1 - a[..., None])) / safe, 0, 255)
        else:
            a = np.where(a < 0.16, 0.0, a)   # quầng mờ còn sót khi tách nền
        m = a > 0.2
        lab, n = nd.label(m, structure=np.ones((3, 3)))
        objs = nd.find_objects(lab)
        ch = H / float(rows); cw = W / float(cols)
        thr = max(30.0, (ch / 54.0) ** 2)
        groups = {}
        for i, sl in enumerate(objs, 1):
            y0, y1 = sl[0].start, sl[0].stop; x0, x1 = sl[1].start, sl[1].stop
            area = int((lab[sl] == i).sum())
            if area < thr:
                continue
            txt = False
            for r in range(rows):   # chữ tên: nằm gọn trong dải đầu ô (từ hơi trên ranh ô tới 19% ô)
                band = (r * ch - ch * 0.06, r * ch + ch * 0.19)
                if y0 >= band[0] - 4 and y1 <= band[1] + 4 and (y1 - y0) < ch * 0.17:
                    txt = True
            if txt:
                continue
            cy, cx = nd.center_of_mass(lab[sl] == i)
            cy += y0; cx += x0
            rr = int(min(rows - 1, cy // ch)); cc = int(min(cols - 1, cx // cw))
            groups.setdefault((rr, cc), []).append(i)
        names = nm.split(',')
        for idx, name in enumerate(names):
            r, c = divmod(idx, cols)
            ids = groups.get((r, c), [])
            if not ids:
                print('THIẾU', sheet, name); continue
            # bỏ mẩu lẻ nhỏ nằm xa hình chính (vết sót khi tách nền)
            ar = {i: int((lab == i).sum()) for i in ids}
            big = max(ar, key=ar.get)
            near = nd.binary_dilation(lab == big, iterations=8)
            ids = [i for i in ids if i == big or ar[i] >= 0.004 * ar[big] or near[lab == i].any()]
            mk = np.isin(lab, ids)
            ys, xs = np.where(mk)
            y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
            al = np.where(mk, a, 0.0)[y0:y1, x0:x1]
            # giữ cả viền mờ quanh hình (dãn 2px)
            dil = nd.binary_dilation(mk, iterations=2)[y0:y1, x0:x1]
            al = np.where(dil, a[y0:y1, x0:x1], 0.0)
            out = np.dstack([rgb[y0:y1, x0:x1], al * 255]).clip(0, 255).astype(np.uint8)
            crop = Image.fromarray(out, 'RGBA')
            s = 430.0 / max(crop.size)
            crop = crop.resize((max(1, round(crop.size[0] * s)), max(1, round(crop.size[1] * s))), Image.LANCZOS)
            can = Image.new('RGBA', (512, 512), (0, 0, 0, 0))
            ox = (512 - crop.size[0]) // 2; oy = (512 - crop.size[1]) // 2
            can.paste(crop, (ox, oy), crop)
            sl = {'Bồn bồn': 'bonbonrau'}.get(name, slug(name))
            fn = sl + '.png'
            can.save(os.path.join(outdir, fn), optimize=True)
            meta[sl] = {'file': fn, 'name': name, 'sheet': sheet, 'bbox': [ox, oy, ox + crop.size[0], oy + crop.size[1]]}
    json.dump(meta, open(os.path.join(outdir, 'atlas.json'), 'w'), ensure_ascii=False, indent=0)
    print(len(meta), 'ảnh')
main(sys.argv[1], sys.argv[2])
