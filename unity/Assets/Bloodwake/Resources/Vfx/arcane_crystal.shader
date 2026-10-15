Shader "Bloodwake/Vfx/arcane_crystal"
{
 Properties { _Tint("Tint",Color)=(.30,.56,1,1) _Fade("Fade",Range(0,1))=1 }
 SubShader
 {
  Tags {"RenderPipeline"="UniversalPipeline" "Queue"="Transparent" "RenderType"="Transparent"}
  Pass
  {
   Blend SrcAlpha OneMinusSrcAlpha ZWrite Off Cull Back
   HLSLPROGRAM
   #pragma vertex vert
   #pragma fragment frag
   #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
   float _Fade;float4 _Tint;
   float3 hash3(float3 p){return frac(sin(float3(dot(p,float3(127.1,311.7,74.7)),dot(p,float3(269.5,183.3,246.1)),dot(p,float3(113.5,271.9,124.6))))*43758.5453);}
   float iceNoise(float3 p)
   {
    float3 c=floor(p),f=frac(p);f=f*f*(3-2*f);
    float a=lerp(lerp(hash3(c).x,hash3(c+float3(1,0,0)).x,f.x),lerp(hash3(c+float3(0,1,0)).x,hash3(c+float3(1,1,0)).x,f.x),f.y);
    float b=lerp(lerp(hash3(c+float3(0,0,1)).x,hash3(c+float3(1,0,1)).x,f.x),lerp(hash3(c+float3(0,1,1)).x,hash3(c+1).x,f.x),f.y);
    return lerp(a,b,f.z);
   }
   float crack(float3 p)
   {
    float3 cell=floor(p),f=frac(p);float first=8,second=8;
    for(int z=-1;z<=1;z++)for(int y=-1;y<=1;y++)for(int x=-1;x<=1;x++){float3 o=float3(x,y,z);float d=length(o+hash3(cell+o)-f);if(d<first){second=first;first=d;}else second=min(second,d);}
    return 1-smoothstep(.004,.028,second-first);
   }
   struct A{float4 p:POSITION;float3 n:NORMAL;};
   struct V{float4 p:SV_POSITION;float3 world:TEXCOORD0;float3 normal:TEXCOORD1;float3 local:TEXCOORD2;};
   V vert(A a){V o;o.world=TransformObjectToWorld(a.p.xyz);o.p=TransformWorldToHClip(o.world);o.normal=TransformObjectToWorldNormal(a.n);o.local=a.p.xyz;return o;}
   half4 frag(V i):SV_Target
   {
    float3 n=normalize(i.normal),v=normalize(GetWorldSpaceViewDir(i.world));float rim=pow(1-saturate(dot(n,v)),3);
    float fracture=crack(i.local*4.5)*.14;
    float frost=smoothstep(.3,.85,iceNoise(i.local*6)+iceNoise(i.local*21)*.25);
    Light light=GetMainLight();float facing=saturate(dot(n,light.direction));
    float spec=pow(saturate(dot(n,normalize(light.direction+v))),70);
    float3 reflected=GlossyEnvironmentReflection(reflect(-v,n),i.world,.12,1);
    float backlight=pow(saturate(dot(-light.direction,v)),3);
    float3 body=_Tint.rgb*(.14+facing*.3+backlight*.15)+reflected*.52;
    body+=float3(.42,.62,.8)*frost*.18;
    float3 color=body+float3(.8,.95,1.2)*fracture*1.1+float3(.48,.65,.95)*rim*.85+light.color*spec*.8;
    return half4(color,saturate(.62+frost*.18+rim*.14)*_Fade);
   }
   ENDHLSL
  }
 }
}
