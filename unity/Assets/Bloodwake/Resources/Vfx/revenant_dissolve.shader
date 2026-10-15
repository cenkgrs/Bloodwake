// Source: godot/shaders/revenant_dissolve.gdshader.
Shader "Bloodwake/Vfx/revenant_dissolve"
{
 Properties {_BaseMap("Body texture",2D)="white"{} _BaseColor("Body tone",Color)=(1,1,1,1) _Progress("Progress",Range(0,1))=0}
 SubShader {Tags {"RenderPipeline"="UniversalPipeline" "Queue"="AlphaTest" "RenderType"="TransparentCutout"}
 Pass {Tags {"LightMode"="UniversalForward"} Cull Off
 HLSLPROGRAM
 #pragma vertex vert
 #pragma fragment frag
 #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE
 #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
 #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
 TEXTURE2D(_BaseMap);SAMPLER(sampler_BaseMap);
 CBUFFER_START(UnityPerMaterial)
 float4 _BaseColor;float4 _BaseMap_ST;float _Progress;
 CBUFFER_END
 struct A {float4 pos:POSITION;float3 normal:NORMAL;float2 uv:TEXCOORD0;};
 struct V {float4 pos:SV_POSITION;float3 local:TEXCOORD0;float3 world:TEXCOORD1;float3 normal:TEXCOORD2;float2 uv:TEXCOORD3;};
 V vert(A v){V o;o.local=v.pos.xyz;o.world=TransformObjectToWorld(v.pos.xyz);o.pos=TransformWorldToHClip(o.world);o.normal=TransformObjectToWorldNormal(v.normal);o.uv=TRANSFORM_TEX(v.uv,_BaseMap);return o;}
 half4 frag(V i):SV_Target
 {
  half4 skin=SAMPLE_TEXTURE2D(_BaseMap,sampler_BaseMap,i.uv)*_BaseColor;
  float grain=frac(sin(dot(floor(i.local*28),float3(17.13,63.71,29.31)))*43758.5453);
  clip(skin.a*step(_Progress,grain)*(1-step(.999,_Progress))-.5);
  float edge=smoothstep(_Progress,_Progress+.055,grain);float burn=(1-edge)*step(_Progress,grain)*step(.001,_Progress);
  Light light=GetMainLight(TransformWorldToShadowCoord(i.world));float3 n=normalize(i.normal);
  float3 lighting=SampleSH(n)+light.color*saturate(dot(n,light.direction))*light.shadowAttenuation;
  return half4(skin.rgb*(1-burn*.7)*lighting+float3(.8,.003,.025)*burn*2,1);
 }
 ENDHLSL
 }}
}
