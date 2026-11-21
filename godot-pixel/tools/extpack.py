# Extrae y reduce al 50% los sprites de los paquetes de itch.io (sin redistribuirlos: solo uso local)
import sys, json, numpy as np
from PIL import Image
from scipy import ndimage
SRC, OUT = sys.argv[1], sys.argv[2]
def half(im):
    a = np.array(im.convert('RGBA')); h, w = a.shape[:2]
    a = np.pad(a, ((0, h % 2), (0, w % 2), (0, 0)))
    H, W = a.shape[0] // 2, a.shape[1] // 2
    o = np.zeros((H, W, 4), np.uint8)
    for y in range(H):
        for x in range(W):
            blk = a[y*2:y*2+2, x*2:x*2+2].reshape(4, 4)
            op = [tuple(int(c) for c in p) for p in blk if p[3] > 0]
            if len(op) >= 2:
                # tono más oscuro si hay contorno (conserva líneas), si no el más común
                cnt = {}
                for p in op: cnt[p] = cnt.get(p, 0) + 1
                best = max(cnt.items(), key=lambda kv: (kv[1], -sum(kv[0][:3])))[0]
                dark = min(op, key=lambda p: sum(p[:3]))
                o[y, x] = dark if sum(dark[:3]) < 120 and cnt[best] < 3 else best
    return Image.fromarray(o)
env = Image.open(f'{SRC}/FreeEnvironment/FreePack.png').convert('RGBA')
a = np.array(env)
lab, n = ndimage.label(a[:, :, 3] > 0, structure=np.ones((3, 3)))
objs = [s for s in ndimage.find_objects(lab) if (s[0].stop - s[0].start) * (s[1].stop - s[1].start) > 1500]
objs.sort(key=lambda s: (0 if s[0].start < 100 else (1 if s[0].start < 260 else 2), s[1].start))
names = ['cactus0', 'cactus1', 'agave0', 'agave1', 'pricklypear', 'pine_big', 'coral0', 'coral1', 'coral2', 'rock_big', 'pine_snow', 'pine_slim0', 'pine_slim1', 'bare', 'ice_big']
idx = {}
for nm, s in zip(names, objs):
    crop = Image.fromarray(np.where((lab[s] > 0)[..., None], a[s], 0).astype(np.uint8))
    hf = half(crop)
    hf.save(f'{OUT}/x_{nm}.png'); idx['x_' + nm] = {'w': hf.width, 'h': hf.height, 'frames': 1, 'ox': hf.width // 2, 'oy': hf.height - 2}
def sheet(fn, fw, fh, name, frames=None):
    im = Image.open(f'{SRC}/FreeAnimalPack/{fn}').convert('RGBA')
    n = im.width // fw
    fr = [half(im.crop((k * fw, 0, k * fw + fw, fh))) for k in range(n)]
    if frames: fr = [fr[i] for i in frames]
    w, h = fr[0].size
    o = Image.new('RGBA', (w * len(fr), h))
    for k, f in enumerate(fr): o.paste(f, (k * w, 0))
    o.save(f'{OUT}/{name}.png'); idx[name] = {'w': w, 'h': h, 'frames': len(fr), 'ox': w // 2, 'oy': h - 2}
sheet('FrogIdle.png', 32, 32, 'x_frog')
sheet('Jumping.png', 32, 32, 'x_rabbit')
b = Image.open(f'{SRC}/FreeAnimalPack/BirdFly.png').convert('RGBA'); b.save(f'{OUT}/x_bird.png')
idx['x_bird'] = {'w': 16, 'h': 16, 'frames': 8, 'ox': 8, 'oy': 14}
import json; json.dump(idx, open(f'{OUT}/ext.json', 'w'), indent=1)
print(len(idx), 'sprites', list(idx)[:20])
