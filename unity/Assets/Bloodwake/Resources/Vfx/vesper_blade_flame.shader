Shader "Bloodwake/Vesper Blade Flame"
{
 Properties { _BaseColor("Flame color",Color)=(1,.65,.05,1) }
 SubShader
 {
  Tags { "Queue"="Transparent+20" "RenderType"="Transparent" "RenderPipeline"="UniversalPipeline" }
  ZWrite Off Cull Off Blend SrcAlpha OneMinusSrcAlpha
  Pass
  {
   HLSLPROGRAM
   #pragma vertex vert
   #pragma fragment frag
   #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
   struct Attributes { float4 positionOS:POSITION; float2 uv:TEXCOORD0; float4 color:COLOR; };
   struct Varyings { float4 positionHCS:SV_POSITION; float2 uv:TEXCOORD0; float4 color:COLOR; };
   CBUFFER_START(UnityPerMaterial) float4 _BaseColor; CBUFFER_END
   Varyings vert(Attributes input){Varyings output;output.positionHCS=TransformObjectToHClip(input.positionOS.xyz);output.uv=input.uv;output.color=input.color;return output;}
   half4 frag(Varyings input):SV_Target
   {
    float across=abs(input.uv.y*2-1);float soft=pow(saturate(1-across),.62);float flicker=.82+.18*sin(_Time.y*15+input.uv.x*31);
    return half4(_BaseColor.rgb*input.color.rgb,_BaseColor.a*input.color.a*soft*flicker);
   }
   ENDHLSL
  }
 }
}
