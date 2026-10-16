Shader "Bloodwake/Vfx/spawn_rift"
{
 Properties {_Tone("Rim color",Color)=(.7,.06,.12,1) _Progress("Progress",Float)=0 _Clock("Clock",Float)=0}
 SubShader {Tags {"RenderPipeline"="UniversalPipeline" "Queue"="Transparent-10" "RenderType"="Transparent"}
 Pass {ZWrite Off Cull Off Blend SrcAlpha OneMinusSrcAlpha Offset -1,-1
 HLSLPROGRAM
 #pragma vertex vert
 #pragma fragment frag
 #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
 struct A{float4 positionOS:POSITION;float2 uv:TEXCOORD0;};
 struct V{float4 positionCS:SV_POSITION;float2 uv:TEXCOORD0;};
 CBUFFER_START(UnityPerMaterial)
 float4 _Tone;float _Progress,_Clock;
 CBUFFER_END
 V vert(A v){V o;o.positionCS=TransformObjectToHClip(v.positionOS.xyz);o.uv=v.uv;return o;}
 float hash(float2 p){return frac(sin(dot(p,float2(127.1,311.7)))*43758.5453);}
 float noise(float2 p){float2 a=floor(p),f=frac(p);f=f*f*(3-2*f);return lerp(lerp(hash(a),hash(a+float2(1,0)),f.x),lerp(hash(a+float2(0,1)),hash(a+1),f.x),f.y);}
 half4 frag(V i):SV_Target
 {
  float opening=smoothstep(0,.15,_Progress)*(1-smoothstep(.64,1,_Progress));
  float2 p=(i.uv*2-1)/max(.025,opening);float radius=length(p);
  float cloud=noise(p*3.2+float2(_Clock*.12,-_Clock*.18))*.65+noise(p*6.7-_Clock*.13)*.35;
  // Wide feathered depression, no bright contour or noisy polygon-like outline.
  float pit=1-smoothstep(.18,.84,radius+(cloud-.5)*.08);
  float haze=exp(-pow((radius-.50)/.30,2))*(.42+cloud*.58);
  float fringe=(1-smoothstep(.72,.98,radius));
  float3 color=float3(.009,.003,.008)+_Tone.rgb*haze*.24;
  float alpha=saturate(pit*.88+haze*.24)*fringe*smoothstep(0,.04,_Progress)*(1-smoothstep(.94,1,_Progress));
  return half4(color,alpha);
 }
 ENDHLSL
 }}
}
