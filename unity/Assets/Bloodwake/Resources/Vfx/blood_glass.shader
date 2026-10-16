Shader "Bloodwake/Vfx/blood_glass"
{
 Properties {_Tone("Blood",Color)=(.55,.008,.025,1) _Progress("Progress",Float)=0}
 SubShader {Tags {"RenderPipeline"="UniversalPipeline" "Queue"="Transparent" "RenderType"="Transparent"}
 Pass {Tags {"LightMode"="UniversalForward"} ZWrite Off Cull Back Blend SrcAlpha OneMinusSrcAlpha
 HLSLPROGRAM
 #pragma vertex vert
 #pragma fragment frag
 #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
 CBUFFER_START(UnityPerMaterial)
 float4 _Tone;float _Progress;
 CBUFFER_END
 struct A{float4 pos:POSITION;float3 normal:NORMAL;};
 struct V{float4 pos:SV_POSITION;float3 world:TEXCOORD0;float3 normal:TEXCOORD1;};
 V vert(A v){V o;o.pos=TransformObjectToHClip(v.pos.xyz);o.world=TransformObjectToWorld(v.pos.xyz);o.normal=TransformObjectToWorldNormal(v.normal);return o;}
 half4 frag(V i):SV_Target
 {
  float3 n=normalize(i.normal),view=normalize(GetWorldSpaceViewDir(i.world));Light light=GetMainLight();
  float facing=saturate(abs(dot(n,view))),rim=pow(1-facing,3);
  float spec=pow(saturate(dot(n,normalize(light.direction+view))),72);
  float glint=pow(saturate(dot(n,normalize(float3(-.5,1,-.3)+view))),95);
  float3 body=_Tone.rgb*(.58+.42*saturate(dot(n,light.direction)));
  // Ruby transmission, dark inner faces, bright chipped edges. No emissive neon sticks.
  float3 color=body+float3(.85,.13,.20)*rim*.55+float3(1,.69,.7)*(spec*.65+glint*.4);
  float fade=1-smoothstep(.62,1,_Progress);
  return half4(color,lerp(.60,.91,rim)*fade*_Tone.a);
 }
 ENDHLSL
 }}
}
