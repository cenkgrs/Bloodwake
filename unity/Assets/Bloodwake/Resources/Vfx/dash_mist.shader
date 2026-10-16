Shader "Bloodwake/Vfx/dash_mist"
{
 Properties {_Tone("Tone",Color)=(.37,.012,.032,.78) _Clock("Clock",Float)=0 _Seed("Seed",Float)=0 _Opacity("Opacity",Float)=1}
 SubShader {Tags {"RenderPipeline"="UniversalPipeline" "Queue"="Transparent" "RenderType"="Transparent"}
 Pass {ZWrite Off Cull Off Blend SrcAlpha OneMinusSrcAlpha
 HLSLPROGRAM
 #pragma vertex vert
 #pragma fragment frag
 #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
 struct A{float4 positionOS:POSITION;float2 uv:TEXCOORD0;};struct V{float4 positionCS:SV_POSITION;float2 uv:TEXCOORD0;};
 CBUFFER_START(UnityPerMaterial)
 float4 _Tone;float _Clock,_Seed,_Opacity;
 CBUFFER_END
 V vert(A v){V o;o.positionCS=TransformObjectToHClip(v.positionOS.xyz);o.uv=v.uv;return o;}
 float hash(float2 p){return frac(sin(dot(p,float2(127.1,311.7)))*43758.5453);}
 float noise(float2 p){float2 a=floor(p),f=frac(p);f=f*f*(3-2*f);return lerp(lerp(hash(a),hash(a+float2(1,0)),f.x),lerp(hash(a+float2(0,1)),hash(a+1),f.x),f.y);}
 float fbm(float2 p){return noise(p)*.57+noise(p*2.03+7)*.28+noise(p*4.11+13)*.15;}
 half4 frag(V i):SV_Target
 {
  float2 p=i.uv*2-1;
  float2 flow=i.uv*float2(6,2.8)+float2(_Seed,-_Clock*1.8);
  float2 warp=float2(fbm(flow+3),fbm(flow+19))-.5;
  float n=fbm(flow+warp*2.2);
  float edge=1-smoothstep(.26,.97,length(p+warp*.28));
  // Torn blood wisps threaded through a softer veil, not a uniform smoke blob.
  float veins=pow(saturate(1-abs(sin((i.uv.x+warp.x*.28)*27+i.uv.y*8-_Clock*7+_Seed))),5);
  float density=smoothstep(.3,.74,n)*.72+veins*smoothstep(.25,.65,n)*.33;
  float alpha=edge*density*_Tone.a*_Opacity;
  return half4(_Tone.rgb*(lerp(.34,1.3,n)+veins*.55),alpha);
 }
 ENDHLSL
 }}
}
