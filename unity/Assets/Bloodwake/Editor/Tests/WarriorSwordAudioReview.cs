using System;
using System.Collections;
using System.IO;
using System.Linq;
using System.Reflection;
using UnityEditor;
using UnityEngine;
namespace Bloodwake.Editor
{
 public static class WarriorSwordAudioReview
 {
  const string Request="Library/WarriorSwordAudioReview.request",Clip="warrior_sword_clash_user";
  const BindingFlags Flags=BindingFlags.Instance|BindingFlags.NonPublic;
  static void Check(bool ok,string message){if(!ok)throw new Exception("WARRIOR_SWORD_AUDIO: "+message);}
  [InitializeOnLoadMethod]static void Init(){EditorApplication.update+=Poll;}
  static void Poll()
  {
   if(!File.Exists(Request)||EditorApplication.isCompiling||EditorApplication.isUpdating||!EditorApplication.isPlaying)return;
   var game=UnityEngine.Object.FindFirstObjectByType<BloodwakeGame>();if(!game||game.Screen!="playing"||game.Enemies.Count!=1)return;
   File.Delete(Request);var enemy=game.Enemies[0];string kind=game.Run.ClassId;
   bool enabled=game.enabled,animatorEnabled=enemy.View.Animator.enabled;int pattern=enemy.Pattern;
   var rotation=enemy.View.transform.rotation;
   object Call(string method,params object[] args)=>typeof(BloodwakeGame).GetMethod(method,Flags).Invoke(game,args);
   void StopClip(){foreach(var s in game.GetComponents<AudioSource>())if(s.clip&&s.clip.name==Clip)s.Stop();}
   int Count()=>game.GetComponents<AudioSource>().Count(s=>s.isPlaying&&s.clip&&s.clip.name==Clip);
   try
   {
    game.enabled=false;enemy.View.Animator.enabled=false;
    var asset=Resources.Load<AudioClip>("audio/"+Clip);Check(asset&&Mathf.Abs(asset.length-1.170068f)<.005f,"Original recording not imported");
    StopClip();game.Run.ClassId="warrior";
    var contact=(IEnumerator)Call("MeleeContact",Vector3.forward,0f,0f,.1f,false,0,0f,false);
    Check(contact.MoveNext()&&Count()==0,"Player sound fired before contact delay");
    contact.MoveNext();Check(Count()==1,"Player contact did not play chosen recording exactly once");
    game.Run.ClassId=kind;StopClip();
    foreach(int index in new[]{0,1})
    {
     enemy.Pattern=index;enemy.View.Play("Idle",0);enemy.View.Animator.Update(.2f);
     Call("WarriorMelee",enemy,Vector3.back);Check(Count()==0,"Enemy sound fired in wind-up");
     float contactTime=index==0?.15f:.4f;
     for(int tick=0;tick<Mathf.CeilToInt((contactTime+.08f)*120);tick++)enemy.View.Animator.Update(1f/120);
     Check(Count()==1,"Enemy contact did not play recording for slash "+index);StopClip();
    }
    enemy.View.Play("Idle",0);enemy.View.Animator.Update(.2f);Call("WarriorMelee",enemy,Vector3.back);
    enemy.View.Play("Hit",.5f);enemy.View.Animator.Update(.6f);Check(Count()==0,"Interrupted slash played audio");
    Debug.Log("WARRIOR_SWORD_AUDIO_PASSED source=1.170s PCM player-contact enemy-outward enemy-inward interruption");
   }
   catch(Exception e){Debug.LogException(e);}
   finally
   {
    StopClip();game.Run.ClassId=kind;enemy.Pattern=pattern;enemy.Turning=false;enemy.View.Play("Idle",0);enemy.View.transform.rotation=rotation;enemy.Cooldown=.9f;
    enemy.View.Animator.enabled=animatorEnabled;game.enabled=enabled;
   }
  }
 }
}
