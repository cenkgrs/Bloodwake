Shader "Bloodwake/Vfx/frost_ground"
{
 Properties {_Tone("Tone",Color)=(.55,.7,1,1) _Progress("Progress",Float)=0}
 SubShader {Tags {"RenderPipeline"="UniversalPipeline" "Queue"="Transparent" "RenderType"="Transparent"}
 Pass {ZWrite Off Cull Off Blend SrcAlpha OneMinusSrcAlpha
 HLSLPROGRAM
 #pragma vertex vert
 #pragma fragment frag
 #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
 struct A{float4 p:POSITION;float2 uv:TEXCOORD0;};struct V{float4 p:SV_POSITION;float2 uv:TEXCOORD0;};
 float4 _Tone;float _Progress;
 V vert(A a){V o;o.p=TransformObjectToHClip(a.p.xyz);o.uv=a.uv;return o;}
 float2 hash(float2 p){return frac(sin(float2(dot(p,float2(127.1,311.7)),dot(p,float2(269.5,183.3))))*43758.5453);}
 float fissure(float2 p){float2 cell=floor(p),f=frac(p);float a=8,b=8;
 for(int x=-1;x<=1;x++)for(int y=-1;y<=1;y++){float2 k=float2(x,y);float d=length(k+hash(cell+k)-f);if(d<a){b=a;a=d;}else b=min(b,d);}return b-a;}
 half4 frag(V i):SV_Target
 {
  float2 p=i.uv*2-1;float r=length(p);float pulse=saturate(_Progress*6);
  float boundary=1-smoothstep(.82,1,r);float reveal=1-smoothstep(pulse-.06,pulse+.03,r);
  float cell=fissure(p*5.3+2.7);float fine=fissure(p*17.8);
  float vein=(1-smoothstep(.006,.028,cell));float frost=(1-smoothstep(.06,.16,cell))*.2+(1-smoothstep(.003,.06,fine))*.15;
  float fall=1-smoothstep(.34,1,_Progress);float wave=exp(-pow((r-pulse)*22,2))*(1-pulse);
  float alpha=(vein*.7+frost+wave*.5)*boundary*reveal*fall;
  float3 col=lerp(float3(.23,.34,.56),float3(.7,.9,1.6),vein)+wave;
  return half4(col*_Tone.rgb,alpha*_Tone.a);
 }
 ENDHLSL
 }}
}
