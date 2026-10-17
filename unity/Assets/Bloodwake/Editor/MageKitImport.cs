using System;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.Animations;
using UnityEngine;
namespace Bloodwake.Editor
{
 // The Mage's moveset borrows the enemy mage's one-hand bolt and two-hand ground cast. Both rigs are
 // Mixamo, so the clips are copied across by bone name: rotations as authored, the hips' travel scaled
 // to the player's leg length, and no other bone translation (it would stretch the limbs).
 public static class MageKitImport
 {
  const string Root="Assets/Bloodwake/Resources/",Folder=Root+"Animations/MageKit/";
  static readonly (string source,string name)[] Clips={("Attack","Mage_Backhand"),("Cast","Mage_GroundCast")};
  [MenuItem("Bloodwake/Import Mage Kit Clips")]
  public static void Build()
  {
   Directory.CreateDirectory(Folder);
   var sourcePath=Root+"Models/enemy_mage/enemy_mage.fbx";var targetPath=Root+"Models/mage_player/mage_player.fbx";
   var source=AssetDatabase.LoadAssetAtPath<GameObject>(sourcePath);var target=AssetDatabase.LoadAssetAtPath<GameObject>(targetPath);
   if(!source||!target)throw new Exception("Mage kit: missing source or target model");
   static string Short(string name)=>name.Contains(':')?name.Substring(name.LastIndexOf(':')+1):name;
   var targetBones=target.GetComponentsInChildren<Transform>(true).GroupBy(t=>Short(t.name)).ToDictionary(g=>g.Key,g=>g.First());
   var sourceBones=source.GetComponentsInChildren<Transform>(true).GroupBy(t=>Short(t.name)).ToDictionary(g=>g.Key,g=>g.First());
   float ratio=targetBones.TryGetValue("Hips",out var th)&&sourceBones.TryGetValue("Hips",out var sh)&&Mathf.Abs(sh.localPosition.y)>.0001f?th.localPosition.y/sh.localPosition.y:1;
   var controller=AssetDatabase.LoadAssetAtPath<AnimatorController>(Root+"Controllers/mage_player.controller");if(!controller)throw new Exception("Mage kit: no mage_player controller");
   var machine=controller.layers[0].stateMachine;
   foreach(var (from,name) in Clips)
   {
    var imported=AssetDatabase.LoadAllAssetsAtPath(sourcePath).OfType<AnimationClip>().FirstOrDefault(c=>c.name==from);if(!imported)throw new Exception("Mage kit: source clip missing "+from);
    var output=Folder+name+".anim";var clip=AssetDatabase.LoadAssetAtPath<AnimationClip>(output);
    if(!clip){clip=new AnimationClip();AssetDatabase.CreateAsset(clip,output);}clip.ClearCurves();clip.frameRate=imported.frameRate;
    int copied=0,skipped=0;
    foreach(var binding in AnimationUtility.GetCurveBindings(imported))
    {
     if(binding.path==""){skipped++;continue;}
     string bone=Short(binding.path.Split('/').Last());if(!targetBones.TryGetValue(bone,out var t)){skipped++;continue;}
     bool position=binding.propertyName.StartsWith("m_LocalPosition");if(position&&bone!="Hips"){skipped++;continue;}
     var curve=AnimationUtility.GetEditorCurve(imported,binding);
     if(position){var keys=curve.keys;for(int i=0;i<keys.Length;i++){keys[i].value*=ratio;keys[i].inTangent*=ratio;keys[i].outTangent*=ratio;}curve.keys=keys;}
     var mapped=binding;mapped.path=AnimationUtility.CalculateTransformPath(t,target.transform);AnimationUtility.SetEditorCurve(clip,mapped,curve);copied++;
    }
    if(copied<20)throw new Exception($"Mage kit: only {copied} curves bound for {name}");
    var settings=AnimationUtility.GetAnimationClipSettings(clip);settings.loopTime=false;AnimationUtility.SetAnimationClipSettings(clip,settings);
    var state=machine.states.FirstOrDefault(s=>s.state.name==name).state??machine.AddState(name);state.motion=clip;
    EditorUtility.SetDirty(clip);Debug.Log($"MAGE_KIT_CLIP {name} length={imported.length:F3}s curves={copied} skipped={skipped} hipRatio={ratio:F3}");
    // Where the motion is: hand speed over the clip, so gameplay can play only the active part.
    var probe=UnityEngine.Object.Instantiate(target);
    try
    {
     var hands=probe.GetComponentsInChildren<Transform>().Where(b=>b.name.EndsWith("RightHand")||b.name.EndsWith("LeftHand")).ToArray();
     const int steps=60;var speeds=new float[steps];Vector3[] last=null;
     for(int i=0;i<steps;i++){clip.SampleAnimation(probe,clip.length*i/(steps-1));var now=hands.Select(h=>h.position).ToArray();if(last!=null)speeds[i]=now.Zip(last,(a,b)=>(a-b).magnitude).Max()/(clip.length/(steps-1));last=now;}
     float peak=speeds.Max();int at=Array.IndexOf(speeds,peak);
     int first=Array.FindIndex(speeds,s=>s>peak*.25f),end=Array.FindLastIndex(speeds,s=>s>peak*.25f);
     Debug.Log($"MAGE_KIT_MOTION {name} peak={clip.length*at/(steps-1):F2}s active={clip.length*first/(steps-1):F2}-{clip.length*end/(steps-1):F2}s speeds="+string.Join(",",speeds.Select(s=>s.ToString("F1"))));
    }
    finally{UnityEngine.Object.DestroyImmediate(probe);}
   }
   EditorUtility.SetDirty(controller);AssetDatabase.SaveAssets();Debug.Log("MAGE_KIT_IMPORT_COMPLETE");
  }
 }
}
