// Additive card for the delivered VFX sheets (painted on black, so black adds nothing).
// _Grid x _Grid cells: _Frames > 0 plays them over _Progress (blending neighbours), otherwise _Cell is shown.
// Fades in over the first moment and out over the last 30% of the card's life; _Opacity is the caller's own fade.
Shader "Bloodwake/Vfx/vfx_tex_add"
{
 Properties { _MainTex("Sheet",2D)="black"{} [HDR]_Tone("Tone",Color)=(1,1,1,1) _Progress("Progress",Float)=0 _Grid("Grid",Float)=1 _Frames("Frames",Float)=0 _Cell("Cell",Float)=0 _Opacity("Opacity",Float)=1 }
 SubShader
 {
  Tags { "RenderPipeline"="UniversalPipeline" "Queue"="Transparent" "RenderType"="Transparent" "IgnoreProjector"="True" }
  Pass
  {
   Blend One One ZWrite Off Cull Off
   HLSLPROGRAM
   #pragma vertex vert
   #pragma fragment frag
   #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
   TEXTURE2D(_MainTex);SAMPLER(sampler_MainTex);
   CBUFFER_START(UnityPerMaterial) float4 _MainTex_ST;float4 _Tone;float _Progress,_Grid,_Frames,_Cell,_Opacity; CBUFFER_END
   struct A{float4 p:POSITION;float2 uv:TEXCOORD0;};struct V{float4 p:SV_POSITION;float2 uv:TEXCOORD0;};
   V vert(A a){V o;o.p=TransformObjectToHClip(a.p.xyz);o.uv=a.uv;return o;}
   float2 CellUv(float cell,float2 uv){float g=max(1,_Grid);cell=clamp(cell,0,g*g-1);float col=fmod(cell,g),row=g-1-floor(cell/g);return (float2(col,row)+uv)/g;}
   float3 Sample(float cell,float2 uv){return SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,_Grid>1?CellUv(cell,saturate(uv)):uv).rgb;}
   half4 frag(V i):SV_Target
   {
    float3 c;
    if(_Frames>0){float t=saturate(_Progress)*(_Frames-1),f=floor(t);c=lerp(Sample(f,i.uv),Sample(min(f+1,_Frames-1),i.uv),t-f);}
    else c=Sample(_Cell,i.uv);
    float fade=smoothstep(0,.06,_Progress)*(1-smoothstep(.7,1,_Progress));
    return half4(c*_Tone.rgb*_Tone.a*_Opacity*fade,0);
   }
   ENDHLSL
  }
 }
}
