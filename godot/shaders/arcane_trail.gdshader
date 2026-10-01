shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 tone : source_color = vec4(0.0,0.65,1.0,1.0);
uniform vec4 accent : source_color = vec4(0.15,0.25,1.0,1.0);
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);}
void fragment(){
 float tail=UV.y;
 float x=UV.x*2.0-1.0;
 float grain=noise(vec2(x*5.0,tail*9.0-TIME*4.0));
 float wave=sin(tail*14.0-TIME*9.0)*0.17*tail;
 float envelope=pow(max(0.0,1.0-tail),0.8);
 float filament=pow(1.0-abs(sin(x*12.0+tail*9.0+grain*3.5-TIME*5.0)),9.0);
 float width=(0.58+grain*0.34)*envelope;
 float body=1.0-smoothstep(width*0.35,width,abs(x-wave));
 float alpha=body*(0.12+filament*0.75+grain*0.15)*envelope;
 alpha*=smoothstep(0.0,0.035,tail)*(1.0-smoothstep(0.93,1.0,tail));
 ALBEDO=mix(accent.rgb,tone.rgb,filament*0.7+grain*0.3)*1.35;
 ALPHA=alpha;
}
