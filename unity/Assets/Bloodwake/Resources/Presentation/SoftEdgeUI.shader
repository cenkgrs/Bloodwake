// UI painting whose rectangle melts into what is behind it: alpha falls off towards each edge.
// _Feather = (left, bottom, right, top) as fractions of the rect.
Shader "Bloodwake/SoftEdgeUI"
{
 Properties
 {
  [PerRendererData]_MainTex("Texture",2D)="white"{}
  _Feather("Feather",Vector)=(.25,.3,.25,.12)
  _UvRect("UV rect",Vector)=(0,0,1,1)
 }
 SubShader
 {
  Tags{"Queue"="Transparent" "RenderType"="Transparent" "IgnoreProjector"="True" "PreviewType"="Plane"}
  Cull Off ZWrite Off ZTest [unity_GUIZTestMode] Blend SrcAlpha OneMinusSrcAlpha
  Pass
  {
   CGPROGRAM
   #pragma vertex vert
   #pragma fragment frag
   #include "UnityCG.cginc"
   sampler2D _MainTex;float4 _MainTex_ST;float4 _Feather,_UvRect;
   struct appdata{float4 vertex:POSITION;float2 uv:TEXCOORD0;float4 color:COLOR;};
   struct v2f{float4 pos:SV_POSITION;float2 uv:TEXCOORD0;float2 rect:TEXCOORD1;float4 color:COLOR;};
   v2f vert(appdata v){v2f o;o.pos=UnityObjectToClipPos(v.vertex);o.uv=v.uv;o.rect=(v.uv-_UvRect.xy)/_UvRect.zw;o.color=v.color;return o;}
   fixed4 frag(v2f i):SV_Target
   {
    fixed4 c=tex2D(_MainTex,i.uv)*i.color;float2 r=i.rect;
    float a=smoothstep(0,_Feather.x,r.x)*smoothstep(0,_Feather.y,r.y)*smoothstep(0,_Feather.z,1-r.x)*smoothstep(0,_Feather.w,1-r.y);
    c.a*=a;return c;
   }
   ENDCG
  }
 }
}
