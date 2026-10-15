Shader "Bloodwake/Vfx/arcane_energy"
{
 Properties{_Tone("Tone",Color)=(1,1,1,1) _Opacity("Opacity",Float)=1}
 SubShader { Tags {"RenderPipeline"="UniversalPipeline" "Queue"="Transparent" "RenderType"="Transparent"}
 Pass { Blend SrcAlpha One ZWrite Off Cull Off
 HLSLPROGRAM
 #pragma vertex vert
 #pragma fragment frag
 #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
 float4 _Tone;float _Opacity;
 struct A{float4 p:POSITION;float2 uv:TEXCOORD0;};struct V{float4 p:SV_POSITION;float2 uv:TEXCOORD0;};
 V vert(A a){V o;o.p=TransformObjectToHClip(a.p.xyz);o.uv=a.uv;return o;}
 half4 frag(V i):SV_Target{return half4(_Tone.rgb,_Tone.a*_Opacity*pow(saturate(1-abs(i.uv.y*2-1)),.7));}
 ENDHLSL
 }}
}
