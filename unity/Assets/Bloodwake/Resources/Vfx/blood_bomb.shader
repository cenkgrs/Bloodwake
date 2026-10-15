Shader "Bloodwake/Vfx/blood_bomb"
{
 Properties { _Progress("Progress",Float)=0 _Clock("Clock",Float)=0 _Layer("Layer",Float)=0 _Seed("Seed",Float)=0 }
 SubShader
 {
  Tags {"RenderPipeline"="UniversalPipeline" "Queue"="Transparent" "RenderType"="Transparent"}
  Pass
  {
   ZWrite Off Cull Off Blend SrcAlpha OneMinusSrcAlpha
   HLSLPROGRAM
   #pragma vertex vert
   #pragma fragment frag
   #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
   struct A {float4 positionOS:POSITION;float2 uv:TEXCOORD0;};
   struct V {float4 positionCS:SV_POSITION;float2 uv:TEXCOORD0;float3 world:TEXCOORD1;float3 normal:TEXCOORD2;};
   CBUFFER_START(UnityPerMaterial)
   float _Progress,_Clock,_Layer,_Seed;
   CBUFFER_END
   float hash(float2 p){return frac(sin(dot(p,float2(127.1,311.7)))*43758.5453);}
   float noise(float2 p){float2 c=floor(p),f=frac(p);f=f*f*(3-2*f);return lerp(lerp(hash(c),hash(c+float2(1,0)),f.x),lerp(hash(c+float2(0,1)),hash(c+1),f.x),f.y);}
   float3 surface(float2 uv)
   {
    float r=uv.x,a=uv.y,angle=lerp(-.785398,.785398,a);
    float expansion=lerp(.16,1,1-pow(1-saturate(_Clock/.14),3));
    float edge=.96+.04*sin(a*26+_Seed);
    float y=r*(_Layer*.62+sin(r*8-a*10+_Seed-_Clock*9)*.16+sin(a*22+_Seed)*.065)-r*_Clock*_Clock*2.5;
    return float3(sin(angle)*r*expansion*edge,y,cos(angle)*r*expansion*edge);
   }
   V vert(A v)
   {
    V o;float3 p=surface(v.uv);o.world=TransformObjectToWorld(p);
    float3 dr=TransformObjectToWorld(surface(v.uv+float2(.002,0)))-o.world;
    float3 da=TransformObjectToWorld(surface(v.uv+float2(0,.002)))-o.world;
    o.normal=normalize(cross(dr,da)+float3(0,.000001,0));
    o.positionCS=TransformWorldToHClip(o.world);o.uv=v.uv;return o;
   }
   half4 frag(V i):SV_Target
   {
    float r=i.uv.x,a=i.uv.y;
    float broad=noise(float2(r*5-_Clock*4,a*24)+_Seed);
    float detail=noise(float2(r*20-_Clock*7,a*95)+_Seed);
    float fluid=broad*.75+detail*.25;
    float threshold=lerp(.33,.74,smoothstep(.28,1,_Progress))+.08*r;
    float mask=smoothstep(threshold-.055,threshold+.025,fluid);
    mask*=smoothstep(0,.06,a)*smoothstep(0,.06,1-a)*smoothstep(0,.08,r)*(1-smoothstep(.87,1,r));
    float3 n=normalize(i.normal),v=normalize(GetWorldSpaceViewDir(i.world));if(dot(n,v)<0)n=-n;
    Light light=GetMainLight();float spec=pow(saturate(dot(n,normalize(light.direction+v))),140);
    float edge=1-smoothstep(.025,.12,abs(fluid-threshold));
    float3 blood=lerp(float3(.065,.001,.004),float3(.27,.006,.019),detail);
    float3 reflection=GlossyEnvironmentReflection(reflect(-v,n),i.world,.14,1);
    float3 color=blood*(.65+abs(dot(n,light.direction))*.5)+float3(.4,.008,.016)*edge*.16+light.color*spec*.075+reflection*.015;
    float alpha=mask*(1-smoothstep(.55,1,_Progress))*.85;
    return half4(color,alpha);
   }
   ENDHLSL
  }
 }
}
