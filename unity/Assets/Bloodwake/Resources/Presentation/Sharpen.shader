// Contrast-adaptive sharpening (after AMD CAS) run after post-processing, before the UI.
// Restores the texture detail that MSAA resolve, mip filtering and macOS display scaling soften.
Shader "Bloodwake/Sharpen"
{
 Properties{_Sharpness("Sharpness",Range(0,1))=.6}
 SubShader
 {
  Tags{"RenderPipeline"="UniversalPipeline"}
  ZWrite Off ZTest Always Cull Off Blend Off
  Pass
  {
   Name "Sharpen"
   HLSLPROGRAM
   #pragma vertex Vert
   #pragma fragment Frag
   #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
   #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
   float _Sharpness;
   half3 Tap(float2 uv){return SAMPLE_TEXTURE2D_X(_BlitTexture,sampler_PointClamp,uv).rgb;}
   half4 Frag(Varyings input):SV_Target
   {
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
    float2 uv=input.texcoord;float2 t=_BlitTexture_TexelSize.xy;
    half3 a=Tap(uv+float2(0,-t.y)),b=Tap(uv+float2(-t.x,0)),c=Tap(uv),d=Tap(uv+float2(t.x,0)),e=Tap(uv+float2(0,t.y));
    half3 lo=min(c,min(min(a,b),min(d,e))),hi=max(c,max(max(a,b),max(d,e)));
    // Less sharpening where local contrast is already high, so edges do not ring.
    half3 amp=sqrt(saturate(min(lo,2-hi)/max(hi,1e-4)));
    half3 w=-amp*lerp(.125,.2,_Sharpness);
    half3 result=saturate((c+(a+b+d+e)*w)/(1+4*w));
    return half4(result,1);
   }
   ENDHLSL
  }
 }
}
