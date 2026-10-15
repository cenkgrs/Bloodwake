using System;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.Animations;
using UnityEngine;
namespace Bloodwake.Editor
{
 public static class WarriorAttackImport
 {
  const string Root="Assets/Bloodwake/Resources/",Folder=Root+"Animations/WarriorCombat/",Request="Library/WarriorAttackImport.request";
  [InitializeOnLoadMethod]static void Init(){EditorApplication.update+=Poll;}
  static void Poll()
  {
   if(EditorApplication.isCompiling||EditorApplication.isUpdating||!File.Exists(Request))return;
   if(EditorApplication.isPlayingOrWillChangePlaymode){EditorApplication.isPlaying=false;return;}
   string command=File.ReadAllText(Request).Trim();File.Delete(Request);
   try{if(command=="outward")UpdateOutward();else if(command=="inward-turn")UpdateInwardAndTurn();else Build();}catch(Exception e){Debug.LogException(e);}
  }
  [MenuItem("Bloodwake/Import Warrior Alternating Slashes")]
  public static void Build()
  {
   Import("Warrior_OutwardSlash",9/60f);
   Import("Warrior_InwardSlash",24/60f);
   if(File.Exists(Folder+"Warrior_Turn180.fbx"))Import("Warrior_Turn180",0);
   AssetDatabase.SaveAssets();
   Debug.Log("WARRIOR_ATTACK_IMPORT_COMPLETE Outward -> Inward; original speed; walk/model unchanged");
  }
  public static void UpdateOutward()
  {
   Import("Warrior_OutwardSlash",9/60f);AssetDatabase.SaveAssets();
   Debug.Log("WARRIOR_OUTWARD_V2_IMPORTED duration=0.6 contact=0.15; Inward and walk unchanged");
  }
  public static void UpdateInwardAndTurn()
  {
   Import("Warrior_InwardSlash",24/60f);Import("Warrior_Turn180",0);AssetDatabase.SaveAssets();
   Debug.Log("WARRIOR_INWARD_TURN_IMPORTED inward=0.7333/contact=0.4 turn=0.9; Outward and walk unchanged");
  }
  static void Import(string name,float contact)
  {
   string path=Folder+name+".fbx";
   AssetDatabase.ImportAsset(path,ImportAssetOptions.ForceSynchronousImport);
   var importer=(ModelImporter)AssetImporter.GetAtPath(path);
   importer.animationType=ModelImporterAnimationType.Generic;importer.importAnimation=true;
   importer.animationCompression=ModelImporterAnimationCompression.Off;
   var clips=importer.defaultClipAnimations;
   if(clips.Length!=1)throw new Exception("Expected one slash: "+name);
   clips[0].name=name;clips[0].loopTime=false;clips[0].loopPose=false;
   clips[0].lockRootPositionXZ=true;clips[0].lockRootRotation=true;
   importer.clipAnimations=clips;importer.SaveAndReimport();
   var imported=AssetDatabase.LoadAllAssetsAtPath(path).OfType<AnimationClip>().Single(c=>c.name==name);
   var model=AssetDatabase.LoadAssetAtPath<GameObject>(Root+"Models/enemy_warrior/enemy_warrior.fbx");
   string output=Folder+name+".anim";
   var clip=AssetDatabase.LoadAssetAtPath<AnimationClip>(output);
   if(!clip){clip=new AnimationClip();AssetDatabase.CreateAsset(clip,output);}
   EditorUtility.CopySerialized(imported,clip);clip.name=name;clip.ClearCurves();
   foreach(var binding in AnimationUtility.GetCurveBindings(imported))
   {
    if(binding.path=="")continue;
    var mapped=binding;
    if(!model.transform.Find(mapped.path))
    {
     var bone=model.GetComponentsInChildren<Transform>(true).SingleOrDefault(t=>t.name==binding.path.Split('/').Last());
     if(!bone)throw new Exception("Unmatched Warrior slash bone "+binding.path);
     mapped.path=AnimationUtility.CalculateTransformPath(bone,model.transform);
    }
    AnimationUtility.SetEditorCurve(clip,mapped,AnimationUtility.GetEditorCurve(imported,binding));
   }
   bool turn=name=="Warrior_Turn180";
   AnimationUtility.SetAnimationEvents(clip,turn?Array.Empty<AnimationEvent>():new[]{new AnimationEvent{time=contact,functionName="OnRevenantMarker",stringParameter="DAMAGE"}});
   if(turn)ExtractTurn(clip,model);
   var instance=UnityEngine.Object.Instantiate(model);
   try
   {
    var hand=instance.GetComponentsInChildren<Transform>().First(t=>t.name.EndsWith("RightHand"));
    var min=Vector3.positiveInfinity;var max=Vector3.negativeInfinity;
    for(int i=0;i<60;i++){clip.SampleAnimation(instance,clip.length*i/59);min=Vector3.Min(min,hand.position);max=Vector3.Max(max,hand.position);}
    float expectedLength=turn?.9f:name=="Warrior_OutwardSlash"?36/60f:44/60f;
    if((max-min).magnitude<(turn?.1f:.5f)||Mathf.Abs(clip.length-expectedLength)>.002f||(!turn&&(contact<=0||contact>=clip.length)))throw new Exception("Invalid motion "+name);
    Debug.Log($"WARRIOR_SLASH_BONE_VALIDATED {name} duration={clip.length:F4} contact={contact:F4} handTravel={(max-min).magnitude:F4}");
   }
   finally{UnityEngine.Object.DestroyImmediate(instance);}
   var controller=AssetDatabase.LoadAssetAtPath<AnimatorController>(Root+"Controllers/enemy_warrior.controller");
   var machine=controller.layers[0].stateMachine;
   var state=machine.states.FirstOrDefault(s=>s.state.name==name).state??machine.AddState(name);
   state.motion=clip;state.speed=1;state.speedParameterActive=false;
   EditorUtility.SetDirty(clip);EditorUtility.SetDirty(controller);
  }
  static void ExtractTurn(AnimationClip clip,GameObject model)
  {
   var instance=UnityEngine.Object.Instantiate(model);
   try
   {
    var bones=instance.GetComponentsInChildren<Transform>();
    var hip=bones.Single(t=>t.name.EndsWith("Hips"));
    var left=bones.Single(t=>t.name.EndsWith("LeftUpLeg"));var right=bones.Single(t=>t.name.EndsWith("RightUpLeg"));
    string path=AnimationUtility.CalculateTransformPath(hip,instance.transform);
    var data=new WarriorTurnData{duration=clip.length,yaw=new float[55],x=new float[55],z=new float[55]};
    var curves=Enumerable.Range(0,7).Select(_=>new AnimationCurve()).ToArray();
    Vector3 start=Vector3.zero,axis=Vector3.zero;float lastRaw=0,yaw=0;Quaternion previous=Quaternion.identity;
    for(int i=0;i<55;i++)
    {
     float time=clip.length*i/54;clip.SampleAnimation(instance,time);
     Vector3 currentAxis=Vector3.ProjectOnPlane(right.position-left.position,Vector3.up).normalized;
     if(i==0){start=hip.position;axis=currentAxis;}
     float raw=Vector3.SignedAngle(axis,currentAxis,Vector3.up);yaw+=Mathf.DeltaAngle(lastRaw,raw);lastRaw=raw;
     data.yaw[i]=yaw;data.x[i]=hip.position.x-start.x;data.z[i]=hip.position.z-start.z;
     hip.rotation=Quaternion.AngleAxis(-yaw,Vector3.up)*hip.rotation;
     hip.position=new Vector3(start.x,hip.position.y,start.z);
     var q=hip.localRotation;if(i>0&&Quaternion.Dot(q,previous)<0)q=new Quaternion(-q.x,-q.y,-q.z,-q.w);previous=q;
     float[] values={hip.localPosition.x,hip.localPosition.y,hip.localPosition.z,q.x,q.y,q.z,q.w};
     for(int c=0;c<7;c++)curves[c].AddKey(time,values[c]);
    }
    if(Mathf.Abs(Mathf.Abs(yaw)-180)>12)throw new Exception("Turn source is not approximately 180 degrees: "+yaw);
    string[] properties={"m_LocalPosition.x","m_LocalPosition.y","m_LocalPosition.z","m_LocalRotation.x","m_LocalRotation.y","m_LocalRotation.z","m_LocalRotation.w"};
    for(int c=0;c<7;c++)
    {
     for(int k=0;k<curves[c].length;k++){AnimationUtility.SetKeyLeftTangentMode(curves[c],k,AnimationUtility.TangentMode.Linear);AnimationUtility.SetKeyRightTangentMode(curves[c],k,AnimationUtility.TangentMode.Linear);}
     AnimationUtility.SetEditorCurve(clip,EditorCurveBinding.FloatCurve(path,typeof(Transform),properties[c]),curves[c]);
    }
    clip.EnsureQuaternionContinuity();
    File.WriteAllText(Folder+"turn.json",JsonUtility.ToJson(data,true));AssetDatabase.ImportAsset(Folder+"turn.json");
    // The remaining pose must not contain another 180-degree rotation.
    for(int i=0;i<55;i++)
    {
     clip.SampleAnimation(instance,clip.length*i/54);
     if(Vector3.Angle(axis,Vector3.ProjectOnPlane(right.position-left.position,Vector3.up))>.1f)
      throw new Exception("Turn yaw was not removed from skeleton");
    }
    Debug.Log($"WARRIOR_TURN_EXTRACTED duration={clip.length:F3} yaw={yaw:F3}; skeletal yaw removed, root track owns rotation");
   }
   finally{UnityEngine.Object.DestroyImmediate(instance);}
  }
 }
}
