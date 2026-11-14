# Vẽ ảnh bong bóng (khung + hình trong) ra PNG nền trong, 9 px mỗi đơn vị làng -> godot/ui/img/bong/
# Chạy: python3 lam.py  (cần playwright)
import os
from playwright.sync_api import sync_playwright
OUT=os.path.join(os.path.dirname(os.path.abspath(__file__)),'..','..','godot','ui','img','bong')
PATH='M3.7 9.29 A10 10 0 1 0 -3.7 9.29 Q-1.2 11.6 -0.55 13.6 Q0 14.6 0.55 13.6 Q1.2 11.6 3.7 9.29 Z'
def khung(col):   # tròn r10 + đuôi tới y 14,6, viền 1,5, nền kem, bóng đổ; khung -12,5..12,5 x -12,5..18,61
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="-12.5 -12.5 25 31.1111" width="225" height="280">
<defs><radialGradient id="g" cx="40%" cy="30%" r="80%"><stop offset="0" stop-color="#ffffff"/><stop offset="1" stop-color="#fbf3e2"/></radialGradient>
<filter id="s" x="-50%" y="-50%" width="200%" height="200%"><feDropShadow dx="0" dy="1.3" stdDeviation="0.9" flood-color="#1a1408" flood-opacity="0.35"/></filter></defs>
<path d="{PATH}" fill="url(#g)" stroke="{col}" stroke-width="1.5" stroke-linejoin="round" filter="url(#s)"/>
<path d="M-6.5 -4.5 A7.8 7.8 0 0 1 -1 -7.6" fill="none" stroke="#ffffff" stroke-width="1.3" stroke-linecap="round" opacity=".9"/></svg>'''
def vong():   # vòng ô chín: elip 21 x 10,5 nét 2,2 vàng tươi + quầng sáng mềm; khung -24..24 x -13..13 đơn vị
    return '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="-24 -13 48 26" width="432" height="234">
<defs><filter id="q" x="-20%" y="-40%" width="140%" height="180%"><feGaussianBlur stdDeviation="1.1"/></filter></defs>
<ellipse rx="21" ry="10.5" fill="none" stroke="#ffe066" stroke-width="4.2" opacity=".55" filter="url(#q)"/>
<ellipse rx="21" ry="10.5" fill="none" stroke="#ffcc1a" stroke-width="2.2"/>
<ellipse rx="21" ry="10.5" fill="none" stroke="#fff6c2" stroke-width=".7" opacity=".9"/></svg>'''
def hinh(body):   # ô hình 13,6 x 13,6 đơn vị (-6,8..6,8) -> 128 px
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="-6.8 -6.8 13.6 13.6" width="128" height="128">{body}</svg>'
F={
 'vong': vong(),
 'xanh': khung('#2f86d6'),
 'do': khung('#d9443a'),
 'nuoc': hinh('<path d="M0 -6 C2.2 -2.6 4.6 0 4.6 2.4 C4.6 5 2.5 6.4 0 6.4 C-2.5 6.4 -4.6 5 -4.6 2.4 C-4.6 0 -2.2 -2.6 0 -6 Z" fill="#3a8fd6" stroke="#2a6fb0" stroke-width=".5"/><path d="M-2.4 2 C-2.4 3.6 -1.4 4.6 -0.2 4.8" fill="none" stroke="#ffffff" stroke-width=".9" stroke-linecap="round" opacity=".85"/>'),
 'gap': hinh('<path d="M-1.35 -5.6 L1.35 -5.6 L0.9 2 L-0.9 2 Z" fill="#d9443a" stroke="#d9443a" stroke-width=".6" stroke-linejoin="round"/><circle cx="0" cy="4.4" r="1.45" fill="#d9443a"/>'),
 'benh': hinh('<rect x="-1.5" y="-5" width="3" height="10" rx=".6" fill="#d9443a"/><rect x="-5" y="-1.5" width="10" height="3" rx=".6" fill="#d9443a"/>'),
}
with sync_playwright() as p:
    b=p.chromium.launch();pg=b.new_page()
    for k,svg in F.items():
        pg.set_content('<html><body style="margin:0;background:transparent">'+svg+'</body></html>')
        pg.locator('svg').screenshot(path=os.path.join(OUT,k+'.png'),omit_background=True)
    b.close()
print('ok',sorted(os.listdir(OUT)))
