// Ported from godot/shaders/combat_surface.gdshader.
Shader "Bloodwake/Vfx/combat_surface"
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
float hash(float2 p) { return frac(sin(dot(p,float2(127.1,311.7)))*43758.5453); }
float noise(float2 p) {
 float2 i=floor(p), f=frac(p); f=f*f*(3.0-2.0*f);
 return lerp(lerp(hash(i),hash(i+float2(1.0,0.0)),f.x),lerp(hash(i+float2(0.0,1.0)),hash(i+float2(1.0,1.0)),f.x),f.y);
}
half4 frag(Varyings i):SV_Target { float3 ALBEDO=0, EMISSION=0; float ALPHA=0;
 float2 p=i.uv*2.0-1.0;
 float r=length(p), a=atan2(p.x,-p.y);
 float grain=noise(p*15.0+float2(_Time.y*0.8,-_Time.y*1.2));
 float aa=max(fwidth(r),0.003);
 float mask=0.0, hot=0.0, fade=1.0;
 if(_Shape==0) {
  float front=lerp(0.12,0.97,1.0-pow(1.0-_Progress,2.0));
  float ripple=(noise(p*8.0+float2(_Time.y*0.6,_Time.y*0.6))-0.5)*0.028;
  float width=lerp(0.08,0.018,_Progress);
  float d=abs(r+ ripple-front);
  hot=1.0-smoothstep(width*0.15,width*0.45+aa,d);
  float rim=1.0-smoothstep(width,width+aa*2.0,d);
  float wake=exp(-abs(r-front+width*2.5)*28.0)*(0.15+grain*0.28);
  mask=rim*(0.4+grain*0.6)+wake;
  fade=smoothstep(0.0,0.045,_Progress)*pow(1.0-_Progress,0.7);
 } else if(_Shape==1) {
  float angular=1.0-smoothstep(0.45,1.35,abs(a));
  float width=0.012+angular*0.11;
  float center=0.77+0.035*sin(a*2.0);
  float d=abs(r-center);
  hot=1.0-smoothstep(0.006,0.018+aa,abs(r-center-width*0.5));
  mask=(1.0-smoothstep(width*0.25,width+aa,d))*angular;
  mask*=0.65+0.35*grain;
  fade=pow(1.0-_Progress,0.65);
 } else if(_Shape==3) {
  float expansion=lerp(0.15,1.0,1.0-pow(1.0-clamp(_Progress*3.0,0.0,1.0),3.0));
  float rr=r/max(expansion,0.05);
  float bend=sin(a*13.0+_Time.y*2.0)*0.005+grain*0.008;
  float rings=exp(-abs(rr-0.94+bend)*180.0)+exp(-abs(rr-0.72-bend)*160.0)*0.65+exp(-abs(rr-0.45+bend)*170.0)*0.5;
  float spokes=pow(1.0-abs(sin(a*12.0)),35.0)*smoothstep(0.44,0.48,rr)*(1.0-smoothstep(0.92,0.98,rr));
  float cell=frac((a+3.141593)/6.283185*24.0);
  float2 glyph=float2((cell-0.5)*4.0,(rr-0.835)*28.0);
  float diamond=exp(-abs(abs(glyph.x)+abs(glyph.y)-0.65)*18.0);
  float runes=diamond*smoothstep(0.78,0.80,rr)*(1.0-smoothstep(0.87,0.89,rr));
  float threads=pow(1.0-abs(sin(rr*24.0+a*3.0+grain*3.0-_Time.y*1.5)),18.0)*0.14;
  mask=rings+spokes*0.32+runes*0.8+threads*(1.0-smoothstep(0.8,0.98,rr));
  hot=rings*0.35;
  fade=smoothstep(0.0,0.035,_Progress)*(1.0-smoothstep(0.38,1.0,_Progress));
 } else {
  float outer=1.0-smoothstep(0.005,0.014+aa,abs(r-0.98));
  float inner=(1.0-smoothstep(0.004,0.012+aa,abs(r-0.79)))*0.3;
  float sector=abs(frac((a+3.141593)/6.283185*20.0)-0.5);
  float glyph=(1.0-smoothstep(0.035,0.08,sector))*smoothstep(0.82,0.84,r)*(1.0-smoothstep(0.91,0.93,r));
  mask=outer*0.55+inner+glyph*0.5;
  hot=outer*0.4;
  fade=smoothstep(0.0,0.08,_Progress)*(1.0-smoothstep(0.8,1.0,_Progress));
 }
 mask*=1.0-smoothstep(0.99,1.01,r);
 ALBEDO=lerp(_Tone.rgb,float3(0.88,0.95,1.0),hot*0.32)*_Energy;
 ALPHA=clamp(mask*fade*_Tone.a,0.0,0.9);
return half4(ALBEDO+EMISSION, ALPHA);
}

 ENDHLSL
 }
 }
}
