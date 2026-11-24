# (bản 539) HÌNH CÁ MỘT NGUỒN: ảnh vẽ cá câu được (art/cc_fish/<cá>.webp, bản gốc lớn) là gốc duy nhất.
#  - câu cá: cauca/ui/img/cc/<cá>.webp = gốc thu về ngang tối đa 1200px (thẻ cá to nhất ~460 điểm, máy 2-3x vẫn nét)
#  - Kho vườn: art/kh_512/<món>.webp = cá đặt giữa ô vuông 512 (chừa lề) -> ui/svg/kh/<món>.svg bọc bản 256,
#    rồi chạy bake_kh.py ra 128 / 64. Hình vẽ tay bằng svg cũ của cá trong Kho bỏ.
#   python3 fish_one.py   (đổi hình cá: bỏ ảnh gốc mới vô art/cc_fish rồi chạy lại)
import os, io, base64, shutil
from PIL import Image
H = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(H, '..', '..')
ART = os.path.join(SRC, 'art', 'cc_fish')
CC = os.path.join(SRC, 'cauca', 'ui', 'img', 'cc')
K512 = os.path.join(SRC, 'art', 'kh_512')
SVG = os.path.join(SRC, 'godot', 'ui', 'svg', 'kh')
KHO = {"ro": "ca_ro", "sac": "ca_sac", "linh": "ca_linh", "mevinh": "ca_mevinh", "chot": "ca_chot", "tre": "ca_tre", "tom": "tom",
       "loc": "ca_loc", "he": "ca_he", "luon": "luon", "thatlat": "ca_thatlat", "bong": "ca_bong", "locbong": "ca_locbong", "chinh": "ca_chinh",
       "ho": "ca_ho", "tradau": "ca_tradau"}
# (11-24 Link "vẽ ếch cá chép với tép") con của lờ / lọp / giăng câu trong vườn, không câu được ở bờ kênh:
# chỉ có ô Kho (không chép vô gói hình câu cá). Gốc art/cc_fish: chep = ca_ve.py, tep = ca_ve2.py, ech = moi/ve_ech.py
KHO_ONLY = {"chep": "ca_chep", "tep": "tep", "ech": "ech", "cua": "cua"}   # ghẹ (art/cc_fish/ghe.webp, ve_cua.py) chưa có món trong vườn
MAXW = 1200
a = b = 0
for fid, kid in list(KHO.items()) + list(KHO_ONLY.items()):
    org = os.path.join(ART, fid + '.webp')
    cur = os.path.join(CC, fid + '.webp')
    if fid in KHO_ONLY:
        im = Image.open(org).convert('RGBA')
    else:
      if not os.path.exists(org):
        shutil.copy(cur, org)   # lần đầu: ảnh đang có = gốc
      im = Image.open(org).convert('RGBA')
      a += os.path.getsize(cur)
      if im.width > MAXW:
        pm = im.convert('RGBa').resize((MAXW, round(im.height * MAXW / im.width)), Image.LANCZOS).convert('RGBA')
      else:
        pm = im
      pm.save(cur, 'WEBP', quality=90, method=6)
      b += os.path.getsize(cur)
    # ô Kho: cắt sát hình, đặt giữa ô vuông, lề 6%
    bb = im.getchannel('A').point(lambda v: 255 if v > 8 else 0).getbbox()
    c = im.crop(bb).convert('RGBa')
    s = 512 * .88 / max(c.width, c.height)
    c = c.resize((max(1, round(c.width * s)), max(1, round(c.height * s))), Image.LANCZOS)
    sq = Image.new('RGBa', (512, 512))
    sq.paste(c, ((512 - c.width) // 2, (512 - c.height) // 2))
    sq = sq.convert('RGBA')
    sq.save(os.path.join(K512, kid + '.webp'), 'WEBP', quality=95, method=6)
    q = io.BytesIO()
    sq.convert('RGBa').resize((256, 256), Image.LANCZOS).convert('RGBA').save(q, 'WEBP', quality=95, method=6)
    open(os.path.join(SVG, kid + '.svg'), 'w').write('<svg viewBox="0 0 64 64" xmlns="http://www.w3.org/2000/svg"><image x="0" y="0" width="64" height="64" href="data:image/webp;base64,' + base64.b64encode(q.getvalue()).decode() + '"/></svg>')
print('câu cá: %d KB -> %d KB' % (a // 1024, b // 1024))
