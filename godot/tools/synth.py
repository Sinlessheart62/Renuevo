import numpy as np, wave, os, sys
SR=44100
out=sys.argv[1]
def save(name,x,stereo=False):
    x=np.clip(x,-1,1)
    if stereo and x.ndim==1: x=np.stack([x,x],1)
    d=(x*32000).astype(np.int16)
    w=wave.open(os.path.join(out,name+'.wav'),'wb');w.setnchannels(2 if stereo else 1);w.setsampwidth(2);w.setframerate(SR);w.writeframes(d.tobytes());w.close()
def t(d): return np.arange(int(SR*d))/SR
def env(x,a=.005,r=.2):
    n=len(x);e=np.ones(n);na=max(1,int(a*SR));e[:na]=np.linspace(0,1,na);tt=np.arange(n)/SR;e*=np.exp(-tt/r);return x*e
def tone(f,d,a=.005,r=.2,h=(1,.3,.1)):
    tt=t(d);x=sum(w*np.sin(2*np.pi*f*(k+1)*tt) for k,w in enumerate(h));return env(x,a,r)
def noise(d): return np.random.randn(int(SR*d))
def lp(x,a):
    y=np.zeros_like(x);s=0
    for i in range(len(x)): s+=a*(x[i]-s);y[i]=s
    return y
def lpf(x,a):  # fast one-pole via scipy-free cumulative trick
    from numpy import zeros
    y=np.empty_like(x);s=0.0
    for i,v in enumerate(x): s+=a*(v-s);y[i]=s
    return y
def mix(*xs):
    n=max(len(x) for x in xs);o=np.zeros(n)
    for x in xs:o[:len(x)]+=x
    return o
def delay(x,dt,n):
    o=np.zeros(len(x)+int(dt*SR*n));
    for k in range(n): o[int(dt*SR*k):int(dt*SR*k)+len(x)]+=x*(0.45**k)
    return o
np.random.seed(3)
# interfaz y acciones
save('sel',tone(880,.12,.002,.05,(1,.2))*.35)
save('err',mix(tone(220,.18,.002,.08,(1,.5,.3)),tone(207,.18,.002,.08,(1,.5,.3)))*.3)
thud=env(lpf(noise(.35),.05),.002,.08)*1.2
save('place',mix(thud,tone(330,.3,.002,.12,(1,.4,.2))*.25,np.concatenate([np.zeros(int(.06*SR)),tone(495,.25,.002,.1)*.15])))
save('rec',mix(*[np.concatenate([np.zeros(int(i*.07*SR)),tone(f,.3,.002,.12)*.25]) for i,f in enumerate([784,659,523])]))
save('seed',mix(env(lpf(noise(.2),.2),.002,.04)*.4,tone(660,.25,.002,.1,(1,.2))*.2))
w=t(.6);save('water',env(np.sin(2*np.pi*(300+900*w)*w)*.25+lpf(noise(.6),.08)*.4,.01,.15)*.6)
save('clean',env(lpf(noise(.5),.3)*np.sin(np.pi*t(.5)/.5),.02,.3)*.35)
for k,f in enumerate([1047,1175,1319,1568]):
    save('grow%d'%k,tone(f,.35,.001,.12,(1,.15,.05))*.13)
save('melt',env(lpf(noise(.5),.15),.05,.2)*.3+tone(1568,.5,.01,.2,(1,))*.05)
save('found',mix(*[np.concatenate([np.zeros(int(i*.11*SR)),tone(f,.6,.003,.25)*.22]) for i,f in enumerate([523,659,784,1047])]))
save('scan',mix(np.sin(2*np.pi*(600+1400*t(.5))*t(.5))*np.exp(-t(.5)*4)*.15,tone(1319,.4,.003,.15)*.15))
save('phase',delay(mix(*[np.concatenate([np.zeros(int(i*.16*SR)),tone(f,1.4,.01,.6,(1,.35,.12))*.2]) for i,f in enumerate([392,523,659,784])]),.22,3))
save('ship',env(mix(tone(98,2.5,.6,1.5,(1,.6,.4,.2))*.4,lpf(noise(2.5),.03)*.4),.6,1.4))
save('win',delay(mix(*[np.concatenate([np.zeros(int(i*.2*SR)),tone(f,2.2,.01,.9,(1,.35,.12))*.2]) for i,f in enumerate([523,659,784,1047,1319])]),.25,3))
# ambientes en bucle (estéreo, 8 s)
D=8.0;n=int(D*SR)
def loopify(x,f=.5):
    k=int(f*SR);x=x.copy();x[:k]=x[:k]*np.linspace(0,1,k)+x[-k:]*np.linspace(1,0,k);return x[:-k]
