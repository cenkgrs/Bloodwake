// Ported from godot/shaders/revenant_burst.gdshader.
Shader "Bloodwake/Vfx/revenant_burst"
{
 Properties { _Opacity("Opacity",Float)=1  _Progress("Progress", Range(0,1))=0 _Wisps("Wisps",Float)=0 _ReverseSweep("Reverse sweep",Float)=0 _Tone("Tone",Color)=(.5,.75,1,1) _Energy("Energy",Float)=1.2 _Shape("Shape",Float)=0 }
 SubShader {
 Tags { "RenderPipeline"="UniversalPipeline" "Queue"="Transparent" "RenderType"="Transparent" }
 Pass {
 ZWrite Off Cull Off Blend SrcAlpha OneMinusSrcAlpha
 HLSLPROGRAM
 #pragma vertex vert
 #pragma fragment frag
 #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
 struct Attributes { float4 positionOS:POSITION; float2 uv:TEXCOORD0; };
 struct Varyings { float4 positionCS:SV_POSITION; float2 uv:TEXCOORD0; };
 CBUFFER_START(UnityPerMaterial)
 float _Opacity, _Progress, _Wisps, _ReverseSweep, _Energy, _Shape; float4 _Tone;
 CBUFFER_END
 Varyings vert(Attributes v) { Varyings o; o.positionCS=TransformObjectToHClip(v.positionOS.xyz); o.uv=v.uv; return o; }
half4 frag(Varyings i):SV_Target { float3 ALBEDO=0, EMISSION=0; float ALPHA=0;
    float u=i.uv.x;
    float bend=sin(u*47.0)*sin(u*19.0+1.3)*.16;
    float v=abs(i.uv.y-.5+bend)*2.0;
    float vein=exp(-v*v*36.0);
    float body=(1.0-smoothstep(.35,.95,v));
    float rag=0.65+0.35*sin(u*91.0+i.uv.y*25.0)*sin(u*37.0-i.uv.y*13.0);
    float reveal=1.0-smoothstep(_Progress*6.0-.1,_Progress*6.0+.1,u);
    float fade=1.0-smoothstep(.3,1.0,_Progress);
    ALBEDO=lerp(float3(.11,.001,.006),float3(.62,.008,.026),vein);
    EMISSION=float3(.48,.002,.015)*vein*.45;
    ALPHA=body*rag*reveal*fade*((_Wisps>0.5) ? .32 : .9);
return half4(ALBEDO+EMISSION, ALPHA*_Opacity);
}

 ENDHLSL
 }
 }
}
