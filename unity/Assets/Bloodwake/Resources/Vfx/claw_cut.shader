Shader "Bloodwake/Vfx/claw_cut"
{
 Properties {_Tone("Tone",Color)=(.7,.02,.06,1) _Progress("Progress",Float)=0 _Seed("Seed",Float)=0}
 SubShader {Tags {"RenderPipeline"="UniversalPipeline" "Queue"="Transparent" "RenderType"="Transparent"}
 Pass {ZWrite Off Cull Off Blend SrcAlpha OneMinusSrcAlpha
 HLSLPROGRAM
 #pragma vertex vert
 #pragma fragment frag
 #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
 struct A{float4 positionOS:POSITION;float2 uv:TEXCOORD0;};
 struct V{float4 positionCS:SV_POSITION;float2 uv:TEXCOORD0;};
 CBUFFER_START(UnityPerMaterial)
 float4 _Tone;float _Progress,_Seed;
 CBUFFER_END
 V vert(A v){V o;o.positionCS=TransformObjectToHClip(v.positionOS.xyz);o.uv=v.uv;return o;}
 half4 frag(V i):SV_Target
 {
  float y=i.uv.y,x=abs(i.uv.x-.5);
  float taper=pow(saturate(sin(y*3.14159)),.8);
  float width=taper*(.065+.015*sin(y*71+_Seed)+.012*sin(y*133));
  float cut=1-smoothstep(width*.35,width+.055,x);
  float mist=(1-smoothstep(width,width+.23,x))*.19;
  float ends=smoothstep(0,.08,y)*(1-smoothstep(.88,1,y));
  float fade=1-smoothstep(.12,1,_Progress);
  float reveal=1-smoothstep(saturate(_Progress*14),saturate(_Progress*14)+.12,y);
  float core=1-smoothstep(0,width*.6+.005,x);
  return half4(lerp(_Tone.rgb*.45,_Tone.rgb*1.35,core),(cut+mist)*ends*fade*reveal*_Tone.a);
 }
 ENDHLSL
 }}
}
