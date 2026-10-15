Shader "Bloodwake/Presentation/TownSky"
{
 SubShader
 {
  Tags { "Queue"="Background" "RenderType"="Background" "PreviewType"="Skybox" "RenderPipeline"="UniversalPipeline" }
  Cull Off ZWrite Off
  Pass
  {
   HLSLPROGRAM
   #pragma vertex vert
   #pragma fragment frag
   #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
   struct Attributes { float4 vertex:POSITION; };
   struct Varyings { float4 position:SV_POSITION; float3 direction:TEXCOORD0; };
   Varyings vert(Attributes v){Varyings o;o.position=TransformObjectToHClip(v.vertex.xyz);o.direction=v.vertex.xyz;return o;}
   half4 frag(Varyings i):SV_Target
   {
    float3 d=normalize(i.direction);
    float3 horizon=float3(.4,.38,.33),zenith=float3(.32,.43,.64),ground=float3(.065,.055,.05);
    float3 color=d.y>0?lerp(horizon,zenith,smoothstep(0,1,d.y)):lerp(horizon,ground,smoothstep(0,.45,-d.y));
    float moon=pow(saturate(dot(d,normalize(float3(-.4,.65,.6)))),12);
    return half4(color+moon*float3(.65,.75,1),1);
   }
   ENDHLSL
  }
 }
}
