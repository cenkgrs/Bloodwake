// Additive 4x4 flame flipbook for Vesper's blade. Each card blends between neighbouring
// frames so 16 painted frames read as continuous fire; _Offset desynchronises cards.
Shader "Bloodwake/VesperFlameFlipbook"
{
 Properties { _MainTex("Flipbook",2D)="black"{} [HDR]_Tint("Tint",Color)=(1,1,1,1) _Fps("Frames per second",Float)=16 _Offset("Frame offset",Float)=0 _Intensity("Intensity",Float)=1.5 }
 SubShader
 {
  Tags { "RenderType"="Transparent" "Queue"="Transparent" "RenderPipeline"="UniversalPipeline" "IgnoreProjector"="True" }
  Pass
  {
   Blend One One ZWrite Off Cull Off
   HLSLPROGRAM
   #pragma vertex vert
   #pragma fragment frag
   #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
   TEXTURE2D(_MainTex);SAMPLER(sampler_MainTex);
   CBUFFER_START(UnityPerMaterial) float4 _Tint;float _Fps,_Offset,_Intensity; CBUFFER_END
   struct Attributes{float4 position:POSITION;float2 uv:TEXCOORD0;};
   struct Varyings{float4 position:SV_POSITION;float2 uv:TEXCOORD0;};
   Varyings vert(Attributes input){Varyings o;o.position=TransformObjectToHClip(input.position.xyz);o.uv=input.uv;return o;}
   float2 FrameUv(float frame,float2 uv){frame=fmod(frame,16);float col=fmod(frame,4),row=3-floor(frame/4);return (float2(col,row)+uv)*.25;}
   float4 frag(Varyings input):SV_Target
   {
    float t=_Time.y*_Fps+_Offset,frame=floor(t),blend=t-frame;
    float3 a=SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,FrameUv(frame,input.uv)).rgb,b=SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,FrameUv(frame+1,input.uv)).rgb;
    // Soft card edges so no rectangle ever shows, even where a frame's smoke touches the border.
    float edge=smoothstep(0,.12,input.uv.x)*smoothstep(1,.88,input.uv.x)*smoothstep(1,.86,input.uv.y);
    return float4(lerp(a,b,blend)*_Tint.rgb*_Intensity*edge,0);
   }
   ENDHLSL
  }
 }
}
