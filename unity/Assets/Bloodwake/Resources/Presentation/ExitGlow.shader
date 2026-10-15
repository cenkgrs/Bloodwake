Shader "Bloodwake/Presentation/ExitGlow"
{
 Properties { _Clock("Clock",Float)=0 }
 SubShader
 {
  Tags { "RenderPipeline"="UniversalPipeline" "Queue"="Transparent" "RenderType"="Transparent" }
  Pass
  {
   Cull Off ZWrite Off Blend SrcAlpha One
   HLSLPROGRAM
   #pragma vertex vert
   #pragma fragment frag
   #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
   CBUFFER_START(UnityPerMaterial)
   float _Clock;
   CBUFFER_END
   struct A { float4 p:POSITION;float2 uv:TEXCOORD0; };
   struct V { float4 p:SV_POSITION;float2 uv:TEXCOORD0; };
   V vert(A a){V o;o.p=TransformObjectToHClip(a.p.xyz);o.uv=a.uv;return o;}
   half4 frag(V i):SV_Target
   {
    float2 d=abs(i.uv-.5)*2;
    float feather=(1-smoothstep(.65,1,d.x))*(1-smoothstep(.6,1,d.y));
    float pulse=.8+.2*sin(_Clock*2);
    return half4(1,.55,.19,feather*.24*pulse);
   }
   ENDHLSL
  }
 }
}
