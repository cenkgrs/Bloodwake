Shader "Bloodwake/Vfx/arcane_energy"
{
 // _MainTex is the delivered arcane noise (arcane_energy_map); it streams along the band when _MapAmount is 1.
 Properties{_Tone("Tone",Color)=(1,1,1,1) _Opacity("Opacity",Float)=1 _MainTex("Noise",2D)="white"{} _MapAmount("Noise amount",Float)=0}
 SubShader { Tags {"RenderPipeline"="UniversalPipeline" "Queue"="Transparent" "RenderType"="Transparent"}
 Pass { Blend SrcAlpha One ZWrite Off Cull Off
 HLSLPROGRAM
 #pragma vertex vert
 #pragma fragment frag
 #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
 TEXTURE2D(_MainTex);SAMPLER(sampler_MainTex);
 float4 _Tone;float _Opacity,_MapAmount;
 struct A{float4 p:POSITION;float2 uv:TEXCOORD0;};struct V{float4 p:SV_POSITION;float2 uv:TEXCOORD0;};
 V vert(A a){V o;o.p=TransformObjectToHClip(a.p.xyz);o.uv=a.uv;return o;}
 half4 frag(V i):SV_Target
 {
  float band=pow(saturate(1-abs(i.uv.y*2-1)),.7);
  // Filaments crawl along the band; bright threads lift above the base tone, the gaps between them dim.
  float3 n=SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,float2(i.uv.x*1.5-_Time.y*.45,i.uv.y*.35+_Time.y*.08)).rgb;
  float lum=max(n.r,max(n.g,n.b)),energy=lerp(1,.35+1.9*lum,_MapAmount);
  return half4(_Tone.rgb*lerp(1,.75+.5*lum,_MapAmount),saturate(_Tone.a*_Opacity*band*energy));
 }
 ENDHLSL
 }}
}
