Shader "Bloodwake/Vfx/arcane_trail"
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
float tail=i.uv.y,x=i.uv.x*2-1;float grain=noise(float2(x*5,tail*9-_Clock*4));
float wave=sin(tail*14-_Clock*9)*.17*tail;float envelope=pow(max(0,1-tail),.8);
float filament=pow(1-abs(sin(x*12+tail*9+grain*3.5-_Clock*5)),9);float width=(.58+grain*.34)*envelope;
float body=1-smoothstep(width*.35,max(width,.0001),abs(x-wave));float alpha=body*(.12+filament*.75+grain*.15)*envelope;
alpha*=smoothstep(0,.035,tail)*(1-smoothstep(.93,1,tail));return half4(lerp(_Accent.rgb,_Tone.rgb,filament*.7+grain*.3)*1.35,alpha);
}
ENDHLSL
}}}
