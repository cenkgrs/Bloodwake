// Source splatter behavior retained; wet surface lighting follows Unity art direction.
Shader "Bloodwake/Vfx/revenant_blood"
{
 Properties { _Progress("Progress", Range(0,1))=0 _Wisps("Wisps",Float)=0 _ReverseSweep("Reverse sweep",Float)=0 _Tone("Tone",Color)=(.5,.75,1,1) _Energy("Energy",Float)=1.2 _Shape("Shape",Float)=0 }
 SubShader {
 Tags { "RenderPipeline"="UniversalPipeline" "Queue"="Transparent" "RenderType"="Transparent" }
 Pass {
 ZWrite Off Cull Off Blend SrcAlpha OneMinusSrcAlpha
 HLSLPROGRAM
 #pragma vertex vert
 #pragma fragment frag
 #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
 struct Attributes { float4 positionOS:POSITION; float2 uv:TEXCOORD0; };
 struct Varyings { float4 positionCS:SV_POSITION; float2 uv:TEXCOORD0; float3 world:TEXCOORD1; };
 CBUFFER_START(UnityPerMaterial)
 float _Progress, _Wisps, _ReverseSweep, _Energy, _Shape; float4 _Tone;
 CBUFFER_END
 Varyings vert(Attributes v) { Varyings o; o.positionCS=TransformObjectToHClip(v.positionOS.xyz); o.uv=v.uv; o.world=TransformObjectToWorld(v.positionOS.xyz); return o; }
float hash(float2 p) {return frac(sin(dot(p,float2(127.1,311.7)))*43758.5453);}
float noise(float2 p){float2 c=floor(p),f=frac(p);f=f*f*(3-2*f);return lerp(lerp(hash(c),hash(c+float2(1,0)),f.x),lerp(hash(c+float2(0,1)),hash(c+1),f.x),f.y);}
half4 frag(Varyings i):SV_Target { float3 ALBEDO=0, EMISSION=0; float ALPHA=0;
    float2 p=i.uv*2.0-1.0;
    float r=length(p);
    float angle=atan2(p.y,p.x);
    float edge=.45+noise(p*7.0)*.2+sin(angle*17.0+.7)*.025;
    float pool=1.0-smoothstep(edge-.08,edge,r);
    float drops=0.0;
    for(int dropIndex=0;dropIndex<12;dropIndex++) {
        float a=float(dropIndex)*2.399;
        float2 c=float2(cos(a),sin(a))*(.48+hash(float2(float(dropIndex),3.0))*.35);
        drops+=1.0-smoothstep(.025,.055,length(p-c));
    }
    float3 n=float3(0,1,0),v=normalize(GetWorldSpaceViewDir(i.world));
    Light light=GetMainLight();
    float spec=pow(saturate(dot(n,normalize(light.direction+v))),90);
    float3 reflected=GlossyEnvironmentReflection(reflect(-v,n),i.world,.18,1);
    ALBEDO=float3(.045,.001,.003)*(.3+saturate(dot(n,light.direction))*light.color);
    ALBEDO+=reflected*.08+light.color*spec*.2;
    ALPHA=clamp(pool*.72+drops*.65,0.0,.82)*(1.0-smoothstep(.55,1.0,_Progress));
return half4(ALBEDO+EMISSION, ALPHA);
}

 ENDHLSL
 }
 }
}
