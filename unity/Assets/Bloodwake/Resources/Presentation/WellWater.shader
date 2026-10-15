Shader "Bloodwake/Presentation/WellWater"
{
 Properties {_DeepColor("Deep water",Color)=(.012,.055,.072,1) _ShallowColor("Reflected water",Color)=(.09,.24,.29,1) _RippleScale("Ripple scale",Float)=1}
 SubShader
 {
  Tags {"RenderType"="Opaque" "RenderPipeline"="UniversalPipeline"}
  Pass
  {
   Tags {"LightMode"="UniversalForwardOnly"}
   Cull Back ZWrite On
   HLSLPROGRAM
   #pragma vertex vert
   #pragma fragment frag
   #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
   #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
   #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
   #pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION
   #pragma multi_compile_fragment _ _REFLECTION_PROBE_ATLAS
   #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
   #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
   CBUFFER_START(UnityPerMaterial)
   half4 _DeepColor,_ShallowColor;float _RippleScale;
   CBUFFER_END
   struct A {float4 position:POSITION;float2 uv:TEXCOORD0;};
   struct V {float4 position:SV_POSITION;float3 world:TEXCOORD0;float2 uv:TEXCOORD1;};
   V vert(A i){V o;o.world=TransformObjectToWorld(i.position.xyz);o.position=TransformWorldToHClip(o.world);o.uv=i.uv;return o;}
   half4 frag(V i):SV_Target
   {
    float2 p=(i.uv-.5)*2;float time=_Time.y;
    float2 gradient=float2(
     cos(p.x*13+p.y*5+time*.55)*.045+cos(p.x*23-p.y*9-time*.31)*.018,
     cos(p.y*15-p.x*4-time*.47)*.04+cos(p.y*27+p.x*7+time*.28)*.015)*_RippleScale;
    half3 normalWS=normalize(half3(gradient.x,1,gradient.y));half3 view=GetWorldSpaceNormalizeViewDir(i.world);
    float fresnel=pow(1-saturate(dot(normalWS,view)),3);float shimmer=saturate(sin((p.x+p.y)*24+time*.7)*.5+.5)*.035;
    SurfaceData surface=(SurfaceData)0;surface.albedo=lerp(_DeepColor.rgb,_ShallowColor.rgb,.18+fresnel*.52);surface.alpha=1;surface.metallic=.03;surface.smoothness=.93;surface.occlusion=1;surface.normalTS=half3(0,0,1);surface.emission=_ShallowColor.rgb*(.025+shimmer);
    InputData input=(InputData)0;input.positionWS=i.world;input.normalWS=normalWS;input.viewDirectionWS=view;input.shadowCoord=TransformWorldToShadowCoord(i.world);input.bakedGI=SampleSH(normalWS);input.normalizedScreenSpaceUV=GetNormalizedScreenSpaceUV(i.position);input.shadowMask=half4(1,1,1,1);
    return UniversalFragmentPBR(input,surface);
   }
   ENDHLSL
  }
 }
}
