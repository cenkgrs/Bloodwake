Shader "Bloodwake/Presentation/Flame"
{
 SubShader
 {
  Tags { "RenderPipeline"="UniversalPipeline" "Queue"="Transparent" "RenderType"="Transparent" }
  Pass
  {
   Cull Off ZWrite Off Blend SrcAlpha One
   HLSLPROGRAM
   #pragma vertex vert
   #pragma fragment frag
   #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
   struct A{float4 p:POSITION;float2 uv:TEXCOORD0;};struct V{float4 p:SV_POSITION;float2 uv:TEXCOORD0;};
   V vert(A a){V o;o.p=TransformObjectToHClip(a.p.xyz);o.uv=a.uv;return o;}
   float hash(float2 p){return frac(sin(dot(p,float2(127.1,311.7)))*43758.5453);}
   float noise(float2 p){float2 i=floor(p),f=frac(p);f=f*f*(3-2*f);return lerp(lerp(hash(i),hash(i+float2(1,0)),f.x),lerp(hash(i+float2(0,1)),hash(i+1),f.x),f.y);}
   half4 frag(V i):SV_Target
   {
    float y=i.uv.y,x=(i.uv.x-.5)*2;
    float n=noise(float2(x*4,y*6-_Time.y*3.5))*.7+noise(float2(x*9,y*13-_Time.y*6))*.3;
    x+=sin(y*7-_Time.y*4)*y*.18;
    float flame=saturate((1-y)*.72-abs(x)+n*.35-.12)*smoothstep(0,.12,y);
    float alpha=smoothstep(.01,.22,flame)*(1-smoothstep(.7,1,y));
    float core=saturate(flame*3)*(1-y);
    return half4(lerp(float3(1,.12,.005),float3(2.8,1.7,.35),core),alpha);
   }
   ENDHLSL
  }
 }
}
