# Generador de arte pixel para Renuevo 2D: casillas 16x16, bordes, sprites con
# sombreado por bandas y contorno selectivo (sel-out). Salida: px/*.png + px/index.json
import numpy as np, json, os, sys, math, random
from PIL import Image

OUT = sys.argv[1]
os.makedirs(OUT, exist_ok=True)
T = 16

def hx(s):
    s = s.lstrip('#'); return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), 255)

RAMPS = {
    'grass': ['#22381a', '#2f4a1f', '#3e6427', '#4f7d2e', '#6a9a3a', '#8db84a'],
    'fgrass': ['#1c3016', '#273f1b', '#335422', '#426b29', '#558133', '#6e9a3e'],
    'dirt': ['#3a2416', '#4a2e1c', '#6b4428', '#8c5a32', '#a8744a', '#c49060'],
    'tox': ['#2a1828', '#3a2238', '#5a3456', '#7a4a6e', '#9a6a8a', '#b98aa6'],
    'slime': ['#4a5a1a', '#6e8a24', '#94b030', '#c0d850', '#e8f090'],
    'ash': ['#1e1b1b', '#2e2a2a', '#46403e', '#5e5652', '#7a706a', '#968a82'],
    'sand': ['#8a6438', '#b08850', '#d0aa6a', '#e6c88a', '#f2deaa', '#fff0cc'],
    'rock': ['#26262c', '#3a3a40', '#5e5d63', '#8a8890', '#b8b6ba', '#dcdce0'],
    'water': ['#163448', '#1f4660', '#2a5f7e', '#3a7c9c', '#5aa2bc', '#9ad0e0', '#e8f6f6'],
    'sea': ['#10263c', '#183652', '#22496c', '#2e5f88', '#4a80a6', '#86b8d2', '#e8f6f6'],
    'tsea': ['#124048', '#185a64', '#1f7480', '#2a8e98', '#46b0b4', '#8ad8d2', '#f0fbf8'],
    'marsh': ['#1e3226', '#284234', '#345440', '#43684c', '#5a8458', '#7ea06a', '#c8dcb0'],
    'ice': ['#4a6a88', '#7aa0c0', '#a8c8e0', '#d0e4f2', '#eef6fc', '#ffffff'],
    'lava': ['#2a0e0a', '#5a1a10', '#b8381a', '#f07020', '#ffb040', '#fff0a0'],
    'oil': ['#08080a', '#141418', '#20202a', '#2e2e3c', '#3e3a56', '#4e6a6a'],
    'mud': ['#2a1c12', '#3e2a1c', '#5a3e28', '#74523a', '#8e6a4c', '#a8866a'],
    'bark': ['#2a1a10', '#3e2818', '#5a3a22', '#7a5030', '#9a6a40'],
    'leaf': ['#16301c', '#1f4424', '#2c5e2c', '#3f7a32', '#5a9a3a', '#7fb84a', '#a8d060'],
    'pine': ['#122620', '#183428', '#204634', '#2c5a40', '#3c7450', '#5a9060'],
    'jungle': ['#0e2a1a', '#164024', '#1f5a2c', '#2c7634', '#46963c', '#6ab848'],
    'taiga': ['#14282a', '#1c3a3a', '#285050', '#3a6a64', '#5a8a7e', '#dceaf0', '#ffffff'],
    'snow': ['#7a94b0', '#a8bcd2', '#d0deea', '#eef4fa', '#ffffff'],
    'white': ['#3a3a44', '#6a6a78', '#a4a4b0', '#d0d0d8', '#eeeef2', '#ffffff'],
    'cream': ['#4a3a2a', '#7a6248', '#b09a78', '#d8c8a8', '#f0e6d0', '#fff8ec'],
    'teal': ['#1a3030', '#24484a', '#33625e', '#4a807a', '#6aa298', '#9ac8bc'],
    'brick': ['#3a1410', '#5e2218', '#8a3424', '#b04a30', '#cc6a48'],
    'roof': ['#2a0e0e', '#5a1c18', '#8a2c22', '#b4402c', '#d86040'],
    'steel': ['#22262c', '#363c44', '#525a64', '#76808a', '#a0aab2', '#d0d6da'],
    'gold': ['#4a3410', '#7a5a18', '#b08a28', '#e0b840', '#f8e070'],
    'glass': ['#2a4a5a', '#3e6a7e', '#5a90a6', '#86b8cc', '#c0e0ea', '#f0fafc'],
    'wood': ['#2e1a0e', '#4a2c18', '#6b4428', '#8c5a32', '#b07a45', '#d09a5c'],
    'pink': ['#5a2030', '#8a3a50', '#c05a78', '#e88aa6', '#f8c0d0'],
    'red': ['#3a0e0e', '#6a1a16', '#a82c22', '#d84a30', '#f07a50'],
    'blue': ['#101a3a', '#1a2e6a', '#2a4aa8', '#4a72d8', '#80a8f0'],
    'yellow': ['#4a3a08', '#8a6a10', '#c8a020', '#f0d040', '#fff090'],
    'orange': ['#4a1e08', '#8a3a10', '#c86020', '#f09040', '#ffc070'],
    'brown': ['#24140c', '#3e2414', '#5e3a20', '#80522e', '#a06e40', '#c09060'],
    'grey': ['#22242a', '#3a3c44', '#565a64', '#7a7e88', '#a0a4ac', '#c8ccd2'],
    'deer': ['#2a160c', '#4a2a16', '#7a4a26', '#a06a38', '#c08a50', '#e0b07a'],
    'fur_w': ['#4a4440', '#7a726a', '#b0a89c', '#d8d0c4', '#f2ece2', '#ffffff'],
    'frog': ['#14300e', '#20501a', '#2e7a24', '#46a032', '#7ac850', '#b0e080'],
    'black': ['#0e0c0c', '#1c1a1a', '#2e2a2a', '#44403e', '#5e5856'],
    'purple': ['#2a1438', '#46205e', '#6a348a', '#9050b4', '#b880d8'],
}
RAMP = {k: [hx(c) for c in v] for k, v in RAMPS.items()}
RID = {k: i for i, k in enumerate(RAMPS)}
OUTLINE = hx('#1e140e')

