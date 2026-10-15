// Source: godot/shaders/ground_scar.gdshader.
Shader "Bloodwake/Vfx/ground_scar" {
 Properties {_Progress("Progress",Float)=0 _Age("Age",Float)=0}
 SubShader {Tags {"RenderPipeline"="UniversalPipeline" "Queue"="Transparent" "RenderType"="Transparent"}
 Pass {ZWrite Off Cull Off Blend SrcAlpha OneMinusSrcAlpha
 HLSLPROGRAM
 #pragma vertex vert
 #pragma fragment frag
 #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
 CBUFFER_START(UnityPerMaterial)
 float _Progress,_Age;
 CBUFFER_END
 struct A{float4 pos:POSITION;float2 uv:TEXCOORD0;};struct V{float4 pos:SV_POSITION;float2 uv:TEXCOORD0;};
 V vert(A v){V o;o.pos=TransformObjectToHClip(v.pos.xyz);o.uv=v.uv;return o;}
 float hash(float2 p){return frac(sin(dot(p,float2(127.1,311.7)))*43758.5453);}
float noise(float2 p){float2 i=floor(p),f=frac(p);f=f*f*(3.0-2.0*f);return lerp(lerp(hash(i),hash(i+float2(1,0)),f.x),lerp(hash(i+float2(0,1)),hash(i+float2(1,1)),f.x),f.y);}
float fracture(float2 p){
 float2 cell=floor(p);float2 local=frac(p);float first=10.0;float second=10.0;
 for(int y=-1;y<=1;y++){
  for(int x=-1;x<=1;x++){
   float2 offset=float2(float(x),float(y));
   float2 seed=float2(hash(cell+offset),hash(cell+offset+float2(47.2,13.7)));
   float d=length(offset+seed-local);
   if(d<first){second=first;first=d;}else{second=min(second,d);}
  }
 }
 return second-first;
}
half4 frag(V i):SV_Target{ float3 ALBEDO=0;float ALPHA=0;
 float2 p=i.uv*2.0-1.0;float r=length(p);
 float n=noise(p*17.0);
 float branch=fracture(p*3.6+float2(0.37,0.13));
 float crack=1.0-smoothstep(0.012,0.04,branch);
 float chip=1.0-smoothstep(0.035,0.075,branch);
 float edge=1.0-smoothstep(0.6+n*0.22,0.94,r);
 float crater=exp(-r*7.0)*0.7;
 ALBEDO=lerp(float3(0.24,0.17,0.11),float3(0.025,0.018,0.012),crack);
 ALPHA=(chip*0.85+crater+n*0.13)*edge*(1.0-smoothstep(1.3,1.9,_Age));
return half4(ALBEDO,ALPHA);
}
 ENDHLSL
 }}}
