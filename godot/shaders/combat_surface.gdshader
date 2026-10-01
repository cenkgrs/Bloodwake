shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 tone : source_color = vec4(0.5,0.75,1.0,1.0);
uniform float progress : hint_range(0.0,1.0) = 0.0;
uniform float energy = 1.2;
// 0: expanding broken wave, 1: swept blade, 2: etched ground sigil.
uniform int shape = 0;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
 vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1.0,0.0)),f.x),mix(hash(i+vec2(0.0,1.0)),hash(i+vec2(1.0)),f.x),f.y);
}
void fragment() {
 vec2 p=UV*2.0-1.0;
 float r=length(p), a=atan(p.x,-p.y);
 float grain=noise(p*15.0+vec2(TIME*0.8,-TIME*1.2));
 float aa=max(fwidth(r),0.003);
 float mask=0.0, hot=0.0, fade=1.0;
 if(shape==0) {
  float front=mix(0.12,0.97,1.0-pow(1.0-progress,2.0));
  float ripple=(noise(p*8.0+vec2(TIME*0.6))-0.5)*0.028;
  float width=mix(0.08,0.018,progress);
  float d=abs(r+ ripple-front);
  hot=1.0-smoothstep(width*0.15,width*0.45+aa,d);
  float rim=1.0-smoothstep(width,width+aa*2.0,d);
  float wake=exp(-abs(r-front+width*2.5)*28.0)*(0.15+grain*0.28);
  mask=rim*(0.4+grain*0.6)+wake;
  fade=smoothstep(0.0,0.045,progress)*pow(1.0-progress,0.7);
 } else if(shape==1) {
  float angular=1.0-smoothstep(0.45,1.35,abs(a));
  float width=0.012+angular*0.11;
  float center=0.77+0.035*sin(a*2.0);
  float d=abs(r-center);
  hot=1.0-smoothstep(0.006,0.018+aa,abs(r-center-width*0.5));
  mask=(1.0-smoothstep(width*0.25,width+aa,d))*angular;
  mask*=0.65+0.35*grain;
  fade=pow(1.0-progress,0.65);
 } else if(shape==3) {
  float expansion=mix(0.15,1.0,1.0-pow(1.0-clamp(progress*3.0,0.0,1.0),3.0));
  float rr=r/max(expansion,0.05);
  float bend=sin(a*13.0+TIME*2.0)*0.005+grain*0.008;
  float rings=exp(-abs(rr-0.94+bend)*180.0)+exp(-abs(rr-0.72-bend)*160.0)*0.65+exp(-abs(rr-0.45+bend)*170.0)*0.5;
  float spokes=pow(1.0-abs(sin(a*12.0)),35.0)*smoothstep(0.44,0.48,rr)*(1.0-smoothstep(0.92,0.98,rr));
  float cell=fract((a+3.141593)/6.283185*24.0);
  vec2 glyph=vec2((cell-0.5)*4.0,(rr-0.835)*28.0);
  float diamond=exp(-abs(abs(glyph.x)+abs(glyph.y)-0.65)*18.0);
  float runes=diamond*smoothstep(0.78,0.80,rr)*(1.0-smoothstep(0.87,0.89,rr));
  float threads=pow(1.0-abs(sin(rr*24.0+a*3.0+grain*3.0-TIME*1.5)),18.0)*0.14;
  mask=rings+spokes*0.32+runes*0.8+threads*(1.0-smoothstep(0.8,0.98,rr));
  hot=rings*0.35;
  fade=smoothstep(0.0,0.035,progress)*(1.0-smoothstep(0.38,1.0,progress));
 } else {
  float outer=1.0-smoothstep(0.005,0.014+aa,abs(r-0.98));
  float inner=(1.0-smoothstep(0.004,0.012+aa,abs(r-0.79)))*0.3;
  float sector=abs(fract((a+3.141593)/6.283185*20.0)-0.5);
  float glyph=(1.0-smoothstep(0.035,0.08,sector))*smoothstep(0.82,0.84,r)*(1.0-smoothstep(0.91,0.93,r));
  mask=outer*0.55+inner+glyph*0.5;
  hot=outer*0.4;
  fade=smoothstep(0.0,0.08,progress)*(1.0-smoothstep(0.8,1.0,progress));
 }
 mask*=1.0-smoothstep(0.99,1.01,r);
 ALBEDO=mix(tone.rgb,vec3(0.88,0.95,1.0),hot*0.32)*energy;
 ALPHA=clamp(mask*fade*tone.a,0.0,0.9);
}
