Shader "Bloodwake/Vfx/damage_text"
{
 Properties {_MainTex("Font atlas",2D)="white"{}}
 SubShader {Tags {"RenderPipeline"="UniversalPipeline" "Queue"="Overlay" "RenderType"="Transparent"}
 Pass {ZWrite Off ZTest Always Cull Off Blend SrcAlpha OneMinusSrcAlpha
 HLSLPROGRAM
 #pragma vertex vert
 #pragma fragment frag
 #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
 TEXTURE2D(_MainTex);SAMPLER(sampler_MainTex);
 struct A{float4 pos:POSITION;float2 uv:TEXCOORD0;float4 color:COLOR;};
 struct V{float4 pos:SV_POSITION;float2 uv:TEXCOORD0;float4 color:COLOR;};
 V vert(A v){V o;o.pos=TransformObjectToHClip(v.pos.xyz);o.uv=v.uv;o.color=v.color;return o;}
 half4 frag(V i):SV_Target{return half4(i.color.rgb,i.color.a*SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.uv).a);}
 ENDHLSL
 }}
}
