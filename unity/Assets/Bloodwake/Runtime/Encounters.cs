using System.Collections.Generic;
using System.Linq;
using Newtonsoft.Json.Linq;
using UnityEngine;
namespace Bloodwake
{
 // Fights are rolled, not authored: each combat room draws wave combos at random from its district's
 // pool in Data/story.json, and each district has its own Bellwarden with its own pattern and tempo.
 public sealed partial class BloodwakeGame
 {
  // A combo is a short chain of rounds: the next round rises only when the last one is dead.
  bool rolledWaves;readonly HashSet<int> comboStarts=new();
  const int RolledAliveCap=8;
  JArray RollWaves()
  {
   var pools=(JArray)GameData.Story["districtPools"];var combos=(JObject)GameData.Story["waveCombos"];
   var pool=pools[Mathf.Clamp(Run.Night-1,0,pools.Count-1)].Values<string>().Where(id=>combos[id]!=null).ToList();
   // The first two streets of a district hold one combo; the deeper three hold two.
   int count=Run.RoomIndex<2?1:2,extra=(Run.Night-1)/3;var rosters=new JArray();comboStarts.Clear();
   for(int i=0;i<count&&pool.Count>0;i++)
   {
    string id=pool[Random.Range(0,pool.Count)];pool.Remove(id);comboStarts.Add(rosters.Count);
    foreach(var round in (JArray)combos[id])
    {
     var list=round.Values<string>().ToList();
     // Later districts thicken every round with more of the same kinds.
     for(int e=0;e<extra;e++)list.Add(list[Random.Range(0,list.Count)]);
     rosters.Add(new JArray(list));
    }
   }
   return rosters;
  }
  // ---- Bellwardens.
  JToken BossVariant{get{var all=(JArray)GameData.Story["bossVariants"];return all[Mathf.Clamp((Run?.Night??1)-1,0,all.Count-1)];}}
  string[] BossPattern{get{var p=BossVariant["pattern"] as JArray;return p!=null&&p.Count>0?p.Values<string>().ToArray():new[]{"attack","sweep","cast","charge","slam","summon"};}}
  float BossTempo=>BossVariant.N("tempo",1);
  string[] BossSummons{get{var s=BossVariant["summon"] as JArray;return s!=null&&s.Count>0?s.Values<string>().ToArray():new[]{"grunt"};}}
 }
}
