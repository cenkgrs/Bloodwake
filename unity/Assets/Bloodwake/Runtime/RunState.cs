using System.Collections.Generic;
using System.Linq;
using Newtonsoft.Json.Linq;
using UnityEngine;
namespace Bloodwake
{
 public sealed class RunState
 {
  public string ClassId; public JObject Stats; public readonly Dictionary<string,JObject> Weapons=new();
  public readonly Dictionary<string,int> Upgrades=new(); public readonly Dictionary<string,float> ItemGrades=new();
  public readonly Dictionary<string,float> Cooldowns=new(); public readonly HashSet<string> Claimed=new();
  public int Wave=1,Kills,Gold,Level=1,Xp,PendingLevels,Night=1,RoomIndex,Fights,RoomsCleared,LevelAwardedWave=-1;
  public bool Awarded; public List<string> Plan=new(); public string MapId="cursed_town";
  public RunState(string id,Progression meta=null){ClassId=id;Stats=GameData.Stats(id);meta?.Apply(Stats,id);Stats["hp"]=Stats["maxHp"].DeepClone();AddWeapon(GameData.Rules["classes"][id].S("weapon"));}
  public bool AddWeapon(string id){if(Weapons.ContainsKey(id)||Weapons.Count>=4||GameData.Row("weapons",id)==null)return false;Weapons[id]=new JObject{["damage"]=1f,["speed"]=1f,["range"]=1f,["pierce"]=0,["chain"]=0,["shockwave"]=0,["burn"]=0,["bleed"]=0};return true;}
  public int XpNeeded=>80+30*(Level-1)+5*(Level-1)*(Level-1);
  public void AddXp(int amount){if(amount<=0)return;Xp+=Mathf.RoundToInt(amount*Stats.N("xpMultiplier"));if(LevelAwardedWave!=Wave&&Xp>=XpNeeded){Xp-=XpNeeded;Level++;PendingLevels++;LevelAwardedWave=Wave;}if(LevelAwardedWave==Wave)Xp=Mathf.Min(Xp,XpNeeded/2);}
  public float Hurt(float damage,float roll=1){if(Stats.N("hp")<=0||roll<Stats.N("dodgeChance"))return 0;float amount=damage*Mathf.Clamp01(1-Stats.N("armor"));Stats["hp"]=Mathf.Max(0,Stats.N("hp")-amount);if(Stats.N("hp")<=0&&(bool)Stats["hasSecondWind"]){Stats["hasSecondWind"]=false;Stats["hp"]=1;}return amount;}
  public bool Available(JToken row,string kind)
  {
   string id=row.S("id");if(kind=="upgrades"&&Upgrades.GetValueOrDefault(id)>=row.N("maxLevel"))return false;
   if(kind=="items"&&(ItemGrades.ContainsKey(id)||ItemGrades.Count>=8||Night<row.N("minNight",1)))return false;
   string gate=row.S("isAvailable");
   foreach(string cls in new[]{"warrior","mage"})if(gate=="_"+cls)return ClassId==cls||((ClassId=="revenant"||ClassId=="vesper")&&cls=="warrior");
   var gates=new Dictionary<string,string>{{"_ownsSword","sword"},{"_ownsLightning","lightning"},{"_ownsRifle","rapid_rifle"},{"_ownsOrb","magic_orb"},{"_ownsDaggers","daggers"}};
   if(gates.ContainsKey(gate)&&!Weapons.ContainsKey(gates[gate]))return false;
   var needs=new Dictionary<string,string[]>{{"thunderquake",new[]{"warrior","greatsword","storm_blade"}},{"spellfire",new[]{"mage","orb_pierce","orb_power"}}};
   if(needs.TryGetValue(id,out var req))return (ClassId==req[0]||((ClassId=="revenant"||ClassId=="vesper")&&req[0]=="warrior"))&&Upgrades.GetValueOrDefault(req[1])>0&&Upgrades.GetValueOrDefault(req[2])>0;return true;
  }
  public bool Upgrade(string id){var row=GameData.Row("upgrades",id);if(row==null||!Available(row,"upgrades"))return false;Upgrades[id]=Upgrades.GetValueOrDefault(id)+1;Apply(id);return true;}
  public void Apply(string id,float level=1)
  {
   GameData.Apply(Stats,id,level);
   string[] spec=id switch {
    "greatsword"=>new[]{"sword","range",".25"},"storm_blade"=>new[]{"sword","chain","1"},"shockwave"=>new[]{"sword","shockwave","35"},
    "orb_pierce"=>new[]{"magic_orb","pierce","1"},"orb_power"=>new[]{"magic_orb","damage",".25"},"orb_range"=>new[]{"magic_orb","range",".2"},
    "spellfire"=>new[]{"magic_orb","burn","7"},
    "rifle_mechanism"=>new[]{"rapid_rifle","speed",".25"},"orb_focus"=>new[]{"magic_orb","damage",".3"},"dagger_steel"=>new[]{"daggers","damage",".3"},_=>null};
   if(spec!=null&&Weapons.TryGetValue(spec[0],out var slot))slot[spec[1]]=slot.N(spec[1])+float.Parse(spec[2],System.Globalization.CultureInfo.InvariantCulture)*level;
   if(id=="thunderquake"&&Weapons.TryGetValue("sword",out var sword)){sword["chain"]=sword.N("chain")+1;sword["shockwave"]=sword.N("shockwave")+60;}
   string mult=id=="gold_sword"?"sword":id=="thunder_core"?"lightning":null;if(mult!=null&&Weapons.TryGetValue(mult,out var w))w["damage"]=w.N("damage")*Mathf.Pow(mult=="sword"?1.3f:1.25f,level);
  }
  public float Grade=>Mathf.Min(1+.6f*(Night-1),3.4f);
  public bool Temperable(string id)=>(GameData.Rules["effects"][id]??new JArray()).Any(e=>e.Count()<3||(string)e[2]!="set")||new[]{"gold_sword","thunder_core","rifle_mechanism","orb_focus","dagger_steel"}.Contains(id);
  public List<JToken> MerchantOffers()
  {
   var pool=new List<(JToken row,float weight)>();foreach(var row in GameData.Rows("items"))
   {
    string id=row.S("id");float prior=ItemGrades.GetValueOrDefault(id);if(Night<row.N("minNight",1))continue;
    if(prior>0?(prior>=Grade-.01f||!Temperable(id)):!Available(row,"items"))continue;
    float weight=row.S("rarity") switch{"common"=>Night<=1?6:0,"rare"=>Night<=1?3:2.5f,"epic"=>Night<=1?1.2f:3,"legendary"=>Night<=1?.5f:2,_=>1};if(prior>0)weight=Mathf.Max(weight,1.5f);if(weight>0)pool.Add((row,weight));
   }
   var picked=new List<JToken>();int count=Night<=1?3:4;
   while(picked.Count<count&&pool.Count>0){float roll=Random.value*pool.Sum(p=>p.weight);int index=pool.Count-1;for(int i=0;i<pool.Count;i++){roll-=pool[i].weight;if(roll<=0){index=i;break;}}picked.Add(pool[index].row);pool.RemoveAt(index);}return picked;
  }
  public bool Buy(string id){var row=GameData.Row("items",id);if(row==null)return false;float previous=ItemGrades.GetValueOrDefault(id);if(previous>=Grade||previous==0&&!Available(row,"items"))return false;int cost=Mathf.RoundToInt(row.N("cost")*(Grade-previous))+(previous>0?5:0);if(Gold<cost)return false;Gold-=cost;ItemGrades[id]=Grade;Apply(id,Grade-previous);return true;}
 }
}
