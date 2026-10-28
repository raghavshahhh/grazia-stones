import json, os, sys, hashlib, urllib.request
A=sys.argv[1]; APP=sys.argv[2]
d=json.load(open(f'{A}/resolved.json'))
for r in d:
    src=r['ar_source']; dst=f"{A}/tex/{r['id']}"
    if src is None: r['file']=None; continue
    ext=os.path.splitext(src.split('?')[0])[1] or '.jpg'; dst+=ext
    if not os.path.exists(dst):
        if src.startswith('http'):
            try: urllib.request.urlretrieve(src, dst)
            except Exception as e: print('FAIL', r['name'], e); r['file']=None; continue
        else:
            p=os.path.join(APP, src)
            if not os.path.exists(p): print('MISSING ASSET', r['name'], src); r['file']=None; continue
            open(dst,'wb').write(open(p,'rb').read())
    r['file']=dst
json.dump(d, open(f'{A}/resolved.json','w'), indent=1)
print('files:', sum(1 for r in d if r.get('file')))
