Shader "Bloodwake/Vfx/arcane_core"
{
Properties{_Tone("Tone",Color)=(.6,.4,1,1) _Accent("Accent",Color)=(.2,.1,.7,1) _Clock("Clock",Float)=0 _Progress("Progress",Float)=0}
SubShader{Tags{"RenderPipeline"="UniversalPipeline" "Queue"="Geometry" "RenderType"="Opaque"}
Pass{ZWrite On Cull Back
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
half4 frag(V i):SV_Target{
float2 p=i.uv*float2(18,12);float swirl=sin(p.x+sin(p.y*1.4-_Clock*3)*2+_Clock*2.5);
float veins=pow(1-abs(sin(p.y+swirl*2.3-_Clock*2)),7);
float rim=pow(1-saturate(dot(normalize(i.normal),GetWorldSpaceNormalizeViewDir(i.world))),2);
return half4(lerp(_Tone.rgb*.3,_Tone.rgb*1.5,.35+swirl*.15)+lerp(_Tone.rgb,1,.35)*(veins*.9+rim*.45)+_Accent.rgb*swirl*.12,1);
}
ENDHLSL
}}}
