# Reemplaza en su lugar los iconos del ejecutable de Godot (mismo tamaño de bytes).
import sys, io, struct, lief
from PIL import Image
exe, png = sys.argv[1], sys.argv[2]
src = Image.open(png).convert('RGBA')
data = bytearray(open(exe, 'rb').read())
pe = lief.PE.parse(exe)
rm = pe.resources_manager
for i in range(len(rm.icons)):
    ic = rm.icons[i]
    old = bytes(ic.pixels)
    pos = data.find(old)
    assert pos >= 0 and data.find(old, pos + 1) < 0, 'icono no único'
    if old[:4] == b'\x89PNG':
        for colors in (None, 256, 128, 64):
            im = src.resize((256, 256), Image.LANCZOS)
            if colors: im = im.quantize(colors, method=Image.FASTOCTREE).convert('RGBA') if False else im.convert('P', palette=Image.ADAPTIVE, colors=colors)
            b = io.BytesIO(); im.save(b, 'PNG', optimize=True); new = b.getvalue()
            if len(new) <= len(old): break
        assert len(new) <= len(old), len(new)
        new = new + b'\x00' * (len(old) - len(new))
    else:
        w = struct.unpack('<i', old[4:8])[0]
        im = src.resize((w, w), Image.LANCZOS)
        px = im.tobytes()
        rows = []
        for y in range(w - 1, -1, -1):
            row = px[y * w * 4:(y + 1) * w * 4]
            rows.append(bytes(b for k in range(w) for b in (row[k*4+2], row[k*4+1], row[k*4], row[k*4+3])))
        mask_row = ((w + 31) // 32) * 4
        new = old[:40] + b''.join(rows) + b'\x00' * (mask_row * w)
        assert len(new) == len(old), (len(new), len(old))
    data[pos:pos + len(old)] = new
    print('icono', i, 'ok', len(old))
open(exe, 'wb').write(data)
