Shader "Bloodwake/Vfx/dash_trace"
{
 Properties {_Tone("Tone",Color)=(.4,.01,.025,1) _Progress("Progress",Float)=0 _Clock("Clock",Float)=0 _Seed("Seed",Float)=0}
 SubShader {Tags {"RenderPipeline"="UniversalPipeline" "Queue"="Transparent" "RenderType"="Transparent"}
 Pass {ZWrite Off Cull Off Blend SrcAlpha OneMinusSrcAlpha
 HLSLPROGRAM
 #pragma vertex vert
 #pragma fragment frag
 #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
 struct A{float4 positionOS:POSITION;float2 uv:TEXCOORD0;};struct V{float4 positionCS:SV_POSITION;float2 uv:TEXCOORD0;};
 CBUFFER_START(UnityPerMaterial)
 float4 _Tone;float _Progress,_Clock,_Seed;
 CBUFFER_END
 V vert(A v){V o;o.positionCS=TransformObjectToHClip(v.positionOS.xyz);o.uv=v.uv;return o;}
 float hash(float2 p){return frac(sin(dot(p,float2(127.1,311.7)))*43758.5453);}
 float noise(float2 p){float2 a=floor(p),f=frac(p);f=f*f*(3-2*f);return lerp(lerp(hash(a),hash(a+float2(1,0)),f.x),lerp(hash(a+float2(0,1)),hash(a+1),f.x),f.y);}
 half4 frag(V i):SV_Target
 {
  float2 p=i.uv*2-1;float n=noise(i.uv*float2(13,5)+_Seed);
  float width=abs(p.x+sin(p.y*7+_Seed)*.08);
  float veil=(1-smoothstep(.18,.94,width))*(.12+n*.22);
  float lines=pow(saturate(1-abs(sin((p.x+n*.08)*17+p.y*.7))),14);
  float edge=(1-smoothstep(.5,1,abs(p.y)))*(1-smoothstep(.4,.92,width));
  float fade=1-smoothstep(.68,1,_Progress);
  return half4(_Tone.rgb*(.55+lines*.65),(veil+lines*.7)*edge*fade);
 }
 ENDHLSL
 }}
}
