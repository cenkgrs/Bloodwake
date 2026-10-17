using System.Collections.Generic;
using System.Linq;
using Newtonsoft.Json.Linq;
using UnityEngine;
namespace Bloodwake
{
 // The first-launch prologue, and what the Blood Sage and the Quartermaster say on each return,
 // picked from Data/story.json by how the last run ended and never repeated until a pool runs dry.
 public sealed partial class BloodwakeGame
 {
  JObject StoryState{get{if(!(Meta.Data["story"] is JObject state)){state=new JObject();Meta.Data["story"]=state;}return state;}}
  bool IntroSeen=>(bool?)StoryState["introSeen"]==true;
  // One line per host per return: talking to the same host again on the same visit repeats it.
  readonly Dictionary<string,string> visitLines=new();

  // NEW RUN: the very first time it plays the prologue as Vesper and goes straight into the first
  // district; afterwards it opens the oath screen.
  void NewRun()
  {
   mirrorMode=false;if(IntroSeen){Screen="classes";return;}
   SelectedClass="vesper";StartRun("vesper");visitLines.Clear();
   OpenDialogue(new JObject{["role"]="prologue",["name"]="",["verb"]="BEGIN THE HUNT",["lines"]=GameData.Story["prologue"].DeepClone()});
  }
  void FinishPrologue()
  {
   StoryState["introSeen"]=true;Meta.Save();EndDialogue();Sound("ui_begin_hunt");EnterDistrict();
  }

  // Called when a run ends one way or another; the next visit to the hall reads it.
  // The warden this run broke, if any: a death after a kill is remembered as the kill.
  string slainThisRun,slainDistrict;
  void RecordRunEnd(string outcome)
  {
   if(Run==null)return;
   string boss=outcome=="slew_boss"&&slainThisRun!=null?slainThisRun:BossVariant.S("name");
   StoryState["last"]=new JObject{["outcome"]=outcome,["district"]=outcome=="slew_boss"&&slainDistrict!=null?slainDistrict:DistrictName,["boss"]=boss};
   StoryState["returns"]=((int?)StoryState["returns"]??0)+1;visitLines.Clear();slainThisRun=null;Meta.Save();
  }
  string RunEndCategory()=>room?.S("type")=="boss"?"fell_boss":slainThisRun!=null?"slew_boss":Run.Night<=1&&Run.RoomIndex<=1?"fell_early":"fell_deep";

  // The hall's hosts speak one fresh line, then open their service.
  JArray HostLines(JToken host)
  {
   string role=host.S("role");if(GameData.Story["hostLines"]?[role]==null)return host["lines"] as JArray;
   if(!visitLines.TryGetValue(role,out var line))visitLines[role]=line=PickHostLine(role);
   return new JArray(line);
  }
  string PickHostLine(string role)
  {
   var pools=(JObject)GameData.Story["hostLines"][role];var last=StoryState["last"];
   int returns=(int?)StoryState["returns"]??0;string outcome=last?.S("outcome")??"";
   // The first return after the first run gets the welcome; otherwise the outcome, then the general pool.
   var order=new List<string>();if(returns==1&&!SeenAny(role,"first"))order.Add("first");if(outcome!="")order.Add(outcome);order.Add("any");
   for(int attempt=0;attempt<2;attempt++)
   {
    var seen=Seen(role);
    foreach(string category in order)
    {
     var lines=pools[category] as JArray;if(lines==null)continue;
     var fresh=Enumerable.Range(0,lines.Count).Where(i=>!seen.Any(s=>(string)s==category+":"+i)).ToList();if(fresh.Count==0)continue;
     int pick=fresh[Random.Range(0,fresh.Count)];seen.Add(category+":"+pick);Meta.Save();
     return ((string)lines[pick]).Replace("{district}",TitleCase(last?.S("district")??DistrictName)).Replace("{boss}",TitleCase(last?.S("boss")??BossVariant.S("name")));
    }
    // Every line of these categories has been heard: start the pools over.
    seen.Clear();
   }
   return (string)pools["any"][0];
  }
  JArray Seen(string role){if(!(StoryState["seen"] is JObject all)){all=new JObject();StoryState["seen"]=all;}if(!(all[role] is JArray list)){list=new JArray();all[role]=list;}return list;}
  bool SeenAny(string role,string category)=>Seen(role).Any(s=>((string)s).StartsWith(category+":"));
  static string TitleCase(string text)
  {
   if(string.IsNullOrEmpty(text))return text;var words=text.ToLowerInvariant().Split(' ');
   for(int i=0;i<words.Length;i++)if(words[i].Length>0&&(i==0||words[i] is not ("of" or "the" or "who" or "to")))words[i]=char.ToUpperInvariant(words[i][0])+words[i].Substring(1);
   return string.Join(" ",words);
  }
 }
}
