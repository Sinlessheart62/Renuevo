# Efectos y música estilo 8 bits (onda cuadrada, triangular y ruido).
import numpy as np, wave, os, sys
SR=44100; out=sys.argv[1]
def save(name,x,stereo=False):
    x=np.clip(x,-1,1)
    if stereo: x=np.stack([x,x],1)
    w=wave.open(os.path.join(out,name+'.wav'),'wb');w.setnchannels(2 if stereo else 1);w.setsampwidth(2);w.setframerate(SR);w.writeframes((x*30000).astype(np.int16).tobytes());w.close()
def t(d): return np.arange(int(SR*d))/SR
def sq(f,d,duty=.5): tt=t(d); return np.where((tt*f)%1<duty,1.0,-1.0)
def tri(f,d): tt=t(d); return 2*np.abs(2*((tt*f)%1)-1)-1
def nz(d): 
    n=int(SR*d); step=max(1,int(SR/8000)); return np.repeat(np.random.choice([-1.0,1.0],n//step+1),step)[:n]
def env(x,r=.15,a=.003):
    n=len(x);tt=np.arange(n)/SR;e=np.exp(-tt/r);na=int(a*SR);e[:na]*=np.linspace(0,1,na);return x*e
def seq(notes,dur,fn=lambda f,d: sq(f,d,.25),r=.08,vol=.25):
    return np.concatenate([env(fn(f,dur),r)*vol if f>0 else np.zeros(int(SR*dur)) for f in notes])
def mix(*xs):
    n=max(len(x) for x in xs);o=np.zeros(n)
    for x in xs:o[:len(x)]+=x
    return o
np.random.seed(5)
save('sel',seq([1568],.05,r=.03,vol=.18))
save('err',seq([196,147],.09,fn=lambda f,d: sq(f,d,.5),r=.1,vol=.22))
save('place',mix(env(nz(.12),.04)*.3,seq([523,784],.06,r=.05,vol=.2)))
save('rec',seq([1047,784,523],.06,r=.05,vol=.2))
save('seed',seq([880,1175],.05,r=.04,vol=.16))
tt=t(.35);save('water',env(np.where(((tt*(300+1200*tt))%1)<.5,1.,-1.),.12)*.18)
save('clean',env(nz(.4),.15)*.18+seq([392,523,659],.07,r=.06,vol=.1)[:int(SR*.4)].copy() if False else env(nz(.35),.12)*.16)
for k,f in enumerate([1319,1568,1760,2093]): save('grow%d'%k,seq([f],.08,r=.05,vol=.1))
save('melt',seq([1760,1568,1319],.05,r=.04,vol=.12))
save('found',seq([523,659,784,1047,0,1047],.09,r=.12,vol=.2))
save('scan',seq([880,1319,1760],.06,fn=lambda f,d: tri(f,d),r=.08,vol=.3))
save('phase',seq([392,523,659,784,0,659,784,1047],.11,r=.2,vol=.2))
save('ship',env(mix(tri(98,2.2)*.4,nz(2.2)*.1),1.2))
save('win',seq([523,659,784,1047,784,1047,1319,0,1319,1568],.14,r=.3,vol=.2))
# música chiptune en bucle (pulso + triangular + ruido), 16 compases a 112 bpm
bpm=112; b=60/bpm/2
prog=[(262,330,392),(220,262,330),(175,220,262),(196,247,294)]
mel=[659,0,784,659,587,0,523,587, 523,0,659,523,440,0,392,440, 440,523,587,0,523,440,392,0, 392,494,587,0,659,587,494,392]
lead=[];bass=[];arp=[];perc=[]
for bar in range(16):
    ch=prog[bar%4]
    for s in range(8):
        i=(bar*8+s)%len(mel); f=mel[i] if bar%8<6 else (mel[i]*2 if mel[i] else 0)
        lead.append(env(sq(f,b,.25),.18)*.10 if f else np.zeros(int(SR*b)))
        bass.append(env(tri(ch[0]/2 if s%2==0 else ch[0],b),.3)*.22)
        arp.append(env(sq(ch[s%3]*2,b,.125),.05)*.035)
        perc.append(env(nz(b),.02 if s%2 else .05)*(.05 if s%2 else .08))
music=np.concatenate(lead)+np.concatenate(bass)+np.concatenate(arp)+np.concatenate(perc)
save('music',music*.9,True)
print('ok')
