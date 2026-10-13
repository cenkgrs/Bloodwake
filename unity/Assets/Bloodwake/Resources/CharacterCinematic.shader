Shader "Bloodwake/CharacterCinematic"
{
 Properties { _MainTex("Texture",2D)="white"{} _AtlasA("Frames 1–3",2D)="black"{} _AtlasB("Frames 4–6",2D)="black"{} _Elapsed("Elapsed",Float)=0 _Aspect("Aspect",Float)=1.77778 }
 SubShader
 {
  Tags { "Queue"="Transparent" "RenderType"="Transparent" "RenderPipeline"="UniversalPipeline" }
  Cull Off ZWrite Off ZTest Always Blend SrcAlpha OneMinusSrcAlpha
  Pass
  {
   HLSLPROGRAM
   #pragma vertex vert
   #pragma fragment frag
   #include "UnityCG.cginc"
   sampler2D _AtlasA,_AtlasB;float _Elapsed,_Aspect;
   struct appdata {float4 vertex:POSITION;float2 uv:TEXCOORD0;float4 color:COLOR;};
   struct v2f {float4 vertex:SV_POSITION;float2 uv:TEXCOORD0;float4 color:COLOR;};
   v2f vert(appdata v){v2f o;o.vertex=UnityObjectToClipPos(v.vertex);o.uv=v.uv;o.color=v.color;return o;}
   float3 frame(float index,float2 uv){float2 atlas=float2((uv.x+fmod(index,3))/3,uv.y);return index<3?tex2D(_AtlasA,atlas).rgb:tex2D(_AtlasB,atlas).rgb;}
   float3 panel(float index,float2 uv)
   {
    float3 bg=frame(index,float2(uv.x,(uv.y-.5)*.5/_Aspect+.5))*float3(.12,.075,.08);
    float2 local=(uv-.5)/float2(min(1,.82*.5/_Aspect),.82)+.5;
    if(any(local<0)||any(local>1))return bg;
    float2 zoom=(local-.5)/(1+.018*(.5+.5*sin(_Elapsed*1.7)))+.5;
    float vignette=1-smoothstep(.22,.78,distance(local,float2(.5,.5)));
    float edge=smoothstep(0,.045,local.x)*smoothstep(0,.045,1-local.x)*smoothstep(0,.035,local.y)*smoothstep(0,.035,1-local.y);
    return lerp(bg,frame(index,zoom)*(.58+.42*vignette),edge);
   }
   float4 frag(v2f i):SV_Target{float sequence=fmod(_Elapsed/.72,6);float current=floor(sequence);return float4(lerp(panel(current,i.uv),panel(fmod(current+1,6),i.uv),smoothstep(.18,.82,frac(sequence))),1)*i.color;}
   ENDHLSL
  }
 }
}
