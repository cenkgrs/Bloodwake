Shader "Bloodwake/Vfx/glow"
{
 Properties {_Tone("Tone",Color)=(1,0,0,1) _Progress("Progress",Float)=0 _Energy("Energy",Float)=1}
 SubShader {Tags {"RenderPipeline"="UniversalPipeline" "Queue"="Transparent" "RenderType"="Transparent"}
 Pass {ZWrite Off Cull Off Blend SrcAlpha One
 HLSLPROGRAM
 #pragma vertex vert
 #pragma fragment frag
 #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
 struct A{float4 positionOS:POSITION;float2 uv:TEXCOORD0;};struct V{float4 positionCS:SV_POSITION;float2 uv:TEXCOORD0;};
 CBUFFER_START(UnityPerMaterial)
 float4 _Tone;float _Progress,_Energy;
 CBUFFER_END
 V vert(A v){V o;o.positionCS=TransformObjectToHClip(v.positionOS.xyz);o.uv=v.uv;return o;}
 half4 frag(V i):SV_Target{float r=length(i.uv*2-1);float alpha=r<.35?lerp(1,.55,r/.35):r<.7?lerp(.55,.12,(r-.35)/.35):lerp(.12,0,saturate((r-.7)/.3));return half4(_Tone.rgb*_Energy,alpha*_Tone.a*(1-_Progress));}
 ENDHLSL
 }}
}
