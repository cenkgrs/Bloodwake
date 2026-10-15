Shader "Bloodwake/Vfx/dust"
{
 Properties {_Tone("Tone",Color)=(1,0,0,1) _Progress("Progress",Float)=0 _Energy("Energy",Float)=1}
 SubShader {Tags {"RenderPipeline"="UniversalPipeline" "Queue"="Transparent" "RenderType"="Transparent"}
 Pass {ZWrite Off Cull Off Blend SrcAlpha OneMinusSrcAlpha
 HLSLPROGRAM
 #pragma vertex vert
 #pragma fragment frag
 #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
 struct A{float4 positionOS:POSITION;float2 uv:TEXCOORD0;};struct V{float4 positionCS:SV_POSITION;float2 uv:TEXCOORD0;};
 CBUFFER_START(UnityPerMaterial)
 float4 _Tone;float _Progress,_Energy;
 CBUFFER_END
 V vert(A v){V o;o.positionCS=TransformObjectToHClip(v.positionOS.xyz);o.uv=v.uv;return o;}
 float hash(float2 p){return frac(sin(dot(p,float2(127.1,311.7)))*43758.5453);}
 float noise(float2 p){float2 a=floor(p),f=frac(p);f=f*f*(3-2*f);return lerp(lerp(hash(a),hash(a+float2(1,0)),f.x),lerp(hash(a+float2(0,1)),hash(a+1),f.x),f.y);}
 half4 frag(V i):SV_Target
 {
  float2 p=i.uv*2-1;float r=length(p);float2 flow=i.uv*5+float2(_Progress*.6,-_Progress*1.5);
  float turbulence=noise(flow)*.55+noise(flow*2.1)*.3+noise(flow*4.3)*.15;
  float alpha=smoothstep(1,.2,r)*smoothstep(.2,.68,turbulence)*_Tone.a*(1-_Progress);
  return half4(_Tone.rgb*_Energy*(.75+turbulence*.35),alpha);
 }
 ENDHLSL
 }}
}
