using System;
using System.IO;
using System.Linq;
using Newtonsoft.Json.Linq;
using UnityEngine;

namespace Bloodwake
{
 public static class GameData
 {
  public const float Unit=.02f;
  public static readonly JObject Catalog=Read("catalogs"), Rules=Read("rules"), Rooms=Read("rooms"), Maps=Read("maps"), Story=Read("story");
  static JObject Read(string name)=>JObject.Parse(Resources.Load<TextAsset>("Data/"+name).text);
  // A region is one self-contained file under Data/regions (maps, rooms, wave combos, enemy kinds), merged in
  // at load so a new district never has to reformat the shared tables.
  static GameData()
  {
   foreach(var asset in Resources.LoadAll<TextAsset>("Data/regions"))
   {
    var region=JObject.Parse(asset.text);
    foreach(var map in region["maps"]??new JArray())((JArray)Maps["maps"]).Add(map.DeepClone());
    foreach(var room in region["rooms"]??new JArray())((JArray)Rooms["rooms"]).Add(room.DeepClone());
    foreach(var enemy in region["enemies"]??new JArray())((JArray)Catalog["enemies"]).Add(enemy.DeepClone());
    if(region["waveCombos"] is JObject combos)foreach(var p in combos.Properties())Story["waveCombos"][p.Name]=p.Value.DeepClone();
   }
  }
  public static JArray Rows(string kind)=>(JArray)Catalog[kind];
  public static JObject Row(string kind,string id)=>(JObject)Rows(kind).FirstOrDefault(r=>(string)r["id"]==id);
  public static float N(this JToken row,string key,float fallback=0)=>row?[key]?.Value<float>()??fallback;
  public static string S(this JToken row,string key,string fallback="")=>row?[key]?.Value<string>()??fallback;
  public static JObject Stats(string id)
  {
   var stats=(JObject)Rules["defaults"].DeepClone();
   foreach(var p in ((JObject)Rules["classes"][id]["stats"]).Properties())stats[p.Name]=p.Value.DeepClone();
   stats["hp"]=stats["maxHp"].DeepClone();return stats;
  }
  public static void Apply(JObject stats,string id,float level=1)
  {
   foreach(var e in Rules["effects"][id]??new JArray())
   {
    string key=(string)e[0],mode=e.Count()>2?(string)e[2]:"add";
    stats[key]=mode=="set"?e[1].DeepClone():new JValue(mode=="mul"?stats.N(key)*Mathf.Pow((float)e[1],level):stats.N(key)+(float)e[1]*level);
   }
   if(id=="last_stand"&&level>=3)stats["hasSecondWind"]=true;
  }
 }
 public sealed class Progression
 {
  public JObject Data=new JObject{["version"]=1,["essence"]=0,["levels"]=new JObject(),["ownedEquipment"]=new JArray(),["loadouts"]=new JArray(new JObject(),new JObject(),new JObject()),["activeLoadout"]=0};
  public string Path=>System.IO.Path.Combine(Application.persistentDataPath,"bloodwake_progression.json");
  public int Essence{get=>(int)Data["essence"];set=>Data["essence"]=Mathf.Clamp(value,0,1000000000);}
  public void Load(){if(File.Exists(Path)&&Import(File.ReadAllText(Path))&&refunded>0)Save();}
  int refunded;
  public bool Import(string text)
  {
   var previous=(JObject)Data.DeepClone();
   try {
    var src=JObject.Parse(text);Essence=Mathf.Clamp((int?)src["essence"]??0,0,1000000000);
    // Retired skills (the old shared passives) are refunded in full and dropped from the save.
    var levels=new JObject();refunded=0;
    foreach(var row in GameData.Rows("skills"))
    {
     int level=Mathf.Clamp((int?)src["levels"]?[row.S("id")]??0,0,(int)row.N("maxLevel",3));
     if((bool?)row["retired"]==true){refunded+=(int)row.N("baseCost")*level*(level+1)/2;continue;}
     levels[(string)row["id"]]=level;
    }
    Data["levels"]=levels;Essence=Mathf.Clamp(Essence+refunded,0,1000000000);
    var owned=new JArray();foreach(var id in src["ownedEquipment"] as JArray??new JArray())if(id.Type==JTokenType.String&&GameData.Row("equipment",(string)id)!=null&&!owned.Any(x=>JToken.DeepEquals(x,id)))owned.Add(id.DeepClone());Data["ownedEquipment"]=owned;
    var loadouts=new JArray();for(int i=0;i<3;i++){var build=new JObject();foreach(string slot in new[]{"armor","boots","charm"}){var list=src["loadouts"] as JArray;string id=list!=null&&i<list.Count?list[i].S(slot):"";if(owned.Any(x=>(string)x==id)&&GameData.Row("equipment",id).S("slot")==slot)build[slot]=id;}loadouts.Add(build);}Data["loadouts"]=loadouts;Data["activeLoadout"]=Mathf.Clamp((int?)src["activeLoadout"]??0,0,2);
    // Story progress: prologue seen, how the last run ended, and the host lines already spoken.
    Data["story"]=src["story"] is JObject story?story.DeepClone():new JObject();return true;
   }catch(Exception e){Data=previous;Debug.LogWarning("Save import rejected: "+e.Message);return false;}
  }
  public int Level(string id)=>(int?)Data["levels"]?[id]??0;
  public void Save(){Directory.CreateDirectory(Application.persistentDataPath);File.WriteAllText(Path+".tmp",Data.ToString());if(File.Exists(Path))File.Replace(Path+".tmp",Path,Path+".bak");else File.Move(Path+".tmp",Path);}
  public void Apply(JObject stats,string classId=null){foreach(var p in ((JObject)Data["levels"]).Properties()){var row=GameData.Row("skills",p.Name);if(row!=null&&(int)p.Value>0&&(row.S("class")==""||row.S("class")==classId))GameData.Apply(stats,p.Name,(int)p.Value);}foreach(var p in ((JObject)Data["loadouts"][(int)Data["activeLoadout"]]).Properties())GameData.Apply(stats,(string)p.Value);}
 }
}
