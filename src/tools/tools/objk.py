# (b56) info.json "ok": the web's draw key k (gx+gy depth, the same as scenery r[4]) of every object, from the export
# list (g/gdx/o9e/list.json, same order as info objs). main.gd sorts objects, scenery and the logic's nodes together by it.
import json, sys
info_p, list_p = sys.argv[1], sys.argv[2]
i = json.load(open(info_p)); L = json.load(open(list_p))
assert len(L) == len(i['objs'])
i['ok'] = [round(float(b['k']), 4) for b in L]
json.dump(i, open(info_p, 'w'), ensure_ascii=False, separators=(',', ':'))
print('ok', len(i['ok']))
