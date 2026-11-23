import sys,time,json,base64,os
from playwright.sync_api import sync_playwright
out=sys.argv[1]; os.makedirs(out,exist_ok=True)
with sync_playwright() as p:
    b=p.chromium.launch(args=['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader','--ignore-gpu-blocklist'])
    pg=b.new_context(viewport={'width':338,'height':610},device_scale_factor=2).new_page(); LOG=[]; pg.on('console',lambda m: LOG.append(m.text)); pg.goto('http://127.0.0.1:8791/')
    t0=time.time()
    while time.time()-t0<400 and not pg.evaluate('!!window.__nt'): pg.wait_for_timeout(3000)
    pg.wait_for_timeout(30000)
    pg.evaluate("window.__ntcmd='ctdump'")
    for i in range(300):
        pg.wait_for_timeout(2000)
        if pg.evaluate('!!window.__ctd'): break
    d=pg.evaluate('window.__ctd') or {}
    n=0
    for k,v in d.items():
        if v:
            open(os.path.join(out,k+'.png'),'wb').write(base64.b64decode(v)); n+=1
    print([l for l in LOG if 'CTD' in l or 'rror' in l][:15]); print('got',len(d),'png',n, [k for k,v in d.items() if not v][:20])
    b.close()
