shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 tone : source_color = vec4(0.0,0.75,1.0,1.0);
uniform vec4 accent : source_color = vec4(0.0,0.2,0.9,1.0);
uniform float progress=0.0;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);}
void fragment(){
 float h=1.0-UV.y;
 float n=noise(vec2(UV.x*7.0,h*6.0-TIME*3.5));
 float x=abs(UV.x*2.0-1.0+sin(h*6.0+TIME*4.0)*h*0.15);
 float width=pow(1.0-h,1.4)*(0.65+n*0.6);
 float body=1.0-smoothstep(width*0.4,width,x);
 float veins=pow(1.0-abs(sin(x*13.0+h*11.0+n*4.0)),6.0);
 float life=smoothstep(0.0,0.12,progress)*(1.0-smoothstep(0.25,1.0,progress));
 ALBEDO=mix(accent.rgb,tone.rgb,0.4+veins*0.6)*1.6;
 ALPHA=body*(0.15+n*0.25+veins*0.6)*life*(1.0-smoothstep(0.85,1.0,h));
}
