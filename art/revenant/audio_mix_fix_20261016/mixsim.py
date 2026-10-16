# Offline re-creation of BloodwakeGame.SoundFrom summing (2D AudioSources, linear sum, master .8).
import wave,sys,numpy as np,matplotlib;matplotlib.use('Agg');import matplotlib.pyplot as plt
A='unity/Assets/Bloodwake/Resources/audio/';S=sys.argv[1];OUT=sys.argv[2]
SR=48000
def load(p):
    w=wave.open(p);n=w.getnframes();ch=w.getnchannels();sr=w.getframerate();x=np.frombuffer(w.readframes(n),'<i2').astype(np.float64)/32768;x=x.reshape(-1,ch)
    if ch==1:x=np.repeat(x,2,1)
    if sr!=SR:t=np.arange(int(len(x)*SR/sr))*sr/SR;x=np.stack([np.interp(t,np.arange(len(x)),x[:,c]) for c in range(2)],1)
    return x
def db(v):return 10**(v/20)
def render(events,dur):
    out=np.zeros((int(dur*SR),2))
    for t,clip,gain,skip in events:
        x=clip[int(skip*SR):];i=int(t*SR);n=min(len(x),len(out)-i);out[i:i+n]+=x[:n]*gain
    return out*.8  # AudioListener.volume default .8
def duck_env(dur,t0,sec,depth):
    # mirrors TickSoundMix: attack 40/s, release 5.5/s, at 60 fps
    n=int(dur*SR);g=np.ones(n);cur=1;fps=60
    for f in range(int(dur*fps)+1):
        now=f/fps;target=depth if t0<=now<t0+sec else 1
        cur=max(target,cur-40/fps) if target<cur else min(target,cur+5.5/fps)
        g[int(now*SR):int((now+1/fps)*SR)]=cur
    return g[:,None]
qo,qn=load(S+'/q_orig.wav'),load(A+'revenant_q_mist_claw.wav')
so,sn=load(S+'/space_orig.wav'),load(A+'revenant_space_blood_burst.wav')
hit=load(A+'polished/sword_hit_flesh_2.wav');death=load(A+'enemy_death_1.wav');wood=load(A+'wood_break.wav');swing=load(A+'polished/revenant_basic_attack_c.wav')
QD=25/60;SKIP=.185;SD=.6583
cases={}
# Q in the sanctuary training room: one hit dummy + a breakable prop on the path
cases['Q_before']=render([(0,qo,1,0),(QD,hit,db(-4),0),(QD,wood,db(-5),0)],1.4)
d=duck_env(1.4,0,.75,db(-9))
cases['Q_after']=render([(0,qn,1,0)],1.4)+render([(QD,wood,db(-5),0)],1.4)*d
# Space killing two enemies (enemy_death gap .04 -> one death sound) + hit
cases['Space_before']=render([(0,so,1,SKIP),(SD,hit,db(-4),0),(SD,death,db(-5),0)],2.3)
d=duck_env(2.3,0,1.25,db(-9))
cases['Space_after']=render([(0,sn,1,SKIP)],2.3)+render([(SD,death,db(-5),0)],2.3)*d
# reference: one basic claw swing as heard in game (.72 gain)
cases['basic_swing_ref']=render([(0,swing,.72,0)],.7)
for k,v in cases.items():
    o=wave.open(f'{OUT}/{k}.wav','wb');o.setnchannels(2);o.setsampwidth(2);o.setframerate(SR);o.writeframes((np.clip(v,-1,1)*32767).astype('<i2').tobytes());o.close()
def rms(x,a,b):seg=x[int(a*SR):int(b*SR)];return 20*np.log10(np.sqrt((seg**2).mean())+1e-9)
print('peak/RMS dBFS (listener .8):')
for k,v in cases.items():print(f' {k:16s} peak {20*np.log10(np.abs(v).max()):6.2f}  body RMS {rms(v,0,1.0 if "Q" in k else 1.4):6.2f}')
# signature vs others around damage
def ratio(sig,others,t):
    a=rms(sig,t-.03,t+.12);b=rms(others,t-.03,t+.12);return a-b
qb_sig=render([(0,qo,1,0)],1.4);qb_oth=render([(QD,hit,db(-4),0),(QD,wood,db(-5),0)],1.4)
qa_sig=render([(0,qn,1,0)],1.4);qa_oth=render([(QD,wood,db(-5),0)],1.4)*duck_env(1.4,0,.75,db(-9))
sb_sig=render([(0,so,1,SKIP)],2.3);sb_oth=render([(SD,hit,db(-4),0),(SD,death,db(-5),0)],2.3)
sa_sig=render([(0,sn,1,SKIP)],2.3);sa_oth=render([(SD,death,db(-5),0)],2.3)*duck_env(2.3,0,1.25,db(-9))
print(f'Q claw vs layered SFX at DAMAGE: before {ratio(qb_sig,qb_oth,QD):+.1f} dB  after {ratio(qa_sig,qa_oth,QD):+.1f} dB')
print(f'Space burst vs layered SFX at ULT_DAMAGE: before {ratio(sb_sig,sb_oth,SD):+.1f} dB  after {ratio(sa_sig,sa_oth,SD):+.1f} dB')
fig,ax=plt.subplots(4,1,figsize=(12,10))
for i,(k,mark) in enumerate((('Q_before',QD),('Q_after',QD),('Space_before',SD),('Space_after',SD))):
    v=cases[k].mean(1);t=np.arange(len(v))/SR;ax[i].plot(t,v,lw=.4,color='#a33');ax[i].axvline(mark,color='k',ls='--',lw=.8);ax[i].set_ylim(-1,1);ax[i].set_title(k+'  (dashed = damage marker)');ax[i].set_xlim(0,t[-1])
    sig={'Q_before':qb_sig,'Q_after':qa_sig,'Space_before':sb_sig,'Space_after':sa_sig}[k].mean(1)
    ax[i].plot(t,sig,lw=.4,color='#348',alpha=.6)
fig.legend(['full mix','damage','signature cast only'],loc='upper right');fig.tight_layout();fig.savefig(f'{OUT}/mix_before_after.png',dpi=90)