class Cv:
    def __init__(s, w, h):
        s.w, s.h = w, h
        s.c = np.zeros((h, w, 4), np.uint8)
        s.r = np.full((h, w), -1, np.int16)    # rampa de cada píxel (para el contorno)
        s.solid = np.zeros((h, w), bool)
    def px(s, x, y, ramp, i, solid=True):
        x, y = int(x), int(y)
        if 0 <= x < s.w and 0 <= y < s.h:
            rr = RAMP[ramp]; i = max(0, min(len(rr) - 1, int(i)))
            s.c[y, x] = rr[i]; s.r[y, x] = RID[ramp]; s.solid[y, x] = s.solid[y, x] or solid
    def rgba(s, x, y, col):
        if 0 <= x < s.w and 0 <= y < s.h: s.c[y, x] = col
    def shadow(s, cx, cy, rx, ry, a=90):
        for y in range(s.h):
            for x in range(s.w):
                if ((x + .5 - cx) / rx) ** 2 + ((y + .5 - cy) / ry) ** 2 <= 1 and s.c[y, x, 3] == 0:
                    s.c[y, x] = (20, 14, 10, a)
    def blob(s, cx, cy, rx, ry, ramp, bands=None, lx=-.55, ly=-.7, lift=0.0, inner_line=True, top=None):
        """Elipse sombreada por bandas, luz arriba-izquierda."""
        rr = RAMP[ramp]; n = len(rr)
        L = np.array([lx, ly, .55]); L /= np.linalg.norm(L)
        drawn = []
        for y in range(s.h):
            for x in range(s.w):
                nx = (x + .5 - cx) / rx; ny = (y + .5 - cy) / ry
                d = nx * nx + ny * ny
                if d <= 1:
                    nz = math.sqrt(max(0, 1 - d))
                    sh = float(np.dot([nx, ny, nz], L)) * .5 + .5 + lift
                    i = int(round(sh * (n - 1.6))) + (0 if top is None else 0)
                    if d > .78: i = min(i, n - 3)
                    drawn.append((x, y, i, d))
        prev = s.solid.copy()
        for x, y, i, d in drawn:
            s.px(x, y, ramp, i)
        if inner_line:
            # línea interior donde el racimo se superpone a lo ya dibujado (copas en "coliflor")
            for x, y, i, d in drawn:
                if d > .62 and (y + .5 - cy) > -ry * .1:
                    for dx, dy in ((0, 1), (1, 0), (-1, 0), (0, -1)):
                        xx, yy = x + dx, y + dy
                        if 0 <= xx < s.w and 0 <= yy < s.h and prev[yy, xx]:
                            inside = ((xx + .5 - cx) / rx) ** 2 + ((yy + .5 - cy) / ry) ** 2 <= 1
                            if not inside:
                                s.px(x, y, ramp, 1); break
    def rect(s, x0, y0, w, h, ramp, i, shade_lr=True):
        for y in range(y0, y0 + h):
            for x in range(x0, x0 + w):
                k = i
                if shade_lr and w >= 3:
                    if x == x0: k = i + 1
                    elif x == x0 + w - 1: k = i - 1
                s.px(x, y, ramp, k)
    def line(s, x0, y0, x1, y1, ramp, i):
        n = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
        for k in range(n + 1):
            t = k / max(1, n)
            s.px(round(x0 + (x1 - x0) * t), round(y0 + (y1 - y0) * t), ramp, i)
    def outline(s, color=None):
        """Contorno selectivo: cada borde toma el tono más oscuro de su vecino."""
        sol = s.solid.copy()
        out = []
        for y in range(s.h):
            for x in range(s.w):
                if sol[y, x]: continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    xx, yy = x + dx, y + dy
                    if 0 <= xx < s.w and 0 <= yy < s.h and sol[yy, xx]:
                        rid = s.r[yy, xx]
                        col = color or (RAMP[list(RAMPS)[rid]][0] if rid >= 0 else OUTLINE)
                        out.append((x, y, col)); break
        for x, y, col in out:
            s.c[y, x] = col
    def img(s):
        return Image.fromarray(s.c, 'RGBA')

def strip(frames):
    w, h = frames[0].w, frames[0].h
    im = Image.new('RGBA', (w * len(frames), h))
    for k, f in enumerate(frames): im.paste(f.img(), (k * w, 0))
    return im

