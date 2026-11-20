# thêm danh sách tay đua (tên, chỉ số, kỹ năng, mở khóa bằng cúp nào) + tính cách AI vào meta của gói dg_card
import json, struct, re
d = json.load(open('out/map/nongtrai.json'))
b = open('lb/dg_card.wasm', 'rb').read(); n = struct.unpack('<I', b[:4])[0]; j = json.loads(b[4:4 + n]); body = b[4 + n:]
src = open('/mnt/project-files/dua-ga/index.html').read()
unl = {m.group(1): m.group(2) for m in re.finditer(r"\{id:'(\w+)',name:[^\n]*?unlock:'(\w+)'", src)}
chars = []
for c in d['CHARS']:
    c = dict(c)
    if c['id'] in unl: c['unlock'] = unl[c['id']]
    chars.append(c)
j['m']['chars'] = chars; j['m']['pers'] = d['PERS']
js = json.dumps(j, ensure_ascii=False, separators=(',', ':')).encode()
open('lb/dg_card.wasm', 'wb').write(struct.pack('<I', len(js)) + js + body)
