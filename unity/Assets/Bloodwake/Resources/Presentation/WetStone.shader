Shader "Bloodwake/Presentation/WetStone"
{
 Properties { _BaseMap("Stone",2D)="white"{} _BumpMap("Normal",2D)="bump"{} _ARM("AO Rough Metal",2D)="white"{} _Scale("Repeats per metre",Float)=.4 _Wetness("Wetness",Range(0,1))=.65 _Weathering("Surface variation",Range(0,1))=1 }
 SubShader
 {
  Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" }
  Pass
  {
   Tags { "LightMode"="UniversalForwardOnly" }
   HLSLPROGRAM
   #pragma vertex vert
   #pragma fragment frag
   #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
   #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
   #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
   #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
   #pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION
   #pragma multi_compile_fragment _ _REFLECTION_PROBE_ATLAS
   #pragma multi_compile_fragment _ _SHADOWS_SOFT _SHADOWS_SOFT_LOW _SHADOWS_SOFT_MEDIUM _SHADOWS_SOFT_HIGH
   #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
   #pragma multi_compile_fragment _ _LIGHT_LAYERS
   #pragma multi_compile _ _CLUSTER_LIGHT_LOOP
   #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
   #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
   TEXTURE2D(_BaseMap);SAMPLER(sampler_BaseMap);
   TEXTURE2D(_BumpMap);SAMPLER(sampler_BumpMap);
   TEXTURE2D(_ARM);SAMPLER(sampler_ARM);
   CBUFFER_START(UnityPerMaterial)
   float _Scale,_Wetness,_Weathering;
   CBUFFER_END
   struct A { float4 position:POSITION; };
   struct V { float4 position:SV_POSITION;float3 world:TEXCOORD0; };
   V vert(A i){V o;o.world=TransformObjectToWorld(i.position.xyz);o.position=TransformWorldToHClip(o.world);return o;}
   float hash(float2 p){return frac(sin(dot(p,float2(127.1,311.7)))*43758.5453);}
   float dampNoise(float2 p){float2 cell=floor(p),f=frac(p);f=f*f*(3-2*f);return lerp(lerp(hash(cell),hash(cell+float2(1,0)),f.x),lerp(hash(cell+float2(0,1)),hash(cell+1),f.x),f.y);}
   half4 frag(V i):SV_Target
   {
    float2 uv=i.world.xz*_Scale;
    half3 albedo=SAMPLE_TEXTURE2D(_BaseMap,sampler_BaseMap,uv).rgb;
    half3 arm=SAMPLE_TEXTURE2D(_ARM,sampler_ARM,uv).rgb;
    half3 n=UnpackNormal(SAMPLE_TEXTURE2D(_BumpMap,sampler_BumpMap,uv));
    // Broad irregular damp patches vary the reflection without erasing mortar.
    float patch=dampNoise(i.world.xz*.19)*.65+dampNoise(i.world.xz*.49+17)*.35;
    float wet=_Wetness*smoothstep(.32,.74,patch);
    // Low-frequency mineral and dirt variation breaks the texture repeat.
    float mineral=dampNoise(i.world.xz*.31+43);
    float grit=dampNoise(i.world.xz*1.7+8);
    float soil=smoothstep(.48,.79,dampNoise(i.world.xz*.24-11));
    half3 tint=lerp(half3(.76,.82,.87),half3(1.13,1.06,.94),mineral);
    albedo*=lerp(half3(1,1,1),tint*lerp(1,.64,soil),_Weathering);
    // Shallow water smooths the stone relief; dry patches retain the source normal.
    n.xy*=lerp(1,lerp(1,.28,smoothstep(.22,.60,wet)),_Weathering);n=normalize(n);
    SurfaceData surface=(SurfaceData)0;
    surface.albedo=albedo*lerp(lerp(.24,.33,_Weathering),lerp(.1,.14,_Weathering),wet);surface.alpha=1;surface.metallic=0;
    surface.smoothness=lerp(clamp(1-arm.g,.15,.5),.94,wet);surface.smoothness=lerp(surface.smoothness,lerp(surface.smoothness,.22,soil*.65)+(.5-grit)*.07,_Weathering);surface.occlusion=lerp(.5,1,arm.r);surface.normalTS=half3(0,0,1);
    InputData input=(InputData)0;input.positionWS=i.world;input.normalWS=normalize(half3(n.x,n.z,n.y));
    input.viewDirectionWS=GetWorldSpaceNormalizeViewDir(i.world);input.shadowCoord=TransformWorldToShadowCoord(i.world);
    input.bakedGI=SampleSH(input.normalWS);input.normalizedScreenSpaceUV=GetNormalizedScreenSpaceUV(i.position);input.shadowMask=half4(1,1,1,1);
    return UniversalFragmentPBR(input,surface);
   }
   ENDHLSL
  }
  Pass
  {
   Tags { "LightMode"="DepthOnly" }
   ZWrite On ColorMask R
   HLSLPROGRAM
   #pragma vertex vert
   #pragma fragment frag
   #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
   float4 vert(float4 p:POSITION):SV_POSITION{return TransformObjectToHClip(p.xyz);}
   half4 frag():SV_Target{return 0;}
   ENDHLSL
  }
  Pass
  {
   Tags { "LightMode"="DepthNormalsOnly" }
   ZWrite On
   HLSLPROGRAM
   #pragma vertex vert
   #pragma fragment frag
   #pragma multi_compile_fragment _ _GBUFFER_NORMALS_OCT
   #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
   TEXTURE2D(_BumpMap);SAMPLER(sampler_BumpMap);
   CBUFFER_START(UnityPerMaterial)
   float _Scale,_Wetness,_Weathering;
   CBUFFER_END
   float hash(float2 p){return frac(sin(dot(p,float2(127.1,311.7)))*43758.5453);}
   float dampNoise(float2 p){float2 cell=floor(p),f=frac(p);f=f*f*(3-2*f);return lerp(lerp(hash(cell),hash(cell+float2(1,0)),f.x),lerp(hash(cell+float2(0,1)),hash(cell+1),f.x),f.y);}
   struct A{float4 p:POSITION;};struct V{float4 p:SV_POSITION;float3 world:TEXCOORD0;};
   V vert(A a){V o;o.world=TransformObjectToWorld(a.p.xyz);o.p=TransformWorldToHClip(o.world);return o;}
   half4 frag(V i):SV_Target
   {
    half3 n=UnpackNormal(SAMPLE_TEXTURE2D(_BumpMap,sampler_BumpMap,i.world.xz*_Scale));
    float patch=dampNoise(i.world.xz*.19)*.65+dampNoise(i.world.xz*.49+17)*.35;
    float wet=_Wetness*smoothstep(.32,.74,patch);
    n.xy*=lerp(1,lerp(1,.28,smoothstep(.22,.60,wet)),_Weathering);n=normalize(n).xzy;
    #if defined(_GBUFFER_NORMALS_OCT)
     float2 oct=PackNormalOctQuadEncode(normalize(n));return half4(PackFloat2To888(saturate(oct*.5+.5)),0);
    #else
     return half4(normalize(n),0);
    #endif
   }
   ENDHLSL
  }
 }
}