INDEX = {'tile': T, 'sprites': {}}
def save_sprite(name, frames, ox=None, oy=None):
    im = strip(frames if isinstance(frames, list) else [frames])
    im.save(f'{OUT}/{name}.png')
    f0 = frames[0] if isinstance(frames, list) else frames
    INDEX['sprites'][name] = {'w': f0.w, 'h': f0.h, 'frames': len(frames) if isinstance(frames, list) else 1,
                              'ox': f0.w // 2 if ox is None else ox, 'oy': f0.h - 2 if oy is None else oy}

# =================================================================== casillas
def rng_for(*a):
    return random.Random(hash(a) & 0xffffffff)

def tile_base(kind, v, frame=0):
    r = rng_for(kind, v)
    c = Cv(T, T)
    def fill(ramp, i):
        for y in range(T):
            for x in range(T): c.px(x, y, ramp, i)
    def speck(ramp, i, n, sz=1):
        for _ in range(n):
            x, y = r.randrange(T), r.randrange(T)
            for k in range(sz): c.px((x + k) % T, y, ramp, i)
    if kind in ('grass', 'flower', 'forest'):
        g = 'fgrass' if kind == 'forest' else 'grass'
        fill(g, 3)
        for _ in range(7):
            x, y = r.randrange(T), r.randrange(T)
            c.px(x, y, g, 2); c.px(x + 1, y, g, 2)
        for _ in range(9):   # matitas de pasto: "v" clara con sombra
            x, y = r.randrange(1, T - 1), r.randrange(2, T)
            c.px(x, y, g, 4); c.px(x - 1, y - 1, g, 4); c.px(x + 1, y - 1, g, 5 if r.random() < .5 else 4); c.px(x, y + 1 if y + 1 < T else y, g, 2)
        if kind == 'flower':
            cols = [('yellow', 4), ('pink', 4), ('white', 5), ('purple', 4), ('orange', 4)]
            for _ in range(7):
                x, y = r.randrange(1, T - 1), r.randrange(1, T - 1)
                cr, ci = cols[r.randrange(len(cols))]
                c.px(x, y, cr, ci); c.px(x + 1, y, cr, ci - 1); c.px(x, y + 1, g, 1)
        if kind == 'forest':
            for _ in range(5):
                x, y = r.randrange(T), r.randrange(T)
                c.px(x, y, 'brown', 3)
    elif kind == 'dirt':
        fill('dirt', 3)
        speck('dirt', 2, 14); speck('dirt', 4, 6)
        for _ in range(2):
            x, y = r.randrange(1, T - 2), r.randrange(1, T - 2)
            c.px(x, y, 'dirt', 5); c.px(x + 1, y, 'dirt', 4); c.px(x, y + 1, 'dirt', 1); c.px(x + 1, y + 1, 'dirt', 1)
    elif kind == 'tox':
        fill('tox', 2)
        speck('tox', 1, 14); speck('tox', 3, 10)
        if v == 0:
            cx, cy = r.uniform(5, 11), r.uniform(5, 11)
            rx, ry = (3.4, 2.3)
            for y in range(T):
                for x in range(T):
                    d = ((x + .5 - cx) / rx) ** 2 + ((y + .5 - cy) / ry) ** 2 + .25 * math.sin(x * 1.7 + y)
                    if d < 1: c.px(x, y, 'slime', 2 if d > .5 else 3)
                    elif d < 1.35: c.px(x, y, 'tox', 0)
            c.px(int(cx) - 1, int(cy) - 1, 'slime', 4)
            c.px(int(cx) + 1, int(cy), 'slime', 4) if frame % 2 else None
        elif v == 2:
            x, y = r.randrange(3, T - 3), r.randrange(3, T - 3)
            c.px(x, y, 'slime', 3); c.px(x + 1, y, 'slime', 2); c.px(x, y + 1, 'tox', 0)
    elif kind == 'ash':
        fill('ash', 2)
        speck('ash', 1, 16); speck('ash', 4, 7)
        if v == 1: c.px(r.randrange(T), r.randrange(T), 'lava', 3)
    elif kind == 'sand':
        fill('sand', 3)
        for k in range(3):
            y = r.randrange(2, T - 1); x0 = r.randrange(0, 8)
            for x in range(x0, x0 + r.randrange(4, 8)): c.px(x, y, 'sand', 4); c.px(x, y + 1, 'sand', 2)
        speck('sand', 1, 4)
    elif kind in ('rock', 'mnt'):
        fill('rock', 2 if kind == 'rock' else 1)
        speck('rock', 1, 10)
        for _ in range(3 if kind == 'rock' else 2):   # piedras planas
            x, y = r.randrange(1, T - 4), r.randrange(1, T - 3)
            w = r.randrange(3, 5)
            for xx in range(x, x + w): c.px(xx, y, 'rock', 4); c.px(xx, y + 1, 'rock', 3); c.px(xx, y + 2, 'rock', 1)
    elif kind in ('water', 'sea', 'tsea', 'oil', 'marsh', 'lava'):
        ramp = kind
        base = {'water': 3, 'sea': 3, 'tsea': 3, 'oil': 2, 'marsh': 3, 'lava': 2}[kind]
        fill(ramp, base)
        ph = frame * 4
        for k in range(5):   # ondas que se desplazan
            y = (r.randrange(T) + (frame if kind != 'lava' else 0)) % T
            x0 = (r.randrange(T) + ph) % T
            ln = r.randrange(3, 6)
            for x in range(x0, x0 + ln):
                c.px(x % T, y, ramp, base + 1)
                if kind in ('water', 'sea', 'tsea') and x == x0 + 1: c.px(x % T, y, ramp, base + 2)
        for k in range(4):
            x, y = r.randrange(T), r.randrange(T)
            c.px(x, y, ramp, base - 1)
        if kind == 'lava':
            for k in range(3):
                cx, cy = (r.uniform(0, T) + frame * 1.3) % T, r.uniform(0, T)
                for y in range(T):
                    for x in range(T):
                        d = ((x + .5 - cx) / 3.2) ** 2 + ((y + .5 - cy) / 2.2) ** 2
                        if d < 1: c.px(x, y, 'lava', 4 if d < .35 else 3)
            for k in range(5):
                x, y = r.randrange(T), r.randrange(T)
                c.px(x, y, 'lava', 1); c.px(x + 1, y, 'lava', 1)
        if kind == 'oil':
            for k in range(4):   # brillo iridiscente
                y = (r.randrange(T) + frame) % T; x0 = r.randrange(T)
                cols = [('purple', 3), ('teal', 4), ('oil', 5)]
                for j, x in enumerate(range(x0, x0 + 6)): 
                    cr, ci = cols[(j + k) % 3]; c.px(x % T, y, cr, ci)
        if kind == 'marsh':
            for k in range(2):   # nenúfares
                x, y = r.randrange(2, T - 3), r.randrange(2, T - 3)
                for dx, dy in ((0, 0), (1, 0), (0, 1), (1, 1), (2, 0), (-1, 1)):
                    c.px(x + dx, y + dy, 'leaf', 4 if dy == 0 else 3)
                if k == 0 and v % 2: c.px(x + 1, y - 1, 'pink', 4)
    elif kind == 'ice':
        fill('ice', 3)
        for k in range(2):
            x, y = r.randrange(T), r.randrange(T)
            for s in range(r.randrange(4, 8)):
                c.px(x, y, 'ice', 1); x += r.choice([1, 1, 0]); y += r.choice([1, 0, -1])
        speck('ice', 4, 6)
    elif kind == 'bed':
        fill('mud', 2)
        for y in range(5, 11):
            for x in range(T): c.px(x, y, 'mud', 1 if 6 <= y <= 9 else 2)
        speck('mud', 3, 6)
        for _ in range(3): c.px(r.randrange(T), r.randrange(T), 'rock', 3)
    return c

KIND_OF = {'tox': 'tox', 'dirt': 'dirt', 'grass': 'grass', 'forest': 'forest', 'water': 'water', 'wet': 'marsh',
           'flower': 'flower', 'rock': 'rock', 'mnt': 'mnt', 'sea': 'sea', 'sand': 'sand', 'mang': 'marsh',
           'ash': 'ash', 'ice': 'ice', 'lava': 'lava', 'oil': 'oil', 'bed': 'bed'}
ANIM = {'water', 'sea', 'tsea', 'oil', 'marsh', 'lava', 'tox'}
KINDS = ['tox', 'dirt', 'grass', 'forest', 'water', 'marsh', 'flower', 'rock', 'mnt', 'sea', 'tsea', 'sand', 'ash', 'ice', 'lava', 'oil', 'bed']
WATERISH = {'water', 'sea', 'tsea', 'oil', 'marsh'}

# Bordes: el tipo de arriba "se derrama" sobre el vecino con borde irregular
EDGE_LINE = {'grass': ('grass', 1), 'flower': ('grass', 1), 'forest': ('fgrass', 0), 'dirt': ('dirt', 1), 'tox': ('tox', 0),
             'ash': ('ash', 0), 'sand': ('sand', 1), 'rock': ('rock', 0), 'mnt': ('rock', 0), 'ice': ('ice', 1),
             'bed': ('mud', 0), 'lava': ('lava', 1), 'water': ('water', 2), 'marsh': ('marsh', 1), 'sea': ('sea', 2), 'tsea': ('tsea', 2), 'oil': ('oil', 0)}

def edge_masks():
    """Máscaras de borde (N, E, S, W y esquinas) con contorno irregular."""
    r = random.Random(7)
    prof = [3 + (1 if r.random() < .5 else 0) - (1 if r.random() < .25 else 0) for _ in range(T)]
    for i in range(1, T - 1): prof[i] = round((prof[i - 1] + prof[i] * 2 + prof[i + 1]) / 4)
    M = {}
    n = np.zeros((T, T), bool)
    for x in range(T):
        for y in range(prof[x]): n[y, x] = True
    M['n'] = n; M['e'] = np.rot90(n, -1); M['s'] = np.rot90(n, 2); M['w'] = np.rot90(n, 1)
    cn = np.zeros((T, T), bool)
    for y in range(T):
        for x in range(T):
            if (x + .5) ** 2 + (y + .5) ** 2 < 5.2 ** 2: cn[y, x] = True
    M['nw'] = cn; M['ne'] = np.fliplr(cn); M['se'] = np.rot90(cn, 2); M['sw'] = np.flipud(cn)
    return M
MASKS = edge_masks()
DIRS = ['n', 'e', 's', 'w', 'ne', 'se', 'sw', 'nw']

def edge_tile(kind, d, onto_water, frame=0):
    src = tile_base(kind, 0, frame)
    m = MASKS[d]
    c = Cv(T, T)
    lr, li = EDGE_LINE[kind]
    for y in range(T):
        for x in range(T):
            if m[y, x]:
                c.c[y, x] = src.c[y, x]
    # línea de borde y espuma
    for y in range(T):
        for x in range(T):
            if not m[y, x]: continue
            border = False
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                xx, yy = x + dx, y + dy
                if 0 <= xx < T and 0 <= yy < T and not m[yy, xx]: border = True
            if border:
                c.px(x, y, lr, li)
    if onto_water and kind not in WATERISH:
        for y in range(T):
            for x in range(T):
                if m[y, x]: continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    xx, yy = x + dx, y + dy
                    if 0 <= xx < T and 0 <= yy < T and m[yy, xx]:
                        if (x + y + frame) % 3 != 0: c.rgba(x, y, hx('#e8f6f6'))
                        break
    return c

# atlas: una fila por tipo. columnas: 4 variantes x 4 cuadros | 8 bordes x (tierra, agua) x 4 cuadros
COLS_BASE = 16
atlas_rows = []
for kind in KINDS:
    cells = []
    for v in range(4):
        for f in range(4):
            cells.append(tile_base(kind, v, f if kind in ANIM else 0))
    for ow in (False, True):
        for d in DIRS:
            for f in range(4):
                cells.append(edge_tile(kind, d, ow, f if kind in ANIM else 0))
    atlas_rows.append(cells)
ncol = len(atlas_rows[0])
atlas = Image.new('RGBA', (ncol * T, len(KINDS) * T))
for ry, row in enumerate(atlas_rows):
    for cx, cell in enumerate(row): atlas.paste(cell.img(), (cx * T, ry * T))
atlas.save(f'{OUT}/tiles.png')
INDEX['tiles'] = {'kinds': KINDS, 'cols': ncol, 'kind_of': KIND_OF, 'dirs': DIRS, 'anim': sorted(ANIM)}

# =================================================================== sprites
def tree_broad(seed, ramp='leaf'):
    r = random.Random(seed)
    c = Cv(26, 32)
    c.shadow(13, 29, 9, 3)
    c.rect(11, 18, 4, 12, 'bark', 2)
    c.px(10, 29, 'bark', 1); c.px(15, 29, 'bark', 1); c.px(12, 22, 'bark', 0)
    clumps = [(13, 14, 8, 6.5)]
    for k in range(6):
        a = r.uniform(0, math.tau); d = r.uniform(3.5, 5.5)
        clumps.append((13 + math.cos(a) * d * 1.2, 12 + math.sin(a) * d * .9, r.uniform(4.2, 5.5), r.uniform(3.6, 4.6)))
    clumps.sort(key=lambda t: t[1] + (t[0] - 13) * .1, reverse=True)
    for cx, cy, rx, ry in clumps[::-1]:
        lift = -.12 + (14 - cy) * .03
        c.blob(cx, cy, rx, ry, ramp, lift=lift)
    # brillos
    for _ in range(4):
        x, y = r.randrange(6, 16), r.randrange(4, 12)
        if c.solid[y, x] and c.r[y, x] == RID[ramp] and tuple(c.c[y, x]) == RAMP[ramp][-2]: c.px(x, y, ramp, len(RAMP[ramp]) - 1)
    c.outline()
    return c

def tree_pine(seed, ramp='pine', snow=False):
    r = random.Random(seed)
    c = Cv(18, 32)
    c.shadow(9, 29, 6, 2.5)
    c.rect(8, 25, 3, 5, 'bark', 2)
    tiers = 4
    for k in range(tiers):
        y0 = 4 + k * 5; h = 9; half = 3 + k * 1.6
        for y in range(y0, y0 + h):
            t = (y - y0) / h
            w = half * t + .5
            for x in range(18):
                dx = x + .5 - 9
                if abs(dx) <= w:
                    i = 4 if dx < -w * .3 else (3 if dx < w * .4 else 2)
                    if y == y0 + h - 1 or (y == y0 + h - 2 and abs(dx) > w - 1.5): i = 1
                    if snow and t < .35 and y > y0: i = len(RAMP[ramp]) - 1 if ramp == 'taiga' else i
                    c.px(x, y, ramp, i)
    c.px(9, 3, ramp, 4)
    c.outline()
    return c

def palm(seed):
    r = random.Random(seed)
    c = Cv(26, 32)
    c.shadow(13, 29, 8, 2.5)
    x, y = 12, 29
    bend = r.choice([-1, 1])
    for k in range(18):
        c.px(x, y - k, 'bark', 3 if k % 3 else 2); c.px(x + 1, y - k, 'bark', 2)
        if k % 5 == 4: x += bend
    top = (x, y - 18)
    for k in range(7):
        a = math.pi + k * math.pi / 6 + r.uniform(-.1, .1)
        for s in range(9):
            px = top[0] + math.cos(a) * s * 1.2; py = top[1] + math.sin(a) * s * .8 + s * s * .06
            c.px(px, py, 'jungle', 4 if s < 5 else 3); c.px(px, py + 1, 'jungle', 2)
    c.blob(top[0] + .5, top[1] + 1, 2, 1.6, 'brown')
    c.outline()
    return c

def bush(seed, flowers=None):
    r = random.Random(seed)
    c = Cv(16, 14)
    c.shadow(8, 12, 6, 2)
    for k in range(3):
        c.blob(5 + k * 3 + r.uniform(-.5, .5), 8 - (k % 2) * 1.5, 3.6, 3.2, 'leaf', lift=.05)
    if flowers:
        for _ in range(6):
            x, y = r.randrange(3, 13), r.randrange(4, 10)
            if c.solid[y, x]: c.px(x, y, flowers, 4); c.px(x + 1, y, flowers, 3)
    c.outline()
    return c

def boulder(seed, ramp='rock'):
    r = random.Random(seed)
    c = Cv(14, 12)
    c.shadow(7, 10, 6, 2)
    c.blob(7, 7, 5.5, 4, ramp, lift=.05, inner_line=False)
    if r.random() < .6: c.blob(10, 8, 3, 2.6, ramp, lift=0)
    c.outline()
    return c

def peak(seed, snow=False, dark=False):
    r = random.Random(seed)
    c = Cv(20, 22)
    ramp = 'ash' if dark else 'rock'
    c.shadow(10, 20, 9, 2.5)
    pts = []
    for y in range(3, 21):
        t = (y - 3) / 17
        w = 1 + t * 8.5
        for x in range(20):
            dx = x + .5 - 10 - (1 - t) * 1.2
            if abs(dx) <= w:
                i = 4 if dx < -w * .2 else (3 if dx < w * .35 else 1)
                if y > 18: i = max(1, i - 1)
                if snow and t < .38: i = 3 if dx > w * .35 else 4; ramp2 = 'snow'
                c.px(x, y, 'snow' if (snow and t < .38) else ramp, i)
    # grieta
    x = 10
    for y in range(8, 18): c.px(x + (y % 3 == 0), y, ramp, 2)
    c.outline()
    return c

def dead_tree(seed):
    c = Cv(14, 20)
    c.shadow(7, 18, 4, 1.5)
    c.rect(6, 6, 2, 12, 'bark', 2, False)
    c.line(7, 9, 3, 4, 'bark', 2); c.line(7, 11, 11, 6, 'bark', 2); c.line(4, 5, 3, 2, 'bark', 1)
    c.outline()
    return c

def reeds(seed):
    r = random.Random(seed)
    c = Cv(14, 16)
    for k in range(6):
        x = r.randrange(3, 11); h = r.randrange(6, 11)
        for y in range(14 - h, 15): c.px(x, y, 'grass', 4 if y < 14 - h + 3 else 3)
        if k < 2:
            c.px(x, 14 - h - 1, 'brown', 4); c.px(x, 14 - h - 2, 'brown', 3); c.px(x, 14 - h - 3, 'brown', 3)
    c.outline()
    return c

def mangrove(seed):
    c = Cv(22, 24)
    for k in range(5):
        x0 = 4 + k * 3.5
        c.line(x0, 22, 11, 14, 'bark', 3)
    c.rect(10, 11, 3, 5, 'bark', 2)
    c.blob(11, 9, 8, 5.5, 'jungle', lift=0)
    c.blob(7, 8, 4, 3.5, 'jungle', lift=.08)
    c.blob(15, 8, 4, 3.5, 'jungle', lift=.08)
    c.outline()
    return c

veg = {}
for k in range(3): veg[f'broad{k}'] = tree_broad(10 + k)
for k in range(2): veg[f'jungle{k}'] = tree_broad(20 + k, 'jungle')
for k in range(3): veg[f'pine{k}'] = tree_pine(30 + k)
for k in range(2): veg[f'spruce{k}'] = tree_pine(40 + k, 'taiga', True)
for k in range(2): veg[f'palm{k}'] = palm(50 + k)
for k in range(2): veg[f'bush{k}'] = bush(60 + k)
for k, fc in enumerate(['yellow', 'pink', 'purple']): veg[f'fbush{k}'] = bush(70 + k, fc)
for k in range(3): veg[f'rock{k}'] = boulder(80 + k)
for k in range(2): veg[f'dead{k}'] = dead_tree(90 + k)
for k in range(2): veg[f'reed{k}'] = reeds(100 + k)
veg['mang0'] = mangrove(110)
for k in range(2): veg[f'peak{k}'] = peak(120 + k)
for k in range(2): veg[f'peaksnow{k}'] = peak(130 + k, True)
for k in range(2): veg[f'peakdark{k}'] = peak(140 + k, False, True)
for name, cv in veg.items(): save_sprite(name, cv)

# =================================================================== edificios
def pad(c, cx, cy, rx=7):
    c.shadow(cx, cy + 1, rx + 1, 2.5)
    c.blob(cx, cy, rx, 2.6, 'cream', lift=.1, inner_line=False)

def lamp(c, x, y, on):
    c.px(x, y, 'frog' if on else 'red', 4)

def b_turbine(frame):
    c = Cv(26, 40)
    pad(c, 13, 36, 5)
    for y in range(10, 36):
        w = 1 if y < 22 else 2
        for x in range(13 - w, 13 + w): c.px(x, y, 'white', 4 if x < 13 else 3)
    c.rect(11, 8, 5, 3, 'white', 4)
    hub = (13, 9)
    for k in range(3):
        a = frame * (math.tau / 3 / 4) + k * math.tau / 3
        for s in range(2, 12):
            x = hub[0] + math.cos(a) * s; y = hub[1] + math.sin(a) * s
            c.px(x, y, 'red' if s > 9 else 'white', 3 if s > 9 else 5)
    c.px(13, 9, 'steel', 3)
    c.outline()
    return c

def b_geo(frame):
    c = Cv(26, 26)
    pad(c, 13, 22, 10)
    for cx in (8, 18):
        for y in range(8, 22):
            t = (y - 8) / 14
            w = 3.5 - math.sin(t * math.pi) * 1.0 + t * .8
            for x in range(26):
                dx = x + .5 - cx
                if abs(dx) <= w: c.px(x, y, 'cream', 4 if dx < -w * .3 else (3 if dx < w * .4 else 2))
        for x in range(cx - 3, cx + 4): c.px(x, 8, 'red', 3)
    c.rect(4, 18, 18, 3, 'steel', 3)
    c.outline()
    return c

def b_scrub(frame):
    c = Cv(20, 24)
    pad(c, 10, 20, 7)
    c.rect(4, 9, 12, 11, 'teal', 3)
    c.blob(10, 9, 6, 3, 'teal', lift=.15, inner_line=False)
    for x in range(4, 16): c.px(x, 14, 'gold', 3)
    fx = [(8, 6), (12, 6)] if frame % 2 else [(10, 5), (10, 7)]
    for x, y in fx: c.px(x, y, 'steel', 4)
    c.px(10, 6, 'steel', 2)
    c.outline()
    return c

def b_sprink(frame):
    c = Cv(26, 24)
    pad(c, 13, 20, 5)
    c.rect(11, 16, 5, 4, 'blue', 3)
    for y in range(6, 17): c.px(13, y, 'steel', 4); c.px(14, y, 'steel', 3)
    a = frame * math.pi / 4
    for s in range(-10, 11):
        c.px(13 + math.cos(a) * s, 6 + math.sin(a) * s * .35, 'steel', 4)
    for s in (-10, 10):
        x = 13 + math.cos(a) * s; y = 6 + math.sin(a) * s * .35
        for k in range(3): c.px(x + (k - 1) * (1 if s > 0 else -1), y + 2 + k, 'water', 6)
    c.outline()
    return c

def b_pump(frame):
    c = Cv(20, 20)
    pad(c, 10, 17, 7)
    c.rect(4, 9, 10, 8, 'brick', 3)
    for y in range(3, 9):
        w = (y - 3) + 1
        for x in range(9 - w, 9 + w + 1): c.px(x, y, 'roof', 4 if x < 9 else 2)
    c.rect(7, 12, 3, 5, 'wood', 2)
    c.rect(14, 12, 4, 2, 'steel', 3)
    c.px(17, 14 + frame % 2, 'water', 6)
    c.outline()
    return c

def b_solar(frame):
    c = Cv(20, 20)
    pad(c, 10, 17, 5)
    c.rect(9, 10, 2, 7, 'steel', 3)
    for y in range(3, 11):
        for x in range(2, 18):
            sk = (x - 2) + (y - 3)
            c.px(x, y, 'glass', 5 if (sk + frame) % 7 == 0 else (4 if y < 6 else 3))
    for x in range(2, 18): c.px(x, 10, 'steel', 2)
    c.outline()
    return c

def b_cloud(frame):
    c = Cv(14, 36)
    pad(c, 7, 32, 4)
    for y in range(4, 32):
        w = 1.5 if y < 20 else 2.5
        for x in range(14):
            dx = x + .5 - 7
            if abs(dx) <= w: c.px(x, y, 'white', 4 if dx < 0 else 3)
    for y in (12, 22):
        for x in range(3, 11): c.px(x, y, 'blue', 3)
    c.blob(7, 4, 3.5, 2, 'blue', lift=.2, inner_line=False)
    c.outline()
    return c

def b_cooler(frame):
    c = Cv(20, 20)
    pad(c, 10, 17, 7)
    c.rect(3, 7, 14, 10, 'teal', 4)
    for x in range(4, 16, 2):
        for y in range(11, 16): c.px(x, y, 'teal', 1)
    c.blob(10, 7, 5, 2, 'steel', lift=.1, inner_line=False)
    b = [(7, 7), (13, 7)] if frame % 2 else [(10, 6), (10, 8)]
    for x, y in b: c.px(x, y, 'white', 5)
    c.outline()
    return c

def b_nursery(frame):
    c = Cv(26, 20)
    pad(c, 13, 17, 10)
    for y in range(6, 17):
        for x in range(3, 23):
            dy = (y - 16) / 10; dx = (x + .5 - 13) / 10
            if dx * dx + dy * dy <= 1.0:
                frame_px = (x - 3) % 5 == 0 or y == 16
                c.px(x, y, 'white' if frame_px else 'glass', 4 if frame_px else (5 if (x + y) % 9 == 0 else 3))
    for k in range(4): c.blob(7 + k * 4, 14, 1.6, 1.4, 'leaf', lift=.1, inner_line=False)
    c.outline()
    return c

def b_hive(frame):
    c = Cv(20, 20)
    c.shadow(10, 18, 8, 2)
    for k, (x, h) in enumerate([(3, 8), (8, 11), (13, 8)]):
        c.rect(x, 17 - h, 5, h, 'gold', 3)
        c.rect(x - 1, 16 - h, 7, 1, 'wood', 4, False)
        c.px(x + 2, 15, 'brown', 0)
    for k in range(3):
        bx = (frame * 3 + k * 6) % 18 + 1; by = 3 + (k * 2 + frame) % 4
        c.px(bx, by, 'yellow', 4); c.px(bx + 1, by, 'black', 2)
    c.outline()
    return c

def b_hydro(frame):
    c = Cv(26, 22)
    pad(c, 13, 18, 10)
    c.blob(13, 15, 9, 3.6, 'steel', lift=.2, inner_line=False)
    c.blob(13, 15, 7.5, 2.6, 'marsh', lift=.1, inner_line=False)
    for k in range(5): c.px(7 + k * 3, 14 + k % 2, 'leaf', 5)
    for y in range(5, 15): c.px(13, y, 'steel', 4)
    a = frame * math.pi / 4
    for s in range(-8, 9): c.px(13 + math.cos(a) * s, 5 + math.sin(a) * s * .35, 'steel', 4)
    c.outline()
    return c

def b_obs(frame):
    c = Cv(22, 24)
    pad(c, 11, 20, 8)
    c.rect(4, 12, 14, 8, 'white', 4)
    c.blob(11, 12, 7, 6, 'white', lift=.15, inner_line=False)
    sx = 9 + frame % 3
    for y in range(6, 13): c.px(sx, y, 'steel', 1); c.px(sx + 1, y, 'steel', 1)
    for x in range(4, 18): c.px(x, 13, 'gold', 3)
    c.rect(10, 16, 3, 4, 'steel', 1)
    c.outline()
    return c

def b_calc(frame):
    """Calcificador: toma agua y la convierte en roca."""
    c = Cv(24, 24)
    pad(c, 12, 20, 9)
    c.rect(5, 9, 10, 11, 'steel', 3)
    c.blob(10, 9, 5, 2.2, 'steel', lift=.25, inner_line=False)
    for y in range(11, 19): c.px(7, y, 'water', 4 if (y + frame) % 3 else 6)
    c.rect(15, 15, 6, 2, 'steel', 2, False)
    for k, (x, h) in enumerate([(17, 5), (20, 3), (14, 2)]):
        for yy in range(h):
            for xx in range(2):
                c.px(x + xx, 19 - yy, 'rock', 4 - yy % 2 + (1 if xx == 0 else 0))
    c.px(10, 6 - frame % 2, 'water', 5)
    lamp(c, 12, 12, frame % 2 == 0)
    c.outline()
    return c

def b_monsoon(frame):
    """Torre monzón: siembra nubes para provocar lluvias."""
    c = Cv(20, 44)
    pad(c, 10, 40, 6)
    for y in range(12, 40):
        w = 1.5 if y < 26 else 2.6
        for x in range(20):
            dx = x + .5 - 10
            if abs(dx) <= w: c.px(x, y, 'steel', 4 if dx < 0 else 3)
    for y in range(16, 40, 6):
        for x in range(6, 14):
            if c.solid[y, x]: c.px(x, y, 'blue', 3)
    c.blob(10, 11, 6, 2.2, 'white', lift=.2, inner_line=False)
    c.rect(9, 6, 3, 4, 'steel', 4)
    for k in range(3):
        cx = 4 + ((frame * 2 + k * 5) % 12); cy = 3 + (k % 2)
        c.blob(cx, cy, 2.6, 1.6, 'white', lift=.3, inner_line=False)
    c.outline()
    return c

BLD = {'tur': (b_turbine, 4), 'geo': (b_geo, 1), 'dep': (b_scrub, 2), 'asp': (b_sprink, 4), 'pum': (b_pump, 2),
       'sol': (b_solar, 4), 'nub': (b_cloud, 1), 'fri': (b_cooler, 2), 'viv': (b_nursery, 1), 'col': (b_hive, 4),
       'hid': (b_hydro, 4), 'obs': (b_obs, 3), 'cal': (b_calc, 2), 'mon': (b_monsoon, 4)}
for k, (fn, nf) in BLD.items():
    save_sprite('b_' + k, [fn(f) for f in range(nf)])

# =================================================================== animales
def quad(body, belly, L=10, H=5, leg=3, head='deer', frame=0, extra=None):
    w = L + 8; h = H + leg + 8
    c = Cv(w, h)
    by = h - leg - 2
    c.shadow(w / 2, h - 1.5, L / 2 + 1, 1.5)
    graze = frame == 3
    # patas
    for k, lx in enumerate([3, 5, L, L + 2]):
        off = 0
        if frame in (1, 2): off = (1 if (k % 2) == (frame - 1) else -1)
        for y in range(by, by + leg + 1):
            c.px(lx + (off if y == by + leg else 0), y, body, 1 if k in (1, 3) else 2)
    # cuerpo
    c.blob(L / 2 + 4, by - H / 2 + 1, L / 2 + .5, H / 2 + .3, body, lift=.08, inner_line=False)
    for x in range(5, L + 2): c.px(x, by, belly, 3)
    # cabeza
    hx_, hy = (L + 5, by - H + 1) if not graze else (L + 5, by + 1)
    c.blob(hx_, hy, 2.6, 2.1, body, lift=.12, inner_line=False)
    c.px(hx_ + 2, hy + 1 if not graze else hy + 1, body, 1)
    c.px(hx_ + 1, hy - (0 if graze else 1), 'black', 0)
    c.px(hx_ - 1, hy - 2, body, 2)
    if extra == 'antler':
        for k in range(3): c.px(hx_ - 1 + (k == 2), hy - 3 - k, 'cream', 4)
        c.px(hx_ - 2, hy - 4, 'cream', 4)
    if extra == 'horn':
        c.px(hx_ - 1, hy - 3, 'grey', 3); c.px(hx_ - 2, hy - 4, 'grey', 3)
    if extra == 'tail':
        c.px(3, by - H + 2, body, 3); c.px(2, by - H + 3, belly, 4)
    c.outline()
    return c

def small(body, belly, kind, frame):
    c = Cv(12, 10)
    c.shadow(6, 8.5, 4, 1.2)
    hop = 1 if (frame in (1, 2) and kind in ('rabbit', 'hare', 'frog')) and frame == 1 else 0
    c.blob(5.5, 6 - hop, 3.6, 2.6, body, lift=.08, inner_line=False)
    c.blob(8.5, 4.5 - hop, 2.2, 2, body, lift=.12, inner_line=False)
    if kind in ('rabbit', 'hare'):
        c.px(8, 1 - hop, body, 3); c.px(8, 2 - hop, body, 3); c.px(9, 1 - hop, body, 2); c.px(9, 2 - hop, body, 2)
        if kind == 'hare': c.px(8, 0, 'black', 1)
    if kind == 'frog':
        c.px(8, 3 - hop, 'white', 5); c.px(9, 3 - hop, 'black', 0)
    else:
        c.px(9, 4 - hop, 'black', 0)
    if kind == 'beaver':
        for x in range(0, 3): c.px(x, 7, 'brown', 1)
    if kind == 'fox':
        c.px(8, 2, body, 4); c.px(1, 5, body, 4); c.px(0, 5, body, 5)
    c.outline()
    return c

def bird(body, wing, kind, frame):
    c = Cv(12, 10)
    up = frame % 2 == 0
    c.blob(6, 5, 2.6, 1.8, body, lift=.15, inner_line=False)
    c.px(9, 4, body, 3); c.px(10, 4, 'gold' if kind != 'bee' else 'black', 3)
    for k in range(4):
        y = 3 - k if up else 5 + k // 2
        c.px(5 - k // 2, y, wing, 4); c.px(6 + k // 3, y, wing, 3)
    if kind == 'bee':
        c.px(5, 5, 'black', 1); c.px(7, 5, 'black', 1)
    c.outline()
    return c

def wader(body, frame, flam=False):
    c = Cv(12, 18)
    c.shadow(6, 16.5, 3, 1)
    legc = 'pink' if flam else 'gold'
    c.px(5, 16, legc, 2); c.px(7, 16, legc, 2)
    for y in range(10, 16): c.px(5, y, legc, 3)
    if frame != 1:
        for y in range(10, 16): c.px(7, y, legc, 3)
    c.blob(6, 8, 3.2, 2.3, body, lift=.15, inner_line=False)
    neck = [(8, 6), (8, 5), (9, 4), (9, 3)] if frame != 3 else [(8, 8), (9, 9), (9, 10), (9, 11)]
    for x, y in neck: c.px(x, y, body, 4)
    hx_, hy = neck[-1]
    c.px(hx_ + 1, hy, body, 4); c.px(hx_ + 2, hy, 'gold' if not flam else 'black', 2); c.px(hx_ + 3, hy + (1 if flam else 0), 'gold' if not flam else 'black', 2)
    c.px(hx_, hy - 1 if frame != 3 else hy, 'black', 0) if False else None
    c.outline()
    return c

def floater(body, head, kind, frame):
    c = Cv(14, 10)
    for x in range(2, 12): c.rgba(x, 8, hx('#e8f6f6') if (x + frame) % 3 else (0, 0, 0, 0))
    if kind == 'duck':
        c.blob(6, 6, 3.6, 2, body, lift=.1, inner_line=False)
        c.blob(9, 3.5, 1.8, 1.6, head, lift=.15, inner_line=False)
        c.px(11, 4, 'gold', 3); c.px(9, 3, 'black', 0)
    elif kind == 'seal':
        c.blob(7, 6, 5, 2.2, body, lift=.12, inner_line=False)
        c.blob(11, 4.5, 2, 1.8, body, lift=.15, inner_line=False); c.px(12, 4, 'black', 0)
    elif kind == 'turtle':
        c.blob(7, 6, 4, 2.6, 'leaf', lift=.1, inner_line=False)
        for x in (5, 7, 9): c.px(x, 5, 'leaf', 2)
        c.blob(11.5, 6.5, 1.5, 1.2, 'frog', lift=.1, inner_line=False)
    elif kind == 'beaver':
        c.blob(6, 6, 4, 2, body, lift=.1, inner_line=False)
        c.blob(10, 5, 1.8, 1.6, body, lift=.12, inner_line=False); c.px(11, 4, 'black', 0)
    c.outline()
    return c

def manta(frame):
    c = Cv(18, 12)
    w = 8 if frame % 2 == 0 else 7
    for y in range(12):
        for x in range(18):
            dx = abs(x + .5 - 9) / w; dy = abs(y + .5 - 6) / 4
            if dx + dy * 1.4 < 1: c.rgba(x, y, (24, 40, 64, 160))
    return c

def whale(frame):
    c = Cv(28, 16)
    for x in range(0, 28): c.rgba(x, 12, hx('#e8f6f6') if (x + frame) % 3 == 0 else (0, 0, 0, 0))
    c.blob(13, 11, 10, 3.5 + (1 if frame == 1 else 0), 'blue', lift=.05, inner_line=False)
    for y in range(9, 12): c.px(2, y, 'blue', 1); c.px(1, y - 1, 'blue', 1); c.px(3, y - 1, 'blue', 1)
    if frame == 2:
        for k in range(5): c.px(18 + (k % 2), 7 - k, 'water', 6); c.px(17 - k // 2, 3 - k // 2, 'water', 6)
    c.outline()
    return c

def flyer_frames(kind):
    if kind == 'butterfly':
        out = []
        for f in range(2):
            c = Cv(10, 8)
            wc = 'orange'
            if f == 0:
                c.blob(3, 3, 2.2, 2.4, wc, lift=.2, inner_line=False); c.blob(7, 3, 2.2, 2.4, wc, lift=.2, inner_line=False)
            else:
                c.blob(3.5, 3.5, 1.2, 2.4, wc, lift=.2, inner_line=False); c.blob(6.5, 3.5, 1.2, 2.4, wc, lift=.2, inner_line=False)
            for y in range(2, 6): c.px(5, y, 'black', 1)
            c.outline(); out.append(c)
        return out
    if kind == 'bee':
        return [bird('yellow', 'white', 'bee', f) for f in range(2)]
    return [bird('red', 'blue', 'parrot', f) for f in range(2)]

ANIMALS = {
    'deer': lambda f: quad('deer', 'cream', 10, 5, 4, extra='antler', frame=f),
    'reindeer': lambda f: quad('brown', 'cream', 11, 5, 4, extra='antler', frame=f),
    'goat': lambda f: quad('fur_w', 'fur_w', 9, 5, 3, extra='horn', frame=f),
    'bear': lambda f: quad('brown', 'brown', 12, 7, 3, frame=f),
    'wolf': lambda f: quad('grey', 'fur_w', 10, 5, 3, extra='tail', frame=f),
    'fox': lambda f: small('fur_w', 'white', 'fox', f),
    'rabbit': lambda f: small('deer', 'cream', 'rabbit', f),
    'hare': lambda f: small('fur_w', 'white', 'hare', f),
    'frog': lambda f: small('frog', 'frog', 'frog', f),
    'lizard': lambda f: small('frog', 'frog', 'lizard', f),
    'heron': lambda f: wader('white', f),
    'flamingo': lambda f: wader('pink', f, True),
    'duck': lambda f: floater('brown', 'leaf', 'duck', f),
    'seal': lambda f: floater('grey', 'grey', 'seal', f),
    'turtle': lambda f: floater('leaf', 'leaf', 'turtle', f),
    'beaver': lambda f: floater('brown', 'brown', 'beaver', f),
    'manta': lambda f: manta(f),
    'whale': lambda f: whale(f),
}
for k, fn in ANIMALS.items():
    save_sprite('a_' + k, [fn(f) for f in range(4 if k not in ('manta', 'whale') else 3)])
for k in ('butterfly', 'bee', 'parrot'):
    save_sprite('a_' + k, flyer_frames(k), oy=None)

# =================================================================== otros
def drone():
    c = Cv(16, 10)
    c.rect(5, 4, 6, 3, 'steel', 3); c.rect(6, 3, 4, 1, 'gold', 3, False)
    for x in (2, 13):
        for k in range(-2, 3): c.px(x + k, 2, 'white', 5)
        c.px(x, 3, 'steel', 2)
    c.outline()
    return c
save_sprite('drone', [drone()])

def airship():
    c = Cv(52, 34)
    c.blob(26, 12, 22, 9, 'cream', lift=.1, inner_line=False)
    for x in range(6, 47, 6):
        for y in range(4, 21):
            if c.solid[y, x]: c.px(x, y, 'cream', 2)
    c.rect(18, 24, 16, 6, 'wood', 3)
    for x in range(20, 33, 3): c.px(x, 26, 'yellow', 4)
    c.line(20, 20, 20, 24, 'wood', 1); c.line(32, 20, 32, 24, 'wood', 1)
    for k in range(6): c.px(4 - k // 2, 8 + k, 'red', 3); c.px(4 - k // 2, 16 - k, 'red', 3)
    c.outline()
    return c
save_sprite('airship', [airship()])

def fence(frame):
    c = Cv(16, 14)
    for x in (1, 13):
        c.rect(x, 1, 3, 12, 'wood', 3)
        c.px(x, 1, 'wood', 5); c.px(x + 1, 1, 'wood', 5)
    for y in (4, 8):
        for x in range(0, 16): c.px(x, y, 'wood', 4); c.px(x, y + 1, 'wood', 2)
    c.outline()
    return c
save_sprite('fence_h', [fence(0)])
def fence_v():
    c = Cv(6, 18)
    c.rect(1, 1, 3, 16, 'wood', 3)
    c.px(1, 1, 'wood', 5); c.px(2, 1, 'wood', 5)
    c.outline()
    return c
save_sprite('fence_v', [fence_v()])

# =================================================================== nave colonia
def lander(frame):
    """Nave de aterrizaje. frame 0 = cerrada, 1 = rampa abierta, 2 = motores encendidos."""
    W, H = 64, 54
    c = Cv(W, H)
    cx = 32
    if frame != 2: c.shadow(cx, 50, 26, 4, 80)
    # patas
    for sx in (-1, 1):
        x0 = cx + sx * 14; x1 = cx + sx * 24
        c.line(x0, 34, x1, 48, 'steel', 2); c.line(x0, 35, x1, 49, 'steel', 1)
        c.rect(x1 - 2, 48, 5, 2, 'steel', 3, False)
    c.line(cx, 38, cx, 49, 'steel', 2); c.rect(cx - 2, 49, 5, 1, 'steel', 3, False)
    # toberas
    for nx in (cx - 9, cx + 9):
        c.blob(nx, 40, 4, 3, 'grey', lift=-.1, inner_line=False)
        c.rect(nx - 2, 41, 5, 2, 'black', 3, False)
        if frame == 2: c.rect(nx - 2, 42, 5, 1, 'orange', 4, False)
    # casco
    c.blob(cx, 28, 25, 12, 'white', lift=.05, inner_line=False)
    c.blob(cx, 22, 18, 11, 'white', lift=.2, inner_line=False)
    for x in range(W):
        for y in (30, 31):
            if c.solid[y, x]: c.px(x, y, 'orange', 3 if y == 30 else 2)
    for x in range(cx - 20, cx + 21, 4):
        if c.solid[34, x]: c.px(x, 34, 'grey', 2)
    # cabina
    c.blob(cx - 2, 16, 9, 5, 'glass', lift=.25, inner_line=False)
    c.px(cx - 6, 14, 'glass', 5); c.px(cx - 5, 13, 'glass', 5)
    # antena y luces
    c.line(cx + 10, 11, cx + 13, 4, 'steel', 3); c.px(cx + 13, 3, 'red', 4)
    for k, x in enumerate(range(cx - 18, cx + 19, 9)):
        lamp(c, x, 27, (k + frame) % 2 == 0)
    # escotilla / rampa
    if frame == 1:
        c.rect(cx - 4, 33, 9, 6, 'black', 2, False)
        for y in range(39, 47):
            w = 4 + (y - 39) // 3
            for x in range(cx - w, cx + w + 1): c.px(x, y, 'steel', 3 if (y % 2) else 4)
    else:
        c.rect(cx - 4, 33, 9, 6, 'steel', 3)
        c.line(cx - 4, 33, cx + 4, 33, 'steel', 1)
    c.outline()
    return c
save_sprite('lander', [lander(f) for f in range(3)], ox=32, oy=50)

def flame(frame):
    c = Cv(8, 18)
    L = [12, 16, 10, 14][frame]
    for y in range(L):
        w = 3.2 * (1 - y / L) ** .6
        for x in range(8):
            dx = abs(x + .5 - 4)
            if dx <= w:
                i = 4 if dx < w * .45 else (3 if y < L * .6 else 2)
                c.px(x, y, 'lava' if y > 2 else 'yellow', i + (1 if y < 3 else 0))
    return c
save_sprite('flame', [flame(f) for f in range(4)], ox=4, oy=0)

def worker(frame):
    """Colono: 0-1 caminar, 2 quieto, 3-4 martillar."""
    c = Cv(9, 13)
    c.shadow(4.5, 12, 3, 1, 70)
    lx = [(3, 5), (4, 4), (3, 5), (3, 5), (3, 5)][frame]
    ly = [(11, 10), (11, 11), (11, 11), (11, 11), (11, 11)][frame]
    c.px(lx[0], ly[0], 'steel', 1); c.px(lx[0], ly[0] - 1, 'orange', 2)
    c.px(lx[1], ly[1], 'steel', 1); c.px(lx[1], ly[1] - 1, 'orange', 2)
    c.rect(3, 6, 3, 4, 'orange', 3)
    c.px(4, 7, 'white', 4)
    c.rect(3, 3, 3, 3, 'cream', 4, False)
    c.rect(3, 2, 3, 2, 'white', 5, False); c.px(2, 3, 'white', 4); c.px(6, 3, 'white', 4)
    c.px(5, 4, 'black', 1)
    if frame in (3, 4):
        if frame == 3:
            c.line(6, 6, 7, 3, 'wood', 3); c.px(7, 2, 'steel', 4); c.px(8, 2, 'steel', 3)
        else:
            c.line(6, 7, 8, 8, 'wood', 3); c.px(8, 9, 'steel', 4); c.px(8, 8, 'steel', 3)
    else:
        c.px(2, 7, 'orange', 2); c.px(6, 7 + (frame % 2), 'orange', 2)
    c.outline()
    return c
save_sprite('worker', [worker(f) for f in range(5)], ox=4, oy=12)

def part(frame):
    c = Cv(6, 5)
    if frame == 0: c.rect(0, 1, 6, 3, 'white', 4); c.px(1, 2, 'orange', 3)
    elif frame == 1: c.rect(1, 0, 3, 5, 'steel', 4); c.px(2, 2, 'glass', 4)
    else: c.rect(0, 1, 5, 3, 'grey', 3); c.px(4, 1, 'orange', 4)
    c.outline()
    return c
save_sprite('part', [part(f) for f in range(3)], ox=3, oy=2)

json.dump(INDEX, open(f'{OUT}/index.json', 'w'), indent=1)
print('ok', len(INDEX['sprites']), 'sprites; atlas', atlas.size)
