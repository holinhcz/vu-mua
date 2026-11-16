# Xuất cây tràm từ hàm vẽ của bản web (at.plants.tram.draw) ở 9 px/đơn vị: cần trang web có window.__TRAM (chèn trong closure, xem hinh/caylang/tram/README.md)
import json,base64,sys
from playwright.sync_api import sync_playwright
S=sys.argv[1]
with sync_playwright() as p:
    b=p.chromium.launch(); pg=b.new_page(); errs=[]; pg.on('pageerror',lambda e: errs.append(str(e)))
    pg.goto('file://'+S+'/web/gen_tram.html'); pg.wait_for_timeout(10000)
    out=json.loads(pg.evaluate('window.__TRAM()'))
    print(errs[:2], out.get('err'), out['o'])
    for k,v in out.items():
        if v and isinstance(v,str) and v.startswith('data:'):
            open(S+'/tram/'+k+'.png','wb').write(base64.b64decode(v.split(',')[1]))
    b.close()
