Shader "Bloodwake/Vfx/particle_opaque"
{
 Properties {_Tone("Tone",Color)=(1,1,1,1) _Progress("Progress",Float)=0}
 SubShader {Tags {"RenderPipeline"="UniversalPipeline" "Queue"="Geometry" "RenderType"="Opaque"}
 Pass {ZWrite On Cull Back
 HLSLPROGRAM
 #pragma vertex vert
 #pragma fragment frag
 #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
 CBUFFER_START(UnityPerMaterial)
 float4 _Tone;float _Progress;
 CBUFFER_END
 struct A{float4 pos:POSITION;};struct V{float4 pos:SV_POSITION;};
 V vert(A v){V o;o.pos=TransformObjectToHClip(v.pos.xyz);return o;}
 half4 frag(V i):SV_Target{return half4(_Tone.rgb,_Tone.a);}
 ENDHLSL
 }}
}