wnd=lpf(noise(D+.5),.02);wnd*=0.6+0.4*np.sin(2*np.pi*t(D+.5)/4.0)
save('amb_wind',np.stack([loopify(wnd)*.7,loopify(np.roll(wnd,9000))*.7],1),True)
rn=lpf(noise(D+.5),.5)*.5+lpf(noise(D+.5),.08)*.6
save('amb_rain',np.stack([loopify(rn)*.6,loopify(np.roll(rn,13000))*.6],1),True)
sea=lpf(noise(D+.5),.04)*(0.5+0.5*np.sin(2*np.pi*t(D+.5)/(D+.5)*2)**2)*1.4
save('amb_sea',np.stack([loopify(sea)*.6,loopify(np.roll(sea,20000))*.6],1),True)
# pájaros
b=np.zeros(int((D+.5)*SR))
for k in range(14):
    st=np.random.uniform(0,D);f0=np.random.uniform(2200,4200)
    for j in range(np.random.randint(2,6)):
        d=np.random.uniform(.05,.12);tt=t(d);ch=np.sin(2*np.pi*(f0+np.random.uniform(-600,900)*tt/d)*tt)*np.sin(np.pi*tt/d)**2
        s=int((st+j*np.random.uniform(.1,.18))*SR)
        if s+len(ch)<len(b): b[s:s+len(ch)]+=ch*np.random.uniform(.08,.18)
L=loopify(b);Rr=loopify(np.roll(b,7000))
save('amb_birds',np.stack([L*.9+Rr*.2,Rr*.9+L*.2],1),True)
# grillos de noche
c=np.zeros(int((D+.5)*SR));tt=np.arange(len(c))/SR
for f,ph in [(4300,0),(4700,.3),(5100,.7)]:
    gate=(np.sin(2*np.pi*14*tt+ph)>0.6)*(np.sin(2*np.pi*.7*tt+ph*3)>-.2)
    c+=np.sin(2*np.pi*f*tt)*gate*.05
save('amb_night',np.stack([loopify(c),loopify(np.roll(c,5000))],1),True)
# lava burbujeante
lv=lpf(noise(D+.5),.01)*1.5
for k in range(30):
    s=int(np.random.uniform(0,D)*SR);bb=tone(np.random.uniform(60,140),.15,.005,.05,(1,.5))*.3
    lv[s:s+len(bb)]+=bb
save('amb_lava',np.stack([loopify(lv)*.6,loopify(np.roll(lv,4000))*.6],1),True)
# música: pad suave con acordes (32 s)
MD=32.0;tt=t(MD+1);mus=np.zeros(len(tt))
chords=[[261.6,329.6,392.0,493.9],[220.0,261.6,329.6,392.0],[174.6,220.0,261.6,329.6],[196.0,246.9,293.7,392.0]]
for ci,ch in enumerate(chords*2):
    s=ci*4.0
    for f in ch:
        seg=(tt>=s)&(tt<s+5.5);x=tt[seg]-s
        e=np.minimum(1,x/1.5)*np.exp(-np.maximum(0,x-3.5)/0.8)
        mus[seg]+=(np.sin(2*np.pi*f*x)+.25*np.sin(2*np.pi*f*2.003*x)+.12*np.sin(2*np.pi*f*.5*x))*e*.045
# notas de piano tenues
mel=[784,659,587,523,659,587,523,440,523,587,659,784,880,784,659,587]
for k,f in enumerate(mel):
    s=int((k*2.0+.5)*SR);nn=tone(f,2.0,.003,.6,(1,.25,.1,.05))*.07
    if s+len(nn)<len(mus): mus[s:s+len(nn)]+=nn
mus=delay(mus,.31,4)[:len(mus)]
m2=loopify(mus,1.0)
save('music',np.stack([m2,np.roll(m2,800)],1),True)
print('ok')
