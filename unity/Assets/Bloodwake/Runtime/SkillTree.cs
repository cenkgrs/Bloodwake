using System.Collections.Generic;
using System.Linq;
using Newtonsoft.Json.Linq;
using UnityEngine;
using UnityEngine.UI;
namespace Bloodwake
{
 // The Blood Sage's tree: each oath has a Power branch (passives, several ranks) and a Motion branch
 // (new moves and combos, one rank). Essence pays for it. Essence earned in a run is only carried:
 // a boss kill secures it into the vault, dying before the boss loses whatever is still carried.
 public sealed partial class BloodwakeGame
 {
  bool Owns(string id)=>Meta.Level(id)>0;
  string hudToast;float hudToastTime;Text toastLabel;
  void Toast(string text){hudToast=text;hudToastTime=2.8f;}

  void EarnEssence(int amount){if(Run!=null&&amount>0&&!combatPractice)Run.EssencePending+=amount;}
  void SecureEssence()
  {
   if(Run==null||Run.EssencePending<=0)return;int amount=Run.EssencePending;Meta.Essence+=amount;Run.EssencePending=0;Meta.Save();
   Toast($"ESSENCE SECURED  +{amount}");Sound("ui_level_up");
  }
  // Called once for every kill.
  void OnEnemyKilled(Enemy e)
  {
   EarnEssence(Mathf.Max(1,Mathf.RoundToInt(e.Data.N("xpReward")/10)));
   if(e.Id=="boss")SecureEssence();
  }
  void OnRoomCleared(){EarnEssence(room.S("type")=="boss"?10:3);if(room.S("type")=="boss"){SecureEssence();slainThisRun=BossVariant.S("name");slainDistrict=DistrictName;}}

  // ---- The tree page.
  static readonly string[] branches={"power","motion"};
  static string BranchTitle(string branch)=>branch=="power"?"POWER":"MOTION";
  JObject[] TreeRows(string classId,string branch)=>GameData.Rows("skills").OfType<JObject>().Where(r=>(bool?)r["retired"]!=true&&r.S("class")==classId&&r.S("branch",r["move"]!=null?"motion":"power")==branch).ToArray();
  int Depth(JObject row){int d=0;var r=row;while(r!=null&&r["requires"]!=null&&d<8){r=GameData.Row("skills",r.S("requires"));d++;}return d;}
  bool Unlockable(JObject row)=>row["requires"]==null||Owns(row.S("requires"));
  int NextCost(JObject row)=>(int)row.N("baseCost")*(Meta.Level(row.S("id"))+1);
  void BuySkill(JObject row)
  {
   string id=row.S("id");int level=Meta.Level(id),max=(int)row.N("maxLevel",3),cost=NextCost(row);
   if(level>=max||!Unlockable(row)||Meta.Essence<cost){Sound("ui_error");return;}
   Meta.Essence-=cost;Meta.Data["levels"][id]=level+1;Meta.Save();Sound("upgrade_pick");
   // A rank bought mid-run takes effect at once.
   if(Run!=null&&row.S("class")==Run.ClassId){float before=Run.Stats.N("maxHp");GameData.Apply(Run.Stats,id,1);if(Run.Stats.N("hp")>Run.Stats.N("maxHp"))Run.Stats["hp"]=Run.Stats["maxHp"].DeepClone();}
  }
  void DrawSkillTree()
  {
   string cls=Run?.ClassId??SelectedClass;var oath=GameData.Rules["classes"][cls];
   Label(page,"OATH OF "+oath.S("name").ToUpperInvariant(),70,150,1460,40,22,true,TextAnchor.MiddleCenter).color=new Color(.86f,.18f,.2f);
   for(int b=0;b<branches.Length;b++)
   {
    string branch=branches[b];float px=110+b*700,py=205,pw=680,ph=575;Frame(page,px,py,pw,ph);
    Label(page,BranchTitle(branch),px+40,py+22,pw-80,44,30,true,TextAnchor.MiddleCenter).color=ink;Rule(page,px+180,py+70,pw-360,.35f);
    var rows=TreeRows(cls,branch).OrderBy(Depth).ThenBy(r=>r.N("baseCost")).ToArray();
    if(rows.Length==0){Label(page,"The Sage has not yet taught this oath its new forms.",px+60,py+260,pw-120,80,20,false,TextAnchor.MiddleCenter).color=new Color(.7f,.66f,.62f);continue;}
    float rowH=Mathf.Min(78,(ph-110)/rows.Length);
    for(int i=0;i<rows.Length;i++)
    {
     var row=rows[i];string id=row.S("id");int level=Meta.Level(id),max=(int)row.N("maxLevel",3),depth=Depth(row);bool open=Unlockable(row),done=level>=max;
     float x=px+34+depth*26,y=py+92+i*rowH,w=pw-68-depth*26;
     if(depth>0)Plate(page,"Tree line",x-16,y+rowH*.5f-1,12,1,new Color(.78f,.72f,.66f,.35f));
     var dim=open?ink:new Color(.5f,.47f,.45f);
     Label(page,row.S("name").ToUpperInvariant()+(max>1?$"   {level}/{max}":""),x,y+2,w-210,26,18,true).color=done?gold:dim;
     Label(page,row.S("description"),x,y+28,w-210,rowH-30,14).color=open?new Color(.74f,.7f,.66f):new Color(.45f,.42f,.4f);
     string text=done?(max>1?"MASTERED":"LEARNED"):!open?"LOCKED":$"{NextCost(row)} ESSENCE";
     var r=row;Button(page,text,x+w-200,y+8,195,Mathf.Min(48,rowH-16),()=>BuySkill(r));
    }
   }
   Label(page,$"ESSENCE  {Meta.Essence}"+(Run!=null&&Run.EssencePending>0?$"   ·   CARRIED  {Run.EssencePending}  (secured when a boss falls)":""),300,800,1000,40,20,true,TextAnchor.MiddleCenter).color=ink;
   Back(Run==null?"menu":"playing");
  }
 }
}
