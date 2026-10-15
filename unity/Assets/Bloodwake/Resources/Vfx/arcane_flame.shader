Shader "Bloodwake/Vfx/arcane_flame"
{
Properties{_Tone("Tone",Color)=(.6,.4,1,1) _Accent("Accent",Color)=(.2,.1,.7,1) _Clock("Clock",Float)=0 _Progress("Progress",Float)=0}
SubShader{Tags{"RenderPipeline"="UniversalPipeline" "Queue"="Transparent" "RenderType"="Transparent"}
Pass{Blend SrcAlpha One ZWrite Off Cull Off
HLSLPROGRAM
#pragma vertex vert
#pragma fragment frag
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
CBUFFER_START(UnityPerMaterial)
float4 _Tone,_Accent;float _Clock,_Progress;
CBUFFER_END
struct A{float4 pos:POSITION;float3 normal:NORMAL;float2 uv:TEXCOORD0;};
struct V{float4 pos:SV_POSITION;float3 world:TEXCOORD0;float3 normal:TEXCOORD1;float2 uv:TEXCOORD2;};
V vert(A a){V o;o.world=TransformObjectToWorld(a.pos.xyz);o.pos=TransformWorldToHClip(o.world);o.normal=TransformObjectToWorldNormal(a.normal);o.uv=a.uv;return o;}
float hash(float2 p){return frac(sin(dot(p,float2(127.1,311.7)))*43758.5453);}
float noise(float2 p){float2 j=floor(p),f=frac(p);f=f*f*(3-2*f);return lerp(lerp(hash(j),hash(j+float2(1,0)),f.x),lerp(hash(j+float2(0,1)),hash(j+1),f.x),f.y);}
half4 frag(V i):SV_Target{
float h=i.uv.y;float n=noise(float2(i.uv.x*7,h*6-_Clock*3.5));
float x=abs(i.uv.x*2-1+sin(h*6+_Clock*4)*h*.15);float width=pow(1-h,1.4)*(.65+n*.6);
float body=1-smoothstep(width*.4,max(width,.0001),x);float veins=pow(1-abs(sin(x*13+h*11+n*4)),6);
float life=smoothstep(0,.12,_Progress)*(1-smoothstep(.25,1,_Progress));
return half4(lerp(_Accent.rgb,_Tone.rgb,.4+veins*.6)*1.6,body*(.15+n*.25+veins*.6)*life*(1-smoothstep(.85,1,h)));
}
ENDHLSL
}}}
