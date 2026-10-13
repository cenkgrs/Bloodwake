Shader "Bloodwake/Town Outside"
{
 Properties { _BaseMap("Cobble",2D)="white"{} _HalfSize("Town half size",Vector)=(20,20,0,0) _Night("Night",Color)=(.012,.014,.02,1) }
 SubShader
 {
  Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="Opaque" }
  Pass
  {
   HLSLPROGRAM
   #pragma vertex vert
   #pragma fragment frag
   #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
   TEXTURE2D(_BaseMap);SAMPLER(sampler_BaseMap);
   CBUFFER_START(UnityPerMaterial)
   float4 _HalfSize;float4 _Night;
   CBUFFER_END
   struct Attributes {float4 positionOS:POSITION;};
   struct Varyings {float4 positionCS:SV_POSITION;float3 world:TEXCOORD0;};
   Varyings vert(Attributes v){Varyings o;o.world=TransformObjectToWorld(v.positionOS.xyz);o.positionCS=TransformWorldToHClip(o.world);return o;}
   half4 frag(Varyings i):SV_Target{float2 beyond=max(abs(i.world.xz)-_HalfSize.xy,0);float lit=1-smoothstep(0,8,length(beyond));return half4(lerp(_Night.rgb,SAMPLE_TEXTURE2D(_BaseMap,sampler_BaseMap,i.world.xz/2.6).rgb*.22,lit),1);}
   ENDHLSL
  }
 }
}
