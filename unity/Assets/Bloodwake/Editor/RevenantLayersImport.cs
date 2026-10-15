using System;
using System.Collections.Generic;
using System.Linq;
using UnityEditor;
using UnityEditor.Animations;
using UnityEngine;

namespace Bloodwake.Editor
{
 public static class RevenantLayersImport
 {
  const string Root="Assets/Bloodwake/Resources/";
  public static void Build()
  {
   var controller=AssetDatabase.LoadAssetAtPath<AnimatorController>(Root+"Controllers/revenant_player.controller");
   var clips=controller.animationClips.Distinct().ToArray();
   var paths=new HashSet<string>{""};
   foreach(var clip in clips)foreach(var binding in AnimationUtility.GetCurveBindings(clip))
   {
    string path=binding.path;paths.Add(path);
    while(path.Contains('/')){path=path.Substring(0,path.LastIndexOf('/'));paths.Add(path);}
   }
   string[] lower={"pelvis","thigh_l","calf_l","foot_l","ball_l","thigh_r","calf_r","foot_r","ball_r"};
   string[] upper={"spine_","neck_","head","clavicle_","upperarm_","lowerarm_","hand_","blood_claw","armor_","thumb_","index_","middle_","ring_","pinky_","hair_"};
   var legs=Mask("Revenant legs",paths,n=>lower.Contains(n)||n.StartsWith("coat_"));
   var hit=Mask("Revenant hit",paths,n=>upper.Any(p=>n.StartsWith(p,StringComparison.Ordinal)));
   Layer(controller,"Moving attack legs",legs,AnimatorLayerBlendingMode.Override,clips.Where(c=>c.name=="REV_AssassinRun"),"RevenantLegSpeed");
   Layer(controller,"Upper body hit",hit,AnimatorLayerBlendingMode.Additive,clips.Where(c=>c.name.EndsWith("_Additive",StringComparison.Ordinal)),"RevenantHitSpeed");
   EditorUtility.SetDirty(controller);AssetDatabase.SaveAssets();
  }
  static AvatarMask Mask(string name,HashSet<string> paths,Func<string,bool> active)
  {
   var path=Root+"Controllers/"+name.Replace(' ','_')+".mask";var mask=AssetDatabase.LoadAssetAtPath<AvatarMask>(path);
   if(!mask){mask=new AvatarMask{name=name};AssetDatabase.CreateAsset(mask,path);}
   var ordered=paths.OrderBy(p=>p).ToArray();mask.transformCount=ordered.Length;
   for(int i=0;i<ordered.Length;i++){mask.SetTransformPath(i,ordered[i]);mask.SetTransformActive(i,active(ordered[i].Split('/').Last()));}
   EditorUtility.SetDirty(mask);return mask;
  }
  static void Layer(AnimatorController c,string name,AvatarMask mask,AnimatorLayerBlendingMode mode,IEnumerable<AnimationClip> clips,string speed)
  {
   if(!c.parameters.Any(p=>p.name==speed))c.AddParameter(speed,AnimatorControllerParameterType.Float);
   if(!c.layers.Any(l=>l.name==name))c.AddLayer(name);
   var layers=c.layers;var layer=layers.First(l=>l.name==name);layer.avatarMask=mask;layer.blendingMode=mode;layer.defaultWeight=0;
   foreach(var clip in clips){var state=layer.stateMachine.states.FirstOrDefault(s=>s.state.name==clip.name).state;if(!state)state=layer.stateMachine.AddState(clip.name);state.motion=clip;state.speedParameter=speed;state.speedParameterActive=true;}
   c.layers=layers;
  }
 }
}
