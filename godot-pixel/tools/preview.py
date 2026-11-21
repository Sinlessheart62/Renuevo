# Vista previa: compone un mapa de prueba con el atlas y los sprites (misma lógica que el juego)
import json, sys, random
from PIL import Image
D=sys.argv[1]; idx=json.load(open(D+'/index.json')); T=16
atlas=Image.open(D+'/tiles.png'); K=idx['tiles']['kinds']; DIRS=idx['tiles']['dirs']
PRI=['sea','tsea','oil','water','marsh','bed','lava','ash','tox','dirt','sand','ice','rock','mnt','grass','flower','forest']
def cell(kind,col): r=K.index(kind); return atlas.crop((col*T,r*T,col*T+T,r*T+T))
W,H=16,11
rnd=random.Random(3)
m=[['grass']*W for _ in range(H)]
for y in range(H):
  for x in range(W):
    if x>12: m[y][x]='sea' if x>13 else 'sand'
    elif x<3: m[y][x]='tox' if y<6 else 'ash'
    elif 3<=x<6 and y<5: m[y][x]='dirt'
    elif y==7 and 3<=x<12: m[y][x]='water'
    elif y==6 and 6<x<9: m[y][x]='marsh'
    elif 7<=x<10 and y<4: m[y][x]='forest'
    elif x in (10,11) and y in (1,2): m[y][x]='flower'
    elif x==6 and y==9: m[y][x]='rock'
img=Image.new('RGBA',(W*T,H*T),(0,0,0,255))
WAT={'water','sea','tsea','oil','marsh'}
for y in range(H):
  for x in range(W):
    k=m[y][x]; img.alpha_composite(cell(k,rnd.randrange(4)*4),(x*T,y*T))
    p=PRI.index(k)
    def at(xx,yy): return m[yy][xx] if 0<=xx<W and 0<=yy<H else None
    over={}
    for d,(dx,dy) in zip(['n','e','s','w'],[(0,-1),(1,0),(0,1),(-1,0)]):
      q=at(x+dx,y+dy)
      if q and PRI.index(q)>p: over.setdefault(q,[]).append(d)
    for d,(dx,dy),a,b in zip(['ne','se','sw','nw'],[(1,-1),(1,1),(-1,1),(-1,-1)],['n','s','s','n'],['e','e','w','w']):
      q=at(x+dx,y+dy)
      if q and PRI.index(q)>p and at(x+(0 if a in 'ns' else 0),y+(-1 if a=='n' else 1))!=q and at(x+(1 if b=='e' else -1),y)!=q: over.setdefault(q,[]).append(d)
    for q in sorted(over,key=PRI.index):
      for d in over[q]:
        col=16+(32 if k in WAT else 0)+DIRS.index(d)*4
        img.alpha_composite(cell(q,col),(x*T,y*T))
def spr(name,x,y,f=0):
  s=idx['sprites'][name]; im=Image.open(f"{D}/{name}.png").crop((f*s['w'],0,f*s['w']+s['w'],s['h']))
  img.alpha_composite(im,(int(x-s['ox']),int(y-s['oy'])))
objs=[('broad0',8*T+8,1*T+12),('pine1',9*T+4,3*T+10),('broad2',7*T+6,2*T+14),('fbush1',10*T+8,2*T+10),('bush0',4*T+8,8*T+12),
 ('b_tur',6*T+8,9*T+12,1),('b_asp',4*T+8,3*T+12,1),('b_dep',1*T+8,4*T+12),('a_deer',8*T,5*T+10),('a_heron',7*T+8,6*T+12),
 ('reed0',8*T+6,6*T+12),('a_rabbit',11*T,5*T+12,1),('a_duck',5*T,7*T+10),('rock1',2*T+8,9*T+12),('palm0',13*T+8,5*T+14),
 ('a_seal',15*T,3*T+10),('b_viv',11*T+8,9*T+14),('peaksnow0',1*T+8,1*T+14),('a_butterfly',10*T,1*T+4)]
for o in sorted(objs,key=lambda o:o[2]): spr(o[0],o[1],o[2],o[3] if len(o)>3 else 0)
img=img.resize((W*T*4,H*T*4),Image.NEAREST); img.save('/tmp/preview.png'); print(img.size)
