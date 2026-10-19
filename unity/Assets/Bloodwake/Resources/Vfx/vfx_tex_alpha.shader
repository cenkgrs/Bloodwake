// Alpha-blended card for the delivered blood sheets. They are painted on black, and dark blood would vanish
// under additive blending, so coverage comes from the brightest channel and the colour is divided by it
// (the sheet read as colour x coverage over black): no dark fringe, and the blood keeps its own depth.
// Same cell/frame/fade rules as vfx_tex_add.
Shader "Bloodwake/Vfx/vfx_tex_alpha"
{
 Properties { _MainTex("Sheet",2D)="black"{} _Tone("Tone",Color)=(1,1,1,1) _Progress("Progress",Float)=0 _Grid("Grid",Float)=1 _Frames("Frames",Float)=0 _Cell("Cell",Float)=0 _Opacity("Opacity",Float)=1 _Gain("Coverage gain",Float)=2.2 }
 SubShader
 {
  Tags { "RenderPipeline"="UniversalPipeline" "Queue"="Transparent" "RenderType"="Transparent" "IgnoreProjector"="True" }
  Pass
  {
   Blend SrcAlpha OneMinusSrcAlpha ZWrite Off Cull Off
   HLSLPROGRAM
   #pragma vertex vert
   #pragma fragment frag
   #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
   TEXTURE2D(_MainTex);SAMPLER(sampler_MainTex);
   CBUFFER_START(UnityPerMaterial) float4 _MainTex_ST;float4 _Tone;float _Progress,_Grid,_Frames,_Cell,_Opacity,_Gain; CBUFFER_END
   struct A{float4 p:POSITION;float2 uv:TEXCOORD0;};struct V{float4 p:SV_POSITION;float2 uv:TEXCOORD0;};
   V vert(A a){V o;o.p=TransformObjectToHClip(a.p.xyz);o.uv=a.uv;return o;}
   float2 CellUv(float cell,float2 uv){float g=max(1,_Grid);cell=clamp(cell,0,g*g-1);float col=fmod(cell,g),row=g-1-floor(cell/g);return (float2(col,row)+uv)/g;}
   float3 Sample(float cell,float2 uv){return SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,_Grid>1?CellUv(cell,saturate(uv)):uv).rgb;}
   half4 frag(V i):SV_Target
   {
    float3 c;
    if(_Frames>0){float t=saturate(_Progress)*(_Frames-1),f=floor(t);c=lerp(Sample(f,i.uv),Sample(min(f+1,_Frames-1),i.uv),t-f);}
    else c=Sample(_Cell,i.uv);
    float peak=max(c.r,max(c.g,c.b)),cover=saturate(peak*_Gain);
    float fade=smoothstep(0,.06,_Progress)*(1-smoothstep(.7,1,_Progress));
    return half4(c/max(cover,.02)*_Tone.rgb,cover*_Tone.a*_Opacity*fade);
   }
   ENDHLSL
  }
 }
}
