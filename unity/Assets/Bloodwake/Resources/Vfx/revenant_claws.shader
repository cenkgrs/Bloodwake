// Ported from godot/shaders/revenant_claws.gdshader.
Shader "Bloodwake/Vfx/revenant_claws"
{
 Properties { _Progress("Progress", Range(0,1))=0 _Wisps("Wisps",Float)=0 _ReverseSweep("Reverse sweep",Float)=0 _Tone("Tone",Color)=(.5,.75,1,1) _Energy("Energy",Float)=1.2 _Shape("Shape",Float)=0 }
 SubShader {
 Tags { "RenderPipeline"="UniversalPipeline" "Queue"="Transparent" "RenderType"="Transparent" }
 Pass {
 ZWrite Off Cull Off Blend SrcAlpha One
 HLSLPROGRAM
 #pragma vertex vert
 #pragma fragment frag
 #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
 struct Attributes { float4 positionOS:POSITION; float2 uv:TEXCOORD0; };
 struct Varyings { float4 positionCS:SV_POSITION; float2 uv:TEXCOORD0; };
 CBUFFER_START(UnityPerMaterial)
 float _Progress, _Wisps, _ReverseSweep, _Energy, _Shape; float4 _Tone;
 CBUFFER_END
 Varyings vert(Attributes v) { Varyings o; o.positionCS=TransformObjectToHClip(v.positionOS.xyz); o.uv=v.uv; return o; }
half4 frag(Varyings i):SV_Target { float3 ALBEDO=0, EMISSION=0; float ALPHA=0;
    float u = (_ReverseSweep>0.5) ? 1.0-i.uv.x : i.uv.x;
    float v = abs(i.uv.y-.5)*2.0;
    float jag = sin(i.uv.x*91.0+_Progress*12.0)*sin(i.uv.x*37.0-_Progress*8.0);
    float core = exp(-v*v*42.0);
    float halo = exp(-v*v*7.0);
    float filaments = pow(max(0.0,sin(i.uv.x*130.0+i.uv.y*28.0+_Progress*19.0)),6.0);
    float reveal = 1.0-smoothstep(_Progress*4.0-.12,_Progress*4.0+.12,u);
    float tip = pow(max(0.0,sin(i.uv.x*3.141593)),.45);
    float fade = pow(1.0-_Progress,1.6);
    float strength = (_Wisps>0.5) ? halo*(.22+filaments*.35)*(0.7+jag*.3) : core*2.2+halo*.48;
    ALBEDO = (_Wisps>0.5) ? float3(.65,.002,.012) : lerp(float3(.8,.004,.014),float3(1.0,.20,.12),core*.6);
    ALPHA = clamp(strength*reveal*tip*fade,0.0,1.0);
return half4(ALBEDO+EMISSION, ALPHA);
}

 ENDHLSL
 }
 }
}
