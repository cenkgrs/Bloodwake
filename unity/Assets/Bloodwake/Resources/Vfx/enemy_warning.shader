Shader "Bloodwake/Vfx/enemy_warning"
{
 Properties {_Tone("Tone",Color)=(1,.4,.2,1) _Progress("Progress",Float)=0 _Arc("Half arc",Float)=3.141593 _Lane("Lane",Float)=0}
 SubShader {Tags {"RenderPipeline"="UniversalPipeline" "Queue"="Transparent" "RenderType"="Transparent"}
 Pass {ZWrite Off Cull Off Blend SrcAlpha OneMinusSrcAlpha
 HLSLPROGRAM
 #pragma vertex vert
 #pragma fragment frag
 #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
 CBUFFER_START(UnityPerMaterial)
 float4 _Tone;float _Progress,_Arc,_Lane;
 CBUFFER_END
 struct A{float4 pos:POSITION;float2 uv:TEXCOORD0;};struct V{float4 pos:SV_POSITION;float2 uv:TEXCOORD0;};
 V vert(A v){V o;o.pos=TransformObjectToHClip(v.pos.xyz);o.uv=v.uv;return o;}
 half4 frag(V i):SV_Target
 {
  float2 p=i.uv*2-1;float r=length(p),angle=abs(atan2(p.x,p.y));float inside,edge,travel;
  if(_Lane>.5){inside=1;edge=smoothstep(.93,.99,max(abs(p.x),abs(p.y)));travel=i.uv.y;}
  else{float aa=max(fwidth(r),.002);inside=(1-smoothstep(1-aa,1+aa,r))*(_Arc>3.13?1:1-smoothstep(_Arc-.012,_Arc+.012,angle));edge=smoothstep(.965,1,r);if(_Arc<3.13)edge=max(edge,1-smoothstep(.0,.025,abs(angle-_Arc)*max(r,.1)));travel=r;}
  float progress=saturate(_Progress),front=1-smoothstep(.012,.045,abs(travel-progress));
  float hatch=pow(saturate(sin((p.x+p.y)*42)),12)*.035;
  float alpha=inside*(.09+progress*.1+hatch+edge*.58+front*.2);
  return half4(_Tone.rgb*(.7+edge*.5+front*.25),saturate(alpha)*_Tone.a);
 }
 ENDHLSL
 }}}
