// Swept-blade flame ribbon. u: 0 at the blade now -> 1 oldest; v: 0 grip -> 1 tip.
// Long fire streaks stretched along the swing, white-gold at the blade edge, cooling
// through crimson into black smoke as they trail and fade.
Shader "Bloodwake/VesperBladeStreak"
{
 Properties { _Intensity("Intensity",Float)=2.4 _Speed("Streak scroll",Float)=3 }
 SubShader
 {
  Tags { "RenderType"="Transparent" "Queue"="Transparent" "RenderPipeline"="UniversalPipeline" }
  Pass
  {
   Blend One One ZWrite Off Cull Off
   HLSLPROGRAM
   #pragma vertex vert
   #pragma fragment frag
   #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
   CBUFFER_START(UnityPerMaterial) float _Intensity,_Speed; CBUFFER_END
   struct A{float4 p:POSITION;float2 uv:TEXCOORD0;float4 c:COLOR;};
   struct V{float4 p:SV_POSITION;float2 uv:TEXCOORD0;float4 c:COLOR;};
   V vert(A i){V o;o.p=TransformObjectToHClip(i.p.xyz);o.uv=i.uv;o.c=i.c;return o;}
   float h(float2 p){return frac(sin(dot(p,float2(127.1,311.7)))*43758.5453);}
   float n(float2 p){float2 i=floor(p),f=frac(p);f=f*f*(3-2*f);return lerp(lerp(h(i),h(i+float2(1,0)),f.x),lerp(h(i+float2(0,1)),h(i+1),f.x),f.y);}
   float fbm(float2 p){return n(p)*.55+n(p*2.1)*.3+n(p*4.3)*.15;}
   float4 frag(V i):SV_Target
   {
    float u=i.uv.x,v=i.uv.y,t=_Time.y*_Speed;
    // Streaks: noise stretched along u (the swing direction), so it reads as lines of flame.
    float streak=fbm(float2(u*2.2-t,v*14));streak=smoothstep(.35,.85,streak+.35*(1-u));
    float body=smoothstep(0,.18,v)*smoothstep(1,.7,v);      // fade at grip, strongest toward the tip
    float tail=pow(1-u,1.6);                                  // newest edge brightest
    float heat=saturate(tail*1.4-.15);
    float3 col=lerp(float3(.06,.01,.01),float3(.9,.08,.02),saturate(heat*2));
    col=lerp(col,float3(1,.55,.08),saturate(heat*2-.6));col=lerp(col,float3(1,.93,.6),saturate(heat*3-2.2));
    return float4(col*streak*body*tail*_Intensity*i.c.a,0);
   }
   ENDHLSL
  }
 }
}
