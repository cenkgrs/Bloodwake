using UnityEngine;
namespace Bloodwake
{
 // audio.gd's two-voice crossfade survives EnterRoom cancelling combat routines.
 public sealed class MusicBlend:MonoBehaviour
 {
  public BloodwakeGame Game;
  readonly AudioSource[] voices=new AudioSource[2];
  readonly float[] startDb=new float[2],endDb=new float[2];
  string track="";int active;float age=1.2f,duck,duckStart,duckTarget,duckAge=1;
  void Awake(){for(int i=0;i<2;i++){voices[i]=gameObject.AddComponent<AudioSource>();voices[i].loop=true;voices[i].playOnAwake=false;voices[i].volume=0;startDb[i]=endDb[i]=-60;}}
  public void Set(string id,AudioClip clip)
  {
   if(id==track)return;track=id;
   for(int i=0;i<2;i++)startDb[i]=Mathf.Lerp(startDb[i],endDb[i],Mathf.Clamp01(age/1.2f));
   if(clip){active=1-active;voices[active].Stop();voices[active].clip=clip;startDb[active]=-60;voices[active].volume=0;voices[active].Play();}
   for(int i=0;i<2;i++)endDb[i]=clip&&i==active?(id=="music_combat"?-15:-13):-60;
   age=0;
  }
  void Update()
  {
   if(!Game)return;float desired=Game.Screen=="playing"||Game.Screen=="loading"||Game.Screen=="menu"||Game.Screen=="classes"?0:Game.Screen=="pause"||Game.Screen=="upgrade"?-9:-7;
   if(desired!=duckTarget){duckStart=duck;duckTarget=desired;duckAge=0;}
   float dt=Time.unscaledDeltaTime;age+=dt;duckAge+=dt;duck=Mathf.Lerp(duckStart,duckTarget,Mathf.Clamp01(duckAge/.35f));
   for(int i=0;i<2;i++){float db=Mathf.Lerp(startDb[i],endDb[i],Mathf.Clamp01(age/1.2f))+duck;voices[i].volume=Mathf.Pow(10,db/20);if(age>=1.2f&&endDb[i]<=-60&&voices[i].isPlaying){voices[i].Stop();voices[i].clip=null;}}
  }
 }
}
