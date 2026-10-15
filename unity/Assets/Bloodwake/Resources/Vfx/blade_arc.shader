// Source: godot/shaders/blade_arc.gdshader.
Shader "Bloodwake/Vfx/blade_arc" {
 Properties {_Progress("Progress",Float)=0 _Age("Age",Float)=0 _Tone("Tone",Color)=(1,1,1,1) _Opacity("Opacity",Float)=1}
 SubShader {Tags {"RenderPipeline"="UniversalPipeline" "Queue"="Transparent" "RenderType"="Transparent"}
 Pass {ZWrite Off Cull Off Blend SrcAlpha OneMinusSrcAlpha
 HLSLPROGRAM
 #pragma vertex vert
 #pragma fragment frag
 #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
 CBUFFER_START(UnityPerMaterial)
 float _Progress,_Age,_Opacity;float4 _Tone;
 CBUFFER_END
 struct A{float4 pos:POSITION;float2 uv:TEXCOORD0;};struct V{float4 pos:SV_POSITION;float2 uv:TEXCOORD0;};
 V vert(A v){V o;o.pos=TransformObjectToHClip(v.pos.xyz);o.uv=v.uv;return o;}
 half4 frag(V i):SV_Target { float3 ALBEDO=0;float ALPHA=0;
 float r=i.uv.y;
 float edge=smoothstep(0.84,0.96,r);
 float inner=smoothstep(0.55,0.8,r)*(1.0-smoothstep(0.82,0.92,r));
 float taper=lerp(0.35,1.0,sin(i.uv.x*3.141593));
 float fade=pow(1.0-_Progress,1.25);
 float sweep=exp(-abs(i.uv.x-_Progress)*12.0);
 ALBEDO=lerp(float3(0.38,0.41,0.44),float3(0.95,0.97,1.0),edge);
 ALPHA=(edge*0.78+inner*0.17+0.055)*(0.65+sweep*0.35)*taper*fade;
return half4(ALBEDO*_Tone.rgb,ALPHA*_Opacity);
}
 ENDHLSL
 }}}
